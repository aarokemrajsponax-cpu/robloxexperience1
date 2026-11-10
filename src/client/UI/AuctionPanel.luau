--!strict
-- The Grand Auction's screen (at the Library's rostrum): this week's lots, each with its time left,
-- the highest bid and who made it, the least the next bid may be, the last few bids, and keys to bid
-- that much (or a little more). Every figure is the server's (AuctionAsk "board"); a bid asks the
-- server, which takes it from your purse only if it stands and gives it back if it's beaten. The
-- notices: outbid (and your bid back), and a lot won (the piece is in your collection).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local AuctionPanel = {}

local NAME = "GrandAuction"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)

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
	local rows = Instance.new("Frame")
	rows.Name = "Lots"
	rows.BackgroundTransparency = 1
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.Size = UDim2.new(1, 0, 0, 0)
	rows.LayoutOrder = 4
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
		for i, l in lots do
			local f = Instance.new("Frame")
			f.Name = "Lot"
			f.BackgroundColor3 = Color3.fromRGB(26, 22, 18)
			f.BackgroundTransparency = 0.2
			f.AutomaticSize = Enum.AutomaticSize.Y
			f.Size = UDim2.new(1, 0, 0, 0)
			f.LayoutOrder = i
			f.Parent = rows
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = f
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 12)
			pad.PaddingRight = UDim.new(0, 12)
			pad.PaddingTop = UDim.new(0, 8)
			pad.PaddingBottom = UDim.new(0, 8)
			pad.Parent = f
			Theme.list(f, 3).VerticalAlignment = Enum.VerticalAlignment.Top
			local currency = tostring(l.currency or "Gilt")
			Theme.text(f, string.format("%s  %s%s", tostring(l.glyph or ""), tostring(l.name), if l.seasonal then "  ·  a seasonal lot" else ""), 15, "bodyBold", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
			Theme.text(f, tostring(l.line or ""), 12, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
			local high = tonumber(l.high) or 0
			local standing = if high > 0 then string.format("Highest: %s, by %s%s", money(high, currency), if l.mine then "you" else tostring(l.by or "a guest"), "") else string.format("No bids yet: it opens at %s", money(tonumber(l.start) or 0, currency))
			Theme.text(f, standing, 13, "bodyBold", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if l.mine then GOLD else C.bone })
			Theme.text(f, if l.settled then "Closed." else string.format("Closes in %s  ·  the least bid now is %s", AuctionPanel.left(tonumber(l.left) or 0), money(tonumber(l.minNext) or 0, currency)), 12, "body", { LayoutOrder = 4, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.lightGold })
			local history = if type(l.history) == "table" then l.history else {}
			if #history > 0 then
				local parts = {}
				for k, h in history do
					if k > 3 then
						break
					end
					table.insert(parts, string.format("%s %s", tostring(h.name), Rules.format(tonumber(h.amount) or 0)))
				end
				Theme.text(f, "Lately: " .. table.concat(parts, "  ·  "), 11, "body", { LayoutOrder = 5, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
			end
			if not l.settled and not l.mine then
				local keys = Instance.new("Frame")
				keys.Name = "Keys"
				keys.BackgroundTransparency = 1
				keys.Size = UDim2.new(1, 0, 0, 42)
				keys.LayoutOrder = 6
				keys.Parent = f
				Theme.list(keys, 8, true)
				local least = tonumber(l.minNext) or 0
				local more = if currency == "Gems" then least + 10 else math.ceil(least * 1.1 / 100) * 100
				Theme.key(keys, "Bid " .. money(least, currency), true, function()
					bid(l.id, least)
				end, 200)
				Theme.key(keys, "Bid " .. money(more, currency), false, function()
					bid(l.id, more)
				end, 200)
			end
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
