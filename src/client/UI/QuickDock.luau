--!strict
-- The quick dock: six round keys down the left side of the screen, always one tap away
-- (and a key each on the keyboard): your Collection (C), Trade (T), your Wardrobe (V), Gems,
-- Suites (your own, or a friend's: friends on Roblox may visit each other's), and Invite (Roblox's
-- invite prompt, to bring a friend).
-- Trade opens a short list of everyone in the house, each with a Trade key, and your past trades.
-- It steps aside while you sort at a table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Names = require(ReplicatedStorage.Shared.Names)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local QuickDock = {}

local C = Brand.Colours
local PICKER = "TradeWith"
local SUITES = "SuiteVisit"

-- Set by Main.
QuickDock.openCollection = function() end
QuickDock.openTrades = function() end
QuickDock.openWardrobe = function() end
QuickDock.openGems = function() end
QuickDock.inviteFriend = function() end
QuickDock.invite = function(_userId: number, _name: string) end
QuickDock.isSeated = function(): boolean
	return false
end

local dock: Frame? = nil

-- The list of guests to trade with.
function QuickDock.openTrade()
	if Root.isOpen(PICKER) then
		Root.close(PICKER)
		return
	end
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer then
			table.insert(others, p)
		end
	end
	local size = Root.size()
	local rows = math.max(1, #others)
	local group, content = Theme.glass(Root.panels, PICKER, UDim2.fromOffset(math.min(420, size.X - 24), math.min(170 + rows * 52, size.Y - 90)))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Trade", 24, "display", { LayoutOrder = 1 })
	if #others == 0 then
		Theme.text(content, "Nobody else is in the house just now. Invite a friend, then trade here.", 14, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true })
	else
		Theme.text(content, "Choose a guest. They're asked first; nothing changes hands until you both confirm.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true })
		for i, p in others do
			local k = Theme.key(content, Names.of(p), i == 1, function()
				Root.close(PICKER)
				QuickDock.invite(p.UserId, Names.of(p))
			end, 320)
			k.LayoutOrder = 2 + i
		end
	end
	local past = Theme.key(content, "Your trades", false, function()
		Root.close(PICKER)
		QuickDock.openTrades()
	end, 200)
	past.LayoutOrder = 100
	local close = Theme.key(content, "Close", false, function()
		Root.close(PICKER)
	end, 200)
	close.LayoutOrder = 101
	Root.open(PICKER, group)
end

-- Your Suite, or a friend's: friends in the house (the server knows who), each with a key.
local function askSuites(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("SuiteAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

function QuickDock.openSuites()
	if Root.isOpen(SUITES) then
		Root.close(SUITES)
		return
	end
	task.spawn(function()
		local r = askSuites({ op = "list" })
		local friends = if type(r) == "table" and type(r.friends) == "table" then r.friends else {}
		local visiting = if type(r) == "table" then r.visiting else nil
		local size = Root.size()
		local rows = #friends + 1
		local group, content = Theme.glass(Root.panels, SUITES, UDim2.fromOffset(math.min(420, size.X - 24), math.min(200 + rows * 52, size.Y - 90)))
		Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
		Theme.text(content, "Suites", 24, "display", { LayoutOrder = 1 })
		Theme.text(content, "Your own, private Suite, or a friend's: friends on Roblox may visit each other's.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true })
		local function go(request: { [string]: any })
			Root.close(SUITES)
			task.spawn(function()
				local res = askSuites(request)
				if type(res) == "table" and res.ok == false and res.why then
					QuickDock.say("Suites", tostring(res.why))
				end
			end)
		end
		local home = Theme.key(content, if visiting then "Back to my Suite" else "My Suite", true, function()
			go({ op = "home" })
		end, 320)
		home.Name = "MySuite"
		home.LayoutOrder = 3
		if #friends == 0 then
			Theme.text(content, "No friends in the house just now. Invite one with the Invite key, then visit each other's Suites.", 13, "body", { LayoutOrder = 4, TextColor3 = C.smoke, TextWrapped = true })
		end
		for i, f in friends do
			local k = Theme.key(content, tostring(f.name) .. "'s Suite" .. (if visiting == f.userId then "  ·  here" else ""), false, function()
				go({ op = "visit", userId = f.userId })
			end, 320)
			k.Name = "Visit_" .. tostring(f.userId)
			k.LayoutOrder = 4 + i
		end
		local close = Theme.key(content, "Close", false, function()
			Root.close(SUITES)
		end, 200)
		close.LayoutOrder = 100
		Root.open(SUITES, group)
	end)
end

-- A short word on screen (set by Main: a toast).
QuickDock.say = function(_title: string, _line: string) end

local SIZE = 62
local KEYS = 6

local function tile(parent: Instance, order: number, glyph: string, label: string, hotkey: string?, onPress: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = label
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(SIZE, SIZE)
	b.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	b.BackgroundTransparency = 0.12
	b.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.floor(SIZE * 0.24))
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = C.gold
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = b
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, math.floor(SIZE * 0.1))
	icon.Size = UDim2.fromOffset(math.floor(SIZE * 0.5), math.floor(SIZE * 0.5))
	icon.Text = glyph
	icon.TextScaled = true
	icon.Parent = b
	local name = Instance.new("TextLabel")
	name.Name = "Label"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -math.floor(SIZE * 0.06))
	name.Size = UDim2.new(1, -4, 0, math.floor(SIZE * 0.22))
	name.FontFace = Brand.Fonts.bodyBold
	name.TextSize = if SIZE >= 60 then 12 else 10
	name.TextColor3 = C.lightGold
	name.Text = label
	name.Parent = b
	-- The keyboard key, a small badge on the corner (not on phones).
	if hotkey and not UserInputService.TouchEnabled then
		local badge = Instance.new("TextLabel")
		badge.Name = "Hotkey"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, 4, 0, -4)
		badge.Size = UDim2.fromOffset(18, 18)
		badge.BackgroundColor3 = C.gold
		badge.TextColor3 = Color3.fromRGB(20, 16, 10)
		badge.FontFace = Brand.Fonts.bodyBold
		badge.TextSize = 11
		badge.Text = hotkey
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = badge
		badge.Parent = b
	end
	b.MouseEnter:Connect(function()
		stroke.Transparency = 0
		b.BackgroundTransparency = 0
	end)
	b.MouseLeave:Connect(function()
		stroke.Transparency = 0.25
		b.BackgroundTransparency = 0.12
	end)
	b.Activated:Connect(onPress)
	b.Parent = parent
	return b
end

function QuickDock.start()
	-- On a phone (a short screen) the keys are smaller and sit high, clear of the thumbstick.
	local short = Root.size().Y < 520
	SIZE = if short then 44 else 60
	local f = Instance.new("Frame")
	f.Name = "QuickDock"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0, 0)
	f.Position = if short then UDim2.new(0, 10, 0, 60) else UDim2.new(0.0, 12, 0.5, -(KEYS * SIZE + (KEYS - 1) * 8) / 2 - 30)
	f.Size = UDim2.fromOffset(SIZE, KEYS * SIZE + (KEYS - 1) * 8)
	f.Parent = Root.hud
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	tile(f, 1, "🏺", "Collection", "C", function()
		QuickDock.openCollection()
	end)
	tile(f, 2, "🤝", "Trade", "T", QuickDock.openTrade)
	tile(f, 3, "👔", "Wardrobe", "V", function()
		QuickDock.openWardrobe()
	end)
	tile(f, 4, "💎", "Gems", nil, function()
		QuickDock.openGems()
	end)
	tile(f, 5, "🛋️", "Suites", nil, QuickDock.openSuites)
	tile(f, 6, "✉️", "Invite", nil, function()
		QuickDock.inviteFriend()
	end)
	dock = f
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or QuickDock.isSeated() then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			QuickDock.openCollection()
		elseif input.KeyCode == Enum.KeyCode.T then
			QuickDock.openTrade()
		elseif input.KeyCode == Enum.KeyCode.V then
			QuickDock.openWardrobe()
		end
	end)
end

-- Out of the way while sorting.
function QuickDock.setSeated(seated: boolean)
	local f = dock
	if f then
		f.Visible = not seated
	end
end

return QuickDock
