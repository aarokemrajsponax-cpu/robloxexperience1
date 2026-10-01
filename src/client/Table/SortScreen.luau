--!strict
-- The sorting screen. Sit down at a table and the house falls away: this is all there is. A dark
-- lacquered tray of pieces, each one drawn and named, and the six cases beneath it with their
-- counts. Drag a piece onto its case, or tap it and then the case, or keys 1 to 6, or a gamepad's
-- D-pad and A. A right case takes the piece in with a glint and its points; a wrong one flashes
-- and shakes, and the piece comes home. Everything is laid out by hand from the screen's size, so
-- it fits a phone, a tablet and a monitor alike, and every position is known without asking the
-- engine (which keeps it testable).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Voice = require(ReplicatedStorage.Shared.Voice)
local PieceIcon = require(script.Parent.Parent.UI.PieceIcon)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)

local SortScreen = {}

export type PieceInfo = { uid: number, id: string, name: string, case: string, rare: boolean, mythic: boolean, seasonal: boolean }

type Card = {
	info: PieceInfo,
	frame: Frame,
	scale: UIScale,
	ring: Frame,
	home: Vector2,
	pos: Vector2,
	vel: Vector2,
	target: Vector2?,
	state: "rest" | "held" | "flying" | "shaking" | "filed",
	inCase: string?,
	order: number,
}

type Bin = {
	id: string,
	index: number,
	frame: Frame,
	scale: UIScale,
	stroke: UIStroke,
	flash: Frame,
	count: TextLabel,
	name: TextLabel,
	sub: TextLabel,
	centre: Vector2,
	size: Vector2,
	open: boolean,
	filed: number,
}

local GOLD = Brand.Colours.gold
local LIGHT = Brand.Colours.lightGold
local BONE = Brand.Colours.bone
local SMOKE = Brand.Colours.smoke
local CORAL = Color3.fromRGB(236, 112, 92)
local F = Brand.Fonts

local player = Players.LocalPlayer

-- Callbacks the table sets.
SortScreen.canLift = function(_uid: number): boolean
	return true
end
SortScreen.onLift = function(_uid: number, _mode: string) end
SortScreen.onFile = function(_uid: number, _caseId: string) end
SortScreen.onCancel = function() end

---------------------------------------------------------------------------------------------------
-- The screen
---------------------------------------------------------------------------------------------------

