--!strict
-- The HUD is almost nothing: a settings key, a clear Leave key at the table, a slim top line on
-- phones (score · multiplier · clock), and, on a first visit, "Straight to the table".
-- Nothing sits under the thumbstick or the jump button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local Hud = {}

local bar = Instance.new("Frame")
bar.Name = "TopRight"
bar.BackgroundTransparency = 1
bar.AnchorPoint = Vector2.new(1, 0)
bar.Position = UDim2.new(1, -12, 0, 10)
bar.Size = UDim2.fromOffset(300, 40)
bar.Parent = Root.hud
local barList = Theme.list(bar, 8, true)
barList.HorizontalAlignment = Enum.HorizontalAlignment.Right
bar.Visible = false

local leaveKey: TextButton? = nil
local extraKey: TextButton? = nil
local extraKeys: { TextButton } = {}
local straightKey: TextButton? = nil

-- The slim top line, for phones.
local line = Instance.new("Frame")
line.Name = "TopLine"
line.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
line.BackgroundTransparency = 0.3
line.AnchorPoint = Vector2.new(0.5, 0)
line.Position = UDim2.new(0.5, 0, 0, 10)
line.Size = UDim2.fromOffset(260, 34)
line.Visible = false
line.Parent = Root.hud
local lineCorner = Instance.new("UICorner")
lineCorner.CornerRadius = UDim.new(0, 2)
lineCorner.Parent = line
local lineStroke = Instance.new("UIStroke")
lineStroke.Color = Brand.Colours.gold
lineStroke.Transparency = 0.55
lineStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
lineStroke.Parent = line
local lineText = Theme.text(line, "", 15, "bodyMedium", {
	AutomaticSize = Enum.AutomaticSize.None,
	Size = UDim2.fromScale(1, 1),
	TextColor3 = Brand.Colours.lightGold,
})

function Hud.start(openSettings: () -> (), leave: () -> ())
	bar.Visible = true
	local leaveButton = Theme.key(bar, Voice.Table.leave, false, leave, 110)
	leaveButton.LayoutOrder = 1
	leaveButton.Visible = false
	leaveKey = leaveButton
	local settingsButton = Theme.key(bar, "Settings", false, openSettings, 120)
	settingsButton.LayoutOrder = 2
end

-- How much of the top-right corner the keys take, in screen pixels (the sorting screen keeps its
-- figures clear of them).
function Hud.width(): number
	if not bar.Visible then
		return 0
	end
	local w, n = 0, 0
	for _, key in bar:GetChildren() do
		if key:IsA("GuiObject") and key.Visible then
			w += key.Size.X.Offset
			n += 1
		end
	end
	if n == 0 then
		return 0
	end
	return (w + (n - 1) * 8 + 12) * Root.scale
end

-- The Shop key: gold, first in the row, while walking (the sorting screen stays clean).
local shopKey: TextButton? = nil
function Hud.setShopKey(onPress: () -> ())
	if shopKey then
		return
	end
	local key = Theme.key(bar, "Shop", true, onPress, 100)
	key.Name = "ShopKey"
	key.LayoutOrder = -20
	shopKey = key
end

