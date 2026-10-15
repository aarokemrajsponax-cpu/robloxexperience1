--!strict
-- How to play (the key at the top right): the whole game in plain words. What you do (sit, sort,
-- spend), every room in a line with a Go key that takes you straight there, and the extras (the
-- Grand Prix, curios and brainrots, Gems, levels, events). For a first evening and for every one
-- after: nothing in it assumes you've been before.
--
-- And the sorting, step by step (HowToPlay.sorting): five short steps with the real pieces
-- turning slowly in gold light. Back / Next; the last step seats you at a table. Closing either
-- returns you exactly where you were.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local PieceIcon = require(script.Parent.PieceIcon)
local State = require(script.Parent.Parent.State)

local HowToPlay = {}

local NAME = "HowToPlay"
local GUIDE = "HowToPlayGuide"
local C = Brand.Colours

local STEPS = {
	{ title = Voice.HowToPlay[1], line = "Drag a piece, or tap it.", piece = "dressWatch" },
	{ title = Voice.HowToPlay[2], line = "Every piece has a case. Drop it in.", piece = "diamondRing" },
	{ title = Voice.HowToPlay[3], line = "A thread of gold runs to the right case.", piece = "goldBar" },
	{ title = Voice.HowToPlay[4], line = "A streak raises the multiplier. Three into one case pays more.", piece = "rubyGem" },
	{ title = Voice.HowToPlay[5], line = "The Salon keeps no clock. Take your time.", piece = "objetEgg" },
}

-- The Club Floor's own three steps, the first time a guest climbs the stair (§15).
local CLUB_STEPS = {
	{ title = "Same pieces, both of you", line = "In the Library two guests sort the identical deal. First to clear the felt takes the hand.", piece = "pocketWatch" },
	{ title = "Three in a row sends a parcel", line = "Three into one case sends a sealed parcel of lookalikes across. Your own parcels cancel theirs.", piece = "goldCoins" },
	{ title = "Keep your lamp lit", line = "In the Ballroom a felt holds sixteen. Go over for three seconds and your lamp goes out. The last lamp wins.", piece = "blackDiamond" },
}

-- Set by Main: what the last step's key does (seat the guest, or return them to the table).
HowToPlay.onFinish = function() end
-- Set by Main: going straight to a place (the server moves the guest), and the Concierge's tour.
HowToPlay.go = function(_place: string) end
HowToPlay.tour = function() end
-- Set by Main: tonight's table (one try a day), straight to a free table for it; the Shop.
HowToPlay.tonight = function() end
HowToPlay.shop = function() end

-- The piece, drawn as it is on the sorting screen, in a pool of gold light, floating gently.
local function viewport(parent: Instance, pieceId: string): (Frame, () -> ())
	local holder = Instance.new("Frame")
	holder.Name = "Piece"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 170)
	holder.LayoutOrder = 2
	holder:SetAttribute("Piece", pieceId)
	holder.Parent = parent
	for k, size in { 1.0, 0.78, 0.58 } do
		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromOffset(170 * size, 170 * size)
		glow.BorderSizePixel = 0
		glow.BackgroundColor3 = Color3.fromRGB(226, 176, 86)
		glow.BackgroundTransparency = 0.95 - k * 0.012
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = glow
		glow.Parent = holder
	end
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromOffset(130, 130)
	art.Parent = holder
	PieceIcon.piece(art, pieceId, 130)
	local t = 0
	local conn = RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		art.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 1.4) * 4)
		art.Rotation = math.sin(t * 0.9) * 3
	end)
	return holder, function()
		conn:Disconnect()
	end
end

