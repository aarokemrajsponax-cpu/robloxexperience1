--!strict
-- The sorting screen. Sit down at a table and the house falls away: this is all there is. The
-- Jeweller's Desk: a mahogany desk with brass corner guards, its green leather top tooled in
-- gold, under lamplight, with the pieces set down on it, each one drawn and resting on its own
-- shadow; beneath, six jewellery drawers, each lined in its own velvet with an engraved brass
-- plate and a count on the shoulder of its plinth; above, the house's crest and the figures on
-- small brass-edged plaques. Point at a piece and its name shows; pick
-- it up and, in the rooms that help you, a line of light runs to the case it belongs in. Drag it
-- onto its case, or tap it and then the case, or keys 1 to 6, or a gamepad's D-pad and A. A right
-- case takes it in with a glint and its points; a wrong one flashes and shakes, and the piece
-- goes home. Everything is laid out by hand from the screen's size, so it fits a phone, a tablet
-- and a monitor alike, and every position is known without asking the engine (which keeps it
-- testable).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Voice = require(ReplicatedStorage.Shared.Voice)
local PieceIcon = require(script.Parent.Parent.UI.PieceIcon)
local Closet = require(script.Parent.Parent.Closet)
local GuideTrail = require(script.Parent.GuideTrail)
local ScreenFX = require(script.Parent.Parent.UI.ScreenFX)
local State = require(script.Parent.Parent.State)

local SortScreen = {}

-- `golden`: a golden piece (Admin Abuse at the table; the server picked it): its right case pays.
export type PieceInfo = { uid: number, id: string, name: string, case: string, rare: boolean, mythic: boolean, seasonal: boolean, golden: boolean? }

type Card = {
	info: PieceInfo,
	frame: Frame,
	scale: UIScale,
	ring: Frame,
	art: Frame,
	shadow: Frame,
	tag: TextLabel?,
	twinkle: Frame?,
	home: Vector2,
	placed: boolean,
	pos: Vector2,
	vel: Vector2,
	target: Vector2?,
	state: "rest" | "held" | "flying" | "shaking" | "filed",
	inCase: string?,
	order: number,
	phase: number,
	hover: boolean,
}

type Bin = {
	id: string,
	face: string,
	index: number,
	frame: Frame,
	scale: UIScale,
	stroke: UIStroke,
	flash: Frame,
	lip: Frame,
	mark: Frame,
	markPx: number,
	count: TextLabel,
	name: TextLabel,
	plate: Frame,
	sub: TextLabel,
	key: TextLabel,
	centre: Vector2,
	size: Vector2,
	open: boolean,
	filed: number,
}

type Stat = { frame: Frame, key: TextLabel, value: TextLabel, scale: UIScale, width: number, shown: boolean }

type Mote = {
	frame: Frame,
	x: number,
	y: number,
	fall: number,
	sway: number,
	phase: number,
	spin: number,
	w: number,
	h: number,
	alpha: number,
	blink: boolean,
}

local C = Brand.Colours
local GOLD = C.gold
local LIGHT = C.lightGold
local BONE = C.bone
local SMOKE = C.smoke
local CORAL = Color3.fromRGB(230, 118, 96)
local F = Brand.Fonts
-- The house's cloth and lamp, unless the guest wears a table style or a lamp of their own.
-- The Jeweller's Desk: a mahogany desk with brass corner guards, its top a deep green leather
-- tooled with a double gold border; the six cases are jewellery drawers, each lined in its own
-- velvet, with an engraved brass plate for its name.
local CLOTH = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 62, 47)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(19, 42, 32)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 24, 18)),
})
local VELVET = { Color3.fromRGB(84, 26, 38), Color3.fromRGB(56, 15, 26), Color3.fromRGB(32, 8, 15) }
local WALNUT = { Color3.fromRGB(104, 46, 32), Color3.fromRGB(74, 30, 21), Color3.fromRGB(48, 18, 13), Color3.fromRGB(22, 8, 6) }
-- Each drawer's velvet (top, middle, bottom), so a case is known by its colour at a glance.
local CASE_VELVET: { [string]: { Color3 } } = {
	watches = { Color3.fromRGB(36, 52, 96), Color3.fromRGB(22, 32, 64), Color3.fromRGB(12, 17, 36) },
	jewelry = { Color3.fromRGB(104, 28, 44), Color3.fromRGB(70, 16, 30), Color3.fromRGB(38, 8, 16) },
	money = { Color3.fromRGB(30, 78, 54), Color3.fromRGB(18, 52, 36), Color3.fromRGB(9, 28, 19) },
	keys = { Color3.fromRGB(24, 74, 80), Color3.fromRGB(14, 48, 54), Color3.fromRGB(7, 26, 30) },
	accessories = { Color3.fromRGB(78, 36, 92), Color3.fromRGB(52, 22, 64), Color3.fromRGB(28, 11, 36) },
	collectibles = { Color3.fromRGB(110, 70, 24), Color3.fromRGB(76, 46, 14), Color3.fromRGB(42, 24, 7) },
}
local BRASS = { Color3.fromRGB(240, 210, 140), Color3.fromRGB(206, 164, 84), Color3.fromRGB(150, 110, 48) }
local ENGRAVED = Color3.fromRGB(42, 28, 10)
local LAMP = Color3.fromRGB(214, 150, 72)
local POOL = Color3.fromRGB(255, 214, 150)
local rim = LIGHT -- the cases' and the cloth's edges

local player = Players.LocalPlayer

-- Callbacks the table sets.
SortScreen.canLift = function(_uid: number): boolean
	return true
end
SortScreen.onLift = function(_uid: number, _mode: string) end
SortScreen.onFile = function(_uid: number, _caseId: string) end
SortScreen.onCancel = function() end
-- How much of the top-right corner the HUD's keys (Leave, Settings) take, in pixels.
SortScreen.keysWidth = function(): number
	return 0
end

---------------------------------------------------------------------------------------------------
-- The screen
---------------------------------------------------------------------------------------------------

local gui: ScreenGui? = nil
local root: Frame = nil :: any
local moteLayer: Frame = nil :: any
local piecesLayer: Frame = nil :: any
local casesLayer: Frame = nil :: any
local trailLayer: Frame = nil :: any
local fxLayer: Frame = nil :: any
local curtain: Frame = nil :: any
local tray: Frame = nil :: any
local header = {} :: { [string]: any }
local stats: { [string]: Stat } = {}
local motes: { Mote } = {}
local moteKind = ""
local trail: { uid: number, bin: Bin, since: number }? = nil
-- Admin Abuse and the owner's effects, drawn over this table too (UI/ScreenFX).
local tableFX: ScreenFX.FX? = nil

local cards: { [number]: Card } = {}
local bins: { [string]: Bin } = {}
local binOrder: { Bin } = {}
local isOpen = false
local playing = false
local names = true
local guide = "full"
local guideDelay = 0
local held: number? = nil
local heldMode: string? = nil
local press: { uid: number, at: Vector2, input: InputObject }? = nil
local hoverBin: string? = nil
local padIndex = 1
local padCase = 1
local guideThread: thread? = nil
local dealCount = 0
local roomText = ""
local roundExtra = ""
local eventLine: string? = nil
local clock = 0
-- Feedback by the run of correct pieces in a row (reset by a mistake or a new sitting).
local runOfCorrect = 0

type Layout = {
	s: number,
	vp: Vector2,
	pad: number,
	left: number,
	width: number,
	portrait: boolean,
	cols: number,
	gap: number,
	binH: number,
	binW: number,
	headerTop: number,
	headerH: number,
	binsTop: number,
	rim: number,
	frame: { x: number, y: number, w: number, h: number },
	tray: { x: number, y: number, w: number, h: number },
	icon: number,
	keys: number,
	stacked: boolean,
}
local L: Layout = {
	s = 1,
	vp = Vector2.new(1280, 720),
	pad = 24,
	left = 24,
	width = 1232,
	portrait = false,
	cols = 6,
	gap = 12,
	binH = 100,
	binW = 196,
	headerTop = 4,
	headerH = 60,
	binsTop = 600,
	rim = 10,
	frame = { x = 0, y = 0, w = 0, h = 0 },
	tray = { x = 0, y = 0, w = 0, h = 0 },
	icon = 80,
	keys = 0,
	stacked = false,
}

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	local v = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	if v.X < 10 or v.Y < 10 then
		return Vector2.new(1280, 720)
	end
	return v
end

-- Input positions sit below Roblox's top bar; this screen's positions start at the very top.
local function inset(): Vector2
	local ok, top = pcall(function()
		return GuiService:GetGuiInset()
	end)
	return if ok and typeof(top) == "Vector2" then top else Vector2.zero
end

local function toScreen(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y) + inset()
end

-- Text on this screen is never set below MIN_TEXT pixels, however small the screen.
local MIN_TEXT = 12
local function textSize(size: number): number
	return math.floor(math.max(MIN_TEXT, size) * Settings.textScale(State.get("textSize")) + 0.5)
end

