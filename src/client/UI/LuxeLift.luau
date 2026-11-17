--!strict
-- Steal a Luxe's lift, as it happens (Build 89): while a guest holds a piece's Take prompt, a card
-- low in the middle of the screen (above the keys along the foot, clear of the prompts beside
-- the guest) shows what's coming off its plinth: its glyph in a ring of its grade's colour, its
-- name, grade and worth, a bar filling for exactly the hold the prompt asks, and the security
-- around them (asleep, Alert, Lockdown, or one of the night staff stirring close by). The screen's
-- edges darken a little and breathe, the camera closes in a touch, a clock ticks faster as it
-- fills; the finer the piece, the stronger all of it (an Epic and up: the edges in its colour, a
-- riser under the ticking). When the server says it's lifted, the card says so with its worth;
-- let go early and it's gone. Nothing on it is a button and nothing covers the controls; with
-- reduced motion the camera stays where it is. Everything it shows is the prompt's own hold and
-- what the server last said.

local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Plan = require(ReplicatedStorage.Shared.Luxe)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Sound = require(script.Parent.Parent.Sound)
local Root = require(script.Parent.Root)

local LuxeLift = {}

local GOLD = Color3.fromRGB(255, 204, 90)
local RED = Color3.fromRGB(235, 70, 80)
local AMBER = Color3.fromRGB(255, 176, 60)
local CALM = Color3.fromRGB(150, 200, 170)
local W, H = 380, 86

-- Set by the HUD: the wing's alarm now (0 calm, 1 Alert, 2 Lockdown), whether security is awake
-- for this guest, and who of the night staff is stirring nearby.
LuxeLift.alarm = function(): number
	return 0
end
LuxeLift.awake = function(): boolean
	return false
end
LuxeLift.restless = function(): string?
	return nil
end

type Lift = { prompt: ProximityPrompt, piece: Plan.Piece, began: number, hold: number, grade: number, colour: Color3, fov: number?, ticked: number }
local lift: Lift? = nil
local card: Frame? = nil
local edges: Frame? = nil
local parts: { [string]: any } = {}
local beat: RBXScriptConnection? = nil
local wires: { RBXScriptConnection } = {}
local fadeAt = 0

local function rarityColour(piece: Plan.Piece): Color3
	local r = Plan.rarityOf[piece.rarity]
	return if r then r.colour else GOLD
end

