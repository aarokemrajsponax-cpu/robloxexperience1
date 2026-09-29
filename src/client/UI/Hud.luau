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
local State = require(script.Parent.Parent.State)

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
	line.Visible = seated and State.inputKind() == "touch"
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
