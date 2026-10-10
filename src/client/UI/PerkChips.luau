--!strict
-- A guest's perks at a glance, at the left edge while they walk the house (clear of the keys
-- and the objective card at the top right, the chat at the top left and the thumbstick below):
-- friends here (friends on Roblox in the house together earn more Gilt), God-Mode Luck's time
-- left (it only runs while they're here), and anything bought and waiting
-- (a decree to write, revives kept for the next run, a rain waiting its turn). Nothing is shown
-- when there's nothing to show, and it's hidden at the table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
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
-- (Just right of the quick dock down the left edge, clear of its glow.)
stack.Position = UDim2.new(0, 100, 0.42, 0)
stack.Size = UDim2.fromOffset(CHIP_WIDTH, 0)
stack.AutomaticSize = Enum.AutomaticSize.Y
stack.Parent = Root.hud
Theme.list(stack, 6).HorizontalAlignment = Enum.HorizontalAlignment.Left

local chips: { [string]: TextButton } = {}
-- Each perk's own point of light.
local DOTS: { [string]: Color3 } = {
	Friends = Color3.fromRGB(120, 236, 150),
	Luck = Color3.fromRGB(140, 230, 120),
	Decree = Color3.fromRGB(255, 214, 120),
	Revive = Color3.fromRGB(150, 200, 255),
	Rain = Color3.fromRGB(255, 196, 92),
	Piano = Color3.fromRGB(230, 180, 255),
}
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
		-- A capsule of black glass with a fine turning gold edge and a point of the perk's own
		-- light at its left; its words in bright gold.
		local b = Instance.new("TextButton")
		b.Name = id
		b.AutoButtonColor = false
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BackgroundTransparency = 0.06
		b.Size = UDim2.fromOffset(CHIP_WIDTH, 30)
		b.LayoutOrder = order
		b.FontFace = Brand.Fonts.bodyBold
		b.TextSize = 13
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextTruncate = Enum.TextTruncate.AtEnd
		b.TextColor3 = Brand.Colours.brightGold
		b.Active = onPress ~= nil
		local fill = Instance.new("UIGradient")
		fill.Rotation = 90
		fill.Color = ColorSequence.new(Color3.fromRGB(30, 28, 32), Color3.fromRGB(9, 9, 12))
		fill.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 26)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.15
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		Theme.edge(stroke, 1.1)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 15)
		corner.Parent = b
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(0, -13, 0.5, 0)
		dot.Size = UDim2.fromOffset(8, 8)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = DOTS[id] or Brand.Colours.brightGold
		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(1, 0)
		dc.Parent = dot
		dot.Parent = b
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
	-- Friends in the house: the server counts them (and pays the boost).
	local friends = Players.LocalPlayer:GetAttribute("FriendsHere")
	local more = math.floor((Config.data.Friends.giltBoost - 1) * 100 + 0.5)
	chip("Friends", 0, if type(friends) == "number" and friends > 0 then string.format("FRIENDS HERE (%d)  ·  +%d%% GILT", friends, more) else nil)
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
	Players.LocalPlayer:GetAttributeChangedSignal("FriendsHere"):Connect(refresh)
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
