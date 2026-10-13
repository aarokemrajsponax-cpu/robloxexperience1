--!strict
-- Lights Out's sabotage, on the guest's screen: the panel (the tables still lit, each with its
-- guest, its felt and a Shield if it has one; then what to send, each with its price in Robux, or
-- "1 held" for one already paid for), and what lands on you: a Blackout's dark felt, Butterfingers'
-- frost, a Parcel Bomb's warning, a Shield that held. The room hears every one, with its sender.
--
-- Nothing here decides anything: the server checks every request (the evening, the table, the
-- count) before Roblox's purchase window opens, and sends what happens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Fade = require(script.Parent.Fade)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local SabotagePanel = {}

local C = Brand.Colours
local ROBUX = utf8.char(0xE002)
local rgb = Color3.fromRGB
local NAME = "Sabotage"

-- Set by BallroomView: send a request to the Ballroom.
SabotagePanel.send = function(_message: { [string]: any }) end

export type Kind = { id: string, glyph: string, name: string, line: string, colour: Color3 }
SabotagePanel.Kinds = {
	{ id = "bomb", glyph = "💣", name = "Parcel Bomb", line = "Six lookalikes on their felt in 2 s", colour = rgb(255, 120, 70) },
	{ id = "blackout", glyph = "🌑", name = "Blackout", line = "Their felt goes dark for 6 s", colour = rgb(150, 120, 255) },
	{ id = "freeze", glyph = "🧊", name = "Butterfingers", line = "They can't file a piece for 4 s", colour = rgb(120, 210, 255) },
} :: { Kind }
local SHIELD: Kind = { id = "shield", glyph = "🛡️", name = "Shield", line = "Stops the next one sent at you", colour = rgb(255, 214, 110) }
local byId: { [string]: Kind } = { shield = SHIELD }
for _, k in SabotagePanel.Kinds do
	byId[k.id] = k
end

local chosen: number? = nil -- the table aimed at

