--!strict
-- What a guest wears, and how the house shows it: the nameplate over every guest (with their
-- Mark, and their frame), the table they sit at (felt, rims and lamp in their style), and their
-- house look. Equipping is checked here; chimes, trails, card backs and flourishes are drawn on
-- the guest's own screen from what they wear.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Ledger = require(ReplicatedStorage.Shared.Ledger)
local Rating = require(ReplicatedStorage.Shared.Rating)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)

local Profiles = require(script.Parent.Profiles)

local Dressing = {}

local descriptions: { [Player]: HumanoidDescription } = {}
local dressed: { [Model]: Player } = {}

-- Any item id, including the Ledger's editions.
function Dressing.item(id: string): Wardrobe.Item?
	local medal = string.match(id, "^soiree:([%d%-]+):medal$")
	if medal then
		return Wardrobe.soireeMedal(medal)
	end
	return Wardrobe.get(id) or Ledger.item(id)
end

local function equippedItem(data: Profiles.Data, kind: string): Wardrobe.Item?
	local id = data.equipped[kind]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	return Dressing.item(id)
end

---------------------------------------------------------------------------------------------------
-- Nameplates
---------------------------------------------------------------------------------------------------
-- A guest's Circle crest: its glyph and colour, or nil (set by Main from CircleService).
Dressing.crestOf = function(_data: Profiles.Data): (string?, Color3?)
	return nil, nil
end

function Dressing.nameplate(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head or not head:IsA("BasePart") then
		return
	end
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local data = Profiles.get(player)
	local old = head:FindFirstChild("Nameplate")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(200, 34)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	gui.Adornee = head
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.new(1, 0, 1, 0)
	plate.AutomaticSize = Enum.AutomaticSize.None
	plate.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
	plate.BackgroundTransparency = 0.35
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = plate
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1
	stroke.Color = Brand.Colours.deepGold
	stroke.Transparency = 0.4
	stroke.Parent = plate
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -12, 1, 0)
	name.Position = UDim2.fromOffset(6, 0)
	name.FontFace = Brand.Fonts.display
	name.TextScaled = true
	name.TextColor3 = Brand.Colours.bone
	name.Text = player.DisplayName
	name.Parent = plate
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = 18
	sizeLimit.Parent = name
	if data then
		local frame = equippedItem(data, "nameplate")
		if not frame and data.blackCard.active then
			frame = Wardrobe.get("plate_blackcard")
		end
		if not frame and data.goldKey then
			frame = Wardrobe.get("plate_goldkey")
		end
		if frame then
			plate.BackgroundColor3 = frame.style.fill or plate.BackgroundColor3
			plate.BackgroundTransparency = 0.15
			stroke.Color = frame.style.frame or stroke.Color
			stroke.Thickness = 2
			stroke.Transparency = 0
			if frame.style.line then
				name.TextColor3 = frame.style.line
			end
		end
		-- The Mark, as a small stamped word beside the name (after the placement evenings).
		if data.duel.matches >= Config.data.Library.placementMatches and data.settings.showMark ~= "Off" then
			local mark = Instance.new("TextLabel")
			mark.BackgroundTransparency = 1
			mark.AnchorPoint = Vector2.new(0.5, 0)
			mark.Position = UDim2.new(0.5, 0, 1, 1)
			mark.Size = UDim2.new(1, 0, 0.5, 0)
			mark.FontFace = Brand.Fonts.bodyMedium
			mark.TextScaled = true
			mark.TextColor3 = Brand.Colours.gold
			mark.Text = string.upper(Rating.mark(data.duel.r).label)
			mark.Parent = plate
		end
		-- The Circle's crest at the plate's left end (each can be hidden in Settings).
		local glyph, colour = Dressing.crestOf(data)
		if glyph and data.settings.showCrest ~= "Off" then
			local crest = Instance.new("TextLabel")
			crest.Name = "Crest"
			crest.BackgroundTransparency = 1
			crest.AnchorPoint = Vector2.new(1, 0.5)
			crest.Position = UDim2.new(0, -2, 0.5, 0)
			crest.Size = UDim2.new(0.18, 0, 1, 0)
			crest.FontFace = Brand.Fonts.display
			crest.TextScaled = true
			crest.TextColor3 = colour or Brand.Colours.gold
			crest.Text = glyph
			crest.Parent = plate
		end
	end
	gui.Parent = head
end

---------------------------------------------------------------------------------------------------
-- Tables
---------------------------------------------------------------------------------------------------
local function remember(part: Instance, attr: string, value: any)
	if part:GetAttribute(attr) == nil then
		part:SetAttribute(attr, value)
	end
end

