--!strict
-- The attractions on a guest's screen (shared/Attractions): each one's own screen is shown while,
-- and only while, the server says they're in it (the "Attraction" attribute), and goes the moment
-- they're out. What the server tells them about it (the Attraction event) comes here first: going
-- in and out, the house's notices, the board at the Luxe Lounge's lectern, and Stride while they
-- walk a treadmill in the Lounge (a small count at the foot of the screen).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local LuxeHud = require(script.Parent.LuxeHud)
local LuxePanel = require(script.Parent.LuxePanel)
local Root = require(script.Parent.Root)
local Toast = require(script.Parent.Toast)

local Attraction = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 204, 90)

local chip: TextLabel? = nil
local chipUntil = 0

local function strideChip(m: { [string]: any })
	local c = chip
	if not c then
		local l = Instance.new("TextLabel")
		l.Name = "StrideChip"
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Size = UDim2.fromOffset(0, 30)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.BackgroundColor3 = Color3.fromRGB(16, 13, 9)
		l.BackgroundTransparency = 0.08
		l.FontFace = Brand.Fonts.bodyBold
		l.TextSize = 13
		l.TextColor3 = GOLD
		l.Parent = Root.hud
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 15)
		corner.Parent = l
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = l
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = GOLD
		edge.Transparency = 0.3
		edge.Parent = l
		chip = l
		c = l
	end
	local label = c :: TextLabel
	label.Position = UDim2.new(0.5, 0, 1, -(70 + Root.bottomClear()))
	local nextAt = tonumber(m.next)
	label.Text = string.format("%sSTRIDE  ·  LEVEL %d  ·  %s", if m.golden then "GOLDEN  ·  " else "", tonumber(m.level) or 1, if nextAt then string.format("%d / %d", tonumber(m.points) or 0, nextAt) else "THE TOP")
	label.Visible = true
	chipUntil = os.clock() + 2.5
	task.delay(2.6, function()
		if chip and os.clock() >= chipUntil then
			chip.Visible = false
		end
	end)
end

local function follow()
	local id = player:GetAttribute(AttractionList.ATTRIBUTE)
	if id == "luxe" then
		LuxeHud.mount()
	else
		LuxeHud.unmount()
	end
end

function Attraction.start()
	LuxeHud.openBoard = LuxePanel.open
	Remotes.event("Attraction").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		local op = m.op
		if op == "entered" then
			follow()
			local def = AttractionList.byId[tostring(m.id)]
			if def then
				Toast.show(def.name, def.line, 6)
			end
		elseif op == "left" then
			follow()
		elseif op == "lostOnLeaving" then
			Toast.show("Left behind", string.format("What you hadn't banked (%s) stays in the residence.", Rules.format(tonumber(m.lost) or 0)), 4)
		elseif op == "notice" then
			Toast.show(tostring(m.title or ""), tostring(m.line or ""), 3)
		elseif op == "panel" then
			if m.id == "luxe" then
				LuxePanel.open()
			end
		elseif op == "stride" then
			strideChip(m)
		elseif op == "strideUp" then
			Toast.show(string.format("Stride level %d", tonumber(m.level) or 1), string.format("%d%% faster in Steal a Luxe", tonumber(m.faster) or 0), 3)
		elseif LuxeHud.mounted() then
			LuxeHud.on(m)
		end
	end)
	player:GetAttributeChangedSignal(AttractionList.ATTRIBUTE):Connect(follow)
	follow()
end

return Attraction
