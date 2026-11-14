--!strict
-- The Grand Ballroom's cards. Dance & music (the jukebox's prompt, or the key at the foot of the
-- hall's screen): seven moves to dance (Roblox's own emotes, on your own avatar for everyone to
-- see; a dance keeps going while you move, until Stop dancing or you leave the Ballroom), and the jukebox: every record, the one playing, how many
-- votes each has for the next, and your vote. The Exchange (its stands): every other guest in the
-- house, and Trade, which asks them (the trade itself is the house's trading screen: Gilt, Gems,
-- brainrots and curios, both sides seen, nothing moved until both confirm). And the poses, a row
-- of moves along the foot of the screen while a photograph is framed at a photo set. Every figure
-- is the server's; a vote is only asked for.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Plan = require(ReplicatedStorage.Shared.Gala)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local GalaPanel = {}

-- Set by Main: play a move on this guest's avatar (World/GalaView), stop it, the hall's state
-- (for the jukebox), a trade invitation (UI/TradePanel), and the state changed.
GalaPanel.move = function(_id: string): boolean
	return false
end
GalaPanel.stop = function() end
GalaPanel.state = function(): { [string]: any }
	return {}
end
GalaPanel.invite = function(_userId: number, _name: string) end
GalaPanel.changed = function(_st: { [string]: any }) end

local NAME = "GalaCard"
local POSES = "GalaPoses"
local C = Brand.Colours
local rgb = Color3.fromRGB
local GOLD = rgb(255, 204, 90)
local WARM = rgb(255, 196, 120)

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

-- A row in a list: words on the left, a key on the right.
local function row(parent: Instance, order: number, title: string, line: string, colour: Color3, keyText: string?, primary: boolean?, onPress: (() -> ())?): Frame
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.BackgroundColor3 = rgb(255, 255, 255)
	f.BackgroundTransparency = 0.96
	f.Size = UDim2.new(1, 0, 0, 56)
	f.LayoutOrder = order
	f.Parent = parent
	corner(f, 10)
	local t = Theme.text(f, title, 15, "bodyBold", { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = colour, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(14, 8), TextTruncate = Enum.TextTruncate.AtEnd })
	t.Name = "Title"
	local l = Theme.text(f, line, 12, "body", { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -170, 0, 18), Position = UDim2.fromOffset(14, 30), TextTruncate = Enum.TextTruncate.AtEnd })
	l.Name = "Line"
	if keyText and onPress then
		local k = Theme.key(f, keyText, primary, onPress, 140)
		k.AnchorPoint = Vector2.new(1, 0.5)
		k.Position = UDim2.new(1, -8, 0.5, 0)
		k.Size = UDim2.fromOffset(140, 38)
	elseif keyText then
		local w = Theme.text(f, keyText, 12, "bodyBold", { TextColor3 = GOLD, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(140, 38), TextXAlignment = Enum.TextXAlignment.Center })
		w.AnchorPoint = Vector2.new(1, 0.5)
		w.Position = UDim2.new(1, -8, 0.5, 0)
		w.Name = "Word"
	end
	return f
end

---------------------------------------------------------------------------------------------------
-- Dance & music
---------------------------------------------------------------------------------------------------
local function moveGrid(parent: Instance, order: number, cell: number, onMove: ((id: string) -> ())?): Frame
	local grid = Instance.new("Frame")
	grid.Name = "Moves"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, cell + 8)
	grid.LayoutOrder = order
	grid.Parent = parent
	local list = Theme.list(grid, 8, true)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	for i, m in Plan.Moves do
		local b = Instance.new("TextButton")
		b.Name = "Move_" .. m.id
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = rgb(30, 24, 22)
		b.BackgroundTransparency = 0.15
		b.Size = UDim2.fromOffset(cell, cell)
		b.LayoutOrder = i
		b.Parent = grid
		corner(b, 12)
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = WARM
		edge.Transparency = 0.6
		edge.Parent = b
		local g = Theme.text(b, m.glyph, math.floor(cell * 0.36), "body", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0.58, 0), Position = UDim2.fromScale(0, 0.06), TextXAlignment = Enum.TextXAlignment.Center })
		g.Name = "Glyph"
		local n = Theme.text(b, m.name, 12, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -6, 0, 16), Position = UDim2.new(0, 3, 0.66, 0), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.bone })
		n.Name = "MoveName"
		b.Activated:Connect(function()
			if GalaPanel.move(m.id) then
				for _, other in grid:GetChildren() do
					local s = other:FindFirstChildOfClass("UIStroke")
					if s then
						s.Transparency = if other == b then 0 else 0.6
						s.Color = if other == b then GOLD else WARM
					end
				end
				if onMove then
					onMove(m.id)
				end
			else
				Toast.show("Dancing", "Your avatar can't dance just now.", 2.5)
			end
		end)
	end
	return grid
end