local function text(parent: Instance, name: string, s: string, size: number, font: Font, colour: Color3, x: number, y: number, w: number, h: number, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = colour
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = s
	l.Parent = parent
	return l
end

-- The four edges of the screen, each a band fading inward (drawn only during a lift).
local function makeEdges(): Frame
	local f = Instance.new("Frame")
	f.Name = "LiftEdges"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 1
	f.Visible = false
	f.Parent = Root.hud
	type Band = { name: string, size: UDim2, at: UDim2, turn: number }
	local bands: { Band } = {
		{ name = "Top", size = UDim2.new(1, 0, 0.16, 0), at = UDim2.fromScale(0, 0), turn = 90 },
		{ name = "Bottom", size = UDim2.new(1, 0, 0.16, 0), at = UDim2.fromScale(0, 0.84), turn = 270 },
		{ name = "Left", size = UDim2.new(0.12, 0, 1, 0), at = UDim2.fromScale(0, 0), turn = 0 },
		{ name = "Right", size = UDim2.new(0.12, 0, 1, 0), at = UDim2.fromScale(0.88, 0), turn = 180 },
	}
	for _, spec in bands do
		local band = Instance.new("Frame")
		band.Name = spec.name
		band.BorderSizePixel = 0
		band.BackgroundColor3 = Color3.new(0, 0, 0)
		band.Size = spec.size
		band.Position = spec.at
		band.ZIndex = 1
		local g = Instance.new("UIGradient")
		g.Rotation = spec.turn
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = band
		band.Parent = f
	end
	return f
end

local function setEdges(colour: Color3, strength: number)
	local f = edges
	if not f then
		return
	end
	f.Visible = strength > 0.01
	for _, band in f:GetChildren() do
		if band:IsA("Frame") then
			band.BackgroundColor3 = colour
			band.BackgroundTransparency = 1 - strength
		end
	end
end

local function makeCard(): Frame
	local c = Instance.new("Frame")
	c.Name = "LuxeLift"
	c.AnchorPoint = Vector2.new(0.5, 1)
	c.Size = UDim2.fromOffset(W, H)
	c.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
	c.BackgroundTransparency = 0.08
	c.Visible = false
	c.ZIndex = 5
	c.Parent = Root.hud
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = c
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1.5
	stroke.Color = GOLD
	stroke.Parent = c
	parts.stroke = stroke
	-- The piece's glyph in a ring of its grade's colour.
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Position = UDim2.fromOffset(14, 14)
	ring.Size = UDim2.fromOffset(58, 58)
	ring.BackgroundColor3 = Color3.fromRGB(26, 24, 28)
	ring.ZIndex = 6
	ring.Parent = c
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local rs = Instance.new("UIStroke")
	rs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rs.Thickness = 3
	rs.Color = GOLD
	rs.Parent = ring
	parts.ringStroke = rs
	local glyph = text(ring, "Glyph", "", 28, Brand.Fonts.body, Color3.new(1, 1, 1), 0, 0, 58, 58, Enum.TextXAlignment.Center)
	glyph.ZIndex = 7
	parts.glyph = glyph
	parts.caption = text(c, "Caption", "LIFTING", 11, Brand.Fonts.heavy, GOLD, 86, 10, 140, 16)
	parts.security = text(c, "Security", "", 11, Brand.Fonts.heavy, CALM, 186, 10, W - 186 - 14, 16, Enum.TextXAlignment.Right)
	parts.name = text(c, "PieceName", "", 17, Brand.Fonts.bodyBold, Color3.fromRGB(246, 238, 222), 86, 26, W - 100, 22)
	parts.grade = text(c, "Grade", "", 13, Brand.Fonts.bodyBold, GOLD, 86, 48, W - 100, 16)
	for _, p in { parts.caption, parts.security, parts.name, parts.grade } do
		p.ZIndex = 6
	end
	-- The bar: exactly the prompt's hold.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(86, 70)
	track.Size = UDim2.fromOffset(W - 100, 6)
	track.BackgroundColor3 = Color3.fromRGB(46, 44, 50)
	track.BorderSizePixel = 0
	track.ZIndex = 6
	track.Parent = c
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(1, 0)
	tc.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GOLD
	fill.BorderSizePixel = 0
	fill.ZIndex = 7
	fill.Parent = track
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill
	parts.fill = fill
	return c
end

local function place()
	local c = card
	if not c then
		return
	end
	-- (Above the keys along the foot of the screen.)
	c.Position = UDim2.new(0.5, 0, 1, -(Root.bottomClear() + 14 + 44 + 18))
end

-- What the security line says now.
local function securityLine(): (string, Color3)
	local who = LuxeLift.restless()
	local alarm = LuxeLift.alarm()
	if alarm >= 2 then
		return "LOCKDOWN", RED
	elseif alarm >= 1 then
		return "SECURITY ON ALERT", AMBER
	elseif who then
		return string.upper(who) .. " STIRS", AMBER
	elseif LuxeLift.awake() then
		return "SECURITY AWAKE", AMBER
	end
	return "SECURITY ASLEEP", CALM
end

local function restoreCamera(l: Lift)
	local cam = Workspace.CurrentCamera
	if l.fov and cam then
		Ease.play(cam, Ease.info(0.35, Enum.EasingStyle.Quad), { FieldOfView = l.fov })
	end
	l.fov = nil
end

-- The guest started holding `prompt` on a piece: the card up, the edges in, the camera closer.
function LuxeLift.begin(prompt: ProximityPrompt)
	local model = prompt.Parent and prompt.Parent.Parent
	local id = model and model:GetAttribute("Piece")
	local piece = if type(id) == "string" then Plan.byId[id] else nil
	if not piece or not card then
		return
	end
	if lift then
		restoreCamera(lift)
	end
	local grade = Plan.rarityOf[piece.rarity]
	local colour = rarityColour(piece)
	local l: Lift = { prompt = prompt, piece = piece, began = os.clock(), hold = math.max(0.05, prompt.HoldDuration), grade = if grade then grade.order else 1, colour = colour, fov = nil, ticked = 0 }
	lift = l
	local c = card :: Frame
	parts.glyph.Text = piece.glyph
	parts.name.Text = piece.name
	parts.grade.Text = string.format("%s  ·  worth %s", piece.rarity, Rules.format(piece.worth))
	parts.grade.TextColor3 = colour
	parts.ringStroke.Color = colour
	parts.stroke.Color = colour
	parts.fill.BackgroundColor3 = colour
	parts.fill.Size = UDim2.fromScale(0, 1)
	parts.caption.Text = "LIFTING"
	parts.caption.TextColor3 = GOLD
	c.Visible = true
	place()
	-- (The camera closes in a touch, unless motion is reduced.)
	local cam = Workspace.CurrentCamera
	if cam and Ease.motionScale >= 1 then
		l.fov = cam.FieldOfView
		Ease.play(cam, Ease.info(l.hold, Enum.EasingStyle.Sine), { FieldOfView = cam.FieldOfView - (if l.grade >= 5 then 7 else 4) })
	end
	if l.grade >= 4 and Sound.has("showRiser") then
		Sound.play("showRiser", if l.grade >= 5 then 0.5 else 0.32)
	end
end

-- The guest let go before it was lifted.
function LuxeLift.release(prompt: ProximityPrompt)
	local l = lift
	if not l or l.prompt ~= prompt then
		return
	end
	restoreCamera(l)
	lift = nil
	if card and (os.clock() - l.began) < l.hold then
		parts.caption.Text = "LET GO"
		parts.caption.TextColor3 = Color3.fromRGB(190, 186, 180)
		fadeAt = os.clock() + 0.5
	end
end

-- The server says it's lifted: the card says so, with its worth.
function LuxeLift.took(m: { [string]: any })
	local l = lift
	if l then
		restoreCamera(l)
	end
	lift = nil
	if not card then
		return
	end
	local piece = if type(m.piece) == "string" then Plan.byId[m.piece] else nil
	if piece then
		parts.glyph.Text = piece.glyph
		parts.name.Text = piece.name
		parts.grade.Text = string.format("%s  ·  +%s to carry out", piece.rarity, Rules.format(tonumber(m.worth) or piece.worth))
		parts.grade.TextColor3 = rarityColour(piece)
	end
	parts.caption.Text = "LIFTED"
	parts.caption.TextColor3 = GOLD
	parts.fill.Size = UDim2.fromScale(1, 1)
	local c = card :: Frame
	c.Visible = true
	place()
	fadeAt = os.clock() + 1.4
end

function LuxeLift.lifting(): boolean
	return lift ~= nil
end

local function step()
	local c = card
	if not c then
		return
	end
	local l = lift
	local t = os.clock()
	if l then
		if not l.prompt.Parent then
			restoreCamera(l)
			lift = nil
			fadeAt = t
			return
		end
		local k = math.clamp((t - l.began) / l.hold, 0, 1)
		parts.fill.Size = UDim2.fromScale(k, 1)
		local line, colour = securityLine()
		parts.security.Text = line
		parts.security.TextColor3 = colour
		-- (The edges: darker the finer the piece and the nearer done, breathing; an Epic and up in its colour.)
		local strength = (0.18 + 0.08 * math.min(l.grade, 6)) * (0.6 + 0.4 * k) * (0.85 + 0.15 * math.sin(t * 7))
		setEdges(if l.grade >= 4 then l.colour:Lerp(Color3.new(0, 0, 0), 0.55) else Color3.new(0, 0, 0), strength)
		if colour == RED or colour == AMBER then
			parts.stroke.Color = colour
		end
		-- (A clock ticking faster as it fills.)
		local gap = 0.32 - 0.2 * k
		if t - l.ticked >= gap and Sound.has("tick") then
			l.ticked = t
			Sound.play("tick", 0.25 + 0.15 * k, 0.9 + 0.35 * k)
		end
		c.Visible = true
	else
		setEdges(Color3.new(0, 0, 0), 0)
		if c.Visible and t >= fadeAt then
			c.Visible = false
		end
	end
end

function LuxeLift.mounted(): boolean
	return card ~= nil
end

function LuxeLift.mount()
	if card then
		return
	end
	card = makeCard()
	edges = makeEdges()
	place()
	local me = Players.LocalPlayer
	local function ours(prompt: ProximityPrompt, who: Player?): boolean
		return prompt.Name == "Take" and (who == nil or who == me)
	end
	pcall(function()
		table.insert(wires, ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt, who: Player)
			if ours(prompt, who) then
				LuxeLift.begin(prompt)
			end
		end))
		table.insert(wires, ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt, who: Player)
			if ours(prompt, who) then
				LuxeLift.release(prompt)
			end
		end))
	end)
	beat = RunService.Heartbeat:Connect(function()
		pcall(step)
	end)
end

function LuxeLift.unmount()
	if lift then
		restoreCamera(lift)
	end
	lift = nil
	for _, w in wires do
		w:Disconnect()
	end
	wires = {}
	if beat then
		beat:Disconnect()
		beat = nil
	end
	if card then
		card:Destroy()
		card = nil
	end
	if edges then
		edges:Destroy()
		edges = nil
	end
	parts = {}
end

-- (For tests: one frame.)
LuxeLift.step = step

return LuxeLift