local function label(parent: Instance, text: string, size: number, font: Font, colour: Color3, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = textSize(size)
	l.FontFace = font
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

local function corner(parent: Instance, px: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, colour: Color3, transparency: number, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = colour
	s.Transparency = transparency
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function colours(points: { { any } }): ColorSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, ColorSequenceKeypoint.new(p[1] :: number, p[2] :: Color3))
	end
	return ColorSequence.new(keys)
end

local function alphas(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function shade(parent: Instance, rotation: number, colour: ColorSequence?, alpha: NumberSequence?): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	if colour then
		g.Color = colour
	end
	if alpha then
		g.Transparency = alpha
	end
	g.Parent = parent
	return g
end

local function sheet(parent: Instance, name: string, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function number(n: number): string
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

-- The layout, in screen pixels, from the screen's size alone.
local function measure()
	local vp = viewport()
	local top = inset().Y
	local s = math.clamp(math.min(vp.X, vp.Y) / 760, 0.62, 1.35)
	local pad = math.floor(math.clamp(vp.X * 0.025, 12, 40))
	local width = math.min(vp.X - 2 * pad, math.floor(1640 * s))
	local left = math.floor((vp.X - width) / 2)
	local portrait = vp.X / vp.Y < 1.05
	local cols = if portrait then 3 else 6
	local rows = if portrait then 2 else 1
	local gap = math.floor(12 * s)
	local binH = math.floor((if portrait then 92 else 100) * s)
	-- On a narrow screen the figures take a row of their own under the room's line.
	local stacked = vp.X < 700
	local headerTop = top + math.floor(4 * s)
	local headerH = math.floor((if stacked then 112 else 60) * s)
	local binsH = rows * binH + (rows - 1) * gap
	local bottom = vp.Y - math.floor(14 * s)
	local trayTop = headerTop + headerH + math.floor(14 * s)
	local trayBottom = bottom - binsH - math.floor(12 * s)
	local rimPx = math.max(5, math.floor(10 * s))
	L = {
		s = s,
		vp = vp,
		pad = pad,
		left = left,
		width = width,
		portrait = portrait,
		cols = cols,
		gap = gap,
		binH = binH,
		binW = math.floor((width - (cols - 1) * gap) / cols),
		headerTop = headerTop,
		headerH = headerH,
		binsTop = bottom - binsH,
		rim = rimPx,
		frame = { x = left, y = trayTop, w = width, h = math.max(120, trayBottom - trayTop) },
		tray = { x = left + rimPx, y = trayTop + rimPx, w = width - 2 * rimPx, h = math.max(120, trayBottom - trayTop) - 2 * rimPx },
		icon = L.icon,
		keys = SortScreen.keysWidth(),
		stacked = stacked,
	}
end

---------------------------------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------------------------------

local function makeStat(parent: Instance, name: string, key: string, width: number): Stat
	local f = Instance.new("Frame")
	f.Name = "Stat_" .. name
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(1, 0)
	f.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = f
	-- Each figure sits on its own small plaque: dark glass, a gold hairline, a brass top edge.
	local plaque = sheet(f, "Plaque", Color3.new(1, 1, 1), 1)
	plaque.Size = UDim2.fromScale(1, 1)
	shade(plaque, 90, colours({ { 0, Color3.fromRGB(34, 26, 22) }, { 1, Color3.fromRGB(14, 11, 11) } }))
	plaque.BackgroundTransparency = 0.12
	corner(plaque, 6)
	stroke(plaque, GOLD, 0.62, 1)
	local edge = sheet(plaque, "Edge", BRASS[1], 2)
	edge.Size = UDim2.new(1, -12, 0, 1)
	edge.Position = UDim2.fromOffset(6, 0)
	edge.BackgroundTransparency = 0.45
	local k = label(f, key, 11, F.bodyBold, LIGHT, {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(1, 0.26),
		TextTransparency = 0.15,
		ZIndex = 2,
	})
	local v = label(f, "", 30, F.figures, BONE, {
		Name = "Value",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(1, 0.66),
		ZIndex = 2,
	})
	local st: Stat = { frame = f, key = k, value = v, scale = scale, width = width, shown = false }
	stats[name] = st
	return st
end

local function build()
	if gui and gui.Parent then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "MaisonSort"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ScreenInsets = Enum.ScreenInsets.None
	g.DisplayOrder = 18 -- above the world and the prompts; under the keys, notices and panels
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Enabled = false
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g

	-- The room: dark, warm where the lamp hangs over the table.
	root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BorderSizePixel = 0
	root.BackgroundColor3 = Color3.new(1, 1, 1)
	root.Active = true
	shade(root, 90, colours({ { 0, Color3.fromRGB(44, 31, 17) }, { 0.3, Color3.fromRGB(18, 16, 14) }, { 1, Color3.fromRGB(7, 8, 10) } }))
	root.Parent = g

	local lamp = sheet(root, "Lamp", LAMP, 1)
	header.lamp = lamp
	lamp.AnchorPoint = Vector2.new(0.5, 0.5)
	lamp.Position = UDim2.fromScale(0.5, 0)
	lamp.Size = UDim2.fromScale(1.15, 0.8)
	corner(lamp, 9999)
	shade(lamp, 90, nil, alphas({ { 0, 0.55 }, { 0.5, 0.78 }, { 0.8, 0.95 }, { 1, 1 } }))
	for _, side in { 0, 180 } do
		local v = sheet(root, "Vignette", Color3.new(0, 0, 0), 1)
		v.Size = UDim2.fromScale(0.2, 1)
		v.Position = UDim2.fromScale(if side == 0 then 0 else 0.8, 0)
		shade(v, side, nil, alphas({ { 0, 0.3 }, { 1, 1 } }))
	end
	local floor = sheet(root, "Vignette", Color3.new(0, 0, 0), 1)
	floor.Size = UDim2.fromScale(1, 0.3)
	floor.Position = UDim2.fromScale(0, 0.7)
	shade(floor, 90, nil, alphas({ { 0, 1 }, { 1, 0.35 } }))

	-- The season's weather drifting across the room (leaves, snow, petals, embers...).
	moteLayer = Instance.new("Frame")
	moteLayer.Name = "Motes"
	moteLayer.BackgroundTransparency = 1
	moteLayer.Size = UDim2.fromScale(1, 1)
	moteLayer.ZIndex = 1
	moteLayer.Parent = root

	-- The desk: polished mahogany with a gold bead round its edge and brass guards on its four
	-- corners; set into it, the leather top (a shadow along its edges where the wood stands over
	-- it), tooled with a double gold border and a fleuron in each corner, under a warm wash of
	-- lamplight.
	local frame = sheet(root, "TrayFrame", Color3.new(1, 1, 1), 2)
	header.trayFrame = frame
	shade(frame, 90, colours({ { 0, WALNUT[1] }, { 0.08, WALNUT[2] }, { 0.55, WALNUT[3] }, { 1, WALNUT[4] } }))
	header.frameCorner = corner(frame, 10)
	header.frameStroke = stroke(frame, GOLD, 0.45, 1)
	local shine = sheet(frame, "Shine", LIGHT, 2)
	shine.Size = UDim2.new(1, -24, 0, 1)
	shine.Position = UDim2.fromOffset(12, 1)
	shade(shine, 0, nil, alphas({ { 0, 1 }, { 0.25, 0.6 }, { 0.75, 0.6 }, { 1, 1 } }))
	tray = sheet(root, "Tray", Color3.new(1, 1, 1), 2)
	header.trayShade = shade(tray, 90, CLOTH)
	header.trayCorner = corner(tray, 4)
	header.trayStroke = stroke(tray, Color3.new(0, 0, 0), 0.35, 2)
	-- The leather's grain catching the lamp: a soft diagonal sheen.
	local sheen = sheet(tray, "Sheen", Color3.fromRGB(255, 240, 210), 1)
	sheen.Size = UDim2.fromScale(1, 1)
	shade(sheen, 35, nil, alphas({ { 0, 0.93 }, { 0.45, 0.985 }, { 1, 1 } }))
	header.sheenCorner = corner(sheen, 4)
	header.edges = {}
	for _, side in { 90, 270, 0, 180 } do
		local e = sheet(tray, "Edge", Color3.new(0, 0, 0), 1)
		e:SetAttribute("Side", side)
		shade(e, side, nil, alphas({ { 0, 0.25 }, { 0.35, 0.68 }, { 1, 1 } }))
		table.insert(header.edges, e)
	end
	-- A pool of lamplight in the middle of the leather: faint ovals, each a little smaller.
	header.pools = {}
	for k = 1, 16 do
		local pool = sheet(tray, "Pool", POOL, 1)
		table.insert(header.pools, pool)
		pool.AnchorPoint = Vector2.new(0.5, 0.5)
		pool.Position = UDim2.fromScale(0.5, 0.42)
		local f = 1 - (k - 1) * 0.055
		pool.Size = UDim2.fromScale(0.95 * f, 1.05 * f)
		pool.BackgroundTransparency = 0.993
		corner(pool, 9999)
	end
	-- Brass guards on the desk's corners: an L of brass at each, a rivet where the legs meet.
	for i, at in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local guard = Instance.new("Frame")
		guard.Name = "Ornament" .. i
		guard.BackgroundTransparency = 1
		guard.AnchorPoint = at
		guard.ZIndex = 3
		guard:SetAttribute("Corner", at)
		guard.Parent = frame
		for _, leg in { "LegX", "LegY" } do
			local l = sheet(guard, leg, Color3.new(1, 1, 1), 3)
			shade(l, if leg == "LegX" then 90 else 0, colours({ { 0, BRASS[1] }, { 0.5, BRASS[2] }, { 1, BRASS[3] } }))
			l.AnchorPoint = at
			l.Position = UDim2.fromScale(at.X, at.Y)
			l:SetAttribute("Leg", leg)
			corner(l, 2)
		end
		local rivet = sheet(guard, "Rivet", BRASS[1], 4)
		rivet.AnchorPoint = Vector2.new(0.5, 0.5)
		rivet:SetAttribute("Rivet", true)
		corner(rivet, 9999)
		stroke(rivet, BRASS[3], 0.2, 1)
		header["ornament" .. i] = guard
	end
	-- The tooling: two gold lines round the leather, a fleuron (a gold lozenge with a dot either
	-- side) in each inner corner.
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Parent = tray
	header.trayInner = inner
	header.innerStroke = stroke(inner, GOLD, 0.45, 1)
	header.innerCorner = corner(inner, 2)
	local inner2 = Instance.new("Frame")
	inner2.Name = "Inner2"
	inner2.BackgroundTransparency = 1
	inner2.AnchorPoint = Vector2.new(0.5, 0.5)
	inner2.Position = UDim2.fromScale(0.5, 0.5)
	inner2.Parent = tray
	header.trayInner2 = inner2
	stroke(inner2, GOLD, 0.72, 1)
	header.fleurons = {}
	for _, at in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local f = sheet(inner, "Fleuron", GOLD, 2)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(at.X, at.Y)
		f.Rotation = 45
		f.BackgroundTransparency = 0.25
		table.insert(header.fleurons, f)
		for _, d in { -1, 1 } do
			local dot = sheet(f, "Dot", GOLD, 2)
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.new(0.5, d * 9, 0.5, -d * 9)
			dot.Size = UDim2.fromOffset(3, 3)
			dot.Rotation = -45
			dot.BackgroundTransparency = 0.35
			corner(dot, 9999)
		end
	end

	-- Admin Abuse and the owner's effects at the table: one layer over the leather and under the
	-- cases and pieces, one over everything (neither ever takes a click), and a ribbon.
	local abuseBack = Instance.new("Frame")
	abuseBack.Name = "AbuseBack"
	abuseBack.Size = UDim2.fromScale(1, 1)
	abuseBack.ZIndex = 3
	abuseBack.Parent = root

	-- Header: the house's mark and the room on the left; score, combo, time and round on the
	-- right, each a small label over a large figure; a gold rule beneath.
	local head = Instance.new("Frame")
	head.Name = "Header"
	head.BackgroundTransparency = 1
	head.ZIndex = 3
	head.Parent = root
	header.frame = head
	-- The house's crest: a gold-rimmed medallion with its monogram.
	local crest = sheet(head, "Crest", Color3.new(1, 1, 1), 3)
	crest.AnchorPoint = Vector2.new(0, 0.5)
	shade(crest, 135, colours({ { 0, Color3.fromRGB(44, 30, 22) }, { 1, Color3.fromRGB(14, 10, 9) } }))
	corner(crest, 9999)
	stroke(crest, GOLD, 0.2, 1.5)
	header.crest = crest
	header.crestText = label(crest, "MN", 18, F.display, LIGHT, {
		Name = "Monogram",
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	})
	header.mark = label(head, Brand.Name, 24, F.display, BONE, {
		Name = "Mark",
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	header.room = label(head, "", 13, F.bodyMedium, LIGHT, {
		Name = "Room",
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	stats = {}
	makeStat(head, "SCORE", "SCORE", 132)
	makeStat(head, "COMBO", "COMBO", 86)
	makeStat(head, "TIME", "TIME", 100)
	makeStat(head, "ROUND", "ROUND", 86)

	local rule = sheet(root, "Rule", GOLD, 3)
	shade(rule, 0, nil, alphas({ { 0, 0.15 }, { 0.65, 0.7 }, { 1, 1 } }))
	header.rule = rule
	local rail = sheet(root, "Clock", Color3.fromRGB(70, 58, 38), 3)
	rail.BackgroundTransparency = 0.4
	rail.Visible = false
	local fill = sheet(rail, "Fill", GOLD, 3)
	fill.Size = UDim2.fromScale(1, 1)
	header.rail = rail
	header.railFill = fill

	-- The hint across the middle of the cloth, the first times you sit; your rival's line at its
	-- foot.
	header.hint = label(root, "", 15, F.body, SMOKE, { Name = "Hint", TextTransparency = 1, TextWrapped = true, ZIndex = 3 })
	header.rival = label(root, "", 13, F.bodyMedium, SMOKE, { Name = "Rival", TextTransparency = 1, ZIndex = 3 })

	casesLayer = Instance.new("Frame")
	casesLayer.Name = "Cases"
	casesLayer.BackgroundTransparency = 1
	casesLayer.Size = UDim2.fromScale(1, 1)
	casesLayer.ZIndex = 4
	casesLayer.Parent = root
	trailLayer = Instance.new("Frame")
	trailLayer.Name = "Trail"
	trailLayer.BackgroundTransparency = 1
	trailLayer.Size = UDim2.fromScale(1, 1)
	trailLayer.ZIndex = 5
	trailLayer.Parent = root
	GuideTrail.attach(trailLayer)
	piecesLayer = Instance.new("Frame")
	piecesLayer.Name = "Pieces"
	piecesLayer.BackgroundTransparency = 1
	piecesLayer.Size = UDim2.fromScale(1, 1)
	piecesLayer.ZIndex = 6
	piecesLayer.Parent = root
	fxLayer = Instance.new("Frame")
	fxLayer.Name = "Effects"
	fxLayer.BackgroundTransparency = 1
	fxLayer.Size = UDim2.fromScale(1, 1)
	fxLayer.ZIndex = 7
	fxLayer.Parent = root
	local abuseFront = Instance.new("Frame")
	abuseFront.Name = "AbuseFront"
	abuseFront.Size = UDim2.fromScale(1, 1)
	abuseFront.ZIndex = 8
	abuseFront.Parent = root
	tableFX = ScreenFX.new(abuseBack, abuseFront, function(): Vector2
		return L.vp
	end, "table", root)
	ScreenFX.setEnabled(tableFX :: ScreenFX.FX, false)

	curtain = Instance.new("Frame")
	curtain.Name = "Curtain"
	curtain.Size = UDim2.fromScale(1, 1)
	curtain.BorderSizePixel = 0
	curtain.BackgroundColor3 = Color3.new(0, 0, 0)
	curtain.BackgroundTransparency = 1
	curtain.ZIndex = 10
	curtain.Parent = g
end

-- The season's weather, made afresh when the screen opens (the season may have turned).
local WEATHER: { [string]: { count: number, w: number, h: number, fall: number, sway: number, spin: number, alpha: number, blink: boolean, round: boolean } } = {
	leaves = { count = 18, w = 11, h = 5, fall = 0.035, sway = 0.014, spin = 40, alpha = 0.3, blink = false, round = true },
	snow = { count = 30, w = 4, h = 4, fall = 0.022, sway = 0.008, spin = 0, alpha = 0.35, blink = false, round = true },
	petals = { count = 16, w = 8, h = 6, fall = 0.026, sway = 0.016, spin = 60, alpha = 0.3, blink = false, round = true },
	clover = { count = 14, w = 7, h = 7, fall = 0.024, sway = 0.012, spin = 30, alpha = 0.35, blink = false, round = true },
	confetti = { count = 24, w = 7, h = 3, fall = 0.045, sway = 0.01, spin = 160, alpha = 0.2, blink = false, round = false },
	embers = { count = 18, w = 3, h = 3, fall = -0.03, sway = 0.01, spin = 0, alpha = 0.3, blink = true, round = true },
	fireflies = { count = 16, w = 3, h = 3, fall = -0.006, sway = 0.02, spin = 0, alpha = 0.3, blink = true, round = true },
	motes = { count = 16, w = 3, h = 3, fall = -0.008, sway = 0.012, spin = 0, alpha = 0.45, blink = true, round = true },
}

local function makeMotes()
	local id = Workspace:GetAttribute("Season")
	local season = if type(id) == "string" then Seasons.byId[id] else nil
	local kind = if season and WEATHER[season.weather] then season.weather else "motes"
	local tints = if season and #season.weatherColours > 0 then season.weatherColours else { LIGHT }
	if kind == moteKind and #motes > 0 then
		return
	end
	moteKind = kind
	for _, m in motes do
		m.frame:Destroy()
	end
	motes = {}
	local spec = WEATHER[kind]
	local rng = Random.new(7)
	for i = 1, spec.count do
		local f = sheet(moteLayer, "Mote", tints[(i - 1) % #tints + 1], 1)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		if spec.round then
			corner(f, 9999)
		end
		local alpha = spec.alpha + rng:NextNumber() * 0.3
		f.BackgroundTransparency = alpha
		table.insert(motes, {
			frame = f,
			x = rng:NextNumber(),
			y = rng:NextNumber(),
			fall = spec.fall * (0.7 + rng:NextNumber() * 0.6),
			sway = spec.sway * (0.6 + rng:NextNumber() * 0.8),
			phase = rng:NextNumber() * math.pi * 2,
			spin = spec.spin * (rng:NextNumber() * 2 - 1),
			w = spec.w * (0.75 + rng:NextNumber() * 0.5),
			h = spec.h * (0.75 + rng:NextNumber() * 0.5),
			alpha = alpha,
			blink = spec.blink,
		})
	end
end

-- The figures on the right, laid out from the right edge (clear of the HUD's keys) leftwards;
-- on a narrow screen, spread across a row of their own under the room's line.
local function layoutStats()
	local s = L.s
	-- The HUD's keys come and go (Leave appears once you're seated): ask each time.
	L.keys = SortScreen.keysWidth()
	local shown: { Stat } = {}
	for _, name in { "SCORE", "COMBO", "TIME", "ROUND" } do
		local st = stats[name]
		if st then
			st.frame.Visible = st.shown
			if st.shown then
				table.insert(shown, st)
			end
		end
	end
	local mark = header.mark :: TextLabel
	local line = header.room :: TextLabel
	if L.stacked then
		local each = L.width / math.max(1, #shown)
		for i, st in shown do
			st.frame.Position = UDim2.fromOffset(math.floor(i * each), math.floor(46 * s))
			st.frame.Size = UDim2.fromOffset(math.floor(each - 6 * s), L.headerH - math.floor(50 * s))
		end
		mark.Visible = false
		header.crest.Visible = false
		line.Size = UDim2.fromOffset(math.max(60 * s, L.vp.X - L.keys - L.left - 44 * s), 18 * s)
		line.Position = UDim2.fromOffset(0, math.floor(26 * s))
		return
	end
	local right = math.min(L.width, L.vp.X - L.keys - L.left - 18 * s)
	local gap = 10 * s
	local x = right
	for i = #shown, 1, -1 do
		local st = shown[i]
		local w = st.width * s
		st.frame.Position = UDim2.fromOffset(x, math.floor(2 * s))
		st.frame.Size = UDim2.fromOffset(w, L.headerH - math.floor(4 * s))
		x -= w + gap
	end
	-- The house's mark and the room take what's left.
	local mid = L.headerH / 2
	-- The crest first, when there's room for it beside the words.
	local crest = header.crest :: Frame
	local crestPx = math.floor(46 * s)
	local showCrest = x > 260 * s
	crest.Visible = showCrest
	crest.Size = UDim2.fromOffset(crestPx, crestPx)
	crest.Position = UDim2.fromOffset(0, mid)
	header.crestText.TextSize = textSize(17 * s)
	local textX = if showCrest then crestPx + math.floor(12 * s) else 0
	local room = math.max(60 * s, x - textX)
	local showMark = room > 170 * s
	mark.Visible = showMark
	mark.Size = UDim2.fromOffset(room, 26 * s)
	mark.Position = UDim2.fromOffset(textX, mid - 9 * s)
	line.Size = UDim2.fromOffset(room, 16 * s)
	line.Position = UDim2.fromOffset(textX, if showMark then mid + 13 * s else mid)
end

local function layoutChrome()
	local s = L.s
	local t = L.tray
	local fr = L.frame
	header.trayFrame.Position = UDim2.fromOffset(fr.x, fr.y)
	header.trayFrame.Size = UDim2.fromOffset(fr.w, fr.h)
	header.frameCorner.CornerRadius = UDim.new(0, math.max(4, math.floor(12 * s)))
	tray.Position = UDim2.fromOffset(t.x, t.y)
	tray.Size = UDim2.fromOffset(t.w, t.h)
	local radius = UDim.new(0, math.max(2, math.floor(3 * s)))
	header.trayCorner.CornerRadius = radius
	header.sheenCorner.CornerRadius = radius
	header.trayStroke.Thickness = math.max(1, 2 * s)
	local depth = math.floor(26 * s)
	for _, e in header.edges do
		local side = e:GetAttribute("Side")
		if side == 90 or side == 270 then
			e.Size = UDim2.new(1, 0, 0, depth)
			e.Position = if side == 90 then UDim2.fromScale(0, 0) else UDim2.new(0, 0, 1, -depth)
		else
			e.Size = UDim2.new(0, depth, 1, 0)
			e.Position = if side == 0 then UDim2.fromScale(0, 0) else UDim2.new(1, -depth, 0, 0)
		end
	end
	-- The tooling, set in from the leather's edge; the fleurons in its corners.
	local insetPx = math.floor(12 * s)
	header.trayInner.Size = UDim2.new(1, -2 * insetPx, 1, -2 * insetPx)
	local inset2 = math.floor(17 * s)
	header.trayInner2.Size = UDim2.new(1, -2 * inset2, 1, -2 * inset2)
	local fl = math.max(4, math.floor(7 * s))
	for _, f in header.fleurons do
		f.Size = UDim2.fromOffset(fl, fl)
	end
	-- The brass corner guards: legs a little longer on a big screen, a rivet at the corner.
	local leg = math.max(12, math.floor(34 * s))
	local thick = math.max(3, math.floor(5 * s))
	for i = 1, 4 do
		local g = header["ornament" .. i] :: Frame?
		if g then
			local at = g:GetAttribute("Corner") :: Vector2
			local off = math.floor(3 * s)
			g.Position = UDim2.new(at.X, if at.X == 0 then off else -off, at.Y, if at.Y == 0 then off else -off)
			g.Size = UDim2.fromOffset(leg, leg)
			for _, c in g:GetChildren() do
				if c:IsA("Frame") then
					if c:GetAttribute("Leg") == "LegX" then
						c.Size = UDim2.new(1, 0, 0, thick)
					elseif c:GetAttribute("Leg") == "LegY" then
						c.Size = UDim2.new(0, thick, 1, 0)
					elseif c:GetAttribute("Rivet") then
						local r = math.max(3, math.floor(thick * 1.1))
						c.Size = UDim2.fromOffset(r, r)
						c.Position = UDim2.new(at.X, if at.X == 0 then thick / 2 else -thick / 2, at.Y, if at.Y == 0 then thick / 2 else -thick / 2)
					end
				end
			end
		end
	end
	local head = header.frame :: Frame
	head.Position = UDim2.fromOffset(L.left, L.headerTop)
	head.Size = UDim2.fromOffset(L.width, L.headerH)
	layoutStats()
	local ruleY = L.headerTop + L.headerH + math.floor(3 * s)
	local rule = header.rule :: Frame
	rule.Position = UDim2.fromOffset(L.left, ruleY)
	rule.Size = UDim2.fromOffset(L.width, 1)
	if tableFX then
		ScreenFX.placeRibbon(tableFX, ruleY + math.floor(6 * s))
	end
	local rail = header.rail :: Frame
	rail.Position = UDim2.fromOffset(L.left, ruleY - 1)
	rail.Size = UDim2.fromOffset(L.width, math.max(2, math.floor(2 * s)))
	local hint = header.hint :: TextLabel
	hint.Position = UDim2.fromOffset(L.vp.X / 2, t.y + t.h / 2)
	hint.Size = UDim2.fromOffset(math.min(t.w - 40 * s, 760 * s), 44 * s)
	local rival = header.rival :: TextLabel
	rival.Position = UDim2.fromOffset(L.vp.X / 2, t.y + t.h - 18 * s)
	rival.Size = UDim2.fromOffset(t.w - 40 * s, 20 * s)
end

---------------------------------------------------------------------------------------------------
-- The cases
---------------------------------------------------------------------------------------------------

local function binFrame(case: Catalogue.Case, index: number): Bin
	local s = L.s
	local f = Instance.new("Frame")
	f.Name = "Case"
	f:SetAttribute("CaseId", case.id)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Active = true
	-- Settings → Case style: walnut cases lined with velvet, lidded boxes, or round plates.
	local style = State.get("caseStyle")
	local radius = math.max(3, math.floor(5 * s))
	if style == "Boxes" then
		radius = 0
		shade(f, 90, colours({ { 0, Color3.fromRGB(44, 46, 52) }, { 0.2, Color3.fromRGB(34, 36, 42) }, { 0.21, Color3.fromRGB(16, 18, 22) }, { 1, Color3.fromRGB(10, 11, 14) } }))
		local seam = sheet(f, "Seam", LIGHT, 2)
		seam.Size = UDim2.new(1, 0, 0, 1)
		seam.Position = UDim2.fromScale(0, 0.21)
		seam.BackgroundTransparency = 0.78
	elseif style == "Plates" then
		radius = math.floor(math.min(L.binH, L.binW) * 0.34)
		shade(f, 90, colours({ { 0, Color3.fromRGB(40, 37, 33) }, { 0.6, Color3.fromRGB(24, 22, 20) }, { 1, Color3.fromRGB(15, 14, 13) } }))
	else
		-- A jewellery drawer: mahogany, lined in this case's own velvet.
		radius = math.max(4, math.floor(8 * s))
		shade(f, 90, colours({ { 0, WALNUT[1] }, { 0.1, WALNUT[2] }, { 0.6, WALNUT[3] }, { 1, WALNUT[4] } }))
		local velvet = sheet(f, "Velvet", Color3.new(1, 1, 1), 1)
		local v = CASE_VELVET[case.id] or VELVET
		shade(velvet, 90, colours({ { 0, v[1] }, { 0.55, v[2] }, { 1, v[3] } }))
		corner(velvet, math.max(2, radius - 2))
		stroke(velvet, GOLD, 0.5, 1)
		-- The case's front edge throws a shadow onto the velvet.
		local edge = sheet(velvet, "Edge", Color3.new(0, 0, 0), 1)
		edge.Size = UDim2.fromScale(1, 0.4)
		shade(edge, 90, nil, alphas({ { 0, 0.4 }, { 1, 1 } }))
	end
	f:SetAttribute("Style", style)
	corner(f, radius)
	local st = stroke(f, rim, 0.75, 1)
	local scale = Instance.new("UIScale")
	scale.Parent = f
	local flash = sheet(f, "Flash", GOLD, 2)
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	corner(flash, radius)
	-- A line of light along the top edge when the case is the one under your piece.
	local lip = sheet(f, "Lip", LIGHT, 3)
	lip.Size = UDim2.new(1, -2 * math.max(radius, 3), 0, 1)
	lip.Position = UDim2.fromOffset(math.max(radius, 3), 0)
	lip.BackgroundTransparency = 1
	shade(lip, 0, nil, alphas({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }))
	-- A round velvet plinth under the case's piece, ringed in gold (placed by layoutBinInside).
	local plinth = sheet(f, "Plinth", Color3.new(1, 1, 1), 2)
	plinth.AnchorPoint = Vector2.new(0.5, 0.5)
	local pv = CASE_VELVET[case.id] or VELVET
	shade(plinth, 90, colours({ { 0, pv[1]:Lerp(Color3.new(1, 1, 1), 0.12) }, { 0.55, pv[2] }, { 1, pv[3]:Lerp(Color3.new(0, 0, 0), 0.4) } }))
	corner(plinth, 999)
	stroke(plinth, GOLD, 0.55, 1)
	plinth.BackgroundTransparency = if style == "Boxes" or style == "Plates" then 1 else 0
	-- Glass over the drawer: a soft sheen across its top.
	local glass = sheet(f, "Glass", Color3.new(1, 1, 1), 4)
	glass.Size = UDim2.fromScale(1, 0.5)
	glass.BackgroundTransparency = 0
	shade(glass, 90, nil, alphas({ { 0, 0.9 }, { 0.6, 0.97 }, { 1, 1 } }))
	corner(glass, radius)
	glass.Active = false
	-- The piece that stands for the case, resting on the velvet.
	local mark = Instance.new("Frame")
	mark.Name = "MarkHolder"
	mark.BackgroundTransparency = 1
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.ZIndex = 3
	mark.Parent = f
	-- How many are in it, on a small gold-rimmed badge.
	local pill = sheet(f, "CountPill", Color3.fromRGB(14, 10, 10), 3)
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.BackgroundTransparency = 0.25
	corner(pill, 999)
	stroke(pill, GOLD, 0.45, 1)
	local count = label(f, "0", 17, F.figures, LIGHT, {
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
	})
	local key = label(f, tostring(index), 12, F.bodyMedium, SMOKE, {
		Name = "KeyNum",
		AnchorPoint = Vector2.new(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 0.4,
		ZIndex = 3,
	})
	-- An engraved brass plate for the case's name (sized by layoutBinInside).
	local plate = sheet(f, "Plate", Color3.new(1, 1, 1), 3)
	shade(plate, 90, colours({ { 0, BRASS[1] }, { 0.5, BRASS[2] }, { 1, BRASS[3] } }))
	corner(plate, 3)
	stroke(plate, Color3.fromRGB(90, 62, 24), 0.25, 1)
	-- (Sized and placed by layoutBinInside, for the case's size.)
	local name = label(f, case.name, 16, F.bodyBold, ENGRAVED, { Name = "Title", ZIndex = 4 })
	local sub = label(f, case.subtitle, 13, F.body, SMOKE, { Name = "Sub", ZIndex = 3 })
	f.Parent = casesLayer
	return {
		id = case.id,
		face = case.face,
		index = index,
		frame = f,
		scale = scale,
		stroke = st,
		flash = flash,
		lip = lip,
		mark = mark,
		markPx = 0,
		count = count,
		name = name,
		plate = plate,
		sub = sub,
		key = key,
		centre = Vector2.zero,
		size = Vector2.zero,
		open = true,
		filed = 0,
	}
end

-- What's on a case, laid out for its size: on a wide case the piece sits on the left with the
-- name and what goes in it beside it; on a narrow one (a phone) the piece sits above the name.
local function layoutBinInside(bin: Bin)
	local s = L.s
	local w, h = L.binW, L.binH
	local f = bin.frame
	local inset = math.max(3, math.floor(4 * s))
	local velvet = f:FindFirstChild("Velvet")
	if velvet and velvet:IsA("Frame") then
		velvet.Position = UDim2.fromOffset(inset, inset)
		velvet.Size = UDim2.new(1, -2 * inset, 1, -2 * inset)
	end
	local pad = math.floor(10 * s) + inset
	local wide = w - h * 0.8 >= 112
	local markPx: number
	local pillW, pillH = math.floor(34 * s), textSize(17 * s) + math.floor(6 * s)
	bin.count.Position = UDim2.new(1, -(inset + math.floor(6 * s)), 0, inset + math.floor(5 * s))
	bin.count.Size = UDim2.fromOffset(pillW, pillH)
	bin.count.TextSize = textSize(17 * s)
	local pill = f:FindFirstChild("CountPill")
	if pill and pill:IsA("Frame") then
		pill.Position = bin.count.Position
		pill.Size = bin.count.Size
	end
	bin.key.Position = UDim2.new(1, -pad, 1, -math.floor(4 * s) - inset)
	bin.key.Size = UDim2.fromOffset(math.floor(24 * s), textSize(12 * s) + 2)
	bin.key.TextSize = textSize(12 * s)
	-- Every case's name is set at one size, the largest at which the longest name fits, so the
	-- six read as a set; the line under it may take two lines rather than shrink.
	local longestName, longestSub = 0, 0
	for _, c in Catalogue.Cases do
		longestName = math.max(longestName, utf8.len(c.name) or #c.name)
		longestSub = math.max(longestSub, utf8.len(c.subtitle) or #c.subtitle)
	end
	local subSize = textSize(math.clamp(h * 0.14, 12, 15))
	local nameSize: number
	if wide then
		markPx = math.floor(h * 0.66)
		bin.mark.Position = UDim2.new(0, pad + markPx / 2 - math.floor(2 * s), 0.5, 0)
		local textLeft = pad + markPx + math.floor(6 * s)
		local textW = w - textLeft - pad
		nameSize = textSize(math.min(math.clamp(h * 0.19, 13, 19), textW / (longestName * 0.62)))
		local lines = if longestSub * subSize * 0.5 > textW then 2 else 1
		local block = nameSize + math.floor(3 * s) + lines * math.ceil(subSize * 1.15)
		local top = (h - block) / 2
		-- The name engraved on its brass plate, just wide enough for the longest name.
		local platePad = math.floor(7 * s)
		local plateW = math.min(textW, math.floor(longestName * nameSize * 0.6) + 2 * platePad)
		local plateH = nameSize + math.floor(6 * s)
		top -= math.floor(3 * s)
		bin.plate.AnchorPoint = Vector2.new(0, 0)
		bin.plate.Position = UDim2.fromOffset(textLeft, top)
		bin.plate.Size = UDim2.fromOffset(plateW, plateH)
		bin.name.AnchorPoint = Vector2.new(0, 0)
		bin.name.TextXAlignment = Enum.TextXAlignment.Center
		bin.name.Position = UDim2.fromOffset(textLeft, top + math.floor(3 * s) - 1)
		bin.name.Size = UDim2.fromOffset(plateW, nameSize + 2)
		top += math.floor(6 * s)
		bin.sub.AnchorPoint = Vector2.new(0, 0)
		bin.sub.TextXAlignment = Enum.TextXAlignment.Left
		bin.sub.TextYAlignment = Enum.TextYAlignment.Top
		bin.sub.TextWrapped = true
		bin.sub.Position = UDim2.fromOffset(textLeft, top + nameSize + math.floor(3 * s))
		bin.sub.Size = UDim2.fromOffset(textW, lines * math.ceil(subSize * 1.15) + 2)
		bin.sub.Visible = true
	else
		markPx = math.floor(h * 0.52)
		bin.mark.Position = UDim2.new(0.5, 0, 0, inset + math.floor(2 * s) + markPx / 2)
		local textW = w - 2 * inset - math.floor(8 * s)
		nameSize = textSize(math.min(math.clamp(h * 0.19, 13, 19), textW / (longestName * 0.62)))
		bin.name.AnchorPoint = Vector2.new(0.5, 1)
		bin.name.TextXAlignment = Enum.TextXAlignment.Center
		bin.name.Position = UDim2.new(0.5, 0, 1, -inset - math.floor(5 * s))
		bin.name.Size = UDim2.fromOffset(textW, nameSize + 4)
		local plateW = math.min(textW, math.floor(longestName * nameSize * 0.6) + math.floor(12 * s))
		bin.plate.AnchorPoint = Vector2.new(0.5, 1)
		bin.plate.Position = UDim2.new(0.5, 0, 1, -inset - math.floor(3 * s))
		bin.plate.Size = UDim2.fromOffset(plateW, nameSize + math.floor(8 * s))
		-- No room for the line under the name: "Closed" shows in the name's place.
		bin.sub.Visible = false
	end
	for _, l in { bin.name, bin.sub } do
		l.TextScaled = false
	end
	bin.name.TextSize = nameSize
	bin.sub.TextSize = subSize
	bin.mark.Size = UDim2.fromOffset(markPx, markPx)
	-- On a wide drawer the count rides on the plinth's shoulder, leaving the plate room.
	if wide then
		local badgeW, badgeH = math.floor(30 * s), textSize(15 * s) + math.floor(4 * s)
		local cx = bin.mark.Position.X.Offset + math.floor(markPx * 0.42)
		local cy = math.floor(h / 2 - markPx * 0.42)
		bin.count.AnchorPoint = Vector2.new(0.5, 0.5)
		bin.count.Position = UDim2.fromOffset(cx, cy)
		bin.count.Size = UDim2.fromOffset(badgeW, badgeH)
		bin.count.TextSize = textSize(15 * s)
		if pill and pill:IsA("Frame") then
			pill.AnchorPoint = Vector2.new(0.5, 0.5)
			pill.Position = bin.count.Position
			pill.Size = bin.count.Size
		end
	else
		bin.count.AnchorPoint = Vector2.new(1, 0)
		if pill and pill:IsA("Frame") then
			pill.AnchorPoint = Vector2.new(1, 0)
		end
	end
	local plinth = f:FindFirstChild("Plinth")
	if plinth and plinth:IsA("Frame") then
		local d = math.floor(markPx * 1.08)
		plinth.Position = bin.mark.Position
		plinth.Size = UDim2.fromOffset(d, d)
	end
	if math.abs(markPx - bin.markPx) > 1 then
		bin.markPx = markPx
		bin.mark:ClearAllChildren()
		PieceIcon.piece(bin.mark, bin.face, markPx, bin.id)
	end
end

local function layoutBins()
	for i, bin in binOrder do
		local col = (i - 1) % L.cols
		local row = (i - 1) // L.cols
		local x = L.left + col * (L.binW + L.gap) + L.binW / 2
		local y = L.binsTop + row * (L.binH + L.gap) + L.binH / 2
		bin.centre = Vector2.new(x, y)
		bin.size = Vector2.new(L.binW, L.binH)
		bin.frame.Position = UDim2.fromOffset(x, y)
		bin.frame.Size = UDim2.fromOffset(L.binW, L.binH)
		layoutBinInside(bin)
	end
end

local function buildBins()
	for _, bin in binOrder do
		bin.frame:Destroy()
	end
	bins = {}
	binOrder = {}
	for i, case in Catalogue.Cases do
		local bin = binFrame(case, i)
		bins[case.id] = bin
		table.insert(binOrder, bin)
		bin.frame.InputBegan:Connect(function(input: InputObject)
			local t = input.UserInputType
			if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and held and heldMode == "tap" and playing then
				SortScreen.onFile(held :: number, case.id)
			end
		end)
	end
	layoutBins()
end

local function paintBin(bin: Bin)
	local over = hoverBin == bin.id
	local selected = heldMode == "pad" and held ~= nil and binOrder[padCase] == bin
	local lit = (over or selected) and bin.open
	local quick = Ease.info(0.14, Enum.EasingStyle.Quad)
	Ease.play(bin.stroke, quick, { Transparency = if lit then 0.2 elseif bin.open then 0.75 else 0.92, Thickness = if lit then 2 else 1 })
	bin.stroke.Color = if lit then GOLD else rim
	Ease.play(bin.flash, quick, { BackgroundTransparency = if lit then 0.9 else 1 })
	Ease.play(bin.lip, quick, { BackgroundTransparency = if lit then 0 else 1 })
	Ease.play(bin.scale, Ease.info(0.18, Enum.EasingStyle.Quad), { Scale = if lit then 1.03 else 1 })
	local dim = if bin.open then 0 else 0.55
	local case = Catalogue.caseById[bin.id] :: Catalogue.Case
	bin.frame.BackgroundTransparency = if bin.open then 0 else 0.45
	local velvet = bin.frame:FindFirstChild("Velvet")
	if velvet and velvet:IsA("Frame") then
		velvet.BackgroundTransparency = if bin.open then 0 else 0.55
	end
	bin.name.TextTransparency = dim
	bin.name.TextColor3 = ENGRAVED
	bin.plate.BackgroundTransparency = if bin.open then 0 else 0.6
	local plateStroke = bin.plate:FindFirstChildOfClass("UIStroke")
	if plateStroke then
		plateStroke.Color = if lit then LIGHT else Color3.fromRGB(90, 62, 24)
		plateStroke.Transparency = if lit then 0 else 0.25
	end
	-- A narrow case has no line under its name, so a closed one says so in its name's place.
	bin.name.Text = if not bin.open and not bin.sub.Visible then "Closed" else case.name
	bin.count.TextTransparency = dim
	bin.sub.TextTransparency = dim
	bin.sub.Text = if bin.open then case.subtitle else "Closed this round"
	bin.key.Visible = bin.open and State.inputKind() == "mouse"
	bin.mark.Visible = bin.open
	local plinth = bin.frame:FindFirstChild("Plinth")
	if plinth and plinth:IsA("Frame") and bin.frame:GetAttribute("Style") ~= "Boxes" and bin.frame:GetAttribute("Style") ~= "Plates" then
		plinth.BackgroundTransparency = if bin.open then 0 else 0.7
		local ring = plinth:FindFirstChildOfClass("UIStroke")
		if ring then
			ring.Transparency = if lit then 0.1 elseif bin.open then 0.55 else 0.9
		end
	end
	local pill = bin.frame:FindFirstChild("CountPill")
	if pill and pill:IsA("Frame") then
		pill.BackgroundTransparency = if bin.open then 0.25 else 0.75
	end
end

local function setHover(caseId: string?)
	if caseId == hoverBin then
		return
	end
	hoverBin = caseId
	for _, bin in binOrder do
		paintBin(bin)
	end
end

local function binAt(point: Vector2): string?
	for _, bin in binOrder do
		local d = point - bin.centre
		if math.abs(d.X) <= bin.size.X / 2 + 4 and math.abs(d.Y) <= bin.size.Y / 2 + 8 then
			return bin.id
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- The pieces
---------------------------------------------------------------------------------------------------

local function unfiled(): { Card }
	local list = {}
	for _, c in cards do
		if c.state ~= "flying" and c.state ~= "filed" then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

-- The room's line in the header: where you are and how much is left on the cloth.
local function updateRoom()
	if not gui then
		return
	end
	local parts = { roomText }
	if roundExtra ~= "" then
		table.insert(parts, roundExtra)
	end
	local n = 0
	for _, c in cards do
		if c.state ~= "flying" and c.state ~= "filed" then
			n += 1
		end
	end
	if next(cards) ~= nil then
		table.insert(parts, if n == 1 then "1 piece left" else tostring(n) .. " pieces left")
	end
	if eventLine then
		table.insert(parts, eventLine)
	end
	header.room.Text = table.concat(parts, "  ·  ")
end

-- What's on in the house (Golden Hour 11:28), on the room's line while you sit here.
function SortScreen.setEvent(line: string?)
	if line == eventLine then
		return
	end
	eventLine = line
	updateRoom()
end

-- Where each piece rests: set down here and there on the cloth as if by hand, never on top of
-- another, and clear of the hint across the middle. Pieces already down stay where they are
-- unless the size of the pieces changes (then everything is set down again). Returns whether it
-- did change.
local function arrange(all: boolean): boolean
	local list = unfiled()
	local n = #list
	if n == 0 then
		return false
	end
	local t = L.tray
	local s = L.s
	local cell = math.sqrt((t.w * t.h) / math.max(n, 6))
	local icon = math.floor(math.clamp(math.min(136 * s, cell * 0.56), 60 * s, 150 * s) * Settings.pieceScale(State.get("pieceSize")))
	local resized = math.abs(icon - L.icon) > 1
	L.icon = icon
	local redo = all or resized
	local margin = icon * 0.62 + 10 * s
	local x0, x1 = t.x + margin, t.x + t.w - margin
	local y0, y1 = t.y + margin + 10 * s, t.y + t.h - margin - 4 * s
	if x1 < x0 then
		x0, x1 = t.x + t.w / 2, t.x + t.w / 2
	end
	if y1 < y0 then
		y0, y1 = t.y + t.h / 2, t.y + t.h / 2
	end
	local hintCentre = Vector2.new(t.x + t.w / 2, t.y + t.h / 2)
	local hintWidth = math.min(t.w - 40 * s, 760 * s)
	local hintLines = if hintWidth < 600 * s then 3 else 2
	local hintHalf = Vector2.new(math.min(hintWidth, 600 * s) / 2 + icon * 0.4, hintLines * textSize(15 * s) * 0.7 + icon * 0.6)
	local placed: { Vector2 } = {}
	for _, c in list do
		if c.placed and not redo then
			table.insert(placed, c.home)
		end
	end
	for _, c in list do
		if c.placed and not redo then
			continue
		end
		local rng = Random.new(dealCount * 7919 + c.info.uid * 104729)
		local best, bestScore = Vector2.new((x0 + x1) / 2, (y0 + y1) / 2), -math.huge
		for _ = 1, 48 do
			local p = Vector2.new(rng:NextNumber(x0, x1), rng:NextNumber(y0, y1))
			local d = 4 * t.w
			for _, q in placed do
				d = math.min(d, (p - q).Magnitude)
			end
			local o = p - hintCentre
			if math.abs(o.X) < hintHalf.X and math.abs(o.Y) < hintHalf.Y then
				d *= 0.05
			end
			if d > bestScore then
				best, bestScore = p, d
			end
		end
		c.home = best
		c.placed = true
		table.insert(placed, best)
	end
	-- Reading order (rows, then left to right), for stepping through them with a gamepad.
	local band = icon * 1.4
	table.sort(list, function(a, b)
		local ra, rb = math.floor((a.home.Y - t.y) / band), math.floor((b.home.Y - t.y) / band)
		if ra ~= rb then
			return ra < rb
		end
		return a.home.X < b.home.X
	end)
	for i, c in list do
		c.order = i
	end
	return resized
end

local function cardFrame(info: PieceInfo, icon: number): (Frame, UIScale, Frame, Frame, Frame, TextLabel?, Frame?)
	local s = L.s
	local f = Instance.new("Frame")
	f.Name = "Piece"
	f:SetAttribute("Uid", info.uid)
	f:SetAttribute("PieceId", info.id)
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(icon, icon)
	f.Active = true
	f.ZIndex = 2
	local scale = Instance.new("UIScale")
	scale.Parent = f
	-- Its shadow on the cloth: soft at the ends, darkest beneath.
	local shadow = sheet(f, "Shadow", Color3.new(0, 0, 0), 1)
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 1, -math.floor(icon * 0.05))
	shadow.Size = UDim2.fromOffset(icon * 0.64, icon * 0.13)
	shadow.BackgroundTransparency = 0.35
	corner(shadow, 9999)
	shade(shadow, 0, nil, alphas({ { 0, 1 }, { 0.18, 0.55 }, { 0.5, 0 }, { 0.82, 0.55 }, { 1, 1 } }))
	-- A gilded or Mythic piece has a warm halo of light about it.
	if info.rare or info.mythic then
		-- Many faint rings, each a little smaller: together a soft halo that fades to nothing at
		-- its edge, with no visible bands.
		local tint = if info.mythic then Color3.fromRGB(255, 222, 150) else Color3.fromRGB(246, 196, 104)
		local layers = 9
		for k = 1, layers do
			local size = 1.45 - (k - 1) * (0.7 / (layers - 1))
			local glow = sheet(f, "Glow", tint, 1)
			glow.AnchorPoint = Vector2.new(0.5, 0.5)
			glow.Position = UDim2.fromScale(0.5, 0.5)
			glow.Size = UDim2.fromOffset(icon * size, icon * size)
			glow.BackgroundTransparency = if info.mythic then 0.965 else 0.975
			corner(glow, 9999)
		end
	end
	-- A golden piece (Admin Abuse): a bright gold halo, a gold ring and its tag.
	if info.golden then
		for k = 1, 6 do
			local glow = sheet(f, "GoldenGlow", Color3.fromRGB(255, 205, 80), 1)
			glow.AnchorPoint = Vector2.new(0.5, 0.5)
			glow.Position = UDim2.fromScale(0.5, 0.5)
			local size = 1.6 - (k - 1) * 0.12
			glow.Size = UDim2.fromOffset(icon * size, icon * size)
			glow.BackgroundTransparency = 0.9
			corner(glow, 9999)
		end
		local band = sheet(f, "GoldenRing", Color3.fromRGB(255, 214, 90), 1)
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Position = UDim2.fromScale(0.5, 0.5)
		band.Size = UDim2.fromOffset(icon * 1.12, icon * 1.12)
		band.BackgroundTransparency = 1
		corner(band, 9999)
		stroke(band, Color3.fromRGB(255, 220, 110), 0, math.max(2, 3 * s))
		local chip = label(f, "GOLDEN", math.max(9, 10 * s), F.bodyBold, Color3.fromRGB(40, 24, 4), {
			Name = "Golden",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, math.floor(2 * s)),
			Size = UDim2.fromOffset(math.floor(64 * s), math.floor(16 * s)),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(255, 206, 84),
			ZIndex = 3,
		})
		corner(chip, 9999)
	end
	local ring = sheet(f, "Selected", LIGHT, 1)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(icon * 1.18, icon * 1.18)
	ring.BackgroundTransparency = 0.92
	ring.Visible = false
	corner(ring, 9999)
	stroke(ring, LIGHT, 0.1, 1.5)
	local art = Instance.new("Frame")
	art.Name = "Icon"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromOffset(icon, icon)
	art.ZIndex = 2
	art.Parent = f
	PieceIcon.piece(art, info.id, icon, info.case)
	-- A glint that comes and goes on the gilded ones (and the golden ones).
	local twinkle: Frame? = nil
	if info.rare or info.mythic or info.golden then
		local tw = Instance.new("Frame")
		tw.Name = "Twinkle"
		tw.BackgroundTransparency = 1
		tw.AnchorPoint = Vector2.new(0.5, 0.5)
		tw.Position = UDim2.fromScale(0.8, 0.16)
		tw.Size = UDim2.fromOffset(icon * 0.16, icon * 0.16)
		tw.ZIndex = 3
		tw.Parent = art
		for _, r in { 0, 90 } do
			local bar = sheet(tw, "Ray", Color3.fromRGB(255, 248, 228), 3)
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.fromScale(0.5, 0.5)
			bar.Size = UDim2.fromScale(0.16, 1)
			bar.Rotation = r
			corner(bar, 9999)
			shade(bar, 90, nil, alphas({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }))
		end
		twinkle = tw
	end
	-- Its name, on a small dark tag above it, while you point at it or hold it.
	local tag: TextLabel? = nil
	if names then
		local t = Instance.new("TextLabel")
		t.Name = "Name"
		t.AnchorPoint = Vector2.new(0.5, 1)
		t.Position = UDim2.new(0.5, 0, 0, -math.floor(6 * s))
		t.AutomaticSize = Enum.AutomaticSize.X
		local size = textSize(13 * s)
		t.Size = UDim2.fromOffset(math.floor(#info.name * size * 0.56 + 22 * s), math.floor(size + 13 * s))
		t.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
		t.BackgroundTransparency = 0.06
		t.BorderSizePixel = 0
		t.Text = info.name
		t.FontFace = F.bodyMedium
		t.TextSize = size
		t.TextColor3 = if info.mythic or info.rare then LIGHT else BONE
		t.Visible = false
		t.ZIndex = 4
		corner(t, math.max(2, math.floor(2 * s)))
		stroke(t, LIGHT, 0.84, 1)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, math.floor(10 * s))
		pad.PaddingRight = UDim.new(0, math.floor(10 * s))
		pad.Parent = t
		t.Parent = f
		tag = t
	end
	f.Parent = piecesLayer
	return f, scale, ring, art, shadow, tag, twinkle
end

local function placeCard(c: Card)
	if c.frame then
		c.frame.Position = UDim2.fromOffset(c.pos.X, c.pos.Y)
	end
end

local function showTag(c: Card)
	-- Names show on a piece you point at, hold or pick out, or on every piece with "Always on".
	local always = State.get("pieceNames") == "Always on"
	local on = names and (always or c.hover or c.state == "held" or c.ring.Visible) and c.state ~= "flying" and c.state ~= "filed"
	if c.tag then
		c.tag.Visible = on
	end
	c.frame.ZIndex = if c.state == "held" then 5 elseif on then 4 else 2
end

local function select(index: number?)
	for _, c in cards do
		if c.ring.Visible then
			c.ring.Visible = false
			showTag(c)
		end
	end
	if index == nil or State.inputKind() ~= "gamepad" then
		return
	end
	local list = unfiled()
	if #list == 0 then
		return
	end
	padIndex = ((index - 1) % #list) + 1
	if not held then
		local c = list[padIndex]
		c.ring.Visible = true
		showTag(c)
	end
end

-- The nearest piece in a direction from the one the gamepad has chosen (up and down the cloth).
local function nearestFrom(index: number, dir: Vector2): number?
	local list = unfiled()
	local from = list[index]
	if not from then
		return nil
	end
	local best, bestScore = nil, math.huge
	for i, c in list do
		local d = c.home - from.home
		local along = d.X * dir.X + d.Y * dir.Y
		if i ~= index and along > 4 then
			local across = math.abs(d.X * dir.Y - d.Y * dir.X)
			local score = along + across * 2
			if score < bestScore then
				best, bestScore = i, score
			end
		end
	end
	return best
end

local function lifted(c: Card, on: boolean)
	Ease.play(c.scale, Ease.info(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if on then 1.14 else 1 })
	local icon = L.icon
	Ease.play(c.shadow, Ease.info(0.16, Enum.EasingStyle.Quad), {
		BackgroundTransparency = if on then 0.62 else 0.35,
		Position = UDim2.new(0.5, 0, 1, if on then math.floor(icon * 0.14) else -math.floor(icon * 0.03)),
		Size = UDim2.fromOffset(icon * (if on then 0.8 else 0.66), icon * (if on then 0.18 else 0.15)),
	})
	showTag(c)
end

local function hideTrail()
	if trail then
		trail = nil
		GuideTrail.hide()
	end
end

-- How the guide looks for this guest: the trail they wear (from the Boutique or the Ledger) or
-- the colour they chose, the style and pace from Settings → The guide, sparkles from Settings →
-- Glow and sparks, and Movement.
function SortScreen.guideLook(): GuideTrail.Look
	local worn = Closet.style("trail")
	local colour = if worn and typeof(worn.colour) == "Color3" then worn.colour else (Brand.TrailColours[State.get("trailColour")] or Brand.TrailColours.House)
	local pace = State.get("trailPace")
	local glow = State.get("glow")
	return {
		kind = tostring(State.get("trail") or "Sparkles"),
		colour = colour,
		pace = if pace == "Lively" then 1.6 elseif pace == "Calm" then 0.55 else 1,
		glow = if glow == "Off" then 0 elseif glow == "Subtle" then 0.5 else 1,
		motion = Ease.motionScale,
	}
end

-- Seconds before the guide shows for a held piece, or nil for none: the room decides (full,
-- delayed, none) and the guest's "Show the way" can only make it later or turn it off.
function SortScreen.guideDelay(): number?
	local setting = State.get("showTheWay")
	if guide == "none" or setting == "Never" then
		return nil
	end
	local roomDelay = if guide == "delayed" then guideDelay else 0
	local settingDelay = if setting == "After a moment" then 1.2 else 0
	return math.max(roomDelay, settingDelay)
end

-- The guide: in the rooms that have one, the right case lights up while a piece is held, a
-- thread of light with sparkles runs to it, and an arrow bobs over it.
local function showGuide(uid: number?)
	if guideThread then
		pcall(task.cancel, guideThread)
		guideThread = nil
	end
	hideTrail()
	GuideTrail.target(nil)
	if uid == nil then
		return
	end
	-- (Read on every pick-up: the sparkles a carried piece sheds follow it too, in every room.)
	GuideTrail.setLook(SortScreen.guideLook())
	local delay = SortScreen.guideDelay()
	if delay == nil then
		return
	end
	local c = cards[uid]
	local bin = c and bins[c.info.case]
	if not bin then
		return
	end
	local b = bin
	guideThread = task.delay(delay, function()
		guideThread = nil
		if held ~= uid or not b.frame.Parent then
			return
		end
		GuideTrail.target(b.frame)
		trail = { uid = uid, bin = b, since = clock }
	end)
end

local function release()
	local uid = held
	held = nil
	heldMode = nil
	setHover(nil)
	showGuide(nil)
	if uid then
		local c = cards[uid]
		if c and c.state == "held" then
			c.state = "rest"
			c.target = nil
			lifted(c, false)
		end
	end
	for _, bin in binOrder do
		paintBin(bin)
	end
	select(padIndex)
end

local function lift(uid: number, mode: string): boolean
	local c = cards[uid]
	if not c or c.state ~= "rest" or not playing then
		return false
	end
	if not SortScreen.canLift(uid) then
		return false
	end
	if held and held ~= uid then
		release()
	end
	held = uid
	heldMode = mode
	c.state = "held"
	c.target = if mode == "drag" then c.pos else nil
	select(nil)
	lifted(c, true)
	SortScreen.onLift(uid, mode)
	showGuide(uid)
	if mode == "pad" then
		padCase = 1
		for _, bin in binOrder do
			paintBin(bin)
		end
	end
	return true
end

-- A short "no" for a piece that can't be lifted just now (a fumble).
function SortScreen.refuse(uid: number)
	local c = cards[uid]
	if not c then
		return
	end
	for i, dx in { 8, -6, 4, 0 } do
		task.delay(0.04 * (i - 1), function()
			if c.state == "rest" then
				c.frame.Position = UDim2.fromOffset(c.pos.X + dx * L.s, c.pos.Y)
			end
		end)
	end
end

-- (Re)builds a piece's frame at the current piece size and wires its input.
local function attach(c: Card)
	local old = c.frame
	local frame, scale, ring, art, shadow, tag, twinkle = cardFrame(c.info, L.icon)
	if old then
		frame.Position = old.Position
		frame.Visible = old.Visible
		old:Destroy()
	end
	c.frame = frame
	c.scale = scale
	c.ring = ring
	c.art = art
	c.shadow = shadow
	c.tag = tag
	c.twinkle = twinkle
	c.hover = false
	local uid = c.info.uid
	frame.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and playing then
			press = { uid = uid, at = toScreen(input), input = input }
		end
	end)
	frame.MouseEnter:Connect(function()
		c.hover = true
		showTag(c)
		if held == nil and c.state == "rest" and playing then
			Ease.play(scale, Ease.info(0.14, Enum.EasingStyle.Quad), { Scale = 1.07 })
		end
	end)
	frame.MouseLeave:Connect(function()
		c.hover = false
		showTag(c)
		if c.state == "rest" and held ~= uid then
			Ease.play(scale, Ease.info(0.14, Enum.EasingStyle.Quad), { Scale = 1 })
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------------------------------

local function popText(at: Vector2, lines: { { text: string, size: number, font: Font, colour: Color3 } }, shake: boolean)
	local s = L.s
	local holder = Instance.new("Frame")
	holder.Name = "Verdict"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.fromOffset(at.X, at.Y)
	holder.Size = UDim2.fromOffset(380 * s, 120 * s)
	holder.ZIndex = 8
	holder.Parent = fxLayer
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = holder
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = holder
	local made: { TextLabel } = {}
	for i, spec in lines do
		local l = label(holder, spec.text, spec.size * s, spec.font, spec.colour, {
			LayoutOrder = i,
			AnchorPoint = Vector2.new(0, 0),
			Size = UDim2.new(1, 0, 0, math.floor(spec.size * s * 1.35)),
			TextStrokeTransparency = 0.55,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			ZIndex = 8,
		})
		table.insert(made, l)
	end
	local seconds = Config.data.Sorting.verdictSeconds
	Ease.play(scale, Ease.info(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	Ease.play(holder, Ease.info(seconds + 0.3, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(at.X, at.Y - 34 * s) })
	if shake and Ease.motionScale >= 0.5 then
		for i, angle in { -5, 4, -3, 2, 0 } do
			task.delay(0.05 * i, function()
				if holder.Parent then
					Ease.play(holder, Ease.info(0.05, Enum.EasingStyle.Sine), { Rotation = angle })
				end
			end)
		end
	end
	task.delay(seconds * 0.6, function()
		for _, l in made do
			Ease.play(l, Ease.info(seconds * 0.4 + 0.2, Enum.EasingStyle.Sine), { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
	task.delay(seconds + 0.5, function()
		holder:Destroy()
	end)
end

local function burst(at: Vector2, count: number, colour: Color3)
	if Ease.motionScale < 0.5 then
		return
	end
	local s = L.s
	for i = 1, count do
		local p = sheet(fxLayer, "Spark", colour, 8)
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.fromOffset(at.X, at.Y)
		p.Size = UDim2.fromOffset(4 * s, 9 * s)
		corner(p, 9999)
		local ang = (i / count) * math.pi * 2 + math.random() * 0.4
		local dist = (40 + math.random() * 44) * s
		local goal = at + Vector2.new(math.cos(ang), math.sin(ang) - 0.6) * dist
		local t = Ease.play(p, Ease.info(0.5 + math.random() * 0.2, Enum.EasingStyle.Quad), {
			Position = UDim2.fromOffset(goal.X, goal.Y),
			BackgroundTransparency = 1,
			Rotation = math.deg(ang) + 90,
		})
		t.Completed:Once(function()
			p:Destroy()
		end)
	end
end

local function flashBin(bin: Bin, colour: Color3)
	bin.flash.BackgroundColor3 = colour
	bin.flash.BackgroundTransparency = 0.68
	Ease.play(bin.flash, Ease.info(0.55, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
	bin.stroke.Color = colour
	bin.stroke.Transparency = 0
	local t = Ease.play(bin.stroke, Ease.info(0.6, Enum.EasingStyle.Sine), { Transparency = if bin.open then 0.9 else 0.95 })
	t.Completed:Once(function()
		bin.stroke.Color = rim
	end)
	-- A band of light sweeps across the drawer's glass, as if its lid had just been closed.
	if Ease.motionScale >= 0.5 then
		-- (in a clipping frame of its own, so the light stays on the glass)
		local clip = Instance.new("Frame")
		clip.Name = "Sweep"
		clip.BackgroundTransparency = 1
		clip.Size = UDim2.fromScale(1, 1)
		clip.ClipsDescendants = true
		clip.ZIndex = 5
		clip.Parent = bin.frame
		local band = sheet(clip, "Band", Color3.new(1, 1, 1), 5)
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Position = UDim2.fromScale(-0.2, 0.5)
		band.Size = UDim2.fromScale(0.22, 1)
		band.BackgroundTransparency = 0.55
		shade(band, 0, nil, alphas({ { 0, 1 }, { 0.5, 0.3 }, { 1, 1 } }))
		local sweep = Ease.play(band, Ease.info(0.5, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.2, 0.5) })
		sweep.Completed:Once(function()
			clip:Destroy()
		end)
	end
end

-- Into its case: the piece flies down, shrinks into the case, and the case counts it.
local function flyIn(c: Card, bin: Bin, quiet: boolean)
	c.state = "flying"
	c.target = nil
	c.hover = false
	showTag(c)
	if held == c.info.uid then
		held = nil
		heldMode = nil
	end
	updateRoom()
	local goal = bin.centre - Vector2.new(0, bin.size.Y * 0.15)
	local info = Ease.scaled(TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
	TweenService:Create(c.frame, info, { Position = UDim2.fromOffset(goal.X, goal.Y), Rotation = (c.info.uid % 2 == 0) and 14 or -14 }):Play()
	local t = TweenService:Create(c.scale, info, { Scale = 0.42 })
	t.Completed:Once(function()
		local shrink = TweenService:Create(c.scale, Ease.scaled(TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)), { Scale = 0 })
		shrink.Completed:Once(function()
			-- Kept, hidden, in case the server turns the filing down and it has to come back.
			if c.state == "filed" then
				c.frame.Visible = false
			end
		end)
		shrink:Play()
		c.state = "filed"
		c.inCase = bin.id
		-- (The case as it is now: the cases are made afresh if the case style changes mid-flight.)
		local into = bins[bin.id] or bin
		into.filed += 1
		into.count.Text = tostring(into.filed)
		if not quiet then
			into.scale.Scale = 1.08
			Ease.play(into.scale, Ease.info(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if hoverBin == into.id then 1.03 else 1 })
			into.count.TextColor3 = LIGHT
			Ease.play(into.count, Ease.info(0.8, Enum.EasingStyle.Sine), { TextColor3 = SMOKE })
			flashBin(into, LIGHT)
			burst(goal, if c.info.rare or c.info.mythic then 14 else 8, LIGHT)
		end
	end)
	t:Play()
end

local function goHome(c: Card, shakeFirst: boolean)
	c.target = nil
	lifted(c, false)
	local function back()
		if cards[c.info.uid] == c and (c.state == "shaking" or c.state == "held") then
			c.state = "rest"
			showTag(c)
		end
	end
	if shakeFirst and Ease.motionScale >= 0.5 then
		c.state = "shaking" -- held still while it shakes
		showTag(c)
		local here = c.pos
		for i, dx in { 12, -10, 7, -4, 0 } do
			task.delay(0.045 * (i - 1), function()
				if cards[c.info.uid] == c then
					c.frame.Position = UDim2.fromOffset(here.X + dx * L.s, here.Y)
				end
			end)
		end
		task.delay(0.045 * 5, back)
		return
	end
	back()
end

---------------------------------------------------------------------------------------------------
-- What the table tells the screen
---------------------------------------------------------------------------------------------------

function SortScreen.isOpen(): boolean
	return isOpen
end

local function setRoundText(roomName: string, roundText: string)
	roomText = roomName
	local word, rest = string.match(roundText, "^(%S+)%s+(.+)$")
	local round = stats.ROUND
	if word == "Round" or word == "Hand" then
		round.key.Text = Caps(word :: string)
		round.value.Text = rest :: string
		round.shown = true
		roundExtra = ""
	else
		round.shown = false
		roundExtra = roundText
	end
	updateRoom()
	layoutStats()
end

-- The guest's own table style and lamp, if they wear them: the cloth takes the felt's colour
-- (kept dark enough for the pieces to read), the edges take the rims', the lamplight the lamp's.
local function paintCloth()
	local tableStyle = Closet.style("table")
	local lampStyle = Closet.style("lamp")
	local felt = if tableStyle and typeof(tableStyle.felt) == "Color3" then tableStyle.felt :: Color3 else nil
	local rimColour = if tableStyle and typeof(tableStyle.rim) == "Color3" then tableStyle.rim :: Color3 else nil
	local lampColour = if lampStyle and typeof(lampStyle.colour) == "Color3" then lampStyle.colour :: Color3 else nil
	if felt then
		local h, sat, v = felt:ToHSV()
		local base = Color3.fromHSV(h, sat, math.clamp(v, 0.06, 0.4))
		header.trayShade.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, base:Lerp(Color3.new(1, 1, 1), 0.06)),
			ColorSequenceKeypoint.new(0.5, base),
			ColorSequenceKeypoint.new(1, base:Lerp(Color3.new(0, 0, 0), 0.45)),
		})
	else
		header.trayShade.Color = CLOTH
	end
	rim = rimColour or LIGHT
	header.frameStroke.Color = rim
	-- (A table style with its own rim colour tints the tooling to match.)
	header.innerStroke.Color = rimColour or GOLD
	header.lamp.BackgroundColor3 = lampColour or LAMP
	for _, pool in header.pools do
		pool.BackgroundColor3 = if lampColour then lampColour:Lerp(Color3.new(1, 1, 1), 0.3) else POOL
	end
	for _, bin in binOrder do
		paintBin(bin)
	end
end

function SortScreen.open(roomName: string, roundText: string)
	runOfCorrect = 0
	build()
	paintCloth()
	measure()
	layoutChrome()
	buildBins()
	makeMotes()
	setRoundText(roomName, roundText)
	if isOpen then
		return
	end
	isOpen = true
	if tableFX then
		ScreenFX.setEnabled(tableFX, true)
	end
	local g = gui :: ScreenGui
	-- A dip to black, then the screen.
	curtain.BackgroundTransparency = 1
	root.Visible = false
	g.Enabled = true
	local dark = Ease.play(curtain, Ease.scaled(Ease.info(0.28, Enum.EasingStyle.Sine)), { BackgroundTransparency = 0 })
	dark.Completed:Once(function()
		if isOpen then
			root.Visible = true
			Ease.play(curtain, Ease.scaled(Ease.info(0.45, Enum.EasingStyle.Sine)), { BackgroundTransparency = 1 })
		end
	end)
	SortScreen.bind()
end

function SortScreen.close()
	if not isOpen then
		return
	end
	isOpen = false
	playing = false
	if tableFX then
		ScreenFX.setEnabled(tableFX, false)
	end
	SortScreen.unbind()
	release()
	press = nil
	local g = gui :: ScreenGui
	local dark = Ease.play(curtain, Ease.scaled(Ease.info(0.25, Enum.EasingStyle.Sine)), { BackgroundTransparency = 0 })
	dark.Completed:Once(function()
		if isOpen then
			return
		end
		SortScreen.clear()
		root.Visible = false
		local t = Ease.play(curtain, Ease.scaled(Ease.info(0.45, Enum.EasingStyle.Sine)), { BackgroundTransparency = 1 })
		t.Completed:Once(function()
			if not isOpen then
				g.Enabled = false
			end
		end)
	end)
end

function SortScreen.setRound(roomName: string, roundText: string)
	if not gui then
		return
	end
	setRoundText(roomName, roundText)
end

function SortScreen.setPlaying(on: boolean)
	playing = on
	if not on then
		release()
		press = nil
	end
end

-- The cases open this round; the rest are shown closed.
function SortScreen.setCases(open: { string })
	for _, bin in binOrder do
		bin.open = table.find(open, bin.id) ~= nil
		paintBin(bin)
	end
end

function SortScreen.setRules(showNames: boolean, guideKind: string, delay: number)
	names = showNames
	guide = guideKind
	guideDelay = delay
end

-- A new deal: the cloth clears and the pieces are set down one after another.
function SortScreen.deal(list: { PieceInfo })
	SortScreen.clear()
	dealCount += 1
	for _, bin in binOrder do
		bin.filed = 0
		bin.count.Text = "0"
	end
	SortScreen.add(list, true)
end

-- Pieces arriving (a deal, a parcel): the new ones are set down in the spaces left.
function SortScreen.add(list: { PieceInfo }, fromDeal: boolean?)
	if not gui then
		return
	end
	local fresh: { Card } = {}
	for _, info in list do
		local rng = Random.new(info.uid * 31 + dealCount)
		local c: Card = {
			info = info,
			frame = nil :: any,
			scale = nil :: any,
			ring = nil :: any,
			art = nil :: any,
			shadow = nil :: any,
			tag = nil,
			twinkle = nil,
			home = Vector2.zero,
			placed = false,
			pos = Vector2.zero,
			vel = Vector2.zero,
			target = nil,
			state = "rest",
			order = 100000 + info.uid,
			phase = rng:NextNumber() * math.pi * 2,
			hover = false,
		}
		cards[info.uid] = c
		table.insert(fresh, c)
	end
	-- Pieces already on the cloth take the new size if setting these down changed it.
	if arrange(false) then
		for _, c in cards do
			if c.frame and c.state ~= "flying" and table.find(fresh, c) == nil then
				attach(c)
			end
		end
	end
	for i, c in fresh do
		attach(c)
		c.pos = c.home - Vector2.new(0, 36 * L.s)
		placeCard(c)
		c.scale.Scale = 0.55
		c.frame.Rotation = (Random.new(c.info.uid):NextNumber() - 0.5) * 16
		c.frame.Visible = false
		task.delay((i - 1) * (if fromDeal then 0.05 else 0.06), function()
			if cards[c.info.uid] ~= c then
				return
			end
			c.frame.Visible = true
			Ease.play(c.scale, Ease.info(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		end)
	end
	updateRoom()
	select(padIndex)
end

function SortScreen.clear()
	for _, c in cards do
		c.frame:Destroy()
	end
	cards = {}
	held = nil
	heldMode = nil
	press = nil
	hoverBin = nil
	showGuide(nil)
	GuideTrail.clear()
	if fxLayer then
		fxLayer:ClearAllChildren()
	end
	for _, bin in binOrder do
		paintBin(bin)
	end
	updateRoom()
end

function SortScreen.heldUid(): number?
	return held
end

-- A right case.
local FEEDBACK = {
	{ from = 3, word = "Great", colour = Color3.fromRGB(240, 222, 176), size = 21 },
	{ from = 6, word = "Excellent", colour = Color3.fromRGB(250, 214, 130), size = 23 },
	{ from = 10, word = "Perfect", colour = Color3.fromRGB(255, 240, 200), size = 25 },
	{ from = 15, word = "Legendary", colour = Color3.fromRGB(255, 196, 70), size = 28 },
}

function SortScreen.correct(uid: number, caseId: string, points: number?, multiplier: number?)
	local c = cards[uid]
	local bin = bins[caseId]
	if not c or not bin then
		return
	end
	showGuide(nil)
	setHover(nil)
	flyIn(c, bin, false)
	-- The word grows with the run of correct pieces: Correct, Great, Excellent, Perfect, Legendary.
	runOfCorrect += 1
	local word, colour, size = Voice.Sorting.correct, LIGHT, 19
	for _, tier in FEEDBACK do
		if runOfCorrect >= tier.from then
			word, colour, size = tier.word, tier.colour, tier.size
		end
	end
	local lines = { { text = Caps(word), size = size, font = F.bodyBold, colour = colour } }
	if points and points > 0 then
		local sub = "+" .. number(points)
		if multiplier and multiplier > 1 then
			sub ..= "  ×" .. tostring(multiplier)
		end
		table.insert(lines, { text = sub, size = 30, font = F.figures, colour = BONE })
	end
	popText(bin.centre - Vector2.new(0, bin.size.Y * 0.55), lines, false)
	select(padIndex)
end

-- A golden piece in its right case: what it paid, big, over its case.
function SortScreen.golden(caseId: string, gilt: number)
	local bin = bins[caseId]
	if not bin then
		return
	end
	local at = bin.centre - Vector2.new(0, bin.size.Y * 1.25)
	popText(at, {
		{ text = "GOLDEN!", size = 24, font = F.bodyBold, colour = Color3.fromRGB(255, 214, 90) },
		{ text = "+" .. number(gilt) .. " GILT", size = 34, font = F.figures, colour = Color3.fromRGB(255, 236, 170) },
	}, false)
	burst(bin.centre, 26, Color3.fromRGB(255, 206, 84))
end

-- Whether this table's deals hold golden pieces while the house is in uproar (the rooms do).
function SortScreen.setGolden(on: boolean)
	if tableFX then
		ScreenFX.setGolden(tableFX, on)
	end
end

-- The server filed it after all (a quiet correction): in it goes, without a fuss.
function SortScreen.intoCase(uid: number, caseId: string)
	local c = cards[uid]
	local bin = bins[caseId]
	if c and bin and c.state ~= "flying" then
		flyIn(c, bin, true)
	end
end

-- A wrong case.
function SortScreen.wrong(uid: number, caseId: string, lostStreak: number, penalty: number?)
	runOfCorrect = 0
	local c = cards[uid]
	local bin = bins[caseId]
	showGuide(nil)
	setHover(nil)
	if held == uid then
		held = nil
		heldMode = nil
	end
	if bin then
		flashBin(bin, CORAL)
		if Ease.motionScale >= 0.5 then
			local here = bin.centre
			for i, dx in { 10, -8, 6, -3, 0 } do
				task.delay(0.04 * (i - 1), function()
					bin.frame.Position = UDim2.fromOffset(here.X + dx * L.s, here.Y)
				end)
			end
		end
		local again = Voice.Sorting.tryAgain
		if penalty and penalty > 0 then
			again ..= "   −" .. number(penalty)
		end
		local lines = {
			{ text = Caps(Voice.Sorting.wrong), size = 19, font = F.bodyBold, colour = CORAL },
			{ text = again, size = 24, font = F.displayItalic, colour = BONE },
		}
		if lostStreak >= 2 then
			table.insert(lines, { text = (string.gsub(Voice.Sorting.streakLost, "{n}", tostring(lostStreak))), size = 14, font = F.body, colour = SMOKE })
		end
		popText(bin.centre - Vector2.new(0, bin.size.Y * 0.55), lines, true)
	end
	if c then
		goHome(c, true)
	end
	for _, b in binOrder do
		paintBin(b)
	end
	select(padIndex)
end

-- Back to its place, without a word (a filing the server turned down), even out of a case.
function SortScreen.home(uid: number)
	local c = cards[uid]
	if not c then
		return
	end
	if held == uid then
		held = nil
		heldMode = nil
	end
	if c.state == "filed" or c.state == "flying" then
		local bin = if c.inCase then bins[c.inCase] else nil
		if bin and c.state == "filed" then
			bin.filed = math.max(0, bin.filed - 1)
			bin.count.Text = tostring(bin.filed)
			c.pos = bin.centre
		end
		c.inCase = nil
		c.frame.Visible = true
		c.frame.Rotation = 0
		c.scale.Scale = 1
		c.state = "rest"
		placeCard(c)
		updateRoom()
		return
	end
	goHome(c, false)
end

local function pulse(st: Stat)
	st.scale.Scale = 1.18
	Ease.play(st.scale, Ease.info(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
end

function SortScreen.setScore(score: number, multiplier: number)
	if not gui then
		return
	end
	local sc, combo = stats.SCORE, stats.COMBO
	local layout = not sc.shown or not combo.shown or sc.width ~= 112
	sc.key.Text = "SCORE"
	sc.value.Text = number(score)
	sc.value.TextSize = textSize(34 * L.s)
	sc.width = 112
	sc.shown = true
	local before = combo.value.Text
	combo.value.Text = "×" .. tostring(multiplier)
	combo.value.TextTransparency = if multiplier > 1 then 0 else 0.55
	combo.value.TextColor3 = if multiplier > 1 then LIGHT else BONE
	combo.shown = true
	if before ~= combo.value.Text and multiplier > 1 then
		pulse(combo)
	end
	if layout then
		layoutStats()
	end
end

-- The Library and the Ballroom count pieces, not points.
function SortScreen.setLine(text: string, caption: string)
	if not gui then
		return
	end
	local sc = stats.SCORE
	sc.key.Text = Caps(caption)
	sc.value.Text = text
	sc.value.TextSize = textSize(24 * L.s)
	sc.width = 176
	sc.shown = true
	stats.COMBO.shown = false
	layoutStats()
end

function SortScreen.setClock(left: number?, budget: number?)
	if not gui then
		return
	end
	local rail = header.rail :: Frame
	local time = stats.TIME
	if left == nil or budget == nil or budget <= 0 then
		rail.Visible = false
		time.value.Text = ""
		if time.shown then
			time.shown = false
			layoutStats()
		end
		return
	end
	rail.Visible = true
	local fraction = math.clamp(left / budget, 0, 1)
	local fill = header.railFill :: Frame
	fill.Size = UDim2.fromScale(fraction, 1)
	local low = left <= 10
	fill.BackgroundColor3 = if low then CORAL else GOLD
	time.value.Text = string.format("%d:%02d", math.floor(math.ceil(left) / 60), math.ceil(left) % 60)
	time.value.TextColor3 = if low then CORAL else BONE
	if not time.shown then
		time.shown = true
		layoutStats()
	end
end

-- A streak called out across the top of the cloth.
function SortScreen.streak(n: number, multiplier: number)
	if not gui then
		return
	end
	local s = L.s
	local at = Vector2.new(L.vp.X / 2, L.tray.y + 34 * s)
	-- A brass ribbon across the top of the leather, its ends notched, the words engraved.
	local holder = sheet(fxLayer, "Streak", Color3.new(1, 1, 1), 9)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(at.X, at.Y)
	holder.Size = UDim2.fromOffset(math.min(420 * s, L.tray.w - 80 * s), 60 * s)
	holder.BackgroundTransparency = 0
	shade(holder, 90, colours({ { 0, BRASS[1] }, { 0.5, BRASS[2] }, { 1, BRASS[3] } }))
	corner(holder, 3)
	local ribbonEdge = stroke(holder, Color3.fromRGB(90, 62, 24), 0.2, 1)
	local rules: { Frame } = { holder }
	for _, side in { 0, 1 } do
		local tail = sheet(holder, "Tail", Color3.fromRGB(150, 108, 46), 8)
		tail.AnchorPoint = Vector2.new(0.5, 0.5)
		tail.Position = UDim2.new(side, if side == 0 then -20 * s else 20 * s, 0.55, 0)
		tail.Size = UDim2.fromOffset(34 * s, 34 * s)
		tail.Rotation = 45
		table.insert(rules, tail)
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = holder
	local title = string.gsub(Voice.Sorting.inARow, "{n}", tostring(n))
	local line = Voice.Sorting.moments[n] or string.gsub(Voice.Sorting.multiplier, "{n}", tostring(multiplier))
	local t1 = label(holder, Caps(title), 12 * s, F.bodyBold, ENGRAVED, { Position = UDim2.fromScale(0.5, 0.28), Size = UDim2.fromScale(1, 0.3), ZIndex = 10 })
	local t2 = label(holder, line, 24 * s, F.displayItalic, ENGRAVED, { Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromScale(1, 0.46), ZIndex = 10 })
	Ease.play(scale, Ease.info(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	task.delay(1.4, function()
		if not holder.Parent then
			return
		end
		local fade = Ease.info(0.4, Enum.EasingStyle.Sine)
		Ease.play(t1, fade, { TextTransparency = 1 })
		Ease.play(ribbonEdge, fade, { Transparency = 1 })
		Ease.play(t2, fade, { TextTransparency = 1 })
		for _, r in rules do
			Ease.play(r, fade, { BackgroundTransparency = 1 })
		end
		task.delay(0.45, function()
			holder:Destroy()
		end)
	end)
end

-- Your rival on tonight's table, at the foot of the cloth (gold once you're ahead).
function SortScreen.setRival(text: string?, ahead: boolean)
	if not gui then
		return
	end
	local l = header.rival :: TextLabel
	if text then
		l.Text = text
		l.TextColor3 = if ahead then LIGHT else SMOKE
		Ease.play(l, Ease.info(0.5, Enum.EasingStyle.Sine), { TextTransparency = 0.1 })
	else
		Ease.play(l, Ease.info(0.4, Enum.EasingStyle.Sine), { TextTransparency = 1 })
	end
end

-- Redraws every piece (a setting changed: names, piece size).
function SortScreen.refresh(showNames: boolean)
	names = showNames
	if not gui or not isOpen then
		return
	end
	-- A new case style: the cases are made afresh, keeping their counts and which are open.
	local first = binOrder[1]
	if first and first.frame:GetAttribute("Style") ~= State.get("caseStyle") then
		local kept = {}
		for _, bin in binOrder do
			kept[bin.id] = { filed = bin.filed, open = bin.open }
		end
		showGuide(nil)
		buildBins()
		for _, bin in binOrder do
			local k = kept[bin.id]
			if k then
				bin.filed = k.filed
				bin.open = k.open
				bin.count.Text = tostring(k.filed)
			end
			paintBin(bin)
		end
	end
	arrange(true)
	for _, c in cards do
		if c.state ~= "flying" then
			attach(c)
			placeCard(c)
		end
	end
	select(padIndex)
end

-- The line across the middle of the cloth, the first times you sit.
local hintLeft = 0
function SortScreen.hint(on: boolean)
	if not gui then
		return
	end
	local l = header.hint :: TextLabel
	if on then
		hintLeft = Config.data.Sorting.hintFilings
		local how = (Voice.Sorting.hints :: any)[State.inputKind()] or Voice.Sorting.hints.mouse
		l.Text = Voice.Sorting.objective .. "\n" .. how
		Ease.play(l, Ease.info(0.6, Enum.EasingStyle.Sine), { TextTransparency = 0 })
	else
		hintLeft = 0
		Ease.play(l, Ease.info(0.5, Enum.EasingStyle.Sine), { TextTransparency = 1 })
	end
end

function SortScreen.filed(correct: boolean)
	if hintLeft > 0 and correct then
		hintLeft -= 1
		if hintLeft <= 0 then
			SortScreen.hint(false)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------------------------------

local function pointerMoved(input: InputObject)
	if not isOpen then
		return
	end
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then
		return
	end
	local at = toScreen(input)
	local pr = press
	if pr then
		local same = if t == Enum.UserInputType.Touch then input == pr.input else true
		if same and (at - pr.at).Magnitude > 8 then
			press = nil
			if held ~= pr.uid then
				lift(pr.uid, "drag")
			else
				heldMode = "drag"
				local c = cards[pr.uid]
				if c then
					c.target = c.pos
				end
			end
		end
	end
	if held and heldMode == "drag" then
		local c = cards[held :: number]
		if c and c.state == "held" then
			c.target = at
		end
		setHover(binAt(at))
	elseif held and heldMode == "tap" and t == Enum.UserInputType.MouseMovement then
		setHover(binAt(at))
	end
end

local function pointerUp(input: InputObject)
	if not isOpen then
		return
	end
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
		return
	end
	local at = toScreen(input)
	local pr = press
	if pr then
		press = nil
		-- A tap: with Tap to sort on, it picks the piece up (or puts it back).
		if State.get("tapToSort") == "On" then
			if held == pr.uid then
				release()
			else
				lift(pr.uid, "tap")
			end
		end
		return
	end
	if held and heldMode == "drag" then
		local caseId = binAt(at)
		local uid = held :: number
		if caseId and bins[caseId] and bins[caseId].open then
			SortScreen.onFile(uid, caseId)
		else
			release()
		end
	end
end

local KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

function SortScreen.bind()
	ContextActionService:BindActionAtPriority("MaisonTablePad", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin or not playing then
			return Enum.ContextActionResult.Pass
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.DPadLeft or key == Enum.KeyCode.DPadRight or key == Enum.KeyCode.DPadUp or key == Enum.KeyCode.DPadDown then
			local back = key == Enum.KeyCode.DPadLeft or key == Enum.KeyCode.DPadUp
			if held then
				local step = if back then -1 else 1
				if L.portrait and (key == Enum.KeyCode.DPadUp or key == Enum.KeyCode.DPadDown) then
					step *= L.cols
				end
				padCase = ((padCase - 1 + step) % #binOrder) + 1
				for _, bin in binOrder do
					paintBin(bin)
				end
			elseif key == Enum.KeyCode.DPadUp or key == Enum.KeyCode.DPadDown then
				-- Up and down the cloth to the nearest piece that way.
				local toward = nearestFrom(padIndex, Vector2.new(0, if key == Enum.KeyCode.DPadUp then -1 else 1))
				select(toward or padIndex)
			else
				select(padIndex + (if back then -1 else 1))
			end
			return Enum.ContextActionResult.Sink
		elseif key == Enum.KeyCode.ButtonA then
			if held then
				local bin = binOrder[padCase]
				if bin and bin.open then
					SortScreen.onFile(held :: number, bin.id)
				elseif bin then
					flashBin(bin, CORAL)
				end
			else
				local list = unfiled()
				local c = list[math.clamp(padIndex, 1, math.max(1, #list))]
				if c then
					lift(c.info.uid, "pad")
				end
			end
			return Enum.ContextActionResult.Sink
		elseif key == Enum.KeyCode.ButtonB then
			if held then
				release()
				return Enum.ContextActionResult.Sink
			end
			SortScreen.onCancel()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 2000, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB)

	-- Keys 1 to 6 put the piece you're holding into that case.
	ContextActionService:BindAction("MaisonTableKeys", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin or not held or not playing then
			return Enum.ContextActionResult.Pass
		end
		local n = KEYS[input.KeyCode]
		local case = n and Catalogue.Cases[n]
		if case then
			if bins[case.id] and bins[case.id].open then
				SortScreen.onFile(held :: number, case.id)
			end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six)
end

function SortScreen.unbind()
	ContextActionService:UnbindAction("MaisonTablePad")
	ContextActionService:UnbindAction("MaisonTableKeys")
end

---------------------------------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------------------------------

-- The guide's thread from the held piece to its case, fading in as it appears; sparkles shed by
-- a carried piece in every room.
local function stepTrail(dt: number)
	local heldCard = if held then cards[held :: number] else nil
	local carried = heldCard and heldCard.state == "held" and heldMode == "drag"
	GuideTrail.tick(dt, if carried then (heldCard :: Card).pos else nil, if carried then (heldCard :: Card).vel else nil, L.s)
	local tr = trail
	local c = if tr then cards[tr.uid] else nil
	if not tr or not c or c.state ~= "held" then
		hideTrail()
		return
	end
	local s = L.s
	local to = tr.bin.centre - Vector2.new(0, tr.bin.size.Y * 0.5 - 4 * s)
	local appear = math.clamp((clock - tr.since) / 0.35, 0, 1)
	GuideTrail.draw(dt, c.pos, to, appear, s)
end

local function step(dt: number)
	if not isOpen then
		return
	end
	clock += dt
	local S = Config.data.Sorting
	local k = 1 - math.exp(-S.dragFollow * math.max(dt, 1 / 240))
	local settle = 1 - math.exp(-14 * math.max(dt, 1 / 240))
	local motion = Ease.motionScale
	for _, c in cards do
		if not c.frame then
			continue
		end
		if c.state == "held" then
			local goal = c.target or (c.home - Vector2.new(0, 10 * L.s))
			local nextPos = c.pos:Lerp(goal, k)
			local v = (nextPos - c.pos) / math.max(dt, 1 / 240)
			c.vel = c.vel:Lerp(v, 1 - math.exp(-12 * math.max(dt, 1 / 240)))
			c.pos = nextPos
			c.frame.Rotation = math.clamp(c.vel.X * 0.012, -S.dragTilt, S.dragTilt)
			placeCard(c)
		elseif c.state == "rest" then
			if (c.pos - c.home).Magnitude > 0.5 then
				c.pos = c.pos:Lerp(c.home, settle)
				placeCard(c)
			end
			if math.abs(c.frame.Rotation) > 0.1 then
				c.frame.Rotation *= 0.86
			end
		end
		-- Resting pieces breathe: a slow rise and fall over their shadows.
		if c.art and (c.state == "rest" or c.state == "shaking") then
			local bob = math.sin(clock * (2 * math.pi / 4.8) + c.phase) * 2.2 * L.s * motion
			c.art.Position = UDim2.new(0.5, 0, 0.5, bob)
		end
		local tw = c.twinkle
		if tw then
			local glint = math.max(0, math.sin(clock * 1.9 + c.phase)) ^ 6
			tw.Size = UDim2.fromOffset(L.icon * (0.08 + 0.16 * glint), L.icon * (0.08 + 0.16 * glint))
			tw.Rotation = clock * 40 % 360
		end
	end
	stepTrail(dt)
	local vp = L.vp
	for _, m in motes do
		m.y += m.fall * dt
		if m.y > 1.05 then
			m.y = -0.05
			m.x = (m.x + 0.37) % 1
		elseif m.y < -0.05 then
			m.y = 1.05
			m.x = (m.x + 0.37) % 1
		end
		local x = m.x + math.sin(clock * 0.55 + m.phase) * m.sway
		m.frame.Position = UDim2.fromOffset(x * vp.X, m.y * vp.Y)
		m.frame.Size = UDim2.fromOffset(m.w * L.s, m.h * L.s)
		if m.spin ~= 0 then
			m.frame.Rotation = (clock * m.spin + m.phase * 57) % 360
		end
		if m.blink then
			m.frame.BackgroundTransparency = m.alpha + (1 - m.alpha) * (0.5 + 0.5 * math.sin(clock * 1.3 + m.phase))
		end
	end
end

function SortScreen.start()
	build()
	UserInputService.InputChanged:Connect(pointerMoved)
	UserInputService.InputEnded:Connect(pointerUp)
	RunService.RenderStepped:Connect(step)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if not isOpen then
				return
			end
			measure()
			layoutChrome()
			layoutBins()
			for _, bin in binOrder do
				paintBin(bin)
			end
			arrange(true)
			for _, c in cards do
				if c.state ~= "flying" and c.state ~= "filed" then
					attach(c)
					c.pos = c.home
					placeCard(c)
				end
			end
		end)
	end
end

-- For tests and tools: where a piece and a case are on the screen.
function SortScreen.where(uid: number): Vector2?
	local c = cards[uid]
	return if c then c.pos else nil
end

function SortScreen.caseCentre(caseId: string): Vector2?
	local b = bins[caseId]
	return if b then b.centre else nil
end

return SortScreen
