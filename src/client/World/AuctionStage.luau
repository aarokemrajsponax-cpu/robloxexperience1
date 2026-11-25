--!strict
-- (Build 105) The Grand Auction's stage in the Library, on this guest's screen: the week's real
-- lots standing in the round on the marble plinths either side of the rostrum (in place of the
-- house's egg and vase), each turning slowly under its spotlight, with its name, the bid that
-- stands and when it closes (the lot's real close, from the server: Sunday 19:00 UTC); and a
-- LIVE marquee over the board. Asked of the server when the guest comes near, and again every
-- minute while they're near. Nothing here is a price or a bid (the server keeps those).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BrainrotFigure = require(ReplicatedStorage.Shared.BrainrotFigure)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Fortune = require(ReplicatedStorage.Shared.Fortune)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AuctionStage = {}

local NEAR = 140 -- studs from the rostrum at which the stage is drawn and kept up to date
local REFRESH = 60 -- seconds between asks while near

local player = Players.LocalPlayer
local holder: Folder? = nil
local turning: { { root: BasePart, at: CFrame, phase: number } } = {}
local lastAsk = -math.huge

-- How long until `ends` (server time, seconds since the epoch), in words: "2d 5h", "3h 20m".
function AuctionStage.left(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local d, h, m = s // 86400, (s % 86400) // 3600, (s % 3600) // 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%dm", math.max(1, m))
end

local function stage(): Model?
	local maison = Workspace:FindFirstChild("Maison")
	local m = maison and maison:FindFirstChild("GrandAuction", true)
	return if m and m:IsA("Model") then m else nil
end

local function clear()
	local h = holder
	if h then
		h:Destroy()
	end
	holder = nil
	table.clear(turning)
end

-- Builds the stage from the board (the server's lots): figures on the plinths, labels over them.
function AuctionStage.show(board: { [string]: any })
	clear()
	local m = stage()
	if not m or type(board) ~= "table" or type(board.lots) ~= "table" then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "AuctionStage"
	f.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	holder = f
	-- The rarest lots on the plinths: the dearest first (their first bid, in Gilt worth).
	local lots = table.clone(board.lots) :: { any }
	table.sort(lots, function(a, b)
		local wa = (tonumber(a.start) or 0) * (if a.currency == "Gems" then 400 else 1)
		local wb = (tonumber(b.start) or 0) * (if b.currency == "Gems" then 400 else 1)
		return wa > wb
	end)
	for k = 1, 2 do
		local top = m:FindFirstChild("LotPlinthTop" .. k)
		local lot = lots[k]
		if not top or not top:IsA("BasePart") or type(lot) ~= "table" or type(lot.curio) ~= "string" then
			continue
		end
		local c = Curios.byId[lot.curio]
		local ok, fig = pcall(BrainrotFigure.build, lot.curio, 2.6, if c then c.colour else nil, nil)
		if not ok or not fig then
			continue
		end
		-- (The house's own piece under that dome steps aside on this screen.)
		for _, name in { "LotEgg", "LotEggJewel", "LotStand" .. k, "LotVase" .. k, "LotVaseNeck" .. k, "LotVaseBand" .. k } do
			local old = m:FindFirstChild(name)
			if old and old:IsA("BasePart") then
				old.LocalTransparencyModifier = 1
			end
		end
		local at = CFrame.new(top.CFrame.Position + Vector3.new(0, top.Size.Y / 2, 0))
		BrainrotFigure.place(fig, at)
		fig.Parent = f
		local root = fig.PrimaryPart
		if root then
			table.insert(turning, { root = root, at = at, phase = k * 1.7 })
		end
		-- Its card over the dome: the name, the bid that stands (or the first bid) and the close.
		local tag = Instance.new("BillboardGui")
		tag.Name = "LotCard"
		tag.Size = UDim2.fromOffset(230, 70)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 5.4, 0)
		tag.Adornee = top
		tag.MaxDistance = 70
		tag.LightInfluence = 0
		tag.Parent = f
		local function line(y: number, h: number, text: string, colour: Color3, font: Font)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromOffset(0, y)
			l.Size = UDim2.new(1, 0, 0, h)
			l.Text = text
			l.TextScaled = true
			l.FontFace = font
			l.TextColor3 = colour
			l.TextStrokeTransparency = 0.35
			l.Parent = tag
		end
		local rarity = if c then string.upper(c.rarity) else "LIMITED"
		line(0, 16, "LIMITED · " .. rarity .. " · ONE WINNER", Color3.fromRGB(255, 120, 160), Brand.Fonts.heavy)
		line(16, 24, tostring(lot.name), Brand.Colours.brightGold, Brand.Fonts.display)
		local high = tonumber(lot.high) or 0
		local amount = if high > 0 then high else tonumber(lot.start) or 0
		local cur = tostring(lot.currency or "Gilt")
		line(40, 16, string.format("%s %s %s", if high > 0 then "Top bid" else "Opens at", Fortune.format(amount), cur), Color3.fromRGB(255, 236, 190), Brand.Fonts.heavy)
		line(56, 14, "Closes in " .. AuctionStage.left(tonumber(lot.left) or 0), Color3.fromRGB(220, 220, 230), Brand.Fonts.body)
		-- Gold sparks rising round it.
		if root then
			local att = Instance.new("Attachment")
			att.Parent = root
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Rate = 6
			e.Lifetime = NumberRange.new(1, 2)
			e.Speed = NumberRange.new(0.5, 1.2)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Acceleration = Vector3.new(0, 0.6, 0)
			e.LightEmission = 1
			e.Size = NumberSequence.new(0.18, 0)
			e.Color = ColorSequence.new(Color3.fromRGB(255, 214, 120))
			e.Parent = att
		end
	end
	-- The LIVE marquee over the board.
	local board3d = m:FindFirstChild("AuctionBoard")
	if board3d and board3d:IsA("BasePart") then
		local tag = Instance.new("BillboardGui")
		tag.Name = "AuctionLive"
		tag.Size = UDim2.fromOffset(360, 44)
		tag.StudsOffsetWorldSpace = Vector3.new(0, board3d.Size.Y / 2 + 2, 0)
		tag.Adornee = board3d
		tag.MaxDistance = 160
		tag.LightInfluence = 0
		tag.Parent = f
		local l = Instance.new("TextLabel")
		l.Name = "Live"
		l.BackgroundColor3 = Color3.fromRGB(150, 20, 40)
		l.BackgroundTransparency = 0.1
		l.Size = UDim2.fromScale(1, 1)
		l.TextScaled = true
		l.FontFace = Brand.Fonts.heavy
		l.TextColor3 = Color3.fromRGB(255, 240, 220)
		local first = board.lots[1]
		local closes = if type(first) == "table" then AuctionStage.left(tonumber(first.left) or 0) else ""
		l.Text = string.format("● LIVE  ·  %d LIMITED LOTS  ·  CLOSES IN %s", #board.lots, closes)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = l
		l.Parent = tag
	end
end

local function ask()
	lastAsk = os.clock()
	task.spawn(function()
		local ok, board = pcall(function()
			return Remotes.func("AuctionAsk"):InvokeServer({ op = "board" })
		end)
		if ok and type(board) == "table" and board.ok ~= false then
			AuctionStage.show(board)
		end
	end)
end

-- For tests: the figures on the plinths now.
function AuctionStage.figures(): { Model }
	local out = {}
	local h = holder
	if h then
		for _, d in h:GetChildren() do
			if d:IsA("Model") then
				table.insert(out, d)
			end
		end
	end
	return out
end

function AuctionStage.start()
	task.spawn(function()
		while true do
			local m = stage()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local rostrum = m and m:FindFirstChild("RostrumTop")
			local near = root ~= nil and root:IsA("BasePart") and rostrum ~= nil and rostrum:IsA("BasePart") and (root.CFrame.Position - rostrum.CFrame.Position).Magnitude < NEAR
			if near and (holder == nil or os.clock() - lastAsk > REFRESH) then
				ask()
			elseif not near and holder then
				clear()
			end
			task.wait(2)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if #turning == 0 then
			return
		end
		local t = os.clock()
		for _, s in turning do
			if s.root.Parent then
				s.root.CFrame = s.at * CFrame.new(0, 0.25 + math.sin(t * 1.4 + s.phase) * 0.12, 0) * CFrame.Angles(0, t * 0.6 + s.phase, 0)
			end
		end
	end)
end

return AuctionStage
