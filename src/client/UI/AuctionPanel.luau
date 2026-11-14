--!strict
-- The Grand Auction's screen (at the Library's rostrum): this week's lots, each with its time left,
-- the highest bid and who made it, the least the next bid may be, the last few bids, and keys to bid
-- that much (or a little more). Every figure is the server's (AuctionAsk "board"); a bid asks the
-- server, which takes it from your purse only if it stands and gives it back if it's beaten. The
-- notices: outbid (and your bid back), and a lot won (the piece is in your collection).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Directory = require(ReplicatedStorage.Shared.Directory)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local CurioArt = require(script.Parent.CurioArt)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local AuctionPanel = {}

local NAME = "GrandAuction"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local GREEN = Color3.fromRGB(120, 220, 150)
local rgb = Color3.fromRGB

-- A rounded frame with a hairline edge.
local function box(parent: Instance, name: string, colour: Color3, transparency: number, radius: number, edge: Color3?, edgeSeen: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = f
	if edge then
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = edge
		s.Transparency = edgeSeen or 0.6
		s.Parent = f
	end
	return f
end

-- A small capsule of words (a rarity, the time left, your standing).
local function chip(parent: Instance, name: string, text: string, colour: Color3, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundColor3 = colour
	l.BackgroundTransparency = 0.82
	l.BorderSizePixel = 0
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, 20)
	l.FontFace = Brand.Fonts.heavy
	l.TextSize = 11
	l.TextColor3 = colour
	l.Text = string.upper(text)
	l.LayoutOrder = order
	l.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = l
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 8)
	p.PaddingRight = UDim.new(0, 8)
	p.Parent = l
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = colour
	s.Transparency = 0.55
	s.Parent = l
	return l
end

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("AuctionAsk"):InvokeServer(request)
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

-- "2d 4h", "3h 12m", "45m" left.
function AuctionPanel.left(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d, h, m = seconds // 86400, (seconds // 3600) % 24, (seconds // 60) % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", math.max(1, m))
end

local function money(amount: number, currency: string): string
	return Rules.format(amount) .. " " .. currency
end

-- Set by Main: whether this is the guest's first time at the rostrum (the server's note:
-- AttractionAsk "guide").
AuctionPanel.firstTime = function(): boolean
	return false
end

function AuctionPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local w = Root.panelWidth(560)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 660))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Library", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "The Grand Auction", 26, "display", { LayoutOrder = 2 })
	Theme.text(content, "One of a kind, this week only. Your bid is taken from your purse when it stands, and given back in full if someone outbids you.", 12, "body", { LayoutOrder = 3, TextColor3 = C.smoke })
	-- The first time ever at the rostrum: how bidding works, in a box of its own (the server keeps
	-- the note, so it's shown once).
	task.spawn(function()
		if not AuctionPanel.firstTime() or not group.Parent then
			return
		end
		local spec = Directory.byId.auction
		local box = Instance.new("Frame")
		box.Name = "HowBidding"
		box.BackgroundColor3 = Color3.fromRGB(14, 30, 22)
		box.BackgroundTransparency = 0.15
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.Size = UDim2.new(1, 0, 0, 0)
		box.LayoutOrder = 4
		box.Parent = content
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 10)
		bc.Parent = box
		local bs = Instance.new("UIStroke")
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Color = spec.accent
		bs.Transparency = 0.4
		bs.Parent = box
		local bp = Instance.new("UIPadding")
		bp.PaddingTop = UDim.new(0, 8)
		bp.PaddingBottom = UDim.new(0, 8)
		bp.PaddingLeft = UDim.new(0, 12)
		bp.PaddingRight = UDim.new(0, 12)
		bp.Parent = box
		Theme.list(box, 4).HorizontalAlignment = Enum.HorizontalAlignment.Left
		Theme.text(box, "First time here  ·  how bidding works", 11, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = spec.accent })
		for n, line in spec.intro do
			Theme.text(box, "·  " .. line, 13, "body", {
				LayoutOrder = 1 + n,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				TextColor3 = C.bone,
			})
		end
	end)
	local rows = Instance.new("Frame")
	rows.Name = "Lots"
	rows.BackgroundTransparency = 1
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.Size = UDim2.new(1, 0, 0, 0)
	rows.LayoutOrder = 5
	rows.Parent = content
	Theme.list(rows, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(rows, "One moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })

	local fill: (board: { [string]: any }) -> ()
	local busy = false
	local function bid(lot: string, amount: number)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local r = ask({ op = "bid", lot = lot, amount = amount })
			busy = false
			if not r then
				Toast.show("Not just now", "The auction couldn't be reached. Try again in a moment.", 3)
				return
			end
			if r.ok ~= true then
				Toast.show("Not this time", tostring(r.why or "Not just now."), 4)
			else
				Theme.haptic()
				Toast.show("Your bid stands", "You're the highest bidder for now.", 3)
			end
			local again = ask({ op = "board" })
			if again and again.ok == true and group.Parent then
				fill(again)
			end
		end)
	end
	fill = function(board: { [string]: any })
		clear(rows)
		local lots = if type(board.lots) == "table" then board.lots else {}
		if #lots == 0 then
			Theme.text(rows, "No lots this week.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
			return
		end
		Theme.text(rows, string.format("This week's lots  ·  %d", #lots), 11, "caps", { LayoutOrder = 0, TextXAlignment = Enum.TextXAlignment.Left })
		local okWidth, measured = pcall(function()
			return rows.AbsoluteSize.X
		end)
		local width = if okWidth and type(measured) == "number" then measured else 0
		if width < 50 then
			width = Root.panelWidth(560) - 40
		end
		local STAGE = if width < 420 then 84 else 104
		for i, l in lots do
			-- (Build 82) A lot as an auction house shows it: the piece on a velvet stage with its lot
			-- number, then its name and grade, the bid that stands (large), who holds it and how
			-- long is left, your own standing, the last few bids, and the keys to bid.
			local currency = tostring(l.currency or "Gilt")
			local curio = if type(l.curio) == "string" then Curios.byId[l.curio] else nil
			local rarityColour = if curio then (Curios.RarityColour[(curio :: any).rarity] or GOLD) else GOLD
			local f = box(rows, "Lot", rgb(18, 14, 12), 0.08, 14, rarityColour, if l.mine then 0.25 else 0.6)
			f.AutomaticSize = Enum.AutomaticSize.Y
			f.Size = UDim2.new(1, 0, 0, 0)
			f.LayoutOrder = i
			local depth = Instance.new("UIGradient")
			depth.Rotation = 90
			depth.Color = ColorSequence.new(rgb(255, 255, 255), rgb(170, 160, 150))
			depth.Parent = f
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 12)
			pad.PaddingRight = UDim.new(0, 12)
			pad.PaddingTop = UDim.new(0, 12)
			pad.PaddingBottom = UDim.new(0, 12)
			pad.Parent = f
			-- The stage: velvet, the medallion on it, the lot's number under it.
			local stage = box(f, "Stage", rgb(70, 16, 32), 0.05, 12, rarityColour, 0.4)
			stage.Size = UDim2.fromOffset(STAGE, STAGE + 22)
			local sg = Instance.new("UIGradient")
			sg.Rotation = 90
			sg.Color = ColorSequence.new(rgb(150, 50, 80), rgb(40, 8, 20))
			sg.Parent = stage
			if curio then
				local m = CurioArt.medallion(stage, (curio :: any).id, STAGE - 20)
				m.AnchorPoint = Vector2.new(0.5, 0)
				m.Position = UDim2.new(0.5, 0, 0, 8)
			else
				local g = Instance.new("TextLabel")
				g.BackgroundTransparency = 1
				g.Size = UDim2.fromOffset(STAGE, STAGE - 8)
				g.TextScaled = true
				g.Text = tostring(l.glyph or "")
				g.Parent = stage
			end
			local lotNo = Instance.new("TextLabel")
			lotNo.Name = "LotNumber"
			lotNo.BackgroundTransparency = 1
			lotNo.AnchorPoint = Vector2.new(0.5, 1)
			lotNo.Position = UDim2.new(0.5, 0, 1, -4)
			lotNo.Size = UDim2.new(1, 0, 0, 16)
			lotNo.FontFace = Brand.Fonts.heavy
			lotNo.TextSize = 11
			lotNo.TextColor3 = GOLD
			lotNo.Text = string.format("LOT %d", i)
			lotNo.Parent = stage
			-- What's on the right of the stage.
			local info = Instance.new("Frame")
			info.Name = "Info"
			info.BackgroundTransparency = 1
			info.Position = UDim2.fromOffset(STAGE + 14, 0)
			info.Size = UDim2.new(1, -(STAGE + 14), 0, 0)
			info.AutomaticSize = Enum.AutomaticSize.Y
			info.Parent = f
			Theme.list(info, 6).HorizontalAlignment = Enum.HorizontalAlignment.Left
			Theme.text(info, tostring(l.name), 17, "display", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.bone })
			local chips = Instance.new("Frame")
			chips.Name = "Chips"
			chips.BackgroundTransparency = 1
			chips.Size = UDim2.new(1, 0, 0, 20)
			chips.LayoutOrder = 2
			chips.Parent = info
			Theme.list(chips, 6, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
			if curio then
				chip(chips, "Rarity", tostring((curio :: any).rarity), rarityColour, 1)
			end
			if l.seasonal then
				chip(chips, "Seasonal", "Seasonal", rgb(150, 210, 255), 2)
			end
			chip(chips, "Left", if l.settled then "Closed" else "Closes in " .. AuctionPanel.left(tonumber(l.left) or 0), if l.settled then C.smoke else rgb(255, 214, 140), 3)
			Theme.text(info, tostring(l.line or ""), 12, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
			-- The bid that stands.
			local high = tonumber(l.high) or 0
			Theme.text(info, if high > 0 then "Current bid" else "Opening bid", 10, "caps", { LayoutOrder = 4, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
			local figure = Theme.text(info, money(if high > 0 then high else tonumber(l.start) or 0, currency), 24, "bodyBold", { LayoutOrder = 5, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
			figure.FontFace = Brand.Fonts.figures
			local standing: string
			local standColour = C.bone
			if l.won then
				standing, standColour = "Sold to you: it's in your collection", GREEN
			elseif l.mine then
				standing, standColour = "You're the highest bidder", GREEN
			elseif high > 0 then
				standing = "Held by " .. tostring(l.by or "a guest")
			else
				standing = "No bids yet: be the first"
			end
			Theme.text(info, standing, 13, "bodyBold", { LayoutOrder = 6, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = standColour })
			local history = if type(l.history) == "table" then l.history else {}
			if #history > 0 then
				local parts = {}
				for k, h in history do
					if k > 3 then
						break
					end
					table.insert(parts, string.format("%s %s", tostring(h.name), Rules.format(tonumber(h.amount) or 0)))
				end
				Theme.text(info, "Lately: " .. table.concat(parts, "  ·  "), 11, "body", { LayoutOrder = 7, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
			end
			if not l.settled and not l.mine then
				local keys = Instance.new("Frame")
				keys.Name = "Keys"
				keys.BackgroundTransparency = 1
				keys.Size = UDim2.new(1, 0, 0, 42)
				keys.LayoutOrder = 8
				keys.Parent = info
				Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
				local least = tonumber(l.minNext) or 0
				local more = if currency == "Gems" then least + 10 else math.ceil(least * 1.1 / 100) * 100
				local keyW = math.clamp(math.floor((width - STAGE - 14 - 8) / 2), 120, 200)
				Theme.key(keys, "Bid " .. money(least, currency), true, function()
					bid(l.id, least)
				end, keyW)
				Theme.key(keys, "Bid " .. money(more, currency), false, function()
					bid(l.id, more)
				end, keyW)
			elseif l.mine and not l.settled then
				Theme.text(info, "Outbid, and your bid comes straight back to your purse.", 11, "body", { LayoutOrder = 8, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
			end
			-- (The card as tall as the taller of its stage and its words.)
			local sizer = Instance.new("Frame")
			sizer.Name = "Sizer"
			sizer.BackgroundTransparency = 1
			sizer.Size = UDim2.fromOffset(1, STAGE + 22)
			sizer.Parent = f
		end
	end
	local close = Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 20
	Root.open(NAME, group)
	task.spawn(function()
		local r = ask({ op = "board" })
		if not group.Parent then
			return
		end
		if r and r.ok == true then
			fill(r)
		else
			clear(rows)
			Theme.text(rows, "The auction couldn't be read just now. Try again in a moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
		end
	end)
end

function AuctionPanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

-- The auction's notices.
function AuctionPanel.start()
	Remotes.event("Empire").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "outbid" then
			Toast.show("Outbid: " .. tostring(m.name), string.format("Your %s is back in your purse.", money(tonumber(m.back) or 0, tostring(m.currency or "Gilt"))), 5)
		elseif m.op == "auctionWon" then
			Toast.show("Sold to you: " .. tostring(m.name), string.format("For %s. It's in your collection.", money(tonumber(m.amount) or 0, tostring(m.currency or "Gilt"))), 6)
		end
	end)
end

return AuctionPanel