local gui: ScreenGui? = nil
local root: Frame = nil :: any
local piecesLayer: Frame = nil :: any
local casesLayer: Frame = nil :: any
local fxLayer: Frame = nil :: any
local curtain: Frame = nil :: any
local tray: Frame = nil :: any
local header = {} :: { [string]: any }
local leaves: { { frame: Frame, x: number, y: number, speed: number, sway: number, phase: number, spin: number } } = {}

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
	tray: { x: number, y: number, w: number, h: number },
	icon: number,
}
local L: Layout = {
	s = 1,
	vp = Vector2.new(1280, 720),
	pad = 22,
	left = 22,
	width = 1236,
	portrait = false,
	cols = 6,
	gap = 12,
	binH = 116,
	binW = 196,
	headerTop = 8,
	headerH = 64,
	binsTop = 580,
	tray = { x = 0, y = 0, w = 0, h = 0 },
	icon = 96,
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

local function label(parent: Instance, text: string, size: number, font: Font, colour: Color3, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = math.max(10, math.floor(size * Settings.textScale(State.get("textSize")) + 0.5))
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

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
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

local function vgradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
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
	local pad = math.floor(22 * s)
	local width = math.min(vp.X - 2 * pad, math.floor(1480 * s))
	local left = math.floor((vp.X - width) / 2)
	local portrait = vp.X / vp.Y < 1.05
	local cols = if portrait then 3 else 6
	local rows = if portrait then 2 else 1
	local gap = math.floor(12 * s)
	local binH = math.floor((if portrait then 100 else 116) * s)
	local headerTop = top + math.floor(8 * s)
	local headerH = math.floor(64 * s)
	local binsH = rows * binH + (rows - 1) * gap
	local bottom = vp.Y - pad
	local trayTop = headerTop + headerH + math.floor(14 * s)
	local trayBottom = bottom - binsH - math.floor(16 * s)
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
		tray = { x = left, y = trayTop, w = width, h = math.max(120, trayBottom - trayTop) },
		icon = L.icon,
	}
end

---------------------------------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------------------------------

local function makeLeaf(): Frame
	local f = Instance.new("Frame")
	f.Name = "Leaf"
	f.BorderSizePixel = 0
	f.BackgroundColor3 = GOLD
	f.BackgroundTransparency = 0.55
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(f, 6)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 226, 150), Color3.fromRGB(150, 100, 40))
	g.Rotation = 30
	g.Parent = f
	return f
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

	root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BorderSizePixel = 0
	root.BackgroundColor3 = Color3.new(1, 1, 1)
	root.Active = true
	vgradient(root, Color3.fromRGB(30, 22, 13), Color3.fromRGB(8, 8, 11))
	root.Parent = g

	-- A warm pool of light behind the tray, and darker corners.
	local pool = Instance.new("Frame")
	pool.Name = "Pool"
	pool.AnchorPoint = Vector2.new(0.5, 0.5)
	pool.Position = UDim2.fromScale(0.5, 0.42)
	pool.Size = UDim2.fromScale(0.9, 0.7)
	pool.BorderSizePixel = 0
	pool.BackgroundColor3 = Color3.fromRGB(120, 84, 40)
	pool.BackgroundTransparency = 0.88
	corner(pool, 9999)
	pool.Parent = root
	for _, side in { 0, 180 } do
		local v = Instance.new("Frame")
		v.Name = "Vignette"
		v.Size = UDim2.fromScale(0.22, 1)
		v.Position = UDim2.fromScale(if side == 0 then 0 else 0.78, 0)
		v.BorderSizePixel = 0
		v.BackgroundColor3 = Color3.new(0, 0, 0)
		local vg = Instance.new("UIGradient")
		vg.Rotation = side
		vg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		vg.Parent = v
		v.Parent = root
	end

	-- The tray
	tray = Instance.new("Frame")
	tray.Name = "Tray"
	tray.BorderSizePixel = 0
	tray.BackgroundColor3 = Color3.new(1, 1, 1)
	vgradient(tray, Color3.fromRGB(24, 22, 22), Color3.fromRGB(10, 10, 13))
	tray.Parent = root
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Parent = tray
	header.trayStroke = stroke(tray, GOLD, 0.55, 1)
	header.innerStroke = stroke(inner, GOLD, 0.78, 1)
	header.trayInner = inner
	header.trayCorner = Instance.new("UICorner")
	header.trayCorner.Parent = tray
	local innerCorner = Instance.new("UICorner")
	innerCorner.Parent = inner
	header.innerCorner = innerCorner

	-- Gold leaf drifting down through it all, very slowly.
	local leafLayer = Instance.new("Frame")
	leafLayer.Name = "Leaves"
	leafLayer.BackgroundTransparency = 1
	leafLayer.Size = UDim2.fromScale(1, 1)
	leafLayer.Parent = root
	leaves = {}
	for i = 1, 9 do
		local f = makeLeaf()
		f.Parent = leafLayer
		table.insert(leaves, { frame = f, x = (i * 0.137) % 1, y = (i * 0.291) % 1, speed = 0.012 + (i % 4) * 0.004, sway = 0.01 + (i % 3) * 0.006, phase = i * 1.7, spin = 20 + (i % 5) * 9 })
	end

	-- Header: the room, the score, the multiplier, the clock.
	local head = Instance.new("Frame")
	head.Name = "Header"
	head.BackgroundTransparency = 1
	head.Parent = root
	header.frame = head
	header.room = label(head, "", 13, F.bodyMedium, GOLD, { AnchorPoint = Vector2.new(0, 0.5), TextXAlignment = Enum.TextXAlignment.Left })
	header.round = label(head, "", 11, F.bodyMedium, SMOKE, { AnchorPoint = Vector2.new(0, 0.5), TextXAlignment = Enum.TextXAlignment.Left })
	header.score = label(head, "0", 36, F.light, LIGHT)
	header.scoreLabel = label(head, Theme.track("POINTS"), 10, F.bodyMedium, SMOKE)
	local chip = Instance.new("Frame")
	chip.Name = "Multiplier"
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.BackgroundColor3 = GOLD
	chip.BackgroundTransparency = 0.82
	chip.Parent = head
	corner(chip, 999)
	header.chipStroke = stroke(chip, GOLD, 0.2, 1)
	header.chip = chip
	header.chipScale = Instance.new("UIScale")
	header.chipScale.Parent = chip
	header.mult = label(chip, "×1", 16, F.bodyMedium, LIGHT, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5) })
	header.clockText = label(head, "", 15, F.bodyMedium, BONE, { AnchorPoint = Vector2.new(1, 0.5), TextXAlignment = Enum.TextXAlignment.Right })
	local rail = Instance.new("Frame")
	rail.Name = "Clock"
	rail.BorderSizePixel = 0
	rail.BackgroundColor3 = Color3.fromRGB(40, 34, 24)
	rail.Visible = false
	rail.Parent = root
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = GOLD
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = rail
	header.rail = rail
	header.railFill = fill

	-- The hint, the first times you sit; your rival's line at the foot of the tray.
	header.hint = label(root, "", 15, F.body, SMOKE, { Name = "Hint", TextTransparency = 1, TextWrapped = true })
	header.rival = label(root, "", 13, F.bodyMedium, SMOKE, { Name = "Rival", TextTransparency = 1 })

	piecesLayer = Instance.new("Frame")
	piecesLayer.Name = "Pieces"
	piecesLayer.BackgroundTransparency = 1
	piecesLayer.Size = UDim2.fromScale(1, 1)
	piecesLayer.Parent = root
	casesLayer = Instance.new("Frame")
	casesLayer.Name = "Cases"
	casesLayer.BackgroundTransparency = 1
	casesLayer.Size = UDim2.fromScale(1, 1)
	casesLayer.ZIndex = 1
	casesLayer.Parent = root
	piecesLayer.ZIndex = 2
	fxLayer = Instance.new("Frame")
	fxLayer.Name = "Effects"
	fxLayer.BackgroundTransparency = 1
	fxLayer.Size = UDim2.fromScale(1, 1)
	fxLayer.ZIndex = 3
	fxLayer.Parent = root

	curtain = Instance.new("Frame")
	curtain.Name = "Curtain"
	curtain.Size = UDim2.fromScale(1, 1)
	curtain.BorderSizePixel = 0
	curtain.BackgroundColor3 = Color3.new(0, 0, 0)
	curtain.BackgroundTransparency = 1
	curtain.ZIndex = 10
	curtain.Parent = g
