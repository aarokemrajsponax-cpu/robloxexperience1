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

local controls = { enabled = true }
function controls:Enable()
	self.enabled = true
end
function controls:Disable()
	self.enabled = false
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

local GuiService = { SelectedObject = nil, MenuIsOpen = false, MenuOpened = signal(), MenuClosed = signal() }
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
			return true
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
-- This test walks the whole title (the live game's path), not the Studio shortcut.
Config.data.Studio.skipTitle = false
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
advance(4)
check("no errors in the dialogue", #errors == 0, errors[1])

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
advance(2)
check("seated: controls are off", controls.enabled == false)
check("seated: the camera frames the table", camera.CameraType == roblox.Enum.CameraType.Scriptable)
check("seated: Leave is on screen", textOnScreen("Leave") ~= nil)

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
local piecesFolder = workspace:FindFirstChild("MaisonLocal") and workspace.MaisonLocal:FindFirstChild("Pieces")
check("the deal lands on the felt", piecesFolder ~= nil and #piecesFolder:GetChildren() == 8, piecesFolder and #piecesFolder:GetChildren())
check("no errors rendering the deal", #errors == 0, errors[1])

-- Lift the first piece and file it with the gamepad (A lifts, the D-pad picks a case, A files).
local liftedBefore = sentOps("Table", "lift")
check("A lifts a piece", pad(roblox.Enum.KeyCode.ButtonA))
advance(0.5)
check("the lift is sent", sentOps("Table", "lift") == liftedBefore + 1)
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

-- With a mouse: press on a piece, drag it over its case, let go.
UserInputService.PreferredInput = EnumShim.PreferredInput.KeyboardAndMouse
local Layout = module("ReplicatedStorage", "Shared", "Layout")
local target
for _, m in piecesFolder:GetChildren() do
	if m:GetAttribute("Uid") == 1 then
		target = m
	end
end
local function mouse(kind, at)
	return { UserInputType = kind, Position = Vector3.new(at.X, at.Y, 0), KeyCode = roblox.Enum.KeyCode.Unknown, UserInputState = roblox.Enum.UserInputState.Begin }
end
local frame = salonTable:GetAttribute("Frame")
local wantCase = Catalogue.byId[target:GetAttribute("Uid") and pieceList(10, cases)[1].id].case
local from = toScreen(camera, target:GetPivot().Position)
local to = toScreen(camera, Layout.caseCentre(frame, Catalogue.caseIndex[wantCase]) + Vector3.new(0, 0.3, 0))
local filesBefore = sentOps("Table", "file")
local liftsBeforeDrag = sentOps("Table", "lift")
UserInputService.InputBegan:Fire(mouse(roblox.Enum.UserInputType.MouseButton1, from), false)
UserInputService.InputChanged:Fire(mouse(roblox.Enum.UserInputType.MouseMovement, from + Vector2.new(24, 0)), false)
advance(0.1)
local dragging = sentOps("Table", "lift") - liftsBeforeDrag
UserInputService.InputChanged:Fire(mouse(roblox.Enum.UserInputType.MouseMovement, (from + to) / 2), false)
UserInputService.InputChanged:Fire(mouse(roblox.Enum.UserInputType.MouseMovement, to), false)
UserInputService.InputEnded:Fire(mouse(roblox.Enum.UserInputType.MouseButton1, to), false)
advance(0.5)
local dropped
for _, s in sent do
	if s.remote == "Table" and s.message.op == "file" then
		dropped = s.message
	end
end
check("a mouse drag lifts the piece", dragging > 0)
check("letting go over its case files it", sentOps("Table", "file") == filesBefore + 1 and dropped.uid == 1 and dropped.case == wantCase, dropped and string.format("uid %s case %s want %s files %d->%d", tostring(dropped.uid), dropped.case, wantCase, filesBefore, sentOps("Table", "file")))
UserInputService.PreferredInput = EnumShim.PreferredInput.Gamepad
serverSays("Table", { op = "banked", score = 360, grade = "Polished", rounds = 1, accuracy = 0.9, gilt = 12, best = 360, newBest = true })
advance(2)
check("the banked card offers another run", textOnScreen("Another run") ~= nil)
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
advance(2)
check("leaving hands the camera back", camera.CameraType == roblox.Enum.CameraType.Custom)
check("leaving gives the controls back", controls.enabled == true)
check("the felt is cleared", #piecesFolder:GetChildren() == 0)
check("the rival's plate goes with the table", find(workspace, function(d)
	return d.Name == "RivalPlate"
end) == nil)

---------------------------------------------------------------------------------------------------
-- 5. The Nightly card
---------------------------------------------------------------------------------------------------
serverSays("Table", { op = "seated", table = salonTable:GetAttribute("TableId"), room = "velvet", mode = "nightly" })
advance(1.5)
serverSays("Table", { op = "deal", round = 1, room = "velvet", mode = "nightly", cases = cases, pieces = pieceList(10, cases), score = 0, clock = { left = 30, running = true, budget = 30 } })
advance(3)
check("a timed deal shows the clock rail", find(salonTable, function(d)
	return d.Name == "RailGui"
end) ~= nil)
serverSays("Table", { op = "nightlyCard", key = "2026-09-29", room = "velvet", score = 4210, grade = "Immaculate", rounds = { "Flawless", "Immaculate", "", "", "" }, scored = true, gilt = 120, rank = 12, total = 300, percentile = 4, connections = { place = 2, of = 5 } })
advance(2)
check("the Nightly card shows the score", textOnScreen("4,210") ~= nil)
check("with Share and Invite", textOnScreen("Share") ~= nil and textOnScreen("Invite") ~= nil)
press("Invite")
check("Invite opens Roblox's invite prompt", shared.invites == 1)
press("Leave")
advance(0.5)
serverSays("Table", { op = "left" })
advance(2)
check("no errors through the Nightly", #errors == 0, errors[1])

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
check("Ballroom: over sixteen shows the rail", find(ballroomTable, function(d)
	return d.Name == "RailGui" and d.Enabled
end) ~= nil)
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
check("the Library tab is there", press("Library"))
advance(0.5)
check("the Library board shows ratings", textOnScreen("1540") ~= nil)
Root.close()
advance(1)
local HowToPlay = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "HowToPlay")
HowToPlay.open()
advance(1)
check("how to play opens", textOnScreen("Pick one up") ~= nil)
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
Root2.close()
advance(1)
invokeResults.ShopAsk = ledgerView
serverSays("Shop", { op = "open", panel = "ledger" })
advance(1)
check("the Ledger opens as a book", textOnScreen("Page 2") ~= nil and textOnScreen("100 Gilt") ~= nil)
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
local SuiteLayout = Layout.Suite
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
		{ id = "rug", name = "The rug", room = "main", open = true, house = true, placed = "suite_rug_black", options = { { id = "suite_rug_black", name = "Black Fringed Rug", owned = true }, { id = "suite_rug_persian", name = "Night Garden Rug", owned = false } } },
		{ id = "desk", name = "The Study: the desk", room = "study", open = false, house = false, placed = "", options = {} },
	},
}
serverSays("Shop", { op = "open", panel = "suite" })
advance(1)
check("the bell opens the Suite's furnishing", textOnScreen("Your Suite") ~= nil and textOnScreen("Black Fringed Rug") ~= nil)
check("pieces not yet yours say where they come from", textOnScreen("800 Gilt, in the Boutique") ~= nil)
check("closed rooms say so", textOnScreen("Opens with the Gold Key") ~= nil)
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
