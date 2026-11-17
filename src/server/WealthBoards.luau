--!strict
-- (Build 93) The Wealthiest boards in the Foyer, high on the back wall either side of the Grand
-- Stair, in sight of everyone who comes through the front door:
--   * In this house now: every guest in this server who shows their Fortune, by the Fortune
--     they've earned (server/Fortune.here);
--   * Of all time: the Wealthiest board every server shares (server/Fortune.top).
-- Earned Fortune only, on both: Gilt and Gems bought with Robux are left out, so the top of
-- either can't be bought, and a guest who turns "Show my Fortune" off is on neither. Written by
-- the server for everyone (a SurfaceGui on each board's face), only when what's on it changes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local FortuneRules = require(ReplicatedStorage.Shared.Fortune)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Fortune = require(script.Parent.Fortune)

local WealthBoards = {}

WealthBoards.ROWS = 7
WealthBoards.EVERY = 5 -- seconds between looks at what's on them

local C = Brand.Colours
local drawn: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any

local function label(parent: Instance, order: number, text: string, height: number, font: Font, colour: Color3, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, height, 0)
	l.FontFace = font
	l.TextScaled = true
	l.TextColor3 = colour
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Text = text
	l.Parent = parent
	return l
end

local function row(parent: Instance, order: number, rank: number, name: string, score: number)
	local r = Instance.new("Frame")
	r.Name = "Row" .. rank
	r.LayoutOrder = order
	r.BackgroundColor3 = if rank == 1 then C.deepGold else Color3.fromRGB(255, 255, 255)
	r.BackgroundTransparency = if rank == 1 then 0.78 else 0.96
	r.BorderSizePixel = 0
	r.Size = UDim2.new(1, 0, 0.085, 0)
	r.Parent = parent
	local left = Instance.new("TextLabel")
	left.Name = "Name"
	left.BackgroundTransparency = 1
	left.Position = UDim2.fromScale(0.03, 0.1)
	left.Size = UDim2.fromScale(0.64, 0.8)
	left.FontFace = Brand.Fonts.display
	left.TextScaled = true
	left.TextXAlignment = Enum.TextXAlignment.Left
	left.TextColor3 = if rank == 1 then C.lightGold else C.bone
	left.Text = Voice.roman(rank) .. "   " .. name
	left.Parent = r
	local right = Instance.new("TextLabel")
	right.Name = "Fortune"
	right.BackgroundTransparency = 1
	right.Position = UDim2.fromScale(0.67, 0.1)
	right.Size = UDim2.fromScale(0.3, 0.8)
	right.FontFace = Brand.Fonts.bodyBold
	right.TextScaled = true
	right.TextXAlignment = Enum.TextXAlignment.Right
	right.TextColor3 = if rank == 1 then C.lightGold else C.smoke
	right.Text = FortuneRules.short(score)
	right.Parent = r
end

-- What a board says: its title, its line, its rows (or why it has none).
type Page = { kind: string, subtitle: string, entries: { Fortune.Entry }, empty: string }

function WealthBoards.page(kind: string): Page
	if kind == "wealthHere" then
		local here = {}
		for _, e in Fortune.here() do
			if e.score > 0 then
				table.insert(here, e)
			end
		end
		return { kind = kind, subtitle = "In this house now", entries = here, empty = "Bank a run to be the first name here." }
	end
	return {
		kind = kind,
		subtitle = "Of all time · every house",
		entries = Fortune.top(),
		empty = if Fortune.boardsRead() then "No fortune on the board yet. Yours could be the first." else "The board is being read.",
	}
end

local function signature(p: Page): string
	local parts = { p.subtitle, p.empty }
	for i = 1, math.min(#p.entries, WealthBoards.ROWS) do
		local e = p.entries[i]
		table.insert(parts, string.format("%d:%s:%d", e.userId, e.name, math.floor(e.score)))
	end
	return table.concat(parts, "|")
end

local function draw(face: BasePart, p: Page)
	local old = face:FindFirstChild("WealthGui")
	if old then
		old:Destroy()
	end
	local g = Instance.new("SurfaceGui")
	g.Name = "WealthGui"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 44
	g.LightInfluence = 0.4
	g.Brightness = 1.4
	g.MaxDistance = 160
	g.Parent = face
	-- (Everything on one full-size sheet, laid out top to bottom.)
	local sheet = Instance.new("Frame")
	sheet.Name = "Sheet"
	sheet.BackgroundTransparency = 1
	sheet.Size = UDim2.fromScale(1, 1)
	sheet.Parent = g
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0.012, 0)
	list.Parent = sheet
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.05, 0)
	pad.PaddingLeft = UDim.new(0.07, 0)
	pad.PaddingRight = UDim.new(0.07, 0)
	pad.Parent = sheet
	label(sheet, 1, "THE WEALTHIEST", 0.11, Brand.Fonts.display, C.gold)
	label(sheet, 2, p.subtitle, 0.055, Brand.Fonts.bodyMedium, C.smoke)
	local rule = Instance.new("Frame")
	rule.LayoutOrder = 3
	rule.Size = UDim2.new(0.5, 0, 0, 3)
	rule.BackgroundColor3 = C.deepGold
	rule.BorderSizePixel = 0
	rule.Parent = sheet
	if #p.entries == 0 then
		label(sheet, 4, p.empty, 0.06, Brand.Fonts.body, C.dim)
	end
	for i = 1, math.min(#p.entries, WealthBoards.ROWS) do
		local e = p.entries[i]
		row(sheet, 3 + i, i, e.name, e.score)
	end
	label(sheet, 20, "Fortune earned in play. Gilt and Gems bought with Robux don't count.", 0.04, Brand.Fonts.body, C.dim)
end

-- Writes every Wealthiest board whose page has changed since it was last written.
function WealthBoards.refresh()
	local pages: { [string]: Page } = {}
	for _, face in CollectionService:GetTagged("MaisonBoard") do
		local kind = face:GetAttribute("Kind")
		if face:IsA("BasePart") and face.Parent ~= nil and (kind == "wealthHere" or kind == "wealthAll") then
			local p = pages[kind :: string] or WealthBoards.page(kind :: string)
			pages[kind :: string] = p
			local sig = signature(p)
			if drawn[face] ~= sig or face:FindFirstChild("WealthGui") == nil then
				drawn[face] = sig
				draw(face, p)
			end
		end
	end
end

function WealthBoards.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				WealthBoards.refresh()
			end)
			if not ok then
				warn("[Maison] The Wealthiest boards couldn't be written: " .. tostring(err))
			end
			task.wait(WealthBoards.EVERY)
		end
	end)
end

return WealthBoards