local function styleTable(model: Model, felt: Color3?, rim: Color3?, lamp: Color3?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Felt" and felt then
				remember(d, "HouseColour", d.Color)
				d.Color = felt
			elseif string.sub(d.Name, 1, 7) == "CaseRim" and rim then
				remember(d, "HouseColour", d.Color)
				d.Color = rim
			end
		elseif d:IsA("SpotLight") and d.Name == "TableLight" and lamp then
			remember(d, "HouseColour", d.Color)
			d.Color = lamp
		end
	end
end

-- Dresses the table a guest sits at in their table style and lamp style.
function Dressing.dressTable(model: Model, player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local tableStyle = equippedItem(data, "table")
	if not tableStyle and data.goldKey then
		tableStyle = Wardrobe.get("table_goldkey")
	end
	local lampStyle = equippedItem(data, "lamp")
	dressed[model] = player
	if not tableStyle and not lampStyle then
		return
	end
	styleTable(
		model,
		if tableStyle then tableStyle.style.felt else nil,
		if tableStyle then tableStyle.style.rim else nil,
		if lampStyle then lampStyle.style.colour else nil
	)
end

-- Back to the house's own colours when the guest leaves.
function Dressing.undressTable(model: Model)
	if not dressed[model] then
		return
	end
	dressed[model] = nil
	for _, d in model:GetDescendants() do
		local c = d:GetAttribute("HouseColour")
		if typeof(c) == "Color3" then
			if d:IsA("BasePart") then
				d.Color = c
			elseif d:IsA("Light") then
				d.Color = c
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- House looks
---------------------------------------------------------------------------------------------------
function Dressing.look(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = Profiles.get(player)
	if not humanoid or not data then
		return
	end
	local base = descriptions[player]
	if not base then
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(math.max(1, player.UserId))
		end)
		if not ok or not desc then
			return
		end
		base = desc
		descriptions[player] = desc
	end
	local item = equippedItem(data, "look")
	local desc = base:Clone()
	if item and Wardrobe.deliverable(item) then
		local look = (Config.data.Assets :: any).Looks[item.style.outfit]
		if look then
			if (look.shirt or 0) ~= 0 then
				desc.Shirt = look.shirt
			end
			if (look.pants or 0) ~= 0 then
				desc.Pants = look.pants
			end
			if (look.accessories or "") ~= "" then
				desc.HatAccessory = look.accessories
			end
		end
	end
	pcall(function()
		humanoid:ApplyDescriptionAsync(desc)
	end)
end

---------------------------------------------------------------------------------------------------
-- Equipping
---------------------------------------------------------------------------------------------------
-- Whether a guest may wear an item (owned, or a Gold Key piece while they hold the key).
function Dressing.canWear(data: Profiles.Data, item: Wardrobe.Item): boolean
	if item.source == "goldKey" then
		return data.goldKey
	elseif item.source == "blackCard" and item.kind == "nameplate" then
		return data.blackCard.active
	end
	return data.owned[item.id] == true
end

-- Wears an item (or, with an empty id, the house default for that kind).
function Dressing.equip(player: Player, kind: string, id: string): boolean
	local data = Profiles.get(player)
	if not data or not Wardrobe.KindNames[kind] then
		return false
	end
	if id ~= "" then
		local item = Dressing.item(id)
		if not item or item.kind ~= kind or not Dressing.canWear(data, item) or not Wardrobe.deliverable(item) then
			return false
		end
	end
	data.equipped[kind] = id
	if kind == "nameplate" then
		Dressing.nameplate(player)
	elseif kind == "look" then
		Dressing.look(player)
	end
	-- A seated guest's table changes at once.
	for model, who in dressed do
		if who == player then
			Dressing.undressTable(model)
			Dressing.dressTable(model, player)
		end
	end
	return true
end

-- The table a guest is sitting at, for re-dressing after an equip.
function Dressing.seatedAt(model: Model, player: Player)
	dressed[model] = player
end

-- Dresses any table as a guest sits and undresses it as they leave (every service marks its
-- tables with the occupant's user id).
local function watchTable(model: Model)
	model:GetAttributeChangedSignal("Occupant"):Connect(function()
		local id = model:GetAttribute("Occupant")
		Dressing.undressTable(model)
		if type(id) == "number" then
			local player = Players:GetPlayerByUserId(id)
			if player then
				Dressing.dressTable(model, player)
			end
		end
	end)
end

function Dressing.start()
	local CollectionService = game:GetService("CollectionService")
	for _, m in CollectionService:GetTagged("MaisonTable") do
		if m:IsA("Model") then
			watchTable(m)
		end
	end
	local function spawned(player: Player)
		task.wait(0.5)
		if player.Parent == Players then
			Dressing.nameplate(player)
			Dressing.look(player)
		end
	end
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			spawned(player)
		end)
		if player.Character then
			task.spawn(spawned, player)
		end
	end
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerAdded:Connect(hook)
	Profiles.Loaded:Connect(function(player: Player)
		task.spawn(spawned, player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		descriptions[player] = nil
		for model, who in dressed do
			if who == player then
				Dressing.undressTable(model)
			end
		end
	end)
end

return Dressing