end

local function layoutChrome()
	local s = L.s
	local t = L.tray
	tray.Position = UDim2.fromOffset(t.x, t.y)
	tray.Size = UDim2.fromOffset(t.w, t.h)
	header.trayCorner.CornerRadius = UDim.new(0, math.floor(8 * s))
	local insetPx = math.floor(8 * s)
	header.trayInner.Size = UDim2.new(1, -2 * insetPx, 1, -2 * insetPx)
	header.innerCorner.CornerRadius = UDim.new(0, math.floor(5 * s))
	local head = header.frame :: Frame
	head.Position = UDim2.fromOffset(L.left, L.headerTop)
	head.Size = UDim2.fromOffset(L.width, L.headerH)
	local mid = L.headerH / 2
	header.room.Position = UDim2.fromOffset(0, mid - 9 * s)
	header.round.Position = UDim2.fromOffset(0, mid + 11 * s)
	header.room.Size = UDim2.fromOffset(L.width * 0.3, 18 * s)
	header.round.Size = UDim2.fromOffset(L.width * 0.3, 16 * s)
	header.score.Position = UDim2.fromOffset(L.width / 2, mid - 6 * s)
	header.score.Size = UDim2.fromOffset(240 * s, 40 * s)
	header.scoreLabel.Position = UDim2.fromOffset(L.width / 2, mid + 20 * s)
	header.scoreLabel.Size = UDim2.fromOffset(200 * s, 14 * s)
	local chip = header.chip :: Frame
	chip.Position = UDim2.fromOffset(L.width / 2 + 110 * s, mid - 6 * s)
	chip.Size = UDim2.fromOffset(56 * s, 28 * s)
	-- The clock: keys sit in the top-right corner, so its seconds sit left of centre's chip.
	header.clockText.Position = UDim2.fromOffset(L.width / 2 - 110 * s, mid - 6 * s)
	header.clockText.Size = UDim2.fromOffset(90 * s, 24 * s)
	local rail = header.rail :: Frame
	rail.Position = UDim2.fromOffset(L.left, L.headerTop + L.headerH + math.floor(4 * s))
	rail.Size = UDim2.fromOffset(L.width, math.max(2, math.floor(3 * s)))
	local hint = header.hint :: TextLabel
	hint.Position = UDim2.fromOffset(L.vp.X / 2, t.y + 22 * s)
	hint.Size = UDim2.fromOffset(t.w - 40 * s, 22 * s)
	local rival = header.rival :: TextLabel
	rival.Position = UDim2.fromOffset(L.vp.X / 2, t.y + t.h - 16 * s)
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
	vgradient(f, Color3.fromRGB(26, 22, 18), Color3.fromRGB(14, 13, 14))
	corner(f, math.floor(6 * s))
	local st = stroke(f, GOLD, 0.72, 1)
	local scale = Instance.new("UIScale")
	scale.Parent = f
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BorderSizePixel = 0
	flash.BackgroundColor3 = GOLD
	flash.BackgroundTransparency = 1
	corner(flash, math.floor(6 * s))
	flash.Parent = f
	local mark = Instance.new("Frame")
	mark.Name = "MarkHolder"
	mark.BackgroundTransparency = 1
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.4, 0.3)
	local markPx = math.floor(L.binH * 0.34)
	mark.Size = UDim2.fromOffset(markPx, markPx)
	mark.Parent = f
	PieceIcon.case(mark, case.id, markPx)
	local count = label(f, "0", 24, F.light, GOLD, { Position = UDim2.fromScale(0.62, 0.28), Size = UDim2.fromScale(0.3, 0.3), Name = "Count" })
	local name = label(f, Theme.track(string.upper(case.name)), 15, F.bodyMedium, BONE, { Position = UDim2.fromScale(0.5, 0.63), Size = UDim2.fromScale(1, 0.2), Name = "Title" })
	local sub = label(f, case.subtitle, 12, F.body, SMOKE, { Position = UDim2.fromScale(0.5, 0.83), Size = UDim2.fromScale(1, 0.16), Name = "Sub" })
	f.Parent = casesLayer
	return {
		id = case.id,
		index = index,
		frame = f,
		scale = scale,
		stroke = st,
		flash = flash,
		count = count,
		name = name,
		sub = sub,
		centre = Vector2.zero,
		size = Vector2.zero,
		open = true,
		filed = 0,
	}
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
	Ease.play(bin.stroke, Ease.info(0.12, Enum.EasingStyle.Quad), { Transparency = if lit then 0 elseif bin.open then 0.72 else 0.9, Thickness = if lit then 2 else 1 })
	Ease.play(bin.flash, Ease.info(0.12, Enum.EasingStyle.Quad), { BackgroundTransparency = if lit then 0.86 else 1 })
	Ease.play(bin.scale, Ease.info(0.16, Enum.EasingStyle.Quad), { Scale = if lit then 1.035 else 1 })
	local dim = if bin.open then 0 else 0.55
	bin.name.TextTransparency = dim
	bin.count.TextTransparency = dim
	bin.sub.TextTransparency = dim
	bin.sub.Text = if bin.open then (Catalogue.caseById[bin.id] :: Catalogue.Case).subtitle else "Closed this round"
	local mark = bin.frame:FindFirstChild("MarkHolder")
	if mark and mark:IsA("GuiObject") then
		mark.Visible = bin.open
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

