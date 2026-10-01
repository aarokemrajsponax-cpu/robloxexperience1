--!strict
-- Draws a piece's illustration (or a case's line mark) from Shared.PieceArt: rounded boxes,
-- circles and rings with gradients and outlines, all built from Frames, so nothing needs to be
-- uploaded. `px` is the drawn size in pixels (outline thickness and engraved text scale with it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local PieceArt = require(ReplicatedStorage.Shared.PieceArt) :: any

local PieceIcon = {}

type Prim = { [string]: any }
type Area = { number } -- x0, y0, width, height on the 100 x 100 canvas

local CANVAS: Area = { 0, 0, 100, 100 }

local function colour(s: { number }): Color3
	return Color3.fromRGB(s[2], s[3], s[4])
end

local function sequence(st: { { number } }): ColorSequence
	local points = {}
	for _, s in st do
		table.insert(points, ColorSequenceKeypoint.new(math.clamp(s[1], 0, 1), colour(s)))
	end
	return ColorSequence.new(points)
end

local function flat(st: { { number } }): boolean
	local first = st[1]
	for _, s in st do
		if s[2] ~= first[2] or s[3] ~= first[3] or s[4] ~= first[4] then
			return false
		end
	end
	return true
end

local function fills(object: GuiObject | UIStroke, st: { { number } }, rotation: number, ga: { { number } }?)
	local needGradient = not flat(st) or ga ~= nil
	if object:IsA("UIStroke") then
		object.Color = if needGradient then Color3.new(1, 1, 1) else colour(st[1])
	else
		(object :: GuiObject).BackgroundColor3 = if needGradient then Color3.new(1, 1, 1) else colour(st[1])
	end
	if needGradient then
		local g = Instance.new("UIGradient")
		g.Color = if flat(st) then ColorSequence.new(colour(st[1])) else sequence(st)
		g.Rotation = rotation
		if ga then
			local points = {}
			for _, p in ga do
				table.insert(points, NumberSequenceKeypoint.new(math.clamp(p[1], 0, 1), math.clamp(p[2], 0, 1)))
			end
			g.Transparency = NumberSequence.new(points)
		end
		g.Parent = object
	end
end

local drawAll: (parent: GuiObject, prims: { Prim }, px: number, area: Area) -> ()

local function place(object: GuiObject, p: Prim, area: Area)
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Position = UDim2.fromScale((p.x - area[1]) / area[3], (p.y - area[2]) / area[4])
	object.Size = UDim2.fromScale(p.w / area[3], p.h / area[4])
end

local function box(parent: GuiObject, p: Prim, px: number, area: Area)
	local holder: GuiObject = parent
	local a = area
	if p.clip then
		-- A window that shows only part of the shape (how triangles and half-rings are made).
		local c = p.clip
		local window = Instance.new("Frame")
		window.Name = "Clip"
		window.BackgroundTransparency = 1
		window.ClipsDescendants = true
		window.Position = UDim2.fromScale((c[1] - area[1]) / area[3], (c[2] - area[2]) / area[4])
		window.Size = UDim2.fromScale((c[3] - c[1]) / area[3], (c[4] - c[2]) / area[4])
		window.Parent = parent
		holder = window
		a = { c[1], c[2], c[3] - c[1], c[4] - c[2] }
	end
	local f = Instance.new("Frame")
	f.Name = "Shape"
	f.BorderSizePixel = 0
	place(f, p, a)
	f.Rotation = p.r or 0
	if p.fill then
		fills(f, p.fill, p.g or 90, p.ga)
		f.BackgroundTransparency = p.a or 0
	else
		f.BackgroundTransparency = 1
	end
	if (p.cr or 0) > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(p.cr, 0)
		corner.Parent = f
	end
	if p.s then
		local s = p.s
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Thickness = math.max(0.6, s.th * px / 100)
		stroke.Transparency = s.a or 0
		fills(stroke, s.fill, s.g or 90, nil)
		stroke.Parent = f
	end
	f.Parent = holder
end

local function text(parent: GuiObject, p: Prim, px: number, area: Area)
	local l = Instance.new("TextLabel")
	l.Name = "Engraving"
	l.BackgroundTransparency = 1
	place(l, p, area)
	l.Text = p.text
	l.TextSize = math.max(6, p.size * px / 100)
	l.FontFace = if p.font == "serif" then Brand.Fonts.serif else Brand.Fonts.bodyBold
	l.TextColor3 = colour(p.fill[1])
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
end

drawAll = function(parent: GuiObject, prims: { Prim }, px: number, area: Area)
	for _, p in prims do
		if p.t == "group" then
			local g = Instance.new("Frame")
			g.Name = "Group"
			g.BackgroundTransparency = 1
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.Position = UDim2.fromScale(0.5, 0.5)
			g.Size = UDim2.fromScale(1, 1)
			g.Rotation = p.r or 0
			g.Parent = parent
			drawAll(g, p.kids, px, CANVAS)
		elseif p.t == "text" then
			text(parent, p, px, area)
		else
			box(parent, p, px, area)
		end
	end
end

local function canvas(name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	return f
end

-- A piece's illustration, filling `parent`. Unknown pieces get their case's mark.
function PieceIcon.piece(parent: GuiObject, pieceId: string, px: number, fallbackCase: string?): Frame
	local f = canvas("Art")
	local prims = PieceArt.pieces[pieceId] or (if fallbackCase then PieceArt.cases[fallbackCase] else nil) or {}
	drawAll(f, prims, px, CANVAS)
	f.Parent = parent
	return f
end

-- A case's thin gold line mark.
function PieceIcon.case(parent: GuiObject, caseId: string, px: number): Frame
	local f = canvas("Mark")
	drawAll(f, PieceArt.cases[caseId] or {}, px, CANVAS)
	f.Parent = parent
	return f
end

function PieceIcon.has(pieceId: string): boolean
	return PieceArt.pieces[pieceId] ~= nil
end

return PieceIcon