-- The sorting, step by step (or, with `club`, the Club Floor's three steps).
function HowToPlay.sorting(club: boolean?)
	if Root.isOpen(NAME) then
		return
	end
	local STEPS = if club then CLUB_STEPS else STEPS
	local w = Root.panelWidth(480)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 470))
	Theme.fitHeight(group, content)
	Theme.list(content, 10).VerticalAlignment = Enum.VerticalAlignment.Top

	local stepLabel = Theme.text(content, "", 11, "caps", { LayoutOrder = 1 })
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 170)
	holder.LayoutOrder = 2
	holder.Parent = content
	local title = Theme.text(content, "", 26, "display", { LayoutOrder = 3 })
	Theme.hairline(content, UDim.new(0, 70), 4)
	local line = Theme.text(content, "", 16, "body", { LayoutOrder = 5, TextColor3 = Brand.Colours.smoke })

	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 44)
	keys.LayoutOrder = 6
	keys.Parent = content
	Theme.list(keys, 10, true)

	local index = 1
	local stopSpin: (() -> ())? = nil
	local back: TextButton
	local nextKey: TextButton

	local function render()
		local step = STEPS[index]
		stepLabel.Text = Caps(Voice.roman(index) .. "  of  " .. Voice.roman(#STEPS))
		title.Text = step.title
		line.Text = step.line
		if stopSpin then
			stopSpin()
		end
		for _, c in holder:GetChildren() do
			c:Destroy()
		end
		local vp, stop = viewport(holder, step.piece)
		vp.Size = UDim2.fromScale(1, 1)
		stopSpin = stop
		back.Visible = index > 1
		local last = index == #STEPS
		local text = if last then (if club then "Understood" elseif State.seated then "Back to the table" else "Take me to a table") else "Next"
		nextKey.Text = Caps(text)
	end

	back = Theme.key(keys, "Back", false, function()
		index = math.max(1, index - 1)
		render()
	end, 150)
	nextKey = Theme.key(keys, "Next", true, function()
		if index < #STEPS then
			index += 1
			render()
		else
			Root.close(NAME)
			if not club then
				HowToPlay.onFinish()
			end
		end
	end, 220)
	local close = Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 150)
	close.LayoutOrder = 7
	render()
	Root.open(NAME, group, function()
		if stopSpin then
			stopSpin()
		end
	end)
end


---------------------------------------------------------------------------------------------------
-- The guide
---------------------------------------------------------------------------------------------------
local function heading(parent: Instance, text: string, order: number)
	local h = Theme.text(parent, text, 12, "caps", {
		Name = "Section",
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.gold,
	})
	h.Size = UDim2.new(1, 0, 0, 26)
	h.AutomaticSize = Enum.AutomaticSize.None
	h.TextYAlignment = Enum.TextYAlignment.Bottom
end

-- One line of the guide: (a number in a gold ring,) a name, a plain line, and a key at the right.
local function row(parent: Instance, order: number, n: number?, title: string, line: string, keyText: string?, onPress: (() -> ())?, how: string?, win: string?): Frame
	local r = Instance.new("Frame")
	r.Name = "Row"
	r.BackgroundTransparency = 1
	r.AutomaticSize = Enum.AutomaticSize.Y
	r.Size = UDim2.new(1, 0, 0, 0)
	r.LayoutOrder = order
	r.Parent = parent
	local left = 0
	if n then
		local ring = Instance.new("TextLabel")
		ring.Name = "Number"
		ring.Size = UDim2.fromOffset(28, 28)
		ring.Position = UDim2.fromOffset(0, 2)
		ring.BackgroundColor3 = Color3.fromRGB(28, 24, 18)
		ring.FontFace = Brand.Fonts.figures
		ring.TextSize = 15
		ring.TextColor3 = C.lightGold
		ring.Text = tostring(n)
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(1, 0)
		rc.Parent = ring
		local rs = Instance.new("UIStroke")
		rs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rs.Color = C.gold
		rs.Transparency = 0.2
		rs.Thickness = 1.25
		rs.Parent = ring
		ring.Parent = r
		left = 40
	end
	-- (A key as wide as its words need, on one line.)
	-- (Measured at a phone's lettering, the largest a key's words are ever set.)
	local keyW = if keyText then math.clamp(math.ceil(Theme.measure(Caps(keyText), 19, Brand.Fonts.bodyBold).X) + 30, 96, 210) else 0
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(left, 0)
	words.AutomaticSize = Enum.AutomaticSize.Y
	words.Size = UDim2.new(1, -(left + (if keyText then keyW + 12 else 0)), 0, 0)
	words.Parent = r
	local list = Theme.list(words, 1)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.text(words, title, 16, "bodyBold", { Name = "Title", LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.bone })
	Theme.text(words, line, 14, "bodyMedium", {
		Name = "Line",
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.bone,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
	})
	-- How it works, then what you get (in gold).
	if how then
		Theme.text(words, how, 14, "body", {
			Name = "How",
			LayoutOrder = 3,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.smoke,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
		})
	end
	if win then
		Theme.text(words, "You get: " .. win, 14, "bodyMedium", {
			Name = "Win",
			LayoutOrder = 4,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.lightGold,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
		})
	end
	if keyText and onPress then
		local k = Theme.key(r, keyText, false, onPress, keyW)
		k.Name = "Key"
		-- (Level with the row's title, however long what's under it runs.)
		k.AnchorPoint = Vector2.new(1, 0)
		k.Position = UDim2.new(1, 0, 0, 2)
		k.Size = UDim2.fromOffset(keyW, 34)
	end
	return r
end

-- The six cases, each with the piece drawn on it at the table and what it holds.
local function caseGrid(parent: Instance, order: number)
	local grid = Instance.new("Frame")
	grid.Name = "Cases"
	grid.BackgroundTransparency = 1
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.LayoutOrder = order
	grid.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -5, 0, 66)
	layout.CellPadding = UDim2.fromOffset(10, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, case in Catalogue.Cases do
		local cell = Instance.new("Frame")
		cell.Name = "Case_" .. case.id
		cell.LayoutOrder = i
		cell.BackgroundColor3 = Color3.new(1, 1, 1)
		cell.BackgroundTransparency = 0.04
		local shade = Instance.new("UIGradient")
		shade.Rotation = 62
		shade.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 56, 36)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 17, 19)),
		})
		shade.Parent = cell
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 10)
		cc.Parent = cell
		local cs = Instance.new("UIStroke")
		cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		cs.Color = C.gold
		cs.Transparency = 0.45
		cs.Parent = cell
		local art = Instance.new("Frame")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.AnchorPoint = Vector2.new(0, 0.5)
		art.Position = UDim2.new(0, 8, 0.5, 0)
		art.Size = UDim2.fromOffset(50, 50)
		art.Parent = cell
		pcall(PieceIcon.piece, art, case.face, 50)
		local words = Instance.new("Frame")
		words.Name = "Words"
		words.BackgroundTransparency = 1
		words.AnchorPoint = Vector2.new(0, 0.5)
		words.Position = UDim2.new(0, 66, 0.5, 0)
		words.Size = UDim2.new(1, -74, 0, 0)
		words.AutomaticSize = Enum.AutomaticSize.Y
		words.Parent = cell
		local list = Theme.list(words, 1)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Left
		Theme.text(words, Caps(case.name), 14, "bodyBold", { Name = "Name", LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.lightGold })
		Theme.text(words, case.subtitle, 13, "body", { Name = "Holds", LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
		cell.Parent = grid
	end
end

-- A paragraph across the page.
local function paragraph(parent: Instance, text: string, order: number, size: number?)
	Theme.text(parent, text, size or 15, "body", {
		Name = "Lead",
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.bone,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
	})
end

local currentPage = "basics"

function HowToPlay.guide(page: string?)
	if Root.isOpen(GUIDE) then
		Root.close(GUIDE)
	end
	local G = Voice.Guide
	currentPage = page or currentPage
	-- (Wider on a phone held sideways, where everything is drawn smaller: every tab shows, and the
	-- lines wrap less in the little height there is.)
	local w = Root.panelWidth(if Root.scale < 0.8 then 820 else 600)
	local group, content = Theme.glass(Root.panels, GUIDE, UDim2.fromOffset(w, 680))
	local outer = Theme.list(content, 8)
	outer.VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, G.title, 26, "display", { LayoutOrder = 1 })

	local scroll: ScrollingFrame
	local function goTo(place: string): () -> ()
		return function()
			Root.close(GUIDE)
			HowToPlay.go(place)
		end
	end
	-- What a line's key does.
	local function pressFor(item: Voice.GuideItem): (() -> ())?
		if item.action == "sit" then
			return function()
				Root.close(GUIDE)
				HowToPlay.onFinish()
			end
		elseif item.action == "sorting" then
			return function()
				HowToPlay.guide("sorting")
			end
		elseif item.action == "shop" then
			return function()
				Root.close(GUIDE)
				HowToPlay.shop()
			end
		elseif item.action == "nightly" then
			return function()
				Root.close(GUIDE)
				HowToPlay.tonight()
			end
		elseif item.place then
			return goTo(item.place)
		end
		return nil
	end
	local function keyFor(item: Voice.GuideItem): string?
		if item.key then
			return item.key
		end
		return if item.place then G.go else nil
	end

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function rows(list: { Voice.GuideItem }, numbered: boolean)
		for i, item in list do
			local press = pressFor(item)
			row(scroll, nextOrder(), if numbered then i else nil, item.title, item.line, if press then keyFor(item) else nil, press, item.how, item.win)
		end
	end
	local function nextKey(after: string)
		local ids = {}
		for _, t in G.tabs do
			table.insert(ids, t[1])
		end
		local at = table.find(ids, after) or 1
		local nextId = ids[at + 1]
		if not nextId then
			return
		end
		local label = ""
		for _, t in G.tabs do
			if t[1] == nextId then
				label = t[2]
			end
		end
		local holder = Instance.new("Frame")
		holder.Name = "NextPage"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, 0, 0, 52)
		holder.LayoutOrder = nextOrder()
		holder.Parent = scroll
		local k = Theme.key(holder, G.next .. label, true, function()
			HowToPlay.guide(nextId)
		end, 260)
		k.AnchorPoint = Vector2.new(0.5, 0.5)
		k.Position = UDim2.fromScale(0.5, 0.5)
	end

	local function fill(id: string)
		order = 0
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		scroll.CanvasPosition = Vector2.zero
		if id == "basics" then
			local B = G.basics
			paragraph(scroll, B.lead, nextOrder(), 16)
			heading(scroll, B.heading, nextOrder())
			rows(B.steps, true)
			paragraph(scroll, B.after, nextOrder(), 14)
		elseif id == "sorting" then
			local S = G.sorting
			paragraph(scroll, S.lead, nextOrder(), 16)
			caseGrid(scroll, nextOrder())
			heading(scroll, S.heading, nextOrder())
			rows(S.tips, false)
			local holder = Instance.new("Frame")
			holder.Name = "Try"
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.new(1, 0, 0, 48)
			holder.LayoutOrder = nextOrder()
			holder.Parent = scroll
			local k = Theme.key(holder, S.key, false, function()
				Root.close(GUIDE)
				HowToPlay.onFinish()
			end, 220)
			k.AnchorPoint = Vector2.new(0.5, 0.5)
			k.Position = UDim2.fromScale(0.5, 0.5)
		elseif id == "rooms" then
			local R = G.rooms
			paragraph(scroll, R.lead, nextOrder(), 16)
			heading(scroll, R.heading, nextOrder())
			rows(R.sort, false)
			heading(scroll, R.heading2, nextOrder())
			rows(R.visit, false)
		elseif id == "gilt" then
			paragraph(scroll, G.gilt.lead, nextOrder(), 16)
			rows(G.gilt.items, false)
		else
			paragraph(scroll, G.extras.lead, nextOrder(), 16)
			rows(G.extras.items, false)
		end
		nextKey(id)
	end

	local tabs = Theme.tabs(content, G.tabs, currentPage, function(id: string)
		currentPage = id
		fill(id)
	end, 2)
	tabs.frame.Name = "GuideTabs"

	scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Guide"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 3
	scroll.Size = UDim2.new(1, 0, 1, -(34 + 46 + 44 + 8 * 3 + 4))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = C.gold
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = content
	local inner = Theme.list(scroll, 14)
	inner.VerticalAlignment = Enum.VerticalAlignment.Top
	inner.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = scroll
	fill(currentPage)

	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 44)
	keys.LayoutOrder = 4
	keys.Parent = content
	local keyList = Theme.list(keys, 10, true)
	keyList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(keys, G.tour, false, function()
		Root.close(GUIDE)
		HowToPlay.tour()
	end, 262).LayoutOrder = 1
	Theme.key(keys, "Close", false, function()
		Root.close(GUIDE)
	end, 130).LayoutOrder = 2
	Theme.fillRest(scroll)
	Root.open(GUIDE, group)
end

-- How to play: the guide (or, with `club`, the Club Floor's three steps).
function HowToPlay.open(club: boolean?)
	if club then
		HowToPlay.sorting(true)
		return
	end
	HowToPlay.guide()
end

return HowToPlay
