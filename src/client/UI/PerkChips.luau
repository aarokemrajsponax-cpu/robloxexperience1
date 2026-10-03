--!strict
-- A guest's perks at a glance, at the left edge while they walk the house (clear of the keys
-- and the objective card at the top right, the chat at the top left and the thumbstick below):
-- God-Mode Luck's time left (it only runs while they're here), and anything bought and waiting
-- (a decree to write, revives kept for the next run, a rain waiting its turn). Nothing is shown
-- when there's nothing to show, and it's hidden at the table.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Perks = require(script.Parent.Parent.Perks)

local PerkChips = {}

-- Set by Main: open the decree panel; open the piano's offer.
PerkChips.openDecree = function() end
PerkChips.openPiano = function() end

local CHIP_WIDTH = 260
local stack = Instance.new("Frame")
stack.Name = "PerkChips"
stack.BackgroundTransparency = 1
stack.AnchorPoint = Vector2.new(0, 0.5)
stack.Position = UDim2.new(0, 12, 0.42, 0)
stack.Size = UDim2.fromOffset(CHIP_WIDTH, 0)
stack.AutomaticSize = Enum.AutomaticSize.Y
stack.Parent = Root.hud
Theme.list(stack, 4).HorizontalAlignment = Enum.HorizontalAlignment.Left

local chips: { [string]: TextButton } = {}
local hidden = false

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function chip(id: string, order: number, text: string?, onPress: (() -> ())?)
	local c = chips[id]
	if not text then
		if c then
			c:Destroy()
			chips[id] = nil
		end
		return
	end
	if not c then
		local b = Instance.new("TextButton")
		b.Name = id
		b.AutoButtonColor = false
		b.BackgroundColor3 = Color3.fromRGB(14, 12, 8)
		b.BackgroundTransparency = 0.2
		b.Size = UDim2.fromOffset(CHIP_WIDTH, 28)
		b.LayoutOrder = order
		b.FontFace = Brand.Fonts.body
		b.TextSize = 14
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextTruncate = Enum.TextTruncate.AtEnd
		b.TextColor3 = Brand.Colours.lightGold
		b.Active = onPress ~= nil
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Color = Brand.Colours.gold
		stroke.Transparency = 0.45
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 2)
		corner.Parent = b
		if onPress then
			b.Activated:Connect(onPress)
		end
		b.Parent = stack
		chips[id] = b
		c = b
	end
	(c :: TextButton).Text = text
end

local function refresh()
	stack.Visible = not hidden
	local luck = Perks.luckLeft()
	local mult = if type(Perks.state.luck) == "table" then tonumber(Perks.state.luck.multiplier) else nil
	chip("Luck", 1, if luck > 0 then string.format("LUCK BOOSTER  %s×  ·  %s", tostring(mult or 2.5), clock(luck)) else nil)
	local decrees = Perks.held("decree")
	chip("Decree", 2, if decrees > 0 then string.format("A DECREE TO WRITE (%d)  ›", decrees) else nil, function()
		PerkChips.openDecree()
	end)
	local revives = Perks.held("revive")
	chip("Revive", 3, if revives > 0 then string.format("REVIVES KEPT  %d", revives) else nil)
	local rain = Perks.state.rain
	local waiting = if type(rain) == "table" then tonumber(rain.held) or 0 else 0
	chip("Rain", 4, if waiting > 0 then "YOUR RAIN IS NEXT IN LINE" else nil)
	-- Piano time held (it only runs at the keys, so it doesn't count down here).
	local piano = Perks.state.piano
	local held = if type(piano) == "table" and piano.playing ~= true then tonumber(piano.seconds) or 0 else 0
	chip("Piano", 5, if held > 0 then string.format("PIANO TIME %s · THE FOYER  ›", clock(held)) else nil, function()
		PerkChips.openPiano()
	end)
end

-- Hidden at the table (the sorting screen keeps its header clear).
function PerkChips.setHidden(on: boolean)
	hidden = on
	refresh()
end

function PerkChips.start()
	Perks.Changed:Connect(refresh)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			if Perks.luckLeft() > 0 or chips.Luck then
				refresh()
			end
		end
	end)
	refresh()
end

return PerkChips
