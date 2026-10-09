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
-- The timers are a heap, soonest first (equal times in the order they were set), so thousands of
-- them (a fireworks show's) cost little.
local timerCount = 0
local function sooner(a, b): boolean
	return a.at < b.at or (a.at == b.at and a.n < b.n)
end
local function schedule(at, fn, ...)
	timerCount += 1
	table.insert(timers, { at = at, n = timerCount, fn = fn, args = table.pack(...) })
	local i = #timers
	while i > 1 do
		local up = i // 2
		if sooner(timers[i], timers[up]) then
			timers[i], timers[up] = timers[up], timers[i]
			i = up
		else
			break
		end
	end
end
local function nextTimer()
	local first = timers[1]
	local last = table.remove(timers)
	if #timers > 0 then
		timers[1] = last
		local i = 1
		while true do
			local l, r = i * 2, i * 2 + 1
			local best = i
			if l <= #timers and sooner(timers[l], timers[best]) then
				best = l
			end
			if r <= #timers and sooner(timers[r], timers[best]) then
				best = r
			end
			if best == i then
				break
			end
			timers[i], timers[best] = timers[best], timers[i]
			i = best
		end
	end
	return first
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
		local t = timers[1]
		if not t or t.at > target then
			break
		end
		nextTimer()
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
local preloads = {} -- each ContentProvider:PreloadAsync the game asks for
local otherPlayers = {} -- other guests in the server (Players:GetPlayers), when a check wants some
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
for _, m in { "Stop", "Pause", "Resume" } do
	roblox.implementMethod("Sound", m, function() end)
end
-- Each Sound counts its plays (the piano's checks hear whether a key sounded).
roblox.implementMethod("Sound", "Play", function(self)
	self:SetAttribute("TestPlays", (self:GetAttribute("TestPlays") or 0) + 1)
end)
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

-- Every tag here is added through this shim, so each tag keeps a list of what carries it (looked
-- up without walking the whole game every frame; only what is in the game and still tagged counts).
local tagged: { [string]: { any } } = {}
local CollectionService = {
	AddTag = function(_, instance, tag)
		if instance:HasTag(tag) then
			return
		end
		instance:AddTag(tag)
		local list = tagged[tag]
		if not list then
			list = {}
			tagged[tag] = list
		end
		table.insert(list, instance)
	end,
	RemoveTag = function(_, instance, tag)
		instance:RemoveTag(tag)
	end,
	HasTag = function(_, instance, tag)
		return instance:HasTag(tag)
	end,
	GetTagged = function(_, tag)
		local out = {}
		for _, d in tagged[tag] or {} do
			local ok, here = pcall(function()
				return d:IsDescendantOf(game) and d:HasTag(tag)
			end)
			if ok and here then
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
		local all = { LocalPlayer }
		for _, other in otherPlayers do
			table.insert(all, other)
		end
		return all
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
	ContentProvider = {
		-- What the game asks Roblox to fetch, and how to answer it (see the piano's checks).
		PreloadAsync = function(_, list, callback)
			table.insert(preloads, { list = list, callback = callback })
		end,
	},
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
		IsRunning = function()
			return false -- draw in one go here
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
			elseif key == "FindFirstChild" then
				-- (As on Roblox: a child by name, or nil. Only the sourcemap's children are here.)
				return function(_self, name)
					for _, child in node.children or {} do
						if child.name == name then
							return proxyFor(child, p, path .. "." .. child.name)
						end
					end
					return nil
				end
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

-- Places named in drawn studs are opened out by the Grand Scale (read once the game is set up).
local function GRAND(): number
	return module("ReplicatedStorage", "Shared", "Layout").SCALE
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
			n.padS = { inst.PaddingTop.Scale, inst.PaddingBottom.Scale, inst.PaddingLeft.Scale, inst.PaddingRight.Scale }
		elseif inst:IsA("UITextSizeConstraint") then
			n.maxText = inst.MaxTextSize
			n.minText = inst.MinTextSize
		elseif inst:IsA("UIGridLayout") then
			n.cell = udim2(inst.CellSize)
			n.cellPad = udim2(inst.CellPadding)
			n.hAlign = inst.HorizontalAlignment.Name
		elseif inst:IsA("UISizeConstraint") then
			n.max = { inst.MaxSize.X, inst.MaxSize.Y }
			n.min = { inst.MinSize.X, inst.MinSize.Y }
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
	-- STOP_AFTER=<name>: end the run once that snapshot is written (for looking at one screen).
	if process.env.STOP_AFTER == name then
		print("stopped after " .. name)
		process.exit(0)
	end
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
	-- (At the lectern, in the grown house.)
	local home = Vector3.new(9, 3, 4.2) * GRAND()
	croot.CFrame = CFrame.new(home + Vector3.new(0, 3, 0))
	croot.Parent = concierge
	local chead = Instance.new("Part")
	chead.Name = "Head"
	chead.Size = Vector3.new(1, 1, 1)
	chead.CFrame = CFrame.new(home + Vector3.new(0, 4.5, 0))
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
	moveGuest(Vector3.new(9, 5, 12) * GRAND())
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
	check("the Concierge waits when you fall behind", waitState == "walking" and (waitAt - Vector3.new(9, 3, 12) * GRAND()).Magnitude < 20, waitAt)
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
	moveGuest(Vector3.new(9, 5, 12) * GRAND())
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
	check("sorting: each case shows a piece that goes in it", (function()
		for _, bin in sortGui.Root.Cases:GetChildren() do
			local holder = bin:FindFirstChild("MarkHolder")
			local mark = holder and holder:FindFirstChild("Art")
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
workspace:SetAttribute("Event_goldenHour", workspace:GetServerTimeNow() + 600)
signalOf(workspace, "attr:Event_goldenHour"):Fire()
advance(1.1)
check("at a table, what's on shows on the room's line, not across the cloth", string.find(sortGui.Root.Header.Room.Text, "Golden Hour 9:", 1, true) ~= nil and playerGui.MaisonHud:FindFirstChild("HouseEvents", true).Visible == false, sortGui.Root.Header.Room.Text)
workspace:SetAttribute("Event_goldenHour", nil)
signalOf(workspace, "attr:Event_goldenHour"):Fire()
advance(1.1)
check("and goes from it when it's over", string.find(sortGui.Root.Header.Room.Text, "Golden Hour", 1, true) == nil)
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
	check("and a case closed this round says so on a phone, too", (function()
		local closed = 0
		for _, bin in sortGui.Root.Cases:GetChildren() do
			if bin.Title.Text == "Closed" then
				closed += 1
			end
		end
		return closed == 2
	end)())
	snapshot("sort-phone")
	-- In a laptop's Studio window (short and wide, with Studio's panels around it).
	camera.ViewportSize = Vector2.new(1450, 580)
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.1)
	local laptopIcon = sortGui.Root.Pieces:GetChildren()[1].Icon.Size.X.Offset
	check("in a small Studio window the pieces are still a good size", laptopIcon >= 90, laptopIcon)
	local smallest = math.huge
	for _, d in sortGui:GetDescendants() do
		-- (Letters engraved on a drawn piece, like "999.9" on a gold bar, are part of its picture.)
		local engraved = d:FindFirstAncestor("Art") ~= nil
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.Text ~= "" and not d.TextScaled and not engraved then
			smallest = math.min(smallest, d.TextSize)
		end
	end
	check("and no words on it are smaller than 12 pixels", smallest >= 12, smallest)
	snapshot("sort-laptop")
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
		check(string.format("a right case says so (%d): CORRECT, or GREAT and up on a run", n), (textOnScreen("CORRECT") ~= nil or textOnScreen("GREAT") ~= nil or textOnScreen("EXCELLENT") ~= nil) and textOnScreen("WRONG CASE") == nil)
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
-- Chronos Defiance: the clock ran out (the server only says this in a timed room; the screen
-- shows what it's told). The card counts down the server's own window.
do
	local robux = utf8.char(0xE002)
	local offer = { op = "reviveOffer", left = 10, prompting = false, held = 0, price = 49, onSale = true, add = 15, boardsCount = false, score = 1240, boardScore = 1240, used = 0, usesLeft = 3 }
	serverSays("Table", offer)
	advance(1)
	check("the revive card opens with the real countdown", textOnScreen("Chronos Defiance") ~= nil and (textOnScreen("0:09") ~= nil or textOnScreen("0:10") ~= nil))
	check("it says what it gives, what it costs and what the boards keep", textOnScreen("+15 seconds, and your run goes on") ~= nil and textOnScreen("Revive " .. robux .. " 49") ~= nil and textOnScreen("The boards keep your score from before the revive (1,240)") ~= nil)
	check("banking stays one press away", textOnScreen("Bank the run") ~= nil)
	snapshot("revive")
	local asked = sentOps("Table", "revive")
	press("Revive  " .. robux .. " 49")
	check("Revive asks the server (never decides by itself)", sentOps("Table", "revive") == asked + 1)
	local waiting = table.clone(offer)
	waiting.op, waiting.left, waiting.prompting = "reviveUpdate", 60, true
	serverSays("Table", waiting)
	advance(0.5)
	check("while Roblox's window is open the card says the clock waits", textOnScreen("The clock waits") ~= nil)
	serverSays("Table", { op = "revived", clock = { budget = 30, left = 15, running = true }, held = 0, used = 1, boardScore = 1240 })
	advance(0.5)
	check("revived: the card closes and the clock is back", textOnScreen("Bank the run") == nil and textOnScreen("The clock is yours again") ~= nil)
	-- A revive already held is offered as one, and banking says so to the server.
	local held = table.clone(offer)
	held.held = 2
	serverSays("Table", held)
	advance(0.5)
	check("a revive held is offered without a price", textOnScreen("Use a revive (2 held)") ~= nil)
	local banks = sentOps("Table", "noRevive")
	press("Bank the run")
	check("Bank the run tells the server", sentOps("Table", "noRevive") == banks + 1)
	check("no errors on the revive card", #errors == 0, errors[1])
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
-- Roblox's policy doesn't (yet) let this guest share captures: no Share key at all.
LocalPlayer:SetAttribute("ContentSharingAllowed", nil)
serverSays("Table", { op = "nightlyCard", key = "2026-09-29", room = "velvet", score = 4210, grade = "Immaculate", rounds = { "Flawless", "Immaculate", "", "", "" }, scored = true, gilt = 120, rank = 12, total = 300, percentile = 4, connections = { place = 2, of = 5 } })
advance(2)
check("where Roblox's policy doesn't allow sharing, the Nightly card has no Share key", textOnScreen("Invite") ~= nil and textOnScreen("Share") == nil)
LocalPlayer:SetAttribute("ContentSharingAllowed", true)
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
check("Ballroom: the camera finds the last lamp from the Gallery", camera.CFrame.Position.Y > 35 * GRAND(), camera.CFrame.Position.Y)
serverSays("Table", { op = "eveningResult", place = 4, of = 20, keys = 1, points = 53, gilt = 40, counted = false, won = false })
advance(8)
check("Ballroom: the result card", textOnScreen("4th of 20") ~= nil and textOnScreen("not counted for records") ~= nil)
check("Ballroom: the camera is back at the table", camera.CFrame.Position.Y < 35 * GRAND(), camera.CFrame.Position.Y)
press("Watch from the Gallery")
check("Ballroom: to the Gallery is sent", sentOps("Table", "gallery") == 1)
serverSays("Table", { op = "left" })
advance(2)
check("Ballroom: leaving gives the controls back", controls.enabled == true)
check("no errors through a Lights Out evening", #errors == 0, errors[1])
-- Standing in the Ballroom without a chair: Next evening and Watch.
root.Position = Vector3.new(61, 21, 90) * GRAND()
root.CFrame = CFrame.new(root.Position)
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

---------------------------------------------------------------------------------------------------
-- 7c. The five new products: the Offers, a decree written and proclaimed, the banners, the rain,
-- the perk chips
---------------------------------------------------------------------------------------------------
do
	local robux = utf8.char(0xE002)
	local Root3 = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Root")
	Root3.close()
	advance(1)
	invokeResults.ShopAsk = {
		today = {}, featured = {}, season = { id = "harvest", name = "Harvest Nights", price = 599, pieces = {} },
		gilt = {}, goldKey = { owned = false, price = 499 }, ledger = { view = ledgerView, price = 399 },
		guests = {}, standing = "Guest", balance = 0, credits = {},
		offers = {
			{ key = "doubleGilt", name = "Double Gilt", line = "Every Gilt you earn, doubled, for good. Your purse fills twice as fast.", price = 399, best = true, action = "prompt", category = "Boost" },
			{ key = "godModeLuck", name = "Luck Booster", line = "2.5× Gilt and 2.5× Ledger pages for 30 minutes of play. Time only runs while you're in the house. Scores are never boosted.", price = 199, action = "prompt", category = "Boost", status = "Active: 23 minutes of play left" },
			{ key = "velocityElite", name = "VIP Velocity Elite", line = "Walk and run 1.5× faster through the house, for good, with a gold trail at your heels. Both can be switched off in Settings.", price = 499, action = "prompt", category = "Status" },
			{ key = "emperorsDecree", name = "Emperor's Decree", line = "Your words, in gold, across every screen in the house for eight seconds.", price = 149, action = "compose", category = "Social" },
			{ key = "megalodonRainmaker", name = "Megalodon Rainmaker", line = "Gold rains on the whole house: every guest gets 150 Gilt, you get 500 more, and everyone sees who made it rain.", price = 699, action = "prompt", category = "Spectacle", disabled = true, why = "Rains are already waiting their turn in this house. Try again in a few minutes." },
		},
		ok = true, prompted = true,
	}
	serverSays("Shop", { op = "open", panel = "boutique" })
	advance(1)
	check("the Offers show the new products with Roblox's prices", textOnScreen("Luck Booster") ~= nil and textOnScreen(robux .. " 199") ~= nil and textOnScreen("VIP Velocity Elite") ~= nil)
	check("Luck's time left shows under it", textOnScreen("Active: 23 minutes of play left") ~= nil)
	snapshot("offers")
	check("an offer that can't be bought now says why", textOnScreen("Rains are already waiting their turn") ~= nil)
	press(robux .. " 199")
	local luckAsked = false
	for _, sm in sent do
		if sm.remote == "ShopAsk" and sm.message[1] and sm.message[1].op == "offer" and sm.message[1].key == "godModeLuck" then
			luckAsked = true
		end
	end
	check("buying an offer sends only its key", luckAsked)
	-- The decree: words first, then the purchase.
	invokeResults.PerkAsk = {
		ok = true,
		presets = { "Good evening, everyone.", "The next round is on me.", "Long live the house!", "To the last lamp lit.", "Sort well, my friends.", "Tonight belongs to all of us." },
		maxLength = 80, seconds = 8, price = 149, onSale = true, held = 0, cooldown = 0, queue = 0, queueMax = 3,
	}
	check("Write it opens the decree", press("Write it"))
	advance(1)
	check("the decree panel: a line to write, the house's own lines", textOnScreen("Emperor's Decree") ~= nil and textOnScreen("Check my words") ~= nil and textOnScreen("Long live the house!") ~= nil)
	check("nothing can be proclaimed before the words are checked", textOnScreen("Proclaim") == nil)
	snapshot("decree")
	local box = find(playerGui, function(d)
		return d:IsA("TextBox") and d.Name == "DecreeText"
	end)
	check("the decree has a text box", box ~= nil)
	if box then
		box.Text = "Long live the house"
	end
	invokeResults.PerkAsk = { ok = true, text = "Long live the house", held = 0, price = 149, cooldown = 0, queue = 0 }
	press("Check my words")
	advance(0.5)
	check("checked: the words as the house will show them, then Proclaim with the price", textOnScreen("“Long live the house”") ~= nil and textOnScreen("Proclaim " .. robux .. " 149") ~= nil)
	snapshot("decree-checked")
	invokeResults.PerkAsk = { ok = true, prompted = true }
	press("Proclaim  " .. robux .. " 149")
	local proclaimed = false
	for _, sm in sent do
		if sm.remote == "PerkAsk" and sm.message[1] and sm.message[1].op == "decreeProclaim" then
			proclaimed = true
		end
	end
	check("Proclaim asks the server", proclaimed)
	advance(1)
	-- What every screen sees.
	serverSays("Purchase", { op = "decree", id = "d1", name = "Ada", user = "ada_k", text = "Long live the house", seconds = 8 })
	advance(1)
	check("a decree appears with who proclaimed it", textOnScreen("Decree of Ada (@ada_k)") ~= nil and textOnScreen("Long live the house") ~= nil)
	snapshot("decree-banner")
	advance(9)
	check("and goes after its seconds", textOnScreen("Decree of Ada (@ada_k)") == nil)
	serverSays("Purchase", { op = "rain", id = "r1", by = "Ray", user = "ray", userId = 9, share = 150, seconds = 20, line = "Ray triggered MEGALODON RAIN!" })
	advance(1)
	check("the rain names who made it rain", textOnScreen("Ray triggered MEGALODON RAIN!") ~= nil)
	check("gold falls around the guest", find(game:GetService("Workspace"), function(d)
		return d.Name == "MegalodonRain"
	end) ~= nil)
	snapshot("rain")
	serverSays("Purchase", { op = "rainShare", id = "r1", gilt = 150, by = "Ray" })
	advance(0.5)
	check("their own share is told", textOnScreen("+150 Gilt from Ray's rain.") ~= nil)
	advance(25)
	-- The perk chips: what's bought and waiting, and Luck's time.
	serverSays("Purchase", { op = "perks", credits = { decree = 1, revive = 2 }, luck = { remaining = 1500, multiplier = 2.5, systems = { "gilt", "ledger" } }, rain = { held = 1, position = 1, nextIn = 30 } })
	advance(1.5)
	check("Luck's time left counts down in a chip", textOnScreen("LUCK BOOSTER 2.5×") ~= nil and (textOnScreen("24:58") ~= nil or textOnScreen("24:59") ~= nil or textOnScreen("24:57") ~= nil))
	check("what's held is listed", textOnScreen("A DECREE TO WRITE (1)") ~= nil and textOnScreen("REVIVES KEPT 2") ~= nil and textOnScreen("YOUR RAIN IS NEXT IN LINE") ~= nil)
	snapshot("perk-chips")
	serverSays("Purchase", { op = "notice", title = "Luck Booster", line = "Your Luck has run its course." })
	advance(0.5)
	check("purchase notices show", textOnScreen("Your Luck has run its course.") ~= nil)
	serverSays("Purchase", { op = "perks", credits = {}, luck = { remaining = 0, multiplier = 2.5, systems = { "gilt", "ledger" } } })
	advance(1.5)
	local chips = find(playerGui, function(d)
		return d.Name == "PerkChips"
	end)
	local left = 0
	for _, c in (if chips then chips:GetChildren() else {}) do
		if c:IsA("TextButton") then
			left += 1
		end
	end
	check("and the chips go when there's nothing to show", chips ~= nil and left == 0, left)
	Root3.close()
	advance(1)
	check("no errors in the new products' screens", #errors == 0, errors[1])
end

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
root.Position = Vector3.new(-8, 5, 50) * GRAND()
root.CFrame = CFrame.new(root.Position)
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
local SuiteShared = module("ReplicatedStorage", "Shared", "Suite")
local function countPieces(placed, key)
	local n = 0
	for _ in SuiteShared.pieces(placed, key) do
		n += 1
	end
	return n
end
local expected = countPieces({ rug = "suite_rug_black" }, false)
check("the house's own pieces fill the spots you haven't", suiteFolder ~= nil and #suiteFolder:GetChildren() == expected, suiteFolder and #suiteFolder:GetChildren(), expected)
local alcove = CollectionService:GetTagged("SuiteAlcove")[1]
check("without the Gold Key its rooms stay shut", alcove ~= nil and alcove.CanCollide == true)
local sitPrompts = 0
if suiteFolder then
	for _, d in suiteFolder:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "SeatPrompt" then
			sitPrompts += 1
		end
	end
end
check("the Suite's sofas and chairs can be sat on", sitPrompts >= 4, sitPrompts)
do
	-- Another guest in their own Suite at the same moment: they aren't on your screen, nor is
	-- their name, a glow or a light they wear, or their footsteps. The Suite you walk into is yours.
	local ghost = roblox.Instance.new("Model")
	ghost.Name = "Quin"
	local groot = roblox.Instance.new("Part")
	groot.Name = "HumanoidRootPart"
	groot.Position = SuiteLayout.arrival + Vector3.new(4, 3, 0)
	groot.CFrame = CFrame.new(groot.Position)
	groot.Parent = ghost
	local ghead = roblox.Instance.new("Part")
	ghead.Name = "Head"
	ghead.Parent = ghost
	local gplate = roblox.Instance.new("BillboardGui")
	gplate.Name = "Nameplate"
	gplate.Enabled = true
	gplate.Parent = ghead
	local gaura = roblox.Instance.new("ParticleEmitter")
	gaura.Enabled = true
	gaura.Parent = groot
	local glight = roblox.Instance.new("PointLight")
	glight.Enabled = true
	glight.Parent = groot
	local gsteps = roblox.Instance.new("Sound")
	gsteps.Name = "Running"
	gsteps.Volume = 0.5
	gsteps.Parent = groot
	ghost.Parent = workspace
	local quin = { Name = "Quin", DisplayName = "Quin", UserId = 77, Character = ghost, attrs = {} }
	function quin:GetAttribute(k)
		return self.attrs[k]
	end
	table.insert(otherPlayers, quin)
	advance(1)
	check("another guest in the Suite isn't drawn on your screen", groot.LocalTransparencyModifier == 1 and ghead.LocalTransparencyModifier == 1)
	check("...nor their name, a glow or a light they wear, or their footsteps", gplate.Enabled == false and gaura.Enabled == false and glight.Enabled == false and gsteps.Volume == 0)
	local hat = roblox.Instance.new("Part")
	hat.Name = "Handle"
	hat.Parent = ghost
	advance(1)
	check("...nor what they put on while there", hat.LocalTransparencyModifier == 1)
	-- A friend visiting your Suite (the server says so) is there with you: seen.
	quin.attrs.SuiteHost = LocalPlayer.UserId
	advance(1)
	check("a friend visiting your Suite is seen there with you", groot.LocalTransparencyModifier == 0 and gplate.Enabled == true and hat.LocalTransparencyModifier == 0)
	quin.attrs.SuiteHost = nil
	advance(1)
	check("...and unseen again once they're back in their own", groot.LocalTransparencyModifier == 1)
	groot.Position = Vector3.new(0, 5, -40)
	groot.CFrame = CFrame.new(groot.Position)
	advance(1)
	check("once they leave the Suite they're seen again, just as they were", groot.LocalTransparencyModifier == 0 and hat.LocalTransparencyModifier == 0 and gplate.Enabled == true and gaura.Enabled == true and glight.Enabled == true and math.abs(gsteps.Volume - 0.5) < 1e-3)
	table.remove(otherPlayers, table.find(otherPlayers, quin))
	ghost:Destroy()
end
serverSays("Shop", { op = "state", owned = { "suite_rug_black", "suite_mirror_gilt" }, equipped = {}, gilt = 800, goldKey = true, credits = {}, suite = { rug = "suite_rug_black", mirror = "suite_mirror_gilt" }, ledger = { page = 2, pages = 50, progress = 0.1, leather = false, term = "2026-autumn" } })
advance(0.5)
suiteFolder = workspace.MaisonLocal:FindFirstChild("Suite")
check("with the Gold Key its rooms open", alcove.CanCollide == false and alcove.LocalTransparencyModifier == 1)
check("and the Dressing Room's glass stands", suiteFolder ~= nil and suiteFolder:FindFirstChild("mirror") ~= nil)
check("the rest of the Suite stays as it was", suiteFolder ~= nil and suiteFolder:FindFirstChild("sofa") ~= nil and suiteFolder:FindFirstChild("bed") ~= nil)
-- A friend's Suite (the server checked the friendship): drawn as they've furnished it.
serverSays("Shop", { op = "suiteHost", host = 77, name = "Quin", suite = { rug = "suite_rug_black" }, goldKey = false })
advance(1.5)
local visited = workspace.MaisonLocal:FindFirstChild("Suite")
check("in a friend's Suite it's drawn as they've furnished it (their Gold Key rooms, not yours)", alcove.CanCollide == true and visited ~= nil and visited:FindFirstChild("mirror") == nil and textOnScreen("Quin's Suite") ~= nil)
serverSays("Shop", { op = "open", panel = "suite" })
advance(0.5)
check("their bell is theirs: yours is in your own Suite", textOnScreen("Only Quin furnishes it") ~= nil and textOnScreen("Black Deco Rug") == nil)
serverSays("Shop", { op = "suiteHost" })
advance(1.5)
visited = workspace.MaisonLocal:FindFirstChild("Suite")
check("home again: your own Suite and your Gold Key rooms", alcove.CanCollide == false and visited ~= nil and visited:FindFirstChild("mirror") ~= nil)
-- The Suites key in the dock: your Suite, or a friend's.
invokeResults.SuiteAsk = { ok = true, friends = { { userId = 77, name = "Quin" } } }
local suitesKey = find(playerGui, function(d)
	return d:IsA("TextButton") and d.Name == "Suites"
end)
check("the Suites key sits in the dock on the left", suitesKey ~= nil)
if suitesKey then
	signalOf(suitesKey, "Activated"):Fire()
end
advance(0.5)
check("it offers your own Suite and each friend's", textOnScreen("My Suite") ~= nil and textOnScreen("Quin's Suite") ~= nil)
local quinKey = find(playerGui, function(d)
	return d:IsA("TextButton") and d.Name == "Visit_77"
end)
if quinKey then
	signalOf(quinKey, "Activated"):Fire()
end
advance(0.5)
local visitAsked = nil
for _, m in sent do
	if m.remote == "SuiteAsk" and type(m.message[1]) == "table" and m.message[1].op == "visit" then
		visitAsked = m.message[1].userId
	end
end
check("choosing one asks the server to take you there (it checks you're friends)", visitAsked == 77, visitAsked)
invokeResults.SuiteAsk = nil
invokeResults.ShopAsk = {
	rooms = SuiteShared.RoomNames,
	spots = {
		{
			id = "rug",
			name = "The rug",
			room = "main",
			open = true,
			house = { model = "deco" },
			placed = "suite_rug_black",
			options = {
				{ id = "suite_rug_black", name = "Black Deco Rug", line = "Black wool, a gold fan in the middle.", owned = true, source = "gilt", gilt = 400 },
				{ id = "suite_rug_persian", name = "Night Garden Rug", line = "Deep reds, knotted by hand.", owned = false, source = "gilt", gilt = 800 },
				{ id = "suite_rug_moon", name = "Moonlit Rug", line = "Ink blue, a silver ring.", owned = false, source = "boutique", robux = 149, onSale = true, robuxOnSale = true, giltAlt = 5960 },
			},
		},
		{ id = "sofa", name = "The sofa", room = "main", open = true, house = { model = "chesterfield" }, placed = "", options = {} },
		{ id = "desk", name = "The Study: the desk", room = "study", open = false, placed = "", options = {} },
	},
	gilt = 1200,
	goldKey = false,
}
serverSays("Shop", { op = "open", panel = "suite" })
advance(1)
check("the bell opens the Suite's furnishing", textOnScreen("Your Suite") ~= nil and textOnScreen("Black Deco Rug") ~= nil)
check("with a panel open, the prompts in the world step aside", services.ProximityPromptService.Enabled == false)
snapshot("suite")
if MODE == "full" then
	camera.ViewportSize = Vector2.new(1450, 580)
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.1)
	snapshot("suite-laptop")
	camera.ViewportSize = Vector2.new(1280, 720)
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.1)
end
check("the Suite says what it is", textOnScreen("nothing here changes a score") ~= nil or textOnScreen("only you see your Suite") ~= nil)
check("a tab for every room", textOnScreen("The Drawing Room") ~= nil and textOnScreen("The Screening Room") ~= nil and textOnScreen("The Gym") ~= nil)
check("how far along you are", textOnScreen("Your pieces in 1 of 2 places") ~= nil and textOnScreen("1,200 Gilt") ~= nil)
check("a piece for Gilt can be bought right there", textOnScreen("Night Garden Rug") ~= nil and textOnScreen("800 Gilt") ~= nil)
check("a Robux piece, its price plain", textOnScreen("Moonlit Rug") ~= nil and textOnScreen(utf8.char(0xE002) .. " 149") ~= nil)
check("and it can be had for Gilt instead", textOnScreen("5,960 Gilt") ~= nil)
check("each spot shows a picture of what stands there", (function()
	for _, d in playerGui:GetDescendants() do
		if d:IsA("ViewportFrame") and d.Name == "Picture" and d:FindFirstChildWhichIsA("Model") then
			return true
		end
	end
	return false
end)())
invokeResults.ShopAsk = { ok = true }
check("choosing the house's own piece", press("The house's own"))
advance(0.5)
local lastPlace
for _, sm in sent do
	if sm.remote == "ShopAsk" and sm.message[1] and sm.message[1].op == "place" then
		lastPlace = sm.message[1]
	end
end
check("puts it back", lastPlace ~= nil and lastPlace.spot == "rug" and lastPlace.id == "", lastPlace and lastPlace.id)
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
check("and says so", textOnScreen("Night Garden Rug is in your Suite.") ~= nil)
invokeResults.ShopAsk = {
	rooms = SuiteShared.RoomNames,
	spots = { { id = "desk", name = "The Study: the desk", room = "study", open = false, placed = "", options = {} } },
	gilt = 1200,
	goldKey = false,
}
check("the Study's tab", press("The Study"))
advance(0.5)
check("a Gold Key room says what it holds and how to get it", textOnScreen("Comes with the Gold Key") ~= nil and textOnScreen("A partners' desk and a globe.") ~= nil and textOnScreen("See the Gold Key") ~= nil)
Root2.close()
advance(0.5)
check("and with it closed, they're back", services.ProximityPromptService.Enabled == true)
root.Position = Vector3.new(0, 5, -40)
root.CFrame = CFrame.new(0, 5, -40)
advance(1)
check("leaving the Suite puts it away", workspace.MaisonLocal:FindFirstChild("Suite") == nil)
check("no errors in the Suite", #errors == 0, errors[1])

-- The Terrace Bar: the menu, its prices plain, an order, a special.
do
	invokeResults.BarAsk = {
		ok = true,
		gilt = 60,
		pour = false,
		items = {
			{ id = "lemonade", name = "Sparkling Lemonade", kind = "drink", line = "Pressed lemons, cane sugar and soda, over ice.", gilt = 25, servings = 6 },
			{ id = "fries", name = "Truffle Fries", kind = "snack", line = "Thin fries, parmesan and truffle salt, in a paper cup.", gilt = 40, servings = 6 },
			{ id = "strawberries", name = "Chocolate Strawberries", kind = "snack", line = "Five strawberries.", gilt = 80, servings = 5 },
			{ id = "goldSpritz", key = "barGoldSpritz", name = "The Gold-Leaf Spritz", kind = "drink", line = "Sparkling white grape and elderflower.", robux = 25, ready = true, waiting = 0, servings = 8, glow = true },
			{ id = "platter", key = "barGrandPlatter", name = "The Grand Platter", kind = "snack", line = "A silver platter of sweets.", robux = 99, ready = false, waiting = 0, servings = 10, glow = true, share = true },
		},
	}
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BarPrompt"
	services.ProximityPromptService.PromptTriggered:Fire(prompt)
	advance(1)
	check("the bar's prompt opens its menu", textOnScreen("The Terrace Bar") ~= nil and textOnScreen("Sparkling Lemonade") ~= nil)
	snapshot("bar")
	check("every price is plain: Gilt for the menu", textOnScreen("25 Gilt") ~= nil and textOnScreen("40 Gilt") ~= nil)
	check("Robux for the specials", textOnScreen(utf8.char(0xE002) .. " 25") ~= nil)
	check("a special not on sale yet says so", textOnScreen("not on sale yet") ~= nil)
	check("and the menu says what it isn't", textOnScreen("no alcohol, nothing random") ~= nil)
	invokeResults.BarAsk = { ok = true, gilt = 35 }
	check("ordering for Gilt", press("25 Gilt"))
	advance(0.5)
	local order
	for _, sm in sent do
		if sm.remote == "BarAsk" and sm.message[1] and sm.message[1].op == "order" then
			order = sm.message[1]
		end
	end
	check("asks for the item by name, never with a price", order ~= nil and order.id == "lemonade" and order.gilt == nil and order.price == nil)
	check("and closes with a word", Root2.isOpen("Bar") == false and textOnScreen("Sparkling Lemonade. Enjoy it.") ~= nil)
	check("no errors at the bar", #errors == 0, errors[1])
end

-- The Menu, your Collection (curios, the Cabinet, Gems), a find, and a trade.
do
	check("the Menu key is on the screen", press("Menu"))
	advance(0.6)
	check("the Menu lists the house's places", textOnScreen("Your Collection") ~= nil and textOnScreen("Trading") ~= nil and textOnScreen("The Register") ~= nil and textOnScreen("How to play") ~= nil)
	snapshot("menu")
	invokeResults.CurioAsk = {
		ok = true,
		op = "curios",
		items = { croissantino = 3, frogKing = 1, truffle = 1 },
		favs = { frogKing = true },
		recent = { "truffle", "croissantino" },
		gems = 90,
		found = 4,
		cabinet = {
			items = { { id = "truffle", gems = 60 }, { id = "caviarTin", gems = 150 } },
			packs = { { key = "gems1", name = "Gem Pouch", gems = 120, robux = 99, ready = true }, { key = "gems2", name = "Gem Case", gems = 650, robux = 449, ready = false } },
		},
	}
	local tile
	for _, d in playerGui:GetDescendants() do
		if d:IsA("TextButton") and d.Name == "Tile_collection" then
			tile = d
		end
	end
	check("the Collection tile opens the Collection", tile ~= nil)
	if tile then
		signalOf(tile, "Activated"):Fire()
	end
	advance(1)
	check("your curios, with how many you hold", textOnScreen("Croissantino Furioso") ~= nil and textOnScreen("×3") ~= nil and textOnScreen("5 curios, 3 of") ~= nil)
	snapshot("collection")
	local frog
	for _, d in playerGui:GetDescendants() do
		if d:IsA("TextButton") and d.Name == "Curio_frogKing" then
			frog = d
		end
	end
	check("a curio opens its card", frog ~= nil)
	if frog then
		signalOf(frog, "Activated"):Fire()
		advance(0.3)
	end
	check("the card says what it is, its rarity and how it's had", textOnScreen("Crowned at a lily pond") ~= nil and textOnScreen("LEGENDARY") ~= nil and textOnScreen("Found at the tables (Legendary)") ~= nil and textOnScreen("can be traded") ~= nil)
	check("the search finds by name", (function()
		local box
		for _, d in playerGui:GetDescendants() do
			if d:IsA("TextBox") and d.Name == "Search" then
				box = d
			end
		end
		if not box then
			return false
		end
		box.Text = "frog"
		signalOf(box, "prop:Text"):Fire()
		advance(0.2)
		local ok = textOnScreen("Le Roi Grenouille") ~= nil and textOnScreen("Croissantino Furioso") == nil
		box.Text = ""
		signalOf(box, "prop:Text"):Fire()
		advance(0.2)
		return ok
	end)())
	check("the whole book shows the ones still to find", press("Every curio"))
	advance(0.4)
	check("dark, as 'Not found yet'", textOnScreen("Not found yet") ~= nil)
	check("the Gems tab", press("Gems"))
	advance(0.4)
	check("packs at Roblox's price, and one not on sale says so", textOnScreen(utf8.char(0xE002) .. " 99") ~= nil and textOnScreen("not on sale yet") ~= nil)
	snapshot("gems")
	Root2.close()
	advance(0.5)
	-- A find: the reveal.
	serverSays("Curio", { op = "found", id = "goldenGoose", line = "Among the pieces, a curio.", gilt = 400 })
	advance(0.8)
	check("a curio found is revealed, with its rarity and its Gilt", textOnScreen("L'Oie d'Or") ~= nil and textOnScreen("LEGENDARY") ~= nil and textOnScreen("+400 Gilt") ~= nil)
	snapshot("curio-found")
	advance(6)
	check("and goes by itself", textOnScreen("L'Oie d'Or") == nil)
	-- A trade.
	serverSays("Curio", { op = "tradeInvite", from = "Nia", userId = 77 })
	advance(0.5)
	check("an invitation to trade, with accept, no thanks and block", textOnScreen("Nia would like to trade") ~= nil and textOnScreen("No thanks") ~= nil and textOnScreen("Block") ~= nil)
	invokeResults.TradeAsk = { ok = true }
	press("Trade")
	advance(0.5)
	serverSays("Curio", { op = "trade", id = 1, with = "Nia", withId = 77, mine = {}, theirs = { frogKing = 1 }, ready = false, theyReady = true, confirmed = false, theyConfirmed = false, version = 2, state = "open", countdown = 0 })
	advance(0.5)
	check("the trade shows both sides, exactly as the house holds them", textOnScreen("A trade with Nia") ~= nil and textOnScreen("Le Roi Grenouille ×1") ~= nil and textOnScreen("Nia offers  ·  locked in") ~= nil)
	snapshot("trade")
	local offered
	for _, d in playerGui:GetDescendants() do
		if d:IsA("TextButton") and d.Name == "Offered_croissantino" then
			offered = d
		end
	end
	check("your own curios to offer", offered ~= nil)
	if offered then
		signalOf(offered, "Activated"):Fire()
		advance(0.4)
	end
	local lastOffer
	for _, sm in sent do
		if sm.remote == "TradeAsk" and sm.message[1] and sm.message[1].op == "offer" then
			lastOffer = sm.message[1]
		end
	end
	check("tapping one offers it (the screen sends ids and counts only)", lastOffer ~= nil and lastOffer.items.croissantino == 1)
	check("lock in", press("Lock in"))
	advance(0.4)
	local readied
	for _, sm in sent do
		if sm.remote == "TradeAsk" and sm.message[1] and sm.message[1].op == "ready" then
			readied = sm.message[1]
		end
	end
	check("locking in names the version seen", readied ~= nil and readied.version == 2)
	serverSays("Curio", { op = "tradeEnd", id = 1, state = "done", why = "The trade is done." })
	advance(0.5)
	check("a finished trade closes the screen and says so", Root2.isOpen("Trade") == false and textOnScreen("The trade is done.") ~= nil)
	check("no errors in the Collection or a trade", #errors == 0, errors[1])
end

-- The Foyer's grand piano: the sessions at the bench, then the keyboard while playing.
do
	invokeResults.PianoAsk = {
		ok = false, needTime = true, seconds = 0, playing = false,
		offers = {
			{ key = "pianoSession1", name = "1 minute at the piano", seconds = 60, price = 99, ready = true },
			{ key = "pianoSession3", name = "3 minutes at the piano", seconds = 180, price = 349, ready = true },
			{ key = "pianoSession5", name = "5 minutes at the piano", seconds = 300, price = 599, ready = true },
			{ key = "pianoSession10", name = "10 minutes at the piano", seconds = 600, price = 899, ready = false },
		},
	}
	serverSays("Purchase", { op = "pianoOffer" })
	advance(1)
	check("the piano: the bench offers its sessions", textOnScreen("The Grand Piano") ~= nil and textOnScreen("everyone in the Foyer") ~= nil)
	local buy = find(playerGui, function(d)
		return d:IsA("TextButton") and d.Name == "Buy_pianoSession3"
	end)
	check("each at Roblox's price", buy ~= nil and string.find(buy.Text, "349", 1, true) ~= nil and textOnScreen("10 minutes at the piano · not on sale yet") ~= nil)
	snapshot("piano-offer")
	if buy then
		signalOf(buy, "Activated"):Fire()
	end
	advance(0.5)
	local asked
	for _, m in sent do
		if m.remote == "PianoAsk" and type(m.message[1]) == "table" and m.message[1].op == "buy" then
			asked = m.message[1].key
		end
	end
	check("choosing one asks the server for it by name", asked == "pianoSession3", asked)
	-- Today's free taste still to be had: it comes first, and the sessions wait below it.
	Root.close("Piano")
	advance(0.5)
	invokeResults.PianoAsk.taste = 30
	serverSays("Purchase", { op = "pianoOffer" })
	advance(1)
	local taste = find(playerGui, function(d)
		return d:IsA("TextButton") and d.Name == "Taste"
	end)
	check("the piano: today's free taste is offered first", taste ~= nil and string.find(taste.Text, "0:30", 1, true) ~= nil and textOnScreen("free time every day") ~= nil, taste and taste.Text)
	snapshot("piano-taste")
	if taste then
		signalOf(taste, "Activated"):Fire()
	end
	advance(0.5)
	local sat = false
	for _, m in sent do
		if m.remote == "PianoAsk" and type(m.message[1]) == "table" and m.message[1].op == "sit" then
			sat = true
		end
	end
	check("taking it asks the server to sit them down", sat)
	invokeResults.PianoAsk.taste = nil
	Root.close("Piano")
	advance(0.5)
	-- The server seats this guest: the keyboard comes up.
	workspace:SetAttribute("PianoPlayer", LocalPlayer.UserId)
	workspace:SetAttribute("PianoEnds", workspace:GetServerTimeNow() + 180)
	signalOf(workspace, "attr:PianoPlayer"):Fire()
	advance(1)
	local keys = playerGui:FindFirstChild("PianoKeys", true)
	check("seated: the keyboard comes up, three octaves", keys ~= nil and keys.Visible and #keys:FindFirstChild("Keybed", true):GetChildren() == 37)
	check("and the offer goes", textOnScreen("everyone in the Foyer") == nil)
	check("and the prompts in the world step aside", services.ProximityPromptService.Enabled == false)
	snapshot("piano-keys")
	local action = actions.MaisonPiano
	if action then
		action.fn("MaisonPiano", roblox.Enum.UserInputState.Begin, { KeyCode = roblox.Enum.KeyCode.Z })
	end
	local last
	for _, m in sent do
		if m.remote == "PianoNote" then
			last = m.message
		end
	end
	check("Z plays the lowest C, sent to the server for the room", action ~= nil and last == 1, last)
	-- The note itself: a slice of a licensed APM recording (other creators' audio is refused by
	-- Roblox in this experience), retuned from the slice's F3 down to the low C.
	local function played()
		local out = {}
		for _, d in game:GetDescendants() do
			if d:IsA("Sound") and d.Name == "PianoNote" and (d:GetAttribute("TestPlays") or 0) > 0 then
				table.insert(out, d)
			end
		end
		return out
	end
	local note = played()[1]
	check("the note plays a licensed recording every experience may use", note ~= nil and note.SoundId == "rbxassetid://1847254302", note and note.SoundId)
	check("...only its one clean note (a slice of the recording)", note ~= nil and note.PlaybackRegionsEnabled == true and math.abs(note.PlaybackRegion.Min - 0.775) < 1e-3)
	check("...retuned to the key (C3, from the slice's F3)", note ~= nil and math.abs(note.PlaybackSpeed - 2 ^ ((48 - 52.97) / 12)) < 1e-3, note and note.PlaybackSpeed)
	-- Roblox fetches the assets of Instances: a bare id handed to PreloadAsync reports "Failure"
	-- for a sound (which, until Build 48, struck the piano's recordings off and silenced it).
	local fetched, bare = {}, 0
	for _, p in preloads do
		for _, item in p.list do
			if typeof(item) == "Instance" and item:IsA("Sound") then
				fetched[item.SoundId] = p
			elseif type(item) == "string" then
				bare += 1
			end
		end
	end
	check("the piano's recordings are fetched as Sounds, not bare ids", fetched["rbxassetid://1847254302"] ~= nil and fetched["rbxassetid://1848319257"] ~= nil and bare == 0, bare)
	-- Even when Roblox says every recording failed, the keys keep trying them: never a silent
	-- keyboard. (Fresh recordings, so none has been heard yet.)
	local Assets = Config.data.Assets
	local real = Assets.PianoSlices
	Assets.PianoSlices = {
		{ id = "rbxassetid://5551", note = 52.97, start = 0.775, length = 2.5, gain = 1.6 },
		{ id = "rbxassetid://5552", note = 72.08, start = 0.952, length = 3.0, gain = 1.3 },
	}
	local asked = #preloads
	module("StarterPlayer", "StarterPlayerScripts", "Client", "Sound").preloadPiano()
	local failed = 0
	for i = asked + 1, #preloads do
		local p = preloads[i]
		for _, item in p.list do
			if typeof(item) == "Instance" and p.callback then
				p.callback(item.SoundId, roblox.Enum.AssetFetchStatus.Failure)
				failed += 1
			end
		end
	end
	local _, ready, gone = module("StarterPlayer", "StarterPlayerScripts", "Client", "Sound").pianoHealth()
	if action then
		action.fn("MaisonPiano", roblox.Enum.UserInputState.Begin, { KeyCode = roblox.Enum.KeyCode.Z })
	end
	local struck = nil
	for _, d in played() do
		if d.SoundId == "rbxassetid://5551" then
			struck = d
		end
	end
	check("a recording Roblox called failed still sounds (the keys never go silent)", failed == 2 and gone == 2 and ready == 0 and struck ~= nil and struck.PlaybackRegionsEnabled == true, string.format("failed %d, health %d ready %d failed", failed, ready, gone))
	Assets.PianoSlices = real
	-- Each key has its voices ready, with the room's reach for the bigger Foyer.
	local voices = 0
	local reach = true
	for _, d in game:GetDescendants() do
		if d:IsA("Sound") and d.Name == "PianoNote" then
			voices += 1
			reach = reach and d.RollOffMaxDistance == Config.data.Piano.heard and d.RollOffMinDistance == Config.data.Piano.near
		end
	end
	check("every key's voices are ready before the first note (3 a key)", voices == Config.data.Piano.keys * 3 and reach, voices)
	workspace:SetAttribute("PianoPlayer", nil)
	signalOf(workspace, "attr:PianoPlayer"):Fire()
	advance(1)
	check("getting up puts the keyboard away", actions.MaisonPiano == nil and services.ProximityPromptService.Enabled == true)
	check("no errors at the piano", #errors == 0, errors[1])
end

-- A Salute: everyone sees it, and who gave it.
serverSays("Salute", { op = "salute", id = "grand", by = "Ben", userId = 1, seconds = 6, effects = { "goldLeaf", "encore", "chandelier", "fireworks" }, line = "Ben gave the house the Grand Salute." })
advance(2)
check("a salute names its giver", textOnScreen("Ben gave the house the Grand Salute") ~= nil)
check("gold confetti showers down", workspace.MaisonLocal:FindFirstChild("GoldLeaf") ~= nil)
check("fireworks over the house: shells going up and bursting over the estate", (function()
	local f = workspace.MaisonLocal:FindFirstChild("Fireworks")
	return f ~= nil and #f:GetChildren() > 0
end)())
check("the shells fly high over the roofs", (function()
	local f = workspace.MaisonLocal:FindFirstChild("Fireworks")
	for _, p in (f and f:GetChildren() or {}) do
		if (p.Name == "Shell" or p.Name == "Rocket" or p.Name == "Shape") and p.Position.Y > 60 then
			return true
		end
	end
	return false
end)())
check("the spotlight finds the giver", workspace.MaisonLocal:FindFirstChild("Spotlight") ~= nil)
check("...its beam seen in the air", (function()
	local lamp = workspace.MaisonLocal:FindFirstChild("Spotlight")
	return lamp ~= nil and lamp:FindFirstChildOfClass("Beam") ~= nil
end)())
check("gold confetti: slips of gold foil flutter down, turning as they fall", (function()
	local leaves = 0
	for _, f in workspace.MaisonLocal:GetChildren() do
		if f.Name == "Flakes" then
			for _, leaf in f:GetChildren() do
				if leaf:IsA("BasePart") and leaf.Material == roblox.Enum.Material.Metal then
					leaves += 1
				end
			end
		end
	end
	return leaves >= 80
end)())
advance(14)
check("and it all clears away", workspace.MaisonLocal:FindFirstChild("GoldLeaf") == nil and workspace.MaisonLocal:FindFirstChild("Spotlight") == nil and workspace.MaisonLocal:FindFirstChild("Flakes") == nil)
advance(12)
check("...the fireworks too, once the last willows have fallen", (function()
	local f = workspace.MaisonLocal:FindFirstChild("Fireworks")
	return f == nil or #f:GetChildren() == 0
end)(), (function()
	local f = workspace.MaisonLocal:FindFirstChild("Fireworks")
	return f and #f:GetChildren()
end)())
-- The Midnight Finale: a countdown on every screen, then the show.
serverSays("Salute", { op = "salute", id = "finale", by = "Ben", userId = 1, seconds = 16, scale = 1.6, effects = { "countdown", "goldLeaf", "chandelier", "fireworks" }, line = "Ben lit the Midnight Finale." })
advance(1.5)
check("the Midnight Finale counts down on screen", textOnScreen("9") ~= nil or textOnScreen("8") ~= nil)
check("...and no shell goes up before midnight", (function()
	local f = workspace.MaisonLocal:FindFirstChild("Fireworks")
	return f == nil or #f:GetChildren() == 0
end)())
advance(10.5)
check("at midnight the sky goes up", (function()
	local f = workspace.MaisonLocal:FindFirstChild("Fireworks")
	return f ~= nil and #f:GetChildren() > 0
end)())
advance(25)
invokeResults.ShopAsk = {
	always = {}, today = {}, featured = {}, gilt = {}, guests = {}, credits = {}, balance = 0, standing = "Guest",
	season = { id = "autumn", name = "Autumn", pieces = {} },
	goldKey = { owned = false }, ledger = { view = { term = "2026-autumn", page = 1, pages = 50, leather = false } },
	salutes = {
		{ id = "goldLeaf", name = "A Shower of Gold Confetti", line = "Gold confetti flutters down.", price = 75, ready = true },
		{ id = "fireworks", name = "Fireworks over the House", line = "A full fireworks show over the whole estate.", price = 299, ready = false, preview = true },
		{ id = "finale", name = "The Midnight Finale", line = "A countdown, then the biggest show.", price = 999, ready = false, preview = false },
	},
	saluteWaiting = 0,
}
serverSays("Shop", { op = "open", panel = "salutes" })
advance(1)
check("the piano's card opens the Salutes", textOnScreen("A Shower of Gold Confetti") ~= nil and textOnScreen("changes no score") ~= nil)
check("no salute says \"Soon\": each shows its price, or a Studio preview", textOnScreen("Soon") == nil and textOnScreen("Preview") ~= nil and textOnScreen("299 when on sale") ~= nil and textOnScreen("999") ~= nil)
snapshot("salutes")
Root2.close()
advance(0.5)
check("no errors in a salute", #errors == 0, errors[1])

-- Fireworks: a key to go out and watch them (and the giver is taken out at once).
serverSays("Salute", { op = "salute", id = "fireworks", by = "Ada", userId = LocalPlayer.UserId, seconds = 10, scale = 1, effects = { "fireworks" }, line = "Ada lit fireworks over the house." })
advance(1)
local watchKey = find(playerGui, function(d)
	return d:IsA("TextButton") and d.Name == "Watch"
end)
check("fireworks: a key to watch them from outside", watchKey ~= nil)
check("...and the guest who lit them is taken out to watch at once", watchKey ~= nil and watchKey.Text == "Back to the house", watchKey and watchKey.Text)
snapshot("fireworks-watch")
if watchKey then
	signalOf(watchKey, "Activated"):Fire()
end
advance(0.5)
check("...and brought back with the same key", watchKey ~= nil and watchKey.Text == "Watch the fireworks")
advance(20)
check("when the show is over, the key goes", find(playerGui, function(d)
	return d:IsA("TextButton") and d.Name == "Watch"
end) == nil)

-- A long show plays all three acts, each to its own score: Hanabi, Liberty (with Niagara Falls
-- pouring down the front of the house) and Majesty (searchlights, the house's monogram in gold,
-- comets with tails), then a cheer.
do
	local SoundService = game:GetService("SoundService")
	local seen = { falls = false, searchlight = false, comet = false, monogram = false, fountain = false }
	local scores: { [string]: boolean } = {}
	serverSays("Salute", { op = "salute", id = "fireworks", by = "Ada", userId = 2, seconds = 70, scale = 1.3, effects = { "fireworks" }, line = "Ada lit fireworks over the house." })
	for _ = 1, 72 do
		advance(1)
		local f = workspace.MaisonLocal:FindFirstChild("Fireworks")
		for _, d in (f and f:GetChildren() or {}) do
			if d.Name == "Falls" then
				seen.falls = true
			elseif d.Name == "Searchlight" then
				seen.searchlight = true
			elseif d.Name == "Comet" then
				seen.comet = true
			elseif d.Name == "Fountain" then
				seen.fountain = true
			elseif d.Name == "Shape" and d:GetAttribute("Shape") == "monogram" then
				seen.monogram = true
			end
		end
		for _, d in SoundService:GetChildren() do
			if d:IsA("Sound") and d.Name == "Score" then
				scores[d.SoundId] = true
			end
		end
	end
	local C = module("ReplicatedStorage", "Shared", "Config").data.Fireworks.score
	check("fireworks: the opening's fountains of gold on the parapet", seen.fountain)
	check("...comets with real tails (palms, willows, kamuro)", seen.comet)
	check("...Niagara Falls pours down the front of the house", seen.falls)
	check("...searchlights sweep the sky in the finale", seen.searchlight)
	check("...the house's monogram written in gold stars", seen.monogram)
	check("...each act to its own score: taiko, Sousa, Handel", scores[C.hanabi] == true and scores[C.liberty] == true and scores[C.majesty] == true)
	advance(12)
	check("...and when it's over the sky and the score clear away", (function()
		local f = workspace.MaisonLocal:FindFirstChild("Fireworks")
		local left = 0
		for _, d in (f and f:GetChildren() or {}) do
			if d.Name ~= "Smoke" then
				left += 1
			end
		end
		return left == 0
	end)() and SoundService:FindFirstChild("Score") == nil)
	check("no errors in the fireworks", #errors == 0, errors[1])
end

-- The Golden Transformation: the Midas touch turns the Suite to gold, crowns the guest, and puts
-- everything back as it was.
do
	local maison = workspace:FindFirstChild("Maison")
	if not maison then
		maison = Instance.new("Folder")
		maison.Name = "Maison"
		maison.Parent = workspace
	end
	local made = maison:FindFirstChild("Suite") == nil
	local suite = maison:FindFirstChild("Suite") or Instance.new("Model")
	suite.Name = "Suite"
	suite.Parent = maison
	local wallColour = roblox.Color3.fromRGB(34, 26, 22)
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Size = Vector3.new(1, 10, 10)
	wall.Color = wallColour
	wall.Material = roblox.Enum.Material.Wood
	wall.CFrame = root.CFrame * CFrame.new(5, 0, 0)
	wall.Position = root.Position + Vector3.new(5, 0, 0)
	wall.Parent = suite
	-- (The fire the transformation finds: the Suite's own fireplace if the world has one.)
	local madeFire = suite:FindFirstChild("Fireplace") == nil
	local fireplace = suite:FindFirstChild("Fireplace") or Instance.new("Model")
	fireplace.Name = "Fireplace"
	fireplace.Parent = suite
	local core = fireplace:FindFirstChild("FireCore") or Instance.new("Part")
	core.Name = "FireCore"
	core.Transparency = 1
	core.Parent = fireplace
	local flames = core:FindFirstChildOfClass("ParticleEmitter") or Instance.new("ParticleEmitter")
	flames.Name = "Flames"
	flames.Rate = 70
	flames.Parent = core
	serverSays("Purchase", { op = "spectacle", key = "spectacleGolden", seconds = 40 })
	advance(3)
	check("the Midas touch: the Suite turns to gold where the ring of gold has passed", wall.Material == roblox.Enum.Material.Metal and wall.Color ~= wallColour)
	check("...the fire burns gold", flames.Rate > 70)
	advance(8)
	local touch = workspace.MaisonLocal:FindFirstChild("MidasTouch")
	check("...gold coins rain down round the guest", touch ~= nil and touch:FindFirstChild("Coin") ~= nil)
	check("...leaves of gold fall through the rooms", workspace.MaisonLocal:FindFirstChild("Flakes") ~= nil)
	check("...a heavenly choir", (function()
		local choir = module("ReplicatedStorage", "Shared", "Config").data.Midas.choir
		for _, d in game:GetService("SoundService"):GetChildren() do
			if d:IsA("Sound") and d.Name == "Score" and d.SoundId == choir then
				return true
			end
		end
		return false
	end)())
	advance(11)
	check("...a jewelled crown settles on the guest's head", touch ~= nil and touch:FindFirstChild("MidasCrown") ~= nil)
	snapshot("midas")
	advance(22)
	check("...and everything is put back as it was", wall.Color == wallColour and wall.Material == roblox.Enum.Material.Wood)
	check("...the fire too", flames.Rate == 70)
	check("...and the gold is gone", workspace.MaisonLocal:FindFirstChild("MidasTouch") == nil)
	check("no errors in the Midas touch", #errors == 0, errors[1])
	wall:Destroy()
	if madeFire then
		fireplace:Destroy()
	end
	if made then
		suite:Destroy()
	end
end

-- The Meme Takeover: six acts in the Suite, then everything put back.
serverSays("Purchase", { op = "spectacle", key = "spectacleMemes", seconds = 20 })
advance(1)
check("the Meme Takeover starts with its warning", textOnScreen("MEME TAKEOVER") ~= nil)
advance(3)
local takeover = workspace.MaisonLocal:FindFirstChild("MemeTakeover")
check("...the portal spews memes into the room", takeover ~= nil and #takeover:GetChildren() > 10, takeover and #takeover:GetChildren())
snapshot("meme-takeover")
advance(8)
check("...then the boss arrives", textOnScreen("THE BIG CHEESE") ~= nil or textOnScreen("MAXIMUM BRAINROT") ~= nil or textOnScreen("RAINING MEMES") ~= nil)
advance(14)
check("...and when it's over, the room is put back", workspace.MaisonLocal:FindFirstChild("MemeTakeover") == nil and find(playerGui, function(d)
	return d.Name == "MemeTakeover"
end) == nil)
check("no errors in the spectacles", #errors == 0, errors[1])

-- Friends in the house: a word at the left edge (the server counts them, and pays the boost).
LocalPlayer:SetAttribute("FriendsHere", 1)
advance(0.3)
check("friends in the house: the boost is shown", textOnScreen("FRIENDS HERE (1)") ~= nil and textOnScreen("GILT") ~= nil)
LocalPlayer:SetAttribute("FriendsHere", nil)
advance(0.3)
check("...and goes when they do", textOnScreen("FRIENDS HERE") == nil)

-- The House Party: every lamp in the house turns disco, then back exactly as it was.
do
	local lamp = nil
	for _, d in workspace.Maison:GetDescendants() do
		if d:IsA("PointLight") then
			lamp = d
			break
		end
	end
	local was = lamp and lamp.Color
	workspace:SetAttribute("Event_discoHouse", workspace:GetServerTimeNow() + 60)
	signalOf(workspace, "attr:Event_discoHouse"):Fire()
	advance(1.5)
	check("the House Party: the lamps turn disco", lamp ~= nil and lamp:GetAttribute("DiscoWas") ~= nil and lamp.Color ~= was)
	workspace:SetAttribute("Event_discoHouse", nil)
	advance(1.5)
	check("...and every lamp is back as it was", lamp ~= nil and lamp:GetAttribute("DiscoWas") == nil and lamp.Color == was)
end

-- Disco Night and the House Party together: whichever ends last puts the lamps back.
do
	local ballroomLamp = nil
	local ballroom = workspace.Maison:FindFirstChild("Ballroom")
	for _, d in (ballroom and ballroom:GetDescendants() or {}) do
		if d:IsA("PointLight") then
			ballroomLamp = d
			break
		end
	end
	local own = ballroomLamp and ballroomLamp.Color
	workspace:SetAttribute("Event_disco", workspace:GetServerTimeNow() + 60)
	signalOf(workspace, "attr:Event_disco"):Fire()
	advance(0.5)
	workspace:SetAttribute("Event_discoHouse", workspace:GetServerTimeNow() + 60)
	signalOf(workspace, "attr:Event_discoHouse"):Fire()
	advance(1.5)
	workspace:SetAttribute("Event_disco", nil)
	signalOf(workspace, "attr:Event_disco"):Fire()
	advance(1)
	check("Disco Night ends while the House Party goes on: the lamps keep partying", ballroomLamp ~= nil and ballroomLamp:GetAttribute("DiscoWas") ~= nil)
	workspace:SetAttribute("Event_discoHouse", nil)
	advance(1.5)
	check("...and when the party ends too, each lamp is its own colour again", ballroomLamp ~= nil and ballroomLamp.Color == own and ballroomLamp:GetAttribute("DiscoWas") == nil)
end

-- Many events at once (Admin Abuse Night): one headline and one turning line, not a wall.
do
	local soon = workspace:GetServerTimeNow() + 900
	for _, id in { "goldenHour", "luckyHour", "giants", "quickstep", "goldRain", "featherlight" } do
		workspace:SetAttribute("Event_" .. id, soon)
		signalOf(workspace, "attr:Event_" .. id):Fire()
	end
	workspace:SetAttribute("AbuseUntil", soon)
	signalOf(workspace, "attr:AbuseUntil"):Fire()
	advance(1.2)
	local strip = find(playerGui, function(d)
		return d.Name == "HouseEvents" and d:IsA("Frame")
	end)
	local lines = 0
	for _, c in (strip and strip:GetChildren() or {}) do
		if c:IsA("TextLabel") then
			lines += 1
		end
	end
	check("Admin Abuse Night: one headline on every screen, and one line turning through the events", textOnScreen("ADMIN ABUSE NIGHT") ~= nil and textOnScreen("6 EVENTS ON") ~= nil and lines <= 3, lines)
	snapshot("abuse-banner")
	for _, id in { "goldenHour", "luckyHour", "giants", "quickstep", "goldRain", "featherlight" } do
		workspace:SetAttribute("Event_" .. id, nil)
		signalOf(workspace, "attr:Event_" .. id):Fire()
	end
	workspace:SetAttribute("AbuseUntil", nil)
	signalOf(workspace, "attr:AbuseUntil"):Fire()
	advance(1.2)
	check("...and it goes when the night ends", textOnScreen("ADMIN ABUSE NIGHT") == nil)
end

-- Effects for everyone (the server says which; this screen plays it round its guest).
serverSays("Salute", { op = "abuseFX", id = "intro", seconds = 6 })
advance(0.5)
check("the intro: ADMIN ABUSE slams onto the screen", textOnScreen("ADMIN ABUSE") ~= nil)
snapshot("abuse-intro")
serverSays("Salute", { op = "abuseFX", id = "memeRain", seconds = 5 })
advance(1.5)
local fxFolder = workspace.MaisonLocal:FindFirstChild("AbuseFX")
local memes = 0
for _, c in (fxFolder and fxFolder:GetChildren() or {}) do
	if c.Name == "Meme" then
		memes += 1
	end
end
check("a brainrot storm: memes pour from the sky round you", memes >= 6 and textOnScreen("BRAINROT STORM") ~= nil, memes)
serverSays("Salute", { op = "abuseFX", id = "shockwave", seconds = 4, origin = Vector3.new(0, 5, 0) })
advance(0.3)
check("a shockwave: a ring of gold blasts out", workspace.MaisonLocal.AbuseFX:FindFirstChild("Shockwave") ~= nil)
serverSays("Salute", { op = "abuseFX", id = "confetti", seconds = 4 })
advance(0.5)
local cannons = 0
for _, c in workspace.MaisonLocal:GetChildren() do
	if c.Name == "Flakes" then
		cannons += 1
	end
end
check("confetti cannons on every side", cannons >= 4, cannons)
serverSays("Salute", { op = "abuseFX", id = "launch", seconds = 4 })
advance(0.3)
local launchRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
check("a rocket launch: you shoot up on a trail of smoke", launchRoot ~= nil and launchRoot:FindFirstChild("LaunchTrail") ~= nil and textOnScreen("LIFT OFF") ~= nil)
serverSays("Salute", { op = "abuseFX", id = "storm", seconds = 6 })
serverSays("Salute", { op = "abuseFX", id = "dance", seconds = 6 })
serverSays("Salute", { op = "abuseFX", id = "spin", seconds = 3 })
advance(2)
check("a storm, a dance party and a spin, all at once, without a fault", textOnScreen("DANCE PARTY") ~= nil and #errors == 0, errors[1])
serverSays("Salute", { op = "abuseFX", id = "stop" })
advance(6)
check("Stop everything: whatever was playing goes", workspace.MaisonLocal:FindFirstChild("AbuseFX") == nil and (launchRoot == nil or launchRoot:FindFirstChild("LaunchTrail") == nil))

-- The owner's flight: only the server switches it on (for the owner); the screen flies.
LocalPlayer:SetAttribute("AdminFly", true)
advance(0.5)
local flyRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
check("the owner flies when the server says so", flyRoot ~= nil and flyRoot:FindFirstChild("AdminFlyVelocity") ~= nil)
LocalPlayer:SetAttribute("AdminFly", nil)
advance(0.5)
check("...and lands when it stops", flyRoot ~= nil and flyRoot:FindFirstChild("AdminFlyVelocity") == nil)
check("no errors with friends, the party or the flight", #errors == 0, errors[1])

-- The bell's Spectacles page: each show with its whole line (every row as tall as its words), its
-- price in Robux or a Play key for one held, and plainly: only you see it.
do
	local Products = module("ReplicatedStorage", "Shared", "ProductConfig")
	local shows = {}
	for i, key in { "spectacleFireworks", "spectacleMemes", "spectacleGolden" } do
		local e = Products.byKey[key]
		table.insert(shows, { key = key, name = e.UX.DisplayName, line = e.UX.Line, robux = e.Pricing.ReferencePrice, ready = true, held = if i == 3 then 1 else 0 })
	end
	invokeResults.SpectacleAsk = { ok = true, shows = shows }
	module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "SuiteSpectacle").open()
	advance(1)
	local page = find(playerGui, function(d)
		return d.Name == "Shows" and d:IsA("ScrollingFrame")
	end)
	local rows = 0
	local grows = true
	if page then
		for _, row in page:GetChildren() do
			if row:IsA("Frame") then
				rows += 1
				grows = grows and row.AutomaticSize == roblox.Enum.AutomaticSize.Y and row:FindFirstChild("Words") ~= nil
			end
		end
	end
	check("the Spectacles page lists the three shows, each row as tall as its words", rows == 3 and grows, rows)
	check("...says plainly that only you see a show", textOnScreen("Only you see it") ~= nil)
	check("...with each price, and a Play key for one you hold", textOnScreen("Play (1 held)") ~= nil and textOnScreen("199") ~= nil)
	snapshot("spectacles")
	module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Root").close("Spectacles")
	advance(0.5)
	invokeResults.SpectacleAsk = nil
end

-- Eating at the Terrace: a click takes a bite; the treat gets smaller as it's eaten.
do
	local treat = Instance.new("Model")
	treat.Name = "Treat"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Parent = treat
	treat.PrimaryPart = handle
	for i = 1, 4 do
		local b = Instance.new("Part")
		b.Name = "Bite" .. i
		b.Position = Vector3.new(0, 5 + i * 0.1, -40)
		b.Parent = treat
	end
	treat:SetAttribute("Owner", LocalPlayer.UserId)
	treat:SetAttribute("Kind", "snack")
	treat:SetAttribute("Servings", 4)
	treat:SetAttribute("Total", 4)
	treat:SetAttribute("Sips", 0)
	treat.Parent = character
	signalOf(workspace, "DescendantAdded"):Fire(treat)
	advance(0.5)
	local eat = find(playerGui, function(d)
		return d:IsA("TextButton") and d.Name == "Eat"
	end)
	check("holding a treat: a key to eat it", eat ~= nil and string.find(eat.Text, "Take a bite · 4 left", 1, true) ~= nil, eat and eat.Text)
	snapshot("eat")
	if eat then
		signalOf(eat, "Activated"):Fire()
	end
	advance(0.3)
	local asked = 0
	for _, m in sent do
		if m.remote == "BarAsk" and type(m.message) == "table" and type(m.message[1]) == "table" and m.message[1].op == "bite" then
			asked += 1
		end
	end
	check("a click asks the server for a bite", asked == 1, asked)
	if eat then
		signalOf(eat, "Activated"):Fire()
	end
	advance(0.1)
	local again = 0
	for _, m in sent do
		if m.remote == "BarAsk" and type(m.message) == "table" and type(m.message[1]) == "table" and m.message[1].op == "bite" then
			again += 1
		end
	end
	check("...not faster than a person can chew", again == 1, again)
	-- The server says two bites are gone.
	treat:SetAttribute("Servings", 2)
	signalOf(treat, "attr:Servings"):Fire()
	treat:SetAttribute("Sips", 2)
	signalOf(treat, "attr:Sips"):Fire()
	advance(1)
	local hidden = 0
	for _, d in treat:GetChildren() do
		if string.sub(d.Name, 1, 4) == "Bite" and d.Transparency == 1 then
			hidden += 1
		end
	end
	check("the treat gets smaller as it's eaten (half gone, half left)", hidden == 2, hidden)
	check("...and the key counts down", eat ~= nil and string.find(eat.Text, "2 left", 1, true) ~= nil, eat and eat.Text)
	treat.Parent = nil
	signalOf(treat, "AncestryChanged"):Fire()
	advance(0.3)
	check("no errors eating", #errors == 0, errors[1])
end

-- The quick dock: Collection, Trade, Wardrobe, Gems and Invite, one tap away.
do
	local dockKeys = {}
	for _, name in { "Collection", "Trade", "Wardrobe", "Gems", "Invite" } do
		dockKeys[name] = find(playerGui, function(d)
			return d:IsA("TextButton") and d.Name == name and d.Parent ~= nil and d.Parent.Name == "QuickDock"
		end)
	end
	check("the dock: Collection, Trade, Wardrobe, Gems and Invite on screen", dockKeys.Collection ~= nil and dockKeys.Trade ~= nil and dockKeys.Wardrobe ~= nil and dockKeys.Gems ~= nil and dockKeys.Invite ~= nil)
	local invitesBefore = shared.invites
	if dockKeys.Invite then
		signalOf(dockKeys.Invite, "Activated"):Fire()
	end
	advance(0.5)
	check("Invite opens Roblox's own invite prompt", shared.invites == invitesBefore + 1)
	if dockKeys.Trade then
		signalOf(dockKeys.Trade, "Activated"):Fire()
	end
	advance(1)
	check("Trade lists who to trade with, and your past trades", textOnScreen("Your trades") ~= nil and textOnScreen("nothing changes hands until you both confirm") ~= nil or textOnScreen("Nobody else is in the house") ~= nil)
	snapshot("dock-trade")
	Root2.close()
	advance(0.5)
	check("no errors at the dock", #errors == 0, errors[1])
end

-- The Owner Console: only the owner has the key; it opens by itself (with a welcome) when they
-- arrive; every tile asks the server (which checks it's the owner).
local function pressNamed(name: string): boolean
	local button = find(playerGui, function(d)
		return d:IsA("TextButton") and d.Name == name and d.Visible ~= false
	end)
	if not button then
		return false
	end
	signalOf(button, "Activated"):Fire()
	return true
end
local function lastAsk(op: string): any
	for i = #sent, 1, -1 do
		local sm = sent[i]
		if sm.remote == "AdminAsk" and sm.message[1] and sm.message[1].op == op then
			return sm.message[1]
		end
	end
	return nil
end
do
	local hit = find(playerGui, function(d)
		return d:IsA("TextButton") and d.Name == "OwnerKey"
	end)
	check("guests don't see the owner's key", hit == nil, hit and hit:GetFullName())
end
invokeResults.AdminAsk = {
	ok = true, minutes = { 5, 15, 30 }, giftGilt = { 100, 500, 1000 }, now = 0,
	events = {
		{ id = "goldenHour", name = "Golden Hour", line = "Gilt counts double.", glyph = "🪙" },
		{ id = "doubleXP", name = "Double XP", line = "Every level comes twice as fast.", glyph = "⭐" },
		{ id = "halloween", name = "The All Hallows' Hunt", line = "Pumpkins are hidden all over the house.", glyph = "🎃", holiday = true },
		{ id = "newYear", name = "The New Year Countdown", line = "Ten seconds, then fireworks.", glyph = "🎆", holiday = true },
	},
	salutes = { { id = "goldLeaf", name = "A Shower of Gold Confetti" } },
	seasons = { { id = "yule", name = "Yuletide" } },
	guests = { { userId = 2, name = "Ben", crowned = false } },
	announcements = { "The owner is in the house tonight." },
	headlines = { "ADMIN ABUSE IN 5 MINUTES! DON'T LEAVE!", "GIVEAWAY TIME! STAY IN THE SERVER!" },
	headlineStyles = { "gold", "red", "rainbow", "ice", "green" },
	countdowns = { { id = "abuse", name = "Admin Abuse Night", label = "ADMIN ABUSE IN" }, { id = "giveaway", name = "A giveaway", label = "GIVEAWAY IN" } },
	countdownSeconds = { 10, 30, 60 },
	giveawayGilt = { 250, 1000, 5000 },
	abuseMinutes = { 15, 30, 60 },
	powers = { fly = false, ghost = false, speed = 1, jump = 1, size = 1, invisible = false, frozen = false, abuseOn = true, clock = "midnight", clocks = { "midnight", "dawn", "noon", "sunset" }, effects = { { id = "launch", name = "Rocket launch", glyph = "🚀" }, { id = "dance", name = "Dance party" }, { id = "storm", name = "Lightning storm" }, { id = "memeRain", name = "Brainrot storm" }, { id = "confetti", name = "Confetti cannons" }, { id = "shockwave", name = "Shockwave" }, { id = "spin", name = "Spin" }, { id = "meteor", name = "Meteor shower", glyph = "☄️" }, { id = "blackHole", name = "Black hole", glyph = "🕳️" }, { id = "titan", name = "Titan meme", glyph = "🗿" } }, speeds = { 1, 2, 3, 5 }, jumps = { 1, 2, 4 }, sizes = { 0.5, 1, 2, 4 }, places = { "street", "foyer", "salon", "boutique", "vault", "library", "ballroom", "terrace", "suite" } },
}
LocalPlayer:SetAttribute("MaisonAdmin", true)
advance(2.5)
check("the owner is welcomed when they arrive", textOnScreen("WELCOME BACK, OWNER") ~= nil)
advance(3)
check("then the Owner Console opens by itself", textOnScreen("OWNER CONSOLE") ~= nil)
snapshot("owner-console")
check("its categories: abuse, effects, holidays, events, players, world, message, powers, more", (function()
	for _, id in { "abuse", "effects", "holidays", "events", "players", "world", "message", "powers", "more" } do
		if not find(playerGui, function(d)
			return d:IsA("TextButton") and d.Name == "Cat_" .. id
		end) then
			return false
		end
	end
	return true
end)())
check("Admin Abuse and Mega Abuse, every length, and Stop everything, on the first page", textOnScreen("Admin Abuse · 30 min") ~= nil and textOnScreen("MEGA ABUSE · 60 min") ~= nil and textOnScreen("Stop everything") ~= nil)
check("Admin Abuse goes to every server by default", pressNamed("Tile_abuse30") and (function()
	advance(0.5)
	local m = lastAsk("abuse")
	return m ~= nil and m.minutes == 30 and m.everywhere == true
end)())
check("a countdown to it", pressNamed("Tile_countabuse10") and (function()
	advance(0.5)
	local m = lastAsk("countdown")
	return m ~= nil and m.id == "abuse" and m.seconds == 10
end)())
check("the effects page has every effect as a tile", pressNamed("Cat_effects") and (function()
	advance(0.3)
	return textOnScreen("Meteor shower") ~= nil and textOnScreen("Black hole") ~= nil and textOnScreen("Titan meme") ~= nil
end)())
snapshot("owner-console-effects")
check("THIS SERVER keeps it to this server", press("THIS SERVER") and pressNamed("Tile_fx_meteor") and (function()
	advance(0.5)
	local m = lastAsk("fx")
	return m ~= nil and m.id == "meteor" and m.everywhere == false
end)())
press("🌍 ALL SERVERS")
check("the holidays page: the hunts and the New Year", pressNamed("Cat_holidays") and (function()
	advance(0.3)
	return textOnScreen("All Hallows") ~= nil and textOnScreen("New Year Countdown") ~= nil and textOnScreen("Double XP") == nil
end)())
check("a holiday starts for the minutes chosen", press("30 MIN") and pressNamed("Tile_event_halloween") and (function()
	advance(0.5)
	local m = lastAsk("event")
	return m ~= nil and m.id == "halloween" and m.minutes == 30 and m.everywhere == true
end)())
check("players: giveaways, gifts and the Owner's Token", pressNamed("Cat_players") and (function()
	advance(0.3)
	return textOnScreen("Giveaway · 1000") ~= nil and textOnScreen("Owner's Token") ~= nil and textOnScreen("Bring everyone") ~= nil
end)())
check("a giveaway asks the server for that amount", pressNamed("Tile_giveaway1000") and (function()
	advance(0.5)
	local m = lastAsk("giveaway")
	return m ~= nil and m.amount == 1000
end)())
check("message: headlines, ready-made or your own", pressNamed("Cat_message") and (function()
	advance(0.3)
	return textOnScreen("READY-MADE HEADLINES") ~= nil and textOnScreen("GIVEAWAY TIME") ~= nil
end)())
check("a ready-made headline in the style chosen", press("RAINBOW") and pressNamed("Tile_headline2") and (function()
	advance(0.5)
	local m = lastAsk("headline")
	return m ~= nil and m.preset == 2 and m.style == "rainbow"
end)())
snapshot("owner-console-message")
check("powers: fly, ghost, vanish, speed, size, go anywhere", pressNamed("Cat_powers") and (function()
	advance(0.3)
	return textOnScreen("Fly") ~= nil and textOnScreen("Ghost") ~= nil and textOnScreen("COLOSSAL") ~= nil and textOnScreen("Ballroom") ~= nil
end)())
check("Fly asks the server (which checks it's the owner)", pressNamed("Tile_fly") and (function()
	advance(0.5)
	local m = lastAsk("power")
	return m ~= nil and m.power == "fly"
end)())
check("the classic House controls are a tap away", pressNamed("Cat_more") and pressNamed("Tile_classic_events") and (function()
	advance(1)
	return textOnScreen("House controls") ~= nil and textOnScreen("Golden Hour") ~= nil
end)())
check("the owner has their own key (gold, with a crown)", find(playerGui, function(d)
	return d:IsA("TextButton") and d.Name == "OwnerKey"
end) ~= nil)
check("Stop everything sits at the top of the Events page", textOnScreen("Stop everything") ~= nil and textOnScreen("Admin Abuse Night is on") ~= nil)
snapshot("admin")
check("Start begins an event", press("Start") and (function()
	advance(0.5)
	for i = #sent, 1, -1 do
		local sm = sent[i]
		if sm.remote == "AdminAsk" and sm.message[1] and sm.message[1].op == "event" then
			local id = sm.message[1].id
			return (id == "goldenHour" or id == "doubleXP" or id == "halloween" or id == "newYear") and sm.message[1].minutes == 15
		end
	end
	return false
end)())
check("the Guests page has crowns and gifts", press("Guests") and (function()
	advance(0.3)
	return textOnScreen("Crown") ~= nil and textOnScreen("Ben") ~= nil
end)())
check("the owner's Powers page: fly, speed, jump, size, invisible, go anywhere, everyone", press("Powers") and (function()
	advance(0.3)
	return textOnScreen("Fly") ~= nil and textOnScreen("Super jump") ~= nil and textOnScreen("Colossal") ~= nil and textOnScreen("Vanish") ~= nil and textOnScreen("Ballroom") ~= nil and textOnScreen("Bring all") ~= nil and textOnScreen("Freeze") ~= nil
end)())
check("...and effects for everyone, the time of day and Ghost", textOnScreen("Rocket launch") ~= nil and textOnScreen("Brainrot storm") ~= nil and textOnScreen("Sunset") ~= nil and textOnScreen("Ghost") ~= nil)
check("the page you're on is the tab that's lit", (function()
	local tab = find(playerGui, function(d)
		return d:IsA("TextButton") and d.Name == "Tab_powers"
	end)
	local other = find(playerGui, function(d)
		return d:IsA("TextButton") and d.Name == "Tab_events"
	end)
	return tab ~= nil and other ~= nil and tab.BackgroundColor3 ~= other.BackgroundColor3
end)())
snapshot("admin-powers")
check("the classic Powers page's Fly asks the server too", press("Fly") and (function()
	advance(0.5)
	local m = lastAsk("power")
	return m ~= nil and m.power == "fly"
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

-- The Terrace is open to everyone, every season.
local terraceDoor = CollectionService:GetTagged("TerraceDoor")[1]
serverSays("Shop", { op = "state", owned = {}, equipped = {}, gilt = 0, goldKey = false, credits = {}, suite = {}, ledger = { page = 2, pages = 50, progress = 0.1, leather = false, term = "2026-autumn" } })
advance(0.5)
check("the Terrace doors stand open for every guest", terraceDoor ~= nil and terraceDoor.CanCollide == false, terraceDoor and tostring(terraceDoor:GetAttribute("Open")) .. " " .. terraceDoor:GetFullName())
local barPrompt = nil
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Name == "BarPrompt" then
		barPrompt = d
	end
end
check("and the bar has its prompt", barPrompt ~= nil)

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

-- Build 51: the owner's headlines, countdowns and giveaways on every screen; the Gilt bar; levels;
-- badges; the Gem Shop; the Badge Book.
serverSays("Salute", { op = "headline", text = "WHO'S READY FOR CHAOS?!", by = "XxxXxxX_77797", style = "rainbow", seconds = 6 })
advance(0.6)
check("a headline crosses the top of every screen, with who sent it", textOnScreen("WHO'S READY FOR CHAOS?!") ~= nil and textOnScreen("XxxXxxX_77797") ~= nil)
snapshot("headline")
advance(7)
check("and goes after a few seconds", textOnScreen("WHO'S READY FOR CHAOS?!") == nil)
serverSays("Salute", { op = "countdown", id = "abuse", label = "ADMIN ABUSE IN", seconds = 10, endsAt = workspace:GetServerTimeNow() + 10 })
advance(0.5)
check("a countdown in big numbers", textOnScreen("ADMIN ABUSE IN") ~= nil and textOnScreen("10") ~= nil)
snapshot("countdown")
advance(10)
check("then GO!", textOnScreen("GO!") ~= nil)
advance(2)
serverSays("Salute", { op = "countdown", id = "abuse", label = "MEGA ABUSE IN", seconds = 30, endsAt = workspace:GetServerTimeNow() + 30 })
advance(0.5)
serverSays("Salute", { op = "countdown", id = "", stop = true })
advance(0.3)
check("Stop everything takes a countdown away", textOnScreen("MEGA ABUSE IN") == nil)
serverSays("Salute", { op = "giveaway", names = { "Ben", "Ada", "Cy" }, winner = "Ben", winnerId = 2, amount = 1000, by = "XxxXxxX_77797" })
advance(0.3)
check("a giveaway is drawn on every screen, free", textOnScreen("GIVEAWAY") ~= nil and textOnScreen("free for everyone") ~= nil)
advance(4)
check("and lands on the winner", textOnScreen("Ben wins 1000 Gilt!") ~= nil)
snapshot("giveaway")
advance(4)
serverSays("Salute", { op = "giveaway", names = { "You" }, winner = LocalPlayer.DisplayName, winnerId = LocalPlayer.UserId, amount = 250, by = "XxxXxxX_77797" })
advance(4.5)
check("the winner's own screen says YOU WON!", textOnScreen("YOU WON!") ~= nil)
advance(4)
-- The Gilt bar.
LocalPlayer:SetAttribute("Gilt", 12500)
LocalPlayer:SetAttribute("Gems", 340)
LocalPlayer:SetAttribute("Level", 12)
LocalPlayer:SetAttribute("LevelXP", 300)
LocalPlayer:SetAttribute("LevelNeed", 940)
advance(2)
check("the Gilt bar shows Gilt, Gems and the level, live", textOnScreen("12,500") ~= nil and textOnScreen("340") ~= nil and textOnScreen("SORTER") ~= nil)
snapshot("gilt-bar")
local giltBar = find(playerGui, function(d)
	return d.Name == "GiltBar"
end)
check("the Gilt bar steps aside under a panel", (function()
	press("Settings")
	advance(0.5)
	local hidden = giltBar ~= nil and giltBar.Visible == false
	Root2.close()
	advance(0.5)
	return hidden and giltBar.Visible == true
end)())
-- Levels and badges, celebrated.
serverSays("Shop", { op = "levelUp", level = 20, title = "Adept", gilt = 350, gems = 20 })
advance(0.6)
check("LEVEL UP! with the new level, its name and its reward", textOnScreen("LEVEL UP!") ~= nil and textOnScreen("ADEPT") ~= nil and textOnScreen("+350 Gilt") ~= nil)
snapshot("level-up")
advance(4)
serverSays("Shop", { op = "badge", key = "metOwner", name = "Met the Owner", line = "Be in the house with the owner.", glyph = "👑", tier = "gold" })
serverSays("Shop", { op = "badge", key = "firstRound", name = "First Round", line = "Clear your first round at the tables.", glyph = "🃏", tier = "bronze" })
advance(0.8)
check("a badge earned slides in", textOnScreen("Met the Owner") ~= nil and textOnScreen("BADGE EARNED") ~= nil)
snapshot("badge")
advance(4.5)
check("and the next waits its turn", textOnScreen("First Round") ~= nil)
advance(5)
-- The Gem Shop: every price on its card; two taps to buy; the screen never sends a price.
invokeResults.GemAsk = { ok = true, gems = 500, owned = {}, aura = "", title = "", giltUntil = 0, xpUntil = 0, now = 0, cabinet = { items = { { id = "saffronJar", gems = 60 } } } }
local GemShopPanel = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "GemShopPanel")
GemShopPanel.open("aura")
advance(1)
check("the Gem Shop opens with your Gems and its auras, each with its price", textOnScreen("The Gem Shop") ~= nil and textOnScreen("500 Gems") ~= nil and textOnScreen("Gold Dust") ~= nil and textOnScreen("💎 120") ~= nil)
snapshot("gem-shop")
local buysBefore = 0
for _, sm in sent do
	if sm.remote == "GemAsk" and sm.message[1] and sm.message[1].op == "buy" then
		buysBefore += 1
	end
end
check("the first tap only asks you to confirm", press("💎 120") and (function()
	advance(0.3)
	local buys = 0
	for _, sm in sent do
		if sm.remote == "GemAsk" and sm.message[1] and sm.message[1].op == "buy" then
			buys += 1
		end
	end
	return buys == buysBefore and textOnScreen("CONFIRM · 💎 120") ~= nil
end)())
check("the second buys it, sending only what it is", press("CONFIRM · 💎 120") and (function()
	advance(0.5)
	for i = #sent, 1, -1 do
		local sm = sent[i]
		if sm.remote == "GemAsk" and sm.message[1] and sm.message[1].op == "buy" then
			local m = sm.message[1]
			local keys = 0
			for _ in m do
				keys += 1
			end
			return m.id == "aura_golddust" and keys == 2
		end
	end
	return false
end)())
check("titles, surges, Gilt and curios are shelves of their own", press("TITLES") and (function()
	advance(0.3)
	return textOnScreen("Certified Legend") ~= nil
end)() and press("SURGES") and (function()
	advance(0.3)
	return textOnScreen("Gilt Surge") ~= nil and textOnScreen("XP Surge") ~= nil
end)() and press("CURIOS") and (function()
	advance(0.3)
	return textOnScreen("A Jar of Saffron") ~= nil
end)())
Root2.close()
advance(0.5)
-- The Badge Book.
invokeResults.BadgeAsk = { ok = true, earned = { firstRound = 1790000000, metOwner = 1790000100 }, stats = { rounds = 7, level = 12 }, count = 2, total = 151 }
local BadgeBookPanel = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "BadgeBookPanel")
BadgeBookPanel.open()
advance(1)
check("the Badge Book: what's earned, and how far along the rest are", textOnScreen("The Badge Book") ~= nil and textOnScreen("2 of 151 badges earned") ~= nil and textOnScreen("Met the Owner") ~= nil and textOnScreen("7 / 10") ~= nil)
snapshot("badge-book")
check("its groups", press("HOLIDAYS") and (function()
	advance(0.3)
	return textOnScreen("All Hallows' Hunter") ~= nil
end)())
Root2.close()
advance(0.5)
-- Holidays and auras on this screen.
workspace:SetAttribute("Event_valentine", workspace:GetServerTimeNow() + 600)
signalOf(workspace, "attr:Event_valentine"):Fire()
advance(1.5)
check("Valentine's Day turns the light rosy", game:GetService("Lighting"):FindFirstChild("HolidayTint") ~= nil)
workspace:SetAttribute("Event_valentine", nil)
signalOf(workspace, "attr:Event_valentine"):Fire()
advance(1.5)
check("and back when it's over", game:GetService("Lighting"):FindFirstChild("HolidayTint") == nil)
LocalPlayer:SetAttribute("Aura", "aura_golddust")
advance(1)
check("an aura glows round whoever wears it", root:FindFirstChild("MaisonAura") ~= nil)
LocalPlayer:SetAttribute("Aura", nil)
advance(1)
check("and goes when it's taken off", root:FindFirstChild("MaisonAura") == nil)
check("no errors in Build 51's screens", #errors == 0, errors[1])

---------------------------------------------------------------------------------------------------
-- Build 53: effects switched on stay on (and come to the sorting tables), golden pieces, music
---------------------------------------------------------------------------------------------------
do
	local SoundService = game:GetService("SoundService")
	local function fxOn(id, on)
		workspace:SetAttribute("Fx_" .. id, if on then os.time() else nil)
		signalOf(workspace, "attr:Fx_" .. id):Fire()
	end
	local function busy(layer)
		return layer ~= nil and #layer:GetDescendants() > 4
	end
	local function scoreId()
		local s = SoundService:FindFirstChild("ScoreList")
		return if s then s.SoundId else nil
	end
	local function inList(id, list)
		for _, song in Config.data.Assets.AbuseMusic[list] do
			if song.id == id then
				return true
			end
		end
		return false
	end
	local walk = playerGui:FindFirstChild("MaisonScreenFX")
	check("the walking screen has a layer of its own for the effects", walk ~= nil)
	fxOn("meteor", true)
	advance(1.5)
	check("an effect switched on plays at once", textOnScreen("METEOR SHOWER") ~= nil)
	check("...and shows on the screen as well (indoors too)", busy(walk))
	snapshot("walk-meteor")
	advance(45)
	check("and it's still going long after: it stays on until it's switched off", busy(walk))
	check("its own music plays (a meteor shower: something epic)", inList(scoreId(), "epic"), scoreId())
	fxOn("meteor", false)
	advance(3)
	check("switched off: it stops, and the screen clears", not busy(walk))
	check("and the house's own music comes back", scoreId() == nil)
	-- Effects that move guests come in waves, with a rest between.
	fxOn("launch", true)
	advance(1)
	check("a rocket launch switched on: lift off", textOnScreen("LIFT OFF") ~= nil)
	fxOn("launch", false)
	advance(1)
	-- Admin Abuse's music, then Mega Abuse's.
	workspace:SetAttribute("AbuseUntil", workspace:GetServerTimeNow() + 900)
	workspace:SetAttribute("AbuseSince", os.time())
	signalOf(workspace, "attr:AbuseUntil"):Fire()
	advance(1)
	check("Admin Abuse: dance music over the house", inList(scoreId(), "abuse"), scoreId())
	workspace:SetAttribute("AbuseMega", true)
	signalOf(workspace, "attr:AbuseMega"):Fire()
	advance(3)
	check("Mega Abuse: harder music", inList(scoreId(), "mega"), scoreId())
	-- At a table in the middle of it.
	serverSays("Table", { op = "seated", table = salonTable:GetAttribute("TableId"), room = "salon", mode = "room" })
	advance(2)
	local list = pieceList(8, cases)
	list[3].golden = true
	list[6].golden = true
	serverSays("Table", { op = "deal", round = 1, room = "salon", mode = "room", cases = cases, pieces = list, score = 0, twist = "mega" })
	advance(2.5)
	check("at the table, a ribbon says what's on and what it brings", textOnScreen("MEGA ABUSE · ×3 GILT · GOLDEN PIECES") ~= nil)
	check("golden pieces wear their gold (only those)", Sort.card(3):FindFirstChild("Golden") ~= nil and Sort.card(6):FindFirstChild("Golden") ~= nil and Sort.card(1):FindFirstChild("Golden") == nil)
	check("Mega Abuse's glow shows round the table", busy(sortGui.Root.AbuseBack) or busy(sortGui.Root.AbuseFront))
	check("the walking screen's effects step aside at the table (the table has its own)", not busy(walk))
	snapshot("table-mega")
	serverSays("Table", { op = "filed", uid = 3, case = list[3].case, correct = true, points = 30, setBonus = 0, penalty = 0, score = 30, streak = 1, multiplier = 1, runLength = 1, remaining = 7, golden = 120 })
	advance(0.3)
	check("a golden piece in its right case: GOLDEN! and what it paid", textOnScreen("GOLDEN!") ~= nil and textOnScreen("+120 GILT") ~= nil)
	snapshot("table-golden")
	advance(2)
	-- Every effect has its own look on the table.
	workspace:SetAttribute("AbuseUntil", nil)
	workspace:SetAttribute("AbuseMega", nil)
	workspace:SetAttribute("AbuseSince", nil)
	signalOf(workspace, "attr:AbuseUntil"):Fire()
	advance(3)
	local looks = {}
	for _, id in { "meteor", "blackHole", "aurora", "galaxy", "ufo", "blizzard", "earthquake", "rainbow", "bubbles", "goldWave", "fireIce", "blackout", "tornado", "fireworks", "titan", "zeroG", "dance", "storm", "memeRain", "confetti", "shockwave", "spin", "launch" } do
		fxOn(id, true)
		advance(2.5)
		if not (busy(sortGui.Root.AbuseBack) or busy(sortGui.Root.AbuseFront)) then
			table.insert(looks, id)
		end
		snapshot("table-fx-" .. id)
		fxOn(id, false)
		advance(1)
	end
	check("every effect has its own look over the sorting table", #looks == 0, table.concat(looks, ", "))
	fxOn("galaxy", true)
	advance(1)
	check("an effect on, at the table: the ribbon says so", textOnScreen("GALAXY SKY · GOLDEN PIECES") ~= nil)
	fxOn("galaxy", false)
	advance(1)
	check("nothing on: no ribbon", textOnScreen("GOLDEN PIECES") == nil)
	serverSays("Table", { op = "left" })
	advance(3)
	check("no errors in Build 53's screens", #errors == 0, errors[1])
end

---------------------------------------------------------------------------------------------------
-- Build 54: Admin Abuse as a show: the opening, the drop, the owner's hologram, the realms, the
-- owner's gifts and the finale
---------------------------------------------------------------------------------------------------
;(function() -- (its own function: the file has used up its room for top-level names)
	local Lighting = game:GetService("Lighting")
	local HouseEvents = module("ReplicatedStorage", "Shared", "HouseEvents")
	local show = function()
		return playerGui:FindFirstChild("MaisonAbuseShow")
	end
	local function part(name)
		local s = show()
		return s and s:FindFirstChild(name)
	end
	local function abuse(on, mega)
		if on then
			workspace:SetAttribute("AbuseUntil", workspace:GetServerTimeNow() + 900)
			workspace:SetAttribute("AbuseSince", os.time())
			workspace:SetAttribute("AbuseMega", if mega then true else nil)
		else
			workspace:SetAttribute("AbuseUntil", nil)
			workspace:SetAttribute("AbuseSince", nil)
			workspace:SetAttribute("AbuseMega", nil)
			workspace:SetAttribute("AbuseRealm", nil)
		end
		signalOf(workspace, "attr:AbuseUntil"):Fire()
	end
	local function realm(id)
		workspace:SetAttribute("AbuseRealm", id)
		workspace:SetAttribute("AbuseRealmAt", os.time())
		signalOf(workspace, "attr:AbuseRealm"):Fire()
	end
	LocalPlayer:SetAttribute("Gilt", 1000)
	advance(1)
	-- The opening.
	serverSays("Salute", { op = "abuseShow", stage = "intro", mega = false, by = "XxxXxxX_77797" })
	abuse(true, false)
	realm("gilded")
	advance(1.2)
	check("the opening: the screen goes cinematic, bars top and bottom", part("Opening") ~= nil and part("Opening"):FindFirstChild("BarTop") ~= nil)
	check("...a transmission from the owner: their name, and what they're doing", textOnScreen("XXXXXXX_77797") ~= nil and textOnScreen("IS ABUSING THEIR POWERS") ~= nil and textOnScreen("INCOMING TRANSMISSION") ~= nil)
	check("...and nothing slammed onto the screen yet (that's the drop)", part("Opening"):FindFirstChild("Title") == nil)
	snapshot("abuse-opening")
	advance(Config.data.Admin.show.dropAt - 1.2 + 0.6)
	local title = part("Opening") and part("Opening"):FindFirstChild("Title")
	check("the drop: ADMIN ABUSE slammed onto the screen, and what it brings", title ~= nil and title.Text == "ADMIN ABUSE" and textOnScreen("GIFTS FROM THE OWNER") ~= nil)
	check("...the transmission gone", textOnScreen("INCOMING TRANSMISSION") == nil)
	advance(0.8)
	snapshot("abuse-drop")
	advance(Config.data.Admin.show.seconds)
	check("after the opening the screen is the house's again", part("Opening") == nil)
	check("and the owner says it's on", textOnScreen("ADMIN ABUSE IS ON") ~= nil)
	check("the gilded night's colours are over the house", Lighting:FindFirstChild("AbuseRealm") ~= nil)
	advance(6)
	-- A surprise cast by the owner: the hologram.
	serverSays("Salute", { op = "abuseFX", id = "meteor", by = "XxxXxxX_77797", seconds = 18 })
	advance(1.2)
	check("a surprise: the owner's hologram casts it (named, with its glyph)", textOnScreen("cast ☄️ METEOR SHOWER!") ~= nil and textOnScreen("THE OWNER") ~= nil)
	snapshot("owner-cameo")
	advance(5)
	-- The owner's gift.
	invokeResults.AbuseGiftAsk = { ok = true, gilt = 120, crown = true, count = 3 }
	serverSays("Salute", { op = "abuseGift", id = 7, gilt = 40, crown = true, number = 3, seconds = 25 })
	advance(1)
	check("a gift from the owner: a card to open, saying what's in it", part("Gift") ~= nil and textOnScreen("A GIFT FROM XXXXXXX_77797") ~= nil and textOnScreen("+40 GILT") ~= nil and textOnScreen("THE ADMIN'S CROWN") ~= nil)
	snapshot("abuse-gift")
	local before = #sent
	check("the gift opens with a press", press("OPEN IT!"))
	advance(0.3)
	local asked = sent[#sent]
	check("...which asks the server (the gift's id, nothing else)", #sent > before and asked.remote == "AbuseGiftAsk" and asked.message[1].op == "open" and asked.message[1].id == 7)
	check("...and shows what it paid", textOnScreen("+120 GILT") ~= nil and textOnScreen("THE CROWN") ~= nil)
	snapshot("abuse-gift-open")
	advance(3)
	check("then the card goes", part("Gift") == nil)
	invokeResults.AbuseGiftAsk = { ok = false, why = "That gift has gone." }
	serverSays("Salute", { op = "abuseGift", id = 8, gilt = 40, crown = false, number = 4, seconds = 25 })
	advance(1)
	press("OPEN IT!")
	advance(0.3)
	check("a gift that's gone says so (nothing paid on this screen)", textOnScreen("That gift has gone.") ~= nil)
	advance(3)
	serverSays("Salute", { op = "abuseGift", id = 9, gilt = 40, crown = false, number = 5, seconds = 6 })
	advance(8)
	check("a gift left unopened goes when its time is up", part("Gift") == nil)
	-- Mega Abuse: the realms.
	abuse(false)
	advance(12)
	serverSays("Salute", { op = "abuseShow", stage = "intro", mega = true, by = "XxxXxxX_77797" })
	abuse(true, true)
	realm("cosmos")
	advance(1.2)
	check("Mega Abuse's opening: the owner has broken the multiverse", textOnScreen("HAS BROKEN THE MULTIVERSE") ~= nil)
	advance(Config.data.Admin.show.dropAt)
	title = part("Opening") and part("Opening"):FindFirstChild("Title")
	check("...MEGA ABUSE at the drop", title ~= nil and title.Text == "MEGA ABUSE")
	advance(Config.data.Admin.show.seconds - Config.data.Admin.show.dropAt + 1.2)
	check("after the opening, the first realm is named", textOnScreen("THE COSMOS") ~= nil)
	check("...and the house is in its colours", Lighting:FindFirstChild("AbuseRealm") ~= nil)
	advance(5)
	realm("candy")
	advance(0.9)
	check("a new realm: the shift, and its name", textOnScreen("SUGAR RUSH") ~= nil and textOnScreen("ENTERING") ~= nil)
	advance(1)
	snapshot("realm-shift")
	advance(5)
	for _, id in { "midas", "neon", "abyss", "frost" } do
		realm(id)
		advance(1)
		check("the realm " .. id .. " is drawn", Lighting:FindFirstChild("AbuseRealm") ~= nil and textOnScreen(HouseEvents.realmById[id].name) ~= nil)
		advance(4)
	end
	-- The finale, with this guest's haul.
	LocalPlayer:SetAttribute("Gilt", 3450)
	abuse(false)
	advance(1.5)
	check("the finale: it's over, thank you, and the guest's haul", (textOnScreen("ADMIN ABUSE IS OVER") ~= nil or textOnScreen("THAT'S A WRAP") ~= nil) and textOnScreen("YOUR HAUL") ~= nil)
	advance(3)
	check("...the Gilt they won, the gifts they opened, the realms they saw", textOnScreen("GILT") ~= nil and textOnScreen("REALMS VISITED") ~= nil)
	snapshot("abuse-finale")
	check("the owner waves goodbye", textOnScreen("Thank you for coming") ~= nil or textOnScreen("See you at the next Admin Abuse") ~= nil)
	check("the realm's colours are gone", Lighting:FindFirstChild("AbuseRealm") == nil)
	advance(12)
	-- Arriving while it's on (no opening heard): a welcome.
	abuse(true, false)
	advance(2.5)
	check("arriving during Admin Abuse: a welcome, saying what's on", textOnScreen("YOU ARRIVED DURING ADMIN ABUSE") ~= nil)
	snapshot("abuse-arrived")
	abuse(false)
	advance(12)
	-- With the owner's avatar (a stand-in rig here): the hologram's portrait, the giant over the
	-- house, and the owner's army.
	local OwnerCameo = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "OwnerCameo")
	local AbuseFX = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "AbuseFX")
	local rig = Instance.new("Model")
	rig.Name = "MaisonOwnerAvatar"
	local hum = Instance.new("Humanoid")
	hum.Parent = rig
	for _, name in { "HumanoidRootPart", "Head", "UpperTorso" } do
		local bit = Instance.new("Part")
		bit.Name = name
		bit.Size = roblox.Vector3.new(2, 2, 1)
		bit.Parent = rig
	end
	rig.PrimaryPart = rig.HumanoidRootPart
	local realTemplate = OwnerCameo.template
	OwnerCameo.template = function()
		return rig
	end
	OwnerCameo.say("cast ☄️ METEOR SHOWER!", "point", 4)
	advance(1)
	check("the hologram draws the owner's own avatar (in a 3D window)", find(playerGui, function(d)
		return d:IsA("ViewportFrame") and d.Name == "Portrait"
	end) ~= nil)
	advance(5)
	abuse(true, true)
	advance(2.5)
	local giant = workspace.MaisonLocal:FindFirstChild("OwnerColossus")
	check("the owner stands giant over the house, with ADMIN ABUSE in the sky over them", giant ~= nil and giant:FindFirstChild("Marquee", true) ~= nil)
	AbuseFX.play("ownerArmy", 6)
	advance(2.5)
	local copies = 0
	for _, d in workspace.MaisonLocal:GetDescendants() do
		if d.Name == "OwnerCopy" then
			copies += 1
		end
	end
	check("the owner's army: a ring of the owner round the guest", copies == 12, copies)
	advance(6)
	copies = 0
	for _, d in workspace.MaisonLocal:GetDescendants() do
		if d.Name == "OwnerCopy" then
			copies += 1
		end
	end
	check("...gone when it's over", copies == 0, copies)
	abuse(false)
	advance(8)
	check("the giant goes when Admin Abuse ends", workspace.MaisonLocal:FindFirstChild("OwnerColossus") == nil)
	OwnerCameo.template = realTemplate
	check("no errors in Build 54's show", #errors == 0, errors[1])
end)()

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
