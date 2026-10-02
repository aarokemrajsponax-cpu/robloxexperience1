--!nocheck
-- Boots the whole client under Lune against the real built house: the intro, the title, Play,
-- the walk in, a Salon table (deal, lift, file with a gamepad, the round card, the next
-- round, banking), the Nightly card, the Library (a whole Tête-à-Tête on screen, parcels, the
-- result card), the panels (settings, the leaderboard, how to play) and the Concierge's
-- dialogue. Every Roblox call the client makes goes through real Lune instances or a small
-- stand-in, so a crash anywhere on these paths fails the test.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/client.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

-- "full" walks everything, with the optional title screen switched on. "live" and "studio" boot
-- the client exactly as a guest meets it in the live game, and as the owner meets it pressing
-- Play in Studio: their own character, Roblox's camera and controls, from the first second.
local MODE = process.args[1] or "full"

local Instance, Vector3, Vector2 = roblox.Instance, roblox.Vector3, roblox.Vector2

-- Lune 0.10's CFrame.lookAt faces away from its target (see tests/smoke.luau).
local function lookAt(at, target, up)
	up = up or Vector3.new(0, 1, 0)
	local look = (target - at).Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.new(0, 0, 1))
	end
	right = right.Unit
	local up2 = right:Cross(look)
	return roblox.CFrame.fromMatrix(at, right, up2, -look)
end
local CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame })

local passed, failed = 0, 0
local function check(name: string, ok: boolean, detail: any?)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. (if detail ~= nil then "  -> " .. tostring(detail) else ""))
	end
end

---------------------------------------------------------------------------------------------------
-- A fake clock, a scheduler and signals
---------------------------------------------------------------------------------------------------
local now = 100
local timers = {}
local errors = {}
-- Roblox lets code read a destroyed instance (its Parent is nil); Lune raises instead. Those
-- reads are counted, not failed.
local destroyedReads = 0
local function record(trace: string)
	if string.find(trace, "Instance has been destroyed", 1, true) then
		destroyedReads += 1
		return
	end
	table.insert(errors, trace)
	print("ERROR  " .. trace)
end
local function schedule(at, fn, ...)
	table.insert(timers, { at = at, fn = fn, args = table.pack(...) })
end

local function run(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		record(debug.traceback(co, tostring(err)))
	end
	return co
end

local function resume(co, ...)
	if coroutine.status(co) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		record(debug.traceback(co, tostring(err)))
	end
end

local function signal()
	local s = { handlers = {}, waiting = {} }
	function s:Connect(fn)
		local entry = { fn = fn, live = true }
		table.insert(self.handlers, entry)
		return {
			Connected = true,
			Disconnect = function()
				entry.live = false
			end,
		}
	end
	function s:Once(fn)
		local c
		c = self:Connect(function(...)
			c.Disconnect()
			fn(...)
		end)
		return c
	end
	function s:Wait()
		table.insert(self.waiting, coroutine.running())
		return coroutine.yield()
	end
	function s:Fire(...)
		for _, h in table.clone(self.handlers) do
			if h.live then
				run(h.fn, ...)
			end
		end
		local waiting = self.waiting
		self.waiting = {}
		for _, co in waiting do
			resume(co, ...)
		end
	end
	return s
end

local heartbeat = signal()
local renderStepped = signal()

local function step(dt: number)
	local target = now + dt
	while true do
		table.sort(timers, function(a, b)
			return a.at < b.at
		end)
		local t = timers[1]
		if not t or t.at > target then
			break
		end
		table.remove(timers, 1)
		now = math.max(now, t.at)
		if type(t.fn) == "thread" then
			resume(t.fn, table.unpack(t.args, 1, t.args.n))
		else
			run(t.fn, table.unpack(t.args, 1, t.args.n))
		end
	end
	now = target
	renderStepped:Fire(dt)
	heartbeat:Fire(dt)
end

local function advance(seconds: number)
	local left = seconds
	while left > 1e-9 do
		local dt = math.min(1 / 20, left)
		step(dt)
		left -= dt
	end
end

local taskShim = {
	spawn = function(fn, ...)
		if type(fn) == "thread" then
			resume(fn, ...)
			return fn
		end
		return run(fn, ...)
	end,
	delay = function(t, fn, ...)
		schedule(now + (t or 0), fn, ...)
	end,
	defer = function(fn, ...)
		schedule(now, fn, ...)
	end,
	wait = function(t)
		local co = coroutine.running()
		schedule(now + (t or 1 / 60), co)
		coroutine.yield()
		return t or 1 / 60
	end,
	cancel = function() end,
}

---------------------------------------------------------------------------------------------------
-- What Lune's instances don't do: events, a few methods, per-instance signals
---------------------------------------------------------------------------------------------------
local nextSid = 0
local instanceSignals = {}
local function sid(inst)
	local id = inst:GetAttribute("TestSid")
	if not id then
		nextSid += 1
		id = nextSid
		inst:SetAttribute("TestSid", id)
	end
	return id
end
local function signalOf(inst, name)
	local key = tostring(sid(inst)) .. ":" .. name
	local s = instanceSignals[key]
	if not s then
		s = signal()
		instanceSignals[key] = s
	end
	return s
end

local events = {
	Instance = { "Changed", "Destroying", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "AttributeChanged" },
	GuiButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" },
	GuiObject = { "MouseEnter", "MouseLeave", "SelectionGained", "SelectionLost", "InputBegan", "InputEnded", "InputChanged" },
	Humanoid = { "Seated", "Died", "Running", "StateChanged", "MoveToFinished" },
	ProximityPrompt = { "Triggered", "TriggerEnded", "PromptShown", "PromptHidden", "PromptButtonHoldBegan", "PromptButtonHoldEnded" },
	BindableEvent = { "Event" },
	Sound = { "Ended", "Loaded", "Played" },
}
for class, list in events do
	for _, name in list do
		roblox.implementProperty(class, name, function(self)
			return signalOf(self, name)
		end)
	end
end
roblox.implementMethod("BindableEvent", "Fire", function(self, ...)
	signalOf(self, "Event"):Fire(...)
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, prop)
	return signalOf(self, "prop:" .. prop)
end)
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, name)
	return signalOf(self, "attr:" .. name)
end)
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	return self:FindFirstChild(name)
end)
for _, m in { "Play", "Stop", "Pause", "Resume" } do
	roblox.implementMethod("Sound", m, function() end)
end
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
-- The server's clock, running with the fake one.
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return 1790000000 + now
end)
roblox.implementMethod("ParticleEmitter", "Clear", function() end)

local function corners(cf, size)
	local out = {}
	for _, sx in { -0.5, 0.5 } do
		for _, sy in { -0.5, 0.5 } do
			for _, sz in { -0.5, 0.5 } do
				table.insert(out, cf * Vector3.new(size.X * sx, size.Y * sy, size.Z * sz))
			end
		end
	end
	return out
end
local function boundingBox(model)
	local lo, hi
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			for _, c in corners(d.CFrame, d.Size) do
				lo = if lo then Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z)) else c
				hi = if hi then Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z)) else c
			end
		end
	end
	if not lo then
		return CFrame.new(), Vector3.new()
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end
roblox.implementMethod("Model", "GetBoundingBox", function(self)
	return boundingBox(self)
end)
roblox.implementMethod("Model", "GetPivot", function(self)
	local pp = self.PrimaryPart
	return if pp then pp.CFrame else (boundingBox(self))
end)
roblox.implementMethod("Model", "PivotTo", function(self, target)
	local pivot = if self.PrimaryPart then self.PrimaryPart.CFrame else (boundingBox(self))
	local delta = target * pivot:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)
roblox.implementMethod("Model", "GetScale", function(self)
	return self:GetAttribute("TestScale") or 1
end)
roblox.implementMethod("Model", "ScaleTo", function(self, s)
	self:SetAttribute("TestScale", s)
end)
-- A pinhole camera, the same one the test uses to find things on screen.
local function lens(cam)
	local vp = cam.ViewportSize
	local ty = math.tan(math.rad(cam.FieldOfView) / 2)
	return vp, ty * vp.X / vp.Y, ty
end
roblox.implementMethod("Camera", "ScreenPointToRay", function(self, x, y)
	local vp, tx, ty = lens(self)
	local cf = self.CFrame
	local nx, ny = x / vp.X * 2 - 1, 1 - y / vp.Y * 2
	return { Origin = cf.Position, Direction = (cf.LookVector + cf.RightVector * nx * tx + cf.UpVector * ny * ty).Unit }
end)
roblox.implementMethod("WorldRoot", "Raycast", function()
	return nil -- no physics here: the table falls back to the nearest piece under the pointer
end)
local function toScreen(cam, p)
	local vp, tx, ty = lens(cam)
	local rel = cam.CFrame:PointToObjectSpace(p)
	local nx, ny = (rel.X / -rel.Z) / tx, (rel.Y / -rel.Z) / ty
	return Vector2.new((nx + 1) / 2 * vp.X, (1 - ny) / 2 * vp.Y)
end

---------------------------------------------------------------------------------------------------
-- The DataModel, services and the local guest
---------------------------------------------------------------------------------------------------
local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local camera = Instance.new("Camera")
camera.Parent = workspace
workspace.CurrentCamera = camera
camera.ViewportSize = Vector2.new(1280, 720)
camera.FieldOfView = 70
camera.CFrame = CFrame.new(0, 10, -60)

-- Enums newer than Lune's database resolve to stand-in tokens.
local fakeEnums = {}
local EnumShim = setmetatable({}, {
	__index = function(_, key)
		local ok, value = pcall(function()
			return roblox.Enum[key]
		end)
		if ok and value ~= nil then
			return value
		end
		if not fakeEnums[key] then
			fakeEnums[key] = setmetatable({}, {
				__index = function(t, item)
					local token = key .. "." .. item
					rawset(t, item, token)
					return token
				end,
			})
		end
		return fakeEnums[key]
	end,
})

local CollectionService = {
	AddTag = function(_, instance, tag)
		instance:AddTag(tag)
	end,
	RemoveTag = function(_, instance, tag)
		instance:RemoveTag(tag)
	end,
	HasTag = function(_, instance, tag)
		return instance:HasTag(tag)
	end,
	GetTagged = function(_, tag)
		local out = {}
		for _, d in game:GetDescendants() do
			if d:HasTag(tag) then
				table.insert(out, d)
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function()
		return signal()
	end,
	GetInstanceRemovedSignal = function()
		return signal()
	end,
}

local tweens = 0
local function okSetAll(instance)
	local ok = pcall(function()
		return instance.Parent
	end)
	return ok
