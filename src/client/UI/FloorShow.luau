--!strict
-- Lights Out on the dance floor, on this guest's screen (server/FloorShow decides all of it):
--   * in the Ballroom, the keys: Join Lights Out while it's open (Leave, once in), Open it now
--     and Remind me while it's closed, Remind me while a show is on;
--   * waiting for the start: a pill with the countdown and how many have joined;
--   * each round: its name, what to do, and a bar running down to the moment that decides it;
--     the music stopping dead in the Chairs, the room going dark in Lights Out; SAFE and OUT;
--   * the Spinner's duel: a big Shove key for the two in the ring (or a click, a tap, F, R2),
--     and a shove landing on you moves you (the server checks who's still in the ring);
--   * the cards at the end (UI/BallroomPanel): your lamp going out, the evening's result.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Fortune = require(ReplicatedStorage.Shared.Fortune)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Voice = require(ReplicatedStorage.Shared.Voice)
local BallroomPanel = require(script.Parent.BallroomPanel)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local FloorShow = {}

local V = Voice.Ballroom
local rgb = Color3.fromRGB
local NEON = rgb(255, 70, 170)
local ICE = rgb(120, 220, 255)
local GOLD = rgb(240, 204, 120)
local GRAPHITE = rgb(16, 15, 20)

local player = Players.LocalPlayer
local event = Remotes.event("LightsOut")

local view = {
	joined = false,
	startsAt = 0,
	count = 0,
	playing = false, -- in the show, lamp lit
	round = 0,
	kind = "",
	phase = "",
	ends = 0,
	started = 0,
	alive = 0,
	of = 0,
	duel = nil :: { a: string, b: string, aId: number, bId: number }?,
}
local banner: Frame? = nil
local pill: TextLabel? = nil
local shoveKey: TextButton? = nil
local dark: ColorCorrectionEffect? = nil
local pad: Frame? = nil
local padShape = ""
-- What opening it early costs this guest (from the server's hello): its price, or a credit held.
local offer = { price = nil :: number?, held = 0 }
local ROBUX = utf8.char(0xE002)
local lastShove = -math.huge

local function now(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

local function sound(): any
	local ok, m = pcall(function()
		return require(script.Parent.Parent.Sound)
	end)
	return if ok then m else nil
end

local function send(message: { [string]: any })
	pcall(function()
		event:FireServer(message)
	end)
end
FloorShow.send = send

local function clockText(seconds: number): string
	local t = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", t // 60, t % 60)
end

local function corner(o: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end

local function edge(o: GuiObject, colour: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
end

---------------------------------------------------------------------------------------------------
-- The round's banner: its name, what to do, and the time running down
---------------------------------------------------------------------------------------------------

local function roundName(kind: string): string
	return if kind == "chairs" then V.roundChairs elseif kind == "lights" then V.roundLights else V.roundSpinner
end

local function instruction(): string
	local p, k = view.phase, view.kind
	local d = view.duel
	if p == "intro" then
		return if k == "chairs" then V.chairsMusic elseif k == "lights" then V.lightsWarn else V.spinnerPicks
	elseif p == "music" then
		return V.chairsMusic
	elseif p == "scramble" then
		return V.chairsScramble
	elseif p == "warn" then
		return V.lightsWarn
	elseif p == "dark" then
		return V.lightsDark
	elseif p == "duel" and d then
		if d.aId == player.UserId then
			return Voice.fill(V.duelYou, { rival = d.b })
		elseif d.bId == player.UserId then
			return Voice.fill(V.duelYou, { rival = d.a })
		end
		return Voice.fill(V.duelWatch, { a = d.a, b = d.b })
	end
	return Voice.fill(V.lampsLit, { n = tostring(view.alive), of = tostring(view.of) })
end

local function ensureBanner(): Frame
	local b = banner
	if b and b.Parent then
		return b
	end
	local f = Instance.new("Frame")
	f.Name = "LightsOutBanner"
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.new(0.5, 0, 0, math.max(Root.topClear("LightsOut") + 8, 64))
	f.Size = UDim2.fromOffset(math.min(520, Root.size().X - 24), 92)
	f.BackgroundColor3 = GRAPHITE
	f.BackgroundTransparency = 0.1
	f.Parent = Root.hud
	corner(f, 14)
	edge(f, NEON, 1.6)
	Theme.text(f, "", 11, "caps", {
		Name = "Kicker",
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 14),
		TextColor3 = NEON,
		TextWrapped = false,
	})
	Theme.text(f, "", 24, "display", {
		Name = "Heading",
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = false,
	})
	Theme.text(f, "", 14, "body", {
		Name = "Line",
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 0, 18),
		TextColor3 = Brand.Colours.smoke,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BorderSizePixel = 0
	track.BackgroundColor3 = rgb(40, 38, 48)
	track.Position = UDim2.new(0, 16, 1, -12)
	track.Size = UDim2.new(1, -32, 0, 4)
	track.Parent = f
	corner(track, 2)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.Size = UDim2.fromScale(1, 1)
	bar.Parent = track
	corner(bar, 2)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(NEON, ICE)
	g.Parent = bar
	banner = f
	return f
end

local function setText(f: Frame, name: string, text: string)
	local l = f:FindFirstChild(name)
	if l and l:IsA("TextLabel") then
		l.Text = text
	end
end

local function drawBanner()
	if not view.playing and not view.duel and view.round == 0 then
		return
	end
	local f = ensureBanner()
	setText(f, "Kicker", string.upper(string.format("%s · round %d · %s", V.title, view.round, Voice.fill(V.lampsLit, { n = tostring(view.alive), of = tostring(view.of) }))))
	setText(f, "Heading", string.upper(roundName(view.kind)))
	setText(f, "Line", instruction())
	local bar = f:FindFirstChild("Track") and (f :: any).Track:FindFirstChild("Bar")
	if bar and bar:IsA("Frame") then
		local left = math.max(0, view.ends - now())
		local whole = math.max(0.1, view.ends - view.started)
		bar.Size = UDim2.fromScale(math.clamp(left / whole, 0, 1), 1)
		TweenService:Create(bar, TweenInfo.new(left, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
	end
end

local function clearBanner()
	if banner then
		banner:Destroy()
		banner = nil
	end
end

-- SAFE or OUT, big in the middle of the screen for a moment.
local function flash(text: string, colour: Color3)
	local l = Theme.text(Root.hud, text, 64, "display", {
		Name = "LightsOutFlash",
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(600, 90),
		TextColor3 = colour,
		TextStrokeTransparency = 0.4,
		TextWrapped = false,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = l
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.1, function()
		TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.5, function()
		l:Destroy()
	end)
end

-- The room going dark (only on this screen): Lights Out's circles are what's left to see.
local function setDark(on: boolean)
	if on and not dark then
		local c = Instance.new("ColorCorrectionEffect")
		c.Name = "LightsOutDark"
		c.Parent = Lighting
		dark = c
		TweenService:Create(c, TweenInfo.new(0.5), { Brightness = -0.42, Saturation = -0.55, Contrast = 0.2 }):Play()
	elseif not on and dark then
		local c = dark :: ColorCorrectionEffect
		dark = nil
		TweenService:Create(c, TweenInfo.new(0.6), { Brightness = 0, Saturation = 0, Contrast = 0 }):Play()
		task.delay(0.7, function()
			c:Destroy()
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- The duel: the Shove key, and being shoved
---------------------------------------------------------------------------------------------------

local function inDuel(): boolean
	local d = view.duel
	return view.phase == "duel" and d ~= nil and (d.aId == player.UserId or d.bId == player.UserId)
end

local function shove()
	if not inDuel() then
		return
	end
	local t = os.clock()
	if t - lastShove < 0.45 then
		return
	end
	lastShove = t
	send({ op = "shove" })
end
FloorShow.shove = shove

local function setShoveKey(on: boolean)
	if on and not shoveKey then
		local k = Theme.key(Root.hud, "Shove", true, shove, 220)
		k.Name = "ShoveKey"
		k.AnchorPoint = Vector2.new(0.5, 1)
		k.Position = UDim2.new(0.5, 0, 1, -(24 + Root.bottomClear()))
		k.Size = UDim2.fromOffset(220, 60)
		shoveKey = k
	elseif not on and shoveKey then
		shoveKey:Destroy()
		shoveKey = nil
	end
end

local function shoved(m: { [string]: any })
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local x, z = tonumber(m.x) or 0, tonumber(m.z) or 0
	local power = math.clamp(tonumber(m.power) or 60, 0, 120)
	if root and root:IsA("BasePart") then
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.new(x * power, 22, z * power)
		end)
	end
	pcall(function()
		sound().play("drop", 0.8)
	end)
end

---------------------------------------------------------------------------------------------------
-- The keys in the room, and the pill while waiting
---------------------------------------------------------------------------------------------------

local function inBallroom(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "ballroom"
end

local function hud(): any
	local ok, m = pcall(function()
		return require(script.Parent.Hud)
	end)
	return if ok then m else nil
end

-- What it is and its keys, at the foot of the screen (the top row of keys stays as it is): Join
-- while it's open; Leave once in; Remind me while a show is on; Open it now (its price on the key,
-- or the credit held) and Remind me while it's closed.
type PadKey = { text: string, primary: boolean, onPress: () -> () }
local function padSpec(): (string, string, { PadKey })
	local state = Workspace:GetAttribute("BallroomState")
	local at = tonumber(Workspace:GetAttribute("BallroomAt")) or now()
	local pot = Fortune.format(tonumber(Workspace:GetAttribute("BallroomPot")) or 0)
	local function join()
		send({ op = "join" })
	end
	if view.joined then
		return V.padKicker, V.padJoined, { { text = V.floorLeave, primary = false, onPress = function()
			send({ op = "leave" })
		end } }
	elseif state == "open" then
		return V.padKicker, Voice.fill(V.padOpen, { pot = pot }), { { text = V.floorJoin, primary = true, onPress = join } }
	elseif state == "gathering" then
		return V.padKicker, Voice.fill(V.padGathering, { time = clockText(at - now()), pot = pot }), { { text = V.floorJoin, primary = true, onPress = join } }
	elseif state == "closed" then
		local keys: { PadKey } = {}
		local function open()
			send({ op = "openNow" })
		end
		if offer.held > 0 then
			table.insert(keys, { text = V.openNow .. "  ·  " .. V.openHeld, primary = true, onPress = open })
		elseif offer.price then
			table.insert(keys, { text = V.openNow .. "  ·  " .. ROBUX .. " " .. Fortune.format(offer.price :: number), primary = true, onPress = open })
		end
		table.insert(keys, { text = V.remind, primary = #keys == 0, onPress = join })
		return V.padClosedKicker, Voice.fill(if #keys > 1 then V.padClosed else V.padClosedFree, { time = clockText(at - now()) }), keys
	end
	return V.padOnKicker, V.padPlaying, { { text = V.remind, primary = true, onPress = join } }
end

local function clearPad()
	local p = pad
	if p then
		pad = nil
		p:Destroy()
	end
	padShape = ""
end

-- (Rebuilt only when its keys change; the line, with its countdown, is set in place.)
function FloorShow.roomKeys()
	if view.playing or not inBallroom() or Root.isOpen() then
		clearPad()
		return
	end
	local kicker, line, keys = padSpec()
	local texts = {}
	for _, k in keys do
		table.insert(texts, k.text)
	end
	local shape = kicker .. "|" .. table.concat(texts, "|")
	local f = pad
	if not f or not f.Parent or shape ~= padShape then
		clearPad()
		local w = math.min(460, Root.size().X - 24)
		local frame = Instance.new("Frame")
		frame.Name = "LightsOutPad"
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Size = UDim2.fromOffset(w, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.BackgroundColor3 = GRAPHITE
		frame.BackgroundTransparency = 0.08
		frame.Parent = Root.hud
		corner(frame, 16)
		edge(frame, NEON, 1.4)
		local inner = Instance.new("UIPadding")
		inner.PaddingTop = UDim.new(0, 12)
		inner.PaddingBottom = UDim.new(0, 12)
		inner.PaddingLeft = UDim.new(0, 14)
		inner.PaddingRight = UDim.new(0, 14)
		inner.Parent = frame
		Theme.list(frame, 6)
		Theme.text(frame, string.upper(kicker), 12, "caps", {
			Name = "Kicker",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(1, 0, 0, 16),
			TextColor3 = NEON,
			TextWrapped = false,
		})
		Theme.text(frame, line, 14, "body", {
			Name = "Line",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			TextColor3 = Brand.Colours.smoke,
			TextWrapped = true,
		})
		local row = Instance.new("Frame")
		row.Name = "Keys"
		row.BackgroundTransparency = 1
		row.LayoutOrder = 3
		row.Size = UDim2.new(1, 0, 0, 50)
		row.Parent = frame
		Theme.list(row, 8, true)
		local each = if #keys == 1 then math.min(280, w - 28) else math.floor((w - 28 - 8 * (#keys - 1)) / #keys)
		for i, k in keys do
			local b = Theme.key(row, k.text, k.primary, k.onPress, each)
			b.Size = UDim2.fromOffset(each, 50)
			b.LayoutOrder = i
		end
		pad = frame
		padShape = shape
		f = frame
	end
	local frame = f :: Frame
	-- (Clear of the line of small print along the very foot of the screen.)
	frame.Position = UDim2.new(0.5, 0, 1, -(30 + Root.bottomClear()))
	setText(frame, "Line", line)
end

local function drawPill()
	if not view.joined or view.playing then
		if pill then
			pill:Destroy()
			pill = nil
		end
		return
	end
	local p = pill
	if not p or not p.Parent then
		local l = Theme.text(Root.hud, "", 13, "caps", {
			Name = "LightsOutPill",
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, math.max(Root.topClear("LightsOut") + 8, 64)),
			Size = UDim2.fromOffset(0, 32),
			BackgroundColor3 = GRAPHITE,
			BackgroundTransparency = 0.1,
			TextColor3 = GOLD,
			TextWrapped = false,
		})
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = l
		edge(l, NEON, 1.4)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 18)
		pad.PaddingRight = UDim.new(0, 18)
		pad.Parent = l
		pill = l
		p = l
	end
	local left = view.startsAt - now()
	local who = if view.count == 1 then "1 guest" else tostring(view.count) .. " guests"
	;(p :: TextLabel).Text = string.upper(string.format("%s · %s · %s", V.youreIn, Voice.fill(V.startsIn, { time = clockText(left) }), who))
end

---------------------------------------------------------------------------------------------------
-- What the server says
---------------------------------------------------------------------------------------------------

-- (No Leave on the cards: out of the show, a guest simply walks on.)
local actions: BallroomPanel.Actions = {
	gallery = function() end,
	stay = function()
		send({ op = "join" })
	end,
	galleryText = V.keepWatching,
}

function FloorShow.handle(m: { [string]: any })
	local op = m.op
	if op == "joined" then
		view.joined = true
		view.startsAt = tonumber(m.startsAt) or now()
		-- (The pill says it: you're in, when it starts, how many have joined.)
		pcall(function()
			sound().play("chair", 0.8)
		end)
		drawPill()
		FloorShow.roomKeys()
	elseif op == "left" then
		view.joined = false
		drawPill()
		FloorShow.roomKeys()
	elseif op == "gathering" then
		view.count = tonumber(m.count) or view.count
		view.startsAt = tonumber(m.startsAt) or view.startsAt
		drawPill()
	elseif op == "hello" then
		view.joined = m.joined == true and m.state == "gathering"
		offer.price = if type(m.openPrice) == "number" then m.openPrice else nil
		offer.held = if type(m.openHeld) == "number" then m.openHeld else 0
		drawPill()
		FloorShow.roomKeys()
	elseif op == "showStart" then
		-- (Everyone who had joined is in it: their lamps are lit.)
		view.playing = view.joined
		view.joined = false
		view.round = 0
		view.of = tonumber(m.of) or 0
		view.alive = view.of
		drawPill()
		FloorShow.roomKeys()
		-- (On the floor, the screen is the show's: the next-thing-to-do note steps aside.)
		local h = hud()
		if view.playing and h then
			pcall(h.hideCoach)
		end
	elseif op == "round" then
		local before = view.phase
		view.round = tonumber(m.round) or view.round
		view.kind = tostring(m.kind or "")
		view.phase = tostring(m.phase or "")
		view.started = now()
		view.ends = tonumber(m.ends) or now()
		view.alive = tonumber(m.alive) or view.alive
		view.of = tonumber(m.of) or view.of
		if view.phase == "duel" then
			view.duel = { a = tostring(m.a or ""), b = tostring(m.b or ""), aId = tonumber(m.aId) or 0, bId = tonumber(m.bId) or 0 }
		elseif view.phase ~= "result" then
			view.duel = nil
		end
		local s = sound()
		if s then
			-- The Chairs: the music stops dead when it's time to find a seat.
			pcall(function()
				s.musicStop(view.phase == "scramble")
				if view.phase == "scramble" and before ~= "scramble" then
					s.play("low", 0.9)
				end
			end)
		end
		setDark(view.phase == "dark")
		setShoveKey(inDuel())
		drawBanner()
	elseif op == "safe" then
		flash(string.upper(V.safe), GOLD)
	elseif op == "lampOut" then
		view.alive = tonumber(m.alive) or view.alive
		if banner then
			drawBanner()
		end
	elseif op == "out" then
		view.playing = false
		setShoveKey(false)
		setDark(false)
		-- (The card says it all; the round's banner comes back with the next round, to watch.)
		clearBanner()
		flash("OUT", NEON)
		task.delay(1.4, function()
			BallroomPanel.out(m, actions)
		end)
	elseif op == "shoved" then
		shoved(m)
	elseif op == "showEnd" then
		BallroomPanel.standings(m.results)
		setShoveKey(false)
		setDark(false)
		pcall(function()
			sound().musicStop(false)
		end)
		if type(m.winner) == "string" then
			Toast.show(V.title, if m.standIn then m.winner .. ", a stand-in, kept the last lamp." else m.winner .. " kept the last lamp.", 4)
		end
		task.delay(4, function()
			clearBanner()
		end)
		view.round = 0
		view.duel = nil
	elseif op == "showResult" then
		view.playing = false
		task.delay(3, function()
			BallroomPanel.result(m, actions)
		end)
	elseif op == "refused" then
		if type(m.why) == "string" then
			Toast.show(V.title, m.why, 3.5)
		end
	elseif op == "ballroomOpen" or op == "reminder" then
		Toast.show("The Ballroom is open", V.joinHow, 4)
	elseif op == "ballroomCountdown" and not view.joined then
		Toast.show(V.title, "A show starts in a minute. " .. V.joinHow, 4)
	end
end

function FloorShow.state(): typeof(view)
	return view
end

function FloorShow.start()
	event.OnClientEvent:Connect(function(m: unknown)
		if type(m) == "table" then
			FloorShow.handle(m :: any)
		end
	end)
	-- A click, a tap, F or R2 shoves (in the ring only).
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not inDuel() then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
			shove()
		end
	end)
	-- Closed: what opening it now costs is asked again (the price, or a credit bought meanwhile).
	Workspace:GetAttributeChangedSignal("BallroomState"):Connect(function()
		if Workspace:GetAttribute("BallroomState") == "closed" then
			send({ op = "hello" })
		end
	end)
	task.spawn(function()
		while true do
			pcall(FloorShow.roomKeys)
			pcall(drawPill)
			task.wait(0.5)
		end
	end)
	send({ op = "hello" })
end

return FloorShow
