--!strict
-- Steal a Luxe's board (at the lectern in the Luxe Lounge, or Upgrades in the residence): a bigger
-- bag, quiet shoes and the banker's cut, each with what it does now, what the next does and its
-- price in Gilt; Stride (trained on the Lounge's treadmills: the level, the points, the next); the
-- golden treadmill (double Stride) for Gems; and the guest's records. Every figure and price is the
-- server's (AttractionAsk "state"); buying asks the server, which takes the price or says why not.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local LuxePanel = {}

local NAME = "LuxeBoard"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)

local UPGRADES = {
	{ key = "bag", name = "A bigger bag" },
	{ key = "quiet", name = "Quiet shoes" },
	{ key = "banker", name = "The banker's cut" },
	{ key = "hands", name = "Quick hands" },
}

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer(request)
	end)
	if ok and type(r) == "table" then
		return r
	end
	return nil
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- One upgrade: its name and what it does now, what the next does, and its price on the key.
local function upgradeRow(parent: Instance, order: number, name: string, u: { [string]: any }, buy: () -> ()): Frame
	local f = Instance.new("Frame")
	f.Name = "Upgrade"
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 52)
	f.LayoutOrder = order
	f.Parent = parent
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Size = UDim2.new(1, -150, 1, 0)
	words.Parent = f
	Theme.list(words, 1).VerticalAlignment = Enum.VerticalAlignment.Center
	Theme.text(words, string.format("%s  ·  %d of %d", name, tonumber(u.level) or 1, tonumber(u.top) or 1), 14, "bodyBold", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None })
	Theme.text(words, "Now: " .. tostring(u.now or ""), 12, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke, Size = UDim2.new(1, 0, 0, 15), AutomaticSize = Enum.AutomaticSize.None })
	if u.nextLine then
		Theme.text(words, "Next: " .. tostring(u.nextLine), 12, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.lightGold, Size = UDim2.new(1, 0, 0, 15), AutomaticSize = Enum.AutomaticSize.None })
	end
	local price = tonumber(u.price)
	local key = Theme.key(f, if price then Rules.format(price) .. " Gilt" else "At its best", price ~= nil, function()
		if price then
			buy()
		end
	end, 140)
	key.AnchorPoint = Vector2.new(1, 0.5)
	key.Position = UDim2.new(1, 0, 0.5, 0)
	if not price then
		key.Active = false
		key.AutoButtonColor = false
	end
	return f
end

function LuxePanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local w = Root.panelWidth(520)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 600))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Steal a Luxe", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "The Upgrades", 26, "display", { LayoutOrder = 2 })
	Theme.text(content, "Carry more, be seen less, lift quicker, bank more of it. Your Fortune grows with every haul.", 13, "body", { LayoutOrder = 3, TextColor3 = C.smoke })
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.Size = UDim2.new(1, 0, 0, 0)
	rows.LayoutOrder = 4
	rows.Parent = content
	Theme.list(rows, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	local loading = Theme.text(rows, "One moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })

	local fill: (u: { [string]: any }) -> ()
	local busy = false
	local function buy(request: { [string]: any })
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local r = ask(request)
			busy = false
			if not r then
				Toast.show("Not just now", "The house couldn't be reached. Try again in a moment.", 3)
			elseif r.ok ~= true then
				Toast.refused(r)
			elseif type(r.upgrades) == "table" and group.Parent then
				Theme.haptic()
				Toast.show("Yours", "The upgrade is yours, for good.", 2.5)
				fill(r.upgrades)
			end
		end)
	end

	fill = function(u: { [string]: any })
		clear(rows)
		for i, spec in UPGRADES do
			local row = u[spec.key]
			if type(row) == "table" then
				upgradeRow(rows, i, spec.name, row, function()
					buy({ op = "act", id = "luxe", act = "upgrade", what = spec.key })
				end)
			end
		end
		Theme.hairline(rows, UDim.new(0, 120), 10)
		local st = if type(u.stride) == "table" then u.stride else {}
		local level, top = tonumber(st.level) or 1, tonumber(st.top) or 1
		local points, nextAt = tonumber(st.points) or 0, tonumber(st.next)
		Theme.text(rows, string.format("Stride  ·  level %d of %d", level, top), 14, "bodyBold", { LayoutOrder = 11, TextXAlignment = Enum.TextXAlignment.Left })
		Theme.text(rows, string.format("%d%% faster in the residence  ·  %s", tonumber(st.faster) or 0, if nextAt then string.format("%d of %d points to the next level", points, nextAt) else "the highest level"), 12, "body", { LayoutOrder = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
		Theme.text(rows, "Walk the treadmills in the Luxe Lounge to train it: a point a second.", 12, "body", { LayoutOrder = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
		local gems = tonumber(u.goldenGems) or 0
		local golden = Instance.new("Frame")
		golden.Name = "Golden"
		golden.BackgroundTransparency = 1
		golden.Size = UDim2.new(1, 0, 0, 46)
		golden.LayoutOrder = 14
		golden.Parent = rows
		local gw = Theme.text(golden, "The golden treadmill: double Stride, for good", 13, "bodyBold", { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -150, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextColor3 = GOLD })
		gw.Position = UDim2.fromOffset(0, 0)
		local gk = Theme.key(golden, if u.golden then "Yours" else string.format("%d Gems", gems), not u.golden, function()
			if not u.golden then
				buy({ op = "act", id = "luxe", act = "golden" })
			end
		end, 140)
		gk.AnchorPoint = Vector2.new(1, 0.5)
		gk.Position = UDim2.new(1, 0, 0.5, 0)
		Theme.hairline(rows, UDim.new(0, 120), 15)
		Theme.text(rows, string.format("Hauls banked: %d  ·  in all: %s  ·  best: %s", tonumber(u.hauls) or 0, Rules.format(tonumber(u.banked) or 0), Rules.format(tonumber(u.best) or 0)), 12, "body", { LayoutOrder = 16, TextColor3 = C.lightGold })
		-- (Build 82) The Collection: the guest's rank, and every wing's set with its reward.
		local col = if type(u.collection) == "table" then u.collection else nil
		if col then
			Theme.hairline(rows, UDim.new(0, 120), 17)
			Theme.text(rows, "The Collection", 11, "caps", { LayoutOrder = 18 })
			local rankNext = tonumber(col.nextAt)
			Theme.text(rows, string.format("Rank: %s", tostring(col.rankName or "")), 18, "display", { LayoutOrder = 19, TextColor3 = GOLD })
			Theme.text(rows, if rankNext then string.format("%s banked of the %s for %s", Rules.format(tonumber(col.banked) or 0), Rules.format(rankNext), tostring(col.nextName or "the next rank")) else "The highest rank there is.", 12, "body", { LayoutOrder = 20, TextColor3 = C.smoke })
			Theme.text(rows, "Bank every piece of a wing once and its set pays out, once. Limited pieces come and go with their holiday, and aren't in the sets.", 12, "body", { LayoutOrder = 21, TextColor3 = C.smoke })
			for i, w in (if type(col.wings) == "table" then col.wings else {}) :: { any } do
				local line = Instance.new("Frame")
				line.Name = "Set" .. tostring(w.wing)
				line.BackgroundTransparency = 1
				line.Size = UDim2.new(1, 0, 0, 22)
				line.LayoutOrder = 21 + i
				line.Parent = rows
				local have, of = tonumber(w.have) or 0, tonumber(w.of) or 0
				local name = Theme.text(line, string.format("%s  ·  %d / %d", tostring(w.name), have, of), 13, "bodyBold", { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -150, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextColor3 = if w.paid then GOLD else C.bone })
				name.Position = UDim2.fromOffset(0, 0)
				local reward = Theme.text(line, if w.paid then "Set complete" else string.format("Set: +%s Gilt", Rules.format(tonumber(w.gilt) or 0)), 12, "body", { TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 146, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextColor3 = if w.paid then GOLD else C.smoke })
				reward.AnchorPoint = Vector2.new(1, 0)
				reward.Position = UDim2.new(1, 0, 0, 0)
			end
		end
	end

	local close = Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 40
	Root.open(NAME, group)
	task.spawn(function()
		local r = ask({ op = "state", id = "luxe" })
		if not group.Parent then
			return
		end
		if r and r.ok == true and type(r.upgrades) == "table" then
			fill(r.upgrades)
		else
			loading.Text = "The board couldn't be read just now. Try again in a moment."
		end
	end)
end

function LuxePanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

return LuxePanel