-- Where each piece rests: a loose grid over the tray with a little scatter, as if set down by hand.
local function arrange()
	local list = unfiled()
	local n = #list
	if n == 0 then
		return
	end
	local t = L.tray
	local s = L.s
	local top = t.y + 46 * s
	local w, h = t.w - 40 * s, t.h - 56 * s
	local cell = math.sqrt((w * h) / n)
	local cols = math.max(1, math.min(n, math.floor(w / cell + 0.5)))
	local rows = math.ceil(n / cols)
	local cw, ch = w / cols, h / rows
	local icon = math.floor(math.clamp(math.min(cw * 0.7, ch * 0.62), 50 * s, 118 * s) * Settings.pieceScale(State.get("pieceSize")))
	L.icon = icon
	for i, c in list do
		local col = (i - 1) % cols
		local row = (i - 1) // cols
		local inRow = math.min(cols, n - row * cols)
		local offset = (cols - inRow) * cw / 2
		local rng = Random.new(c.info.uid * 7919 + dealCount)
		local jx = (rng:NextNumber() - 0.5) * math.max(0, cw - icon) * 0.7
		local jy = (rng:NextNumber() - 0.5) * math.max(0, ch - icon * 1.3) * 0.7
		c.home = Vector2.new(t.x + 20 * s + offset + (col + 0.5) * cw + jx, top + (row + 0.5) * ch + jy)
		c.order = i
	end
