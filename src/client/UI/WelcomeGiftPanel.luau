--!strict
-- (Build 93) The house's welcome gift (server/WelcomeGift): in a new guest's first minute, three
-- brainrots side by side, each with its medallion, its line and the Gilt it earns an hour. Choose
-- one: it joins your squad at once and its tip jar starts filling. The server decides what can be
-- had; this card only names the one chosen. "Not now" keeps it: the Concierge offers it again
-- next time you come in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CurioArt = require(script.Parent.CurioArt)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local WelcomeGiftPanel = {}

local NAME = "WelcomeGift"
local C = Brand.Colours

local function commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

local busy = false

local function choose(id: string)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local ok, r = pcall(function()
			return Remotes.func("WelcomeGiftAsk"):InvokeServer({ op = "claim", id = id })
		end)
		busy = false
		if ok and type(r) == "table" and r.ok then
			-- (The reveal comes from the server, as for any curio that comes to you.)
			Root.close(NAME)
		elseif ok and type(r) == "table" and type(r.why) == "string" then
			Toast.show("A welcome gift", r.why, 3)
			Root.close(NAME)
		else
			Toast.show("A welcome gift", "One moment, then choose again.", 3)
		end
	end)
end

-- Shows the three (as the server sent them). Nothing happens if it's already open.
function WelcomeGiftPanel.offer(m: any)
	if type(m) ~= "table" or type(m.choices) ~= "table" or #m.choices == 0 or Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = Root.panelWidth(720)
	-- (On a phone the words are set larger: the card is given the height they need there.)
	local compact = Root.scale < 0.95
	local h = math.min(if compact then 540 else 400, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "A welcome gift from the house", 26, "display", { LayoutOrder = 1 })
	Theme.text(content, "Choose your first brainrot. It joins your squad and earns Gilt for you every hour, even while you're away. Free, and yours to keep.", 13, "body", {
		LayoutOrder = 2,
		TextColor3 = C.smoke,
		TextWrapped = true,
	})
	local row = Instance.new("Frame")
	row.Name = "Choices"
	row.BackgroundTransparency = 1
	row.LayoutOrder = 3
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Size = UDim2.new(1, 0, 0, 0)
	row.Parent = content
	local rl = Theme.list(row, 10, true)
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rl.VerticalAlignment = Enum.VerticalAlignment.Top
	local n = math.min(3, #m.choices)
	local cardW = math.floor((w - 48 - 10 * (n - 1)) / n)
	for i, o in m.choices do
		if i > 3 or type(o) ~= "table" or type(o.id) ~= "string" then
			continue
		end
		local id = o.id :: string
		local card = Instance.new("Frame")
		card.Name = "Gift_" .. id
		card.LayoutOrder = i
		card.BackgroundColor3 = Color3.fromRGB(26, 22, 20)
		card.BackgroundTransparency = 0.1
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.Size = UDim2.fromOffset(cardW, 0)
		card.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = C.gold
		edge.Transparency = 0.45
		edge.Parent = card
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = card
		local cl = Theme.list(card, 6)
		cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		cl.VerticalAlignment = Enum.VerticalAlignment.Top
		local holder = Instance.new("Frame")
		holder.Name = "Medal"
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = 1
		-- (On a phone, where the words are set larger: a smaller medallion and no one-liner, so the
		-- whole card fits on the screen with its keys.)
		local medal = if compact then 56 else 76
		holder.Size = UDim2.fromOffset(medal, medal)
		holder.Parent = card
		pcall(CurioArt.medallion, holder, id, medal)
		Theme.text(card, tostring(o.name or id), 15, "bodyMedium", { LayoutOrder = 2, TextColor3 = C.bone, TextWrapped = true })
		if not compact then
			Theme.text(card, tostring(o.line or ""), 12, "body", { LayoutOrder = 3, TextColor3 = C.smoke, TextWrapped = true })
		end
		local rate = tonumber(o.rate) or 0
		if rate > 0 then
			Theme.text(card, "+" .. commas(rate) .. " Gilt an hour", 13, "caps", { LayoutOrder = 4, TextColor3 = C.lightGold })
		end
		Theme.key(card, "Choose", true, function()
			choose(id)
		end, math.min(160, cardW - 20)).LayoutOrder = 5
	end
	local foot = Instance.new("Frame")
	foot.BackgroundTransparency = 1
	foot.LayoutOrder = 4
	foot.AutomaticSize = Enum.AutomaticSize.Y
	foot.Size = UDim2.new(1, 0, 0, 0)
	foot.Parent = content
	Theme.list(foot, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(foot, "Not now", false, function()
		Toast.show("A welcome gift", "The Concierge keeps it for you: it's offered again next time you come in.", 4)
		Root.close(NAME)
	end, 160)
	Root.open(NAME, group)
end

return WelcomeGiftPanel
