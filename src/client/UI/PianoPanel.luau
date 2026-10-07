--!strict
-- The Foyer's grand piano, on a guest's screen. Two faces:
--   the offer, when they come to the bench with no time held: what playing is, who is at the
--     piano now, and the four sessions at Roblox's own prices (or "Play now" with time held);
--   the keyboard, while they play: three octaves along the foot of the screen, played with the
--     mouse, by touch (several fingers at once) or on the computer's keys (PianoKeys), the time
--     left, and a key to get up.
-- This screen plays each note the moment it's pressed and sends it to the server, which passes it
-- to everyone else. Who is at the piano, and until when, comes from the server (Workspace
-- attributes); prices and time held come from its answers. Nothing here decides either.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local PianoKeys = require(ReplicatedStorage.Shared.PianoKeys)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fade = require(script.Parent.Fade)
local Prompts = require(script.Parent.Prompts)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)

local PianoPanel = {}

-- The space this guest is in (set by Main from Ambient).
PianoPanel.zone = function(): string
	return ""
end

local NAME = "Piano"
local ROBUX = utf8.char(0xE002)
local C = Brand.Colours
local IVORY = Color3.fromRGB(240, 233, 216)
local IVORY_SHADE = Color3.fromRGB(206, 196, 174)
local EBONY = Color3.fromRGB(14, 14, 17)
local EBONY_SHINE = Color3.fromRGB(52, 50, 54)

local player = Players.LocalPlayer

