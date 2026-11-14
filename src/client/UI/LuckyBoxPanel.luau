--!strict
-- The Luxe Lucky Boxes' panel, opened at their showroom in the Foyer. The three boxes side by side
-- (drawn in their own colours); for the one chosen, everything that decides what comes out of it,
-- before the key to buy it:
--   * the guarantee and its counter: how many more opens until one of its rarity is certain;
--   * the odds of every brainrot in it (grouped by rarity, adding up to 100%), and how many of
--     each the guest already holds;
--   * the odds of it coming Gold, Diamond or Rainbow;
--   * the price, from Roblox, on the key.
-- Every open gives a brainrot: there is no empty result. The reveal is honest: the box glows in
-- the colour of the rarity that actually came, from the first moment, then opens to it (the
-- house's own find reveal, CurioReveal). A guest Roblox's policy restricts from paid random items
-- sees only why they're closed and where else brainrots come from.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Boxes = require(ReplicatedStorage.Shared.LuckyBoxes)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local Ease = require(ReplicatedStorage.Shared.Ease)
local CurioState = require(script.Parent.Parent.CurioState)
local Sound = require(script.Parent.Parent.Sound)
local CurioArt = require(script.Parent.CurioArt)
local CurioReveal = require(script.Parent.CurioReveal)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local LuckyBoxPanel = {}

local NAME = "LuckyBoxes"
local ROBUX = utf8.char(0xE002)
local C = Brand.Colours

local chosen = "gilded"
local state: { [string]: any }? = nil
local waiting = false -- Roblox's purchase window is open, or the box's receipt is on its way
local openKey: TextButton? = nil
local bodyRef: ScrollingFrame? = nil
local keysRef: Frame? = nil
local art: { [string]: Frame } = {}

local function number(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function boxState(id: string): { [string]: any }?
	if not state then
		return nil
	end
	for _, b in state.boxes or {} do
		if b.id == id then
			return b
		end
	end
	return nil
end

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = parent
end

local function frame(parent: Instance, name: string, size: UDim2, pos: UDim2, colour: Color3, z: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.ZIndex = z or 2
	f.Parent = parent
	return f
end

-- A gift box drawn in frames: its glow, body, lid, ribbon and bow, in the box's own colours.
function LuckyBoxPanel.art(parent: Instance, id: string, px: number): Frame
	local b = Boxes.Boxes[id]
	local holder = Instance.new("Frame")
	holder.Name = "BoxArt"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(px, px)
	holder.Parent = parent
	local halo = frame(holder, "Halo", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.55), b.glow, 1)
	halo.BackgroundTransparency = 0.55
	corner(halo, px)
	local hg = Instance.new("UIGradient")
	hg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 1) })
	hg.Parent = halo
	local body = frame(holder, "Body", UDim2.fromScale(0.62, 0.42), UDim2.fromScale(0.5, 0.66), b.colour, 3)
	corner(body, 3)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	shade.Parent = body
	local lid = frame(holder, "Lid", UDim2.fromScale(0.7, 0.13), UDim2.fromScale(0.5, 0.4), b.colour, 4)
	corner(lid, 3)
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	sheen.Parent = lid
	frame(holder, "RibbonV", UDim2.fromScale(0.1, 0.42), UDim2.fromScale(0.5, 0.66), b.ribbon, 5)
	frame(holder, "RibbonLid", UDim2.fromScale(0.1, 0.13), UDim2.fromScale(0.5, 0.4), b.ribbon, 6)
	for _, side in { -1, 1 } do
		local loop = frame(holder, "Bow", UDim2.fromScale(0.2, 0.12), UDim2.fromScale(0.5 + side * 0.1, 0.3), b.ribbon, 6)
		loop.Rotation = side * -24
		corner(loop, px)
	end
	local knot = frame(holder, "Knot", UDim2.fromScale(0.08, 0.08), UDim2.fromScale(0.5, 0.32), b.ribbon, 7)
	corner(knot, px)
	return holder
end

local function sectionLabel(parent: Instance, text: string, order: number, colour: Color3?)
	Theme.text(parent, text, 11, "caps", { LayoutOrder = order, TextColor3 = colour or C.lightGold, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 16) })
end