-- The How to play key: the whole game in plain words, a Go key for every room (between Shop and
-- Menu, where anyone lost looks first).
local helpKey: TextButton? = nil
local coach: TextButton? = nil
function Hud.setHelpKey(onPress: () -> ())
	if helpKey then
		return
	end
	-- (Wide enough for its words on one line at a phone's larger lettering.)
	local key = Theme.key(bar, Voice.Guide.key, false, function()
		Hud.hideCoach()
		onPress()
	end, 176)
	key.Name = "HowToPlayKey"
	key.LayoutOrder = -15
	helpKey = key
end

-- A small gold note under the How to play key, once, for someone new: where to look when lost.
-- It goes when the key is pressed, when it's tapped, or after `seconds`.
function Hud.coachHelp(text: string, seconds: number?)
	local key = helpKey
	if coach or not key or not key.Visible then
		return
	end
	local note = Instance.new("TextButton")
	note.Name = "HowToPlayCoach"
	note.AutoButtonColor = false
	note.AnchorPoint = Vector2.new(1, 0)
	note.Position = UDim2.new(1, -12, 0, 10 + 44 + 12)
	note.Size = UDim2.fromOffset(250, 0)
	note.AutomaticSize = Enum.AutomaticSize.Y
	note.BackgroundColor3 = Color3.fromRGB(22, 19, 14)
	note.BackgroundTransparency = 0.04
	note.Text = ""
	note.ZIndex = 20
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = note
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = Brand.Colours.gold
	st.Transparency = 0.15
	st.Thickness = 1.25
	st.Parent = note
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = note
	Theme.text(note, text, 14, "bodyMedium", {
		Name = "Words",
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Brand.Colours.bone,
		ZIndex = 21,
	})
	-- (Its little point, up toward the key.)
	local tip = Instance.new("Frame")
	tip.Name = "Point"
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Size = UDim2.fromOffset(12, 12)
	tip.Rotation = 45
	tip.BorderSizePixel = 0
	tip.BackgroundColor3 = Brand.Colours.gold
	tip.ZIndex = 19
	tip.Parent = note
	note.Activated:Connect(function()
		Hud.hideCoach()
	end)
	note.Parent = Root.hud
	coach = note
	-- Line the point up under the key's middle (the keys sit right to left from the corner).
	task.defer(function()
		if coach ~= note then
			return
		end
		-- (Where the screen can't say where things are yet, the point sits under the key's
		-- usual place: the second key from the corner.)
		local ok, fromRight = pcall(function()
			local keyMid = key.AbsolutePosition.X + key.AbsoluteSize.X / 2
			local noteRight = note.AbsolutePosition.X + note.AbsoluteSize.X
			return (noteRight - keyMid) / math.max(Root.scale, 0.01)
		end)
		if not ok or type(fromRight) ~= "number" then
			fromRight = 200
		end
		-- (The note's padding moves its children in: 14 from the right, 10 from the top.)
		tip.Position = UDim2.new(1, -(math.clamp(fromRight, 16, 234) - 14), 0, -8)
	end)
	note.BackgroundTransparency = 1
	Ease.play(note, Ease.settle, { BackgroundTransparency = 0.04 })
	task.delay(seconds or 14, function()
		if coach == note then
			Hud.hideCoach()
		end
	end)
end

function Hud.hideCoach()
	local note = coach
	if not note then
		return
	end
	coach = nil
	note:Destroy()
end

-- The Menu key: everything else in the house (Main fills it), just after Shop.
local menuKey: TextButton? = nil
function Hud.setMenuKey(onPress: () -> ())
	if menuKey then
		return
	end
	local key = Theme.key(bar, "Menu", false, onPress, 100)
	key.Name = "MenuKey"
	key.LayoutOrder = -10
	menuKey = key
end

-- The owner's key (the Owner Console), after Settings: gold, with a crown.
function Hud.setOwnerKey(onPress: () -> ())
	local key = Theme.key(bar, "👑 Owner", true, onPress, 120)
	key.Name = "OwnerKey"
	key.LayoutOrder = 3
end

-- One optional key beside Leave (in the Library, "Invite a friend" while you wait).
function Hud.setExtraKey(text: string?, onPress: (() -> ())?)
	if extraKey then
		extraKey:Destroy()
		extraKey = nil
	end
	if text and onPress then
		local key = Theme.key(bar, text, false, onPress, 170)
		key.LayoutOrder = 0
		extraKey = key
	end
end

-- Keys beside Leave and Settings (in the Ballroom, "Next evening" and "Watch").
function Hud.setExtraKeys(list: { { text: string, onPress: () -> () } })
	for _, k in extraKeys do
		k:Destroy()
	end
	extraKeys = {}
	for i, spec in list do
		local key = Theme.key(bar, spec.text, i == 1, spec.onPress, 160)
		key.LayoutOrder = -10 + i
		table.insert(extraKeys, key)
	end
end

-- A free line of text on the phone's top line.
function Hud.setTextLine(text: string)
	lineText.Text = text
end

function Hud.setSeated(seated: boolean)
	if leaveKey then
		leaveKey.Visible = seated
	end
	if shopKey then
		shopKey.Visible = not seated
	end
	if helpKey then
		helpKey.Visible = not seated
	end
	if seated then
		Hud.hideCoach()
	end
	-- At a table the sorting screen carries the score and the clock itself.
	line.Visible = false
end

function Hud.setLine(score: string, multiplier: number, clock: number?)
	local parts = { score, "×" .. tostring(multiplier) }
	if clock then
		table.insert(parts, string.format("%d s", math.ceil(clock)))
	end
	lineText.Text = table.concat(parts, "   ·   ")
end

-- In the Library: pieces left on your felt against theirs.
function Hud.setDuelLine(mine: number, theirs: number?, clock: number?)
	local parts = { string.format("%d left", mine) }
	if theirs then
		table.insert(parts, string.format("rival %d", theirs))
	end
	if clock then
		table.insert(parts, string.format("%d s", math.ceil(clock)))
	end
	lineText.Text = table.concat(parts, "   ·   ")
end

function Hud.showStraight(onPress: () -> ())
	if straightKey then
		return
	end
	local key = Theme.key(Root.hud, Voice.Table.straightToTable, true, function()
		Hud.hideStraight()
		onPress()
	end, 250)
	key.AnchorPoint = Vector2.new(0.5, 0)
	key.Position = UDim2.new(0.5, 0, 0, 58)
	key.TextTransparency = 1
	key.BackgroundTransparency = 1
	Ease.play(key, Ease.settle, { TextTransparency = 0, BackgroundTransparency = 0.08 })
	straightKey = key
end

function Hud.hideStraight()
	local key = straightKey
	if not key then
		return
	end
	straightKey = nil
	local t = Ease.play(key, Ease.quick, { TextTransparency = 1, BackgroundTransparency = 1 })
	t.Completed:Once(function()
		key:Destroy()
	end)
end

return Hud
