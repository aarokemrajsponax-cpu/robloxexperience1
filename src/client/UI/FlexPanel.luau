--!strict
-- The Flex Studio's card (its gold mark, and the kiosk by the Flex Wall). Make a reel: what you're
-- flexing (only what's yours, as the server lists it), the set, and the caption (the house's own
-- lines, shown with your thing in them), a preview of how it will read on the wall, and Shoot the
-- reel (on the mark). The Flex Wall: every reel up there, newest first, its likes, and a Like for
-- each one that isn't yours (once). Every figure is the server's; a like or a reel is only asked for.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Plan = require(ReplicatedStorage.Shared.Flex)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local FlexPanel = {}

-- Set by Main: the reel itself, shot on this screen (World/FlexReel).
FlexPanel.shoot = function(_reel: { [string]: any }) end

local NAME = "FlexStudio"
local C = Brand.Colours
local rgb = Color3.fromRGB
local PINK = rgb(255, 90, 180)
local GOLD = rgb(255, 204, 90)
local DONE = rgb(110, 230, 160)
local TILE = rgb(16, 16, 24)

local view: { [string]: any } = {}
local refresh: (() -> ())? = nil

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else nil
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function corner(f: GuiObject, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = f
end

local function stroke(f: GuiObject, colour: Color3, transparency: number): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = colour
	s.Transparency = transparency
	s.Thickness = 1.4
	s.Parent = f
	return s
end

local function heading(parent: Instance, text: string, order: number)
	Theme.text(parent, text, 11, "caps", { LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
end

-- A grid of tiles: each a glyph, a name, a small line; the chosen one edged in gold.
local function tiles(parent: Instance, order: number, cols: number, high: number, list: { { id: string, glyph: string, name: string, small: string?, colour: Color3? } }, chosen: string?, onChoose: (id: string) -> ())
	local holder = Instance.new("Frame")
	holder.Name = "Tiles"
	holder.BackgroundTransparency = 1
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.LayoutOrder = order
	holder.Parent = parent
	local grid = Instance.new("UIGridLayout")
	-- (Shares of the row, so a row of `cols` always fits whatever width the card has.)
	grid.CellSize = UDim2.new(1 / cols, -math.ceil(8 * (cols - 1) / cols), 0, high)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder
	for i, t in list do
		local b = Instance.new("TextButton")
		b.Name = "Tile_" .. t.id
		b.AutoButtonColor = false
		b.Text = ""
		b.BackgroundColor3 = TILE
		b.BackgroundTransparency = 0.1
		b.LayoutOrder = i
		b.Parent = holder
		corner(b, 10)
		stroke(b, if t.id == chosen then GOLD else rgb(70, 66, 80), if t.id == chosen then 0 else 0.4)
		Theme.text(b, t.glyph, 20, "body", {
			Name = "Glyph",
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0, 30, 1, 0),
			TextWrapped = false,
		})
		Theme.text(b, t.name, 13, "bodyBold", {
			Name = "Name",
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(42, 6),
			Size = UDim2.new(1, -48, 0, if t.small then high - 30 else high - 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = C.bone,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		if t.small then
			Theme.text(b, t.small, 11, "caps", {
				Name = "Small",
				AutomaticSize = Enum.AutomaticSize.None,
				Position = UDim2.new(0, 42, 1, -18),
				Size = UDim2.new(1, -48, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = t.colour or C.smoke,
				TextWrapped = false,
			})
		end
		b.Activated:Connect(function()
			onChoose(t.id)
		end)
	end
end

local function rarityColour(r: string?): Color3?
	local c = if r then (Curios.RarityColour :: any)[r] else nil
	return if typeof(c) == "Color3" then c else nil
end

-- Make a reel.
local function maker(body: GuiObject, w: number)
	local items = if type(view.items) == "table" then view.items else {}
	local sets = if type(view.sets) == "table" then view.sets else {}
	local captions = if type(view.captions) == "table" then view.captions else {}
	view.item = view.item or (items[1] and items[1].key)
	view.set = view.set or (sets[1] and sets[1].id)
	view.line = view.line or (captions[1] and captions[1].id)
	local itemName = ""
	for _, it in items do
		if it.key == view.item then
			itemName = tostring(it.name)
		end
	end
	local cols = if w >= 520 then 3 else 2
	heading(body, "1  ·  What you're flexing (only what's yours)", 1)
	local list = {}
	for _, it in items do
		local kind = Plan.KindNames[tostring(it.kind)] or ""
		table.insert(list, { id = tostring(it.key), glyph = tostring(it.glyph or "✨"), name = tostring(it.name), small = string.upper(if it.rarity then tostring(it.rarity) else kind), colour = rarityColour(it.rarity) })
	end
	-- (Narrow cards: a taller tile, so a long name's two lines sit clear of the line under it.)
	tiles(body, 2, cols, if w < 520 then 74 else 60, list, view.item, function(id: string)
		view.item = id
		if refresh then
			refresh()
		end
	end)
	heading(body, "2  ·  The set", 3)
	local setList = {}
	for _, s in sets do
		table.insert(setList, { id = tostring(s.id), glyph = tostring(s.glyph or ""), name = tostring(s.name) })
	end
	tiles(body, 4, 2, 48, setList, view.set, function(id: string)
		view.set = id
		if refresh then
			refresh()
		end
	end)
	heading(body, "3  ·  The caption", 5)
	local capList = {}
	for _, c in captions do
		table.insert(capList, { id = tostring(c.id), glyph = "💬", name = Plan.caption(tostring(c.id), itemName) or tostring(c.text) })
	end
	tiles(body, 6, 2, 52, capList, view.line, function(id: string)
		view.line = id
		if refresh then
			refresh()
		end
	end)
	-- How it will read on the wall.
	local preview = Plan.caption(view.line or "", itemName) or ""
	local set = Plan.setById[view.set or ""]
	local card = Instance.new("Frame")
	card.Name = "Preview"
	card.BackgroundColor3 = rgb(10, 10, 14)
	card.BackgroundTransparency = 0.05
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Size = UDim2.new(1, 0, 0, 0)
	card.LayoutOrder = 7
	card.Parent = body
	corner(card, 12)
	stroke(card, PINK, 0.2)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = card
	Theme.list(card, 4).HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.text(card, "On the Flex Wall" .. (if set then "  ·  " .. set.name else ""), 11, "caps", { LayoutOrder = 1, TextColor3 = PINK, TextXAlignment = Enum.TextXAlignment.Left })
	Theme.text(card, "@" .. Players.LocalPlayer.DisplayName .. "  " .. preview, 16, "bodyBold", { LayoutOrder = 2, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	Theme.text(card, string.format("Stand on the gold mark to shoot. Your first reel today: +%d Gilt. Each like from another guest: +%d Gilt (%d a day).", Plan.REWARDS.firstReel, Plan.REWARDS.like, Plan.REWARDS.likesPaid), 12, "body", { LayoutOrder = 3, TextColor3 = C.smoke, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
end

-- The Flex Wall: every reel, its likes, and a Like for each that isn't yours.
local function wallList(body: GuiObject)
	local reels = if type(view.reels) == "table" then view.reels else {}
	if #reels == 0 then
		Theme.text(body, "No reels on the wall yet. Stand on the gold mark and shoot the first.", 14, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true })
		return
	end
	for i, r in reels do
		local row = Instance.new("Frame")
		row.Name = "Reel_" .. tostring(r.id)
		row.BackgroundColor3 = TILE
		row.BackgroundTransparency = 0.1
		row.Size = UDim2.new(1, 0, 0, 64)
		row.LayoutOrder = i
		row.Parent = body
		corner(row, 10)
		stroke(row, if r.mine then GOLD else rgb(70, 66, 80), 0.35)
		local item = if type(r.item) == "table" then r.item else {}
		Theme.text(row, tostring(item.glyph or "✨"), 22, "body", { AutomaticSize = Enum.AutomaticSize.None, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, 34, 1, 0), TextWrapped = false })
		Theme.text(row, "@" .. tostring(r.by) .. "  ·  ♥ " .. tostring(r.likes or 0), 12, "caps", {
			Name = "Who",
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(48, 8),
			Size = UDim2.new(1, -190, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = PINK,
			TextWrapped = false,
		})
		Theme.text(row, tostring(r.text or ""), 14, "bodyBold", {
			Name = "Text",
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(48, 26),
			Size = UDim2.new(1, -190, 0, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = C.bone,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		if r.mine then
			Theme.text(row, "YOURS", 12, "caps", { AutomaticSize = Enum.AutomaticSize.None, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(120, 20), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GOLD })
		elseif r.liked then
			Theme.text(row, "♥  LIKED", 12, "caps", { AutomaticSize = Enum.AutomaticSize.None, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(120, 20), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = DONE })
		else
			local key = Theme.key(row, "♥  Like", true, function()
				task.spawn(function()
					local res = ask({ op = "act", id = "gala", act = "flex", what = "like", n = r.id })
					if res and res.ok == true then
						r.liked = true
						r.likes = tonumber(res.likes) or r.likes
						if refresh then
							refresh()
						end
					else
						Toast.show("Not just now", tostring(res and res.why or "The house couldn't be reached."), 3)
					end
				end)
			end, 120)
			key.AnchorPoint = Vector2.new(1, 0.5)
			key.Position = UDim2.new(1, -10, 0.5, 0)
		end
	end
end

function FlexPanel.open(which: string?)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local tab = if which == "feed" then "feed" else "make"
	local size = Root.size()
	local w = Root.panelWidth(640)
	local h = math.min(660, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Flex Studio", 11, "caps", { LayoutOrder = 1, TextColor3 = PINK })
	local title = Theme.text(content, "", 26, "display", { LayoutOrder = 2 })
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.LayoutOrder = 4
	body.Size = UDim2.new(1, 0, 0, 300)
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = C.gold
	body.Parent = content
	Theme.list(body, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = body
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 48)
	keys.LayoutOrder = 20
	keys.Parent = content
	Theme.list(keys, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local busy = false
	local function draw()
		clear(body)
		clear(keys)
		if not view.ok then
			title.Text = "One moment"
			Theme.text(body, "The studio is getting ready.", 14, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
		elseif tab == "feed" then
			title.Text = "The Flex Wall"
			wallList(body)
		else
			title.Text = "Make a reel"
			maker(body, w)
			local wait = tonumber(view.wait) or 0
			local shoot = Theme.key(keys, if wait > 0 then string.format("Next reel in %d s", wait) else "Shoot the reel", wait <= 0, function()
				if busy or (tonumber(view.wait) or 0) > 0 then
					return
				end
				busy = true
				task.spawn(function()
					local res = ask({ op = "act", id = "gala", act = "flex", what = "record", item = view.item, set = view.set, line = view.line })
					busy = false
					if res and res.ok == true and type(res.reel) == "table" then
						Root.close(NAME)
						FlexPanel.shoot(res.reel)
					else
						Toast.show("Not just now", tostring(res and res.why or "The house couldn't be reached."), 3.5)
					end
				end)
			end, 240)
			shoot.LayoutOrder = 1
		end
		Theme.key(keys, "Close", false, function()
			Root.close(NAME)
		end, 140).LayoutOrder = 2
	end
	refresh = draw
	local tabs = Theme.tabs(content, { { "make", "Make a reel" }, { "feed", "The Flex Wall" } }, tab, function(id: string)
		tab = id
		draw()
	end, 3)
	tabs.select(tab)
	view = { ok = false }
	draw()
	Theme.fillRest(body)
	Root.open(NAME, group, function()
		refresh = nil
	end)
	task.spawn(function()
		local r = ask({ op = "act", id = "gala", act = "flex", what = "list" })
		if not group.Parent then
			return
		end
		if r and r.ok == true then
			view = r
		else
			view = { ok = false }
			Toast.show("Not just now", tostring(r and r.why or "The house couldn't be reached."), 3)
		end
		draw()
	end)
end

function FlexPanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

-- Word from the hall: a new reel on the wall, or a reel's likes (the open card follows).
function FlexPanel.on(m: { [string]: any })
	if not view.ok or type(view.reels) ~= "table" then
		return
	end
	if m.what == "reel" and type(m.reel) == "table" then
		local r = table.clone(m.reel)
		r.mine = r.userId == Players.LocalPlayer.UserId
		table.insert(view.reels, 1, r)
	elseif m.what == "likes" then
		for _, r in view.reels do
			if r.id == m.id then
				r.likes = tonumber(m.likes) or r.likes
			end
		end
	end
	if refresh then
		refresh()
	end
end

return FlexPanel