local function ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("PianoAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function mine(): boolean
	return Workspace:GetAttribute("PianoPlayer") == player.UserId
end

---------------------------------------------------------------------------------------------------
-- The piano itself: every note played, by anyone, presses its key on the Foyer's grand piano and
-- lifts a few gold motes from the strings (drawn on this screen only; the server's piano never
-- moves).
---------------------------------------------------------------------------------------------------

local restAt: { [BasePart]: CFrame } = {}
local motes: ParticleEmitter? = nil

local function piano(): Model?
	local maison = Workspace:FindFirstChild("Maison")
	local m = maison and maison:FindFirstChild("GrandPiano", true)
	return if m and m:IsA("Model") then m else nil
end

-- This guest's own piano (the baby grand in their Suite), while they play it; nil otherwise.
local privatePiano: Model? = nil

local function strike(index: number, on: Model?)
	local p = on or privatePiano or piano()
	local keyboard = p and p:FindFirstChild("Keyboard")
	local key = keyboard and keyboard:FindFirstChild("Key" .. index)
	if key and key:IsA("BasePart") then
		local rest = restAt[key]
		if not rest then
			rest = key.CFrame
			restAt[key] = rest
		end
		local k = PianoKeys.list[index]
		local down = (rest :: CFrame) * CFrame.new(0, -0.07, 0) * CFrame.Angles(math.rad(if k and k.black then -2 else -3), 0, 0)
		key.CFrame = down
		Ease.play(key, Ease.info(0.22, Enum.EasingStyle.Quad), { CFrame = rest })
	end
	local strings = p and p:FindFirstChild("Strings")
	if strings and strings:IsA("BasePart") then
		local e = motes
		if not e or e.Parent ~= strings then
			local n = Instance.new("ParticleEmitter")
			n.Name = "NoteMotes"
			n.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			n.Color = ColorSequence.new(C.lightGold, C.gold)
			n.LightEmission = 0.8
			n.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
			n.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			n.Lifetime = NumberRange.new(0.9, 1.6)
			n.Speed = NumberRange.new(1.5, 3)
			n.SpreadAngle = Vector2.new(25, 25)
			n.EmissionDirection = Enum.NormalId.Top
			n.Acceleration = Vector3.new(0, 0.6, 0)
			n.Rate = 0
			n.Parent = strings
			motes = n
			e = n
		end
		(e :: ParticleEmitter):Emit(2)
	end
end
PianoPanel.strike = strike

---------------------------------------------------------------------------------------------------
-- The offer
---------------------------------------------------------------------------------------------------

local function line(parent: Instance, text: string, order: number, colour: Color3?)
	Theme.text(parent, text, 14, "body", { LayoutOrder = order, TextWrapped = true, TextColor3 = colour or C.smoke })
end

local function render(info: { [string]: any })
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local size = Root.size()
	local w = math.min(440, size.X - 24)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 0))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Foyer", 12, "caps", { LayoutOrder = 1 })
	Theme.text(content, "The Grand Piano", 26, "display", { LayoutOrder = 2 })
	Theme.hairline(content, UDim.new(0, 120), 3)
	line(content, "Play for everyone in the Foyer: they hear every note, and the house's music rests while you play. Your time only runs while you sit at the keys.", 4, C.bone)
	local held = tonumber(info.seconds) or 0
	if type(info.busy) == "string" then
		line(content, string.format("%s is playing now (%s left). Your time waits for you.", info.busy, clock(tonumber(info.busyLeft) or 0)), 5, C.lightGold)
	end
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 10
	keys.Parent = content
	Theme.list(keys, 6)
	local order = 0
	local function add(): number
		order += 1
		return order
	end
	local function sitDown()
		local r = ask({ op = "sit" })
		if type(r) == "table" and r.ok then
			Root.close(NAME)
		else
			Toast.show("The Grand Piano", if type(r) == "table" and type(r.why) == "string" then r.why else "The piano didn't answer. Try again in a moment.", 4)
		end
	end
	-- The owner plays free; anyone else, today's taste first if it's still there.
	if info.free == true then
		Theme.key(keys, "Play now · free for the owner", type(info.busy) ~= "string", sitDown, 320).LayoutOrder = add()
	elseif held <= 0 and type(info.taste) == "number" then
		local taste = Theme.key(keys, string.format("Try it free · %s today", clock(info.taste)), type(info.busy) ~= "string", sitDown, 320)
		taste.Name = "Taste"
		taste.LayoutOrder = add()
		line(keys, "A little free time every day. Longer sessions:", add())
	end
	if held > 0 then
		local play = Theme.key(keys, "Play now · " .. clock(held) .. " held", type(info.busy) ~= "string" and info.free ~= true, sitDown, 320)
		play.LayoutOrder = add()
		line(keys, "Or add more time:", add())
	end
	for _, o in (if type(info.offers) == "table" then info.offers else {}) :: { any } do
		if type(o) ~= "table" then
			continue
		end
		local label = tostring(o.name)
		if o.ready == true and type(o.price) == "number" then
			local k = Theme.key(keys, string.format("%s · %s %d", label, ROBUX, o.price), held <= 0 and type(info.busy) ~= "string" and info.free ~= true and type(info.taste) ~= "number", function()
				local r = ask({ op = "buy", key = o.key })
				if type(r) ~= "table" or not r.ok then
					Toast.show("The Grand Piano", if type(r) == "table" and type(r.why) == "string" then r.why else "The purchase window couldn't open. Try again in a moment.", 4)
				end
			end, 320)
			k.Name = "Buy_" .. tostring(o.key)
			k.LayoutOrder = add()
		else
			Theme.text(keys, label .. " · not on sale yet", 13, "body", { LayoutOrder = add(), TextColor3 = C.dim })
		end
	end
	Theme.key(keys, "Close", false, function()
		Root.close(NAME)
	end, 320).LayoutOrder = add()
	Root.open(NAME, group, function()
		-- Closed without playing: the server needn't sit them down when a purchase lands later.
		if not mine() then
			task.spawn(ask, { op = "stand" })
		end
	end, true)
end

