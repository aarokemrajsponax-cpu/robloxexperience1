--!strict
-- The Concierge's question book (Build 87): every question he answers, on the guest's own screen,
-- with a search box, the kinds of question along the top (All first), and each answer opened in
-- place with Back and, when it's about a place, Guide me there (the gold arrows, walking: the server
-- checks the place). Everything in it is what the server sent: the same answers he gives aloud,
-- filled with the house's own numbers. Opened from "Search every question" at the Concierge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local AskPanel = {}

local NAME = "AskPanel"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)

type Item = { id: string, cat: string?, q: string, a: string, place: string? }

local function lower(s: string): string
	return string.lower(s)
end

-- Whether every word of `query` is in the question or its answer.
function AskPanel.matches(item: Item, query: string): boolean
	local hay = lower(item.q .. " " .. item.a)
	for word in string.gmatch(lower(query), "%S+") do
		if not string.find(hay, word, 1, true) then
			return false
		end
	end
	return true
end

function AskPanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

function AskPanel.open(m: { [string]: any })
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local items: { Item } = {}
	for _, it in (if type(m.items) == "table" then m.items else {}) :: { any } do
		if type(it) == "table" and type(it.id) == "string" and type(it.q) == "string" and type(it.a) == "string" then
			table.insert(items, { id = it.id, cat = if type(it.cat) == "string" then it.cat else nil, q = it.q, a = it.a, place = if type(it.place) == "string" then it.place else nil })
		end
	end
	local tabs: { { string } } = { { "all", "All" } }
	for _, c in (if type(m.cats) == "table" then m.cats else {}) :: { any } do
		if type(c) == "table" and type(c.id) == "string" and type(c.name) == "string" then
			table.insert(tabs, { c.id, c.name })
		end
	end

	local size = Root.size()
	local w = Root.panelWidth(620)
	local h = math.min(620, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Ask the Concierge", 26, "display", { LayoutOrder = 1 })
	Theme.text(content, "Every question he answers, from how the house really works.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke })

	local cat = "all"
	local query = ""
	local fill: () -> ()

	-- The search box.
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.PlaceholderText = "Search: a place, a game, Gems, brainrots..."
	search.Text = ""
	search.ClearTextOnFocus = false
	search.Size = UDim2.new(1, 0, 0, 36)
	search.BackgroundColor3 = Color3.fromRGB(26, 24, 26)
	search.TextColor3 = C.bone
	search.PlaceholderColor3 = C.dim
	search.FontFace = Brand.Fonts.body
	search.TextSize = 15
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.LayoutOrder = 3
	search.Parent = content
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 8)
	sc.Parent = search
	local ss = Instance.new("UIStroke")
	ss.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ss.Color = GOLD
	ss.Transparency = 0.6
	ss.Parent = search
	local sp = Instance.new("UIPadding")
	sp.PaddingLeft = UDim.new(0, 12)
	sp.Parent = search

	Theme.tabs(content, tabs, cat, function(id: string)
		cat = id
		fill()
	end, 4)

	-- The list (or one answer, opened).
	local body = Instance.new("ScrollingFrame")
	body.Name = "Questions"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, 0, 1, -(26 + 18 + 36 + 46 + 8 * 4 + 50))
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = GOLD
	body.LayoutOrder = 5
	body.Parent = content
	local bl = Theme.list(body, 6)
	bl.VerticalAlignment = Enum.VerticalAlignment.Top
	local bp = Instance.new("UIPadding")
	bp.PaddingRight = UDim.new(0, 8)
	bp.Parent = body

	local function clear()
		for _, c in body:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	local function openAnswer(item: Item)
		clear()
		Theme.text(body, item.q, 18, "bodyBold", { LayoutOrder = 1, TextColor3 = GOLD, TextWrapped = true })
		Theme.text(body, item.a, 15, "body", { LayoutOrder = 2, TextWrapped = true })
		local row = Instance.new("Frame")
		row.Name = "Keys"
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 40)
		row.LayoutOrder = 3
		row.Parent = body
		local rl = Theme.list(row, 8, true)
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local back = Theme.key(row, "Back", false, function()
			fill()
		end, 110)
		back.LayoutOrder = 2
		if item.place then
			local guide = Theme.key(row, "Guide me there", true, function()
				pcall(function()
					Remotes.event("Travel"):FireServer({ op = "way", place = item.place })
				end)
				Root.close(NAME)
			end, 170)
			guide.LayoutOrder = 1
		end
	end

	fill = function()
		clear()
		local shown = 0
		for i, item in items do
			if (cat == "all" or item.cat == cat) and (query == "" or AskPanel.matches(item, query)) then
				shown += 1
				local b = Instance.new("TextButton")
				b.Name = "Q_" .. item.id
				b.AutoButtonColor = true
				b.BackgroundColor3 = Color3.fromRGB(24, 22, 24)
				b.BackgroundTransparency = 0.05
				b.Size = UDim2.new(1, 0, 0, 0)
				b.AutomaticSize = Enum.AutomaticSize.Y
				b.FontFace = Brand.Fonts.bodyBold
				b.TextSize = 15
				b.TextColor3 = C.bone
				b.TextXAlignment = Enum.TextXAlignment.Left
				b.TextWrapped = true
				b.Text = item.q
				b.LayoutOrder = i
				b.Parent = body
				local bc = Instance.new("UICorner")
				bc.CornerRadius = UDim.new(0, 8)
				bc.Parent = b
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 12)
				pad.PaddingRight = UDim.new(0, 12)
				pad.PaddingTop = UDim.new(0, 10)
				pad.PaddingBottom = UDim.new(0, 10)
				pad.Parent = b
				b.Activated:Connect(function()
					openAnswer(item)
				end)
			end
		end
		if shown == 0 then
			Theme.text(body, "Nothing matches that. Try another word, or ask me in person.", 14, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true })
		end
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		query = search.Text
		fill()
	end)
	fill()
	local close = Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 120)
	close.LayoutOrder = 6
	Root.open(NAME, group)
end

return AskPanel