end

local function cardFrame(info: PieceInfo, icon: number): (Frame, UIScale, Frame)
	local s = L.s
	local f = Instance.new("Frame")
	f.Name = "Piece"
	f:SetAttribute("Uid", info.uid)
	f:SetAttribute("PieceId", info.id)
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(icon * 1.5, icon * 1.32)
	f.Active = true
	local scale = Instance.new("UIScale")
	scale.Parent = f
	-- A gilded or Mythic piece has a soft glow of light about it.
	if info.rare or info.mythic then
		-- A warm halo: soft rings of gold light, brightest close in.
		for k, size in { 1.5, 1.25, 1.02 } do
			local glow = Instance.new("Frame")
			glow.Name = "Glow"
			glow.AnchorPoint = Vector2.new(0.5, 0.5)
			glow.Position = UDim2.new(0.5, 0, 0, icon * 0.5)
			glow.Size = UDim2.fromOffset(icon * size, icon * size)
			glow.BorderSizePixel = 0
			glow.BackgroundColor3 = if info.mythic then Color3.fromRGB(255, 214, 130) else Color3.fromRGB(226, 176, 86)
			glow.BackgroundTransparency = 0.955 - k * 0.012
			corner(glow, 9999)
			glow.Parent = f
		end
	end
	local ring = Instance.new("Frame")
	ring.Name = "Selected"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(0.5, 0, 0, icon * 0.5)
	ring.Size = UDim2.fromOffset(icon * 1.12, icon * 1.12)
	ring.BackgroundColor3 = LIGHT
	ring.BackgroundTransparency = 0.9
	ring.Visible = false
	corner(ring, 9999)
	stroke(ring, LIGHT, 0, 2)
	ring.Parent = f
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0, icon * 0.96)
	shadow.Size = UDim2.fromOffset(icon * 0.7, icon * 0.13)
	shadow.BorderSizePixel = 0
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.35
	corner(shadow, 9999)
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
	sg.Parent = shadow
	shadow.Parent = f
	local art = Instance.new("Frame")
	art.Name = "Icon"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.fromScale(0.5, 0)
	art.Size = UDim2.fromOffset(icon, icon)
	art.Parent = f
	PieceIcon.piece(art, info.id, icon, info.case)
	if names then
		label(f, info.name, 14 * s, F.bodyMedium, if info.mythic or info.rare then LIGHT else BONE, {
			Name = "Name",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, icon * 1.04),
			Size = UDim2.new(1.4, 0, 0, 18 * s),
			TextStrokeTransparency = 0.6,
			TextStrokeColor3 = Color3.new(0, 0, 0),
		})
	end
	f.Parent = piecesLayer
	return f, scale, ring
end

local function placeCard(c: Card)
	if c.frame then
		c.frame.Position = UDim2.fromOffset(c.pos.X, c.pos.Y)
	end
end

local function select(index: number?)
	for _, c in cards do
		c.ring.Visible = false
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
		list[padIndex].ring.Visible = true
	end
end

local function lifted(c: Card, on: boolean)
	Ease.play(c.scale, Ease.info(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if on then 1.14 else 1 })
	local shadow = c.frame:FindFirstChild("Shadow")
	if shadow and shadow:IsA("Frame") then
		Ease.play(shadow, Ease.info(0.16, Enum.EasingStyle.Quad), { BackgroundTransparency = if on then 0.6 else 0.35, Position = UDim2.new(0.5, 0, 0, L.icon * (if on then 1.12 else 0.96)) })
	end
	c.frame.ZIndex = if on then 5 else 2
end