end
local TweenService = {
	Create = function(_, instance, info, goal)
		local completed = signal()
		local t
		t = {
			PlaybackState = "Begin",
			Completed = completed,
			Play = function()
				tweens += 1
				local seconds = (info and info.Time or 0) + (info and info.DelayTime or 0)
				local repeating = info and info.RepeatCount and info.RepeatCount < 0
				schedule(now + seconds, function()
					if t.PlaybackState == "Cancelled" then
						return
					end
					for k, v in goal do
						-- The goal is written for real, which validates every tweened property. (A
						-- tween on something already destroyed does nothing, as in Roblox.)
						local okSet, why = pcall(function()
							instance[k] = v
						end)
						if not okSet and not string.find(tostring(why), "destroyed") then
							error(why)
						end
					end
					-- Value objects announce their new value (the table's glides listen for it).
					if okSetAll(instance) and instance:IsA("ValueBase") and goal.Value ~= nil then
						signalOf(instance, "Changed"):Fire(goal.Value)
					end
					if not repeating then
						completed:Fire(roblox.Enum.PlaybackState.Completed)
					end
				end)
			end,
			Cancel = function()
				t.PlaybackState = "Cancelled"
			end,
			Pause = function() end,
		}
		return t
	end,
}

-- The guest on this screen.
local playerGui = Instance.new("PlayerGui")
local character = Instance.new("Model")
character.Name = "Ada"
local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Size = Vector3.new(2, 2, 1)
root.CFrame = CFrame.new(0, 5, -40)
root.Position = Vector3.new(0, 5, -40)
root.Parent = character
local head = Instance.new("Part")
head.Name = "Head"
head.Size = Vector3.new(1, 1, 1)
head.CFrame = CFrame.new(0, 6.5, -40)
head.Parent = character
local humanoid = Instance.new("Humanoid")
humanoid.Parent = character
character.PrimaryPart = root
character.Parent = workspace

local controls = { enabled = true, disabledCount = 0 }
function controls:Enable()
	self.enabled = true
end
function controls:Disable()
	self.enabled = false
	self.disabledCount += 1
end
local PLAYER_MODULE = { __stub = "PlayerModule" }
local playerScripts = {
	WaitForChild = function(_, name)
		return if name == "PlayerModule" then PLAYER_MODULE else nil
	end,
}
local attrs = {}
local playerAttrSignals = {}
local LocalPlayer = setmetatable({
	Name = "Ada",
	DisplayName = "Ada",
	UserId = 1,
	AccountAge = 400,
	Character = character,
	CharacterAdded = signal(),
	CharacterRemoving = signal(),
	PlayerGui = playerGui,
	CameraMinZoomDistance = 0.5,
	CameraMaxZoomDistance = 400,
	DevEnableMouseLock = true,
}, {
	__index = {
		WaitForChild = function(_, name)
			if name == "PlayerGui" then
				return playerGui
			elseif name == "PlayerScripts" then
				return playerScripts
			end
			return nil
		end,
		FindFirstChild = function(_, name)
			if name == "PlayerGui" then
				return playerGui
			end
			return nil
		end,
		GetAttribute = function(_, k)
			return attrs[k]
		end,
		SetAttribute = function(_, k, v)
			attrs[k] = v
			if playerAttrSignals[k] then
				playerAttrSignals[k]:Fire()
			end
		end,
		GetAttributeChangedSignal = function(_, k)
			playerAttrSignals[k] = playerAttrSignals[k] or signal()
			return playerAttrSignals[k]
		end,
		IsA = function(_, class)
			return class == "Player" or class == "Instance"
		end,
	},
})

local Players = {
	LocalPlayer = LocalPlayer,
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return { LocalPlayer }
	end,
	GetPlayerByUserId = function(_, id)
		return if id == 1 then LocalPlayer else nil
	end,
	GetPlayerFromCharacter = function(_, c)
		return if c == character then LocalPlayer else nil
	end,
}

local keysDown = {}
local UserInputService = {
	TouchEnabled = false,
	KeyboardEnabled = true,
	MouseEnabled = true,
	GamepadEnabled = false,
	PreferredInput = EnumShim.PreferredInput.KeyboardAndMouse,
	InputBegan = signal(),
	InputChanged = signal(),
	InputEnded = signal(),
	LastInputTypeChanged = signal(),
	GetLastInputType = function()
		return roblox.Enum.UserInputType.MouseMovement
	end,
	GetConnectedGamepads = function()
		return {}
	end,
	GetMouseLocation = function()
		return Vector2.new(640, 360)
	end,
	IsKeyDown = function(_, key)
		return keysDown[key.Name] == true
	end,
	IsMouseButtonPressed = function()
		return false
	end,
	MouseBehavior = roblox.Enum.MouseBehavior.Default,
}

local actions = {}
local ContextActionService = {
	BindAction = function(_, name, fn, _touch, ...)
		actions[name] = { fn = fn, keys = { ... } }
	end,
	BindActionAtPriority = function(_, name, fn, _touch, _priority, ...)
		actions[name] = { fn = fn, keys = { ... } }
	end,
	UnbindAction = function(_, name)
		actions[name] = nil
	end,
}

local GuiService = {
	SelectedObject = nil,
	MenuIsOpen = false,
	MenuOpened = signal(),
	MenuClosed = signal(),
	-- Roblox's top bar: input positions start below it.
	GetGuiInset = function()
		return Vector2.new(0, 58), Vector2.zero
	end,
}
local shared = { invites = 0 }
shared.SocialService = {
		PromptGameInvite = function()
			shared.invites += 1
		end,
		CanSendGameInviteAsync = function()
			return true
		end,
	}

local services = {
	Players = Players,
	CollectionService = CollectionService,
	TweenService = TweenService,
	UserInputService = UserInputService,
	ContextActionService = ContextActionService,
	GuiService = GuiService,
	SocialService = shared.SocialService,
	CaptureService = {
		CaptureScreenshot = function(_, cb)
			cb("rbxtemp://capture")
		end,
		PromptShareCapture = function() end,
	},
	HapticService = {
		SetMotor = function() end,
		IsVibrationSupported = function()
			return false
		end,
	},
	ContentProvider = { PreloadAsync = function() end },
	ProximityPromptService = { PromptShown = signal(), PromptHidden = signal(), PromptTriggered = signal() },
	StarterGui = {
		SetCoreGuiEnabled = function() end,
		SetCore = function() end,
	},
	RunService = {
		Heartbeat = heartbeat,
		RenderStepped = renderStepped,
		Stepped = signal(),
		IsServer = function()
			return true -- the builders run first, as the server; the client never asks
		end,
		IsClient = function()
			return true
		end,
		IsStudio = function()
			return MODE ~= "live"
		end,
		BindToRenderStep = function(_, _name, _priority, fn)
			renderStepped:Connect(fn)
		end,
		UnbindFromRenderStep = function() end,
	},
}

---------------------------------------------------------------------------------------------------
-- The remotes, as the client sees them
---------------------------------------------------------------------------------------------------
local sent = {} -- what the client sent the server, in order
local remoteEvents = {}
local invokeResults = { QuickSit = true, GetBoard = {} }
local RemotesStub = {
	Events = {},
	Functions = {},
	event = function(name)
		if not remoteEvents[name] then
			remoteEvents[name] = {
				OnClientEvent = signal(),
				FireServer = function(_, message, ...)
					table.insert(sent, { remote = name, message = message, extra = table.pack(...) })
				end,
			}
		end
		return remoteEvents[name]
	end,
	func = function(name)
		return {
			InvokeServer = function(_, ...)
				table.insert(sent, { remote = name, message = table.pack(...) })
				return invokeResults[name]
			end,
		}
	end,
}
local function serverSays(remote, message)
	RemotesStub.event(remote).OnClientEvent:Fire(message)
end
local function sentOps(remote, op)
	local n = 0
	for _, s in sent do
		if s.remote == remote and type(s.message) == "table" and s.message.op == op then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------------------------------------------
-- Module loading from the Rojo sourcemap
---------------------------------------------------------------------------------------------------
local sourcemap = serde.decode("json", fs.readFile("sourcemap.json"))
local proxies, cache = {}, {}
local sources = {}
local requireModule

local function proxyFor(node, parent, path)
	if proxies[node] then
		return proxies[node]
	end
	local p = {}
	proxies[node] = p
	setmetatable(p, {
		__index = function(_, key)
			if key == "Parent" then
				return parent
			elseif key == "Name" then
				return node.name
			end
			for _, child in node.children or {} do
				if child.name == key then
					return proxyFor(child, p, path .. "." .. child.name)
				end
			end
			error(`{key} is not a valid member of {node.name}`)
		end,
	})
	rawset(p, "__node", node)
	rawset(p, "__path", path)
	return p
end
local rootProxy = proxyFor(sourcemap, nil, "game")

local function service(name)
	if services[name] then
		return services[name]
	end
	for _, child in sourcemap.children do
		if child.name == name then
			return proxyFor(child, rootProxy, child.name)
		end
	end
	return game:GetService(name)
end
local gameShim = setmetatable({
	GetService = function(_, name)
		return service(name)
	end,
}, {
	__index = function(_, key)
		return service(key)
	end,
})

local Random = {}
Random.__index = Random
function Random.new(seed)
	local state = (math.floor(seed or 1) * 2654435761 + 12345) % 4294967296
	if state == 0 then
		state = 1
	end
	return setmetatable({ state = state }, Random)
end
function Random:next()
	local s = self.state
	s = bit32.bxor(s, bit32.lshift(s, 13) % 4294967296)
	s = bit32.bxor(s, bit32.rshift(s, 17))
	s = bit32.bxor(s, bit32.lshift(s, 5) % 4294967296)
	self.state = s
	return s / 4294967296
end
function Random:NextNumber(a, b)
	local r = self:next()
	return if a then a + r * (b - a) else r
end
function Random:NextInteger(a, b)
	return a + math.floor(self:next() * (b - a + 1))
end

local fakeOs = setmetatable({
	clock = function()
		return now
	end,
}, { __index = os })

-- Parts made by the client start with a readable Position too.
local InstanceShim = {
	new = function(class, parent)
		-- Classes newer than Lune's database become plain stand-ins.
		local okNew, made = pcall(Instance.new, class)
		if not okNew then
			if class == "ExperienceInviteOptions" or class == "HapticEffect" then
				return { ClassName = class, Play = function() end, Destroy = function() end }
			end
			error(made)
		end
		local i = made
		if i:IsA("BasePart") then
			i.Position = Vector3.zero
		elseif i:IsA("Sound") then
			i.IsPlaying = false
			i.TimePosition = 0
		end
		if parent then
			i.Parent = parent
		end
		return i
	end,
}

local globals = {
	Instance = InstanceShim,
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = CFrame,
	Color3 = roblox.Color3,
	Enum = EnumShim,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Font = {
		new = roblox.Font.new,
		fromName = roblox.Font.fromName,
		fromEnum = function(e)
			local ok, f = pcall(roblox.Font.fromEnum, e)
			return if ok then f else roblox.Font.new("rbxasset://fonts/families/BuilderSans.json")
		end,
	},
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	PhysicalProperties = roblox.PhysicalProperties,
	Rect = roblox.Rect,
	Ray = roblox.Ray,
	Content = {
		fromUri = function(uri)
			return uri
		end,
	},
	RaycastParams = {
		new = function()
			return {}
		end,
	},
	Random = Random,
	TweenInfo = {
		new = function(time, style, direction, repeatCount, reverses, delayTime)
			return {
				Time = time or 1,
				EasingStyle = style or roblox.Enum.EasingStyle.Quad,
				EasingDirection = direction or roblox.Enum.EasingDirection.Out,
				RepeatCount = repeatCount or 0,
				Reverses = reverses or false,
				DelayTime = delayTime or 0,
			}
		end,
	},
	task = taskShim,
	game = gameShim,
	workspace = workspace,
	os = fakeOs,
	warn = function(...)
		print("warn:", ...)
	end,
}

local stubs = {
	["ReplicatedStorage.Shared.Remotes"] = RemotesStub,
}

function requireModule(proxy)
	if proxy == PLAYER_MODULE then
		return {
			GetControls = function()
				return controls
			end,
		}
	end
	local node = rawget(proxy, "__node")
	if cache[node] ~= nil then
		return cache[node]
	end
	local stub = stubs[rawget(proxy, "__path")]
	if stub then
		cache[node] = stub
		return stub
	end
	local path
	for _, f in node.filePaths or {} do
		if string.find(f, "%.luau$") then
			path = f
		end
	end
	assert(path, "no source for " .. node.name)
	local env = { script = proxy, require = requireModule }
	for k, v in globals do
		env[k] = v
	end
	local fn = luau.load(sources[path] or fs.readFile(path), { debugName = path, environment = env, injectGlobals = true })
	local result = fn()
	cache[node] = if result == nil then true else result
	return result
end

local function module(...)
	local p = rootProxy
	for _, name in { ... } do
		p = p[name]
	end
	return requireModule(p)
end

-- Load every source file up front (Lune reads files asynchronously, which would otherwise
-- pause a coroutine in the middle of a frame).
local function preload(node)
	for _, f in node.filePaths or {} do
		if string.find(f, "%.luau$") then
			sources[f] = fs.readFile(f)
		end
	end
	for _, c in node.children or {} do
		preload(c)
	end
end
preload(sourcemap)

---------------------------------------------------------------------------------------------------
-- 1. Build the house, then boot the client
---------------------------------------------------------------------------------------------------
local ok, err = pcall(function()
	module("ServerScriptService", "Server", "World", "Build").run()
end)
check("the house builds", ok, err)
-- Lune keeps Position apart from CFrame and has no default for it: copy it across once.
local function syncPositions(parent)
	for _, d in parent:GetDescendants() do
		if d:IsA("BasePart") then
			d.Position = d.CFrame.Position
		end
	end
end
syncPositions(game)
workspace:SetAttribute("MaisonReady", true)
workspace:SetAttribute("Season", "autumn")
workspace:SetAttribute("SeasonName", "Autumn")

local Config = module("ReplicatedStorage", "Shared", "Config")
if MODE == "full" then
	-- This run walks the optional title screen too, not the Studio shortcut.
	Config.data.Studio.skipTitle = false
	Config.data.Title.show = true
else
	-- As in real life, the character arrives a moment after the client starts.
	LocalPlayer.Character = nil
end
-- Music ids, so the mixing has something to mix.
Config.data.Assets.Music.foyer = "rbxassetid://100"
Config.data.Assets.Music.salon = "rbxassetid://101"
Config.data.Assets.MusicLayers.salon = "rbxassetid://102"
for i, stem in { "full", "bass", "piano", "clock" } do
	Config.data.Assets.Band[stem] = "rbxassetid://11" .. i
end
local Catalogue = module("ReplicatedStorage", "Shared", "Catalogue")

local function find(parent, pred)
	for _, d in parent:GetDescendants() do
		if pred(d) then
			return d
		end
	end
	return nil
end
-- Text is compared without spacing or case (the house letter-spaces its capitals).
local function norm(text: string): string
	return (string.lower(string.gsub(text, "%s+", "")))
end
local function textOnScreen(text)
	local wanted = norm(text)
	return find(playerGui, function(d)
		return (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible ~= false and string.find(norm(d.Text), wanted, 1, true) ~= nil
	end)
end
local function press(text)
	local wanted = norm(text)
	local button = find(playerGui, function(d)
		return d:IsA("TextButton") and norm(d.Text) == wanted
	end)
	if not button then
		return false
	end
	signalOf(button, "Activated"):Fire()
	return true
end
-- Snapshots: `lune run tests/client.luau full <folder>` also writes the screen's UI at a few
-- moments as JSON, for tools/ui/render.py to draw (a way to look at the UI without Studio).
local SNAPSHOT = process.args[2]
local function snapshot(name: string)
	if not SNAPSHOT then
		return
	end
	local function udim2(u)
		return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
	end
	local function colour(c)
		return { c.R, c.G, c.B }
	end
	local function get(inst, prop)
		local ok, v = pcall(function()
			return inst[prop]
		end)
		return if ok then v else nil
	end
	local function dump(inst)
		local n = { class = inst.ClassName, name = inst.Name, kids = {} }
		if inst:IsA("GuiObject") then
			n.pos = udim2(inst.Position)
			n.size = udim2(inst.Size)
			n.anchor = { inst.AnchorPoint.X, inst.AnchorPoint.Y }
			n.rot = inst.Rotation
			n.bg = colour(inst.BackgroundColor3)
			n.bgT = inst.BackgroundTransparency
			n.visible = inst.Visible
			n.z = inst.ZIndex
			n.order = inst.LayoutOrder
			n.clip = inst.ClipsDescendants
			n.auto = inst.AutomaticSize.Name
			if inst:IsA("CanvasGroup") then
				n.groupT = inst.GroupTransparency
			end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				n.text = inst.Text
				n.textSize = inst.TextSize
				n.textColor = colour(inst.TextColor3)
				n.textT = inst.TextTransparency
				n.xAlign = inst.TextXAlignment.Name
				n.yAlign = inst.TextYAlignment.Name
				n.wrap = inst.TextWrapped
				n.scaled = inst.TextScaled
				local ff = get(inst, "FontFace")
				n.weight = if ff then ff.Weight.Name else "Regular"
				n.style = if ff then ff.Style.Name else "Normal"
				n.family = if ff then ff.Family else ""
			end
		elseif inst:IsA("ScreenGui") then
			n.order = inst.DisplayOrder
			n.enabled = inst.Enabled
			n.ignoreInset = inst.IgnoreGuiInset
		elseif inst:IsA("UICorner") then
			n.radius = { inst.CornerRadius.Scale, inst.CornerRadius.Offset }
		elseif inst:IsA("UIGradient") then
			local cs = {}
			for _, k in inst.Color.Keypoints do
				table.insert(cs, { k.Time, k.Value.R, k.Value.G, k.Value.B })
			end
			local ts = {}
			for _, k in inst.Transparency.Keypoints do
				table.insert(ts, { k.Time, k.Value })
			end
			n.colors = cs
			n.trans = ts
			n.rot = inst.Rotation
			n.offset = { inst.Offset.X, inst.Offset.Y }
			n.enabled = inst.Enabled
		elseif inst:IsA("UIStroke") then
			n.color = colour(inst.Color)
			n.thickness = inst.Thickness
			n.trans = inst.Transparency
			n.enabled = inst.Enabled
		elseif inst:IsA("UIScale") then
			n.scale = inst.Scale
		elseif inst:IsA("UIListLayout") then
			n.dir = inst.FillDirection.Name
			n.padding = { inst.Padding.Scale, inst.Padding.Offset }
			n.hAlign = inst.HorizontalAlignment.Name
			n.vAlign = inst.VerticalAlignment.Name
		elseif inst:IsA("UIPadding") then
			n.pad = { inst.PaddingTop.Offset, inst.PaddingBottom.Offset, inst.PaddingLeft.Offset, inst.PaddingRight.Offset }
		elseif inst:IsA("UITextSizeConstraint") then
			n.maxText = inst.MaxTextSize
			n.minText = inst.MinTextSize
		elseif inst:IsA("UIGridLayout") then
			n.cell = udim2(inst.CellSize)
			n.cellPad = udim2(inst.CellPadding)
			n.hAlign = inst.HorizontalAlignment.Name
		elseif inst:IsA("UISizeConstraint") then
			n.max = { inst.MaxSize.X, inst.MaxSize.Y }
		end
		for _, c in inst:GetChildren() do
			table.insert(n.kids, dump(c))
		end
		return n
	end
	local out = { viewport = { camera.ViewportSize.X, camera.ViewportSize.Y }, guis = {} }
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") then
			table.insert(out.guis, dump(g))
		end
	end
	fs.writeFile(SNAPSHOT .. "/" .. name .. ".json", serde.encode("json", out))
end

local function pad(key)
	local input = { KeyCode = key, UserInputType = roblox.Enum.UserInputType.Gamepad1, UserInputState = roblox.Enum.UserInputState.Begin, Position = Vector3.zero }
	for name, action in actions do
		for _, k in action.keys do
			if k == key then
				local result = action.fn(name, roblox.Enum.UserInputState.Begin, input)
				if result ~= roblox.Enum.ContextActionResult.Pass then
					return true
				end
			end
		end
	end
	return false
end

local mainNode = rootProxy.StarterPlayer.StarterPlayerScripts.Client.Main
run(function()
	requireModule(mainNode)
end)
advance(1)
check("the client boots without an error", #errors == 0, errors[1])

if MODE ~= "full" then
	local where = if MODE == "live" then "the live game" else "Studio"
	check(where .. ": the client says it started (the failsafe stands down)", LocalPlayer:GetAttribute("MaisonClient") == "ready")
	check(where .. ": no drifting camera over the street", camera.CameraType ~= roblox.Enum.CameraType.Scriptable, tostring(camera.CameraType))
	-- The character arrives from the server a moment later.
	advance(1.5)
	LocalPlayer.Character = character
	LocalPlayer.CharacterAdded:Fire(character)
	local scripted = false
	for _ = 1, 30 do
		advance(0.1)
		if camera.CameraType == roblox.Enum.CameraType.Scriptable then
			scripted = true
		end
	end
	check(where .. ": the camera is never taken over", not scripted)
	check(where .. ": Roblox's own follow camera, on your character", camera.CameraType == roblox.Enum.CameraType.Custom and camera.CameraSubject == humanoid, tostring(camera.CameraType))
	check(where .. ": your controls are never taken away", controls.enabled == true and controls.disabledCount == 0, controls.disabledCount)
	check(where .. ": walking speed is set", humanoid.WalkSpeed == Config.data.Movement.walkSpeed, humanoid.WalkSpeed)
	check(where .. ": Shift runs", (function()
		local action = actions.MaisonRun
		if not action then
			return false
		end
		action.fn("MaisonRun", roblox.Enum.UserInputState.Begin, { KeyCode = roblox.Enum.KeyCode.LeftShift })
		local running = humanoid.WalkSpeed == Config.data.Movement.runSpeed
		action.fn("MaisonRun", roblox.Enum.UserInputState.End, { KeyCode = roblox.Enum.KeyCode.LeftShift })
		return running
	end)())
	check(where .. ": the Settings key is there", textOnScreen("Settings") ~= nil)
	if MODE == "studio" then
		check("Studio: the build number shows in the corner", textOnScreen("Build " .. module("ReplicatedStorage", "Shared", "Build").number) ~= nil)
		local cover = playerGui.MaisonIntro:FindFirstChild("Cover")
		check("Studio: no black cover over the screen", cover == nil or cover.Visible == false or cover.BackgroundTransparency >= 1)
	else
		check("the live game: no build number on screen", textOnScreen("Build " .. module("ReplicatedStorage", "Shared", "Build").number) == nil)
		-- The intro plays over the live house; walking skips it, and the cover lifts.
		local cover = playerGui.MaisonIntro:FindFirstChild("Cover")
		UserInputService.InputBegan:Fire({ UserInputType = roblox.Enum.UserInputType.Keyboard, KeyCode = roblox.Enum.KeyCode.W })
		advance(2)
		check("the live game: pressing W skips the intro and the cover lifts", cover == nil or cover.BackgroundTransparency >= 0.99, cover and cover.BackgroundTransparency)
	end
	-- Sitting down works as ever: the server seats you, the table's camera takes over, Leave gives
	-- your character back.
	local salon
	for _, m in CollectionService:GetTagged("MaisonTable") do
		if m:GetAttribute("Room") == "salon" and salon == nil then
			salon = m
		end
	end
	serverSays("Table", { op = "seated", table = salon:GetAttribute("TableId"), room = "salon", mode = "room" })
	advance(2)
	check(where .. ": sitting at a table frames it", camera.CameraType == roblox.Enum.CameraType.Scriptable and controls.enabled == false)
	serverSays("Table", { op = "left" })
	advance(3)
	check(where .. ": leaving the table gives your character back", camera.CameraType == roblox.Enum.CameraType.Custom and controls.enabled == true)
	check(where .. ": no errors", #errors == 0, errors[1])
	print(string.format("%s: %d passed, %d failed", MODE, passed, failed))
	process.exit(if failed > 0 then 1 else 0)
end
check("the screen layers exist", playerGui:FindFirstChild("MaisonPanels") ~= nil and playerGui:FindFirstChild("MaisonHud") ~= nil)
check("controls are off before Play", controls.enabled == false)
check("the camera drifts under the title", camera.CameraType == roblox.Enum.CameraType.Scriptable)

serverSays("Guest", {
	op = "welcome",
	firstVisit = true,
	displayName = "Ada",
	settings = {},
	overrides = {},
	nights = 1,
	gilt = 0,
	best = { salon = 0, velvet = 0, obsidian = 0, midnight = 0 },
	registered = 0,
	saved = false,
	unlocked = { midnight = false },
	nightly = { played = false, score = 0, grade = "" },
})
advance(12)
check("the title shows Play", textOnScreen("Play") ~= nil)
check("on the title, W/A/S/D count as Play (nobody is left watching)", actions.MaisonWalkToPlay ~= nil)
check("no errors through the intro and title", #errors == 0, errors[1])

---------------------------------------------------------------------------------------------------
-- 2. Play: the camera hands over and the guest can walk
---------------------------------------------------------------------------------------------------
local pressed = press("Play")
check("Play can be pressed", pressed)
advance(3)
check("controls are on after Play", controls.enabled == true)
check("the walking camera is Roblox's own follow camera", camera.CameraType == roblox.Enum.CameraType.Custom, tostring(camera.CameraType))
check("the camera follows the guest", camera.CameraSubject == humanoid)
check("walking speed is set", humanoid.WalkSpeed == Config.data.Movement.walkSpeed, humanoid.WalkSpeed)
check("Shift runs", (function()
	local action = actions.MaisonRun
	if not action then
		return false
	end
	action.fn("MaisonRun", roblox.Enum.UserInputState.Begin, { KeyCode = roblox.Enum.KeyCode.LeftShift })
	local running = humanoid.WalkSpeed == Config.data.Movement.runSpeed
	action.fn("MaisonRun", roblox.Enum.UserInputState.End, { KeyCode = roblox.Enum.KeyCode.LeftShift })
	return running and humanoid.WalkSpeed == Config.data.Movement.walkSpeed
end)())
check("a first visit offers Straight to the table", textOnScreen("Straight to the table") ~= nil)
check("what's next, while walking: take a seat", textOnScreen("Take a seat at any table in the Salon") ~= nil)
check("and how, with the keys in your hands", textOnScreen("Walk up to a chair and press E") ~= nil)
check("no errors after Play", #errors == 0, errors[1])

-- The Black Card on the lectern: not there until it's offered, and never in a guest's first minutes.
local blackCard = CollectionService:GetTagged("BlackCardLectern")[1]
check("the lectern holds the Black Card", blackCard ~= nil)
check("while it isn't offered, the card isn't there", blackCard.LocalTransparencyModifier == 1 and blackCard:FindFirstChildOfClass("ProximityPrompt").Enabled == false)
workspace:SetAttribute("BlackCardOffered", true)
signalOf(workspace, "attr:BlackCardOffered"):Fire()
advance(0.2)
check("offered: the card lies on the lectern", blackCard.LocalTransparencyModifier == 0 and blackCard:FindFirstChildOfClass("ProximityPrompt").Enabled == true)
LocalPlayer:SetAttribute("Quiet", true)
advance(0.2)
check("a guest's first minutes: the card isn't there", blackCard.LocalTransparencyModifier == 1)
LocalPlayer:SetAttribute("Quiet", nil)
advance(0.2)

---------------------------------------------------------------------------------------------------
-- 3. The Concierge speaks, with choices
---------------------------------------------------------------------------------------------------
serverSays("Dialogue", { op = "say", speaker = "THE CONCIERGE", line = "Good evening. The tables are set.", choices = { { id = "room", text = "Take me to a room" }, { id = "bye", text = "Good night" } } })
advance(1)
check("the Concierge's line is on screen", textOnScreen("The tables are set") ~= nil)
snapshot("dialogue")
advance(4)
check("no errors in the dialogue", #errors == 0, errors[1])
-- The Concierge's tour: the Concierge walks you round the whole house, a card at every stop.
do
	local Voice = module("ReplicatedStorage", "Shared", "Voice")
	local Tour = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "Tour")
	-- The house's Concierge at the lectern, as the server's rig arrives on this screen.
	local concierge = Instance.new("Model")
	concierge.Name = "Concierge"
	concierge:SetAttribute("Staff", "Concierge")
	local croot = Instance.new("Part")
	croot.Name = "HumanoidRootPart"
	croot.Size = Vector3.new(2, 2, 1)
	croot.CFrame = CFrame.new(9, 6, 4.2)
	croot.Parent = concierge
	local chead = Instance.new("Part")
	chead.Name = "Head"
	chead.Size = Vector3.new(1, 1, 1)
	chead.CFrame = CFrame.new(9, 7.5, 4.2)
	chead.Parent = concierge
	local speak = Instance.new("ProximityPrompt")
	speak.Name = "SpeakPrompt"
	speak.Parent = chead
	local chum = Instance.new("Humanoid")
	chum.HipHeight = 2
	chum.Parent = concierge
	concierge.PrimaryPart = croot
	concierge.Parent = workspace
	local was = root.Position
	local function moveGuest(p: Vector3)
		root.CFrame = CFrame.new(p)
		root.Position = p
	end
	moveGuest(Vector3.new(9, 5, 12))
	serverSays("Tour", { op = "start" })
	advance(1)
	local guide = workspace:FindFirstChild("MaisonTourGuide")
	check("the tour: the Concierge sets off with you (your own guide, on your screen)", guide ~= nil and guide:FindFirstChildOfClass("ProximityPrompt", true) == nil)
	check("the house's Concierge is hidden from you meanwhile", chead.LocalTransparencyModifier == 1 and speak.Enabled == false)
	check("the server knows you're on the tour", sentOps("Tour", "start") == 1)
	check("the first card: the idea", textOnScreen(Voice.Tour[1].title) ~= nil and textOnScreen("1 of " .. #Voice.Tour) ~= nil)
	-- Next, and stay put: the Concierge waits a little way ahead rather than leaving you behind.
	press("Next")
	advance(6)
	local _, _, waitState, waitAt = Tour.where()
	check("the Concierge waits when you fall behind", waitState == "walking" and (waitAt - Vector3.new(9, 3, 12)).Magnitude < 20, waitAt)
	check("on the way: where to, a pin there, and a key to end the tour", textOnScreen("This way, to the Salon") ~= nil and textOnScreen("End the tour") ~= nil and workspace:FindFirstChild("MaisonWaypoint") ~= nil and workspace.MaisonWaypoint.Pin.Label.Text == "The Salon")
	-- Follow the Concierge to every stop and read every card.
	local visited = {}
	local climbed = false
	local guideTop = 0
	local cardsSeen = 1
	local pinned, placed = 0, 0
	local i = 2
	while i <= #Voice.Tour do
		for _ = 1, 600 do
			local _, _, state, at = Tour.where()
			if state == "card" then
				break
			end
			moveGuest(at + Vector3.new(0, 2, 0))
			advance(0.1)
			if at.Y > 8 and at.Y < 18 then
				climbed = true
			end
			local gr = guide and guide:FindFirstChild("HumanoidRootPart")
			if gr then
				guideTop = math.max(guideTop, gr.CFrame.Position.Y)
			end
		end
		local stopId, cardAt, state = Tour.where()
		visited[stopId] = true
		if state == "card" and cardAt == i and textOnScreen(Voice.Tour[i].title) ~= nil and textOnScreen(i .. " of " .. #Voice.Tour) ~= nil then
			cardsSeen += 1
		end
		local place = Voice.Tour[i].place
		if place then
			local pin = workspace:FindFirstChild("MaisonWaypoint")
			if pin and pin.Pin.Label.Text == Voice.TourPlaces[place] then
				pinned += 1
			end
			placed += 1
		end
		if i == 8 then
			-- Back shows the card before, where you stand.
			press("Back")
			advance(0.3)
			check("Back shows the card before", textOnScreen(Voice.Tour[7].title) ~= nil)
			press("Next")
			advance(0.3)
		end
		if i < #Voice.Tour then
			press("Next")
			advance(0.2)
		end
		i += 1
	end
	check("every card is shown, in order", cardsSeen == #Voice.Tour, cardsSeen)
	check("the tour walks the whole house: the Salon, Tonight's board, the Vault, the Boutique", visited.salon and visited.tonight and visited.vault and visited.boutique)
	check("and upstairs: the Library, the Ballroom, the Terrace, your Suite", visited.library and visited.ballroom and visited.terrace and visited.suite)
	check("the Concierge climbs the Grand Stair to the Club Floor", climbed and guideTop > 20, guideTop)
	check("each card points at its place: a gold pin with its name", placed >= 10 and pinned == placed, pinned .. " of " .. placed)
	advance(1)
	snapshot("tour")
	check("the last card offers a table", textOnScreen("Take me to a table") ~= nil and textOnScreen("I'll explore") ~= nil)
	press("I'll explore")
	advance(1)
	check("ending it: your guide goes and the Concierge is back at the lectern", workspace:FindFirstChild("MaisonTourGuide") == nil and chead.LocalTransparencyModifier == 0 and speak.Enabled == true)
	check("the pin goes with it", workspace:FindFirstChild("MaisonWaypoint") == nil)
	check("and the server hears it's over", sentOps("Tour", "end") == 1)
	-- Wandering off ends it too, kindly.
	moveGuest(Vector3.new(9, 5, 12))
	serverSays("Tour", { op = "start" })
	advance(1)
	moveGuest(Vector3.new(0, 5, -200))
	advance(45)
	check("a guest who wanders off has left the tour", Tour.active() == false and workspace:FindFirstChild("MaisonTourGuide") == nil)
	check("no errors on the tour", #errors == 0, errors[1])
	concierge:Destroy()
	moveGuest(was)
	advance(0.5)
end

---------------------------------------------------------------------------------------------------
-- 4. A Salon table: seated, a deal, lift and file with a gamepad, the round, the bank
---------------------------------------------------------------------------------------------------
local salonTable
for _, m in CollectionService:GetTagged("MaisonTable") do
	if m:GetAttribute("Room") == "salon" and salonTable == nil then
		salonTable = m
	end
end
check("a Salon table exists", salonTable ~= nil)
UserInputService.PreferredInput = EnumShim.PreferredInput.Gamepad
serverSays("Table", { op = "seated", table = salonTable:GetAttribute("TableId"), room = "salon", mode = "room" })
local fovAtSeat = camera.FieldOfView
advance(2)
check("seated: controls are off", controls.enabled == false)
check("seated: the camera frames the table", camera.CameraType == roblox.Enum.CameraType.Scriptable)
check("seated: Leave is on screen", textOnScreen("Leave") ~= nil)
do
	local shopKey = find(playerGui, function(d)
		return d.Name == "ShopKey"
	end)
	check("there's a gold Shop key on screen", shopKey ~= nil)
	check("seated: the Shop key steps aside for the sorting screen", shopKey ~= nil and shopKey.Visible == false)
end
check("seated: the what's-next card steps aside", textOnScreen("Take a seat at any table in the Salon") == nil)

-- The sorting screen: sit down and the house falls away; only the sorting screen is left.
local sortGui = playerGui:FindFirstChild("MaisonSort")
do
	check("sorting: the sorting screen opens", sortGui ~= nil and sortGui.Enabled == true)
	local size = sortGui and sortGui.Root.Size
	check("sorting: it covers the whole screen, nothing of the room shows", sortGui ~= nil and sortGui.IgnoreGuiInset == true and sortGui.Root.Visible == true and sortGui.Root.BackgroundTransparency == 0 and size.X.Scale == 1 and size.Y.Scale == 1)
	check("sorting: in through a dip to black, not a cut", sortGui.Curtain.BackgroundTransparency == 1)
	check("sorting: the six cases, named as in the brief", textOnScreen("WATCHES") ~= nil and textOnScreen("JEWELRY") ~= nil and textOnScreen("COLLECTIBLES") ~= nil and textOnScreen("Bars, notes, coins") ~= nil)
	check("sorting: each case has its own drawn mark", (function()
		for _, bin in sortGui.Root.Cases:GetChildren() do
			local mark = bin:FindFirstChild("Mark", true)
			if not mark or #mark:GetDescendants() < 2 then
				return false
			end
		end
		return #sortGui.Root.Cases:GetChildren() == 6
	end)())
	check("sorting: the room's name in the header", textOnScreen("THE SALON") ~= nil)
	check("sorting: the HUD's keys stay on top of it", playerGui.MaisonHud.DisplayOrder > sortGui.DisplayOrder)
end

-- Finding things on the sorting screen (every position is set in screen pixels).
local Sort = {}
function Sort.centre(f)
	return Vector2.new(f.Position.X.Offset, f.Position.Y.Offset)
end
function Sort.card(uid)
	for _, c in sortGui.Root.Pieces:GetChildren() do
		if c:GetAttribute("Uid") == uid then
			return c
		end
	end
	return nil
end
function Sort.bin(caseId)
	for _, b in sortGui.Root.Cases:GetChildren() do
		if b:GetAttribute("CaseId") == caseId then
			return b
		end
	end
	return nil
end
function Sort.pointer(kind, at)
	-- Screen positions to input positions, which start below the top bar.
	return { UserInputType = kind, Position = Vector3.new(at.X, at.Y - 58, 0), KeyCode = roblox.Enum.KeyCode.Unknown, UserInputState = roblox.Enum.UserInputState.Begin }
end
-- Drags a piece to a case with the mouse and lets go. Returns where the piece was just after the
-- pointer moved, where it was a moment later, whether the case lit up, and where the pointer was.
function Sort.drag(uid, caseId)
	UserInputService.PreferredInput = EnumShim.PreferredInput.KeyboardAndMouse
	local card = Sort.card(uid)
	local from = Sort.centre(card)
	local to = Sort.centre(Sort.bin(caseId))
	signalOf(card, "InputBegan"):Fire(Sort.pointer(roblox.Enum.UserInputType.MouseButton1, from))
	UserInputService.InputChanged:Fire(Sort.pointer(roblox.Enum.UserInputType.MouseMovement, from + Vector2.new(24, 0)), false)
	advance(0.05)
	UserInputService.InputChanged:Fire(Sort.pointer(roblox.Enum.UserInputType.MouseMovement, to), false)
	local justMoved = Sort.centre(card)
	advance(0.4)
	local settled = Sort.centre(card)
	local lit = Sort.bin(caseId):FindFirstChildOfClass("UIStroke").Thickness == 2
	UserInputService.InputEnded:Fire(Sort.pointer(roblox.Enum.UserInputType.MouseButton1, to), false)
	return justMoved, settled, lit, to
end

local function pieceList(n, cases)
	local out = {}
	local i = 0
	for _, p in Catalogue.Core do
		if table.find(cases, p.case) then
			i += 1
			table.insert(out, { uid = i, id = p.id, name = p.name, case = p.case, value = p.value, rare = i == 2, seasonal = false, mythic = false })
			if i >= n then
				break
			end
		end
	end
	return out
end
local cases = { Catalogue.Cases[1].id, Catalogue.Cases[2].id, Catalogue.Cases[3].id, Catalogue.Cases[4].id }
local deal = pieceList(8, cases)
serverSays("Table", { op = "deal", round = 1, room = "salon", mode = "room", cases = cases, pieces = deal, score = 0 })
advance(2)
local piecesFolder = sortGui.Root.Pieces
check("the deal lands on the tray", #piecesFolder:GetChildren() == 8, #piecesFolder:GetChildren())
check("every piece is drawn, not a placeholder", (function()
	for _, card in piecesFolder:GetChildren() do
		local art = card:FindFirstChild("Art", true)
		if not art or #art:GetDescendants() < 6 then
			return false
		end
	end
	return true
end)())
do
	-- Names show on a small tag when you point at a piece (or hold it, or choose it on a pad).
	local quiet
	for _, p in deal do
		local card = Sort.card(p.uid)
		if not card.Selected.Visible then
			quiet = p
			break
		end
	end
	check("a piece's name stays out of the way until you point at it", textOnScreen(quiet.name) == nil)
	signalOf(Sort.card(quiet.uid), "MouseEnter"):Fire()
	check("point at a piece and its name shows", textOnScreen(quiet.name) ~= nil)
	signalOf(Sort.card(quiet.uid), "MouseLeave"):Fire()
	check("and goes again when you look away", textOnScreen(quiet.name) == nil)
	local chosen
	for _, p in deal do
		if Sort.card(p.uid).Selected.Visible then
			chosen = p
		end
	end
	check("with a gamepad, the chosen piece shows its name", chosen ~= nil and textOnScreen(chosen.name) ~= nil)
end
check("the header counts what's left on the cloth", textOnScreen("8 pieces left") ~= nil)
check("and shows the score and the combo as figures", sortGui.Root.Header.Stat_SCORE.Visible and sortGui.Root.Header.Stat_COMBO.Visible and sortGui.Root.Header.Stat_ROUND.Value.Text == "I", sortGui.Root.Header.Stat_ROUND.Value.Text)
check("a gilded piece has a glow about it", Sort.card(2):FindFirstChild("Glow") ~= nil and Sort.card(1):FindFirstChild("Glow") == nil)
check("the cases closed this round say so", (function()
	local closed = 0
	for _, bin in sortGui.Root.Cases:GetChildren() do
		if bin.Sub.Text == "Closed this round" then
			closed += 1
		end
	end
	return closed == 2
end)())
do
	local tray = sortGui.Root.Tray
	local x0, y0 = tray.Position.X.Offset, tray.Position.Y.Offset
	local x1, y1 = x0 + tray.Size.X.Offset, y0 + tray.Size.Y.Offset
	local inside, apart = true, true
	local cards = piecesFolder:GetChildren()
	local icon = cards[1].Icon.Size.X.Offset
	for i, a in cards do
		local c = Sort.centre(a)
		if c.X < x0 or c.X > x1 or c.Y < y0 or c.Y > y1 then
			inside = false
		end
		for j = i + 1, #cards do
			if (Sort.centre(cards[j]) - c).Magnitude < icon * 0.8 then
				apart = false
			end
		end
	end
	check("every piece sits on the tray", inside)
	check("no two pieces sit on top of each other", apart)
	check("the pieces are a good size to pick up", icon >= 50, icon)
end
check("no errors rendering the deal", #errors == 0, errors[1])
check("the first deal says what to do", textOnScreen("Put every piece in the case where it belongs") ~= nil)
check("and how, for the controls in your hands", textOnScreen("A picks up") ~= nil)
snapshot("sort-deal")
if MODE == "full" then
	-- On a phone held upright: the cases in two rows, the figures clear of the keys.
	camera.ViewportSize = Vector2.new(390, 844)
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.1)
	local inside = true
	local tray = sortGui.Root.Tray
	for _, card in sortGui.Root.Pieces:GetChildren() do
		local c = Sort.centre(card)
		if c.X < tray.Position.X.Offset or c.X > tray.Position.X.Offset + tray.Size.X.Offset or c.Y < tray.Position.Y.Offset or c.Y > tray.Position.Y.Offset + tray.Size.Y.Offset then
			inside = false
		end
	end
	check("on a phone, every piece still sits on the cloth", inside)
	snapshot("sort-phone")
	camera.ViewportSize = Vector2.new(1280, 720)
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.1)
end

-- Lift the first piece and file it with the gamepad (A lifts, the D-pad picks a case, A files).
local liftedBefore = sentOps("Table", "lift")
check("A lifts a piece", pad(roblox.Enum.KeyCode.ButtonA))
advance(0.5)
check("the lift is sent", sentOps("Table", "lift") == liftedBefore + 1)
local function trailCount(name: string): number
	local lit = 0
	for _, dot in sortGui.Root.Trail:GetChildren() do
		if dot.Name == name and dot.Visible and (name == "Sparkle" or dot.BackgroundTransparency < 1) then
			lit += 1
		end
	end
	return lit
end
local heldPiece = (function()
	-- The piece in hand is the one lifted off the cloth (drawn a little larger).
	for _, card in sortGui.Root.Pieces:GetChildren() do
		local scale = card:FindFirstChildOfClass("UIScale")
		if scale and scale.Scale > 1.1 then
			for _, p in deal do
				if p.uid == card:GetAttribute("Uid") then
					return p
				end
			end
		end
	end
	return nil
end)()
check("in the Salon, a thread of light runs from the held piece to its case", trailCount("Light") >= 12, trailCount("Light"))
check("and sparkles twinkling along the way", trailCount("Sparkle") >= 2, trailCount("Sparkle"))
local guideCase = (function()
	for _, f in sortGui.Root.Cases:GetChildren() do
		if f:FindFirstChild("Guide") then
			return f
		end
	end
	return nil
end)()
check("the right case lights up", heldPiece ~= nil and guideCase ~= nil and guideCase:GetAttribute("CaseId") == heldPiece.case, heldPiece and heldPiece.case)
local arrow = sortGui.Root.Trail:FindFirstChild("Arrow")
check("and a gold arrow bobs over it", arrow ~= nil and arrow.Visible and guideCase ~= nil and math.abs(arrow.Position.X.Offset - guideCase.Position.X.Offset) < 2 and arrow.Position.Y.Offset < guideCase.Position.Y.Offset)
snapshot("sort-guide")
do
	-- The guide follows Settings → The guide, and the trail the guest wears.
	local SortScreen = module("StarterPlayer", "StarterPlayerScripts", "Client", "Table", "SortScreen")
	local GuideTrail = module("StarterPlayer", "StarterPlayerScripts", "Client", "Table", "GuideTrail")
	local State = module("StarterPlayer", "StarterPlayerScripts", "Client", "State")
	local Brand = module("ReplicatedStorage", "Shared", "Brand")
	local Wardrobe = module("ReplicatedStorage", "Shared", "Wardrobe")
	local look = SortScreen.guideLook()
	check("the guide: sparkles in the house's gold by default", look.kind == "Sparkles" and look.colour == Brand.TrailColours.House)
	check("the guide in the Salon shows at once", SortScreen.guideDelay() == 0)
	State.set("showTheWay", "After a moment")
	check("\"Show the way: After a moment\" waits a moment", SortScreen.guideDelay() == 1.2)
	State.set("showTheWay", "Never")
	check("\"Show the way: Never\" turns it off", SortScreen.guideDelay() == nil)
	State.set("showTheWay", "Always")
	State.set("trailColour", "Ice")
	check("the trail colour setting is used", SortScreen.guideLook().colour == Brand.TrailColours.Ice)
	serverSays("Shop", { op = "state", owned = { "trail_ruby" }, equipped = { trail = "trail_ruby" }, gilt = 0, goldKey = false, credits = {} })
	advance(0.1)
	check("a trail bought in the Boutique colours the guide", SortScreen.guideLook().colour == (Wardrobe.get("trail_ruby") :: any).style.colour)
	State.set("trail", "Case only")
	check("\"Trail: Case only\" draws no thread", (function()
		local layer = roblox.Instance.new("Frame")
		GuideTrail.attach(layer)
		GuideTrail.setLook(SortScreen.guideLook())
		GuideTrail.draw(0.1, Vector2.new(100, 100), Vector2.new(400, 500), 1, 1)
		local shown = 0
		for _, d in layer:GetChildren() do
			if d.Name == "Light" and d.Visible then
				shown += 1
			end
		end
		local arrowShown = layer.Arrow.Visible
		GuideTrail.attach(sortGui.Root.Trail)
		return shown == 0 and arrowShown
	end)())
	for _, kind in { "Ribbon", "Comet", "Runway" } do
		State.set("trail", kind)
		local layer = roblox.Instance.new("Frame")
		GuideTrail.attach(layer)
		GuideTrail.setLook(SortScreen.guideLook())
		local shown = 0
		for _ = 1, 10 do
			GuideTrail.tick(0.05, nil, nil, 1)
			GuideTrail.draw(0.05, Vector2.new(100, 100), Vector2.new(400, 500), 1, 1)
		end
		for _, d in layer:GetChildren() do
			if d.Name == "Light" and d.Visible then
				shown += 1
			end
		end
		check("\"Trail: " .. kind .. "\" draws its thread", shown >= 5, shown)
	end
	GuideTrail.attach(sortGui.Root.Trail)
	State.set("trail", "Sparkles")
	State.set("trailColour", "House")
	serverSays("Shop", { op = "state", owned = {}, equipped = {}, gilt = 0, goldKey = false, credits = {} })
	advance(0.1)
end
local filedBefore = sentOps("Table", "file")
check("A files it into the chosen case", pad(roblox.Enum.KeyCode.ButtonA))
advance(0.5)
check("the filing is sent", sentOps("Table", "file") == filedBefore + 1)
local lastFile
for _, s in sent do
	if s.remote == "Table" and s.message.op == "file" then
		lastFile = s.message
	end
end
serverSays("Table", { op = "filed", uid = lastFile.uid, case = lastFile.case, correct = false, points = 0, setBonus = 0, penalty = 0, score = 0, streak = 0, multiplier = 1, runLength = 0 })
advance(1)
-- File every piece correctly, via the pad, answering as the server would.
for _, p in deal do
	serverSays("Table", { op = "filed", uid = p.uid, case = p.case, correct = true, points = 10, setBonus = 0, penalty = 0, score = p.uid * 10, streak = p.uid, multiplier = 1, runLength = 1 })
	advance(0.2)
end
check("no errors while filing", #errors == 0, errors[1])
do
	-- Settings → Case style changes the cases at once, and they keep their counts.
	local State = module("StarterPlayer", "StarterPlayerScripts", "Client", "State")
	local function counts(): (number, string?, boolean)
		local total, style, seam = 0, nil, false
		for _, b in sortGui.Root.Cases:GetChildren() do
			total += tonumber(b.Count.Text) or 0
			style = b:GetAttribute("Style")
			seam = seam or b:FindFirstChild("Seam") ~= nil
		end
		return total, style, seam
	end
	advance(1)
	local before = counts()
	State.set("caseStyle", "Boxes")
	advance(0.2)
	local after, style, seam = counts()
	check("case style: boxes, with lids", style == "Boxes" and seam and #sortGui.Root.Cases:GetChildren() == 6, style)
	check("and the cases keep their counts", after == before and before > 0, after .. " vs " .. before)
	State.set("caseStyle", "Plates")
	advance(0.2)
	local _, plates = counts()
	check("case style: plates", plates == "Plates")
	State.set("caseStyle", "Trays")
	advance(0.2)
end
serverSays("Table", { op = "roundEnd", round = 1, room = "salon", mode = "room", score = 360, grade = "Polished", bestStreak = 8, bonus = { perfect = 0, streak = 40, time = 0 }, last = false })
advance(3)
check("the round panel offers the next round", textOnScreen("Next round") ~= nil)
check("and banking the run", textOnScreen("Bank the run") ~= nil)
press("Next round")
advance(0.5)
check("Next round is sent", sentOps("Table", "next") == 1)
serverSays("Table", { op = "deal", round = 2, room = "salon", mode = "room", cases = cases, pieces = pieceList(10, cases), score = 360 })
advance(2)
check("round II is dealt", #piecesFolder:GetChildren() == 10, #piecesFolder:GetChildren())

-- What a filing says back, with a mouse: drag a piece to a case and let go.
do
	local Sorting = Config.data.Sorting
	local round2 = pieceList(10, cases)
	local function clearVerdicts()
		advance(Sorting.verdictSeconds + 0.6)
	end

	-- A wrong case: piece 5 offered to a case that isn't its own.
	local wrongPiece = round2[5]
	local wrongCase = if wrongPiece.case == cases[1] then cases[2] else cases[1]
	local home = Sort.centre(Sort.card(5))
	local justMoved, settled, lit, pointerAt = Sort.drag(5, wrongCase)
	check("drag: the piece doesn't jump to the pointer, it travels there", (justMoved - pointerAt).Magnitude > 40, (justMoved - pointerAt).Magnitude)
	check("drag: and is under the pointer a moment later", (settled - pointerAt).Magnitude < 12, (settled - pointerAt).Magnitude)
	check("drag: the case under a held piece lights up", lit)
	advance(0.05)
	check("a wrong case says so: WRONG CASE", textOnScreen("WRONG CASE") ~= nil)
	snapshot("sort-wrong")
	check("and says try again", textOnScreen("Try again") ~= nil)
	check("and names the streak it cost", textOnScreen("Streak of 8 lost") ~= nil)
	local flash = Sort.bin(wrongCase).Flash.BackgroundColor3
	check("the wrong case flashes red", flash.R > flash.G * 1.5, flash)
	serverSays("Table", { op = "filed", uid = 5, case = wrongCase, correct = false, points = 0, setBonus = 0, penalty = 0, score = 360, streak = 0, multiplier = 1, runLength = 0 })
	advance(1)
	check("the piece goes back to its place on the tray", (Sort.centre(Sort.card(5)) - home).Magnitude < 3, (Sort.centre(Sort.card(5)) - home).Magnitude)
	check("the case goes dark again when you let go", Sort.bin(wrongCase):FindFirstChildOfClass("UIStroke").Thickness == 1)
	clearVerdicts()
	check("the message goes again", textOnScreen("WRONG CASE") == nil)

	-- Three right in a row: pieces 6, 7 and 8 into their own cases.
	local score = 360
	for n, uid in { 6, 7, 8 } do
		local p = round2[uid]
		local count = tonumber(Sort.bin(p.case).Count.Text)
		Sort.drag(uid, p.case)
		advance(0.05)
		check(string.format("a right case says so (%d): CORRECT", n), textOnScreen("CORRECT") ~= nil and textOnScreen("WRONG CASE") == nil)
		check(string.format("with the points it earned (%d)", n), find(playerGui, function(d)
			return d:IsA("TextLabel") and string.sub(d.Text, 1, 1) == "+"
		end) ~= nil)
		advance(0.6)
		check(string.format("the piece goes into its case and off the tray (%d)", n), Sort.card(uid) ~= nil and Sort.card(uid).Visible == false)
		check(string.format("the case counts it (%d)", n), tonumber(Sort.bin(p.case).Count.Text) == count + 1, Sort.bin(p.case).Count.Text)
		score += 20
		serverSays("Table", { op = "filed", uid = uid, case = p.case, correct = true, points = 20, setBonus = 0, penalty = 0, score = score, streak = n, multiplier = 1 + n // 2, runLength = 1 })
		if n == 3 then
			advance(0.3)
			check("three in a row is called out", textOnScreen("Now ×2") ~= nil)
			snapshot("sort-streak")
			check("the first-seating hint has gone after three right", find(playerGui, function(d)
				return d:IsA("TextLabel") and d.Name == "Hint" and d.TextTransparency < 1
			end) == nil)
		end
		clearVerdicts()
	end
	check("the header shows the score", textOnScreen(tostring(score)) ~= nil)
	advance(2)
	check("the streak call-out goes again", textOnScreen("Now ×2") == nil)
	check("no errors while sorting by hand", #errors == 0, errors[1])
	UserInputService.PreferredInput = EnumShim.PreferredInput.Gamepad
end

-- The music: the Salon's track, and its fuller layer rising with the run.
local SoundModule = module("StarterPlayer", "StarterPlayerScripts", "Client", "Sound")
local MusicRules = module("ReplicatedStorage", "Shared", "Music")
local function loopNamed(name)
	return find(game, function(d)
		return d:IsA("Sound") and d.Name == name
	end)
end
SoundModule.enterZone("salon")
advance(3)
local salonTrack, salonLayer = loopNamed("Music_salon"), loopNamed("Layer_salon")
check("music: the Salon plays its own track", salonTrack ~= nil and math.abs(salonTrack.Volume - Config.data.Music.level) < 1e-6, salonTrack and salonTrack.Volume)
check("music: the fuller layer sits at round II's intensity", salonLayer ~= nil and math.abs(salonLayer.Volume - Config.data.Music.level * MusicRules.intensity(2)) < 1e-6, salonLayer and salonLayer.Volume)
local piano = loopNamed("Piano")
check("music: the Foyer's music comes from the piano", piano ~= nil and piano.Parent and piano.Parent.Name == "Case" and piano.Parent.Parent.Name == "GrandPiano")
check("music: the piano isn't heard in the Salon", piano ~= nil and piano.Volume == 0, piano and piano.Volume)
SoundModule.enterZone("street")
advance(3)
check("music: the piano leaks, muffled, into the street", piano ~= nil and piano.Volume > 0 and piano:FindFirstChildOfClass("EqualizerSoundEffect").HighGain < 0)
check("music: the Salon falls quiet when you leave", salonTrack.Volume == 0 and salonLayer.Volume == 0)
SoundModule.enterZone("salon")
advance(3)

-- The sound bank: the house's sheet, a different take each time, a little drift.
do
	local Sheet = module("ReplicatedStorage", "Shared", "SoundSheet")
	local Wardrobe = module("ReplicatedStorage", "Shared", "Wardrobe")
	local assets = Config.data.Assets
	local function soundNamed(name)
		return find(game, function(d)
			return d:IsA("Sound") and d.Name == name
		end)
	end
	local function within(region, takes)
		for _, take in takes do
			if math.abs(region.Min - take[1]) < 1e-3 and math.abs(region.Max - take[2]) < 1e-3 then
				return true
			end
		end
		return false
	end
	local needed = { "pickup", "place", "drop", "deal", "slide", "hover", "wrong", "streakLost", "combo", "shimmer", "round", "complete", "low", "enter", "leave", "chair", "door", "click", "tick", "reward", "chime", "chime_harp", "chime_musicBox", "chime_celesta", "chime_glass" }
	local missing
	for _, name in needed do
		local takes = Sheet.cues[name]
		if not takes or #takes < 2 then
			missing = name
		end
	end
	check("the sound sheet holds every sound the house plays, in at least two takes", missing == nil, missing)
	local inOrder = true
	local last = 0
	for _, takes in Sheet.cues do
		for _, take in takes do
			if take[2] <= take[1] or take[2] > Sheet.length + 1e-6 then
				inOrder = false
			end
		end
	end
	check("every take lies inside the sheet", inOrder and Sheet.length > 0)

	check("without the sheet, the Boutique's chimes aren't sold", not Wardrobe.deliverable(Wardrobe.get("chime_harp")))
	SoundModule.play("chime", 0.5)
	local chime = soundNamed("chime")
	local fromLibrary = false
	for _, t in assets.LibrarySounds.chime do
		if chime and chime.SoundId == t.id then
			fromLibrary = true
		end
	end
	check("without the sheet, a real recording from Roblox's licensed library plays", fromLibrary and (chime:FindFirstChild("Soften") == nil or chime.Soften.Enabled == false), chime and chime.SoundId)
	local library = assets.LibrarySounds
	assets.LibrarySounds = {}
	SoundModule.play("chime", 0.5)
	check("and without that, a softened built-in stand-in", chime.SoundId == "rbxasset://sounds/electronicpingshort.wav" and chime:FindFirstChild("Soften") ~= nil and chime.Soften.Enabled == true)
	assets.LibrarySounds = library
	local everyCue = true
	for _, name in { "chime", "pickup", "place", "drop", "deal", "slide", "hover", "wrong", "streakLost", "combo", "shimmer", "round", "complete", "low", "enter", "leave", "chair", "click", "tick", "reward" } do
		local takes = library[name]
		if not takes or #takes == 0 then
			everyCue = false
		end
	end
	check("the library covers every sound the table makes", everyCue)
	assets.LibrarySounds = {}
	SoundModule.play("chime", 0.5)

	assets.SoundSheet = "rbxassetid://4242"
	SoundModule.play("pickup", 0.4)
	local s = soundNamed("pickup")
	local first = s and s.PlaybackRegion
	check("with the sheet set, a sound plays one of its takes", s ~= nil and s.SoundId == "rbxassetid://4242" and s.PlaybackRegionsEnabled == true and within(first, Sheet.cues.pickup))
	local repeated = false
	local previous = first.Min
	local speeds, volumes = {}, {}
	for _ = 1, 8 do
		SoundModule.play("pickup", 0.4)
		if s.PlaybackRegion.Min == previous then
			repeated = true
		end
		previous = s.PlaybackRegion.Min
		speeds[s.PlaybackSpeed] = true
		volumes[s.Volume] = true
	end
	check("never the same take twice running", not repeated)
	local function count(t)
		local n = 0
		for _ in t do
			n += 1
		end
		return n
	end
	check("each play drifts a little in pitch and in volume", count(speeds) > 3 and count(volumes) > 3)
	SoundModule.play("chime", 0.5, 1.5)
	check("the chime keeps its exact pitch (it climbs in steps)", math.abs(chime.PlaybackSpeed - 1.5) < 1e-9 and chime:FindFirstChild("Soften").Enabled == false, chime.PlaybackSpeed)
	assets.Sounds.wrong = "rbxassetid://99"
	SoundModule.play("wrong", 0.4)
	local w = soundNamed("wrong")
	check("a sound set by name replaces the sheet's takes", w.SoundId == "rbxassetid://99" and w.PlaybackRegionsEnabled == false)
	assets.Sounds.wrong = ""
	check("with the sheet set, the Boutique's chimes can be sold", Wardrobe.deliverable(Wardrobe.get("chime_harp")) and Wardrobe.deliverable(Wardrobe.get("chime_glass")))

	-- A room with no music of its own plays one of the house's tracks.
	assets.Tracks.table = "rbxassetid://777"
	SoundModule.enterZone("velvet")
	advance(3)
	local velvet = loopNamed("Music_velvet")
	check("music: a room with no track of its own plays the house's table track", velvet ~= nil and velvet.SoundId == "rbxassetid://777" and velvet.Volume > 0, velvet and velvet.SoundId)
	SoundModule.enterZone("salon")
	advance(3)
	check("music: and a room's own track still wins", salonTrack.SoundId == "rbxassetid://101" and salonTrack.Volume > 0 and velvet.Volume == 0)
	assets.Tracks.table = ""
	-- With nothing set, the house's playlist: real recordings from Roblox's licensed library.
	local tableList = assets.Playlists.table
	local function songIndex(id)
		for i, song in tableList do
			if song.id == id then
				return i
			end
		end
		return nil
	end
	SoundModule.enterZone("velvet")
	advance(3)
	velvet = loopNamed("Music_velvet")
	local at = velvet and songIndex(velvet.SoundId)
	check("music: with nothing to upload, a room plays the house's playlist", at ~= nil and velvet.Looped == false and velvet.Volume > 0, velvet and velvet.SoundId)
	-- The room's level, before each song's own gain.
	local roomLevel = velvet.Volume / tableList[at].gain
	signalOf(velvet, "Ended"):Fire()
	advance(Config.data.Music.gap + 0.2)
	local nextAt = songIndex(velvet.SoundId)
	check("music: when a song ends, the next in the list follows at its own level", nextAt == at % #tableList + 1 and math.abs(velvet.Volume - roomLevel * tableList[nextAt].gain) < 1e-6, velvet.SoundId)
	local wellFormed = true
	for _, track in { "lounge", "table", "ballroom" } do
		local list = assets.Playlists[track]
		if #list < 5 then
			wellFormed = false
		end
		for _, song in list do
			if not string.match(song.id, "^rbxassetid://%d+$") or song.gain < 0.5 or song.gain > 2 then
				wellFormed = false
			end
		end
	end
	check("music: three playlists of at least five songs, each with its level", wellFormed)
	check("and the house knows it has music without a single upload", SoundModule.hasMusic())
	-- Or found by name, if a playlist is emptied: a track dropped into SoundService, no id copied.
	assets.Playlists.table = {}
	SoundModule.enterZone("salon")
	advance(3)
	local uploaded = Instance.new("Sound")
	uploaded.Name = "maison-table"
	uploaded.SoundId = "rbxassetid://888"
	uploaded.Parent = game:GetService("SoundService")
	advance(6)
	SoundModule.enterZone("velvet")
	advance(3)
	local found = loopNamed("Music_velvet")
	check("music: a track dropped into SoundService by name plays, no id needed", found ~= nil and found.SoundId == "rbxassetid://888" and found.Volume > 0, found and found.SoundId)
	check("and the house knows it has music", SoundModule.hasMusic())
	uploaded:Destroy()
	assets.Playlists.table = tableList
	advance(6)
	SoundModule.enterZone("salon")
	advance(3)
	assets.SoundSheet = ""
	assets.LibrarySounds = library
	check("no errors in the sound bank", #errors == 0, errors[1])
end

-- With a mouse: press on a piece, drag it over its case, let go.
do
	local first = pieceList(10, cases)[1]
	local filesBefore = sentOps("Table", "file")
	local liftsBeforeDrag = sentOps("Table", "lift")
	Sort.drag(1, first.case)
	advance(0.5)
	local dropped
	for _, sent_ in sent do
		if sent_.remote == "Table" and sent_.message.op == "file" then
			dropped = sent_.message
		end
	end
	check("a mouse drag lifts the piece", sentOps("Table", "lift") > liftsBeforeDrag)
	check("letting go over its case files it", sentOps("Table", "file") == filesBefore + 1 and dropped.uid == 1 and dropped.case == first.case, dropped and string.format("uid %s case %s want %s", tostring(dropped.uid), dropped.case, first.case))
end
UserInputService.PreferredInput = EnumShim.PreferredInput.Gamepad
serverSays("Table", { op = "banked", score = 360, grade = "Polished", rounds = 1, accuracy = 0.9, gilt = 12, best = 360, newBest = true })
advance(2)
check("the banked card offers another run", textOnScreen("Another run") ~= nil)
advance(1.5)
snapshot("banked")
check("the tally lands row by row and counts up to what you earned", textOnScreen("90%") ~= nil and textOnScreen("A new best") ~= nil and find(playerGui, function(d)
	return d:IsA("TextLabel") and d.Text == "+12" and d.TextTransparency == 0
end) ~= nil)
check("no errors through a whole run", #errors == 0, errors[1])

-- The rival's plate appears at the table when the house has picked one.
serverSays("Guest", { op = "rival", rival = { name = "Ben", fact = "40 points ahead of you on tonight's table.", ahead = false } })
advance(0.5)
local rivalPlate = find(workspace, function(d)
	return d.Name == "RivalPlate"
end)
check("the rival's plate is on the table", rivalPlate ~= nil)
serverSays("Guest", { op = "rival", rival = { name = "Ben", fact = "5 points behind you on tonight's table.", ahead = true } })
advance(1.5)
check("no errors turning the plate", #errors == 0, errors[1])

serverSays("Table", { op = "left", summary = { score = 360, grade = "Polished" } })
local fovAtLeave = camera.FieldOfView
advance(2)
check("leaving hands the camera back", camera.CameraType == roblox.Enum.CameraType.Custom)
check("leaving: the field of view eases back out (no snap)", fovAtLeave == Config.data.Sorting.cameraFov and camera.FieldOfView == 70, string.format("%s -> %s", tostring(fovAtLeave), tostring(camera.FieldOfView)))
check("leaving: the sorting screen closes, through black, back to the room", sortGui.Enabled == false and sortGui.Curtain.BackgroundTransparency == 1)
check("leaving gives the controls back", controls.enabled == true)
check("the tray is cleared", #piecesFolder:GetChildren() == 0)
check("standing up: what's next is tonight's table", textOnScreen("Tonight's table is laid") ~= nil)
check("with a key that takes you there", textOnScreen("Take me there") ~= nil)
check("the rival's plate goes with the table", find(workspace, function(d)
	return d.Name == "RivalPlate"
end) == nil)

---------------------------------------------------------------------------------------------------
-- 5. The Nightly card
---------------------------------------------------------------------------------------------------
-- Wearing a table style and a lamp from the Boutique: the sorting screen takes them on.
serverSays("Shop", { op = "state", owned = { "table_oxblood", "lamp_moon" }, equipped = { table = "table_oxblood", lamp = "lamp_moon" }, gilt = 0, goldKey = false, credits = {} })
advance(0.1)
serverSays("Table", { op = "seated", table = salonTable:GetAttribute("TableId"), room = "velvet", mode = "nightly" })
advance(1.5)
serverSays("Table", { op = "deal", round = 1, room = "velvet", mode = "nightly", cases = cases, pieces = pieceList(10, cases), score = 0, clock = { left = 30, running = true, budget = 30 } })
advance(3)
do
	local Wardrobe = module("ReplicatedStorage", "Shared", "Wardrobe")
	local cloth = sortGui.Root.Tray:FindFirstChildOfClass("UIGradient").Color.Keypoints[2].Value
	check("a bought felt colours the cloth on the sorting screen", cloth.R > cloth.G * 2 and cloth.R > cloth.B * 1.5, cloth)
	check("a bought lamp colours its lamplight", sortGui.Root.Lamp.BackgroundColor3 == (Wardrobe.get("lamp_moon") :: any).style.colour)
	check("and the felt's rims edge the cases", sortGui.Root.Cases:GetChildren()[1]:FindFirstChildOfClass("UIStroke").Color == (Wardrobe.get("table_oxblood") :: any).style.rim)
end
check("tonight's table says which room's rules it plays by", textOnScreen("Tonight's table · The Velvet Room") ~= nil)
serverSays("Shop", { op = "state", owned = {}, equipped = {}, gilt = 0, goldKey = false, credits = {} })
check("a timed deal shows the clock: a draining gold rail and the seconds", sortGui.Root.Clock.Visible == true and sortGui.Root.Clock.Fill.Size.X.Scale > 0 and textOnScreen("0:") ~= nil)
serverSays("Table", { op = "nightlyCard", key = "2026-09-29", room = "velvet", score = 4210, grade = "Immaculate", rounds = { "Flawless", "Immaculate", "", "", "" }, scored = true, gilt = 120, rank = 12, total = 300, percentile = 4, connections = { place = 2, of = 5 } })
advance(2)
check("the Nightly card shows the score", textOnScreen("4,210") ~= nil)
snapshot("nightly")
check("with Share and Invite", textOnScreen("Share") ~= nil and textOnScreen("Invite") ~= nil)
press("Invite")
check("Invite opens Roblox's invite prompt", shared.invites == 1)
press("Leave")
advance(0.5)
serverSays("Table", { op = "left" })
advance(2)
check("no errors through the Nightly", #errors == 0, errors[1])
check("after tonight's table, what's next is the Midnight Room", textOnScreen("Reach round IV in the Obsidian Room") ~= nil and textOnScreen("Tonight's table is laid") == nil)

---------------------------------------------------------------------------------------------------
-- 6. The Library: a whole Tête-à-Tête on screen
---------------------------------------------------------------------------------------------------
local ownHalf, rivalHalf
for _, half in CollectionService:GetTagged("DuelHalf") do
	if half:GetAttribute("Duel") == "library-1" then
		if half:GetAttribute("Side") == "a" then
			ownHalf = half
		else
			rivalHalf = half
		end
	end
end
check("the Library's first table has two halves", ownHalf ~= nil and rivalHalf ~= nil)
serverSays("Table", { op = "seated", table = ownHalf:GetAttribute("TableId"), room = "library", mode = "duel" })
serverSays("Table", { op = "duelWaiting" })
advance(1.5)
check("waiting: Invite a friend is offered", textOnScreen("Invite a friend") ~= nil)
check("waiting: the empty chair says so", find(workspace, function(d)
	return d:IsA("TextLabel") and d.Text == "Waiting for a guest opposite"
end) ~= nil)
press("Invite a friend")
check("inviting keeps the chair", sentOps("Table", "inviting") == 1 and shared.invites == 2)
serverSays("Table", { op = "duelStart", side = "a", rival = "Ben", ranked = true, standIn = false, eligible = true })
advance(1)
check("start: the invite key goes", textOnScreen("Invite a friend") == nil)
local duelCases = { Catalogue.Cases[1].id, Catalogue.Cases[2].id, Catalogue.Cases[3].id, Catalogue.Cases[4].id }
local hand = pieceList(14, duelCases)
serverSays("Table", { op = "deal", mode = "duel", room = "library", side = "a", round = 1, cases = duelCases, pieces = hand, score = 14, wins = { a = 0, b = 0 }, clock = { left = 60, running = true, budget = 60 } })
local rivalHand = {}
for i, p in hand do
	local q = table.clone(p)
	q.uid = 100 + i
	table.insert(rivalHand, q)
end
serverSays("Table", { op = "rivalDeal", side = "b", cases = duelCases, pieces = rivalHand })
advance(2)
check("the hand is on your felt", #piecesFolder:GetChildren() == 14, #piecesFolder:GetChildren())
local duelFolder = workspace.MaisonLocal:FindFirstChild("Duel")
check("the rival's felt is shown", duelFolder ~= nil and #duelFolder:GetChildren() >= 14, duelFolder and #duelFolder:GetChildren())
-- A wrong case: the fumble stops the next lift for a moment.
pad(roblox.Enum.KeyCode.ButtonA)
advance(0.2)
pad(roblox.Enum.KeyCode.ButtonA)
advance(0.1)
local fileMsg
for _, s in sent do
	if s.remote == "Table" and s.message.op == "file" then
		fileMsg = s.message
	end
end
local liftsBefore = sentOps("Table", "lift")
serverSays("Table", { op = "filed", uid = fileMsg.uid, case = fileMsg.case, correct = false, points = 0, setBonus = 0, penalty = 0, score = 14, streak = 0, multiplier = 1, runLength = 0, remaining = 14, fumble = 0.8 })
pad(roblox.Enum.KeyCode.ButtonA)
advance(0.2)
check("a fumble stops the hand from lifting", sentOps("Table", "lift") == liftsBefore)
advance(1)
pad(roblox.Enum.KeyCode.ButtonA)
advance(0.2)
check("after the fumble the hand lifts again", sentOps("Table", "lift") == liftsBefore + 1)
pad(roblox.Enum.KeyCode.ButtonB)
-- The rival files; a parcel comes our way and opens on our felt.
serverSays("Table", { op = "rivalFiled", uid = 101, case = hand[1].case, correct = true, remaining = 13 })
serverSays("Table", { op = "parcel", from = "b", to = "a", id = 1, count = 2, fuse = 2 })
advance(1)
check("the parcel is on its way", find(duelFolder, function(d)
	return d.Name == "Parcel"
end) ~= nil)
serverSays("Table", { op = "parcel", from = "b", to = "a", id = 2, count = 1, fuse = 2 })
serverSays("Table", { op = "parcelShrink", side = "a", id = 1, count = 1 })
serverSays("Table", { op = "parcelCancel", side = "a", id = 2 })
advance(1.2)
serverSays("Table", {
	op = "parcelOpen",
	side = "a",
	id = 1,
	remaining = 15,
	pieces = { { uid = 50, id = hand[1].id, name = hand[1].name, case = hand[1].case, value = 10, rare = false, seasonal = false, mythic = false } },
})
advance(1)
check("the parcel's pieces land on your felt", #piecesFolder:GetChildren() == 15, #piecesFolder:GetChildren())
-- A parcel on the rival's felt too.
serverSays("Table", { op = "parcel", from = "a", to = "b", id = 3, count = 1, fuse = 2 })
advance(2)
serverSays("Table", { op = "parcelOpen", side = "b", id = 3, remaining = 14, pieces = { { uid = 150, id = hand[2].id, name = hand[2].name, case = hand[2].case, value = 10, rare = false, seasonal = false, mythic = false } } })
advance(1)
check("no errors through parcels", #errors == 0, errors[1])
-- The rival's connection drops, then returns.
serverSays("Table", { op = "rivalAway", seconds = 20, name = "Ben" })
advance(1)
check("the house says the rival's chair is held", textOnScreen("connection dropped") ~= nil)
serverSays("Table", { op = "rivalBack", name = "Ben" })
advance(4)
serverSays("Table", { op = "handEnd", winner = "a", wins = { a = 1, b = 0 }, hand = 1 })
advance(2)
check("the hand clears", #piecesFolder:GetChildren() == 0, #piecesFolder:GetChildren())
check("the hand card lands", find(workspace, function(d)
	return d:IsA("TextLabel") and d.Text == "Hand to you"
end) ~= nil)
serverSays("Table", { op = "duelEnd", won = true, wins = { a = 3, b = 1 }, reason = "won", ranked = true, standIn = false, rival = "Ben", before = 1500, after = 1523, placementLeft = 4, gilt = 60 })
advance(2)
check("the result card: the table is yours", textOnScreen("The table is yours") ~= nil)
snapshot("duel-result")
check("the result card shows the hands and the rating", textOnScreen("3 – 1") ~= nil and textOnScreen("1523") ~= nil)
check("placement is explained", textOnScreen("4 more before your Mark is shown") ~= nil)
press("Another")
check("Another is sent", sentOps("Table", "again") >= 1)
serverSays("Table", { op = "rematchAsked", by = "Ben" })
advance(1)
-- Shown across to another table by the queue.
serverSays("Table", { op = "left", moving = true })
serverSays("Table", { op = "seated", table = rivalHalf:GetAttribute("TableId"), room = "library", mode = "duel" })
advance(2)
check("moving tables keeps the controls off", controls.enabled == false)
serverSays("Table", { op = "left" })
advance(2)
check("leaving the Library gives the controls back", controls.enabled == true)
check("no errors through a whole Tête-à-Tête", #errors == 0, errors[1])

---------------------------------------------------------------------------------------------------
-- 6b. The Ballroom: a Lights Out evening on screen
---------------------------------------------------------------------------------------------------
local ballroomTable
for _, m in CollectionService:GetTagged("BallroomTable") do
	if m:GetAttribute("Seat") == 3 then
		ballroomTable = m
	end
end
check("the Ballroom's table 3 exists", ballroomTable ~= nil)
UserInputService.PreferredInput = EnumShim.PreferredInput.Gamepad
serverSays("Table", { op = "seated", table = ballroomTable:GetAttribute("TableId"), room = "ballroom", mode = "ballroom", seat = 3 })
serverSays("Table", { op = "gathering", startsIn = 30 })
advance(2)
check("Ballroom: seated at the table", controls.enabled == false and camera.CameraType == roblox.Enum.CameraType.Scriptable)
check("Ballroom: the gathering is announced", textOnScreen("The evening begins in 30 seconds") ~= nil)
local names = {}
for i = 1, 20 do
	names[tostring(i)] = { name = if i == 3 then "Ada" else "Stand-in", standIn = i ~= 3 }
end
serverSays("Table", { op = "eveningStart", seat = 3, names = names, capacity = 16, tab = "random", counted = false, real = 1 })
local opening = pieceList(6, cases)
serverSays("Table", { op = "deal", mode = "ballroom", room = "ballroom", round = 1, cases = cases, pieces = opening, score = 6 })
advance(2)
check("Ballroom: six pieces on the felt", #piecesFolder:GetChildren() == 6, #piecesFolder:GetChildren())
check("Ballroom: the four tabs are shown", textOnScreen("Nearly out") ~= nil and textOnScreen("Leader") ~= nil)
check("Ballroom: the status line counts the felt", textOnScreen("felt 6 of 16") ~= nil)
-- Arrivals from the dumbwaiter.
for i = 1, 3 do
	serverSays("Table", { op = "arrive", pieces = { { uid = 200 + i, id = opening[i].id, name = opening[i].name, case = opening[i].case, value = 10, rare = false, seasonal = false, mythic = false } }, remaining = 6 + i })
	advance(0.5)
end
check("Ballroom: arrivals land on the felt", #piecesFolder:GetChildren() == 9, #piecesFolder:GetChildren())
-- The shoulder button moves the tab.
check("Ballroom: R1 moves to the next tab", pad(roblox.Enum.KeyCode.ButtonR1))
local tabMsg
for _, sm in sent do
	if sm.remote == "Table" and sm.message.op == "tab" then
		tabMsg = sm.message
	end
end
check("Ballroom: the new tab is sent", tabMsg ~= nil and tabMsg.tab == "rivals", tabMsg and tabMsg.tab)
check("Ballroom: pressing a tab sends it", press("Leader") and (function()
	local lastTab
	for _, sm in sent do
		if sm.remote == "Table" and sm.message.op == "tab" then
			lastTab = sm.message.tab
		end
	end
	return lastTab == "leader"
end)())
-- File one with the pad.
local ballFiles = sentOps("Table", "file")
pad(roblox.Enum.KeyCode.ButtonA)
advance(0.3)
pad(roblox.Enum.KeyCode.ButtonA)
advance(0.3)
check("Ballroom: filing works as at any table", sentOps("Table", "file") == ballFiles + 1)
-- A parcel on its way to us, then open on the felt; one of ours cancelled.
serverSays("Table", { op = "parcel", from = 7, to = 3, id = 11, count = 2, fuse = 2.5 })
serverSays("Table", { op = "parcel", from = 3, to = 9, id = 12, count = 1, fuse = 2.5 })
advance(1)
local ballFolder = workspace.MaisonLocal:FindFirstChild("Ballroom")
check("Ballroom: parcels fly between tables", ballFolder ~= nil and #ballFolder:GetChildren() == 2, ballFolder and #ballFolder:GetChildren())
serverSays("Table", { op = "parcelShrink", seat = 3, id = 11, count = 1 })
serverSays("Table", { op = "parcelLanded", seat = 9, id = 12, count = 1, felt = 12 })
advance(1.6)
serverSays("Table", { op = "parcelOpen", side = "mine", seat = 3, id = 11, pieces = { { uid = 300, id = opening[2].id, name = opening[2].name, case = opening[2].case, value = 10, rare = false, seasonal = false, mythic = false } }, remaining = 9 })
advance(1)
-- (The filed piece stays in its case, so the folder holds ten.)
check("Ballroom: a parcel's pieces spill onto the felt", #piecesFolder:GetChildren() == 10, #piecesFolder:GetChildren())
-- Over sixteen: the rail counts three seconds.
serverSays("Table", { op = "flicker", on = true, seconds = 3 })
advance(0.5)
check("Ballroom: over sixteen shows the clock", sortGui.Root.Clock.Visible == true)
serverSays("Table", { op = "flicker", on = false })
ballroomTable:SetAttribute("Flicker", true)
advance(0.5)
ballroomTable:SetAttribute("Flicker", false)
ballroomTable:SetAttribute("KeyLeader", true)
advance(0.5)
check("Ballroom: the Key leader glints", find(ballroomTable, function(d)
	return d.Name == "KeyGlint"
end) ~= nil)
serverSays("Table", { op = "lampOut", seat = 9, place = 20, by = 3, byName = "Ada", keys = 1, leader = 3, alive = 19 })
advance(0.5)
check("Ballroom: a Key when your parcel puts a lamp out", textOnScreen("Table 9's lamp went out on your parcel") ~= nil)
SoundModule.enterZone("ballroom")
advance(3)
check("music: the whole band while the room is lit", loopNamed("Band_full") and loopNamed("Band_full").Volume > 0 and (loopNamed("Band_piano") == nil or loopNamed("Band_piano").Volume == 0))
serverSays("Table", { op = "lampOut", seat = 5, place = 10, by = 0, keys = 1, leader = 3, alive = 10 })
advance(3)
check("music: bass and brushes at ten", loopNamed("Band_bass").Volume > 0 and loopNamed("Band_full").Volume == 0)
serverSays("Table", { op = "lampOut", seat = 6, place = 3, by = 0, keys = 1, leader = 3, alive = 2 })
advance(3)
check("music: a piano and a ticking clock for the final two", loopNamed("Band_piano").Volume > 0 and loopNamed("Band_clock").Volume > 0 and loopNamed("Band_bass").Volume == 0)
serverSays("Table", { op = "closingTime" })
serverSays("Table", { op = "cases", cases = { cases[1], cases[2], cases[3], cases[4], Catalogue.Cases[5].id, Catalogue.Cases[6].id } })
advance(1)
check("Ballroom: Closing Time is announced", textOnScreen("Closing Time") ~= nil)
-- Our lamp goes out.
serverSays("Table", { op = "out", place = 4, keys = 1, by = "Ben", reason = "over", of = 20 })
advance(1.5)
check("Ballroom: the out card lands", textOnScreen("Your lamp is out") ~= nil and textOnScreen("4th of 20") ~= nil)
snapshot("ballroom-out")
check("Ballroom: the felt clears", #piecesFolder:GetChildren() == 0)
press("Stay for the next evening")
press("Next evening")
advance(0.5)
serverSays("Table", { op = "eveningEnd", winner = 12, winnerName = "Ben", keys = 5, seconds = 300, counted = false, results = {} })
advance(3)
check("Ballroom: the camera finds the last lamp from the Gallery", camera.CFrame.Position.Y > 35, camera.CFrame.Position.Y)
serverSays("Table", { op = "eveningResult", place = 4, of = 20, keys = 1, points = 53, gilt = 40, counted = false, won = false })
advance(8)
check("Ballroom: the result card", textOnScreen("4th of 20") ~= nil and textOnScreen("not counted for records") ~= nil)
check("Ballroom: the camera is back at the table", camera.CFrame.Position.Y < 35)
press("Watch from the Gallery")
check("Ballroom: to the Gallery is sent", sentOps("Table", "gallery") == 1)
serverSays("Table", { op = "left" })
advance(2)
check("Ballroom: leaving gives the controls back", controls.enabled == true)
check("no errors through a Lights Out evening", #errors == 0, errors[1])
-- Standing in the Ballroom without a chair: Next evening and Watch.
root.Position = Vector3.new(61, 21, 90)
root.CFrame = CFrame.new(61, 21, 90)
advance(1)
check("in the Ballroom without a chair: Next evening is offered", textOnScreen("Next evening") ~= nil)
check("and Watch", press("Watch"))
advance(7)
check("watching drifts the camera", camera.CameraType == roblox.Enum.CameraType.Scriptable)
press("Next evening")
check("Next evening is sent", sentOps("Table", "nextEvening") == 1)
root.Position = Vector3.new(0, 5, -40)
root.CFrame = CFrame.new(0, 5, -40)
advance(1)
check("leaving the Ballroom drops its keys and the camera", textOnScreen("Next evening") == nil and camera.CameraType == roblox.Enum.CameraType.Custom)
check("no errors in the Ballroom", #errors == 0, errors[1])

---------------------------------------------------------------------------------------------------
-- 7. The panels
---------------------------------------------------------------------------------------------------
UserInputService.PreferredInput = EnumShim.PreferredInput.KeyboardAndMouse
check("Settings opens", press("Settings"))
advance(1)
snapshot("settings")
check("no errors in Settings", #errors == 0, errors[1])
local Root = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Root")
Root.close()
advance(1)
invokeResults.GetBoard = {
	["nightly:tonight"] = { entries = { { userId = 1, name = "Ada", score = 4210 }, { userId = 2, name = "Ben", score = 3900 } }, available = true, count = 2 },
	["library:all"] = { entries = { { userId = 2, name = "Ben", score = 1540 } }, available = true },
}
local BoardPanel = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "BoardPanel")
BoardPanel.open()
advance(1)
check("the leaderboard shows tonight's names", textOnScreen("Ben") ~= nil)
snapshot("board")
check("the Library tab is there", press("Library"))
advance(0.5)
check("the Library board shows ratings", textOnScreen("1540") ~= nil)
Root.close()
advance(1)
local HowToPlay = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "HowToPlay")
HowToPlay.open()
advance(1)
check("how to play opens", textOnScreen("Pick one up") ~= nil)
snapshot("howto")
Root.close()
advance(1)
serverSays("Guest", { op = "inviteLibrary" })
check("the Concierge's invite opens the prompt", shared.invites == 3)
check("no errors in the panels", #errors == 0, errors[1])

---------------------------------------------------------------------------------------------------
-- 7b. The Boutique, the Wardrobe, the Ledger and a gift
---------------------------------------------------------------------------------------------------
local oxblood = { id = "table_oxblood", name = "Oxblood Felt", kind = "table", kindName = "Table styles", line = "Deep red felt.", robux = 249, owned = false, style = {} }
local ledgerView = { term = "2026-autumn", points = 2100, page = 2, pages = 50, progress = 0.1, leather = false, nextFree = { "100 Gilt" }, nextLeather = { "x", "y" }, nextPage = 3 }
invokeResults.ShopAsk = {
	today = { oxblood }, featured = {}, season = { id = "harvest", name = "Harvest Nights", price = 599, pieces = {} },
	gilt = {}, goldKey = { owned = false, price = 499 }, ledger = { view = ledgerView, price = 399 },
	introduction = nil, guests = { { userId = 2, name = "Ben" } }, standing = "Guest", balance = 0, credits = {},
	ok = true, prompted = true,
}
serverSays("Shop", { op = "state", owned = {}, equipped = {}, gilt = 1200, goldKey = false, credits = {}, ledger = { page = 2, pages = 50, progress = 0.1, leather = false, term = "2026-autumn" } })
serverSays("Shop", { op = "open", panel = "boutique" })
advance(1)
check("the Boutique opens from the counter", textOnScreen("The Boutique") ~= nil)
snapshot("boutique")
check("today's piece is on the shelf with its live price", textOnScreen("Oxblood Felt") ~= nil and textOnScreen("249") ~= nil)
check("the Gilt balance shows", textOnScreen("1,200 Gilt") ~= nil)
check("Buy asks the server", press("Buy · " .. utf8.char(0xE002) .. " 249") and (function()
	for _, sm in sent do
		if sm.remote == "ShopAsk" and sm.message[1] and sm.message[1].op == "buy" then
			return true
		end
	end
	return false
end)())
check("Gift lists the guests", press("Gift") and textOnScreen("Ben") ~= nil)
press("Not now")
advance(0.5)
check("the Gold Key tab", press("The Gold Key") and textOnScreen("+20% on all Gilt") ~= nil)
check("the Ledger tab", press("The Ledger") and textOnScreen("Page 2 of 50") ~= nil)
local Root2 = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Root")
Root2.close()
advance(1)
invokeResults.ShopAsk = { kinds = { table = { oxblood } }, equipped = { table = "" }, names = {} }
serverSays("Shop", { op = "open", panel = "wardrobe" })
advance(1)
check("the Wardrobe lists what you own", textOnScreen("The Wardrobe") ~= nil and textOnScreen("Oxblood Felt") ~= nil)
snapshot("wardrobe")
Root2.close()
advance(1)
invokeResults.ShopAsk = ledgerView
serverSays("Shop", { op = "open", panel = "ledger" })
advance(1)
check("the Ledger opens as a book", textOnScreen("Page 2") ~= nil and textOnScreen("100 Gilt") ~= nil)
snapshot("ledger")
Root2.close()
advance(1)
serverSays("Shop", { op = "gift", from = "Ben", item = oxblood })
advance(3.5)
check("a gift arrives wrapped", textOnScreen("From Ben") ~= nil)
press("Open it")
advance(1)
check("opening it shows what it is", textOnScreen("Oxblood Felt") ~= nil)
press("Later")
serverSays("Shop", { op = "pages", pages = { 3 } })
advance(0.5)
check("a page turning is announced", textOnScreen("Page 3 turned") ~= nil)
check("no errors in the Boutique", #errors == 0, errors[1])

-- The Register and the Vault.
local catalogueForTest = module("ReplicatedStorage", "Shared", "Catalogue")
local firstCore = catalogueForTest.coreForCase(catalogueForTest.Cases[1].id)[1]
invokeResults.ShopAsk = {
	register = { [firstCore.id] = { first = 1790000000, count = 7, best = "velvet" } },
	mythics = { { id = "blackDiamond", serial = 412, at = 1790000000, room = "midnight" } },
	standing = "Member", next = { name = "Patron", nights = 14, rounds = 150 }, nights = 5, rounds = 40,
	commissions = { { label = "This evening", text = "File twelve pieces of watches in the Velvet Room", progress = 4, target = 12, done = false, gilt = 150 } },
	odds = { { room = "The Salon", chance = 40000 } }, badges = 3, total = 62,
}
serverSays("Shop", { op = "open", panel = "register" })
advance(1)
check("the Register opens with your standing", textOnScreen("Member") ~= nil and textOnScreen("File twelve pieces") ~= nil)
snapshot("register")
check("a case page shows the found piece in 3D", press(catalogueForTest.Cases[1].name) and textOnScreen(firstCore.name) ~= nil and find(playerGui, function(d)
	return d:IsA("ViewportFrame")
end) ~= nil)
check("the Mythics page prints the odds and the serial", press("Mythics") and textOnScreen("1 in 40,000") ~= nil and textOnScreen("No. 00412") ~= nil)
advance(1)
Root2.close()
advance(1)
root.Position = Vector3.new(-8, 5, 50)
root.CFrame = CFrame.new(-8, 5, 50)
advance(1.5)
local vaultFolder = workspace.MaisonLocal:FindFirstChild("Vault")
check("walking into the Vault fills its cabinets with your finds", vaultFolder ~= nil and #vaultFolder:GetChildren() == 2, vaultFolder and #vaultFolder:GetChildren())
root.Position = Vector3.new(0, 5, -40)
root.CFrame = CFrame.new(0, 5, -40)
advance(1.5)
check("and empties them when you leave", workspace.MaisonLocal:FindFirstChild("Vault") == nil)
check("no errors in the Register and the Vault", #errors == 0, errors[1])

-- The Suite: your own furniture, drawn only for you; the Gold Key rooms; nobody else in it.
serverSays("Shop", { op = "state", owned = { "suite_rug_black" }, equipped = {}, gilt = 800, goldKey = false, credits = {}, suite = { rug = "suite_rug_black" }, ledger = { page = 2, pages = 50, progress = 0.1, leather = false, term = "2026-autumn" } })
advance(0.5)
local SuiteLayout = module("ReplicatedStorage", "Shared", "Layout").Suite
root.Position = SuiteLayout.arrival + Vector3.new(0, 3, 0)
root.CFrame = CFrame.new(SuiteLayout.arrival + Vector3.new(0, 3, 0))
advance(1)
local suiteFolder = workspace.MaisonLocal:FindFirstChild("Suite")
check("walking into the Suite draws your furniture", suiteFolder ~= nil and suiteFolder:FindFirstChild("rug") ~= nil and suiteFolder:FindFirstChild("sofa") ~= nil)
check("the house's own pieces fill the spots you haven't", suiteFolder ~= nil and #suiteFolder:GetChildren() == 4, suiteFolder and #suiteFolder:GetChildren())
local alcove = CollectionService:GetTagged("SuiteAlcove")[1]
check("without the Gold Key its rooms stay shut", alcove ~= nil and alcove.CanCollide == true)
serverSays("Shop", { op = "state", owned = { "suite_rug_black", "suite_mirror_gilt" }, equipped = {}, gilt = 800, goldKey = true, credits = {}, suite = { rug = "suite_rug_black", mirror = "suite_mirror_gilt" }, ledger = { page = 2, pages = 50, progress = 0.1, leather = false, term = "2026-autumn" } })
advance(0.5)
suiteFolder = workspace.MaisonLocal:FindFirstChild("Suite")
check("with the Gold Key its rooms open", alcove.CanCollide == false and alcove.LocalTransparencyModifier == 1)
check("and the Dressing Room's glass stands", suiteFolder ~= nil and suiteFolder:FindFirstChild("mirror") ~= nil)
invokeResults.ShopAsk = {
	rooms = { main = "The Suite", dressing = "The Dressing Room", study = "The Study" },
	spots = {
		{
			id = "rug",
			name = "The rug",
			room = "main",
			open = true,
			house = true,
			placed = "suite_rug_black",
			options = {
				{ id = "suite_rug_black", name = "Black Fringed Rug", owned = true, source = "gilt", gilt = 400 },
				{ id = "suite_rug_persian", name = "Night Garden Rug", owned = false, source = "gilt", gilt = 800 },
				{ id = "suite_rug_moon", name = "Moonlit Rug", owned = false, source = "boutique", robux = 149, onSale = true },
			},
		},
		{ id = "desk", name = "The Study: the desk", room = "study", open = false, house = false, placed = "", options = {} },
	},
	gilt = 1200,
	goldKey = false,
}
serverSays("Shop", { op = "open", panel = "suite" })
advance(1)
check("the bell opens the Suite's furnishing", textOnScreen("Your Suite") ~= nil and textOnScreen("Black Fringed Rug") ~= nil)
snapshot("suite")
check("the Suite says what it is", textOnScreen("Your own rooms upstairs") ~= nil and textOnScreen("nothing here changes a score") ~= nil)
check("and how it works, in three steps", textOnScreen("How it works") ~= nil and textOnScreen("Get a piece") ~= nil and textOnScreen("The Gold Key adds two rooms") ~= nil)
check("how far along you are", textOnScreen("Your pieces in 1 of 1 spots") ~= nil and textOnScreen("1,200 Gilt") ~= nil)
check("a piece for Gilt can be bought right there", textOnScreen("Night Garden Rug") ~= nil and textOnScreen("800 Gilt") ~= nil)
check("a Robux piece on the shelves today, too", textOnScreen("Moonlit Rug") ~= nil and textOnScreen("149 Robux") ~= nil)
check("a Gold Key room says what it holds and how to get it", textOnScreen("Comes with the Gold Key") ~= nil and textOnScreen("A partners' desk and a globe") ~= nil and textOnScreen("See the Gold Key") ~= nil)
invokeResults.ShopAsk = { ok = true }
local placeBefore = 0
for _, sm in sent do
	if sm.remote == "ShopAsk" and sm.message[1] and sm.message[1].op == "place" then
		placeBefore += 1
	end
end
check("› chooses the next piece", press("›"))
advance(0.5)
local lastPlace
for _, sm in sent do
	if sm.remote == "ShopAsk" and sm.message[1] and sm.message[1].op == "place" then
		lastPlace = sm.message[1]
	end
end
check("and places it", lastPlace ~= nil and lastPlace.spot == "rug" and lastPlace.id == "", lastPlace and lastPlace.id)
check("buying a piece for Gilt", press("800 Gilt"))
advance(0.5)
local bought, placedAfter
for _, sm in sent do
	if sm.remote == "ShopAsk" and sm.message[1] and sm.message[1].op == "buyGilt" then
		bought = sm.message[1]
	elseif sm.remote == "ShopAsk" and sm.message[1] and sm.message[1].op == "place" then
		placedAfter = sm.message[1]
	end
end
check("buys it and puts it straight in its spot", bought ~= nil and bought.item == "suite_rug_persian" and placedAfter ~= nil and placedAfter.id == "suite_rug_persian" and placedAfter.spot == "rug")
check("and says so", textOnScreen("Night Garden Rug is in your Suite") ~= nil)
Root2.close()
advance(0.5)
root.Position = Vector3.new(0, 5, -40)
root.CFrame = CFrame.new(0, 5, -40)
advance(1)
check("leaving the Suite puts it away", workspace.MaisonLocal:FindFirstChild("Suite") == nil)
check("no errors in the Suite", #errors == 0, errors[1])

-- A Salute: everyone sees it, and who gave it.
serverSays("Salute", { op = "salute", id = "grand", by = "Ben", userId = 1, seconds = 6, effects = { "goldLeaf", "encore", "chandelier", "fireworks" }, line = "Ben gave the house the Grand Salute." })
advance(2)
check("a salute names its giver", textOnScreen("Ben gave the house the Grand Salute") ~= nil)
check("gold leaf drifts down", workspace.MaisonLocal:FindFirstChild("GoldLeaf") ~= nil)
check("fireworks over the house", workspace.MaisonLocal:FindFirstChild("Firework") ~= nil)
check("the spotlight finds the giver", workspace.MaisonLocal:FindFirstChild("Spotlight") ~= nil)
advance(14)
check("and it all clears away", workspace.MaisonLocal:FindFirstChild("GoldLeaf") == nil and workspace.MaisonLocal:FindFirstChild("Spotlight") == nil)
invokeResults.ShopAsk = {
	always = {}, today = {}, featured = {}, gilt = {}, guests = {}, credits = {}, balance = 0, standing = "Guest",
	season = { id = "autumn", name = "Autumn", pieces = {} },
	goldKey = { owned = false }, ledger = { view = { term = "2026-autumn", page = 1, pages = 50, leather = false } },
	salutes = { { id = "goldLeaf", name = "A Shower of Gold Leaf", line = "Gold leaf drifts down.", price = 49, ready = true } },
	saluteWaiting = 0,
}
serverSays("Shop", { op = "open", panel = "salutes" })
advance(1)
check("the piano's card opens the Salutes", textOnScreen("A Shower of Gold Leaf") ~= nil and textOnScreen("changes no score") ~= nil)
Root2.close()
advance(0.5)
check("no errors in a salute", #errors == 0, errors[1])

-- House controls: only the owner has the key; the events show on everyone's screen.
check("guests don't see the House key", textOnScreen("House") == nil)
LocalPlayer:SetAttribute("MaisonAdmin", true)
advance(0.5)
invokeResults.AdminAsk = {
	ok = true, minutes = { 5, 15, 30 }, giftGilt = { 100, 500, 1000 }, now = 0,
	events = { { id = "goldenHour", name = "Golden Hour", line = "Gilt counts double." } },
	salutes = { { id = "goldLeaf", name = "A Shower of Gold Leaf" } },
	seasons = { { id = "yule", name = "Yuletide" } },
	guests = { { userId = 2, name = "Ben", crowned = false } },
	announcements = { "The owner is in the house tonight." },
}
check("the owner sees the House key", press("House"))
advance(1)
check("the owner's panel opens", textOnScreen("House controls") ~= nil and textOnScreen("Golden Hour") ~= nil)
snapshot("admin")
check("Start begins an event", press("Start") and (function()
	advance(0.5)
	for i = #sent, 1, -1 do
		local sm = sent[i]
		if sm.remote == "AdminAsk" and sm.message[1] and sm.message[1].op == "event" then
			return sm.message[1].id == "goldenHour" and sm.message[1].minutes == 15
		end
	end
	return false
end)())
check("the Guests page has crowns and gifts", press("Guests") and (function()
	advance(0.3)
	return textOnScreen("Crown") ~= nil and textOnScreen("Ben") ~= nil
end)())
Root2.close()
advance(0.5)
workspace:SetAttribute("Event_goldenHour", workspace:GetServerTimeNow() + 600)
signalOf(workspace, "attr:Event_goldenHour"):Fire()
advance(1.2)
check("every guest sees what's on, and for how long", textOnScreen("GOLDEN HOUR") ~= nil and textOnScreen("9:5") ~= nil)
workspace:SetAttribute("Event_goldenHour", nil)
signalOf(workspace, "attr:Event_goldenHour"):Fire()
advance(1.2)
check("and it goes when it's over", textOnScreen("GOLDEN HOUR") == nil)
serverSays("Salute", { op = "announce", text = "Everyone to the Ballroom.", by = "AJ" })
advance(0.5)
check("the owner's announcement lands", textOnScreen("Everyone to the Ballroom") ~= nil)
serverSays("Salute", { op = "summon", jobId = "abc", by = "AJ", text = "Golden Hour here!" })
advance(0.5)
check("a summons offers to go there", press("Go there"))
advance(0.3)
check("and asks the server to go", (function()
	for i = #sent, 1, -1 do
		local sm = sent[i]
		if sm.remote == "Salute" and type(sm.message) == "table" and sm.message.op == "join" then
			return sm.message.jobId == "abc"
		end
	end
	return false
end)())
check("no errors in House controls", #errors == 0, errors[1])

-- Guests noticing each other.
serverSays("Shop", { op = "admired", from = "Ben" })
advance(0.5)
check("being admired is noticed", textOnScreen("Ben admires you") ~= nil)
local AdmireCard = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "AdmireCard")
AdmireCard.show({ ok = true, name = "Ben", userId = 2, counted = true, pieces = { { kind = "table", kindName = "Table styles", id = "table_oxblood", name = "Oxblood Felt", where = "always" } } })
advance(0.5)
check("admiring shows what they wear and where it's from", textOnScreen("Oxblood Felt") ~= nil and textOnScreen("Always here") ~= nil)
invokeResults.ShopAsk = {
	always = { { id = "table_oxblood", name = "Oxblood Felt", kind = "table", kindName = "Table styles", line = "Deep red felt.", robux = 249, owned = false, style = {} } },
	today = {}, featured = {}, gilt = {}, guests = { { userId = 2, name = "Ben" } }, credits = {}, balance = 0, standing = "Guest",
	season = { id = "autumn", name = "Autumn", pieces = {} },
	goldKey = { owned = false }, ledger = { view = { term = "2026-autumn", page = 1, pages = 50, leather = false } },
	salutes = {}, saluteWaiting = 0,
}
check("a gift for them opens the Boutique for them", press("A gift for Ben"))
advance(1)
check("every piece becomes a gift to them", textOnScreen("Choosing a gift for Ben") ~= nil and find(playerGui, function(d)
	return d:IsA("TextButton") and string.find(norm(d.Text), "gift", 1, true) == 1
end) ~= nil)
Root2.close()
advance(0.5)
-- A regular's usual table.
salonTable:SetAttribute("Regular", "Ada")
signalOf(salonTable, "attr:Regular"):Fire()
advance(0.3)
local platesGui = salonTable:FindFirstChild("RegularPlate")
check("a regular's usual table carries their name", platesGui ~= nil and string.find(platesGui:FindFirstChildWhichIsA("TextLabel").Text, "Ada's usual table", 1, true) ~= nil)
-- The Livre d'Or.
invokeResults.ShopAsk = { lines = { "What an evening.", "The Salon, always." }, entries = { { name = "Ben", text = "Until midnight.", at = 0 } }, signedToday = false, now = 7200 }
serverSays("Shop", { op = "open", panel = "guestBook" })
advance(1)
check("the Livre d'Or shows who signed", textOnScreen("Until midnight") ~= nil and textOnScreen("2 hours ago") ~= nil)
check("and offers lines to sign with", press("The Salon, always."))
advance(0.5)
Root2.close()
advance(0.5)
check("no errors among guests", #errors == 0, errors[1])

-- The Gold Key opens the Terrace all year (on the holder's own screen).
local terraceDoor = CollectionService:GetTagged("TerraceDoor")[1]
serverSays("Shop", { op = "state", owned = {}, equipped = {}, gilt = 0, goldKey = false, credits = {}, suite = {}, ledger = { page = 2, pages = 50, progress = 0.1, leather = false, term = "2026-autumn" } })
advance(0.5)
check("out of season the Terrace doors are shut", terraceDoor ~= nil and terraceDoor.CanCollide == true)
serverSays("Shop", { op = "state", owned = {}, equipped = {}, gilt = 0, goldKey = true, credits = {}, suite = {}, ledger = { page = 2, pages = 50, progress = 0.1, leather = false, term = "2026-autumn" } })
advance(0.5)
check("for a Gold Key holder they open", terraceDoor.CanCollide == false)

-- Photo mode, from Settings.
check("Settings opens", press("Settings"))
advance(0.5)
check("photo mode is a key in Settings", press("Photo"))
advance(0.5)
check("photo mode: a free camera", camera.CameraType == roblox.Enum.CameraType.Scriptable and controls.enabled == false)
check("photo mode: depth of field", game:GetService("Lighting"):FindFirstChild("MaisonPhotoFocus") ~= nil)
check("photo mode: its bar, and no interface", textOnScreen("Capture") ~= nil and playerGui:FindFirstChild("MaisonHud").Enabled == false)
local photoStart = camera.CFrame.Position
keysDown.W = true
advance(0.6)
keysDown.W = nil
check("photo mode: W moves the camera, and the avatar stays put", (camera.CFrame.Position - photoStart).Magnitude > 3)
keysDown.W = true
advance(8)
keysDown.W = nil
check("photo mode: the camera stays within reach of you", (camera.CFrame.Position - root.Position).Magnitude <= 28.5, (camera.CFrame.Position - root.Position).Magnitude)
press("Grade ›")
advance(0.2)
check("photo mode: film grades", textOnScreen("NOIR") ~= nil)
advance(1)
check("photo mode: Done hands the camera back", press("Done") and (function()
	advance(1)
	return camera.CameraType == roblox.Enum.CameraType.Custom and controls.enabled == true and game:GetService("Lighting"):FindFirstChild("MaisonPhotoFocus") == nil
end)())
check("and the interface", playerGui:FindFirstChild("MaisonHud").Enabled == true)
check("no errors in photo mode", #errors == 0, errors[1])

---------------------------------------------------------------------------------------------------
-- 8. A respawn hands straight back to the follow camera
---------------------------------------------------------------------------------------------------
camera.CameraType = roblox.Enum.CameraType.Scriptable
LocalPlayer.CharacterAdded:Fire(character)
advance(1)
check("a respawn gives the follow camera back", camera.CameraType == roblox.Enum.CameraType.Custom)
check("and the controls", controls.enabled == true)

advance(10)
check("no errors at all", #errors == 0, #errors)
print(string.format("%d passed, %d failed (%d tweens played, %d reads of destroyed instances)", passed, failed, tweens, destroyedReads))
if failed > 0 then
	process.exit(1)
end