-- Shows the offer (from the bench's prompt with no time held, or from the time-held chip).
function PianoPanel.offer()
	task.spawn(function()
		local info = ask({ op = "state" })
		if type(info) ~= "table" or info.ok == nil then
			Toast.show("The Grand Piano", "The piano didn't answer. Try again in a moment.", 3)
			return
		end
		if info.playing then
			return
		end
		render(info)
		-- The piano greets them: a soft rolled chord (C major), unless someone else is playing.
		if type(info.busy) ~= "string" then
			Sound.pianoChord({ 13, 17, 20, 25 })
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- The keyboard
---------------------------------------------------------------------------------------------------

type KeyView = { button: TextButton, base: Color3, black: boolean }

local board: Frame? = nil
local views: { [number]: KeyView } = {}
local timeLabel: TextLabel? = nil
local playing = false
local beat: RBXScriptConnection? = nil

local function press(index: number)
	if not playing or index < 1 or index > Config.data.Piano.keys then
		return
	end
	Sound.pianoNote(index, true)
	if privatePiano then
		-- Their own piano: heard here, and nowhere else.
		strike(index, privatePiano)
	else
		Remotes.event("PianoNote"):FireServer(index)
		strike(index)
	end
	local v = views[index]
	if v then
		v.button.BackgroundColor3 = if v.black then C.gold else C.lightGold
		Ease.play(v.button, Ease.info(0.35, Enum.EasingStyle.Quad), { BackgroundColor3 = v.base })
	end
end

local function build(): Frame
	local size = Root.size()
	local w = math.min(1040, size.X - 24)
	local keysH = math.clamp(math.floor(w * 0.16), 120, 170)
	local h = keysH + 58
	local group, content = Theme.glass(Root.hud, "PianoKeys", UDim2.fromOffset(w, h), UDim2.new(0.5, 0, 1, -12), Vector2.new(0.5, 1))
	local pad = content:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
	end
	-- The header: the piano's name, the time left, and a key to get up.
	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 34)
	head.Parent = content
	Theme.text(head, "The Grand Piano", 14, "caps", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0.4, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	timeLabel = Theme.text(head, "", 22, "display", {
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.2, 0, 1, 0),
		TextColor3 = C.lightGold,
	})
	local up = Theme.key(head, "Stand up", false, function()
		if privatePiano then
			PianoPanel.stopPrivate()
		else
			task.spawn(ask, { op = "stand" })
		end
	end, 140)
	up.AnchorPoint = Vector2.new(1, 0)
	up.Position = UDim2.fromScale(1, 0)
	up.Size = UDim2.fromOffset(140, 32)

	-- The keys: ivory below, ebony over them, each labelled with the computer key that plays it.
	local bed = Instance.new("Frame")
	bed.Name = "Keybed"
	bed.BackgroundColor3 = EBONY
	bed.BorderSizePixel = 0
	bed.AnchorPoint = Vector2.new(0, 1)
	bed.Position = UDim2.fromScale(0, 1)
	bed.Size = UDim2.new(1, 0, 0, keysH)
	bed.Parent = content
	local whites = 0
	for _, k in PianoKeys.list do
		if not k.black then
			whites += 1
		end
	end
	local innerW = w - 28
	local whiteW = innerW / whites
	local blackW = whiteW * 0.6
	local showLabels = State.inputKind() == "mouse"
	local count = 0
	for _, k in PianoKeys.list do
		local b = Instance.new("TextButton")
		b.Name = "Key_" .. k.name
		b.AutoButtonColor = false
		b.Text = ""
		b.BorderSizePixel = 0
		b:SetAttribute("Key", k.index)
		local base: Color3
		if k.black then
			base = EBONY
			b.Size = UDim2.new(0, blackW, 0.6, 0)
			b.Position = UDim2.fromOffset(count * whiteW - blackW / 2, 0)
			b.ZIndex = 3
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Color = ColorSequence.new(EBONY_SHINE, Color3.new(1, 1, 1))
			g.Parent = b
		else
			base = IVORY
			b.Size = UDim2.new(0, whiteW - 2, 1, -2)
			b.Position = UDim2.fromOffset(count * whiteW + 1, 0)
			b.ZIndex = 2
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Color = ColorSequence.new(Color3.new(1, 1, 1), IVORY_SHADE)
			g.Parent = b
			count += 1
		end
		b.BackgroundColor3 = base
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 3)
		corner.Parent = b
		-- Its computer key (on a computer), and the name of every C, at the foot of the key.
		local caption = PianoKeys.label[k.index]
		local text = if showLabels and caption then Caps(caption) else ""
		if not k.black and string.sub(k.name, 1, 1) == "C" and #k.name == 2 then
			text = if text ~= "" then text .. "\n" .. k.name else k.name
		end
		if text ~= "" then
			local l = Instance.new("TextLabel")
			l.Name = "Label"
			l.BackgroundTransparency = 1
			l.AnchorPoint = Vector2.new(0.5, 1)
			l.Position = UDim2.new(0.5, 0, 1, -4)
			l.Size = UDim2.new(1, 0, 0, 30)
			l.Text = text
			l.FontFace = Brand.Fonts.bodyMedium
			l.TextSize = 12
			l.TextYAlignment = Enum.TextYAlignment.Bottom
			l.TextColor3 = if k.black then C.lightGold else Color3.fromRGB(70, 60, 44)
			l.ZIndex = b.ZIndex + 1
			l.Parent = b
		end
		b.InputBegan:Connect(function(input: InputObject)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
				press(k.index)
			end
		end)
		b.Parent = bed
		views[k.index] = { button = b, base = base, black = k.black }
	end
	return group
end

