--!strict
-- The Gem Shop: what Gems buy, each at one fixed price, shown on its card before you choose. Five
-- shelves: Auras (a glow round you everyone sees), Titles (a line above your name), Surges (more
-- Gilt or XP for half an hour), Gilt (Gems changed for Gilt at a set rate) and Curios (the
-- Cabinet). Buying takes two taps: the price, then "Confirm", so nothing is ever bought by
-- accident. Nothing is random. The server decides everything; this screen only asks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local GemList = require(ReplicatedStorage.Shared.GemShop)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CurioArt = require(script.Parent.CurioArt)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local GemShopPanel = {}

local NAME = "GemShop"
local rgb = Color3.fromRGB
local HEAVY = Font.fromEnum(Enum.Font.GothamBlack)
local BODY = Font.fromEnum(Enum.Font.GothamMedium)
local GEM = rgb(150, 220, 255)
local shelf = "aura"

-- Set by Main: the Gem packs (Robux), in the Collection's Gems page.
GemShopPanel.getGems = function() end

local function ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("GemAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function format(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

function GemShopPanel.open(start: string?)
	if start then
		shelf = start
	end
	if Root.isOpen(NAME) then
		if start then
			return
		end
		Root.close(NAME)
		return
	end
	local size = Root.size()
	local w = math.min(800, size.X - 24)
	local h = math.min(640, size.Y - 40)
	local panel, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Gem Shop", 26, "display", { LayoutOrder = 1 })
	local balance = Theme.text(content, "💎 …", 16, "bodyBold", { LayoutOrder = 2, TextColor3 = GEM })
	local tabs = Instance.new("Frame")
	tabs.Name = "Shelves"
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(1, 0, 0, 34)
	tabs.LayoutOrder = 3
	tabs.Parent = content
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tl.Padding = UDim.new(0, 6)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabs
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 4
	scroll.Size = UDim2.new(1, 0, 1, -(26 + 22 + 34 + 44 + 48))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Brand.Colours.gold
	scroll.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(if w < 520 then 150 else 176, 196)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	local foot = Instance.new("Frame")
	foot.BackgroundTransparency = 1
	foot.Size = UDim2.new(1, 0, 0, 44)
	foot.LayoutOrder = 5
	foot.Parent = content
	Theme.list(foot, 8, true)
	Theme.key(foot, "Get Gems", false, function()
		Root.close(NAME)
		GemShopPanel.getGems()
	end, 180)
	Theme.key(foot, "Close", true, function()
		Root.close(NAME)
	end, 180)

	local view: { [string]: any }? = nil
	local confirming: string? = nil
	local render: () -> ()

	local function apply(result: any)
		if type(result) == "table" and result.ok == false then
			Toast.show("The Gem Shop", tostring(result.why), 3.5)
			return
		end
		if type(result) == "table" and result.owned then
			view = result
		else
			local fresh = ask({ op = "state" })
			if type(fresh) == "table" and fresh.ok then
				view = fresh
			end
		end
		if panel.Parent then
			render()
		end
	end

	local function drawTabs()
		for _, c in tabs:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, kind in GemList.Kinds do
			local lit = kind == shelf
			local b = Instance.new("TextButton")
			b.Name = "Shelf_" .. kind
			b.LayoutOrder = i
			b.AutoButtonColor = false
			b.AutomaticSize = Enum.AutomaticSize.X
			b.Size = UDim2.fromOffset(0, 32)
			b.BackgroundColor3 = if lit then GEM else rgb(28, 26, 30)
			b.FontFace = HEAVY
			b.TextSize = 12
			b.TextColor3 = if lit then rgb(10, 20, 30) else Brand.Colours.lightGold
			b.Text = string.upper((GemList.KindNames :: any)[kind] or kind)
			b.Parent = tabs
			corner(b, 16)
			local p = Instance.new("UIPadding")
			p.PaddingLeft = UDim.new(0, 12)
			p.PaddingRight = UDim.new(0, 12)
			p.Parent = b
			b.Activated:Connect(function()
				shelf = kind
				confirming = nil
				drawTabs()
				render()
			end)
		end
	end

	-- One card: its look, name, what it does, the price, and the key.
	local function card(order: number, id: string, glyph: string?, curioId: string?, name: string, line: string, price: number, keyText: string, keyLit: boolean, onKey: () -> ())
		local c = Instance.new("Frame")
		c.Name = "Item_" .. id
		c.LayoutOrder = order
		c.BackgroundColor3 = rgb(22, 22, 28)
		c.BackgroundTransparency = 0.1
		c.Parent = scroll
		corner(c, 10)
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = if keyLit then GEM else rgb(70, 80, 96)
		edge.Thickness = if keyLit then 2 else 1
		edge.Parent = c
		if curioId then
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.AnchorPoint = Vector2.new(0.5, 0)
			holder.Position = UDim2.new(0.5, 0, 0, 8)
			holder.Size = UDim2.fromOffset(56, 56)
			holder.Parent = c
			CurioArt.medallion(holder, curioId, 56, false)
		else
			local g = Instance.new("TextLabel")
			g.BackgroundTransparency = 1
			g.AnchorPoint = Vector2.new(0.5, 0)
			g.Position = UDim2.new(0.5, 0, 0, 8)
			g.Size = UDim2.fromOffset(56, 56)
			g.TextScaled = true
			g.Text = glyph or "💎"
			g.Parent = c
		end
		local n = Instance.new("TextLabel")
		n.BackgroundTransparency = 1
		n.Position = UDim2.fromOffset(8, 68)
		n.Size = UDim2.new(1, -16, 0, 34)
		n.FontFace = HEAVY
		n.TextSize = 14
		n.TextWrapped = true
		n.TextColor3 = rgb(250, 240, 220)
		n.Text = name
		n.Parent = c
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(8, 102)
		l.Size = UDim2.new(1, -16, 0, 44)
		l.FontFace = BODY
		l.TextSize = 11
		l.TextWrapped = true
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.TextColor3 = rgb(180, 176, 168)
		l.Text = line
		l.Parent = c
		local key = Instance.new("TextButton")
		key.Name = "Key"
		key.AnchorPoint = Vector2.new(0.5, 1)
		key.Position = UDim2.new(0.5, 0, 1, -8)
		key.Size = UDim2.new(1, -16, 0, 34)
		key.AutoButtonColor = false
		key.BackgroundColor3 = if keyLit then GEM else rgb(40, 44, 54)
		key.FontFace = HEAVY
		key.TextSize = 13
		key.TextColor3 = if keyLit then rgb(10, 20, 30) else rgb(236, 230, 214)
		key.Text = keyText
		key.Parent = c
		corner(key, 8)
		key.Activated:Connect(onKey)
		local _ = price
	end

	render = function()
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local v = view
		local gems = if v and type(v.gems) == "number" then v.gems else 0
		balance.Text = "💎 " .. format(gems) .. " Gems"
		if not v then
			return
		end
		local owned = if type(v.owned) == "table" then v.owned else {}
		local now = if type(v.now) == "number" then v.now else os.time()
		local function buy(id: string, op: string)
			if confirming ~= id then
				confirming = id
				render()
				task.delay(4, function()
					if confirming == id then
						confirming = nil
						if panel.Parent then
							render()
						end
					end
				end)
				return
			end
			confirming = nil
			task.spawn(function()
				local r = ask({ op = op, id = id })
				if type(r) == "table" and r.ok ~= false then
					Toast.show("The Gem Shop", "It's yours.", 2.5)
				end
				apply(r)
			end)
		end
		local function equip(kind: string, id: string)
			task.spawn(function()
				apply(ask({ op = "equip", kind = kind, id = id }))
			end)
		end
		if shelf == "curio" then
			local cab = if type(v.cabinet) == "table" and type(v.cabinet.items) == "table" then v.cabinet.items else {}
			for i, it in cab do
				local c = CurioList.byId[tostring(it.id)]
				if c then
					local price = tonumber(it.gems) or 0
					local sure = confirming == c.id
					card(i, c.id, nil, c.id, c.name, c.rarity .. " · " .. c.line, price, if sure then "CONFIRM · 💎 " .. format(price) else "💎 " .. format(price), sure, function()
						buy(c.id, "curio")
					end)
				end
			end
			return
		end
		local order = 0
		for _, item in GemList.List do
			if item.kind == shelf then
				order += 1
				local has = owned[item.id] == true
				local sure = confirming == item.id
				local keyText: string
				local lit = false
				local onKey: () -> ()
				if (item.kind == "aura" or item.kind == "title") and has then
					local wearing = (item.kind == "aura" and v.aura == item.id) or (item.kind == "title" and v.title == item.id)
					keyText = if wearing then "WEARING · TAKE OFF" else "WEAR"
					lit = wearing
					onKey = function()
						equip(item.kind, if wearing then "" else item.id)
					end
				else
					keyText = if sure then "CONFIRM · 💎 " .. format(item.gems) else "💎 " .. format(item.gems)
					lit = sure
					onKey = function()
						buy(item.id, "buy")
					end
				end
				local line = item.line
				if item.kind == "boost" then
					local untilAt = if item.style.boost == "xp" then v.xpUntil else v.giltUntil
					if type(untilAt) == "number" and untilAt > now then
						local left = untilAt - now
						line = line .. string.format(" On now: %d:%02d left (buying again adds 30 minutes).", left // 60, left % 60)
					end
				end
				card(order, item.id, item.glyph, nil, item.name, line, item.gems, keyText, lit, onKey)
			end
		end
	end

	drawTabs()
	render()
	Root.open(NAME, panel)
	task.spawn(function()
		apply(ask({ op = "state" }))
	end)
end

return GemShopPanel