local function corner(f: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = f
end

local function costText(kind: string, info: { [string]: any }): string
	local credits = if type(info.credits) == "table" then info.credits else {}
	local prices = if type(info.prices) == "table" then info.prices else {}
	local held = credits[kind]
	if type(held) == "number" and held > 0 then
		return string.format("%d held", held)
	end
	local p = prices[kind]
	return if type(p) == "number" and p > 0 then ROBUX .. " " .. tostring(p) else "not on sale yet"
end

function SabotagePanel.close()
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
end

function SabotagePanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

-- The panel, from the server's answer (op "sabotageInfo").
function SabotagePanel.show(info: { [string]: any })
	SabotagePanel.close()
	local targets: { { [string]: any } } = if type(info.targets) == "table" then info.targets else {}
	local mine = if type(info.mine) == "number" then info.mine else nil
	local left = if type(info.left) == "number" then info.left else 0
	local others = {}
	for _, t in targets do
		if t.seat ~= mine then
			table.insert(others, t)
		end
	end
	-- (The fullest felt first: the one nearest going out is the one worth pushing.)
	table.sort(others, function(a, b)
		if (a.standIn == true) ~= (b.standIn == true) then
			return b.standIn == true
		end
		return (a.felt or 0) > (b.felt or 0)
	end)
	if chosen == nil or not (function()
		for _, t in others do
			if t.seat == chosen then
				return true
			end
		end
		return false
	end)() then
		chosen = if others[1] then others[1].seat else nil
	end
	local size = Root.size()
	local w = math.min(460, size.X - 24)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 0), UDim2.new(0.5, 0, 0.5, 10), Vector2.new(0.5, 0.5))
	Theme.fitHeight(group, content)
	local pad = content:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingTop = UDim.new(0, 18)
		pad.PaddingBottom = UDim.new(0, 16)
		pad.PaddingLeft = UDim.new(0, 18)
		pad.PaddingRight = UDim.new(0, 18)
	end
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Sabotage", 24, "display", { LayoutOrder = 1 })
	Theme.text(content, if info.playing == true then string.format("Hit a rival's table. The whole room sees who sent it. %d left for you this evening.", left) else "Sabotage is for an evening in play.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke })
	-- The tables still lit.
	local list = Instance.new("ScrollingFrame")
	list.Name = "Targets"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.LayoutOrder = 3
	list.Size = UDim2.new(1, 0, 0, math.min(6, math.max(1, #others)) * 40)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 4
	list.Parent = content
	local ll = Theme.list(list, 4)
	ll.VerticalAlignment = Enum.VerticalAlignment.Top
	local rows: { [number]: TextButton } = {}
	local function paint()
		for seat, r in rows do
			local on = seat == chosen
			r.BackgroundColor3 = if on then rgb(70, 52, 22) else rgb(22, 22, 28)
			local st = r:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = if on then 0 else 0.6
			end
		end
	end
	if #others == 0 then
		Theme.text(list, "No other lamps are lit.", 14, "body", { TextColor3 = C.dim })
	end
	for i, t in others do
		local r = Instance.new("TextButton")
		r.Name = "Table" .. tostring(t.seat)
		r.AutoButtonColor = false
		r.Text = ""
		r.LayoutOrder = i
		r.Size = UDim2.new(1, -8, 0, 36)
		corner(r, 10)
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Color = C.gold
		st.Parent = r
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(12, 0)
		name.Size = UDim2.new(0.62, -12, 1, 0)
		name.FontFace = Brand.Fonts.bodyBold
		name.TextSize = 15
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextColor3 = C.bone
		name.Text = string.format("%d · %s%s", t.seat, tostring(t.name), if t.shield == true then "  🛡️" else "")
		name.Parent = r
		local felt = Instance.new("TextLabel")
		felt.BackgroundTransparency = 1
		felt.AnchorPoint = Vector2.new(1, 0)
		felt.Position = UDim2.new(1, -12, 0, 0)
		felt.Size = UDim2.new(0.38, -12, 1, 0)
		felt.FontFace = Brand.Fonts.bodyBold
		felt.TextSize = 14
		felt.TextXAlignment = Enum.TextXAlignment.Right
		local n = tonumber(t.felt) or 0
		felt.TextColor3 = if n >= 13 then rgb(255, 120, 90) else C.lightGold
		felt.Text = string.format("felt %d / 16", n)
		felt.Parent = r
		local seat = t.seat
		r.Activated:Connect(function()
			chosen = seat
			paint()
		end)
		r.Parent = list
		rows[seat] = r
	end
	paint()
	-- What to send.
	for i, k in SabotagePanel.Kinds do
		local key = Theme.key(content, string.format("%s  %s  ·  %s", k.glyph, k.name, costText(k.id, info)), i == 1, function()
			if chosen then
				SabotagePanel.send({ op = "sabotage", kind = k.id, seat = chosen })
			else
				Toast.show("Sabotage", "Choose a table first.", 2)
			end
		end, w - 36)
		key.LayoutOrder = 10 + i
		key.Size = UDim2.fromOffset(w - 36, 42)
	end
	Theme.text(content, "Parcel Bomb: six lookalikes on their felt  ·  Blackout: their felt dark for 6 s  ·  Butterfingers: no filing for 4 s", 12, "body", { LayoutOrder = 20, TextColor3 = C.dim })
	if mine then
		local shield = Theme.key(content, string.format("%s  Shield my table  ·  %s", SHIELD.glyph, costText("shield", info)), false, function()
			SabotagePanel.send({ op = "sabotage", kind = "shield", seat = mine })
		end, w - 36)
		shield.LayoutOrder = 30
		shield.Size = UDim2.fromOffset(w - 36, 40)
	end
	local close = Theme.key(content, "Close", false, function()
		SabotagePanel.close()
	end, 160)
	close.LayoutOrder = 40
	close.Size = UDim2.fromOffset(160, 36)
	Root.open(NAME, group)
	Fade.set(group, 1)
	Fade.to(group, Ease.scaled(Ease.settle), 0)
end

---------------------------------------------------------------------------------------------------
-- What lands on you
---------------------------------------------------------------------------------------------------
local veil: Frame? = nil

local function clearVeil()
	local v = veil
	veil = nil
	if v then
		v:Destroy()
	end
end

-- A veil over the whole screen (over the felt), with a line on it, for `seconds`.
local function cover(colour: Color3, transparency: number, title: string, line: string, seconds: number)
	clearVeil()
	local f = Instance.new("Frame")
	f.Name = "SabotageVeil"
	f.Size = UDim2.new(1, 0, 1, 200)
	f.Position = UDim2.fromOffset(0, -100)
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = 40
	f.Active = false
	f.Parent = Root.hud
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.42)
	t.Size = UDim2.fromOffset(520, 60)
	t.FontFace = Brand.Fonts.heavy
	t.TextSize = 44
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Text = title
	t.ZIndex = 41
	t.Parent = f
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0.42, 34)
	l.Size = UDim2.fromOffset(520, 30)
	l.FontFace = Brand.Fonts.bodyBold
	l.TextSize = 18
	l.TextColor3 = C.lightGold
	l.Text = line
	l.ZIndex = 41
	l.Parent = f
	veil = f
	Ease.play(f, Ease.info(0.25, Enum.EasingStyle.Quad), { BackgroundTransparency = transparency })
	task.delay(math.max(0.5, seconds - 0.8), function()
		if veil == f then
			Ease.play(f, Ease.info(0.8, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
			Ease.play(t, Ease.info(0.8, Enum.EasingStyle.Sine), { TextTransparency = 1, TextStrokeTransparency = 1 })
			Ease.play(l, Ease.info(0.8, Enum.EasingStyle.Sine), { TextTransparency = 1 })
			task.delay(0.85, function()
				if veil == f then
					clearVeil()
				end
			end)
		end
	end)
end

-- Something sent at your table (op "sabotaged").
function SabotagePanel.hit(m: { [string]: any })
	local by = tostring(m.by or "Someone")
	local k = byId[tostring(m.kind)]
	if not k then
		return
	end
	if m.blocked == true then
		Toast.show("Your Shield held", string.format("%s sent a %s. It bounced off.", by, k.name), 3)
		return
	end
	local seconds = tonumber(m.seconds) or 3
	if k.id == "blackout" then
		cover(rgb(4, 4, 8), 0.06, "🌑 BLACKOUT", "from " .. by, seconds)
	elseif k.id == "freeze" then
		cover(rgb(150, 210, 255), 0.55, "🧊 BUTTERFINGERS", string.format("from %s · no filing for %d s", by, seconds), seconds)
	elseif k.id == "bomb" then
		Toast.show("💣 Parcel Bomb", string.format("%s sent six lookalikes your way. Brace!", by), 2.5)
	end
end

-- The room hears of one (op "sabotage").
function SabotagePanel.heard(m: { [string]: any }, mySeat: number?)
	local k = byId[tostring(m.kind)]
	if not k or m.seat == mySeat and m.kind ~= "shield" then
		return
	end
	local by = tostring(m.by or "Someone")
	local to = tostring(m.toName or ("table " .. tostring(m.seat)))
	if m.kind == "shield" then
		Toast.show("🛡️ Shield up", string.format("%s raised a Shield.", by), 2)
	elseif m.blocked == true then
		Toast.show(k.glyph .. " Blocked", string.format("%s's %s bounced off %s's Shield.", by, k.name, to), 2.2)
	else
		Toast.show(k.glyph .. " " .. k.name, string.format("%s → %s", by, to), 2.2)
	end
end

-- For tests.
function SabotagePanel.veiled(): boolean
	return veil ~= nil and veil.Parent ~= nil
end

return SabotagePanel