-- One brainrot's row in the odds: its medallion, name, rarity, how many held, its chance.
local function oddsRow(parent: Instance, o: { [string]: any }, order: number)
	local c = CurioList.byId[o.id]
	local row = Instance.new("Frame")
	row.Name = "Odds_" .. tostring(o.id)
	row.BackgroundColor3 = Color3.fromRGB(20, 18, 22)
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -6, 0, 38)
	row.LayoutOrder = order
	row.Parent = parent
	corner(row, 6)
	local medal = CurioArt.medallion(row, o.id, 30)
	medal.AnchorPoint = Vector2.new(0, 0.5)
	medal.Position = UDim2.new(0, 6, 0.5, 0)
	local name = Theme.text(row, if c then c.name else tostring(o.id), 13, "bodyBold", {
		Name = "Name",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 44, 0.5, -7),
		Size = UDim2.new(1, -130, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	name.TextColor3 = C.bone
	local held = tonumber(o.held) or 0
	Theme.text(row, string.format("%s%s", tostring(o.rarity), if held > 0 then string.format("  ·  You hold %d", held) else "  ·  New to you"), 11, "body", {
		Name = "Sub",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 44, 0.5, 8),
		Size = UDim2.new(1, -130, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = CurioList.RarityColour[o.rarity] or C.smoke,
	})
	Theme.text(row, Boxes.percent(tonumber(o.chance) or 0), 16, "display", {
		Name = "Chance",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(76, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.lightGold,
	})
end

local function openText(b: { [string]: any }?): string
	if waiting then
		return "Waiting for Roblox"
	elseif not b or not b.ready then
		return "Not on sale yet"
	end
	return string.format("Open  %s %s", ROBUX, number(tonumber(b.price) or 0))
end

local render: () -> ()

local function pick(id: string)
	if id == chosen then
		return
	end
	chosen = id
	Theme.playClick()
	render()
end

local function buy()
	local b = boxState(chosen)
	if waiting or not b or not b.ready then
		return
	end
	local r = CurioState.ask({ op = "luckyOpen", id = chosen })
	if type(r) == "table" and r.prompted then
		waiting = true
		if openKey then
			openKey.Text = Caps(openText(b))
		end
	elseif type(r) == "table" and type(r.why) == "string" then
		Toast.show("Luxe Lucky Boxes", r.why, 5)
	end
end

render = function()
	local s = state
	if not s or not Root.isOpen(NAME) then
		return
	end
	local body = bodyRef
	if not body or not body.Parent then
		return
	end
	body:ClearAllChildren()
	local list = Theme.list(body, 10)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	local keys = keysRef
	if keys then
		keys:ClearAllChildren()
		Theme.list(keys, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	local function closeKey()
		if keys then
			Theme.key(keys, "Close", false, function()
				LuckyBoxPanel.close()
			end, 120).LayoutOrder = 2
		end
	end
	if not s.allowed then
		Theme.text(body, tostring(s.why or "Lucky Boxes aren't available on your account."), 14, "body", { LayoutOrder = 1, TextWrapped = true, TextColor3 = C.bone })
		closeKey()
		return
	end
	-- The three boxes, side by side.
	local row = Instance.new("Frame")
	row.Name = "Boxes"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 132)
	row.LayoutOrder = 1
	row.Parent = body
	local rl = Theme.list(row, 8, true)
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	art = {}
	for i, id in Boxes.Order do
		local def = Boxes.Boxes[id]
		local bs = boxState(id)
		local card = Instance.new("TextButton")
		card.Name = "Box_" .. id
		card.Text = ""
		card.AutoButtonColor = false
		card.BackgroundColor3 = if id == chosen then Color3.fromRGB(40, 30, 28) else Color3.fromRGB(18, 16, 20)
		card.BackgroundTransparency = 0.15
		card.BorderSizePixel = 0
		card.Size = UDim2.new(1 / 3, -6, 1, 0)
		card.LayoutOrder = i
		card.Parent = row
		corner(card, 10)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = if id == chosen then def.glow else Color3.fromRGB(70, 60, 50)
		stroke.Thickness = if id == chosen then 2 else 1
		stroke.Parent = card
		local a = LuckyBoxPanel.art(card, id, 70)
		a.AnchorPoint = Vector2.new(0.5, 0)
		a.Position = UDim2.new(0.5, 0, 0, 4)
		art[id] = a
		Theme.text(card, def.short, 15, "display", { Name = "Name", Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 18), TextColor3 = if id == chosen then def.glow else C.bone })
		Theme.text(card, if bs and bs.ready then string.format("%s %s", ROBUX, number(tonumber(bs.price) or def.price)) else "Not on sale yet", 12, "bodyBold", { Name = "Price", Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 14), TextColor3 = C.lightGold })
		local tier = Theme.text(card, string.format("%s or better", def.odds[1].rarity), 11, "body", { Name = "Line", Position = UDim2.fromOffset(4, 113), Size = UDim2.new(1, -8, 0, 14), TextColor3 = C.smoke })
		Theme.fit(tier, 11, 8)
		card.Activated:Connect(function()
			pick(id)
		end)
	end
	local b = boxState(chosen)
	local def = Boxes.Boxes[chosen]
	if not b then
		return
	end
	-- The guarantee, and its counter.
	local pity = b.pity or {}
	local at = tonumber(pity.at) or def.pity.at
	local left = tonumber(pity.left) or at
	local g = Instance.new("Frame")
	g.Name = "Guarantee"
	g.BackgroundColor3 = Color3.fromRGB(30, 24, 18)
	g.BackgroundTransparency = 0.2
	g.BorderSizePixel = 0
	g.Size = UDim2.new(1, 0, 0, 66)
	g.LayoutOrder = 2
	g.Parent = body
	corner(g, 8)
	Theme.text(g, if left <= 1 then string.format("Your next open is a sure %s or better", tostring(pity.rarity or def.pity.rarity)) else string.format("%s or better, guaranteed within %d opens", tostring(pity.rarity or def.pity.rarity), left), 13, "bodyBold", {
		Name = "Line",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.bone,
	})
	local track = frame(g, "Track", UDim2.new(1, -24, 0, 6), UDim2.new(0.5, 0, 0, 34), Color3.fromRGB(60, 52, 44), 2)
	corner(track, 3)
	local done = math.clamp((at - left) / math.max(1, at - 1), 0, 1)
	local fill = frame(track, "Fill", UDim2.fromScale(done, 1), UDim2.fromScale(done / 2, 0.5), def.glow, 3)
	corner(fill, 3)
	Theme.text(g, string.format("If %d opens in a row bring no %s or better, the next one does (by the same odds among those).", at - 1, tostring(pity.rarity or def.pity.rarity)), 10, "body", {
		Name = "How",
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 24),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.smoke,
	})
	-- The odds of every brainrot in it, by rarity (rarest first), adding up to 100%.
	sectionLabel(body, "What's inside  ·  every open gives one", 3)
	local scroll = Instance.new("Frame")
	scroll.Name = "Odds"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticSize = Enum.AutomaticSize.Y
	scroll.Size = UDim2.new(1, 0, 0, 0)
	scroll.LayoutOrder = 4
	scroll.Parent = body
	Theme.list(scroll, 4).VerticalAlignment = Enum.VerticalAlignment.Top
	local order = 0
	local lastRarity = nil
	local tiers: { [string]: number } = {}
	for _, t in def.odds do
		tiers[t.rarity] = t.chance
	end
	for _, o in b.odds or {} do
		if o.rarity ~= lastRarity then
			lastRarity = o.rarity
			order += 1
			sectionLabel(scroll, string.format("%s  ·  %s", tostring(o.rarity), Boxes.percent(tiers[o.rarity] or 0)), order, CurioList.RarityColour[o.rarity])
		end
		order += 1
		oddsRow(scroll, o, order)
	end
	-- Its mutations.
	local mut = b.mut or {}
	Theme.text(body, string.format("Each one comes Gold %s  ·  Diamond %s  ·  Rainbow %s  ·  plain %s",
		Boxes.percent((tonumber(mut.gold) or 0) * 100), Boxes.percent((tonumber(mut.diamond) or 0) * 100),
		Boxes.percent((tonumber(mut.rainbow) or 0) * 100), Boxes.percent((tonumber(mut.plain) or 0) * 100)), 11, "body", {
		Name = "Mutations",
		LayoutOrder = 5,
		TextWrapped = true,
		TextColor3 = C.bone,
	})
	Theme.text(body, "Every brainrot here is also found free at the tables. For a sure thing, the Cabinet sells the exact curio you choose.", 11, "body", {
		Name = "Free",
		LayoutOrder = 6,
		TextWrapped = true,
		TextColor3 = C.smoke,
	})
	if keys then
		local ok = Theme.key(keys, openText(b), true, buy, 220)
		ok.LayoutOrder = 1
		openKey = ok
	end
	closeKey()
