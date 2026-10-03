--!strict
-- The Black Card (§12), read at the Concierge's lectern: what it gives, the price as Roblox shows
-- it, this month's cardholder look, and one key to hold it. It is a card on a lectern, never a
-- pop-up: nothing opens this but the guest. In a guest's first minutes the card isn't there.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Closet = require(script.Parent.Parent.Closet)

local BlackCardPanel = {}

local NAME = "BlackCard"

local GIVES = {
	"The Leather-Bound Ledger, for as long as you hold the card.",
	"A cardholder look each month, yours to keep.",
	"A black-lacquer nameplate while the card is held.",
}

function BlackCardPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(440, size.X - 24)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, math.min(430, size.Y - 40)))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Black Card", 26, "display", { LayoutOrder = 1 })
	Theme.hairline(content, UDim.new(0, 90), 2)
	for i, line in GIVES do
		Theme.text(content, line, 14, "body", { LayoutOrder = 2 + i, TextColor3 = Brand.Colours.bone })
	end
	local month = Theme.text(content, "", 13, "body", { LayoutOrder = 8, TextColor3 = Brand.Colours.lightGold })
	local price = Theme.text(content, "", 12, "caps", { LayoutOrder = 9 })
	Theme.text(content, "Monthly, through Roblox. Cancel whenever you like; the looks you received stay yours.", 12, "body", { LayoutOrder = 10, TextColor3 = Brand.Colours.dim })
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 20
	keys.Parent = content
	Theme.list(keys, 8)
	local hold = Theme.key(keys, "Hold the card", true, function()
		local r = Closet.ask({ op = "holdCard" })
		if type(r) == "table" and not r.ok then
			Toast.show("The Black Card", tostring(r.why), 3)
		end
	end, 300)
	hold.LayoutOrder = 1
	Theme.key(keys, "Close", false, function()
		Root.close(NAME)
	end, 300).LayoutOrder = 2
	local function show(v: { [string]: any })
		month.Text = if type(v.look) == "string" then "This month's look: " .. v.look .. "." else ""
		price.Text = if type(v.price) == "string" then string.upper(v.price .. " a month") else ""
		hold.Visible = v.held ~= true and v.offered == true
		if v.held then
			price.Text = "YOU HOLD THE CARD"
		end
	end
	show({ held = Closet.blackCard.held, offered = Closet.blackCard.offered })
	task.spawn(function()
		local v = Closet.ask({ op = "blackCard" })
		if type(v) == "table" and content.Parent then
			show(v)
		end
	end)
	local conn = Closet.Changed:Connect(function()
		if content.Parent then
			show({ held = Closet.blackCard.held, offered = Closet.blackCard.offered, look = nil })
		end
	end)
	Root.open(NAME, group, function()
		conn:Disconnect()
	end)
	pcall(function()
		game:GetService("GuiService").SelectedObject = hold
	end)
end

-- The card on the lectern: there only when it's offered, and not in a guest's first minutes.
local function place(card: Instance)
	if not card:IsA("BasePart") then
		return
	end
	local player = Players.LocalPlayer
	local visible = Workspace:GetAttribute("BlackCardOffered") == true and not (player and player:GetAttribute("Quiet") == true)
	card.LocalTransparencyModifier = if visible then 0 else 1
	local parent = card.Parent
	local edge = parent and parent:FindFirstChild("BlackCardEdge")
	if edge and edge:IsA("BasePart") then
		edge.LocalTransparencyModifier = card.LocalTransparencyModifier
	end
	local prompt = card:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = visible
	end
end

function BlackCardPanel.start()
	local function all()
		for _, card in CollectionService:GetTagged("BlackCardLectern") do
			place(card)
		end
	end
	CollectionService:GetInstanceAddedSignal("BlackCardLectern"):Connect(place)
	Workspace:GetAttributeChangedSignal("BlackCardOffered"):Connect(all)
	local player = Players.LocalPlayer
	if player then
		player:GetAttributeChangedSignal("Quiet"):Connect(all)
	end
	all()
end

return BlackCardPanel