local function dance(content: Frame, body: ScrollingFrame)
	local st = GalaPanel.state()
	local juke = if type(st.juke) == "table" then st.juke else {}
	Theme.text(body, "Your moves", 12, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
	moveGrid(body, 2, 64)
	Theme.text(body, "A dance keeps going while you walk about, until you press Stop dancing or leave the Ballroom. Everyone in the hall sees it. A minute on the dance floor pays a little Gilt, ten minutes a day.", 12, "body", { LayoutOrder = 3, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	Theme.hairline(body, UDim.new(0, 120), 4)
	Theme.text(body, "The jukebox", 12, "caps", { LayoutOrder = 5, TextXAlignment = Enum.TextXAlignment.Left })
	local left = math.max(0, math.floor(tonumber(juke.changeIn) or 0))
	Theme.text(body, string.format("Now playing: %s. The most-voted record goes on next, in %d:%02d. One vote each.", tostring(juke.name or "the house's record"), left // 60, left % 60), 12, "body", { LayoutOrder = 6, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	local records = if type(juke.records) == "table" then juke.records else {}
	for i, rec in records do
		local playing = tonumber(juke.track) == tonumber(rec.n)
		local mine = tonumber(juke.mine) == tonumber(rec.n)
		local votes = tonumber(rec.votes) or 0
		local line = string.format("%s%s", if playing then "♪ Playing now  ·  " else "", if votes == 1 then "1 vote for next" else string.format("%d votes for next", votes))
		row(body, 10 + i, tostring(rec.name), line, if playing then GOLD else C.bone, if mine then "Your vote" else "Vote", not mine, if mine
			then nil
			else function()
				task.spawn(function()
					local ok, r = pcall(function()
						return Remotes.func("AttractionAsk"):InvokeServer({ op = "act", id = Plan.ID, act = "vote", what = "juke", n = tonumber(rec.n) })
					end)
					if ok and type(r) == "table" and r.ok == true then
						local s = GalaPanel.state()
						s.juke = r
						GalaPanel.changed(s)
						if Root.isOpen(NAME) then
							clear(body)
							dance(content, body)
						end
					elseif ok and type(r) == "table" then
						Toast.show("The jukebox", tostring(r.why or "Not just now."), 2.5)
					end
				end)
			end)
	end
	if #records == 0 then
		Theme.text(body, "The jukebox is still being filled.", 13, "body", { LayoutOrder = 11, TextColor3 = C.smoke })
	end
end

---------------------------------------------------------------------------------------------------
-- The Exchange
---------------------------------------------------------------------------------------------------
local function exchange(body: ScrollingFrame)
	Theme.text(body, "Trade Gilt, Gems, brainrots and curios with any guest in the house. Both of you see every offer; nothing changes hands until you both confirm the very same trade.", 12, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	local me = Players.LocalPlayer
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= me then
			table.insert(others, p)
		end
	end
	table.sort(others, function(a, b)
		local ah = a:GetAttribute("Attraction") == Plan.ID
		local bh = b:GetAttribute("Attraction") == Plan.ID
		if ah ~= bh then
			return ah
		end
		return a.DisplayName < b.DisplayName
	end)
	for i, p in others do
		local here = p:GetAttribute("Attraction") == Plan.ID
		local f = row(body, 1 + i, p.DisplayName, if here then "Here in the Grand Ballroom" else "In the house", if here then WARM else C.bone, "Trade", true, function()
			GalaPanel.invite(p.UserId, p.DisplayName)
		end)
		local face = Instance.new("ImageLabel")
		face.Name = "Face"
		face.BackgroundColor3 = rgb(50, 40, 40)
		face.Size = UDim2.fromOffset(40, 40)
		face.Position = UDim2.fromOffset(8, 8)
		face.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", p.UserId)
		face.Parent = f
		corner(face, 20)
		for _, name in { "Title", "Line" } do
			local l = f:FindFirstChild(name)
			if l and l:IsA("GuiObject") then
				l.Position = UDim2.fromOffset(58, l.Position.Y.Offset)
			end
		end
	end
	if #others == 0 then
		Theme.text(body, "Nobody else is in the house just now. When a guest arrives, they'll be here.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	end
end

---------------------------------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------------------------------
function GalaPanel.open(which: string?)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local tab = if which == "exchange" then "exchange" else "dance"
	local size = Root.size()
	local w = Root.panelWidth(600)
	local h = math.min(640, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Grand Ballroom", 11, "caps", { LayoutOrder = 1 })
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
	local function fill(id: string)
		tab = id
		clear(body)
		if id == "exchange" then
			title.Text = "The Exchange"
			exchange(body)
		else
			title.Text = "Dance & Music"
			dance(content, body)
		end
	end
	local tabs = Theme.tabs(content, { { "dance", "Dance & music" }, { "exchange", "The Exchange" } }, tab, fill, 3)
	tabs.select(tab)
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 44)
	keys.LayoutOrder = 20
	keys.Parent = content
	local list = Theme.list(keys, 10, true)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(keys, "Stop dancing", false, function()
		GalaPanel.stop()
	end, 170).LayoutOrder = 1
	Theme.key(keys, "Close", false, function()
		Root.close(NAME)
	end, 140).LayoutOrder = 2
	fill(tab)
	Theme.fillRest(body)
	Root.open(NAME, group)
end

function GalaPanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

-- The poses: a row of moves along the foot of the screen while a photograph is framed.
function GalaPanel.poses()
	if Root.isOpen(POSES) then
		return
	end
	local w = math.min(620, Root.size().X - 24)
	-- (Along the top: photo mode's own bar is along the foot.)
	local group, content = Theme.glass(Root.panels, POSES, UDim2.fromOffset(w, 132), UDim2.new(0.5, 0, 0, Root.topClear() + 12), Vector2.new(0.5, 0))
	Theme.list(content, 4).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Strike a pose", 11, "caps", { LayoutOrder = 1 })
	moveGrid(content, 2, 64)
	Root.open(POSES, group)
end

function GalaPanel.closePoses()
	if Root.isOpen(POSES) then
		Root.close(POSES)
	end
end

return GalaPanel
