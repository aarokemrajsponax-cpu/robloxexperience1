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
-- The device to play as, for snapshots on every screen size: `lune run tests/client.luau full
-- <folder> phone` (a touch screen of its size; the checks are written for the desktop, so expect
-- a few to read as failed there).
-- (A global, not a local: the test runs at Luau's limit of 200 locals in one function.)
DEVICE = (function()
	local devices = {
		desktop = { size = Vector2.new(1280, 720), touch = false },
		laptop = { size = Vector2.new(1366, 768), touch = false },
		["phone-small"] = { size = Vector2.new(667, 375), touch = true },
		phone = { size = Vector2.new(844, 390), touch = true },
		["phone-big"] = { size = Vector2.new(932, 430), touch = true },
		tablet = { size = Vector2.new(1180, 820), touch = true },
	}
	return devices[process.args[3] or "desktop"] or devices.desktop
end)()

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

-- (Lune seeds math.random afresh every run; a fixed seed makes every run the same. SEED=n tries
-- another. TRACE=1 names each check as it's made, TRACE=timers every timer too: where a run that
-- stops short got to.)
math.randomseed(tonumber(process.env.SEED) or 1)
local TRACE = process.env.TRACE

local passed, failed = 0, 0
local function check(name: string, ok: boolean, detail: any?)
	if TRACE then
		require("@lune/stdio").ewrite("check: " .. name .. "\n")
	end
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
		if TRACE == "timers" then
			local okInfo, src, line = pcall(function()
				if type(t.fn) == "thread" then
					return debug.info(t.fn, 1, "sl")
				end
				return debug.info(t.fn, "sl")
			end)
			require("@lune/stdio").ewrite(string.format("timer %.2f %s:%s\n", now, tostring(okInfo and src), tostring(okInfo and line)))
		end
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
roblox.implementMethod("WorldRoot", "BulkMoveTo", function(_, parts, cfs)
	for i, p in parts do
		p.CFrame = cfs[i]
	end
end)
local function toScreen(cam, p)
	local vp, tx, ty = lens(cam)
	local rel = cam.CFrame:PointToObjectSpace(p)
	local nx, ny = (rel.X / -rel.Z) / tx, (rel.Y / -rel.Z) / ty
	return Vector2.new((nx + 1) / 2 * vp.X, (1 - ny) / 2 * vp.Y)
end
-- (As Roblox's: the point on screen, its depth in front of the camera, and whether it's in view.)
roblox.implementMethod("Camera", "WorldToViewportPoint", function(self, p)
	local depth = -self.CFrame:PointToObjectSpace(p).Z
	local at = toScreen(self, p)
	local vp = self.ViewportSize
	return Vector3.new(at.X, at.Y, depth), depth > 0 and at.X >= 0 and at.X <= vp.X and at.Y >= 0 and at.Y <= vp.Y
end)

---------------------------------------------------------------------------------------------------
-- The DataModel, services and the local guest
---------------------------------------------------------------------------------------------------
local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local camera = Instance.new("Camera")
camera.Parent = workspace
workspace.CurrentCamera = camera
camera.ViewportSize = DEVICE.size
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
	TouchEnabled = DEVICE.touch,
	KeyboardEnabled = not DEVICE.touch,
	MouseEnabled = not DEVICE.touch,
	GamepadEnabled = false,
	PreferredInput = if DEVICE.touch then EnumShim.PreferredInput.Touch else EnumShim.PreferredInput.KeyboardAndMouse,
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
				-- (A check that wants the server to answer each ask on its own sets a function.)
				local r = invokeResults[name]
				if type(r) == "function" then
					return r(...)
				end
				return r
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
	-- (The server's clock, as GetServerTimeNow has it: never the real one, so a run doesn't
	-- depend on the time of day it starts.)
	time = function(t: any?)
		if t ~= nil then
			return os.time(t)
		end
		return 1790000000 + math.floor(now)
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
	-- (Lune's NumberSequence.new(a, b) loses b; Roblox's runs from a to b.)
	NumberSequence = {
		new = function(a: any, b: any?, ...: any)
			if type(a) == "number" and type(b) == "number" then
				return roblox.NumberSequence.new({ roblox.NumberSequenceKeypoint.new(0, a), roblox.NumberSequenceKeypoint.new(1, b) })
			end
			return if b == nil then roblox.NumberSequence.new(a) else roblox.NumberSequence.new(a, b, ...)
		end,
	},
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

-- The staff's rigs are Roblox's own R15 bodies, which Lune can't make: here they stand in as blocks
-- of the same proportions, jointed the same way (the holiday games' hosts, Santa and his elves).
local function standInRig(name, spec, floor, parent)
	-- (Stood on `floor`, as Rig.build stands its rigs: the root at hip height plus half its own; at
	-- the guests' scale, as Rig.build scales them.)
	local k = requireModule(rootProxy.ReplicatedStorage.Shared.Config).data.Movement.guestScale * (spec.heightScale or 1)
	local home = floor + Vector3.new(0, 3 * k, 0)
	local m = Instance.new("Model")
	m.Name = name
	local skin = spec.skin or roblox.Color3.fromRGB(232, 196, 170)
	local coat = spec.coat or roblox.Color3.fromRGB(20, 20, 24)
	local trousers = coat:Lerp(roblox.Color3.new(0, 0, 0), 0.35)
	local parts = {}
	local function part(pname, size, y, x, colour)
		local p = Instance.new("Part")
		p.Name = pname
		p.Size = size * k
		p.CFrame = home * CFrame.new((x or 0) * k, y * k, 0)
		p.Position = p.CFrame.Position
		p.Color = colour
		p.Material = roblox.Enum.Material.SmoothPlastic
		p.Parent = m
		parts[pname] = p
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), 0, 0, coat)
	root.Transparency = 1
	root.Anchored = true
	part("LowerTorso", Vector3.new(2, 0.4, 1), -0.8, 0, coat)
	part("UpperTorso", Vector3.new(2, 1.6, 1), 0.2, 0, coat)
	part("Head", Vector3.new(1.2, 1.2, 1.2), 1.6, 0, skin)
	for _, s in { { "Left", -1 }, { "Right", 1 } } do
		part(s[1] .. "UpperArm", Vector3.new(1, 1, 1), 0.5, s[2] * 1.5, coat)
		part(s[1] .. "LowerArm", Vector3.new(1, 0.8, 1), -0.4, s[2] * 1.5, coat)
		part(s[1] .. "Hand", Vector3.new(1, 0.3, 1), -0.95, s[2] * 1.5, spec.gloves or skin)
		part(s[1] .. "UpperLeg", Vector3.new(1, 1, 1), -1.5, s[2] * 0.5, trousers)
		part(s[1] .. "LowerLeg", Vector3.new(1, 0.8, 1), -2.4, s[2] * 0.5, trousers)
		part(s[1] .. "Foot", Vector3.new(1, 0.2, 1), -2.9, s[2] * 0.5, roblox.Color3.fromRGB(14, 12, 12))
	end
	-- Each joint where the two parts meet (as an R15 rig's are).
	local function joint(jname, p0name, p1name, top)
		local p0, p1 = parts[p0name], parts[p1name]
		local at = p1.CFrame * CFrame.new(0, (if top then 1 else -1) * p1.Size.Y / 2, 0)
		local j = Instance.new("Motor6D")
		j.Name = jname
		j.Part0 = p0
		j.Part1 = p1
		j.C0 = p0.CFrame:ToObjectSpace(at)
		j.C1 = p1.CFrame:ToObjectSpace(at)
		j.Parent = p1
	end
	joint("Root", "HumanoidRootPart", "LowerTorso", true)
	joint("Waist", "LowerTorso", "UpperTorso", false)
	joint("Neck", "UpperTorso", "Head", false)
	for _, s in { "Left", "Right" } do
		joint(s .. "Shoulder", "UpperTorso", s .. "UpperArm", true)
		joint(s .. "Elbow", s .. "UpperArm", s .. "LowerArm", true)
		joint(s .. "Wrist", s .. "LowerArm", s .. "Hand", true)
		joint(s .. "Hip", "LowerTorso", s .. "UpperLeg", true)
		joint(s .. "Knee", s .. "UpperLeg", s .. "LowerLeg", true)
		joint(s .. "Ankle", s .. "LowerLeg", s .. "Foot", true)
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2 * k
	humanoid.Parent = m
	Instance.new("Animator").Parent = humanoid
	m.PrimaryPart = root
	m.Parent = parent
	return { model = m, root = root, humanoid = humanoid }
end

local stubs = {
	["ReplicatedStorage.Shared.Remotes"] = RemotesStub,
	["ServerScriptService.Server.Staff.Rig"] = { build = standInRig },
	-- (The holiday games read a guest's saved record from here; this screen has none.)
	["ServerScriptService.Server.Profiles"] = {
		get = function()
			return nil
		end,
	},
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
	-- (A module's path starts at game when it was first reached from game, else at its service.)
	local stub = stubs[(string.gsub(rawget(proxy, "__path"), "^game%.", ""))]
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
-- (Headings are set in capitals, accents and all: "SOIRÉE" reads as "soirée".)
local LOWER_ACCENTS = {
	["À"] = "à", ["Á"] = "á", ["Â"] = "â", ["Ä"] = "ä", ["Æ"] = "æ", ["Ç"] = "ç", ["È"] = "è", ["É"] = "é",
	["Ê"] = "ê", ["Ë"] = "ë", ["Ì"] = "ì", ["Í"] = "í", ["Î"] = "î", ["Ï"] = "ï", ["Ñ"] = "ñ", ["Ò"] = "ò",
	["Ó"] = "ó", ["Ô"] = "ô", ["Ö"] = "ö", ["Ù"] = "ù", ["Ú"] = "ú", ["Û"] = "û", ["Ü"] = "ü", ["Œ"] = "œ",
}
local function norm(text: string): string
	local low = string.lower(string.gsub(text, "%s+", ""))
	return (string.gsub(low, "[\195\197][\128-\191]", function(ch)
		return LOWER_ACCENTS[ch] or ch
	end))
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
			if inst:IsA("ScrollingFrame") then
				local cp = get(inst, "CanvasPosition")
				if cp and (cp.X ~= 0 or cp.Y ~= 0) then
					n.canvas = { cp.X, cp.Y }
				end
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
				local trunc = get(inst, "TextTruncate")
				n.truncate = if trunc then trunc.Name else "None"
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
			n.mode = get(inst, "ApplyStrokeMode") and inst.ApplyStrokeMode.Name or nil
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
	-- EXPORT_AT=<name> EXPORT=<file>: the world on this screen at that moment, for the 3D viewer
	-- (tools/view): what a show has built round the guest, say.
	if process.env.EXPORT_AT == name and process.env.EXPORT then
		-- (The server sets the light of the evening; here, a night like the house's.)
		local L = game:GetService("Lighting")
		for prop, value in { ClockTime = 20.5, Brightness = 1, Ambient = roblox.Color3.fromRGB(70, 60, 55), OutdoorAmbient = roblox.Color3.fromRGB(90, 85, 100), ExposureCompensation = 0 } do
			if not pcall(function()
				return L[prop]
			end) then
				L[prop] = value
			end
		end
		require("../tools/view/export")(workspace, L, process.env.EXPORT)
	end
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
-- (This harness runs at 20 frames a second, which Quality takes for a struggling screen: the
-- shows are tested at full strength, and its stepping down is tested on its own, below.)
module("StarterPlayer", "StarterPlayerScripts", "Client", "Quality").pin(1)

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
	guide = true,
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

-- The welcome: WELCOME and the guest's name on their own screen (a first evening: a line about the
-- Concierge), then a gold arrow to the Concierge, who shows new guests round.
do
	local State = module("StarterPlayer", "StarterPlayerScripts", "Client", "State")
	local Welcome = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Welcome")
	local Guide = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "ConciergeGuide")
	local function spelled(gui)
		local word = gui and gui:FindFirstChild("Word", true)
		if not word then
			return ""
		end
		local letters = {}
		for _, l in word:GetChildren() do
			if l:IsA("TextLabel") then
				table.insert(letters, l)
			elseif l:IsA("Frame") and l.Name == "Gap" then
				table.insert(letters, { LayoutOrder = l.LayoutOrder, Text = " " })
			end
		end
		table.sort(letters, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		local out = ""
		for _, l in letters do
			out ..= l.Text
		end
		return out
	end
	local function sameSize(gui)
		local word = gui and gui:FindFirstChild("Word", true)
		local size
		for _, l in (word and word:GetChildren() or {}) do
			if l:IsA("TextLabel") then
				if l.TextScaled or (size and l.TextSize ~= size) then
					return false
				end
				size = l.TextSize
			end
		end
		return size ~= nil
	end
	local welcomeGui = playerGui:FindFirstChild("MaisonWelcome")
	check("a new guest is welcomed on their own screen: WELCOME and their name", welcomeGui ~= nil and spelled(welcomeGui) == "WELCOME" and textOnScreen("ADA") ~= nil, spelled(welcomeGui))
	check("...every letter lit, the same size, in gold", sameSize(welcomeGui) and (function()
		for _, l in welcomeGui.Welcome.Word:GetChildren() do
			if l:IsA("TextLabel") and (l.TextTransparency > 0.01 or not l:FindFirstChild("Metal")) then
				return false
			end
		end
		return true
	end)())
	check("...and on a first evening, the line about the Concierge and the gold arrow", textOnScreen("The Concierge shows new guests round") ~= nil)
	check("...drawn on this guest's screen only (their own PlayerGui; the ring of light in their own camera)", welcomeGui and welcomeGui.Parent == playerGui)
	advance(1)
	snapshot("welcome")

	-- The Concierge at the lectern, as the server's rig arrives on this screen; the guest across the
	-- Foyer, where new guests spawn.
	local home = Vector3.new(9, 3, 4.2) * GRAND()
	local cg = Instance.new("Model")
	cg.Name = "Concierge"
	cg:SetAttribute("Staff", "Concierge")
	local croot = Instance.new("Part")
	croot.Name = "HumanoidRootPart"
	croot.Size = Vector3.new(2, 2, 1)
	croot.CFrame = CFrame.new(home + Vector3.new(0, 3, 0))
	croot.Parent = cg
	local chead = Instance.new("Part")
	chead.Name = "Head"
	chead.Size = Vector3.new(1, 1, 1)
	chead.CFrame = CFrame.new(home + Vector3.new(0, 4.5, 0))
	chead.Parent = cg
	local speak = Instance.new("ProximityPrompt")
	speak.Name = "SpeakPrompt"
	speak.Parent = chead
	cg.PrimaryPart = croot
	cg.Parent = workspace
	local was, camWas = root.Position, camera.CFrame
	local function moveGuest(p)
		root.CFrame = CFrame.new(p)
		root.Position = p
	end
	local spawnAt = Vector3.new(-20, 6, 12) * GRAND()
	moveGuest(spawnAt)
	advance(2.5)
	check("a first evening: the gold arrow to the Concierge is up", Guide.active())
	local bb = playerGui:FindFirstChild("MaisonConciergeGuide")
	check("over the Concierge: THE CONCIERGE, follow the gold arrow to him, and a chevron", bb ~= nil and bb.Adornee == chead and bb.AlwaysOnTop == true and textOnScreen("Follow the gold arrow to him") ~= nil and bb:FindFirstChild("Chevron") ~= nil)
	-- Start here: the whole game in three plain steps, and Show me the way.
	advance(3)
	check("a new guest gets Start here: the game in three plain steps", textOnScreen("Meet the Concierge") ~= nil and textOnScreen("Sit at a table") ~= nil and textOnScreen("Sort the treasures") ~= nil and textOnScreen("Show me the way") ~= nil, textOnScreen("Meet the Concierge") ~= nil)
	snapshot("start-here")
	press("Show me the way")
	advance(0.6)
	check("...Show me the way closes it, and the arrow leads on", textOnScreen("Meet the Concierge") == nil and Guide.active())
	check("the card under the keys says the same: talk to the Concierge", textOnScreen("Talk to the Concierge") ~= nil)
	-- His key says what to pick, for a guest still new to the house.
	local PromptsM = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Prompts")
	speak.ObjectText = "The Concierge"
	check("the Concierge's key says Show me the house to a new guest", PromptsM.actionFor(speak) == "Show me the house")
	local folder = camera:FindFirstChild("MaisonConciergeGuide")
	local arrows = {}
	for _, p in (folder and folder:GetChildren() or {}) do
		if p:IsA("BasePart") then
			table.insert(arrows, p)
		end
	end
	check("on the floor: three gold chevrons, on this screen only (in the guest's camera)", #arrows == 6, #arrows)
	local first = folder and folder:FindFirstChild("GuideChevron1R")
	local firstL = folder and folder:FindFirstChild("GuideChevron1L")
	local toConcierge = (home - spawnAt) * Vector3.new(1, 0, 1)
	-- (The middle of the nearest chevron, between its two arms.)
	local middle = first and firstL and (first.CFrame.Position + firstL.CFrame.Position) / 2
	local toArrow = middle and (middle - spawnAt) * Vector3.new(1, 0, 1)
	check("...pointing the way to the Concierge", toArrow ~= nil and toConcierge.Unit:Dot(toArrow.Unit) > 0.999 and toArrow.Magnitude > 1.5 and toArrow.Magnitude < 4, toArrow and toConcierge.Unit:Dot(toArrow.Unit))
	local feetY = spawnAt.Y - humanoid.HipHeight - root.Size.Y / 2
	check("...lit, at the guest's feet", first ~= nil and first.Transparency < 0.7 and math.abs(first.CFrame.Position.Y - feetY) < 0.2, first and first.CFrame.Position.Y)
	-- The Concierge behind the camera: an arrow at the screen's edge; in view, it steps aside.
	local edge = playerGui:FindFirstChild("MaisonGuideEdge")
	camera.CFrame = CFrame.lookAt(spawnAt + Vector3.new(0, 6, 0), spawnAt + Vector3.new(0, 6, 0) - toConcierge)
	advance(0.1)
	check("the Concierge out of view: an arrow at the screen's edge points the way", edge ~= nil and edge.Arrow.Visible == true and edge.Label.Visible == true)
	camera.CFrame = CFrame.lookAt(spawnAt + Vector3.new(0, 6, 0), home + Vector3.new(0, 4, 0))
	advance(0.1)
	check("...and in view, the edge arrow steps aside", edge ~= nil and edge.Arrow.Visible == false)
	-- Close by: the floor arrows go, and the line says how to talk.
	moveGuest(home + Vector3.new(0, 3, 9))
	advance(0.2)
	local lit = 0
	for _, p in arrows do
		if p.Transparency < 1 then
			lit += 1
		end
	end
	check("close to the Concierge: what to pick, and the floor arrows go", textOnScreen("Press E: Show me the house") ~= nil and lit == 0, lit)
	-- Speaking to the Concierge: done, for good.
	services.ProximityPromptService.PromptTriggered:Fire(speak)
	advance(1)
	check("speaking to the Concierge: the arrow is done", not Guide.active() and playerGui:FindFirstChild("MaisonConciergeGuide") == nil and camera:FindFirstChild("MaisonConciergeGuide") == nil and playerGui:FindFirstChild("MaisonGuideEdge") == nil)
	check("...and doesn't come back", Guide.start() == false and not Guide.active())
	advance(4)
	check("the welcome goes by itself after a few seconds, with its ring of light", playerGui:FindFirstChild("MaisonWelcome") == nil and camera:FindFirstChild("MaisonWelcomeRing") == nil and root:FindFirstChild("MaisonWelcomeSparkles") == nil)
	cg:Destroy()
	moveGuest(was)
	camera.CFrame = camWas

	-- A returning guest: WELCOME BACK, and no arrow.
	Welcome.show("Ben", false)
	advance(2)
	local back = playerGui:FindFirstChild("MaisonWelcome")
	check("a returning guest: WELCOME BACK and their name", back ~= nil and spelled(back) == "WELCOME BACK" and textOnScreen("BEN") ~= nil and sameSize(back), spelled(back))
	check("...without the Concierge's line", textOnScreen("The Concierge shows new guests round") == nil)
	snapshot("welcome-back")
	advance(2.2)
	check("...and it goes sooner", playerGui:FindFirstChild("MaisonWelcome") == nil)
	-- On a phone, it fits; with the Movement setting on Still, the words alone.
	camera.ViewportSize = Vector2.new(390, 844)
	signalOf(camera, "prop:ViewportSize"):Fire()
	local movement = State.settings.movement
	State.settings.movement = "Still"
	Welcome.show("Ada", true)
	advance(2)
	local phone = playerGui:FindFirstChild("MaisonWelcome")
	local holder = phone and phone:FindFirstChild("Welcome")
	local letters, width = 0, 0
	for _, l in (holder and holder.Word:GetChildren() or {}) do
		if l:IsA("TextLabel") then
			letters += 1
			width = l.TextSize
		end
	end
	check("on a phone the word fits across the screen", letters == 7 and width * 7 * 1.2 <= 390 - 40, width)
	local flew = 0
	for _, d in (holder and holder:GetDescendants() or {}) do
		if d.Name == "Spark" or d.Name == "Mote" then
			flew += 1
		end
	end
	check("with Movement on Still: no sparks, no sweep", flew == 0 and holder ~= nil and holder.Sweep.Glint.Visible == false, flew)
	check("...and the line about the Concierge wraps rather than shrinking", holder ~= nil and holder.Line.TextWrapped == true and holder.Line.Size.Y.Offset >= 30)
	snapshot("welcome-phone")
	State.settings.movement = movement
	advance(6)
	camera.ViewportSize = DEVICE.size
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.5)
	check("no errors in the welcome", #errors == 0, errors[1])
end

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
	-- (A hip joint, as the server's R15 rig has, to see the walk.)
	local cleg = Instance.new("Part")
	cleg.Name = "LeftUpperLeg"
	cleg.Size = Vector3.new(0.8, 1.6, 0.8)
	cleg.CFrame = CFrame.new(home + Vector3.new(-0.5, 1.6, 0))
	cleg.Parent = concierge
	local chip = Instance.new("Motor6D")
	chip.Name = "LeftHip"
	chip.Part0 = croot
	chip.Part1 = cleg
	chip.C0 = CFrame.new(-0.5, -0.6, 0)
	chip.Parent = cleg
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
	local stride = 0
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
			local hip = guide and guide:FindFirstChild("LeftHip", true)
			if hip and state == "walking" then
				local _, _, rz = hip.C0:ToEulerAnglesXYZ()
				local rx = select(1, hip.C0:ToEulerAnglesXYZ())
				stride = math.max(stride, math.abs(rx) + math.abs(rz))
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
	check("walking, not gliding: the Concierge's legs swing with every step", stride > math.rad(10), math.deg(stride))
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
	UserInputService.PreferredInput = if DEVICE.touch then EnumShim.PreferredInput.Touch else EnumShim.PreferredInput.KeyboardAndMouse
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
	local lit = Sort.bin(caseId):FindFirstChildOfClass("UIStroke").Thickness >= 2
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
check("at a table, what's on shows on the room's line, not across the cloth", string.find(sortGui.Root.Header.Room.Text, string.format("Golden Hour %d:", ((workspace:GetAttribute("Event_goldenHour") or 0) - workspace:GetServerTimeNow()) // 60), 1, true) ~= nil and playerGui.MaisonHud:FindFirstChild("HouseEvents", true).Visible == false, sortGui.Root.Header.Room.Text)
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
	-- A phone whose camera viewport is only the safe middle of a wider screen (rounded corners,
	-- a camera cut-out): the table stands in the middle of the whole screen, clear of both edges.
	local SortM = module("StarterPlayer", "StarterPlayerScripts", "Client", "Table", "SortScreen")
	SortM.screen = function()
		return Vector2.new(DEVICE.size.X + 260, DEVICE.size.Y)
	end
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.3)
	local frameL = tray.Position.X.Offset
	local frameR = DEVICE.size.X + 260 - (tray.Position.X.Offset + tray.Size.X.Offset)
	check("on a phone wider than its viewport, the table stands in the middle, clear of both edges", math.abs(frameL - frameR) <= 2 and frameL >= 130, frameL .. " / " .. frameR)
	SortM.screen = function()
		return nil
	end
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.3)
	check("...and on a plain screen, in the middle as before", math.abs(tray.Position.X.Offset - (DEVICE.size.X - tray.Position.X.Offset - tray.Size.X.Offset)) <= 2)
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
	camera.ViewportSize = DEVICE.size
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
advance(2.5)
snapshot("round")
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
	check("the case goes dark again when you let go", Sort.bin(wrongCase):FindFirstChildOfClass("UIStroke").Thickness < 2)
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
		advance(0.8)
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
	-- Into its case on a curve: a piece filed from the cloth (by key, tap or pad) rises off it,
	-- sails over and comes down into its case trailing light, and the case counts it as it lands.
	do
		local SortScreenModule = module("StarterPlayer", "StarterPlayerScripts", "Client", "Table", "SortScreen")
		local p = round2[10]
		local card = Sort.card(10)
		local from = Sort.centre(card)
		local count = tonumber(Sort.bin(p.case).Count.Text)
		local landed = 0
		local was = SortScreenModule.onLanded
		SortScreenModule.onLanded = function(...)
			landed += 1
			return was(...)
		end
		SortScreenModule.correct(10, p.case, 20, 1)
		local highest, trailSeen, rising = from.Y, false, false
		for i = 1, 8 do
			advance(0.04)
			local at = Sort.centre(card)
			highest = math.min(highest, at.Y)
			trailSeen = trailSeen or find(sortGui.Root.Effects, function(d)
				return d.Name == "FlightGlow" and d.Visible
			end) ~= nil
			if i == 2 then
				rising = at.Y < from.Y
			end
			if i == 4 then
				snapshot("sort-flight")
			end
		end
		check("a filed piece rises off the cloth first (a toss, not a slide)", rising and highest < from.Y - 10, from.Y - highest)
		check("and trails light in its case's colour as it flies", trailSeen)
		advance(0.6)
		check("then lands in its case, which counts it", card.Visible == false and tonumber(Sort.bin(p.case).Count.Text) == count + 1 and landed == 1, Sort.bin(p.case).Count.Text)
		SortScreenModule.onLanded = was
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
-- A message that never lands never leaves a table stuck (AJKR's Salon froze after round XIX: the
-- server never heard one filing, so its round never ended while the screen said 0 pieces left).
do
	local function caseCount(caseId)
		return tonumber(Sort.bin(caseId).Count.Text) or 0
	end
	-- The drag above filed piece 1 and nobody answered: the table asks where things stand.
	local syncs = sentOps("Table", "sync")
	advance(3)
	check("a filing with no answer: the table asks the server where things stand", sentOps("Table", "sync") == syncs + 1, sentOps("Table", "sync") - syncs)
	-- A fresh round, every answer under the test's control: piece 1 answered, piece 2 never heard.
	local hand = pieceList(4, cases)
	serverSays("Table", { op = "deal", round = 3, room = "salon", mode = "room", cases = cases, pieces = hand, score = 500 })
	advance(2)
	Sort.drag(1, hand[1].case)
	advance(0.3)
	serverSays("Table", { op = "filed", uid = 1, case = hand[1].case, correct = true, points = 10, setBonus = 0, penalty = 0, score = 510, streak = 1, multiplier = 1, runLength = 1, remaining = 3 })
	advance(0.5)
	local before = caseCount(hand[2].case)
	Sort.drag(2, hand[2].case)
	advance(1)
	check("piece 2 goes into its case (predicted)", caseCount(hand[2].case) == before + 1 and Sort.card(2).Visible == false)
	syncs = sentOps("Table", "sync")
	advance(2.5)
	check("...no answer for it: the table asks", sentOps("Table", "sync") == syncs + 1, sentOps("Table", "sync") - syncs)
	serverSays("Table", { op = "sync", state = "playing", round = 3, room = "salon", mode = "room", cases = cases, pieces = { hand[2], hand[3], hand[4] }, score = 510, streak = 1, runLength = 1, lastCase = hand[1].case, multiplier = 1, remaining = 3 })
	advance(1)
	check("...the server never filed it, so it comes back to the felt, and its case lets it go", Sort.card(2).Visible and caseCount(hand[2].case) == before, string.format("%s %d/%d", tostring(Sort.card(2).Visible), caseCount(hand[2].case), before))
	check("...piece 1, which the server did file, stays in its case", Sort.card(1).Visible == false)
	advance(3)
	check("once it agrees with the server it stops asking", sentOps("Table", "sync") == syncs + 1, sentOps("Table", "sync") - syncs)
	local filesBefore = sentOps("Table", "file")
	Sort.drag(2, hand[2].case)
	advance(0.3)
	check("the piece can be sorted again", sentOps("Table", "file") == filesBefore + 1)
	for i = 2, 4 do
		serverSays("Table", { op = "filed", uid = i, case = hand[i].case, correct = true, points = 10, setBonus = 0, penalty = 0, score = 500 + i * 10, streak = i, multiplier = 1, runLength = 1, remaining = 4 - i })
		advance(0.1)
	end
	local roundEnd = { op = "roundEnd", round = 3, room = "salon", mode = "room", score = 560, grade = "Polished", bestStreak = 4, bonus = { perfect = 0, streak = 20, time = 0 }, last = false }
	serverSays("Table", roundEnd)
	advance(3)
	check("round III's card", textOnScreen("Next round") ~= nil)
	-- Next round pressed, and the server never hears it: the screen asks, and sends it again.
	local nexts = sentOps("Table", "next")
	press("Next round")
	advance(0.5)
	check("Next round is sent", sentOps("Table", "next") == nexts + 1)
	syncs = sentOps("Table", "sync")
	advance(3)
	check("no deal after Next round: the table asks where things stand", sentOps("Table", "sync") == syncs + 1, sentOps("Table", "sync") - syncs)
	serverSays("Table", { op = "sync", state = "roundEnd", round = 3, score = 560, roundEnd = roundEnd })
	advance(0.5)
	check("...the server is still between rounds, so Next round goes again (no second press)", sentOps("Table", "next") == nexts + 2 and textOnScreen("Next round") == nil)
	serverSays("Table", { op = "deal", round = 4, room = "salon", mode = "room", cases = cases, pieces = pieceList(10, cases), score = 560 })
	advance(4)
	check("round IV is dealt, and nothing more is asked", #piecesFolder:GetChildren() == 10 and sentOps("Table", "sync") == syncs + 1 and sortGui.Root.Header.Stat_ROUND.Value.Text == "IV", sortGui.Root.Header.Stat_ROUND.Value.Text)
	-- A deal this screen never laid (the server is a round ahead): it lays the server's table.
	serverSays("Table", { op = "sync", state = "playing", round = 5, room = "salon", mode = "room", cases = cases, pieces = pieceList(12, cases), score = 640, streak = 3, runLength = 1, multiplier = 1, remaining = 12 })
	advance(2)
	check("a round the screen missed is laid from the server's table", #piecesFolder:GetChildren() == 12 and sortGui.Root.Header.Stat_ROUND.Value.Text == "V", sortGui.Root.Header.Stat_ROUND.Value.Text)
	-- Endless: long rounds and big scores fit their plaques.
	local Theme = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Theme")
	local function fits(name)
		local st = sortGui.Root.Header["Stat_" .. name]
		local v = st.Value
		return Theme.measure(v.Text, v.TextSize, v.FontFace).X <= st.Size.X.Offset, string.format("%s %q at %d in %d", name, v.Text, v.TextSize, st.Size.X.Offset)
	end
	-- (A numeral too long for its plaque at the smallest size shows in figures: XXXVIII on a phone
	-- held sideways, where the plaques are small, reads 38; a small phone stacks them, wide enough
	-- for CCCLXXXVIII.)
	for _, r in { { 19, "XIX", "19" }, { 20, "XX", "20" }, { 38, "XXXVIII", "38" }, { 49, "XLIX", "49" }, { 99, "XCIX", "99" }, { 388, "CCCLXXXVIII", "388" } } do
		serverSays("Table", { op = "deal", round = r[1], room = "salon", mode = "room", cases = cases, pieces = pieceList(17, cases), score = 12345678 })
		advance(1)
		local ok, why = fits("ROUND")
		local okScore, whyScore = fits("SCORE")
		local shown = sortGui.Root.Header.Stat_ROUND.Value.Text
		local score = sortGui.Root.Header.Stat_SCORE.Value.Text
		check("round " .. r[2] .. " is dealt and fits its plaque, as does a score in the millions (12,345,678, or 12.3M where it can't fit)", (shown == r[2] or shown == r[3]) and (score == "12,345,678" or score == "12.3M") and ok and okScore, why .. " · " .. whyScore)
	end
	-- Round 388's card, with a score in the millions: it opens, and Next round goes on.
	serverSays("Table", { op = "roundEnd", round = 388, room = "salon", mode = "room", score = 12345678, grade = "Flawless", bestStreak = 17, bonus = { perfect = 500, streak = 300, time = 0 }, last = false })
	advance(3)
	check("round 388's card opens", textOnScreen("Next round") ~= nil and #errors == 0, errors[1])
	nexts = sentOps("Table", "next")
	press("Next round")
	advance(0.5)
	check("...and Next round goes on", sentOps("Table", "next") == nexts + 1)
	serverSays("Table", { op = "deal", round = 389, room = "salon", mode = "room", cases = cases, pieces = pieceList(17, cases), score = 12345678 })
	advance(1)
	local shown389 = sortGui.Root.Header.Stat_ROUND.Value.Text
	check("round 389 is dealt", #piecesFolder:GetChildren() == 17 and (shown389 == "389" or shown389 == "CCCLXXXIX"), shown389)
	check("no errors when a message goes missing", #errors == 0, errors[1])
end
-- Chronos Defiance: the clock ran out (the server only says this in a timed room; the screen
-- shows what it's told). The card counts down the server's own window.
do
	local robux = utf8.char(0xE002)
	local offer = { op = "reviveOffer", left = 10, prompting = false, held = 0, price = 49, onSale = true, add = 15, boardsCount = false, score = 1240, boardScore = 1240, used = 0, usesLeft = 3, room = "The Obsidian Room", level = 3 }
	serverSays("Table", offer)
	advance(1)
	check("the revive card opens with the real countdown, naming its room (priced by the room)", textOnScreen("The Obsidian Room") ~= nil and (textOnScreen("0:09") ~= nil or textOnScreen("0:10") ~= nil))
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
check("the sorting screen stays clear: no rival's line under the cases", textOnScreen("points behind you") == nil and textOnScreen("points ahead of you") == nil and (sortGui.Root:FindFirstChild("Rival", true) == nil or sortGui.Root:FindFirstChild("Rival", true).TextTransparency >= 0.99))

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
check("after tonight's try: Keep playing (the room as it is), never a rehearsal", textOnScreen("Keep playing") ~= nil and textOnScreen("Rehearse") == nil)
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
snapshot("duel-play")
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
check("Ballroom: the countdown is announced (last call: no late joins)", textOnScreen("Lights Out begins in 30 seconds") ~= nil)
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
-- Standing in the Ballroom without a chair while it's open: Take a chair and Watch.
workspace:SetAttribute("BallroomState", "open")
root.Position = Vector3.new(61, 21, 90) * GRAND()
root.CFrame = CFrame.new(root.Position)
advance(1)
check("in the Ballroom without a chair, while it's open: Take a chair is offered", textOnScreen("Take a chair") ~= nil)
check("and Watch", press("Watch"))
advance(7)
check("watching drifts the camera", camera.CameraType == roblox.Enum.CameraType.Scriptable)
press("Take a chair")
check("Take a chair is sent", sentOps("Table", "nextEvening") == 1)
-- Closed: the key opens it (the purchase window, through the server).
workspace:SetAttribute("BallroomState", "closed")
advance(1)
check("closed: Open it now is offered", textOnScreen("Open it now") ~= nil)
press("Open it now")
check("Open it now asks the server (never opens it itself)", sentOps("Table", "openNow") == 1)
serverSays("Table", { op = "ballroomClosed", opensIn = 754, canOpen = true, price = 49 })
advance(1)
check("pressing a chair while closed: the offer, its price and when it opens", textOnScreen("The Ballroom is closed") ~= nil or textOnScreen("THE BALLROOM IS CLOSED") ~= nil)
snapshot("ballroom-closed")
press("Not now")
advance(1)
-- An evening in play: the Sabotage key, the panel, and what lands on you.
workspace:SetAttribute("BallroomState", "playing")
advance(1)
check("an evening in play: the Sabotage key, for a guest watching in the room", press("💣  Sabotage"))
check("...which asks the server for the tables", sentOps("Table", "sabotageInfo") == 1)
serverSays("Table", { op = "sabotageInfo", playing = true, left = 6, targets = { { seat = 4, name = "Ben", felt = 14, shield = false }, { seat = 9, name = "Stand-in", felt = 6, standIn = true }, { seat = 12, name = "Cleo", felt = 9, shield = true } }, prices = { bomb = 19, blackout = 29, freeze = 25, shield = 15, open = 49 }, credits = { bomb = 1 } })
advance(1)
check("the panel: the tables still lit, and each sabotage with its price (or held)", textOnScreen("felt 14 / 16") ~= nil and textOnScreen("1 held") ~= nil)
snapshot("sabotage")
press("Close")
serverSays("Table", { op = "sabotaged", kind = "blackout", by = "Ben", seconds = 6 })
advance(0.5)
check("a Blackout lands: the screen goes dark, saying who sent it", textOnScreen("from Ben") ~= nil)
snapshot("sabotaged")
advance(7)
workspace:SetAttribute("BallroomState", "closed")
root.Position = Vector3.new(0, 5, -40)
root.CFrame = CFrame.new(0, 5, -40)
advance(1)
check("leaving the Ballroom drops its keys and the camera", textOnScreen("Open it now") == nil and textOnScreen("Take a chair") == nil and camera.CameraType == roblox.Enum.CameraType.Custom)
check("no errors in the Ballroom", #errors == 0, errors[1])

---------------------------------------------------------------------------------------------------
-- 7. The panels
---------------------------------------------------------------------------------------------------
UserInputService.PreferredInput = if DEVICE.touch then EnumShim.PreferredInput.Touch else EnumShim.PreferredInput.KeyboardAndMouse
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
do
	local helpKey = find(playerGui, function(d)
		return d.Name == "HowToPlayKey"
	end)
	check("How to play: a key at the top right, beside Shop and Menu", helpKey ~= nil and helpKey.Visible == true and helpKey.Parent and helpKey.Parent.Name == "TopRight")
	if helpKey then
		signalOf(helpKey, "Activated"):Fire()
	end
	advance(1)
	check("How to play: the game in plain words", textOnScreen("How to play") ~= nil and textOnScreen("a sorting game in a grand house") ~= nil)
	check("...your first five minutes, step by step", textOnScreen("Go to a table") ~= nil and textOnScreen("Sort the treasures") ~= nil and textOnScreen("Earn Gilt") ~= nil and textOnScreen("Spend it") ~= nil)
	check("...five pages, and a Next key to read on", textOnScreen("Basics") ~= nil and textOnScreen("Sorting") ~= nil and textOnScreen("Rooms") ~= nil and textOnScreen("Extras") ~= nil and textOnScreen("Next: Sorting") ~= nil)
	snapshot("howto-basics")
	press("Next: Sorting")
	advance(0.6)
	check("Sorting: the six cases, each with what it holds", textOnScreen("WATCHES") ~= nil and textOnScreen("JEWELRY") ~= nil and textOnScreen("MONEY") ~= nil and textOnScreen("KEYS") ~= nil and textOnScreen("ACCESSORIES") ~= nil and textOnScreen("COLLECTIBLES") ~= nil and textOnScreen("Bars, notes, coins") ~= nil)
	check("...and how it works: moving a piece, a wrong case, the gold thread, rounds, clocks", textOnScreen("Moving a piece") ~= nil and textOnScreen("A wrong case") ~= nil and textOnScreen("thread of gold") ~= nil and textOnScreen("Bank the run") ~= nil and textOnScreen("Clocks") ~= nil)
	snapshot("howto-sorting")
	press("Rooms")
	advance(0.6)
	local places = { "The Salon", "The Velvet Room", "The Obsidian Room", "The Midnight Room", "The Concierge", "The Boutique", "The Vault", "The Terrace", "Your Suite" }
	local missing = {}
	for _, name in places do
		if not textOnScreen(name) then
			table.insert(missing, name)
		end
	end
	check("The rooms: every place in a line", #missing == 0, table.concat(missing, ", "))
	check("...the Suite, the Vault and the rest explained: what each is and how it works", textOnScreen("Ring the bell inside to furnish them") ~= nil and textOnScreen("The Archivist at the desk") ~= nil and textOnScreen("round IV") ~= nil)
	local goKeys = 0
	for _, d in playerGui:GetDescendants() do
		if d:IsA("TextButton") and d.Name == "Key" and norm(d.Text) == "go" then
			goKeys += 1
		end
	end
	check("...each with a Go key", goKeys == #places, goKeys)
	snapshot("howto-rooms")
	local goes = sentOps("Travel", "go")
	local salonGo
	for _, d in playerGui:GetDescendants() do
		if d:IsA("TextButton") and d.Name == "Key" and d.Parent and d.Parent:FindFirstChild("Words") and d.Parent.Words:FindFirstChild("Title") and d.Parent.Words.Title.Text == "The Salon" then
			salonGo = d
		end
	end
	if salonGo then
		signalOf(salonGo, "Activated"):Fire()
	end
	advance(0.5)
	local last = sent[#sent]
	check("Go asks the house to take you there (the house moves you)", sentOps("Travel", "go") == goes + 1 and last.remote == "Travel" and last.message.place == "salon")
	check("...and the guide steps aside", textOnScreen("Every place in the house") == nil)
	serverSays("Travel", { op = "arrived", place = "salon", name = "The Salon" })
	advance(0.3)
	check("...you're told when you're there", textOnScreen("You're here") ~= nil)
	serverSays("Travel", { op = "refused", why = "Stand up first." })
	advance(0.3)
	check("...or why not", textOnScreen("Stand up first.") ~= nil)
	HowToPlay.open()
	advance(1)
	check("opened again: back on the page last read", textOnScreen("Every place in the house") ~= nil)
	press("Extras")
	advance(0.6)
	check("Extras: the Grand Prix, the Ballroom, the Library, curios and brainrots, holidays, events", textOnScreen("The Grand Prix") ~= nil and textOnScreen("The Ballroom") ~= nil and textOnScreen("The Library") ~= nil and textOnScreen("Curios and brainrots") ~= nil and textOnScreen("Holiday games") ~= nil and textOnScreen("Events") ~= nil)
	check("...each saying how it works and what you get", textOnScreen("press E to drive") ~= nil and textOnScreen("five lights") ~= nil and textOnScreen("lamp goes out") ~= nil and textOnScreen("You get: Gilt for the top three, and Gems for the winner.") ~= nil and textOnScreen("You get: The last lamp still lit wins the whole pot of Gilt.") ~= nil)
	snapshot("howto-extras")
	press("Gilt & Shop")
	advance(0.6)
	check("Gilt & the Shop: Gilt, Gems, the Shop (prices always shown first), levels, tonight's table (optional)", textOnScreen("Gems") ~= nil and textOnScreen("price shown first") ~= nil and textOnScreen("Optional") ~= nil)
	press("Basics")
	advance(0.6)
	press("See how")
	advance(0.6)
	check("See how: the sorting page", textOnScreen("Moving a piece") ~= nil)
	Root.close()
	advance(0.5)
	HowToPlay.sorting()
	advance(1)
	check("the sorting, step by step, with the pieces turning", textOnScreen("Pick one up") ~= nil)
	snapshot("howto")
	Root.close()
	advance(1)
end
serverSays("Guest", { op = "inviteLibrary" })
check("the Concierge's invite opens the prompt", shared.invites == 3)
check("no errors in the panels", #errors == 0, errors[1])

---------------------------------------------------------------------------------------------------
-- 7b. The Boutique, the Wardrobe, the Ledger and a gift
---------------------------------------------------------------------------------------------------
local oxblood = { id = "table_oxblood", name = "Oxblood Felt", kind = "table", kindName = "Table styles", line = "Deep red felt.", robux = 249, owned = false, style = { felt = roblox.Color3.fromRGB(74, 18, 26), rim = roblox.Color3.fromRGB(198, 160, 82) } }
local ledgerView = { term = "2026-autumn", points = 2100, page = 2, pages = 50, progress = 0.1, leather = false, nextFree = { "100 Gilt" }, nextLeather = { "x", "y" }, nextPage = 3 }
invokeResults.ShopAsk = {
	-- (A shelf of every kind, each drawn as itself.)
	today = {
		oxblood,
		{ id = "lamp_rose", name = "Rose Glass", kind = "lamp", kindName = "Lamps", line = "A lamp with a blush in it.", robux = 149, owned = false, style = { colour = roblox.Color3.fromRGB(255, 196, 196) } },
		{ id = "trail_ruby", name = "Ruby", kind = "trail", kindName = "Trails", line = "A red thread, bright as a stone.", robux = 99, owned = false, style = { colour = roblox.Color3.fromRGB(224, 64, 84) } },
		{ id = "card_damask", name = "Damask", kind = "card", kindName = "Card backs", line = "A woven pattern in burgundy.", robux = 99, owned = false, style = { back = roblox.Color3.fromRGB(62, 18, 28), pattern = "damask" } },
		{ id = "look_gown", name = "Silk Evening Gown", kind = "look", kindName = "Looks", line = "Midnight silk to the floor.", robux = 299, owned = false, style = { outfit = "gown" } },
		{ id = "plate_filigree", name = "Gold Filigree", kind = "nameplate", kindName = "Nameplates", line = "Fine gold wire on black.", robux = 149, owned = false, style = { frame = roblox.Color3.fromRGB(198, 160, 82), fill = roblox.Color3.fromRGB(26, 20, 12), line = roblox.Color3.fromRGB(250, 230, 170) } },
	}, featured = {}, season = { id = "harvest", name = "Harvest Nights", price = 599, pieces = {} },
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
-- A full Wardrobe: far more than fits, so it scrolls (on a phone too), and Close stays in the panel.
do
	local many = {}
	for i = 1, 9 do
		table.insert(many, { id = "table_" .. i, name = "Oxblood Felt " .. i, kind = "table", style = oxblood.style })
	end
	invokeResults.ShopAsk = { kinds = { table = many, lamp = many, trail = many, nameplate = many }, equipped = { table = "" }, names = {} }
	serverSays("Shop", { op = "open", panel = "wardrobe" })
	advance(1)
	local panel = find(playerGui, function(d)
		return d.Name == "Wardrobe" and d:IsA("Frame")
	end)
	local list = panel and panel:FindFirstChild("List", true)
	check("a full Wardrobe scrolls: its list has a set height inside the panel, the rest scrolls", list ~= nil and list:IsA("ScrollingFrame") and list.AutomaticSize == roblox.Enum.AutomaticSize.None and list.Size.Y.Scale == 1 and list.Size.Y.Offset < 0 and list.AutomaticCanvasSize == roblox.Enum.AutomaticSize.Y)
	check("...and Close is always there, under the list", panel ~= nil and textOnScreen("Close") ~= nil)
	local overlapping = 0
	for _, d in (list and list:GetDescendants() or {}) do
		if d:IsA("TextButton") and d:FindFirstChild("Swatch") then
			local padding = d:FindFirstChildOfClass("UIPadding")
			if d.TextXAlignment ~= roblox.Enum.TextXAlignment.Left or not padding or padding.PaddingLeft.Offset < 28 then
				overlapping += 1
			end
		end
	end
	check("...each colour dot in its own space, the name beside it (never over it)", overlapping == 0, overlapping)
	snapshot("wardrobe-full")
	Root2.close()
	advance(1)
end
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

-- The Introduction, offered once to a guest in their first week (after their first banked run):
-- its pieces, its price, its real limit, See it and Not now.
do
	local Offer = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "OfferCard")
	Root2.close()
	advance(0.5)
	invokeResults.ShopAsk.introduction = { price = 99, items = { { name = "The Velvet Jacket" }, { name = "A Silver Chime" }, { name = "A Painting for your Suite" } } }
	local opened = false
	Offer.openIntroduction = function()
		opened = true
	end
	run(Offer.introduction)
	advance(3.2)
	check("a first-week guest is shown The Introduction: its pieces, its price and its real limit", textOnScreen("The Introduction") ~= nil and textOnScreen("The Velvet Jacket") ~= nil and textOnScreen("99, and only in your first week") ~= nil)
	snapshot("introduction-offer")
	local see = find(playerGui, function(d)
		return d:IsA("TextButton") and string.sub(d.Name, 1, 10) == "Key_See it"
	end)
	check("...its key says the price too", see ~= nil and string.find(see.Text, "99", 1, true) ~= nil)
	if see then
		signalOf(see, "Activated"):Fire()
	end
	advance(0.6)
	check("...and See it opens the Boutique on its page", opened and textOnScreen("99, and only in your first week") == nil)
	invokeResults.ShopAsk.introduction = nil
end

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
check("...each piece in its own vitrine, the ones not yet found in shadow", find(playerGui, function(d)
	return d.Name == "Entry_" .. firstCore.id and d:FindFirstChild("Spot") ~= nil and d:FindFirstChild("Plinth") ~= nil
end) ~= nil and textOnScreen("Not yet found") ~= nil and textOnScreen("1 OF") ~= nil)
advance(0.5)
snapshot("register-case")
check("the Mythics page prints the odds and the serial", press("Mythics") and textOnScreen("1 in 40,000") ~= nil and textOnScreen("No. 00412") ~= nil)
advance(0.5)
snapshot("register-mythics")
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
	-- Stepping into a Suite again: gone from your screen the moment they do (the next frame).
	groot.Position = SuiteLayout.arrival + Vector3.new(4, 3, 0)
	groot.CFrame = CFrame.new(groot.Position)
	advance(0.05)
	check("...and the moment they step into a Suite again, they're gone from yours", groot.LocalTransparencyModifier == 1 and gplate.Enabled == false and gsteps.Volume == 0)
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
	return d:IsA("TextButton") and d.Name == "Key" and d.Parent ~= nil and d.Parent.Name == "Suites"
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
	camera.ViewportSize = DEVICE.size
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
		squad = { ids = { "croissantino" }, walk = "croissantino", mut = { croissantino = "gold" }, held = 240, rate = 120, cap = 960, slots = 3, wing = false, feast = 960, prices = { brainrotFeast = 39, brainrotPenthouse = 199 } },
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
	-- It opens on the brainrot squad: the tip jar, the places, and the ones to put in.
	check("the Collection opens on your brainrot squad: the tip jar filling, what it earns", textOnScreen("TIP JAR") ~= nil and textOnScreen("240 Gilt") ~= nil and textOnScreen("Your squad earns 120 Gilt an hour") ~= nil)
	check("...the squad's places: the one walking with you, empty places, three more in the Penthouse at its price", textOnScreen("YOUR SQUAD  ·  1 / 3") ~= nil and textOnScreen("WALKING ✓") ~= nil and textOnScreen("AN EMPTY PLACE") ~= nil and textOnScreen("PENTHOUSE +3  ·  " .. utf8.char(0xE002) .. " 199") ~= nil)
	check("...a Gold one says so, with its stars and Gilt an hour", textOnScreen("GOLD  ·  COMMON") ~= nil and textOnScreen("★★☆☆☆") ~= nil and textOnScreen("+120 Gilt/hr") ~= nil)
	check("...the Feast says what it pays and its price", textOnScreen("FEAST  +960  ·  " .. utf8.char(0xE002) .. " 39") ~= nil)
	check("...and every brainrot you hold that isn't placed, to add", textOnScreen("Le Roi Grenouille") ~= nil and (function()
		for _, d in playerGui:GetDescendants() do
			if d:IsA("TextButton") and d.Name == "Add_frogKing" then
				return true
			end
		end
		return false
	end)())
	snapshot("brainrots")
	do
		local shelf = find(playerGui, function(d)
			return d.Name == "Shelf" and d:IsA("ScrollingFrame")
		end)
		if shelf then
			shelf.CanvasPosition = Vector2.new(0, 190)
			snapshot("brainrots-squad")
			shelf.CanvasPosition = Vector2.new(0, 0)
		end
	end
	local fullState = invokeResults.CurioAsk
	invokeResults.CurioAsk = { ok = true, gilt = 240 }
	check("Collect asks the server (never says an amount)", press("COLLECT"))
	advance(0.5)
	invokeResults.CurioAsk = fullState
	check("...the request names nothing but the action", (function()
		for i = #sent, 1, -1 do
			local m = if type(sent[i].message) == "table" then sent[i].message[1] else nil
			if sent[i].remote == "CurioAsk" and type(m) == "table" and m.op == "collect" then
				return m.gilt == nil and m.amount == nil
			end
		end
		return false
	end)())
	check("...and the Gilt is said", textOnScreen("+240 Gilt from your brainrots") ~= nil)
	press("Yours")
	advance(0.4)
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
-- (Watched over a few seconds, not one moment: which shells are in the air at any one instant
-- depends on when the show began on the test's clock.)
do
	local highest = 0
	for _ = 1, 30 do
		local f = workspace.MaisonLocal:FindFirstChild("Fireworks")
		for _, p in (f and f:GetChildren() or {}) do
			if p.Name == "Shell" or p.Name == "Rocket" or p.Name == "Shape" then
				highest = math.max(highest, p.Position.Y)
			end
		end
		advance(0.1)
	end
	check("the shells fly high over the roofs", highest > 60, highest)
end
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
do
	serverSays("Salute", { op = "salute", id = "fireworks", by = "Ada", userId = LocalPlayer.UserId, seconds = 10, scale = 1, effects = { "fireworks" }, line = "Ada lit fireworks over the house." })
	advance(1)
	local function watchTile()
		local dockFrame = find(playerGui, function(d)
			return d.Name == "QuickDock" and d:IsA("Frame")
		end)
		return dockFrame and dockFrame:FindFirstChild("Watch")
	end
	local function watchLabel(): string?
		local t = watchTile()
		local l = t and t:FindFirstChild("Label", true)
		return l and l.Text
	end
	local tileNow = watchTile()
	local invite = tileNow and tileNow.Parent:FindFirstChild("Invite")
	check("fireworks: a key to watch them from outside, at the foot of the dock under Invite", tileNow ~= nil and invite ~= nil and tileNow.LayoutOrder > invite.LayoutOrder)
	check("...never a key in the middle of the screen", find(playerGui, function(d)
		return d.Name == "FireworksWatch"
	end) == nil)
	check("...and the guest who lit them is taken out to watch at once", watchLabel() == "Back", watchLabel())
	snapshot("fireworks-watch")
	local watchKey = tileNow and tileNow:FindFirstChild("Key")
	if watchKey then
		signalOf(watchKey, "Activated"):Fire()
	end
	advance(0.5)
	check("...and brought back with the same key", watchLabel() == "Watch", watchLabel())
	advance(20)
	check("when the show is over, the key goes", watchTile() == nil)
end

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
;(function()
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
	-- (A body for this show only: a torso for the cape to hang from, and limbs for the statue.)
	local limbs = {}
	for _, l in {
		{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.6, 0) },
		{ "LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.4, 0) },
		{ "LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.8, 0) },
		{ "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.8, 0) },
		{ "LeftLowerArm", Vector3.new(1, 1.1, 1), Vector3.new(-1.5, -0.35, 0) },
		{ "RightLowerArm", Vector3.new(1, 1.1, 1), Vector3.new(1.5, -0.35, 0) },
		{ "LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -1.2, 0) },
		{ "RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -1.2, 0) },
		{ "LeftLowerLeg", Vector3.new(1, 1.4, 1), Vector3.new(-0.5, -2.5, 0) },
		{ "RightLowerLeg", Vector3.new(1, 1.4, 1), Vector3.new(0.5, -2.5, 0) },
	} do
		local p = Instance.new("Part")
		p.Name = l[1]
		p.Size = l[2]
		p.Color = roblox.Color3.fromRGB(64, 64, 72)
		p.CFrame = root.CFrame * CFrame.new(l[3])
		p.Parent = character
		table.insert(limbs, p)
	end
	local function card()
		return find(playerGui, function(d)
			return d.Name == "Objective" and d:IsA("Frame") and d.Parent ~= nil and d.Parent.Name == "MaisonHud"
		end)
	end
	local cardBefore = card() ~= nil
	local function inTouch(name)
		local touch = workspace.MaisonLocal:FindFirstChild("MidasTouch")
		return touch ~= nil and touch:FindFirstChild(name, true) ~= nil
	end
	serverSays("Purchase", { op = "spectacle", key = "spectacleGolden", seconds = 40 })
	advance(1)
	local screen = playerGui:FindFirstChild("MidasTouch")
	check("the Midas touch opens like a film: black bars close in, its title in gold", screen ~= nil and screen:FindFirstChild("BarTop") ~= nil and textOnScreen("THE MIDAS TOUCH") ~= nil)
	check("...motes of gold gather into a small sun before the guest", inTouch("Sun") and inTouch("Mote"))
	check("...and the card of what to do next steps aside for its words", cardBefore and card() == nil, cardBefore)
	advance(2)
	check("the Midas touch: the Suite turns to gold where the ring of gold has passed", wall.Material == roblox.Enum.Material.Metal and wall.Color ~= wallColour)
	check("...a wall of golden light runs out across the floor", inTouch("LightEdge") and inTouch("LightVeil"))
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
	check("...shafts of light with gold dust in them, the air glittering, fountains of gold in the corners", inTouch("ShaftTop") and inTouch("GoldDust") and inTouch("GoldFountain"))
	check("...and the guest's own likeness rises, cast in gold, on a plinth", (function()
		local statue = touch and touch:FindFirstChild("MidasStatue")
		local likeness = statue and statue:FindFirstChild("Likeness")
		if not likeness or not statue:FindFirstChild("Plinth") then
			return false
		end
		local head = likeness:FindFirstChild("Head")
		return head ~= nil and head.Material == roblox.Enum.Material.Metal and likeness:FindFirstChildOfClass("Humanoid") == nil
	end)())
	advance(11)
	check("...a jewelled crown settles on the guest's head", touch ~= nil and touch:FindFirstChild("MidasCrown") ~= nil)
	check("...in a pillar of light, cold sparks firing in a ring round them", inTouch("Pillar") and inTouch("SparkMachine"))
	advance(1.5)
	check("...a royal cape on their shoulders, and ALL HAIL with their name", inTouch("Cape") and textOnScreen("ALL HAIL") ~= nil and textOnScreen("ADA") ~= nil)
	snapshot("midas")
	advance(22)
	check("...and everything is put back as it was", wall.Color == wallColour and wall.Material == roblox.Enum.Material.Wood)
	check("...the fire too", flames.Rate == 70)
	check("...and the gold is gone", workspace.MaisonLocal:FindFirstChild("MidasTouch") == nil)
	check("...the bars, the words and the golden light too", playerGui:FindFirstChild("MidasTouch") == nil and game:GetService("Lighting"):FindFirstChild("MidasGlow") == nil)
	check("...and the card of what to do next is back", not cardBefore or card() ~= nil)
	check("no errors in the Midas touch", #errors == 0, errors[1])
	for _, p in limbs do
		p:Destroy()
	end
	wall:Destroy()
	if madeFire then
		fireplace:Destroy()
	end
	if made then
		suite:Destroy()
	end
end)()

-- The Meme Takeover: six acts in the Suite, then everything put back.
do
	-- (The card of what to do next, at the top right, steps aside while the show's words are up.)
	local function objectiveCard()
		return find(playerGui, function(d)
			return d.Name == "Objective" and d:IsA("Frame") and d.Parent ~= nil and d.Parent.Name == "MaisonHud"
		end)
	end
	local cardBefore = objectiveCard() ~= nil
	local memeMusic = Config.data.Spectacles.memeMusic
	local function scorePlaying(): boolean
		for _, d in game:GetService("SoundService"):GetChildren() do
			if d:IsA("Sound") and d.Name == "Score" and d.SoundId == memeMusic then
				return true
			end
		end
		return false
	end
	serverSays("Purchase", { op = "spectacle", key = "spectacleMemes", seconds = 20 })
	advance(1)
	check("the Meme Takeover starts with its warning", textOnScreen("MEME TAKEOVER") ~= nil)
	local showGui = playerGui:FindFirstChild("MemeTakeover")
	check("...black bars close in at the top and foot of the screen, like a film", showGui ~= nil and showGui:FindFirstChild("BarTop") ~= nil and showGui:FindFirstChild("BarBottom") ~= nil)
	advance(3)
	local takeover = workspace.MaisonLocal:FindFirstChild("MemeTakeover")
	check("...the portal spews memes into the room", takeover ~= nil and #takeover:GetChildren() > 10, takeover and #takeover:GetChildren())
	check("...to the show's own score (Swing With Me), as it always was", scorePlaying())
	local MemeSquad = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "MemeSquad")
	check("...your own brainrot squad drops in and stars in it, your best one its champion", takeover ~= nil and takeover:FindFirstChild("SquadChampion") ~= nil and takeover.SquadChampion:GetAttribute("Curio") == "croissantino" and textOnScreen("YOUR SQUAD HAS ARRIVED") ~= nil)
	local litTiles, beamsOn = 0, 0
	if takeover then
		for _, d in takeover:GetDescendants() do
			if d.Name == "FloorLight" and d:IsA("BasePart") and d.Transparency < 0.95 then
				litTiles += 1
			elseif d:IsA("Beam") and d.Parent and d.Parent.Name == "BeamTop" and d.Enabled then
				beamsOn += 1
			end
		end
	end
	check("...a dance floor of light lit on the beat, and beams sweeping the room from the ceiling", litTiles > 0 and beamsOn >= 4, string.format("%d tiles, %d beams", litTiles, beamsOn))
	check("...the lights blooming", game:GetService("Lighting"):FindFirstChild("MemeBloom") ~= nil)
	check("...and the card of what to do next steps aside for it (its big words never land on the card)", cardBefore and objectiveCard() == nil, cardBefore)
	local caption = find(playerGui, function(d)
		return d.Name == "Caption" and d:IsA("Frame") and d.Parent ~= nil and d.Parent.Name == "MemeTakeover"
	end)
	check("...its words stand under the bar at the top and clear of the keys down the left", caption ~= nil and caption.Position.Y.Scale > 0.25 and caption.Position.X.Scale - caption.Size.X.Scale / 2 >= 0.24, if caption then tostring(caption.Position) .. " " .. tostring(caption.Size) .. " in " .. caption.Parent:GetFullName() else "no caption")
	snapshot("meme-takeover")
	advance(8)
	check("...then the boss arrives", textOnScreen("THE BIG CHEESE") ~= nil or textOnScreen("MAXIMUM BRAINROT") ~= nil or textOnScreen("RAINING MEMES") ~= nil)
	check("...with its bar across the top, the meme words popping on the beat and the AURA climbing", find(playerGui, function(d)
		return d.Name == "BossBar" and d.Visible == true
	end) ~= nil and (MemeSquad.last() or {}).words > 0 and textOnScreen("AURA") ~= nil)
	snapshot("meme-squad")
	advance(7.6)
	local fight = MemeSquad.last() or {}
	check("...in the chaos your champion fights the boss, hit after hit, to a K.O.", (fight.hits or 0) >= 2 and fight.hp == 0 and textOnScreen("WINS!") ~= nil, string.format("%s hits, hp %s", tostring(fight.hits), tostring(fight.hp)))
	snapshot("meme-ko")
	advance(6.4)
	check("...and when it's over, the room is put back", workspace.MaisonLocal:FindFirstChild("MemeTakeover") == nil and find(playerGui, function(d)
		return d.Name == "MemeTakeover"
	end) == nil)
	advance(0.5)
	check("...and the card of what to do next is back", objectiveCard() ~= nil)
	check("...and the lights are the room's own again (no bloom left behind)", game:GetService("Lighting"):FindFirstChild("MemeBloom") == nil)
	check("no errors in the spectacles", #errors == 0, errors[1])
end
do
	-- Every edition of the Meme Takeover plays through: its own words, its own boss, its own
	-- finale, and the room put back after.
	local MemeTakeover = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "MemeTakeover")
	local MemeTakeovers = module("ReplicatedStorage", "Shared", "MemeTakeovers")
	local Curios = module("ReplicatedStorage", "Shared", "Curios")
	local problems = {}
	local errorsBefore = #errors
	for _, V in MemeTakeovers.List do
		serverSays("Purchase", { op = "spectacle", key = "spectacleMemes", seconds = 14, variant = V.id })
		advance(1)
		local folder = workspace.MaisonLocal:FindFirstChild("MemeTakeover")
		if not (folder and folder:GetAttribute("Edition") == V.id and MemeTakeover.lastEdition() == V.id) then
			table.insert(problems, V.id .. ": didn't start as itself")
		end
		local ownScore = false
		for _, d in game:GetService("SoundService"):GetChildren() do
			if d:IsA("Sound") and d.Name == "Score" and d.SoundId == Config.data.Spectacles.memeMusic then
				ownScore = true
			end
		end
		if not ownScore then
			table.insert(problems, V.id .. ": not the show's own score")
		end
		advance(8.5)
		if textOnScreen(V.captions[5]) == nil then
			table.insert(problems, V.id .. ": no boss words")
		end
		local bossGlyph = Curios.byId[V.boss] and Curios.byId[V.boss].glyph
		local bossFound = folder and find(folder, function(d)
			return d:IsA("TextLabel") and d.Text == bossGlyph
		end)
		if not bossFound then
			table.insert(problems, V.id .. ": no boss")
		end
		if V.id == "cosmic" or V.id == "solidGold" or V.id == "glitch" then
			snapshot("meme-" .. V.id)
		end
		advance(8)
		if workspace.MaisonLocal:FindFirstChild("MemeTakeover") ~= nil or find(playerGui, function(d)
			return d.Name == "MemeTakeover"
		end) ~= nil then
			table.insert(problems, V.id .. ": not put back")
		end
		if not MemeTakeover.finaleDone() then
			table.insert(problems, V.id .. ": the finale didn't finish")
		end
	end
	check("every edition of the Meme Takeover plays through as itself, boss, finale and all, and the room is put back", #problems == 0, table.concat(problems, "; "))
	check("...without a fault in any of them", #errors == errorsBefore, errors[errorsBefore + 1])
	serverSays("Purchase", { op = "spectacle", key = "spectacleMemes", seconds = 6, variant = "notAnEdition" })
	advance(1)
	check("an edition this screen doesn't know plays the classic", MemeTakeover.lastEdition() == "classic")
	advance(9)
end

-- The Friend Booster, in the bottom-right corner: the server says which friends are here, and the
-- boost (more with every friend); the card shows it, and invites more.
do
	local FriendBooster = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "FriendBooster")
	local SettingsPanel = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "SettingsPanel")
	local RootUI = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Root")
	local booster = find(playerGui, function(d)
		return d.Name == "FriendBooster" and d:IsA("Frame") and d.Parent and d.Parent.Name == "MaisonHud"
	end)
	check("the Friend Booster sits in the bottom-right corner", booster ~= nil and booster.AnchorPoint == Vector2.new(1, 1) and booster.Position.X.Scale == 1 and booster.Position.Y.Scale == 1)
	FriendBooster.unfold()
	advance(0.4)
	check("with no friend here: an invitation (+25% for you both) and a key to invite friends", textOnScreen("Play with a friend") ~= nil and textOnScreen("+25% GILT") ~= nil and textOnScreen("For you both") ~= nil and textOnScreen("INVITE FRIENDS") ~= nil)
	snapshot("friend-booster-none")
	local invitesBefore = shared.invites
	press("INVITE FRIENDS")
	advance(0.2)
	check("...which opens Roblox's own invite", shared.invites == invitesBefore + 1)
	serverSays("Guest", { op = "friends", friends = { { userId = 2, name = "Ben" } }, gilt = 1.25, xp = 1.1 })
	advance(0.8)
	local function face(id)
		return find(booster, function(d)
			return d:IsA("ImageLabel") and string.find(d.Image, "id=" .. tostring(id) .. "&", 1, true) ~= nil
		end)
	end
	check("a friend arrives: the card opens, lit: +25% Gilt, +10% XP, and their face", FriendBooster.isOpen() and textOnScreen("+25%") ~= nil and textOnScreen("+10% XP") ~= nil and textOnScreen("Ben arrived") ~= nil and face(2) ~= nil)
	snapshot("friend-booster")
	local ownerId = Config.data.Admin.ownerUserId
	serverSays("Guest", { op = "friends", friends = { { userId = 2, name = "Ben" }, { userId = ownerId, name = "AJKR", owner = true } }, gilt = 1.35, xp = 1.1 })
	advance(0.8)
	check("a second friend: +35%, the owner shown by AJKR's crest (never their avatar)", textOnScreen("+35%") ~= nil and textOnScreen("AJKR arrived") ~= nil and find(booster, function(d)
		return d.Name == "Crest"
	end) ~= nil and face(ownerId) == nil)
	advance(11)
	check("after a few seconds it folds to a slim pill", FriendBooster.isOpen() == false and textOnScreen("+35% GILT") ~= nil)
	snapshot("friend-booster-pill")
	local pill = find(booster, function(d)
		return d.Name == "Pill" and d:IsA("TextButton")
	end)
	if pill then
		signalOf(pill, "Activated"):Fire()
	end
	advance(0.5)
	check("...a tap opens it again, with what one more friend would bring", FriendBooster.isOpen() and textOnScreen("2 friends here") ~= nil and textOnScreen("One more friend here: +45%") ~= nil)
	FriendBooster.setSeated(true)
	advance(0.3)
	check("it steps aside while sorting at a table", booster.Visible == false)
	FriendBooster.setSeated(false)
	advance(0.3)
	check("...and comes back after", booster.Visible == true)
	SettingsPanel.open()
	advance(0.5)
	check("...and under any panel", booster.Visible == false)
	RootUI.close()
	advance(0.5)
	check("...and back when it's closed", booster.Visible == true)
	-- On a phone it stands above Roblox's jump button, in screen pixels whatever the HUD's scale
	-- (a small screen's button reaches 90 px up): never on it.
	local preferred = UserInputService.PreferredInput
	UserInputService.PreferredInput = EnumShim.PreferredInput.Touch
	camera.ViewportSize = Vector2.new(844, 390)
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.5)
	local liftPx = -booster.Position.Y.Offset * RootUI.scale
	check("on a phone it stands clear above the jump button, not on it", liftPx >= 90 + 10, liftPx)
	camera.ViewportSize = Vector2.new(2000, 921)
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.5)
	liftPx = -booster.Position.Y.Offset * RootUI.scale
	check("...and on a bigger phone, above its bigger button (210 px up)", liftPx >= 210 + 10, liftPx)
	UserInputService.PreferredInput = preferred
	camera.ViewportSize = DEVICE.size
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.5)
	check("...and back in its corner with a mouse", booster.Position.Y.Offset == -18)
	serverSays("Guest", { op = "friends", friends = {}, gilt = 1, xp = 1 })
	advance(0.3)
	check("when they've gone, it's the invitation again", FriendBooster.count() == 0 and textOnScreen("+35% GILT") == nil)
	FriendBooster.fold()
	advance(0.2)
end

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
	-- (With tonight's night known, the headline names it.)
	workspace:SetAttribute("AbuseNight", "midasHeist")
	advance(1.2)
	check("...naming tonight's night: ADMIN ABUSE · THE MIDAS HEIST", textOnScreen("ADMIN ABUSE  ·  THE MIDAS HEIST") ~= nil)
	advance(3.2) -- (the second line turns to the next event)
	local clocked = strip and find(strip, function(d)
		return d:IsA("TextLabel") and string.find(d.Text, "%d+:%d%d") ~= nil
	end)
	check("...and never a clock while Admin Abuse is on (how long it lasts is AJKR's business)", clocked == nil, clocked and clocked.Text)
	-- A notice that comes in now lands below the strip, never over it.
	module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Toast").show("You caught Homard de Luxe", "+72 Gilt", 4)
	advance(0.4)
	local note = find(playerGui, function(d)
		return d.Name == "Toast" and d:IsA("Frame")
	end)
	check("a notice during Admin Abuse comes in at the foot of the screen, never over the strip", note ~= nil and note.Position.Y.Scale == 1 and note.AnchorPoint.Y == 1, note and tostring(note.Position))
	advance(0.8)
	snapshot("toast-under-strip")
	advance(4.2)
	workspace:SetAttribute("AbuseNight", nil)
	for _, id in { "goldenHour", "luckyHour", "giants", "quickstep", "goldRain", "featherlight" } do
		workspace:SetAttribute("Event_" .. id, nil)
		signalOf(workspace, "attr:Event_" .. id):Fire()
	end
	workspace:SetAttribute("AbuseUntil", nil)
	signalOf(workspace, "attr:AbuseUntil"):Fire()
	advance(1.2)
	-- (In the strip: the build's own label in the corner may name Admin Abuse nights too.)
	local still = strip and find(strip, function(d)
		return d:IsA("TextLabel") and string.find(norm(d.Text), norm("ADMIN ABUSE"), 1, true) ~= nil
	end)
	check("...and it goes when the night ends", still == nil, still and (still:GetFullName() .. ": " .. still.Text))
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
-- (One banner at a time, the newest: words never pile up on each other.)
check("a storm, a dance party and a spin, all at once, without a fault", textOnScreen("SPIN!") ~= nil and textOnScreen("DANCE PARTY") == nil and #errors == 0, errors[1])
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
			return d:IsA("TextButton") and d.Name == "Key" and d.Parent ~= nil and d.Parent.Name == name and d.Parent.Parent ~= nil and d.Parent.Parent.Name == "QuickDock"
		end)
	end
	check("the dock: Collection, Trade, Wardrobe, Gems and Invite on screen", dockKeys.Collection ~= nil and dockKeys.Trade ~= nil and dockKeys.Wardrobe ~= nil and dockKeys.Gems ~= nil and dockKeys.Invite ~= nil)
	-- (Each key in its own colour, softened, its name under its icon, on a tile with a soft shadow:
	-- natural, nothing glowing.)
	local lit = dockKeys.Gems and dockKeys.Gems.Parent:FindFirstChild("Shadow")
	local named = dockKeys.Gems and dockKeys.Gems:FindFirstChild("Label")
	check("...each key in its own colour on a tile with a soft shadow, its name under its icon, and nothing glowing", lit ~= nil and dockKeys.Gems.Parent:FindFirstChild("Glow") == nil and dockKeys.Gems:FindFirstChild("Sweep") == nil and named ~= nil and named.Text == "Gems")
	snapshot("dock")
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
	local QuickDockM = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "QuickDock")
	local StateM = module("StarterPlayer", "StarterPlayerScripts", "Client", "State")
	local SortScreenM = module("StarterPlayer", "StarterPlayerScripts", "Client", "Table", "SortScreen")
	local dockFrame = dockKeys.Gems and dockKeys.Gems.Parent.Parent
	local booster = find(playerGui, function(d)
		return d.Name == "FriendBooster" and d:IsA("Frame") and d.Parent and d.Parent.Name == "MaisonHud"
	end)
	-- The sorting screen up, though the table's word never reached the dock (a phone that sat down
	-- before the keys were ready): it still steps aside, and so does the Friend Booster.
	QuickDockM.setSeated(false)
	SortScreenM.open("THE SALON", "")
	advance(0.5)
	check("the dock steps aside whenever the sorting screen is up, even without the table's word", dockFrame ~= nil and dockFrame.Visible == false)
	check("...and so does the Friend Booster", booster ~= nil and booster.Visible == false)
	SortScreenM.close()
	advance(1.5)
	check("...and both come back when it closes", dockFrame ~= nil and dockFrame.Visible == true and booster ~= nil and booster.Visible == true)
	-- Folding it away: the ‹ key beside it, and the KEYS › tab to bring it back.
	local foldKey = find(playerGui, function(d)
		return d.Name == "DockFold" and d:IsA("TextButton")
	end)
	local unfoldTab = find(playerGui, function(d)
		return d.Name == "DockUnfold" and d:IsA("TextButton")
	end)
	check("the dock has a ‹ key to fold it away", foldKey ~= nil and foldKey.Visible == true and unfoldTab ~= nil and unfoldTab.Visible == false)
	if foldKey then
		signalOf(foldKey, "Activated"):Fire()
	end
	advance(0.5)
	check("folded: the keys go, a small KEYS › tab stays, and it's remembered", dockFrame ~= nil and dockFrame.Visible == false and unfoldTab ~= nil and unfoldTab.Visible == true and StateM.get("sideKeys") == "Hidden")
	-- The event keys never fold away: Watch the fireworks, and the holiday's key.
	QuickDockM.setWatch(true, false)
	QuickDockM.setHoliday("🦃", "Turkeys", nil)
	advance(0.5)
	local events = find(playerGui, function(d)
		return d.Name == "DockEvents" and d:IsA("Frame")
	end)
	check("folded: the event keys (Watch, the holiday's) still show, under the tab", events ~= nil and events.Visible == true and events:FindFirstChild("Watch") ~= nil and events:FindFirstChild("Turkeys") ~= nil)
	check("the event keys carry a LIVE tag, so the eye finds them", events.Watch:FindFirstChild("Live") ~= nil and events.Turkeys:FindFirstChild("Live") ~= nil)
	-- (A word beside a key shows once a visit: these keys have been on before, so a fresh one.)
	QuickDockM.hintBeside("dockTest", events.Watch, "Tap to watch the fireworks")
	advance(0.2)
	check("...and the first time a key comes on, a word beside it says what it does", textOnScreen("Tap to watch the fireworks") ~= nil)
	advance(8)
	QuickDockM.hintBeside("dockTest", events.Watch, "Tap to watch the fireworks")
	advance(0.2)
	check("...once a visit, gone after a few seconds", textOnScreen("Tap to watch the fireworks") == nil)
	snapshot("dock-folded")
	SortScreenM.open("THE SALON", "")
	advance(0.5)
	check("...and step aside at the table like the rest", events ~= nil and events.Visible == false and unfoldTab ~= nil and unfoldTab.Visible == false)
	SortScreenM.close()
	advance(1.5)
	if unfoldTab then
		signalOf(unfoldTab, "Activated"):Fire()
	end
	advance(0.5)
	check("KEYS › brings them all back, the event keys at the foot of the dock again", dockFrame ~= nil and dockFrame.Visible == true and unfoldTab ~= nil and unfoldTab.Visible == false and dockFrame:FindFirstChild("Watch") ~= nil and dockFrame:FindFirstChild("Turkeys") ~= nil and StateM.get("sideKeys") == "Shown")
	QuickDockM.setWatch(false)
	QuickDockM.setHoliday(nil, nil)
	advance(0.3)
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
		{ id = "goldenHour", name = "Golden Hour", line = "Gilt counts double.", glyph = "💰" },
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
check("the owner is welcomed when they arrive, as AJKR", textOnScreen("WELCOME BACK, AJKR") ~= nil)
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
check("Start begins an event (in every server, unless the owner chooses this house)", press("Start") and (function()
	advance(0.5)
	for i = #sent, 1, -1 do
		local sm = sent[i]
		if sm.remote == "AdminAsk" and sm.message[1] and sm.message[1].op == "event" then
			local id = sm.message[1].id
			return (id == "goldenHour" or id == "doubleXP" or id == "halloween" or id == "newYear") and sm.message[1].minutes == 15 and sm.message[1].everywhere == true
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
-- (Lune keeps an attribute's number to a float's precision, about two minutes at today's server
-- time, so the clock expected is worked out from the end as it was stored.)
local goldenLeft = (workspace:GetAttribute("Event_goldenHour") or 0) - workspace:GetServerTimeNow()
local goldenClock = string.format("%d:%d", goldenLeft // 60, (goldenLeft % 60) // 10)
check("every guest sees what's on, and for how long", textOnScreen("GOLDEN HOUR") ~= nil and goldenLeft > 300 and textOnScreen(goldenClock) ~= nil, goldenClock)
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
do
	local SoundModule = module("StarterPlayer", "StarterPlayerScripts", "Client", "Sound")
	local realPlay = SoundModule.play
	local heard: { string } = {}
	SoundModule.play = function(name, ...)
		table.insert(heard, name)
		return realPlay(name, ...)
	end
	serverSays("Salute", { op = "headline", text = "WHO'S READY FOR CHAOS?!", by = "AJKR", style = "rainbow", seconds = 6 })
	advance(0.6)
	check("a headline crosses the top of every screen, with who sent it (AJKR)", textOnScreen("WHO'S READY FOR CHAOS?!") ~= nil and textOnScreen("AJKR") ~= nil)
	check("...arriving with a quick two-note ping, like a phone's (no fanfare, no horn)", table.concat(heard, ",") == "notify,notify", table.concat(heard, ","))
	SoundModule.play = realPlay
	snapshot("headline")
end
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
serverSays("Salute", { op = "giveaway", names = { "Ben", "Ada", "Cy" }, winner = "Ben", winnerId = 2, amount = 1000, by = "AJKR" })
advance(0.3)
check("a giveaway is drawn on every screen, free", textOnScreen("GIVEAWAY") ~= nil and textOnScreen("free for everyone") ~= nil)
advance(4)
check("and lands on the winner", textOnScreen("Ben wins 1000 Gilt!") ~= nil)
snapshot("giveaway")
advance(4)
serverSays("Salute", { op = "giveaway", names = { "You" }, winner = LocalPlayer.DisplayName, winnerId = LocalPlayer.UserId, amount = 250, by = "AJKR" })
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
do
	-- Folding it away: the ‹ beside it shrinks it to a pill of Gilt alone, and the pill brings it back.
	local StateG = module("StarterPlayer", "StarterPlayerScripts", "Client", "State")
	local fold = find(playerGui, function(d)
		return d.Name == "GiltFold" and d:IsA("TextButton")
	end)
	local pill = find(playerGui, function(d)
		return d.Name == "GiltMini" and d:IsA("TextButton")
	end)
	local wholeBar = find(playerGui, function(d)
		return d.Name == "GiltBar" and d:IsA("Frame")
	end)
	check("the Gilt bar has a ‹ key to fold it away", fold ~= nil and fold.Visible and pill ~= nil and not pill.Visible)
	if fold then
		signalOf(fold, "Activated"):Fire()
	end
	advance(0.5)
	check("folded: only a small pill of Gilt is left, and it's remembered", wholeBar ~= nil and not wholeBar.Visible and pill ~= nil and pill.Visible and string.find(pill.Text, "12,500", 1, true) ~= nil and StateG.get("giltBar") == "Hidden")
	snapshot("gilt-bar-folded")
	if pill then
		signalOf(pill, "Activated"):Fire()
	end
	advance(0.5)
	check("...and the pill brings the whole bar back", wholeBar ~= nil and wholeBar.Visible and not pill.Visible and StateG.get("giltBar") == "Shown")
end
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
serverSays("Shop", { op = "badge", key = "metOwner", name = "Met the Owner", line = "Be in the house with the owner.", glyph = "👑", tier = "gold", count = 12, total = 155 })
serverSays("Shop", { op = "badge", key = "firstRound", name = "First Round", line = "Clear your first round at the tables.", glyph = "🃏", tier = "bronze", count = 13, total = 155, nextName = "Warming Up", nextHave = 1, nextTarget = 10 })
advance(0.8)
check("a badge earned slides in", textOnScreen("Met the Owner") ~= nil and textOnScreen("BADGE EARNED") ~= nil)
check("...with how many the guest has now, of how many", textOnScreen("12 / 155") ~= nil)
check("...where the card of what to do next was (it steps aside for it)", find(playerGui, function(d)
	return d.Name == "Objective" and d:IsA("Frame") and d.Parent ~= nil and d.Parent.Name == "MaisonHud"
end) == nil)
snapshot("badge")
advance(4.5)
check("and the next waits its turn", textOnScreen("First Round") ~= nil)
check("...pointing at the next badge on its ladder, and how far along", textOnScreen("NEXT:  WARMING UP") ~= nil and textOnScreen("1 / 10") ~= nil)
snapshot("badge-next")
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
do
	-- Gem-only things: its Companions (the shelf it opens on, the first time), then the table
	-- felts and guide trails.
	GemShopPanel.open("companion")
	advance(1)
	check("the Gem Shop opens on its Gem-only companions, each with its price", textOnScreen("Fox Kit") ~= nil and textOnScreen("The Crown Jewel") ~= nil and textOnScreen("💎 250") ~= nil and textOnScreen("Only Gems buy these") ~= nil)
	snapshot("gem-companions")
	check("table felts, each drawn as a swatch of its leather", press("TABLE FELTS") and (function()
		advance(0.3)
		local swatch = find(playerGui, function(d)
			return d.Name == "Swatch" and d:FindFirstChildOfClass("UIGradient") ~= nil
		end)
		return textOnScreen("Aurora Silk") ~= nil and swatch ~= nil
	end)())
	snapshot("gem-felts")
	check("guide trails, each drawn as its thread", press("GUIDE TRAILS") and (function()
		advance(0.3)
		return textOnScreen("Prism") ~= nil and find(playerGui, function(d)
			return d.Name == "Bead"
		end) ~= nil
	end)())
	Root2.close()
	advance(0.5)
	-- A companion floats at the shoulder of whoever wears one, on every screen.
	local Companions = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "Companions")
	LocalPlayer:SetAttribute("Companion", "comp_dragon")
	advance(0.5)
	local pet = Companions.of(LocalPlayer)
	local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	check("wear a companion and it floats at your shoulder", pet ~= nil and pet.Parent ~= nil and myRoot ~= nil and (pet.CFrame.Position - myRoot.CFrame.Position).Magnitude < 5, pet and myRoot and (pet.CFrame.Position - myRoot.CFrame.Position).Magnitude)
	check("...the little dragon, breathing embers", pet ~= nil and pet:FindFirstChild("Face", true) ~= nil and pet:FindFirstChildOfClass("Attachment") ~= nil)
	LocalPlayer:SetAttribute("Companion", nil)
	advance(0.3)
	check("...and it goes when you take it off", Companions.of(LocalPlayer) == nil)
	-- The brainrot out of your squad walks beside you, big, with its name and what it earns.
	local Walkers = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "BrainrotWalkers")
	LocalPlayer:SetAttribute("BrainrotMut", "gold")
	LocalPlayer:SetAttribute("BrainrotStars", 2)
	LocalPlayer:SetAttribute("BrainrotRate", 2250)
	LocalPlayer:SetAttribute("Brainrot", "frogKing")
	advance(1)
	local walker = Walkers.of(LocalPlayer)
	check("your brainrot walks beside you", walker ~= nil and walker.Parent ~= nil and myRoot ~= nil and (walker.CFrame.Position - myRoot.CFrame.Position).Magnitude < 12, walker and myRoot and (walker.CFrame.Position - myRoot.CFrame.Position).Magnitude)
	check("...as tall as its rarity, with its name, stars, mutation and Gilt an hour over its head", walker ~= nil and (function()
		local body = walker:FindFirstChild("Body")
		local line = walker:FindFirstChild("Line", true)
		return body ~= nil and body.Size.X.Scale >= 6.5 and line ~= nil and string.find(line.Text, "GOLD", 1, true) ~= nil and string.find(line.Text, "2.2K Gilt/hr", 1, true) ~= nil
	end)())
	LocalPlayer:SetAttribute("Brainrot", nil)
	advance(0.3)
	check("...and goes back to the squad when it stops walking", Walkers.of(LocalPlayer) == nil)
end
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
-- The Evening Calendar: seven evenings, those opened ticked off, tonight's waiting; opening it
-- (the server says what it was); and on arrival it's offered by itself only when nothing else is up.
;(function()
	local CalendarPanel = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "CalendarPanel")
	local state = { ok = true, op = "calendar", step = 2, weeks = 0, total = 2, ready = true, nextIn = 5 * 3600 }
	invokeResults.CalendarAsk = function(req)
		if type(req) == "table" and req.op == "open" then
			state = { ok = true, op = "calendar", step = 3, weeks = 0, total = 3, ready = false, nextIn = 5 * 3600 + 60, opened = 3, gilt = 0, gems = 5, xp = 0 }
		end
		return state
	end
	local function evening(i)
		return find(playerGui, function(d)
			return d.Name == "Evening" .. i and d:GetAttribute("State") ~= nil
		end)
	end
	CalendarPanel.open()
	advance(1)
	local states = {}
	for i = 1, 7 do
		local e = evening(i)
		states[i] = e and e:GetAttribute("State") or "none"
	end
	check("the Evening Calendar: seven evenings, two opened, tonight's waiting", textOnScreen("The Evening Calendar") ~= nil and textOnScreen("Tonight's present is waiting") ~= nil and table.concat(states, " ") == "opened opened today later later later later", table.concat(states, " "))
	check("...every present shown as it is (the third: 5 Gems)", textOnScreen("5 GEMS") ~= nil and textOnScreen("Miss a day and nothing is lost") ~= nil)
	snapshot("calendar")
	check("opening tonight's", press("Open tonight's present"))
	advance(1)
	check("...the third evening ticked off, and when the next one comes", textOnScreen("Tonight's present is open") ~= nil and textOnScreen("ready in 5h 01m") ~= nil and evening(3) ~= nil and evening(3):GetAttribute("State") == "opened")
	check("...and what it was, said plainly", textOnScreen("Evening 3: 5 Gems.") ~= nil)
	snapshot("calendar-opened")
	Root2.close()
	advance(0.5)
	-- On arrival: offered by itself when tonight's is waiting and nothing else is up...
	state = { ok = true, op = "calendar", step = 3, weeks = 0, total = 3, ready = true, nextIn = 3600 }
	CalendarPanel.offer()
	advance(0.5)
	check("on arrival, tonight's present is offered by itself", textOnScreen("Tonight's present is waiting") ~= nil)
	Root2.close()
	advance(0.5)
	-- ...but not over anything else, and not when it's been opened.
	state = { ok = true, op = "calendar", step = 4, weeks = 0, total = 4, ready = false, nextIn = 3600 }
	CalendarPanel.offer()
	advance(0.5)
	check("...and not when tonight's is already open", find(playerGui, function(d)
		return d.Name == "Calendar" and d:IsA("Frame")
	end) == nil)
	invokeResults.CalendarAsk = nil
end)()
-- Holidays and auras on this screen.
workspace:SetAttribute("Event_valentine", workspace:GetServerTimeNow() + 600)
signalOf(workspace, "attr:Event_valentine"):Fire()
advance(1.5)
check("Valentine's Day turns the light rosy", game:GetService("Lighting"):FindFirstChild("HolidayTint") ~= nil)
workspace:SetAttribute("Event_valentine", nil)
signalOf(workspace, "attr:Event_valentine"):Fire()
advance(1.5)
check("and back when it's over", game:GetService("Lighting"):FindFirstChild("HolidayTint") == nil)
-- Every holiday dresses the house on this screen: its title in its own colours with what to do,
-- its pieces on the street front, in the Foyer and in the sky, its light, its music and its hunt
-- glowing; and when it's over, all of it goes.
;(function()
	local HolidayFX = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "HolidayFX")
	local AbuseMusic = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "AbuseMusic")
	local HouseEvents = module("ReplicatedStorage", "Shared", "HouseEvents")
	local lighting = game:GetService("Lighting")
	local pieces = {
		halloween = { "Pumpkin", "Eye", "Moon", "Bat", "Candle", "Wrap" },
		thanksgiving = { "Leaves", "HayBale", "Corn", "Lantern", "Moon", "Wrap" },
		christmas = { "Boughs", "Bauble", "TreeStar", "Present", "Cane", "SnowCover", "Aurora", "Sleigh", "Wrap" },
		newYear = { "Balloon", "GlitterBall", "Mirror", "Searchlight", "Wrap" },
		valentine = { "HeartPost", "Lantern", "Floater", "Wrap" },
		stPatrick = { "Leaf", "Pennant", "Floater", "Wrap" },
		easter = { "Egg", "Leaves", "Tulip", "Butterfly", "Pennant", "Wrap" },
	}
	local problems = {}
	local errorsBefore = #errors
	for _, id in HouseEvents.Holidays do
		local e = HouseEvents.byId[id]
		-- (One of its hunt's pickups, as the server hides them.)
		local pickup = nil
		if id ~= "newYear" then
			pickup = Instance.new("Part")
			pickup.Name = "HuntPickup"
			pickup.CFrame = root.CFrame * CFrame.new(8, 0, 0)
			pickup:SetAttribute("Hunt", id)
			Instance.new("BillboardGui").Parent = pickup
			pickup.Parent = workspace
			CollectionService:AddTag(pickup, "HuntPickup")
		end
		workspace:SetAttribute("Event_" .. id, workspace:GetServerTimeNow() + 600)
		signalOf(workspace, "attr:Event_" .. id):Fire()
		advance(1.6)
		local folder = HolidayFX.setOf(id)
		if not folder or folder.Parent == nil then
			table.insert(problems, id .. ": the house isn't dressed")
		end
		for _, name in pieces[id] do
			if not (folder and folder:FindFirstChild(name, true)) then
				table.insert(problems, id .. ": no " .. name)
			end
		end
		if id ~= "newYear" then
			-- (Its own title card, in the holiday's colours: not just its name in the strip.)
			local card = find(playerGui, function(d)
				return d.Name == "Caption" and d:IsA("Frame") and d.Parent ~= nil and d.Parent.Name == "HolidayFX"
			end)
			local words = card and card:FindFirstChild("Words")
			if not (words and words.Text == string.upper(e.name) and card:FindFirstChild("Line") and card.Line.Text == e.line) then
				table.insert(problems, id .. ": no title card")
			end
		end
		if lighting:FindFirstChild("HolidayTint") == nil then
			table.insert(problems, id .. ": no tint")
		end
		if AbuseMusic.choose() ~= "holiday:" .. id then
			table.insert(problems, id .. ": not its own music (" .. tostring(AbuseMusic.choose()) .. ")")
		end
		if pickup and not (pickup:FindFirstChild("HolidaySparkle") and pickup:FindFirstChild("HolidayGlow", true)) then
			table.insert(problems, id .. ": its pickups don't glow")
		end
		-- (Each pickup drawn as the real thing: a pumpkin, a turkey, a present, a love letter, a
		-- four-leaf clover, a painted egg; its emoji put away.)
		local real = ({ halloween = "Pumpkin", thanksgiving = "Turkey", christmas = "Gift", valentine = "LoveLetter", stPatrick = "Clover", easter = "Egg" })[id]
		if pickup and real then
			local prop = workspace.MaisonLocal:FindFirstChild(real)
			if not (prop and prop:IsA("Model")) then
				table.insert(problems, id .. ": its pickup isn't a " .. real)
			elseif pickup:FindFirstChildOfClass("BillboardGui").Enabled ~= false then
				table.insert(problems, id .. ": its emoji still shows")
			end
		end
		-- (The strip counts what's left to find once the title card has gone: one hidden here, and
		-- no golden prize out.)
		advance(6)
		local Voice = module("ReplicatedStorage", "Shared", "Voice")
		local words = Voice.Hunts[id]
		if pickup and words and not textOnScreen(string.format(Voice.Hunts.left, 1, words.one) .. "  ·  " .. string.format(Voice.Hunts.found, words.prize)) then
			table.insert(problems, id .. ": the strip doesn't count what's left")
		end
		if id == "stPatrick" and not (workspace.MaisonLocal:FindFirstChild("Rainbow") and workspace.MaisonLocal.Rainbow:FindFirstChild("Band", true)) then
			table.insert(problems, id .. ": no rainbow")
		end
		advance(2)
		snapshot("holiday-" .. id)
		workspace:SetAttribute("Event_" .. id, nil)
		signalOf(workspace, "attr:Event_" .. id):Fire()
		advance(1.5)
		if HolidayFX.running(id) or workspace.MaisonLocal:FindFirstChild("HolidaySet_" .. id) or lighting:FindFirstChild("HolidayTint") then
			table.insert(problems, id .. ": still there after")
		end
		if id == "stPatrick" and workspace.MaisonLocal:FindFirstChild("Rainbow") then
			table.insert(problems, id .. ": the rainbow stays")
		end
		if pickup then
			pickup:Destroy()
		end
	end
	check("every holiday dresses the house (the street, the Foyer, the sky), with its title, light, music and hunt, and puts it all away after", #problems == 0, problems[1])
	check("...without a fault", #errors == errorsBefore, errors[errorsBefore + 1])
	advance(1.5)
	check("...and the music is the house's own again", AbuseMusic.choose() == "")
end)()
-- As grand as each screen can take: on a screen that's struggling (this harness's 20 frames a
-- second) every show draws less, and the holidays leave their extras out; full again once it's
-- smooth.
;(function()
	local Quality = module("StarterPlayer", "StarterPlayerScripts", "Client", "Quality")
	local HolidayFX = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "HolidayFX")
	local full = Quality.level()
	Quality.pin(nil)
	advance(7)
	local struggling = Quality.level()
	check("Quality: frames dropping (20 a second here), every show draws less", Quality.measured() <= 0.5 and struggling < full * 0.6, string.format("%.2f of %.2f", struggling, full))
	workspace:SetAttribute("Event_christmas", workspace:GetServerTimeNow() + 600)
	signalOf(workspace, "attr:Event_christmas"):Fire()
	advance(1.6)
	local set = HolidayFX.setOf("christmas")
	local bulbs = 0
	for _, d in (set and set:GetDescendants() or {}) do
		if d.Name == "Bulb" then
			bulbs += 1
		end
	end
	check("...a lighter Christmas: the trees and the lights, not the garlands wound up the columns", set ~= nil and set:FindFirstChild("Boughs", true) ~= nil and set:FindFirstChild("Wrap", true) == nil and bulbs > 0, bulbs)
	workspace:SetAttribute("Event_christmas", nil)
	signalOf(workspace, "attr:Event_christmas"):Fire()
	advance(1.5)
	Quality.pin(1)
	check("...and full again on a smooth screen", Quality.level() >= full * 0.99)
end)()
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
	check("...the card of what to do next steps aside for its big words", find(playerGui, function(d)
		return d.Name == "Objective" and d:IsA("Frame") and d.Parent ~= nil and d.Parent.Name == "MaisonHud"
	end) == nil)
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
	local AbuseNights = module("ReplicatedStorage", "Shared", "AbuseNights")
	-- (A seed that gives this night this opening, and this title if asked.)
	local function seedFor(night, opening, title)
		for seed = 1, 20000 do
			local p = AbuseNights.plan(seed, false, 0, night)
			if p.opening == opening and (title == nil or p.title == title) then
				return seed
			end
		end
		error("no seed for " .. night .. " " .. opening)
	end
	local classicSeed = seedFor("classic", "transmission", "slam")
	local function abuse(on, mega, seed, night)
		if on then
			workspace:SetAttribute("AbuseSeed", seed or classicSeed)
			workspace:SetAttribute("AbuseNight", night or "classic")
			workspace:SetAttribute("AbuseUntil", workspace:GetServerTimeNow() + 900)
			workspace:SetAttribute("AbuseSince", os.time())
			workspace:SetAttribute("AbuseMega", if mega then true else nil)
		else
			workspace:SetAttribute("AbuseUntil", nil)
			workspace:SetAttribute("AbuseSince", nil)
			workspace:SetAttribute("AbuseMega", nil)
			workspace:SetAttribute("AbuseRealm", nil)
			workspace:SetAttribute("AbuseSeed", nil)
			workspace:SetAttribute("AbuseNight", nil)
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
	serverSays("Salute", { op = "abuseShow", stage = "intro", mega = false, by = "AJKR", seed = classicSeed, night = "classic" })
	abuse(true, false)
	realm("gilded")
	advance(1.2)
	check("the opening: the screen goes cinematic, bars top and bottom", part("Opening") ~= nil and part("Opening"):FindFirstChild("BarTop") ~= nil)
	check("...a transmission from AJKR: their name, and what they're doing", textOnScreen("AJKR") ~= nil and textOnScreen("IS ABUSING THEIR POWERS") ~= nil and textOnScreen("INCOMING TRANSMISSION") ~= nil and textOnScreen("XXXXXXX") == nil)
	check("...AJKR's crest in the ring, never a picture of their avatar", find(part("Opening"), function(d)
		return d.Name == "Crest"
	end) ~= nil and find(playerGui, function(d)
		return d:IsA("ViewportFrame")
	end) == nil)
	check("...and nothing slammed onto the screen yet (that's the drop)", part("Opening"):FindFirstChild("Title") == nil)
	snapshot("abuse-opening")
	advance(Config.data.Admin.show.dropAt - 1.2 + 0.6)
	local title = part("Opening") and part("Opening"):FindFirstChild("Title")
	check("the drop: ADMIN ABUSE resolves onto the screen", title ~= nil and title.Text == "ADMIN ABUSE")
	check("...and tonight's night by name over it", textOnScreen("TONIGHT:  THE CLASSIC") ~= nil)
	check("...the transmission gone", textOnScreen("INCOMING TRANSMISSION") == nil)
	advance(0.8)
	check("...and what it brings, typed out under it", textOnScreen("GIFTS FROM AJKR") ~= nil)
	snapshot("abuse-drop")
	advance(Config.data.Admin.show.seconds)
	check("after the opening the screen is the house's again", part("Opening") == nil)
	check("and AJKR says what tonight is", textOnScreen("Tonight: THE CLASSIC!") ~= nil)
	check("the gilded night's colours are over the house", Lighting:FindFirstChild("AbuseRealm") ~= nil)
	advance(6)
	-- A surprise cast by the owner: the hologram.
	serverSays("Salute", { op = "abuseFX", id = "meteor", by = "AJKR", seconds = 18, v = 2, line = "Heads up! ☄️" })
	advance(1.2)
	local cardLine = find(playerGui, function(d)
		return d:IsA("TextLabel") and d.Name == "Line" and d.Parent ~= nil and d.Parent.Name == "Cameo"
	end)
	check("a surprise: AJKR's card says it, in tonight's looks, with their line", cardLine ~= nil and string.find(cardLine.Text, "ICE COMETS!", 1, true) ~= nil and string.find(cardLine.Text, "Heads up!", 1, true) ~= nil and textOnScreen("THE OWNER") ~= nil, cardLine and cardLine.Text)
	check("...and the effect wears those looks (ice comets, not plain meteors)", textOnScreen("ICE COMETS!") ~= nil)
	snapshot("owner-cameo")
	advance(5)
	-- The owner's gift.
	invokeResults.AbuseGiftAsk = { ok = true, gilt = 120, crown = true, count = 3 }
	serverSays("Salute", { op = "abuseGift", id = 7, gilt = 40, crown = true, number = 3, seconds = 25 })
	advance(1)
	check("a gift from AJKR: a card to open, saying what's in it", part("Gift") ~= nil and textOnScreen("A GIFT FROM AJKR") ~= nil and textOnScreen("+40 GILT") ~= nil and textOnScreen("THE ADMIN'S CROWN") ~= nil)
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
	serverSays("Salute", { op = "abuseShow", stage = "intro", mega = true, by = "AJKR", seed = classicSeed, night = "classic" })
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
	for _, id in { "midas", "neon", "abyss", "frost", "inferno", "heaven", "matrix", "sakura", "synthwave", "jungle", "thunder", "desert" } do
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
	check("arriving during Admin Abuse: a welcome, saying what's on", textOnScreen("YOU ARRIVED DURING ADMIN ABUSE") ~= nil and textOnScreen("ADMIN ABUSE IS LIVE") ~= nil)
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
	OwnerCameo.say("☄️ METEOR SHOWER!", "point", 4)
	advance(1)
	check("the card shows AJKR's crest, never a picture of their avatar (even with the avatar there)", find(playerGui, function(d)
		return d:IsA("ViewportFrame")
	end) == nil and find(playerGui, function(d)
		return d.Name == "Crest"
	end) ~= nil)
	advance(5)
	abuse(true, true, classicSeed, "classic")
	advance(2.5)
	check("on a night not made for it, no giant (AJKR's avatar is kept for a few nights)", workspace.MaisonLocal:FindFirstChild("OwnerColossus") == nil)
	abuse(false)
	advance(12)
	abuse(true, true, 77, "kingOfTheHouse")
	advance(2.5)
	local giant = workspace.MaisonLocal:FindFirstChild("OwnerColossus")
	check("on KING OF THE HOUSE, AJKR stands giant over the house, with ADMIN ABUSE in the sky over them", giant ~= nil and giant:FindFirstChild("Marquee", true) ~= nil)
	check("...and their name over it is AJKR", textOnScreen("👑 AJKR 👑") ~= nil or find(workspace.MaisonLocal, function(d)
		return d:IsA("TextLabel") and d.Text == "👑 AJKR 👑"
	end) ~= nil)
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
	-- The sorting table: a long streak sets the cloth on fire; twenty lights the whole screen.
	local SortScreen = module("StarterPlayer", "StarterPlayerScripts", "Client", "Table", "SortScreen")
	serverSays("Table", { op = "seated", table = salonTable:GetAttribute("TableId"), room = "salon", mode = "room" })
	advance(2)
	serverSays("Table", { op = "deal", round = 1, room = "salon", mode = "room", cases = cases, pieces = pieceList(8, cases), score = 0 })
	advance(2.5)
	SortScreen.streak(12, 6)
	SortScreen.setFever(true, 12)
	advance(0.6)
	check("twelve in a row: the cloth is on fire, and says so", SortScreen.isOnFire() and textOnScreen("ON FIRE · 12 IN A ROW") ~= nil and textOnScreen("You're on fire") ~= nil)
	snapshot("sort-fever")
	SortScreen.setFever(true, 13)
	advance(0.2)
	check("...counting on as it grows", textOnScreen("ON FIRE · 13 IN A ROW") ~= nil)
	advance(2)
	SortScreen.streak(20, 8)
	advance(0.3)
	check("twenty: the whole screen lights up", find(playerGui, function(d)
		return d.Name == "StreakFlash"
	end) ~= nil and textOnScreen("Twenty. Remarkable.") ~= nil)
	snapshot("sort-twenty")
	SortScreen.setFever(false)
	advance(1)
	check("a slip puts the fire out", not SortScreen.isOnFire() and textOnScreen("ON FIRE") == nil)
	serverSays("Table", { op = "left" })
	advance(3)
	check("no errors in Build 54's show", #errors == 0, errors[1])
end)()

---------------------------------------------------------------------------------------------------
-- Build 55: Admin Abuse's nights on this screen: every opening, every title, every finale, every
-- realm, every look of every effect; the owner as AJKR (and nobody else); the chat
---------------------------------------------------------------------------------------------------
;(function()
	local AbuseNights = module("ReplicatedStorage", "Shared", "AbuseNights")
	local AbuseFX = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "AbuseFX")
	local ChatNames = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "ChatNames")
	local show = function()
		return playerGui:FindFirstChild("MaisonAbuseShow")
	end
	local function abuse(on, mega, seed, night)
		if on then
			workspace:SetAttribute("AbuseSeed", seed)
			workspace:SetAttribute("AbuseNight", night)
			workspace:SetAttribute("AbuseUntil", workspace:GetServerTimeNow() + 900)
			workspace:SetAttribute("AbuseSince", os.time())
			workspace:SetAttribute("AbuseMega", if mega then true else nil)
		else
			for _, name in { "AbuseUntil", "AbuseSince", "AbuseMega", "AbuseRealm", "AbuseSeed", "AbuseNight" } do
				workspace:SetAttribute(name, nil)
			end
		end
		signalOf(workspace, "attr:AbuseUntil"):Fire()
	end
	-- (A night and seed for each opening, and for each title.)
	local function find2(want)
		for _, n in AbuseNights.List do
			for seed = 1, 4000 do
				local p = AbuseNights.plan(seed, false, 0, n.id)
				if want(p) then
					return seed, n.id, p
				end
			end
		end
		return nil
	end
	local errorsBefore = #errors
	advance(15)
	local shown = {}
	for _, opening in AbuseNights.Openings do
		local seed, night, p = find2(function(p)
			return p.opening == opening
		end)
		if seed then
			serverSays("Salute", { op = "abuseShow", stage = "intro", mega = false, by = "AJKR", seed = seed, night = night })
			abuse(true, false, seed, night)
			advance(1.5)
			local root = show() and show():FindFirstChild("Opening")
			local styled = root ~= nil and root:GetAttribute("Style") == opening
			local spent = 0
			if opening == "vault" or opening == "terminal" or opening == "hijack" or opening == "breaking" or opening == "countdown" or opening == "curtain" or opening == "warp" or opening == "portal" or opening == "transmission" or opening == "blackout" then
				spent = 1.2
				advance(spent)
				snapshot("opening-" .. opening)
			end
			advance(Config.data.Admin.show.dropAt + 0.4 - 1.5 - spent)
			local title = root and root:FindFirstChild("Title")
			local named = textOnScreen("TONIGHT:") ~= nil and textOnScreen(p.night.name) ~= nil
			if styled and title and named then
				table.insert(shown, opening)
			else
				print("  (opening " .. opening .. ": styled " .. tostring(styled) .. ", title " .. tostring(title ~= nil) .. ", named " .. tostring(named) .. ")")
			end
			if opening == "skyCrack" or opening == "pulse" then
				advance(0.3)
				snapshot("opening-" .. opening .. "-drop")
			end
			advance(Config.data.Admin.show.seconds)
			abuse(false)
			advance(12)
		end
	end
	check("every one of the twelve openings plays, its title lands, tonight's night named over it", #shown == #AbuseNights.Openings, #shown)
	local titled = {}
	for _, style in AbuseNights.TitleStyles do
		local seed, night = find2(function(p)
			return p.title == style
		end)
		if seed then
			serverSays("Salute", { op = "abuseShow", stage = "intro", mega = true, by = "AJKR", seed = seed, night = night })
			abuse(true, true, seed, night)
			advance(Config.data.Admin.show.dropAt + 1)
			local root = show() and show():FindFirstChild("Opening")
			if root and root:GetAttribute("TitleStyle") == style and root:FindFirstChild("Title") then
				titled[style] = true
			end
			if style == "stamp" or style == "split" or style == "flicker" then
				snapshot("title-" .. style)
			end
			advance(Config.data.Admin.show.seconds)
			abuse(false)
			advance(12)
		end
	end
	local titles = 0
	for _ in titled do
		titles += 1
	end
	check("every one of the six titles lands its own way", titles == #AbuseNights.TitleStyles, titles)
	-- Every finale.
	local ended = {}
	for _, finale in AbuseNights.Finales do
		local night
		for _, n in AbuseNights.List do
			if n.finale == finale then
				night = n.id
				break
			end
		end
		abuse(true, false, 11, night)
		advance(3)
		serverSays("Salute", { op = "abuseFX", id = "confetti", by = "AJKR", seconds = 4, v = 2, line = "Confetti budget: unlimited. 🎉" })
		advance(5)
		-- (Each night earns its own Gilt.)
		LocalPlayer:SetAttribute("Gilt", (tonumber(LocalPlayer:GetAttribute("Gilt")) or 0) + 4000)
		if finale == "credits" then
			-- (Seen by a guest.)
			LocalPlayer:SetAttribute("MaisonAdmin", false)
		end
		abuse(false)
		advance(1.5)
		local waited = 1.5
		if finale == "credits" then
			advance(2)
			waited += 2
			check("the credits roll: starring the guest, and AJKR as the owner", textOnScreen("STARRING") ~= nil and textOnScreen("as  THE GUEST") ~= nil and textOnScreen("AJKR  as  THE OWNER") ~= nil)
			check("...with the Gilt the guest earned tonight", textOnScreen("GILT EARNED TONIGHT") ~= nil)
			local window = find(playerGui, function(d)
				return d.Name == "Window" and d.Parent ~= nil and d.Parent.Name == "FinaleShow"
			end)
			check("...rolling in a window clear of the keys along the top and AJKR's farewell at the foot", window ~= nil and window.ClipsDescendants == true and window.Size.Y.Scale == 1 and window.Size.Y.Offset <= -150 and window.Position.Y.Offset > 0)
			snapshot("finale-credits")
			LocalPlayer:SetAttribute("MaisonAdmin", true)
		elseif finale == "curtainCall" then
			advance(0.6)
			waited += 0.6
			snapshot("finale-curtain")
		elseif finale == "goldShower" then
			snapshot("finale-gold")
		end
		-- (Each finale shows the haul in its own time.)
		while waited < 14 and not ended[finale] do
			advance(0.5)
			waited += 0.5
			if textOnScreen("YOUR HAUL") ~= nil and textOnScreen("EFFECT WITNESSED") ~= nil then
				ended[finale] = true
			end
		end
		advance(12)
	end
	local endings = 0
	for _ in ended do
		endings += 1
	end
	check("every one of the six finales ends on the guest's haul (with the effects they saw)", endings == #AbuseNights.Finales, endings)
	-- On AJKR's own screen the credits never name AJKR twice; and Gilt that didn't change isn't
	-- read out as "+0".
	do
		local creditsNight
		for _, n in AbuseNights.List do
			if n.finale == "credits" then
				creditsNight = n.id
				break
			end
		end
		abuse(true, false, 11, creditsNight)
		advance(8)
		abuse(false)
		advance(3.5)
		check("on AJKR's screen: AJKR as the owner, and every guest as themselves", textOnScreen("AJKR  as  THE OWNER") ~= nil and textOnScreen("EVERY GUEST  as  THEMSELVES") ~= nil and textOnScreen("as  THE GUEST") == nil)
		check("...and no '+0' Gilt line when none was earned", textOnScreen("GILT EARNED TONIGHT") == nil and textOnScreen("+0") == nil)
		advance(26)
	end
	-- Every look of every effect: it plays, its own words on the screen.
	local plain = {}
	for id, list in AbuseNights.Variants do
		for v, looks in list do
			AbuseFX.play(id, 3, nil, nil, v)
			advance(0.3)
			if id ~= "shockwave" and id ~= "titan" and textOnScreen(looks.banner) == nil then
				table.insert(plain, id .. " " .. v)
			end
			if (id == "meteor" and v == 2) or (id == "blackHole" and v == 4) or (id == "goldWave" and v == 2) or (id == "blizzard" and v == 2) then
				snapshot("fx-" .. id .. "-" .. v)
			end
			advance(4)
			AbuseFX.play("stop")
			advance(1)
		end
	end
	check("every look of every effect plays, saying its own name", #plain == 0, plain[1])
	-- Every effect OFF ends the effect's fireworks for good (no rocket climbing on after it, nothing
	-- landing in a shell that's gone); a guest's own Salute fireworks go on regardless.
	do
		local Fireworks = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "Fireworks")
		local function shells()
			local f = (workspace:FindFirstChild("MaisonLocal") or workspace):FindFirstChild("Fireworks")
			return if f then #f:GetChildren() else 0
		end
		AbuseFX.play("fireworks", 40)
		advance(9)
		local during = shells()
		AbuseFX.play("stop")
		advance(0.2)
		local cleared = shells()
		advance(8)
		local left = {}
		local f = (workspace:FindFirstChild("MaisonLocal") or workspace):FindFirstChild("Fireworks")
		for _, c in (f and f:GetChildren() or {}) do
			table.insert(left, c.Name .. ":" .. c.ClassName)
		end
		check("Every effect OFF clears the effect's fireworks at once, and none follow", during > 0 and cleared == 0 and shells() == 0 and Fireworks.live() == 0, string.format("%d %d %d %d %s", during, cleared, shells(), Fireworks.live(), table.concat(left, ",")))
		Fireworks.show(30, { scale = 1, music = false })
		AbuseFX.play("fireworks", 30)
		advance(6)
		AbuseFX.play("stop")
		advance(6)
		check("...while a guest's Salute fireworks carry on", shells() > 0)
		advance(40)
	end
	-- An effect switched on keeps the looks the server gave it.
	workspace:SetAttribute("FxV_aurora", 3)
	workspace:SetAttribute("Fx_aurora", os.time())
	signalOf(workspace, "attr:Fx_aurora"):Fire()
	advance(1)
	check("an effect switched on wears the looks the server chose (the same in every server)", textOnScreen("GOLDEN AURORA") ~= nil)
	workspace:SetAttribute("Fx_aurora", nil)
	workspace:SetAttribute("FxV_aurora", nil)
	signalOf(workspace, "attr:Fx_aurora"):Fire()
	advance(3)
	-- The ribbon over the sorting table names tonight's night.
	abuse(true, false, 5, "midasHeist")
	advance(2)
	check("the ribbon at the table names tonight's night", (module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "ScreenFX").ribbonText(true) or ""):find("THE MIDAS HEIST", 1, true) ~= nil)
	abuse(false)
	advance(12)
	-- The chat: AJKR in gold for the owner; a look-alike shown by their @username.
	local realFor = ChatNames.playerFor
	local fakeOwner = { UserId = Config.data.Admin.ownerUserId, DisplayName = "XxxXxxX_77797", Name = "XxxXxxX_77797", GetAttribute = function()
		return nil
	end }
	local copycat = { UserId = 4242, DisplayName = "AJKR", Name = "copycat_99", GetAttribute = function()
		return nil
	end }
	ChatNames.playerFor = function(id)
		return if id == fakeOwner.UserId then fakeOwner elseif id == 4242 then copycat else nil
	end
	local ownerPrefix = ChatNames.prefix(fakeOwner.UserId, "XxxXxxX_77797:")
	local copyPrefix = ChatNames.prefix(4242, "AJKR:")
	check("in the chat the owner is AJKR, crowned in gold (never their username)", ownerPrefix ~= nil and string.find(ownerPrefix, "AJKR", 1, true) ~= nil and string.find(ownerPrefix, "XxxXxxX", 1, true) == nil, ownerPrefix)
	check("...and a guest calling themselves AJKR is shown by their @username", copyPrefix == "@copycat_99:", copyPrefix)
	ChatNames.playerFor = realFor
	check("no errors in Build 55's nights", #errors == errorsBefore, errors[errorsBefore + 1])
end)()

-- The owner's notices: Roblox's services having a moment is a calm house note, once; a real fault
-- is the panel's.
do
	local hud = playerGui:FindFirstChild("MaisonHud")
	local function notes()
		local n = 0
		for _, d in hud:GetChildren() do
			if d.Name == "HouseNote" then
				n += 1
			end
		end
		return n
	end
	local panelBefore = hud:FindFirstChild("Errors")
	serverSays("Errors", "Server: MemoryStoreService: InternalError: Unknown Error. API: SortedMap.GetRange, Data Structure: MaisonNoir_Board_library_week_2962")
	serverSays("Errors", "MemoryStoreService: InternalError: Unknown Error. API: SortedMap.GetSize, Data Structure: MaisonNoir_Soiree_2026-10-10")
	advance(0.5)
	local panel = hud:FindFirstChild("Errors")
	check("the live boards not answering is one calm house note, not a red error", notes() == 1 and textOnScreen("live leaderboards") ~= nil and (panel == nil or panel == panelBefore and (panel.Visible == false or textOnScreen("MemoryStoreService") == nil)), notes())
	snapshot("notes")
	advance(16)
	check("...which leaves by itself", notes() == 0)
	serverSays("Errors", "Server: MemoryStoreService: InternalError: Unknown Error. API: SortedMap.GetRange, Data Structure: nightly_2026-10-10")
	advance(0.5)
	check("...and isn't shown again", notes() == 0)
	serverSays("Errors", "Server: ServerScriptService.Server.Example:12: attempt to index nil with 'Name'")
	advance(0.5)
	panel = hud:FindFirstChild("Errors")
	check("a real fault shows in the owner's panel", panel ~= nil and panel.Visible and textOnScreen("attempt to index nil") ~= nil)
	if panel then
		local close = panel:FindFirstChild("Close", true)
		if close then
			signalOf(close, "Activated"):Fire()
		end
	end
	advance(0.5)
	check("...until it's hidden", panel == nil or panel.Visible == false)
end

---------------------------------------------------------------------------------------------------
-- 7z. The holiday games on this screen: Trick or Treat on Hallows Lane, the Turkey Round-Up in the
-- Harvest Field, Santa's sleigh to the North Pole and the gifts it brings home, the Great Egg Hunt,
-- the Luck of the Irish. Each place is built by the server's own modules (as the server builds
-- it); what the server would say and do is said and done here, and the screen is checked.
---------------------------------------------------------------------------------------------------
;(function()
	local errorsBefore = #errors
	local function client(...)
		return module("StarterPlayer", "StarterPlayerScripts", "Client", ...)
	end
	local HolidayGames = module("ReplicatedStorage", "Shared", "HolidayGames")
	local Layout = module("ReplicatedStorage", "Shared", "Layout")
	local HolidayPlay = client("World", "HolidayPlay")
	local HolidayLane = client("World", "HolidayLane")
	local HolidayField = client("World", "HolidayField")
	local HolidayPole = client("World", "HolidayPole")
	local HolidayEggs = client("World", "HolidayEggs")
	local HolidayKit = client("World", "HolidayKit")
	local SleighRide = client("World", "SleighRide")
	local HolidayPop = client("UI", "HolidayPop")
	local GiftOpening = client("UI", "GiftOpening")
	local function server(name)
		return module("ServerScriptService", "Server", "Holidays", name)
	end
	local Lane, Field, Pole, Eggs = server("Lane"), server("Field"), server("Pole"), server("Eggs")
	local cfg = Config.data.HolidayGames

	-- What the server works through, as the server's own games see it.
	local folder = Instance.new("Folder")
	folder.Name = "HolidayGames"
	folder.Parent = workspace
	signalOf(workspace, "ChildAdded"):Fire(folder)
	local ctx = {
		cfg = function()
			return cfg
		end,
		rng = Random.new(1225),
		folder = function()
			return folder
		end,
		rootOf = function(p)
			local c = p.Character
			return c and c:FindFirstChild("HumanoidRootPart")
		end,
		trusted = function()
			return true
		end,
		moved = function() end,
		saved = function(d)
			return d
		end,
		reward = function(_, gilt, gems)
			return gilt, gems
		end,
		gemsLeft = function()
			return cfg.gemsPerDay
		end,
		send = function() end,
		broadcast = function() end,
		teleport = function()
			return true
		end,
		sendHome = function() end,
		inArea = function()
			return false
		end,
		isSeated = function()
			return false
		end,
		award = function() end,
		tally = function() end,
		curio = function()
			return false
		end,
		salute = function() end,
		price = function()
			return nil
		end,
		year = function()
			return 2026
		end,
	}
	local function arrived(inst)
		signalOf(folder, "ChildAdded"):Fire(inst)
	end
	local function left(inst)
		signalOf(folder, "ChildRemoved"):Fire(inst)
	end
	local function setWs(key, value)
		-- (Lune keeps a whole-number attribute as a 32-bit float, so a server time such as
		-- 1790003033 reads back as 1790003072; a quarter second keeps it exact, as Roblox does.)
		if type(value) == "number" and value == math.floor(value) and math.abs(value) > 16777216 then
			value += 0.25
		end
		workspace:SetAttribute(key, value)
		signalOf(workspace, "attr:" .. key):Fire()
	end
	local function openGame(id)
		setWs(HolidayGames.ATTRIBUTE, id)
	end
	-- The guest, moved as the server moves them (and the camera with them).
	local function moveTo(cf)
		local at = cf * CFrame.new(0, 3, 0)
		root.CFrame = at
		root.Position = at.Position
		camera.CFrame = at * CFrame.new(0, 7, 16)
	end
	local homeSpot = Layout.Street.spawn
	-- The dock's holiday key, and pressing it.
	local function dockTile(label)
		local dockFrame = find(playerGui, function(d)
			return d.Name == "QuickDock" and d:IsA("Frame")
		end)
		return dockFrame and dockFrame:FindFirstChild(label)
	end
	local function pressTile(label)
		local t = dockTile(label)
		local k = t and t:FindFirstChild("Key")
		if not k then
			return false
		end
		signalOf(k, "Activated"):Fire()
		return true
	end
	local function holidayKeys()
		local n = 0
		for _, label in { "Treats", "Turkeys", "Sleigh", "Gifts", "Eggs", "Home" } do
			if dockTile(label) then
				n += 1
			end
		end
		return n
	end
	-- The objective card's words.
	local function card()
		local c = find(playerGui, function(d)
			return d.Name == "Objective" and d:IsA("Frame") and d.Parent ~= nil and d.Parent.Name == "MaisonHud"
		end)
		if not c then
			return ""
		end
		local words = {}
		for _, d in c:GetDescendants() do
			if d:IsA("TextLabel") then
				table.insert(words, d.Text)
			end
		end
		return table.concat(words, " | ")
	end
	local localFolder = workspace:FindFirstChild("MaisonLocal") or workspace
	local function mine(name)
		return localFolder:FindFirstChild(name)
	end
	local function count(container, name)
		local n = 0
		for _, d in (container and container:GetDescendants() or {}) do
			if d.Name == name then
				n += 1
			end
		end
		return n
	end
	-- (For the 3D viewer: Lune doesn't move what's jointed to a part when the part moves, so the
	-- rigs, the turkeys and what's welded on are put where their joints hold them.)
	local function pose(container)
		if not process.env.EXPORT_AT then
			return
		end
		local held = {}
		for _, w in container:GetDescendants() do
			if w:IsA("WeldConstraint") and w.Part0 and w.Part1 then
				table.insert(held, { w.Part0, w.Part1, w.Part0.CFrame:ToObjectSpace(w.Part1.CFrame) })
			end
		end
		local joints = {}
		for _, j in container:GetDescendants() do
			if j:IsA("JointInstance") and j.Part0 and j.Part1 then
				table.insert(joints, j)
			end
		end
		for _ = 1, 6 do
			for _, j in joints do
				j.Part1.CFrame = j.Part0.CFrame * j.C0 * j.C1:Inverse()
			end
		end
		for _ = 1, 3 do
			for _, h in held do
				h[2].CFrame = h[1].CFrame * h[3]
			end
		end
	end
	-- The server's answers to the guest's asks.
	local asks = {}
	local answers = {}
	invokeResults.HolidayAsk = function(req)
		table.insert(asks, req)
		local f = answers[req.op]
		if f then
			return f(req)
		end
		return { ok = true }
	end
	local function lastAsk(op)
		for i = #asks, 1, -1 do
			if asks[i].op == op then
				return asks[i]
			end
		end
		return nil
	end
	answers.state = function()
		return { ok = true, gifts = 0 }
	end
	answers.home = function()
		moveTo(homeSpot)
		return { ok = true }
	end
	moveTo(homeSpot)
	advance(1)

	-------------------------------------------------------------------------------------------
	-- All Hallows': Trick or Treat on Hallows Lane
	-------------------------------------------------------------------------------------------
	Lane.open(ctx)
	advance(0.2)
	local lane = folder:FindFirstChild("HallowsLane")
	local houses, hosts = {}, 0
	for _, h in (lane and lane:GetChildren() or {}) do
		local i = h:GetAttribute("Door")
		if type(i) == "number" then
			houses[i] = h
			for _, d in h:GetChildren() do
				if d:IsA("Model") and d:GetAttribute("Host") then
					hosts += 1
				end
			end
		end
	end
	check("Hallows Lane: nine grand houses down a lamplit street, a host in costume behind every door", lane ~= nil and #houses == 9 and hosts == 9, hosts)
	arrived(lane)
	openGame("halloween")
	-- (The holiday's title comes first; the card steps aside for it.)
	advance(0.6)
	check("the house is dressed for it, its title naming the game (no hunt round the house today)", textOnScreen("TRICK OR TREAT") ~= nil and textOnScreen("Knock at every door on Hallows Lane") ~= nil)
	advance(6)
	check("Trick or Treat: its key stands at the foot of the dock", dockTile("Treats") ~= nil and holidayKeys() == 1)
	check("...and the card says what's on", string.find(norm(card()), norm("Trick or Treat"), 1, true) ~= nil, card())
	-- The Gem Shop puts the holiday's own things first, marked in season.
	local GemShopPanel = client("UI", "GemShopPanel")
	GemShopPanel.open()
	advance(0.6)
	local seasonShelf = find(playerGui, function(d)
		return d:IsA("TextButton") and d.Name == "Shelf_season"
	end)
	if seasonShelf and not textOnScreen("Jack the Lantern") then
		signalOf(seasonShelf, "Activated"):Fire()
		advance(0.3)
	end
	check("the Gem Shop shows the holiday's own things on a shelf of their own, marked in season", seasonShelf ~= nil and textOnScreen("IN SEASON") ~= nil and textOnScreen("Jack the Lantern") ~= nil and textOnScreen("Moonlit Bats") ~= nil and textOnScreen("Trick-or-Treater") ~= nil)
	snapshot("gemshop-season")
	client("UI", "Root").close()
	advance(0.6)
	answers.go = function()
		moveTo(Lane.arrival(ctx, LocalPlayer))
		return { ok = true }
	end
	check("the key takes the guest to the Lane", pressTile("Treats"))
	advance(0.15)
	local fader = playerGui:FindFirstChild("HolidayTravel")
	check("...through a fade to black and back", fader ~= nil and fader:FindFirstChildWhichIsA("Frame") ~= nil)
	advance(1.6)
	check("...and asks the house to go", lastAsk("go") ~= nil)
	check("there: the key reads Home", HolidayPlay.area() == "lane" and dockTile("Home") ~= nil and dockTile("Treats") == nil, HolidayPlay.area())
	check("...the card counts the doors knocked at", string.find(card(), "Doors knocked at: 0 of 9", 1, true) ~= nil, card())
	local dressing = mine("HolidayLane")
	check("...and the Lane is dressed on this screen: mist on the cobbles, candles in the air, bats, a pumpkin over every door", dressing ~= nil and count(dressing, "Mist") >= 4 and count(dressing, "Candle") >= 6 and count(dressing, "Bat") >= 2 and count(dressing, "DoorMarker") == 9)
	pose(folder)
	snapshot("holiday-lane")
	-- A knock at the first door.
	local house = houses[1]
	local leaf = house and house:FindFirstChild("DoorL")
	local leafPart = leaf and leaf:FindFirstChildWhichIsA("BasePart", true)
	local leafWas = leafPart and leafPart.CFrame
	local host
	for _, d in (house and house:GetChildren() or {}) do
		if d:IsA("Model") and d:GetAttribute("Host") then
			host = d
		end
	end
	local hostRoot = host and host:FindFirstChild("HumanoidRootPart")
	local hostWas = hostRoot and hostRoot.CFrame
	serverSays("Holiday", { op = "door", i = 1, by = LocalPlayer.UserId, treat = "truffle" })
	advance(0.9)
	check("a knock: the door swings open on its lit hall", leafPart ~= nil and leafWas ~= nil and (leafPart.CFrame.Position - leafWas.Position).Magnitude > 1)
	check("...its host steps out onto the threshold", hostRoot ~= nil and hostWas ~= nil and (hostRoot.CFrame.Position - hostWas.Position).Magnitude > 1.5)
	pose(folder)
	snapshot("lane-door")
	advance(0.4)
	check("...and throws the treat to whoever knocked", HolidayKit.inFlight() > 0, HolidayKit.inFlight())
	serverSays("Holiday", { op = "treat", i = 1, host = "Lady Belladonna", line = "A gold-leaf truffle for you, darling.", treat = "truffle", treatName = "a gold-leaf truffle", gilt = 45, gems = 1, visited = { 1 }, total = 9 })
	advance(0.3)
	local says = host and host:FindFirstChild("Head") and host.Head:FindFirstChild("HostSays")
	local saysText = says and says:FindFirstChildWhichIsA("TextLabel")
	check("the host says their line", saysText ~= nil and saysText.Text == "A gold-leaf truffle for you, darling.")
	advance(1.9)
	check("what it paid pops up: the treat, who gave it, +45 Gilt and +1 Gem", HolidayPop.count() >= 1 and textOnScreen("Lady Belladonna") ~= nil and textOnScreen("+45 GILT") ~= nil and textOnScreen("+1 GEM") ~= nil)
	check("...the treat landed", HolidayKit.inFlight() == 0)
	snapshot("lane-treat")
	advance(3)
	check("the door closes behind its host", leafPart ~= nil and leafWas ~= nil and (leafPart.CFrame.Position - leafWas.Position).Magnitude < 0.05 and hostRoot ~= nil and (hostRoot.CFrame.Position - hostWas.Position).Magnitude < 0.05)
	local markers = {}
	for _, d in (mine("HolidayLane") or folder):GetDescendants() do
		if d.Name == "Glyph" and d:IsA("TextLabel") then
			table.insert(markers, d.Text)
		end
	end
	local ticks = 0
	for _, t in markers do
		if t == "✓" then
			ticks += 1
		end
	end
	check("a gold tick over the door knocked at; a pumpkin over the rest", #markers == 9 and ticks == 1, table.concat(markers, " "))
	check("...and the card counts it", string.find(card(), "Doors knocked at: 1 of 9", 1, true) ~= nil, card())
	-- A knock at a door already visited this round: the door opens, no treat.
	serverSays("Holiday", { op = "door", i = 1, by = LocalPlayer.UserId, empty = true })
	advance(1.4)
	check("back at the same door: the host waves, no treat thrown", HolidayKit.inFlight() == 0)
	advance(4)
	-- The ninth door: a full bag.
	local all = {}
	for i = 1, 9 do
		table.insert(all, i)
	end
	serverSays("Holiday", { op = "treat", i = 9, host = "The Midnight Hostess", line = "The finest treat on the Lane.", treat = "truffle", treatName = "a midnight truffle", gilt = 150, gems = 0, visited = all, total = 9, full = true, bonusGilt = 300, bonusGems = 3 })
	advance(2.8)
	check("every door: a full bag, and its bonus", textOnScreen("A full bag!") ~= nil and textOnScreen("+300 GILT") ~= nil and textOnScreen("+3 GEMS") ~= nil)
	snapshot("lane-fullbag")
	advance(5)
	check("the reward cards go by themselves", HolidayPop.count() == 0, HolidayPop.count())
	-- Home, with the same key.
	check("Home takes the guest back to the Maison", pressTile("Home"))
	advance(2)
	check("...and asks the house", lastAsk("home") ~= nil)
	check("back at the Maison: the Treats key again, and the Lane's dressing put away", HolidayPlay.area() == nil and dockTile("Treats") ~= nil and dockTile("Home") == nil and count(mine("HolidayLane"), "Mist") == 0, HolidayPlay.area())
	Lane.close(ctx)
	left(lane)
	openGame(nil)
	advance(0.8)
	check("All Hallows' over: the key leaves the dock", holidayKeys() == 0)

	-------------------------------------------------------------------------------------------
	-- Thanksgiving: the Turkey Round-Up
	-------------------------------------------------------------------------------------------
	Field.open(ctx)
	local field = folder:FindFirstChild("HarvestField")
	arrived(field)
	openGame("thanksgiving")
	advance(6.6)
	check("the Turkey Round-Up: its key in the dock", dockTile("Turkeys") ~= nil and holidayKeys() == 1)
	answers.go = function()
		moveTo(Field.arrival(ctx, LocalPlayer))
		return { ok = true }
	end
	pressTile("Turkeys")
	advance(2)
	check("in the Harvest Field: every turkey drawn, bronze and fanned", HolidayPlay.area() == "field" and HolidayField.count() == cfg.field.turkeys, HolidayField.count())
	check("...festoon lights from the barn, leaves falling", count(mine("HolidayField"), "Bulb") >= 10 and count(mine("HolidayField"), "Leaf") >= 4)
	check("...and the card says what to do", string.find(card(), "Run into a turkey", 1, true) ~= nil, card())
	-- The count at the foot of the screen, and the offer once the free catches are used.
	serverSays("Holiday", { op = "turkeyMeter", free = 3, of = 5, held = 0, unlimited = false, caught = 2, more = 10, prices = { turkeyMore = 25, turkeyHunter = 99 } })
	advance(0.5)
	check("the turkey meter: free catches left of five, and how many caught", textOnScreen("3 / 5") ~= nil and textOnScreen("FREE CATCHES") ~= nil)
	snapshot("turkey-meter")
	serverSays("Holiday", { op = "turkeyOut", free = 0, of = 5, held = 0, unlimited = false, caught = 5, more = 10, prices = { turkeyMore = 25, turkeyHunter = 99 } })
	advance(0.5)
	check("free catches used: the offer, each choice with its price, and the free way said plainly", textOnScreen("Unlimited all holiday") ~= nil and textOnScreen("+10 turkeys") ~= nil and textOnScreen("quarter of an hour") ~= nil)
	snapshot("turkey-offer")
	press("Unlimited all holiday  ·  " .. utf8.char(0xE002) .. " 99")
	advance(0.2)
	check("pressing a choice asks the server for that product (never a price)", (function()
		for _, r in sent do
			local m = r.message
			if r.remote == "HolidayAsk" and type(m) == "table" and type(m[1]) == "table" and m[1].op == "buy" and m[1].n == 2 then
				return true
			end
		end
		return false
	end)())
	press("Not now")
	-- (Back to a fresh visit's count for what follows.)
	serverSays("Holiday", { op = "turkeyMeter", free = 5, of = 5, held = 0, unlimited = false, caught = 0, more = 10, prices = { turkeyMore = 25, turkeyHunter = 99 } })
	advance(0.5)
	-- The turkeys run (the server moves them); each drawn bird follows its own.
	local birds = mine("HolidayTurkeys")
	for _ = 1, 30 do
		Field.step(ctx, 0.1)
		advance(0.1)
	end
	local list = Field.turkeys()
	local worst = 0
	for _, t in list do
		local nearest = math.huge
		for _, m in (birds and birds:GetChildren() or {}) do
			if m.PrimaryPart then
				nearest = math.min(nearest, (m.PrimaryPart.CFrame.Position - (t.part.CFrame.Position - Vector3.new(0, 1.5, 0))).Magnitude)
			end
		end
		worst = math.max(worst, nearest)
	end
	check("the turkeys run and every one drawn keeps with its own", #list > 0 and worst < 2, worst)
	pose(birds)
	pose(folder)
	if process.env.EXPORT_AT == "holiday-field" then
		for k = 1, math.min(4, #list) do
			print("TURKEY", list[k].part.CFrame.Position)
		end
	end
	snapshot("holiday-field")
	local t1 = list[1]
	serverSays("Holiday", { op = "caught", id = t1.id, by = LocalPlayer.UserId, golden = false, at = t1.part.CFrame.Position })
	serverSays("Holiday", { op = "turkey", golden = false, gilt = 40, gems = 1 })
	advance(0.3)
	check("a catch: feathers and a GOBBLE!", textOnScreen("GOBBLE!") ~= nil or find(workspace, function(d)
		return d:IsA("TextLabel") and d.Text == "GOBBLE!"
	end) ~= nil)
	check("...and what it paid", textOnScreen("Caught one!") ~= nil and textOnScreen("+40 GILT") ~= nil)
	check("...the card counts the catch", string.find(card(), "Turkeys caught: 1", 1, true) ~= nil, card())
	serverSays("Holiday", { op = "goldenTurkey" })
	advance(0.3)
	check("a golden turkey out of the barn is called out", textOnScreen("A golden turkey has walked out of the barn!") ~= nil)
	serverSays("Holiday", { op = "turkey", golden = true, gilt = 400, gems = 4 })
	advance(0.5)
	check("the golden one: a bigger card", textOnScreen("The golden turkey!") ~= nil and textOnScreen("+4 GEMS") ~= nil)
	snapshot("field-golden")
	advance(6)
	pressTile("Home")
	advance(2)
	check("home from the field: the turkeys rest (nothing drawn moves while no one's there)", HolidayPlay.area() == nil and count(mine("HolidayField"), "Bulb") == 0)
	Field.close(ctx)
	left(field)
	openGame(nil)
	advance(0.8)
	check("...and with Thanksgiving over, every turkey drawn here is gone", HolidayField.count() == 0 and holidayKeys() == 0)

	-------------------------------------------------------------------------------------------
	-- Christmas: Santa's sleigh to the North Pole
	-------------------------------------------------------------------------------------------
	Pole.open(ctx)
	advance(0.2)
	local pole = folder:FindFirstChild("NorthPole")
	local sleigh = folder:FindFirstChild("SantasSleigh")
	arrived(pole)
	arrived(sleigh)
	signalOf(workspace, "attr:SleighState"):Fire()
	openGame("christmas")
	advance(6.8)
	check("Christmas: Santa's sleigh at the kerb, its key in the dock", sleigh ~= nil and dockTile("Sleigh") ~= nil and holidayKeys() == 1)
	check("...Santa at the reins", sleigh ~= nil and sleigh:FindFirstChild("Santa") ~= nil)
	local signGui = sleigh and sleigh.PrimaryPart and sleigh.PrimaryPart:FindFirstChild("SleighSign")
	check("...its sign: To the North Pole! Board now", signGui ~= nil and signGui.Line.Text == "To the North Pole! Board now")
	check("...and the card says where it is", string.find(card(), "waiting at the kerb", 1, true) ~= nil, card())
	check("the gifts in the snow at the Pole are drawn on this screen", HolidayPole.count() == cfg.pole.gifts, HolidayPole.count())
	pose(folder)
	snapshot("holiday-sleigh")
	-- The sleigh's way over the house is clear of it, both ways: no part of the house, the street or
	-- its Christmas dressing within the sleigh's reach of any point along the flight (away from the
	-- kerb it starts and ends at).
	do
		local boxes = {}
		local skip = { folder, mine("HolidaySleigh") }
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.95 and math.max(d.Size.X, d.Size.Y, d.Size.Z) >= 1.5 and d.Name ~= "Terrain" then
				local inSkip = false
				for _, s in skip do
					if s and d:IsDescendantOf(s) then
						inSkip = true
					end
				end
				if not inSkip and d.Parent ~= character then
					local cf, s = d.CFrame, d.Size / 2
					local ext = Vector3.new(
						math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
						math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
						math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
					)
					-- (The road, the kerbs and the snow on them are what it runs on, not in its way.)
					if cf.Position.Y + ext.Y > 2 then
						table.insert(boxes, { at = cf.Position, ext = ext, name = d:GetFullName() })
					end
				end
			end
		end
		local hit = nil
		local reach = 5
		local kerb = HolidayGames.HOME_SLEIGH.Position
		local ways = {
			{ "out", HolidayGames.flightPoints(true) },
			{ "home", HolidayGames.flightPoints(false) },
			{ "flyover from the kerb", SleighRide.flyoverPoints(true) },
			{ "flyover from the north", SleighRide.flyoverPoints(false) },
		}
		for _, way in ways do
			local path = HolidayGames.path(way[2])
			for i = 0, 900 do
				local p = HolidayGames.travel(path, i / 900)
				if (p - kerb).Magnitude > 46 and Vector3.new(p.X, 0, p.Z).Magnitude < 900 then
					for _, b in boxes do
						local d = p - b.at
						if math.abs(d.X) < b.ext.X + reach and math.abs(d.Y) < b.ext.Y + reach and math.abs(d.Z) < b.ext.Z + reach then
							hit = string.format("%s at %.0f, %.0f, %.0f (%s)", b.name, p.X, p.Y, p.Z, way[1])
							break
						end
					end
				end
				if hit then
					break
				end
			end
		end
		check("the sleigh's flight clears the house, the street and its dressing, both ways (and Santa's Flyover's, both ways)", hit == nil, hit)
	end
	-- Santa's Flyover (a salute): the sleigh lifts off from the kerb, circles the house with the
	-- giver's name in gold beside it, and lands where it was.
	serverSays("Salute", { op = "salute", id = "sleigh", by = "Ada", userId = 2, seconds = 30, effects = { "sleigh", "goldLeaf" }, line = "Ada called Santa's sleigh over the house." })
	advance(1)
	local flyCopy = SleighRide.flyoverCopy()
	local banner = flyCopy and flyCopy.PrimaryPart and flyCopy.PrimaryPart:FindFirstChild("Banner")
	local parkedBody = sleigh and sleigh:FindFirstChild("Floor", true)
	-- (The banner's label is a child called "Name": found as a child, not the banner's own Name.)
	local giver = banner and banner:FindFirstChild("Name")
	check("Santa's Flyover: the sleigh takes off from the kerb, the giver's name in gold beside it", flyCopy ~= nil and giver ~= nil and string.find(tostring(giver.Text), "Ada", 1, true) ~= nil and parkedBody ~= nil and parkedBody.LocalTransparencyModifier == 1, giver and giver.Text)
	advance(13)
	local flyAt = flyCopy and flyCopy.PrimaryPart and flyCopy.PrimaryPart.CFrame.Position
	check("...high round the house", flyAt ~= nil and flyAt.Y > 60, flyAt)
	pose(flyCopy)
	snapshot("sleigh-flyover")
	advance(18)
	check("...and lands where it was, and the parked sleigh is back", SleighRide.flyoverCopy() == nil and parkedBody ~= nil and parkedBody.LocalTransparencyModifier == 0)
	answers.board = function()
		return { ok = true }
	end
	pressTile("Sleigh")
	advance(0.3)
	check("the Sleigh key asks to board", lastAsk("board") ~= nil)
	-- Off it goes (the server takes off with the guest aboard).
	local body = sleigh and sleigh:FindFirstChild("Floor", true)
	local flight = cfg.pole.flight
	LocalPlayer:SetAttribute("SleighRide", "toPole")
	setWs("SleighT0", workspace:GetServerTimeNow())
	setWs("SleighFlight", flight)
	setWs("SleighState", "toPole")
	moveTo(HolidayGames.poleSleigh() * CFrame.new(0, 320, 0))
	advance(0.5)
	local copy = SleighRide.copy()
	check("take-off: the sleigh flies on every screen (a copy of it, reindeer and all)", SleighRide.flying() and copy ~= nil and copy:FindFirstChild("Reindeer") ~= nil)
	check("...the parked one hidden meanwhile", body ~= nil and body.LocalTransparencyModifier == 1)
	local rideGui = playerGui:FindFirstChild("SleighRide")
	check("aboard: a film, between black bars, the camera riding with the sleigh", SleighRide.riding() and rideGui ~= nil and rideGui:FindFirstChild("BarTop") ~= nil and camera.CameraType == roblox.Enum.CameraType.Scriptable)
	check("...the card steps aside for it", card() == "")
	local copyRoot = copy and copy.PrimaryPart
	local startAt = copyRoot and copyRoot.CFrame.Position
	advance(flight * 0.25)
	local quarter = copyRoot and copyRoot.CFrame.Position
	check("...off along the street and up over the house", startAt ~= nil and quarter ~= nil and quarter.Y > startAt.Y + 20, quarter)
	advance(flight * 0.27)
	local high = copyRoot and copyRoot.CFrame.Position
	check("...high over the clouds", high ~= nil and high.Y > 200, high)
	check("...the place's name as it nears", textOnScreen("THE NORTH POLE") ~= nil)
	pose(copy)
	if process.env.EXPORT_AT == "sleigh-flight" and copyRoot then
		print("SLEIGH", copyRoot.CFrame.Position, copyRoot.CFrame.LookVector)
	end
	snapshot("sleigh-flight")
	advance(flight * 0.46)
	local landing = copyRoot and copyRoot.CFrame.Position
	check("...and down on the North Pole's pad", landing ~= nil and (landing - HolidayGames.poleSleigh().Position).Magnitude < 12, landing and (landing - HolidayGames.poleSleigh().Position).Magnitude)
	-- Landed (as the server lands it).
	if sleigh then
		sleigh:PivotTo(HolidayGames.poleSleigh())
	end
	moveTo(HolidayGames.poleSleigh() * CFrame.new(8, 0, -2))
	LocalPlayer:SetAttribute("SleighRide", nil)
	setWs("SleighLeaves", workspace:GetServerTimeNow() + cfg.pole.stay)
	setWs("SleighState", "pole")
	serverSays("Holiday", { op = "arrived", place = "pole" })
	advance(1.5)
	check("landed: the film ends and the camera is the guest's again", not SleighRide.flying() and body ~= nil and body.LocalTransparencyModifier == 0 and camera.CameraType == roblox.Enum.CameraType.Custom)
	check("at the North Pole: no key (the sleigh is the way home)", HolidayPlay.area() == "pole" and holidayKeys() == 0)
	check("...snow falling, the great tree lit with its star, lights along the workshop", count(mine("HolidayPole"), "TreeBulb") >= 30 and count(mine("HolidayPole"), "TreeStar") == 1 and count(mine("HolidayPole"), "EaveBulb") >= 10)
	local pillNow = find(playerGui, function(d)
		return d.Name == "SleighClock"
	end)
	check("...the time before the sleigh leaves, at the top of the screen", pillNow ~= nil and textOnScreen("THE SLEIGH LEAVES FOR HOME IN") ~= nil and string.match(pillNow.Digits.Text, "^1:2%d$") ~= nil, pillNow and pillNow.Digits.Text)
	check("...and the card says what to do", string.find(card(), "In your arms: 0", 1, true) ~= nil, card())
	-- A gift picked up (the server takes it from the snow and says who).
	local gifts = Pole.gifts()
	local g1 = gifts[1]
	local giftsFolder = pole and pole:FindFirstChild("Gifts")
	local id1 = g1 and g1:GetAttribute("Id")
	if g1 then
		g1.Parent = nil
		signalOf(giftsFolder, "ChildRemoved"):Fire(g1)
	end
	serverSays("Holiday", { op = "picked", id = id1, by = LocalPlayer.UserId })
	LocalPlayer:SetAttribute("GiftsCarried", 3)
	signalOf(LocalPlayer, "attr:GiftsCarried"):Fire()
	advance(0.1)
	check("a gift picked up flies into the guest's arms", HolidayKit.inFlight() > 0)
	advance(0.6)
	local stack = mine("HolidayStacks")
	check("...the gifts carried are stacked in front of them", stack ~= nil and count(stack, "GiftStack") == 1 and #(stack:FindFirstChild("GiftStack"):GetChildren()) == 3)
	check("...a ring of gold light where to load them", mine("HolidayGifts") ~= nil and mine("HolidayGifts"):FindFirstChild("LoadRing") ~= nil)
	check("...and the card counts them", string.find(card(), "In your arms: 3", 1, true) ~= nil, card())
	check("the gift meter at the foot of the screen: in your arms of five, on the sleigh of fifteen", textOnScreen("IN YOUR ARMS") ~= nil and textOnScreen("3 / 5") ~= nil and textOnScreen("/ 15") ~= nil)
	snapshot("pole-meter")
	pose(folder)
	pose(stack)
	snapshot("holiday-pole")
	serverSays("Holiday", { op = "loaded", by = LocalPlayer.UserId, n = 3 })
	LocalPlayer:SetAttribute("GiftsCarried", nil)
	signalOf(LocalPlayer, "attr:GiftsCarried"):Fire()
	serverSays("Holiday", { op = "gifts", carrying = 0, loaded = 3, gifts = 3 })
	advance(0.5)
	check("loaded: the gifts fly into Santa's sack", HolidayKit.inFlight() > 0)
	check("...and the card says so", textOnScreen("Loaded on the sleigh") ~= nil and textOnScreen("3 gifts, safe in Santa's sack.") ~= nil)
	advance(1)
	check("...the ring goes with nothing in their arms", mine("HolidayGifts"):FindFirstChild("LoadRing") == nil)
	snapshot("pole-loaded")
	-- Fifteen seconds left: the clock turns red.
	setWs("SleighLeaves", workspace:GetServerTimeNow() + 12)
	advance(0.5)
	local clockPill = find(playerGui, function(d)
		return d.Name == "SleighClock"
	end)
	check("the last seconds: the clock turns red", clockPill ~= nil and clockPill.Digits.TextColor3.R > 0.9 and clockPill.Digits.TextColor3.G < 0.6)
	snapshot("pole-clock")
	-- Home (the server takes everyone at the Pole home with the sleigh).
	LocalPlayer:SetAttribute("SleighRide", "toHome")
	setWs("SleighLeaves", nil)
	setWs("SleighT0", workspace:GetServerTimeNow())
	setWs("SleighState", "toHome")
	moveTo(HolidayGames.HOME_SLEIGH * CFrame.new(0, 320, 0))
	advance(flight * 0.6)
	check("homeward: the title says where", textOnScreen("HOME FOR CHRISTMAS") ~= nil)
	advance(flight * 0.45)
	if sleigh then
		sleigh:PivotTo(HolidayGames.HOME_SLEIGH)
	end
	moveTo(CFrame.new(-11, 0.1, -48))
	LocalPlayer:SetAttribute("SleighRide", nil)
	setWs("SleighState", "home")
	serverSays("Holiday", { op = "arrived", place = "home", gifts = 3 })
	advance(0.5)
	check("home: the Gifts key, with how many are waiting", dockTile("Gifts") ~= nil and dockTile("Gifts"):FindFirstChild("Count") ~= nil and dockTile("Gifts").Count.Text == "3")
	-- The gifts open at home: a screen of their own, the odds written at the foot.
	local opened = {
		{ { kind = "gems", gilt = 0, gems = 3 } },
		{ { kind = "gilt", gilt = 60, gems = 0 }, { kind = "moreGilt", gilt = 240, gems = 0 } },
	}
	local giftsLeft = 3
	answers.open = function(req)
		local r = table.remove(opened, 1)
		if not r then
			return { ok = false, why = "No gifts to open." }
		end
		giftsLeft -= #r
		return { ok = true, results = r, gifts = giftsLeft, n = req.n }
	end
	advance(2.2)
	check("...and the gift screen opens by itself", GiftOpening.isOpen() and textOnScreen("Gifts from the North Pole") ~= nil and textOnScreen("3 gifts to open") ~= nil)
	check("...with what a gift holds, and its odds, written at the foot (and that it's free)", textOnScreen("40–90 Gilt 60%") ~= nil and textOnScreen("12–18 Gems 2%") ~= nil and textOnScreen("never sold") ~= nil)
	snapshot("gifts")
	check("OPEN", press("Open"))
	advance(2.6)
	check("...it shakes, the lid flies off and what was in it rises out: +3 Gems", textOnScreen("+3 GEMS") ~= nil and textOnScreen("Gems!") ~= nil and lastAsk("open") ~= nil and lastAsk("open").n == 1)
	snapshot("gift-reveal")
	check("...and the dock's count goes down", dockTile("Gifts") ~= nil and dockTile("Gifts").Count.Text == "2")
	advance(1)
	check("OPEN ALL", press("Open all"))
	advance(3)
	check("...the rest, each in turn, and the totals", textOnScreen("+300 GILT") ~= nil and textOnScreen("Every gift opened") ~= nil)
	check("...with the sleigh still coming: Ride again", textOnScreen("Ride again") ~= nil)
	snapshot("gifts-all")
	camera.ViewportSize = Vector2.new(390, 844)
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.5)
	snapshot("gifts-phone")
	camera.ViewportSize = DEVICE.size
	signalOf(camera, "prop:ViewportSize"):Fire()
	advance(0.5)
	press("Close")
	advance(0.8)
	check("closed: every gift opened, the Sleigh key is back", not GiftOpening.isOpen() and dockTile("Sleigh") ~= nil and dockTile("Gifts") == nil)
	Pole.close(ctx)
	left(pole)
	left(sleigh)
	openGame(nil)
	advance(0.8)
	check("Christmas over: no gifts drawn, no key", HolidayPole.count() == 0 and holidayKeys() == 0)

	-------------------------------------------------------------------------------------------
	-- Easter: the Great Egg Hunt (in the house)
	-------------------------------------------------------------------------------------------
	Eggs.open(ctx)
	local eggs = folder:FindFirstChild("Eggs")
	arrived(eggs)
	openGame("easter")
	advance(6.8)
	check("the Great Egg Hunt: painted eggs hidden round the house, drawn on this screen", HolidayEggs.left() == cfg.eggs.count and count(mine("HolidayEggs"), "Root") >= cfg.eggs.count, HolidayEggs.left())
	check("...its key shows how many are left", dockTile("Eggs") ~= nil and dockTile("Eggs").Count.Text == tostring(cfg.eggs.count))
	check("...and the card says where to look", string.find(card(), "painted eggs hidden round the house", 1, true) ~= nil, card())
	pose(eggs)
	if process.env.EXPORT_AT == "holiday-eggs" then
		for k, e in Eggs.list() do
			if k <= 6 then
				print("EGG", e.CFrame.Position, e:GetAttribute("Golden"))
			end
		end
	end
	snapshot("holiday-eggs")
	local e1 = Eggs.list()[1]
	local at = e1 and e1.CFrame.Position
	if e1 then
		e1.Parent = nil
		signalOf(eggs, "ChildRemoved"):Fire(e1)
	end
	serverSays("Holiday", { op = "egg", id = 1, by = LocalPlayer.UserId, golden = false, at = at })
	serverSays("Holiday", { op = "eggFound", golden = false, gilt = 35, gems = 0, left = cfg.eggs.count - 1 })
	advance(0.6)
	check("an egg found: confetti, and what it paid", textOnScreen("A painted egg") ~= nil and textOnScreen("+35 GILT") ~= nil)
	check("...one fewer on the key", dockTile("Eggs").Count.Text == tostring(cfg.eggs.count - 1))
	advance(5)
	Eggs.close(ctx)
	left(eggs)
	openGame(nil)
	advance(0.8)
	check("Easter over: the eggs are gone from this screen", HolidayEggs.left() == 0 and holidayKeys() == 0)

	-------------------------------------------------------------------------------------------
	-- St Patrick's: the luck of the Irish (no key: it's at every table)
	-------------------------------------------------------------------------------------------
	openGame("stPatrick")
	advance(6.8)
	check("St Patrick's: no key, and the card says the luck is at every table", holidayKeys() == 0 and string.find(norm(card()), norm("Luck of the Irish"), 1, true) ~= nil, card())
	openGame(nil)
	advance(0.8)
	folder:Destroy()
	invokeResults.HolidayAsk = nil
	moveTo(homeSpot)
	advance(1)
	check("no errors in the holiday games", #errors == errorsBefore, errors[errorsBefore + 1])
end)()

---------------------------------------------------------------------------------------------------
-- 7b. Things side by side, long lines, and pictures every screen can draw
---------------------------------------------------------------------------------------------------
;(function()
	local errorsBefore = #errors
	-- Two things close together (the piano and the salute beside it): their cards stand in one
	-- tidy column beside the guest, the same width, never on top of each other.
	local Prompts = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Prompts")
	local made = {}
	for i, spec in { { "Play the piano", "The grand piano", "E" }, { "Salute the house", "An encore, gold confetti, fireworks", "F" } } do
		local part = Instance.new("Part")
		part.Name = "PromptThing" .. i
		part.Parent = workspace
		local p = Instance.new("ProximityPrompt")
		p.Style = roblox.Enum.ProximityPromptStyle.Custom
		p.ActionText = spec[1]
		p.ObjectText = spec[2]
		p.KeyboardKeyCode = roblox.Enum.KeyCode[spec[3]]
		p.Parent = part
		table.insert(made, p)
		services.ProximityPromptService.PromptShown:Fire(p, roblox.Enum.ProximityPromptInputType.Keyboard)
	end
	advance(0.6)
	local cards = Prompts.cards()
	local column = cards[1] and cards[1].Parent
	local sameWidth = #cards == 2 and cards[1].Size.X.Offset == cards[2].Size.X.Offset
	check("two things side by side: one column of cards, the same width, in a list (never piled up)", #cards == 2 and sameWidth and column ~= nil and column:FindFirstChildOfClass("UIListLayout") ~= nil and cards[1].Parent == cards[2].Parent, #cards)
	check("...in the screen's own layer, not floating over the things (or anyone's name)", column ~= nil and column:FindFirstAncestorOfClass("BillboardGui") == nil and column:FindFirstAncestorWhichIsA("ScreenGui") ~= nil)
	local fits = true
	for _, card in cards do
		local action = card:FindFirstChild("Action") :: any
		local object = card:FindFirstChild("Object") :: any
		local Theme = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Theme")
		local room = card.Size.X.Offset - action.Position.X.Offset - 12
		if Theme.measure(action.Text, action.TextSize, action.FontFace).X > room or Theme.measure(object.Text, object.TextSize, object.FontFace).X > room then
			fits = false
		end
	end
	check("...each card wide enough for its words", fits)
	snapshot("prompts")
	for _, p in made do
		services.ProximityPromptService.PromptHidden:Fire(p)
		p.Parent.Parent = nil
	end
	advance(0.3)
	check("walking away: the cards go", #Prompts.cards() == 0)

	-- The strip's lines: each capsule as wide as its words; a long line wraps to a second line in
	-- a taller capsule, never running off its edge.
	local HouseEvents = module("ReplicatedStorage", "Shared", "HouseEvents")
	local longest = {}
	for _, e in HouseEvents.List do
		if not e.holiday then
			table.insert(longest, e)
		end
	end
	table.sort(longest, function(a, b)
		return #a.line > #b.line
	end)
	local soon = workspace:GetServerTimeNow() + 900
	local ids = { longest[1].id, "goldenHour" }
	for _, id in ids do
		workspace:SetAttribute("Event_" .. id, soon)
		signalOf(workspace, "attr:Event_" .. id):Fire()
	end
	advance(1.2)
	local strip = find(playerGui, function(d)
		return d.Name == "HouseEvents" and d:IsA("Frame")
	end)
	local Theme = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Theme")
	local problems = {}
	local widths = {}
	for _, id in ids do
		local holder = strip and strip:FindFirstChild(id)
		local words = holder and holder:FindFirstChild("Words") :: any
		if not words then
			table.insert(problems, id .. ": no capsule")
			continue
		end
		local room = holder.Size.X.Offset + words.Size.X.Offset
		local wide = Theme.measure(words.Text, words.TextSize, words.FontFace).X
		if not words.TextWrapped and wide > room then
			table.insert(problems, string.format("%s: %d wide in %d", id, wide, room))
		end
		if words.TextWrapped and holder.Size.Y.Offset <= 30 then
			table.insert(problems, id .. ": wrapped in a one-line capsule")
		end
		if holder.Size.X.Offset > 500 then
			table.insert(problems, id .. ": wider than the strip")
		end
		widths[id] = holder.Size.X.Offset
	end
	check("the strip: every line whole inside its capsule (a long one on two lines)", #problems == 0, table.concat(problems, "; "))
	check("...and each capsule as wide as its words (a short line, a short capsule)", (widths.goldenHour or 999) < (widths[longest[1].id] or 0), widths.goldenHour)
	snapshot("strip-long-line")
	for _, id in ids do
		workspace:SetAttribute("Event_" .. id, nil)
		signalOf(workspace, "attr:Event_" .. id):Fire()
	end
	advance(1.2)

	-- Pictures from the emoji font only from the ones every screen has had for years (the newer
	-- ones, like the coin, come out as an empty box on some screens).
	local newer = {}
	local function scan(dir: string)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				scan(path)
			elseif string.sub(name, -5) == ".luau" then
				local text = fs.readFile(path)
				for _, cp in utf8.codes(text) do
					if (cp >= 0x1FA70 and cp <= 0x1FAFF) or (cp >= 0x1F7E0 and cp <= 0x1F7F0) or (cp >= 0x1F9A3 and cp <= 0x1F9AE) or (cp >= 0x1F9BA and cp <= 0x1F9BF) or (cp >= 0x1F9C3 and cp <= 0x1F9CF) or cp == 0x1F971 or cp == 0x1F972 or cp == 0x1F978 or cp == 0x1F979 or cp == 0x1F97B or cp == 0x1F93F or cp == 0x1F90C or cp == 0x1F90D or cp == 0x1F90E or cp == 0x1F90F or (cp >= 0x1F6D5 and cp <= 0x1F6DF) or (cp >= 0x1F6FA and cp <= 0x1F6FC) then
						table.insert(newer, path .. ": " .. utf8.char(cp))
						break
					end
				end
			end
		end
	end
	scan("src")
	check("no picture from the emoji font that some screens can't draw", #newer == 0, table.concat(newer, "; "))
	check("no errors with things side by side or long lines", #errors == errorsBefore, errors[errorsBefore + 1])
end)()

---------------------------------------------------------------------------------------------------
-- 7y. The Grand Prix on this screen: at the wheel of one of the house's cars (built by the
-- server's own module), the dash and its keys, the race line, the lights, the chauffeurs, the
-- count and the result card.
---------------------------------------------------------------------------------------------------
;(function()
	local errorsBefore = #errors
	local CarDrive = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "CarDrive")
	local GrandPrix = module("ReplicatedStorage", "Shared", "GrandPrix")
	local Motorcar = module("ServerScriptService", "Server", "World", "Motorcar")
	local maison = workspace:FindFirstChild("Maison")
	local circuit = maison and maison:FindFirstChild("GrandPrix")
	local lights = circuit and circuit:FindFirstChild("Gantry") and circuit.Gantry:FindFirstChild("Lights")
	check("the Grand Prix circuit is built with the house", circuit ~= nil)
	check("...with five starting lights on the gantry", lights ~= nil and #lights:GetChildren() == 5)

	local folder = Instance.new("Folder")
	folder.Name = "GrandPrixCars"
	folder.Parent = maison or workspace
	local def = GrandPrix.CARS[2]
	local car = Motorcar.build(folder, def, GrandPrix.bay(2))
	syncPositions(car)
	local chassis = car:FindFirstChild("Chassis")
	local seat = car:FindFirstChild("DriverSeat")
	local drive = chassis:FindFirstChild("Drive")
	local steer = chassis:FindFirstChild("Steer")
	local dash = find(playerGui, function(d)
		return d.Name == "CarDash"
	end)
	local keys = find(playerGui, function(d)
		return d.Name == "CarKeys"
	end)
	check("on foot: no dash, no car keys", dash ~= nil and dash.Visible == false and keys ~= nil and keys.Visible == false)

	-- In at the wheel, parked in its bay.
	local fovBefore = camera.FieldOfView
	humanoid.SeatPart = seat
	advance(0.5)
	check("at the wheel: the dash comes up", dash.Visible == true and keys.Visible == true)
	check("...with the car's name and the speed", textOnScreen(string.upper(def.name)) ~= nil and textOnScreen("MPH") ~= nil)
	check("...and three keys: Race, Reset, Get out", textOnScreen("Race") ~= nil and textOnScreen("Reset") ~= nil and textOnScreen("Get out") ~= nil)
	check("parked: it stays put until the house hands it over", drive.VectorVelocity.Magnitude == 0)

	-- Handed over: the throttle pulls it away the way it faces.
	chassis.Anchored = false
	seat.ThrottleFloat = 1
	advance(2.5)
	local v = drive.VectorVelocity
	check("throttle: it pulls away, forward", v.Magnitude > 30 and v.Unit:Dot(chassis.CFrame.LookVector) > 0.95, v)
	check("...and the dash shows the speed", (tonumber(dash.Speed.Text) or 0) > 30, dash.Speed.Text)
	check("...the view opens a little with the speed", camera.FieldOfView > fovBefore + 2, camera.FieldOfView)
	local before = steer.CFrame.LookVector
	seat.SteerFloat = 1
	advance(0.8)
	local after = steer.CFrame.LookVector
	check("steering right turns it right", before:Cross(after).Y < -0.05, before:Cross(after))
	seat.SteerFloat = 0

	-- Off the throttle it rolls to a stop; the keys work too where the seat isn't fed.
	seat.ThrottleFloat = 0
	advance(12)
	check("off the throttle: it rolls to a stop", drive.VectorVelocity.Magnitude < 1, drive.VectorVelocity.Magnitude)
	keysDown.W = true
	advance(2)
	check("W drives it too", drive.VectorVelocity.Magnitude > 30, drive.VectorVelocity.Magnitude)

	-- Build 69: the car dressed as a race car (on this screen), the circuit dressed for the night.
	local CircuitDress = module("StarterPlayer", "StarterPlayerScripts", "Client", "World", "CircuitDress")
	local function count(root, name)
		local n = 0
		for _, d in root:GetDescendants() do
			if d.Name == name then
				n += 1
			end
		end
		return n
	end
	local number = nil
	for _, d in car:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "02" then
			number = d
		end
	end
	check("the car is dressed: haunches, stripes, its number, tailpipes, five-spoke rims", count(car, "Haunch") == 4 and count(car, "Stripe") == 4 and number ~= nil and count(car, "Tailpipe") == 2 and count(car, "Spoke") == 12, count(car, "Haunch"))
	check("...with its engine to hear, and smoke for its rear tyres", chassis:FindFirstChild("Engine") ~= nil and count(chassis, "TyreSmoke") == 2)
	check("...and every piece of it weightless and out of the way", (function()
		for _, d in car:GetDescendants() do
			if (d.Name == "Haunch" or d.Name == "Spoke" or d.Name == "Flame") and (d.CanCollide or not d.Massless) then
				return false
			end
		end
		return true
	end)())
	local dress = (workspace:FindFirstChild("MaisonLocal") or workspace):FindFirstChild("GrandPrixDress")
	check("the circuit is dressed: lights along the straights, four boost pads, barriers, boards", dress ~= nil and count(dress, "TrackLight") >= 100 and count(dress, "BoostPad") == 4 and count(dress, "Barrier") == 32 and count(dress, "Board") == 8)
	check("...a podium, flags at the line, and the Timing Tower", dress ~= nil and count(dress, "Podium") == 3 and count(dress, "Flag") == 2 and count(dress, "TimingTower") == 1)

	-- A boost pad: the surge past the car's usual top speed, felt and shown.
	local pad = GrandPrix.boostPads()[1]
	local onPad = CFrame.lookAt(pad.at + Vector3.new(0, GrandPrix.RIDE, 0), pad.at + Vector3.new(0, GrandPrix.RIDE, 0) + pad.dir)
	chassis.CFrame = onPad
	chassis.Position = onPad.Position
	check("the shared rules find the pad under the car", GrandPrix.boostAt(onPad.Position) == 1)
	local fovBeforeBoost = camera.FieldOfView
	CarDrive.step(1 / 60)
	check("over a pad: the surge", CarDrive.boosting())
	check("...BOOST on the dash, the view thrown wider", find(dash, function(d)
		return d.Name == "Boost" and d.Visible == true
	end) ~= nil and camera.FieldOfView > fovBeforeBoost + 4, camera.FieldOfView - fovBeforeBoost)
	local away = onPad * CFrame.new(0, 0, -60)
	chassis.CFrame = away
	chassis.Position = away.Position
	for _ = 1, 60 do
		CarDrive.step(1 / 60)
	end
	check("...past the car's usual top speed", drive.VectorVelocity.Magnitude > GrandPrix.CAR.top, drive.VectorVelocity.Magnitude)
	check("...the speed lines rush", find(playerGui, function(d)
		return d.Name == "SpeedLines" and d.Visible == true
	end) ~= nil)
	advance(3)
	check("...then it settles back to its own top speed", not CarDrive.boosting() and drive.VectorVelocity.Magnitude <= GrandPrix.CAR.top + 0.5, drive.VectorVelocity.Magnitude)
	check("the shared rules: a surge never outruns the server's check", GrandPrix.BOOST.top < GrandPrix.limit())
	snapshot("car-dash")

	-- Into a wall: the car really stopped, so the speed comes down with it (no pushing on).
	local fast = drive.VectorVelocity.Magnitude
	chassis.AssemblyLinearVelocity = Vector3.zero
	CarDrive.step(1 / 60)
	check("into a wall: the speed drops with the car", drive.VectorVelocity.Magnitude < fast - 20, drive.VectorVelocity.Magnitude)
	keysDown.W = nil

	-- Race: the key asks the house.
	local asked = sentOps("Race", "race")
	press("Race")
	check("Race asks the house for a race", sentOps("Race", "race") == asked + 1)

	-- The gathering.
	serverSays("Race", { op = "race", state = "gathering", id = 1, laps = 3, entrants = { LocalPlayer.DisplayName }, gatherLeft = 12, goIn = 0, startAt = 0, grid = {}, ai = {} })
	advance(0.3)
	local line = find(playerGui, function(d)
		return d.Name == "RaceLine"
	end)
	check("gathering: the race line says when it starts", line ~= nil and line.Visible == true and textOnScreen("starts in 12") ~= nil)
	check("...and the key offers to leave", textOnScreen("Leave race") ~= nil)

	-- The grid, the five lights, the count.
	local startAt = workspace:GetServerTimeNow() + 4
	local L = GrandPrix.length()
	serverSays("Race", {
		op = "race",
		state = "countdown",
		id = 1,
		laps = 3,
		entrants = { LocalPlayer.DisplayName },
		gatherLeft = 0,
		goIn = 4,
		startAt = startAt,
		grid = { { name = LocalPlayer.DisplayName, userId = LocalPlayer.UserId, carId = def.id, slot = 1 } },
		ai = { { name = "Monsieur Laurent", carId = def.id, slot = 2, pace = 0.93, behind = 10 } },
	})
	advance(0.2)
	check("countdown: on the grid, watch the lights", textOnScreen("watch the lights") ~= nil)
	local chauffeurs = workspace:FindFirstChild("MaisonChauffeurs")
	local ghost = chauffeurs and chauffeurs:FindFirstChild("Chauffeur")
	check("a chauffeur's car takes its place on the grid", ghost ~= nil and ghost:FindFirstChildWhichIsA("ProximityPrompt", true) == nil)
	advance(2.6)
	local lit = 0
	for _, l in lights:GetChildren() do
		if l.Material == roblox.Enum.Material.Neon then
			lit += 1
		end
	end
	check("the lights come on one by one", lit >= 2 and lit < 5, lit)
	local countLabel = find(playerGui, function(d)
		return d.Name == "RaceCount"
	end)
	check("...with the count in the middle", countLabel ~= nil and countLabel.Visible == true and (countLabel.Text == "2" or countLabel.Text == "1"), countLabel and countLabel.Text)
	snapshot("race-count")

	-- Lights out: GO, the laps, the place.
	serverSays("Race", { op = "race", state = "racing", id = 1, laps = 3, entrants = { LocalPlayer.DisplayName }, gatherLeft = 0, goIn = 0, startAt = startAt, grid = { { name = LocalPlayer.DisplayName, userId = LocalPlayer.UserId, carId = def.id, slot = 1 } }, ai = { { name = "Monsieur Laurent", carId = def.id, slot = 2, pace = 0.93, behind = 10 } } })
	advance(0.3)
	check("lights out: GO", countLabel.Visible == true and countLabel.Text == "GO")
	lit = 0
	for _, l in lights:GetChildren() do
		if l.Material == roblox.Enum.Material.Neon then
			lit += 1
		end
	end
	check("...and every light off", lit == 0, lit)
	serverSays("Race", { op = "standings", id = 1, list = { { name = "Monsieur Laurent", ai = true, place = 1, lap = 1 }, { name = LocalPlayer.DisplayName, userId = LocalPlayer.UserId, place = 2, lap = 1 } } })
	advance(1.5)
	check("racing: the lap and the place along the top", textOnScreen("LAP 1/3") ~= nil and textOnScreen("2nd of 2") ~= nil)
	local tower = CircuitDress.towerText()
	check("the Timing Tower shows the race live", tower[1] == "LIVE" and string.find(tower[2] or "", "Monsieur Laurent", 1, true) ~= nil and string.find(tower[2] or "", "LAP 1/3", 1, true) ~= nil, tower[1], tower[2])
	serverSays("Race", { op = "standings", id = 1, list = { { name = LocalPlayer.DisplayName, userId = LocalPlayer.UserId, place = 1, lap = 1 }, { name = "Monsieur Laurent", ai = true, place = 2, lap = 1 } } })
	advance(0.3)
	check("a place won is called out", textOnScreen("INTO THE LEAD") ~= nil)
	check("the count has gone", countLabel.Visible == false)
	local p0 = ghost:FindFirstChild("Chassis").CFrame.Position
	advance(2)
	local p1 = ghost:FindFirstChild("Chassis").CFrame.Position
	check("the chauffeur drives round", (p1 - p0).Magnitude > 20, (p1 - p0).Magnitude)
	local s, off = GrandPrix.progress(p1)
	check("...on the road", math.abs(off) < GrandPrix.TRACK.width / 2, off)
	snapshot("race-line")
	serverSays("Race", { op = "lap", lap = 3, laps = 3 })
	advance(0.2)
	check("last lap: said so", textOnScreen("Last lap") ~= nil)
	serverSays("Race", { op = "home", time = 38.4 })
	advance(0.4)
	check("home: the time along the top", textOnScreen("HOME") ~= nil and textOnScreen("0:38.4") ~= nil)

	-- The result.
	serverSays("Race", { op = "yourResult", place = 1, field = 2, time = 38.4, gilt = 150, gems = 2 })
	serverSays("Race", { op = "race", state = "results", id = 1, laps = 3, entrants = { LocalPlayer.DisplayName }, gatherLeft = 0, goIn = 0, startAt = startAt, grid = { { name = LocalPlayer.DisplayName, userId = LocalPlayer.UserId, carId = def.id, slot = 1 } }, ai = {} })
	serverSays("Race", { op = "results", id = 1, list = { { name = LocalPlayer.DisplayName, userId = LocalPlayer.UserId, place = 1, time = 38.4 }, { name = "Monsieur Laurent", ai = true, place = 2, time = 39.3 } } })
	advance(0.6)
	check("the result: You won", textOnScreen("You won") ~= nil)
	check("...the prize, Gilt and Gems", textOnScreen("+150 Gilt") ~= nil and textOnScreen("+2 Gems") ~= nil)
	check("...every driver in order, with times", textOnScreen("1st") ~= nil and textOnScreen("Monsieur Laurent") ~= nil and textOnScreen("0:39.3") ~= nil)
	check("...Race again and Close", textOnScreen("Race again") ~= nil and textOnScreen("Close") ~= nil)
	tower = CircuitDress.towerText()
	check("the Timing Tower shows the result", tower[1] == "RESULT" and string.find(tower[2] or "", "0:38.4", 1, true) ~= nil, tower[1], tower[2])
	local podiumNames = {}
	for _, d in dress:GetDescendants() do
		if d:IsA("BillboardGui") and d.Name == "Name" and d.Enabled then
			table.insert(podiumNames, d:FindFirstChildOfClass("TextLabel").Text)
		end
	end
	check("...and the podium the first three home", #podiumNames == 2 and table.find(podiumNames, LocalPlayer.DisplayName) ~= nil, #podiumNames)
	snapshot("race-results")
	press("Close")
	advance(0.5)
	check("Close puts the card away", textOnScreen("You won") == nil)
	serverSays("Race", { op = "race", state = "idle", id = 1, laps = 3, entrants = {}, gatherLeft = 0, goIn = 0, startAt = 0, grid = {}, ai = {} })
	advance(0.4)
	check("idle: the chauffeurs go home", chauffeurs == nil or #chauffeurs:GetChildren() == 0)

	-- A refusal is said plainly.
	serverSays("Race", { op = "refused", why = "Someone is already driving that car." })
	advance(0.2)
	check("a refusal is said plainly", textOnScreen("Someone is already driving that car.") ~= nil)
	check("open, at the wheel: the line says so", line.Visible == true and textOnScreen("open  ·  press Race") ~= nil)

	-- Between races: when it opens, and opening it now for everyone (Robux, the price shown).
	serverSays("Race", { op = "race", state = "idle", id = 1, laps = 3, entrants = {}, gatherLeft = 0, goIn = 0, startAt = 0, grid = {}, ai = {}, door = "closed", doorLeft = 540 })
	advance(0.4)
	check("closed: the line says when it opens", textOnScreen("opens in 9:00") ~= nil)
	check("...and so does the Race key", textOnScreen("Opens 9:00") ~= nil)
	local raceKeyButton = find(playerGui, function(d)
		return d.Name == "RaceKey"
	end)
	local racesAsked = sentOps("Race", "race")
	signalOf(raceKeyButton, "Activated"):Fire()
	check("pressing it still asks the house (who says it's closed)", sentOps("Race", "race") == racesAsked + 1)
	serverSays("Race", { op = "closed", why = "The Grand Prix opens in 9:00.", opensIn = 539.6, price = 39, held = 0 })
	advance(0.6)
	check("closed: a card says when it opens", textOnScreen("The Grand Prix is closed") ~= nil and textOnScreen("It opens again in 9:00") ~= nil)
	local openKey = find(playerGui, function(d)
		return d:IsA("TextButton") and string.find(norm(d.Text), "openthegrandprixnow", 1, true) ~= nil
	end)
	check("...and offers opening it now for everyone, its price on the key", openKey ~= nil and string.find(openKey.Text, "39", 1, true) ~= nil, openKey and openKey.Text)
	check("...or not now", textOnScreen("Not now") ~= nil)
	snapshot("race-closed")
	local opensAsked = sentOps("Race", "openNow")
	if openKey then
		signalOf(openKey, "Activated"):Fire()
	end
	advance(0.4)
	check("Open it now asks the house (the purchase window is Roblox's)", sentOps("Race", "openNow") == opensAsked + 1)
	check("...and the card steps aside", textOnScreen("The Grand Prix is closed") == nil)
	serverSays("Race", { op = "opened", closesIn = 300, gather = 50 })
	advance(0.4)
	check("opened by itself: a quiet word", textOnScreen("Get in any car on the street and press Race.") ~= nil)
	check("...and the line and key are back to Race", textOnScreen("open  ·  press Race") ~= nil and textOnScreen("Opens 9") == nil)

	-- Out of the car: the dash goes, the view comes back.
	-- (Lune can't set a reference back to nil: a seat in no car stands in for none.)
	local nowhere = Instance.new("Seat")
	nowhere.Name = "Nowhere"
	humanoid.SeatPart = nowhere
	advance(0.5)
	check("out of the car: the dash goes", dash.Visible == false and keys.Visible == false)
	check("...and the view is as it was", math.abs(camera.FieldOfView - fovBefore) < 0.01, camera.FieldOfView)
	check("...and the race line, now nothing is on", line.Visible == false)
	folder:Destroy()
	advance(4)
	check("no errors at the wheel", #errors == errorsBefore, errors[errorsBefore + 1])
end)()

---------------------------------------------------------------------------------------------------
-- 7z. Admin Abuse's party: the Foyer dances to the beat (its floor, its stair, its lamps), a crew
-- of brainrots dances round the guest, the Gold Tile and the Piñata are marked for everyone, and
-- at a table the sorting screen dances; everything put back when it ends
---------------------------------------------------------------------------------------------------
;(function()
	local errorsBefore = #errors
	local Color3 = roblox.Color3
	local Enum = roblox.Enum
	-- (The house as built: its Foyer, its tiles, its stair, its lamps.)
	local maison = workspace:FindFirstChild("Maison")
	local foyer = maison and maison:FindFirstChild("Foyer")
	local tiles = {}
	local was = {}
	local stair, lamp, ceiling = nil, nil, nil
	if foyer then
		for _, d in foyer:GetChildren() do
			if d.Name == "Tile" then
				table.insert(tiles, d)
				was[d] = { d.Material, d.Color }
			elseif d.Name == "Ceiling" and not ceiling then
				ceiling = d
			end
		end
		stair = foyer:FindFirstChild("GrandStair")
		for _, d in foyer:GetDescendants() do
			if d:IsA("PointLight") and not lamp then
				lamp = d
			end
		end
	end
	check("the house's Foyer is here to dance in", foyer ~= nil and #tiles > 20 and stair ~= nil and lamp ~= nil and ceiling ~= nil, #tiles)
	local lampWas = lamp.Color
	local ceilingWas = ceiling.CFrame
	local function lit()
		local n = 0
		for _, t in tiles do
			if t.Material == Enum.Material.Neon then
				n += 1
			end
		end
		return n
	end
	local function stage()
		return workspace:FindFirstChild("AbuseParty", true)
	end
	-- Admin Abuse begins.
	workspace:SetAttribute("AbuseUntil", workspace:GetServerTimeNow() + 900)
	workspace:SetAttribute("AbuseSince", os.time())
	signalOf(workspace, "attr:AbuseUntil"):Fire()
	advance(2)
	check("Admin Abuse: the Foyer's marble lights up as a dance floor", lit() > 0 and lit() < #tiles, lit())
	local firstLit = {}
	for i, t in tiles do
		firstLit[i] = t.Material == Enum.Material.Neon
	end
	advance(1.5)
	local changed = false
	for i, t in tiles do
		if (t.Material == Enum.Material.Neon) ~= firstLit[i] or (firstLit[i] and t.Color ~= tiles[i].Color) then
			changed = true
		end
	end
	check("...and it changes with the beat", changed)
	local nosingLit = false
	for _, n in stair:GetChildren() do
		if n.Name == "Nosing" and n.Material == Enum.Material.Neon then
			nosingLit = true
		end
	end
	check("the stair's nosings light up in a run", nosingLit)
	check("the lamps turn party colours", lamp.Color ~= lampWas)
	local dancers = 0
	for _, d in stage():GetChildren() do
		if d.Name == "Dancer" and d:FindFirstChildOfClass("BillboardGui") then
			dancers += 1
		end
	end
	check("brainrots dance: a crew round you and a conga line round the Foyer", dancers >= 4, dancers)
	check("a mirror ball under the chandelier", stage():FindFirstChild("MirrorBall") ~= nil)
	-- The Gold Tile.
	local gold = tiles[math.floor(#tiles / 2)]
	local goldAt = gold.CFrame.Position
	workspace:SetAttribute("PartyTile", goldAt)
	workspace:SetAttribute("PartyTileUntil", workspace:GetServerTimeNow() + 8)
	signalOf(workspace, "attr:PartyTile"):Fire()
	serverSays("Salute", { op = "partyTile", stage = "start", at = goldAt, seconds = 8 })
	advance(1.2)
	check("a Gold Tile: its tile turns gold", gold.Material == Enum.Material.Neon and gold.Color.R > 0.9 and gold.Color.G > 0.75)
	local mark = stage():FindFirstChild("GoldTileMarker")
	check("...with a marker over it seen through walls, counting down", mark ~= nil and mark:FindFirstChildOfClass("BillboardGui").AlwaysOnTop == true and textOnScreen("GOLD TILE") ~= nil)
	check("...and the strip at the top says where", textOnScreen("GOLD TILE  ·  in the Foyer") ~= nil)
	snapshot("party-gold-tile")
	serverSays("Salute", { op = "partyPaid", what = "tile", gilt = 120 })
	advance(0.4)
	check("standing on it: what it paid", textOnScreen("+120 Gilt. You were on it in time.") ~= nil)
	workspace:SetAttribute("PartyTile", nil)
	workspace:SetAttribute("PartyTileUntil", nil)
	signalOf(workspace, "attr:PartyTile"):Fire()
	advance(1.2)
	check("time's up: the marker goes", stage():FindFirstChild("GoldTileMarker") == nil)
	-- The Piñata.
	local pinata = Instance.new("Model")
	pinata.Name = "PartyPinata"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CFrame = CFrame.new(10, 12, 10)
	body.Parent = pinata
	pinata:SetAttribute("Hits", 0)
	pinata:SetAttribute("Needed", 40)
	pinata.Parent = workspace
	advance(1.2)
	check("the Piñata: its bar over it, seen from anywhere", body:FindFirstChild("PinataBar") ~= nil and body.PinataBar.AlwaysOnTop == true and body.PinataBar.Title.Text == "THE PIÑATA")
	pinata:SetAttribute("Hits", 10)
	advance(1.2)
	local fill = body.PinataBar.Track.Fill
	check("...filling as it's hit", math.abs(fill.Size.X.Scale - 0.25) < 0.01, fill.Size.X.Scale)
	check("...and the strip says how close it is", textOnScreen("PIÑATA  ·  in the Foyer  ·  25%") ~= nil)
	snapshot("party-pinata")
	pinata:Destroy()
	serverSays("Salute", { op = "pinata", stage = "burst", at = Vector3.new(10, 12, 10), by = "Ada", count = 3 })
	serverSays("Salute", { op = "partyPaid", what = "pinata", gilt = 200, final = true })
	advance(0.5)
	check("it bursts: the one who broke it is told", textOnScreen("+200 Gilt. You broke it open.") ~= nil)
	-- At a table, the sorting screen dances.
	serverSays("Table", { op = "seated", table = salonTable:GetAttribute("TableId"), room = "salon", mode = "room" })
	advance(2)
	local list = pieceList(6, cases)
	serverSays("Table", { op = "deal", round = 1, room = "salon", mode = "room", cases = cases, pieces = list, score = 0 })
	advance(2.5)
	local party = find(sortGui, function(d)
		return d.Name == "Party"
	end)
	local bulbs = 0
	if party then
		for _, b in party:GetChildren() do
			if b.Name == "Bulb" then
				bulbs += 1
			end
		end
	end
	check("at a table: bulbs chase round the desk like a marquee", party ~= nil and bulbs >= 12, bulbs)
	local danced = false
	for i = 1, 6 do
		local card = Sort.card(i)
		local art = card and card:FindFirstChild("Icon")
		if art and math.abs(art.Rotation) > 0.5 then
			danced = true
		end
	end
	advance(0.15)
	for i = 1, 6 do
		local card = Sort.card(i)
		local art = card and card:FindFirstChild("Icon")
		if art and math.abs(art.Rotation) > 0.5 then
			danced = true
		end
	end
	check("...and the pieces dance where they lie", danced)
	snapshot("table-party")
	serverSays("Table", { op = "left" })
	advance(2)
	-- Tips at the foot of the screen: what's on comes first.
	local Hints = module("StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Hints")
	advance(8)
	Hints.reset(0)
	advance(6)
	check("a tip at the foot of the screen says what's on (Admin Abuse's games)", textOnScreen("Admin Abuse: everything pays double. Find the Gold Tile and the Piñata in the Foyer.") ~= nil)
	snapshot("tip")
	advance(9)
	check("...and goes after a few seconds", textOnScreen("Admin Abuse: everything pays double") == nil)
	advance(30)
	check("...and not another straight after it", find(playerGui, function(d)
		return d.Name == "Tip"
	end) == nil)
	-- It ends: the house as it was.
	workspace:SetAttribute("AbuseUntil", nil)
	workspace:SetAttribute("AbuseSince", nil)
	signalOf(workspace, "attr:AbuseUntil"):Fire()
	advance(2)
	local back = true
	for _, t in tiles do
		if t.Material ~= was[t][1] or t.Color ~= was[t][2] then
			back = false
		end
	end
	check("when it ends, every tile is marble again", back)
	check("...the lamps their own colour, the ceiling in its place", lamp.Color == lampWas and (ceiling.CFrame.Position - ceilingWas.Position).Magnitude < 0.01)
	check("...and the dancers and the mirror ball gone", stage() == nil)
	check("no errors at the party", #errors == errorsBefore, errors[errorsBefore + 1])
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
