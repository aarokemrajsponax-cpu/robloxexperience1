--!strict
-- Admiring another guest: walk up to them and press R (L1 on a gamepad). They hear who admired
-- them; you see what they're wearing and where each piece is from, with a key straight to that
-- shelf of the Boutique, a key to send them a gift, and one to ask them to trade curios.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Closet = require(script.Parent.Parent.Closet)

local AdmireCard = {}

local NAME = "Admire"

-- Set by Main: opens the Boutique on a shelf, optionally to buy a gift for someone.
AdmireCard.openBoutique = function(_tab: string, _giftFor: { userId: number, name: string }?) end
-- Set by Main: asks a guest to trade curios.
AdmireCard.trade = function(_userId: number, _name: string) end
-- Set by Main: whether the guest is seated (no prompts at a table).
AdmireCard.isSeated = function(): boolean
	return false
end

local SHELF_NAMES = {
	always = "Always here",
	today = "Today",
	week = "This week",
	season = "In season",
	gilt = "For Gilt",
	goldKey = "The Gold Key",
}

function AdmireCard.show(card: { [string]: any })
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local pieces = if type(card.pieces) == "table" then card.pieces else {}
	local size = Root.size()
	local h = math.min(220 + #pieces * 44, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(math.min(460, size.X - 24), h))
	Theme.list(content, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, tostring(card.name), 24, "display", { LayoutOrder = 1 })
	Theme.text(content, if card.counted then "They'll know you admired them." else "You admired them a little while ago.", 12, "body", { LayoutOrder = 2, TextColor3 = Brand.Colours.smoke })
	if #pieces == 0 then
		Theme.text(content, "Their own avatar, just as they are.", 14, "body", { LayoutOrder = 3, TextColor3 = Brand.Colours.bone })
	end
	for i, p in pieces do
		local r = Instance.new("Frame")
		r.BackgroundTransparency = 1
		r.Size = UDim2.new(1, 0, 0, 38)
		r.LayoutOrder = 10 + i
		r.Parent = content
		Theme.text(r, tostring(p.kindName or "") .. "  ·  " .. tostring(p.name), 14, "body", {
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0.62, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Brand.Colours.bone,
		})
		if type(p.where) == "string" and SHELF_NAMES[p.where] then
			local k = Theme.key(r, SHELF_NAMES[p.where], false, function()
				Root.close(NAME)
				AdmireCard.openBoutique(p.where, nil)
			end, 150)
			k.AnchorPoint = Vector2.new(1, 0)
			k.Position = UDim2.new(1, 0, 0, 0)
			k.Size = UDim2.fromOffset(150, 34)
		end
	end
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 100
	keys.Parent = content
	Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local gift = Theme.key(keys, "A gift for " .. tostring(card.name), true, function()
		Root.close(NAME)
		AdmireCard.openBoutique("always", { userId = card.userId, name = card.name })
	end, 220)
	if type(card.userId) == "number" then
		Theme.key(keys, "Trade", false, function()
			Root.close(NAME)
			AdmireCard.trade(card.userId, tostring(card.name))
		end, 120)
	end
	Theme.key(keys, "Close", false, function()
		Root.close(NAME)
	end, 140)
	Root.open(NAME, group, nil, false)
	pcall(function()
		game:GetService("GuiService").SelectedObject = gift
	end)
end

function AdmireCard.admire(userId: number)
	task.spawn(function()
		local r = Closet.ask({ op = "admire", userId = userId })
		if type(r) == "table" and r.ok then
			AdmireCard.show(r)
		elseif type(r) == "table" then
			Toast.show("Admire", tostring(r.why), 2.5)
		end
	end)
end

-- A prompt on every other guest (on this screen only).
local function attach(other: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") or root:FindFirstChild("AdmirePrompt") then
		return
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "AdmirePrompt"
	p.ActionText = "Admire"
	p.ObjectText = other.DisplayName
	p.KeyboardKeyCode = Enum.KeyCode.R
	p.GamepadKeyCode = Enum.KeyCode.ButtonL1
	p.HoldDuration = 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.Parent = root
	CollectionService:AddTag(p, "AdmirePrompt")
	p.Triggered:Connect(function()
		AdmireCard.admire(other.UserId)
	end)
end

local function watch(other: Player)
	if other == Players.LocalPlayer then
		return
	end
	if other.Character then
		task.spawn(attach, other, other.Character)
	end
	other.CharacterAdded:Connect(function(character)
		attach(other, character)
	end)
end

function AdmireCard.start()
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)
	-- No admiring from a chair: the prompts rest while seated.
	task.spawn(function()
		while true do
			local seated = AdmireCard.isSeated()
			for _, p in CollectionService:GetTagged("AdmirePrompt") do
				if p:IsA("ProximityPrompt") then
					p.Enabled = not seated
				end
			end
			task.wait(0.5)
		end
	end)
	Closet.Message:Connect(function(op: string, m: any)
		if op == "admired" then
			Toast.show("Admired", tostring(m.from) .. " admires you.", 3)
		end
	end)
end

return AdmireCard
