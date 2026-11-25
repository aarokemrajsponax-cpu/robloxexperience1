--!strict
-- (Build 105) The Boutique's two display plinths, on this guest's screen: the day's two rarest
-- Brainrot Market pieces (shared/Boutique.market: the same in every server, chosen by the date)
-- standing on them in the round, turning slowly in gold sparks, with what each is, its rarity,
-- its exact Gilt price and where it's bought (the Boutique's counter); the house's jewels under
-- their domes are put aside on this screen. They change at midnight UTC, when the Market does.
-- Nothing here sells anything: the counter does, at the price the server keeps.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Boutique = require(ReplicatedStorage.Shared.Boutique)
local BrainrotFigure = require(ReplicatedStorage.Shared.BrainrotFigure)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Fortune = require(ReplicatedStorage.Shared.Fortune)

local MarketShowroom = {}

local holder: Folder? = nil
local shownDay: number? = nil
local turning: { { root: BasePart, at: CFrame, phase: number } } = {}

local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }

-- The day's two rarest picks (rarest first).
function MarketShowroom.picks(now: number?): { Boutique.MarketPick }
	local all = table.clone(Boutique.market(now))
	table.sort(all, function(a, b)
		return (RANK[a.rarity] or 0) > (RANK[b.rarity] or 0)
	end)
	return { all[1], all[2] }
end

local function clear()
	local h = holder
	if h then
		h:Destroy()
	end
	holder = nil
	table.clear(turning)
end

function MarketShowroom.show(now: number?)
	clear()
	local picks = MarketShowroom.picks(now)
	local f = Instance.new("Folder")
	f.Name = "MarketShowroom"
	f.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	holder = f
	for _, plinth in CollectionService:GetTagged("BoutiquePlinth") do
		local i = plinth:GetAttribute("PlinthIndex")
		local pick = if type(i) == "number" then picks[i] else nil
		if not plinth:IsA("BasePart") or not pick then
			continue
		end
		local c = Curios.byId[pick.id]
		local ok, fig = pcall(BrainrotFigure.build, pick.id, 2.8, if c then c.colour else nil, nil)
		if not ok or not fig then
			continue
		end
		-- (The jewel and dome on this plinth step aside on this screen.)
		local room = plinth.Parent
		if room then
			for _, d in room:GetChildren() do
				if d:IsA("BasePart") and d:GetAttribute("UnderDome") == i then
					d.LocalTransparencyModifier = 1
				end
			end
		end
		local at = CFrame.new(plinth.CFrame.Position + Vector3.new(0, plinth.Size.X / 2 + 0.25, 0))
		BrainrotFigure.place(fig, at)
		fig.Parent = f
		local root = fig.PrimaryPart
		if root then
			table.insert(turning, { root = root, at = at, phase = i * 2.1 })
			local att = Instance.new("Attachment")
			att.Parent = root
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Rate = if pick.rarity == "Mythic" then 14 else 8
			e.Lifetime = NumberRange.new(1, 2)
			e.Speed = NumberRange.new(0.4, 1.1)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Acceleration = Vector3.new(0, 0.5, 0)
			e.LightEmission = 1
			e.Size = NumberSequence.new(0.18, 0)
			e.Color = ColorSequence.new(Curios.RarityColour[pick.rarity] or Brand.Colours.gold)
			e.Parent = att
		end
		local tag = Instance.new("BillboardGui")
		tag.Name = "MarketCard"
		tag.Size = UDim2.fromOffset(220, 74)
		tag.StudsOffsetWorldSpace = Vector3.new(0, plinth.Size.X / 2 + 4.2, 0)
		tag.Adornee = plinth
		tag.MaxDistance = 45
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
		line(0, 15, if i == 1 then "BRAINROT OF THE DAY" else "TODAY AT THE MARKET", Color3.fromRGB(255, 120, 160), Brand.Fonts.heavy)
		line(15, 24, if c then c.name else pick.id, Brand.Colours.brightGold, Brand.Fonts.display)
		line(39, 18, string.format("%s  ·  %s Gilt", string.upper(pick.rarity), Fortune.format(pick.gilt)), (Curios.RarityColour[pick.rarity] or Brand.Colours.gold):Lerp(Color3.new(1, 1, 1), 0.25), Brand.Fonts.heavy)
		line(57, 15, "At the counter · new at midnight UTC", Color3.fromRGB(220, 220, 230), Brand.Fonts.body)
	end
	shownDay = math.floor((now or os.time()) / 86400)
end

-- For tests: what's shown on the plinths now (each figure's brainrot).
function MarketShowroom.shown(): { string }
	local out = {}
	local h = holder
	if h then
		for _, d in h:GetChildren() do
			if d:IsA("Model") then
				table.insert(out, tostring(d:GetAttribute("Brainrot")))
			end
		end
	end
	return out
end

function MarketShowroom.start()
	task.spawn(function()
		while true do
			local today = math.floor(os.time() / 86400)
			if shownDay ~= today or holder == nil then
				pcall(MarketShowroom.show)
			end
			task.wait(30)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if #turning == 0 then
			return
		end
		local t = os.clock()
		for _, s in turning do
			if s.root.Parent then
				s.root.CFrame = s.at * CFrame.new(0, 0.2 + math.sin(t * 1.3 + s.phase) * 0.1, 0) * CFrame.Angles(0, t * 0.5 + s.phase, 0)
			end
		end
	end)
end

return MarketShowroom