end

-- Opens the panel (at the showroom) and asks the server for the boxes.
function LuckyBoxPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local w = Root.panelWidth(560)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 0))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Foyer  ·  Luxe Lucky Boxes", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "Pick a box", 26, "display", { LayoutOrder = 2 })
	Theme.text(content, "Every box gives one brainrot. The odds of each are shown below, and they add up to 100%.", 13, "body", { LayoutOrder = 3, TextWrapped = true, TextColor3 = C.smoke })
	-- The boxes, the guarantee and the odds scroll; the keys stay in view beneath them.
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, 0, 0, math.clamp(Root.viewport().Y - 310, 150, 460))
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = C.lightGold
	body.LayoutOrder = 10
	body.Parent = content
	bodyRef = body
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 44)
	keys.LayoutOrder = 11
	keys.Parent = content
	keysRef = keys
	Theme.text(body, "One moment", 13, "body", { TextColor3 = C.smoke })
	Root.open(NAME, group, function()
		openKey = nil
		bodyRef = nil
		keysRef = nil
		art = {}
	end, true)
	Sound.play("shimmer", 0.4)
	task.spawn(LuckyBoxPanel.refresh)
end

-- Asks the server for the boxes again (prices, the counters, what's held) and redraws.
function LuckyBoxPanel.refresh()
	local r = CurioState.ask({ op = "luckyState" })
	if type(r) == "table" and r.ok then
		state = r
		render()
	end
end

-- The box that was bought has opened: it glows in the colour of what came (the rarity that
-- really came, from the first moment), shakes, bursts, then the find's own reveal shows it.
function LuckyBoxPanel.reveal(result: { [string]: any })
	waiting = false
	local id = if type(result.id) == "string" then result.id else nil
	local boxId = if type(result.box) == "string" and Boxes.Boxes[result.box] then result.box else chosen
	if not id or not CurioList.byId[id] then
		return
	end
	local def = Boxes.Boxes[boxId]
	local colour = CurioList.RarityColour[tostring(result.rarity)] or def.glow
	local line = string.format("From %s", def.name)
	if result.new then
		line ..= "  ·  New to your collection"
	elseif type(result.stars) == "number" and result.stars > 1 then
		line ..= string.format("  ·  ★%d now", result.stars)
	end
	if type(result.pityLeft) == "number" then
		line ..= string.format("  ·  Guarantee in %d", result.pityLeft)
	end
	-- The opening, on the screen's middle: the box, lit in the rarity's colour, shaking, then a flash.
	local shade = Instance.new("Frame")
	shade.Name = "LuckyOpening"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(6, 5, 8)
	shade.BackgroundTransparency = 0.25
	shade.BorderSizePixel = 0
	shade.ZIndex = 80
	shade.Parent = Root.toasts
	local boxArt = LuckyBoxPanel.art(shade, boxId, 220)
	boxArt.AnchorPoint = Vector2.new(0.5, 0.5)
	boxArt.Position = UDim2.fromScale(0.5, 0.5)
	for _, d in boxArt:GetDescendants() do
		if d:IsA("Frame") then
			d.ZIndex += 80
		end
	end
	local halo = boxArt:FindFirstChild("Halo") :: Frame?
	if halo then
		halo.BackgroundColor3 = colour
		halo.ZIndex = 80
	end
	local caption = Theme.text(shade, string.upper(tostring(result.rarity or "")), 22, "display", {
		Name = "Rarity",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 130),
		Size = UDim2.fromOffset(400, 30),
		TextColor3 = colour,
		TextTransparency = 1,
		ZIndex = 82,
	})
	Sound.play("crystal", 0.5)
	local from = os.clock()
	local beat: RBXScriptConnection? = nil
	beat = RunService.RenderStepped:Connect(function()
		local t = os.clock() - from
		local shake = math.min(1, t / 1.4)
		boxArt.Rotation = math.sin(t * 38) * 7 * shake
		local grow = 1 + 0.12 * shake
		boxArt.Size = UDim2.fromOffset(220 * grow, 220 * grow)
		if halo then
			halo.BackgroundTransparency = 0.55 - 0.4 * shake
		end
	end)
	task.delay(0.7, function()
		Ease.play(caption, Ease.info(0.4, Enum.EasingStyle.Quad), { TextTransparency = 0 })
	end)
	task.delay(1.5, function()
		if beat then
			beat:Disconnect()
		end
		Sound.play("bellStrike", 0.6)
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = colour
		flash.BackgroundTransparency = 0.2
		flash.BorderSizePixel = 0
		flash.ZIndex = 90
		flash.Parent = shade
		Ease.play(flash, Ease.info(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		boxArt.Visible = false
		caption.Visible = false
		Ease.play(shade, Ease.info(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		task.delay(0.55, function()
			shade:Destroy()
		end)
		CurioReveal.show(id, line, 0, if type(result.mut) == "string" then result.mut else nil)
		task.spawn(LuckyBoxPanel.refresh)
	end)
end

-- Roblox's purchase window closed without a purchase: the key is ready again.
local function promptClosed(_userId: number, _productId: number, purchased: boolean)
	if not purchased and waiting then
		waiting = false
		render()
	end
end

function LuckyBoxPanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

function LuckyBoxPanel.close()
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
end

function LuckyBoxPanel.start()
	MarketplaceService.PromptProductPurchaseFinished:Connect(promptClosed)
end

return LuckyBoxPanel