-- The guide: in the rooms that have one, the right case glows softly while a piece is held.
local function showGuide(uid: number?)
	if guideThread then
		pcall(task.cancel, guideThread)
		guideThread = nil
	end
	for _, bin in binOrder do
		local g = bin.frame:FindFirstChild("Guide")
		if g then
			g:Destroy()
		end
	end
	if uid == nil or guide == "none" then
		return
	end
	local c = cards[uid]
	local bin = c and bins[c.info.case]
	if not bin then
		return
	end
	local b = bin
	guideThread = task.delay(if guide == "delayed" then guideDelay else 0, function()
		guideThread = nil
		if held ~= uid then
			return
		end
		local glow = Instance.new("Frame")
		glow.Name = "Guide"
		glow.Size = UDim2.fromScale(1, 1)
		glow.BorderSizePixel = 0
		glow.BackgroundColor3 = LIGHT
		glow.BackgroundTransparency = 1
		corner(glow, math.floor(6 * L.s))
		glow.Parent = b.frame
		Ease.play(glow, Ease.info(0.5, Enum.EasingStyle.Sine), { BackgroundTransparency = 0.9 })
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
	lifted(c, true)
	select(nil)
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

-- (Re)builds a card's frame at the current piece size and wires its input.
local function attach(c: Card)
	local old = c.frame
	local frame, scale, ring = cardFrame(c.info, L.icon)
	if old then
		frame.Position = old.Position
		frame.Visible = old.Visible
		old:Destroy()
	end
	c.frame = frame
	c.scale = scale
	c.ring = ring
	local uid = c.info.uid
	frame.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and playing then
			press = { uid = uid, at = toScreen(input), input = input }
		end
	end)
	frame.MouseEnter:Connect(function()
		if held == nil and c.state == "rest" and playing then
			Ease.play(scale, Ease.info(0.14, Enum.EasingStyle.Quad), { Scale = 1.06 })
		end
	end)
	frame.MouseLeave:Connect(function()
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
	holder.Size = UDim2.fromOffset(320 * s, 90 * s)
	holder.ZIndex = 6
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
			Size = UDim2.new(1, 0, 0, math.floor(spec.size * s * 1.3)),
			TextStrokeTransparency = 0.45,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			ZIndex = 6,
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
		local p = Instance.new("Frame")
		p.Name = "Spark"
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.fromOffset(at.X, at.Y)
		p.Size = UDim2.fromOffset(5 * s, 9 * s)
		p.BorderSizePixel = 0
		p.BackgroundColor3 = colour
		p.ZIndex = 6
		corner(p, 9999)
		p.Parent = fxLayer
		local ang = (i / count) * math.pi * 2 + math.random() * 0.4
		local dist = (40 + math.random() * 40) * s
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
	bin.flash.BackgroundTransparency = 0.55
	Ease.play(bin.flash, Ease.info(0.55, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
	bin.stroke.Color = colour
	bin.stroke.Transparency = 0
	local t = Ease.play(bin.stroke, Ease.info(0.6, Enum.EasingStyle.Sine), { Transparency = if bin.open then 0.72 else 0.9 })
	t.Completed:Once(function()
		bin.stroke.Color = GOLD
	end)
end

-- Into its case: the piece flies down, shrinks into the case, and the case counts it.
local function flyIn(c: Card, bin: Bin, quiet: boolean)
	c.state = "flying"
	c.target = nil
	if held == c.info.uid then
		held = nil
		heldMode = nil
	end
	local goal = bin.centre - Vector2.new(0, bin.size.Y * 0.2)
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
		bin.filed += 1
		bin.count.Text = tostring(bin.filed)
		if not quiet then
			bin.scale.Scale = 1.08
			Ease.play(bin.scale, Ease.info(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if hoverBin == bin.id then 1.035 else 1 })
			flashBin(bin, LIGHT)
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
		end
	end
	if shakeFirst and Ease.motionScale >= 0.5 then
		c.state = "shaking" -- held still while it shakes
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

function SortScreen.open(roomName: string, roundText: string)
	build()
	measure()
	layoutChrome()
	buildBins()
	header.room.Text = Theme.track(string.upper(roomName))
	header.round.Text = Theme.track(string.upper(roundText))
	if isOpen then
		return
	end
	isOpen = true
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
	header.room.Text = Theme.track(string.upper(roomName))
	header.round.Text = Theme.track(string.upper(roundText))
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

-- A new deal: the tray clears and the pieces are laid out one after another.
function SortScreen.deal(list: { PieceInfo })
	SortScreen.clear()
	dealCount += 1
	for _, bin in binOrder do
		bin.filed = 0
		bin.count.Text = "0"
	end
	SortScreen.add(list, true)
end

-- Pieces arriving (a deal, a parcel): every unfiled piece makes room and the new ones settle in.
function SortScreen.add(list: { PieceInfo }, fromDeal: boolean?)
	if not gui then
		return
	end
	local before = L.icon
	local fresh: { Card } = {}
	for _, info in list do
		local c: Card = {
			info = info,
			frame = nil :: any,
			scale = nil :: any,
			ring = nil :: any,
			home = Vector2.zero,
			pos = Vector2.zero,
			vel = Vector2.zero,
			target = nil,
			state = "rest",
			order = 100000 + info.uid,
		}
		cards[info.uid] = c
		table.insert(fresh, c)
	end
	arrange()
	-- Pieces already on the tray take the new size if the layout changed it.
	if math.abs(before - L.icon) > 1 then
		for _, c in cards do
			if c.frame and c.state ~= "flying" and table.find(fresh, c) == nil then
				attach(c)
			end
		end
	end
	for i, c in fresh do
		attach(c)
		c.pos = c.home - Vector2.new(0, 40 * L.s)
		placeCard(c)
		c.scale.Scale = 0.55
		c.frame.Visible = false
		task.delay((i - 1) * (if fromDeal then 0.045 else 0.06), function()
			if cards[c.info.uid] ~= c then
				return
			end
			c.frame.Visible = true
			Ease.play(c.scale, Ease.info(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		end)
	end
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
	if fxLayer then
		fxLayer:ClearAllChildren()
	end
	for _, bin in binOrder do
		paintBin(bin)
	end
end

function SortScreen.heldUid(): number?
	return held
end

-- A right case.
function SortScreen.correct(uid: number, caseId: string, points: number?, multiplier: number?)
	local c = cards[uid]
	local bin = bins[caseId]
	if not c or not bin then
		return
	end
	showGuide(nil)
	setHover(nil)
	flyIn(c, bin, false)
	local lines = { { text = Theme.track(string.upper(Voice.Sorting.correct)), size = 20, font = F.bodyBold, colour = LIGHT } }
	if points and points > 0 then
		local sub = "+" .. number(points)
		if multiplier and multiplier > 1 then
			sub ..= "   ×" .. tostring(multiplier)
		end
		table.insert(lines, { text = sub, size = 18, font = F.light, colour = BONE })
	end
	popText(bin.centre - Vector2.new(0, bin.size.Y * 0.55), lines, false)
	select(padIndex)
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
		local lines = {
			{ text = Theme.track(string.upper(Voice.Sorting.wrong)), size = 19, font = F.bodyBold, colour = CORAL },
			{ text = Voice.Sorting.tryAgain, size = 15, font = F.bodyMedium, colour = BONE },
		}
		if lostStreak >= 2 then
			table.insert(lines, { text = (string.gsub(Voice.Sorting.streakLost, "{n}", tostring(lostStreak))), size = 13, font = F.body, colour = SMOKE })
		end
		if penalty and penalty > 0 then
			table.insert(lines, { text = "−" .. number(penalty), size = 16, font = F.light, colour = CORAL })
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
		return
	end
	goHome(c, false)
end

function SortScreen.setScore(score: number, multiplier: number)
	if not gui then
		return
	end
	local before = header.mult.Text
	header.score.Text = number(score)
	header.score.TextSize = math.floor(36 * L.s)
	header.scoreLabel.Text = Theme.track("POINTS")
	header.mult.Text = "×" .. tostring(multiplier)
	header.chip.Visible = true
	if before ~= header.mult.Text and multiplier > 1 then
		header.chipScale.Scale = 1.25
		Ease.play(header.chipScale, Ease.info(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	end
end

-- The Library and the Ballroom count pieces, not points.
function SortScreen.setLine(text: string, caption: string)
	if not gui then
		return
	end
	header.score.Text = text
	header.score.TextSize = math.floor(26 * L.s)
	header.scoreLabel.Text = Theme.track(string.upper(caption))
	header.chip.Visible = false
end

function SortScreen.setClock(left: number?, budget: number?)
	if not gui then
		return
	end
	local rail = header.rail :: Frame
	if left == nil or budget == nil or budget <= 0 then
		rail.Visible = false
		header.clockText.Text = ""
		return
	end
	rail.Visible = true
	local fraction = math.clamp(left / budget, 0, 1)
	local fill = header.railFill :: Frame
	fill.Size = UDim2.fromScale(fraction, 1)
	local low = left <= 10
	fill.BackgroundColor3 = if low then CORAL else GOLD
	header.clockText.Text = string.format("%d:%02d", math.floor(math.ceil(left) / 60), math.ceil(left) % 60)
	header.clockText.TextColor3 = if low then CORAL else BONE
end

-- A streak called out over the tray.
function SortScreen.streak(n: number, multiplier: number)
	if not gui then
		return
	end
	local s = L.s
	-- Just under the score, over the tray's top edge, clear of the pieces.
	local at = Vector2.new(L.vp.X / 2, L.tray.y + 8 * s)
	local holder = Instance.new("Frame")
	holder.Name = "Streak"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(at.X, at.Y)
	holder.Size = UDim2.fromOffset(360 * s, 70 * s)
	holder.BorderSizePixel = 0
	holder.BackgroundColor3 = Color3.fromRGB(14, 12, 10)
	holder.BackgroundTransparency = 0.12
	holder.ZIndex = 7
	corner(holder, math.floor(8 * s))
	stroke(holder, GOLD, 0.3, 1)
	holder.Parent = fxLayer
	local scale = Instance.new("UIScale")
	scale.Scale = 0.8
	scale.Parent = holder
	local title = string.gsub(Voice.Sorting.inARow, "{n}", tostring(n))
	local line = Voice.Sorting.moments[n] or string.gsub(Voice.Sorting.multiplier, "{n}", tostring(multiplier))
	local t1 = label(holder, Theme.track(string.upper(title)), 14 * s, F.bodyMedium, GOLD, { Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromScale(1, 0.34), ZIndex = 7 })
	local t2 = label(holder, line, 22 * s, F.display, BONE, { Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromScale(1, 0.4), ZIndex = 7 })
	Ease.play(scale, Ease.info(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	task.delay(1.4, function()
		if not holder.Parent then
			return
		end
		Ease.play(holder, Ease.info(0.4, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
		Ease.play(t1, Ease.info(0.4, Enum.EasingStyle.Sine), { TextTransparency = 1 })
		Ease.play(t2, Ease.info(0.4, Enum.EasingStyle.Sine), { TextTransparency = 1 })
		local st = holder:FindFirstChildOfClass("UIStroke")
		if st then
			Ease.play(st, Ease.info(0.4, Enum.EasingStyle.Sine), { Transparency = 1 })
		end
		task.delay(0.45, function()
			holder:Destroy()
		end)
	end)
end

-- Your rival on tonight's table, at the foot of the tray (gold once you're ahead).
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
	arrange()
	for _, c in cards do
		if c.state ~= "flying" then
			attach(c)
			placeCard(c)
		end
	end
	select(padIndex)
end

-- The line at the top of the tray, the first times you sit.
local hintLeft = 0
function SortScreen.hint(on: boolean)
	if not gui then
		return
	end
	local l = header.hint :: TextLabel
	if on then
		hintLeft = Config.data.Sorting.hintFilings
		local how = (Voice.Sorting.hints :: any)[State.inputKind()] or Voice.Sorting.hints.mouse
		l.Text = Voice.Sorting.objective .. "   ·   " .. how
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
			local step = if key == Enum.KeyCode.DPadLeft or key == Enum.KeyCode.DPadUp then -1 else 1
			if held then
				padCase = ((padCase - 1 + step) % #binOrder) + 1
				for _, bin in binOrder do
					paintBin(bin)
				end
			else
				select(padIndex + step)
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

-- Every frame: a held piece closes on the pointer on a short spring and leans into its
-- movement; pieces whose place moved settle into it; the gold leaf drifts.
local clock = 0
local function step(dt: number)
	if not isOpen then
		return
	end
	clock += dt
	local S = Config.data.Sorting
	local k = 1 - math.exp(-S.dragFollow * math.max(dt, 1 / 240))
	local settle = 1 - math.exp(-14 * math.max(dt, 1 / 240))
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
				c.frame.Rotation *= 0.8
			end
		end
	end
	local vp = L.vp
	for _, leaf in leaves do
		leaf.y += leaf.speed * dt
		if leaf.y > 1.05 then
			leaf.y = -0.05
		end
		local x = leaf.x + math.sin(clock * 0.5 + leaf.phase) * leaf.sway
		leaf.frame.Position = UDim2.fromOffset(x * vp.X, leaf.y * vp.Y)
		leaf.frame.Size = UDim2.fromOffset(9 * L.s, 5 * L.s)
		leaf.frame.Rotation = (clock * leaf.spin + leaf.phase * 40) % 360
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
			arrange()
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