local function bindKeys(on: boolean)
	if on then
		local codes = {}
		for name in PianoKeys.byKeyCode do
			local code = (Enum.KeyCode :: any)[name]
			if code then
				table.insert(codes, code)
			end
		end
		ContextActionService:BindActionAtPriority("MaisonPiano", function(_action: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				local index = PianoKeys.byKeyCode[input.KeyCode.Name]
				if index then
					press(index)
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 50, table.unpack(codes))
	else
		ContextActionService:UnbindAction("MaisonPiano")
	end
end

local function setTouchControls(on: boolean)
	pcall(function()
		(GuiService :: any).TouchControlsEnabled = on
	end)
end

-- Shows the keyboard while this guest plays, and puts it away when they get up.
local function setPlaying(on: boolean)
	if on == playing then
		return
	end
	playing = on
	if on then
		if Root.isOpen(NAME) then
			Root.close(NAME)
		end
		Sound.preloadPiano()
		-- Nothing to hear: say so (and why), rather than leave a silent keyboard.
		task.delay(10, function()
			local total, ready, failed = Sound.pianoHealth()
			if playing and ready == 0 then
				if State.get("effects") ~= "On" or (State.get("effectsLevel") :: number) <= 0 then
					Toast.show("The piano is muted", "Its notes follow the Effects volume: turn Effects on in Settings.", 8)
				elseif failed >= total then
					Toast.show("The piano can't be heard", "Roblox couldn't fetch its recordings. Check your internet and Studio's volume.", 8)
				end
			end
		end)
		local g = board
		if not g or not g.Parent then
			views = {}
			g = build()
			board = g
		end
		local group = g :: Frame
		group.Visible = true
		Fade.set(group, 1)
		Fade.to(group, Ease.panel, 0)
		bindKeys(true)
		-- The world's prompts and a phone's thumbstick step aside for the keys.
		Prompts.hold("piano", true)
		setTouchControls(false)
		beat = RunService.Heartbeat:Connect(function()
			local label = timeLabel
			if label and privatePiano then
				label.Text = "Yours"
				-- Walked away from it: the keys put themselves away.
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local p = privatePiano
				if p and (not p.Parent or not root or not root:IsA("BasePart") or (root.Position - p:GetPivot().Position).Magnitude > 16) then
					task.defer(PianoPanel.stopPrivate)
				end
				return
			end
			local ends = Workspace:GetAttribute("PianoEnds")
			if label and type(ends) == "number" then
				label.Text = clock(ends - Workspace:GetServerTimeNow())
			end
		end)
	else
		bindKeys(false)
		Prompts.hold("piano", false)
		setTouchControls(true)
		if beat then
			beat:Disconnect()
			beat = nil
		end
		local g = board
		if g then
			local t = Fade.to(g, Ease.quick, 1)
			t.Completed:Once(function()
				if not playing then
					g.Visible = false
				end
			end)
		end
	end
end

function PianoPanel.isPlaying(): boolean
	return playing
end

-- Plays this guest's own piano (a baby grand in their Suite): the same keys, free, heard only
-- here. Nothing goes to the server.
function PianoPanel.private(model: Model)
	if playing and not privatePiano then
		return -- at the Foyer's piano already
	end
	Sound.preloadPiano()
	privatePiano = model
	if not playing then
		setPlaying(true)
	end
end

function PianoPanel.stopPrivate()
	if privatePiano then
		privatePiano = nil
		setPlaying(false)
	end
end

-- The server's word when a guest's playing ends.
function PianoPanel.ended(m: { [string]: any })
	local left = tonumber(m.left) or 0
	if m.reason == "time" then
		Toast.show("The Grand Piano", "Your time at the piano is up. Thank you for playing.", 5)
	elseif m.reason == "up" and left > 0 then
		Toast.show("The Grand Piano", string.format("%s of piano time kept for next time.", clock(left)), 4)
	end
end

function PianoPanel.start()
	local function changed()
		if privatePiano then
			return
		end
		setPlaying(mine())
		-- Someone else sits down to play: a word for whoever is in the Foyer to hear it.
		local who = Workspace:GetAttribute("PianoName")
		if not mine() and type(who) == "string" and PianoPanel.zone() == "foyer" then
			Toast.show("The Grand Piano", who .. " is playing for the Foyer.", 4)
		end
	end
	Workspace:GetAttributeChangedSignal("PianoPlayer"):Connect(changed)
	setPlaying(mine())
	-- The other guests' notes, played from the piano.
	Remotes.event("PianoNote").OnClientEvent:Connect(function(index: any, userId: any)
		if type(index) == "number" and userId ~= player.UserId then
			Sound.pianoNote(index)
			strike(index)
		end
	end)
end

return PianoPanel
