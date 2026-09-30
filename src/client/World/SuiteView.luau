--!strict
-- Your Suite, drawn on your own screen (§3): the piece in each spot from your Suite (or the
-- house's own where it has one), the Gold Key rooms opened for holders, and nobody else in the
-- room: other guests in the Suite are hidden here, so it's always yours alone.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Suite = require(ReplicatedStorage.Shared.Suite)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Closet = require(script.Parent.Parent.Closet)

local SuiteView = {}

local player = Players.LocalPlayer
local S = Layout.Suite
local GOLD = Color3.fromRGB(198, 160, 82)

-- The house's own pieces, for the spots that have one.
local HOUSE: { [string]: { [string]: any } } = {
	sofa = { colour = Color3.fromRGB(18, 18, 22), accent = GOLD },
	chair = { colour = Color3.fromRGB(18, 18, 22), accent = GOLD },
	rug = { colour = Color3.fromRGB(40, 14, 18), accent = GOLD },
	lamp = { colour = Color3.fromRGB(236, 214, 170), accent = GOLD },
}

local folder: Folder? = nil
local inside = false
local hidden: { [Player]: boolean? } = {}

local function part(parent: Instance, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.Fabric
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function materialOf(style: { [string]: any }): Enum.Material
	local name = style.material
	if type(name) == "string" then
		local ok, m = pcall(function()
			return (Enum.Material :: any)[name]
		end)
		if ok and m then
			return m
		end
	end
	return Enum.Material.Fabric
end

-- Each spot's piece, built in the spot's own frame (facing -Z, standing on the floor).
local RECIPES: { [string]: (Model, CFrame, { [string]: any }) -> () } = {
	sofa = function(m, cf, st)
		local mat = materialOf(st)
		part(m, Vector3.new(7, 1.2, 2.6), cf * CFrame.new(0, 1.2, 0), st.colour, mat)
		part(m, Vector3.new(7, 2.4, 0.6), cf * CFrame.new(0, 2.4, 1.1), st.colour, mat)
		for _, x in { -3.5, 3.5 } do
			part(m, Vector3.new(0.7, 1.9, 2.6), cf * CFrame.new(x, 1.5, 0), st.colour, mat)
			part(m, Vector3.new(0.3, 0.6, 0.3), cf * CFrame.new(x * 0.9, 0.3, -0.9), st.accent, Enum.Material.Metal)
		end
	end,
	chair = function(m, cf, st)
		local mat = materialOf(st)
		part(m, Vector3.new(2.8, 1.2, 2.6), cf * CFrame.new(0, 1.2, 0), st.colour, mat)
		part(m, Vector3.new(2.8, 3.4, 0.5), cf * CFrame.new(0, 2.9, 1.1), st.colour, mat)
		for _, x in { -1.3, 1.3 } do
			part(m, Vector3.new(0.4, 1.4, 1.4), cf * CFrame.new(x, 3.6, 0.5), st.colour, mat)
			part(m, Vector3.new(0.5, 1.6, 2.6), cf * CFrame.new(x * 1.08, 1.5, 0), st.colour, mat)
			part(m, Vector3.new(0.25, 0.6, 0.25), cf * CFrame.new(x, 0.3, -1), st.accent, Enum.Material.Metal)
		end
	end,
	rug = function(m, cf, st)
		part(m, Vector3.new(12.4, 0.04, 8.4), cf * CFrame.new(0, 0.02, 0), st.accent)
		part(m, Vector3.new(12, 0.06, 8), cf * CFrame.new(0, 0.05, 0), st.colour)
		part(m, Vector3.new(8, 0.07, 4.2), cf * CFrame.new(0, 0.06, 0), st.accent:Lerp(st.colour, 0.6))
	end,
	lamp = function(m, cf, st)
		part(m, Vector3.new(0.2, 1.2, 1.2), cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), st.accent, Enum.Material.Metal, Enum.PartType.Cylinder)
		part(m, Vector3.new(5.6, 0.2, 0.2), cf * CFrame.new(0, 2.9, 0) * CFrame.Angles(0, 0, math.rad(90)), st.accent, Enum.Material.Metal, Enum.PartType.Cylinder)
		local shade = part(m, Vector3.new(1.2, 1.7, 1.7), cf * CFrame.new(0, 5.9, 0) * CFrame.Angles(0, 0, math.rad(90)), st.colour, Enum.Material.Glass, Enum.PartType.Cylinder)
		shade.Transparency = 0.15
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 206, 150)
		light.Brightness = 0.9
		light.Range = 12
		light.Parent = shade
	end,
	painting = function(m, cf, st)
		part(m, Vector3.new(6, 4.4, 0.2), cf, st.accent, Enum.Material.Metal)
		part(m, Vector3.new(5.4, 3.8, 0.1), cf * CFrame.new(0, 0, -0.12), st.colour, Enum.Material.Fabric)
		part(m, Vector3.new(2.6, 1.2, 0.05), cf * CFrame.new(0.6, -0.4, -0.17), st.colour:Lerp(Color3.fromRGB(230, 190, 120), 0.35), Enum.Material.Fabric)
	end,
	bar = function(m, cf, st)
		part(m, Vector3.new(5, 3.8, 1.6), cf * CFrame.new(0, 1.9, 0), st.colour, Enum.Material.Wood)
		part(m, Vector3.new(5.2, 0.15, 1.8), cf * CFrame.new(0, 3.87, 0), st.accent, Enum.Material.Metal)
		for i = -1, 1 do
			part(m, Vector3.new(0.9, 0.35, 0.35), cf * CFrame.new(i * 0.9, 4.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 70, 44), Enum.Material.Glass, Enum.PartType.Cylinder)
		end
	end,
	shelf = function(m, cf, st)
		part(m, Vector3.new(7, 9, 1.2), cf * CFrame.new(0, 4.5, 0), st.colour, Enum.Material.Wood)
		for i = 1, 4 do
			part(m, Vector3.new(6.4, 1.3, 0.3), cf * CFrame.new(0, i * 2 - 0.6, -0.5), st.accent:Lerp(Color3.fromRGB(60, 40, 30), (i % 2) * 0.4), Enum.Material.Fabric)
		end
	end,
	mirror = function(m, cf, st)
		part(m, Vector3.new(3, 8, 0.3), cf * CFrame.new(0, 4.3, 0), st.accent, Enum.Material.Metal)
		local glass = part(m, Vector3.new(2.6, 7.4, 0.1), cf * CFrame.new(0, 4.3, -0.18), st.colour, Enum.Material.Glass)
		glass.Reflectance = 0.6
	end,
	chaise = function(m, cf, st)
		part(m, Vector3.new(5, 1.1, 2), cf * CFrame.new(0, 1.1, 0), st.colour)
		part(m, Vector3.new(1.2, 2.2, 2), cf * CFrame.new(-2.3, 1.8, 0), st.colour)
		part(m, Vector3.new(5, 0.2, 2.1), cf * CFrame.new(0, 0.5, 0), st.accent, Enum.Material.Metal)
	end,
	desk = function(m, cf, st)
		part(m, Vector3.new(5, 0.3, 2.6), cf * CFrame.new(0, 3, 0), st.colour, Enum.Material.Wood)
		part(m, Vector3.new(3.6, 0.05, 1.8), cf * CFrame.new(0, 3.17, 0), st.accent, Enum.Material.Leather)
		for _, x in { -1.8, 1.8 } do
			part(m, Vector3.new(1.3, 2.85, 2.4), cf * CFrame.new(x, 1.45, 0), st.colour, Enum.Material.Wood)
		end
	end,
	globe = function(m, cf, st)
		part(m, Vector3.new(0.2, 1.4, 1.4), cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), st.accent, Enum.Material.Wood, Enum.PartType.Cylinder)
		part(m, Vector3.new(2.4, 0.25, 0.25), cf * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)), st.accent, Enum.Material.Metal, Enum.PartType.Cylinder)
		part(m, Vector3.new(2, 2, 2), cf * CFrame.new(0, 3.3, 0), st.colour, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end,
}

-- What stands in each spot for this guest: { [spot] = style }, nil where the spot is bare.
function SuiteView.pieces(placed: { [string]: string }, goldKey: boolean): { [string]: { [string]: any } }
	local out = {}
	for _, spot in Suite.Spots do
		if not Suite.roomOpen(spot.room, goldKey) then
			continue
		end
		local id = placed[spot.id]
		local item = if type(id) == "string" and id ~= "" then Wardrobe.get(id) else nil
		if item and Suite.spotOf(item) == spot.id then
			out[spot.id] = item.style
		elseif spot.house then
			out[spot.id] = HOUSE[spot.id]
		end
	end
	return out
end

local function draw()
	local old = folder
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Suite"
	f.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	folder = f
	for spotId, style in SuiteView.pieces(Closet.suite, Closet.goldKey) do
		local recipe = RECIPES[spotId]
		local cf = S.spots[spotId]
		if recipe and cf then
			local m = Instance.new("Model")
			m.Name = spotId
			recipe(m, cf, style)
			m.Parent = f
		end
	end
end

local function clear()
	local f = folder
	if f then
		f:Destroy()
		folder = nil
	end
end

-- The Gold Key rooms: open on a holder's screen, shut on everyone else's.
local function doors()
	for _, door in CollectionService:GetTagged("SuiteAlcove") do
		if door:IsA("BasePart") then
			local open = Closet.goldKey
			door.CanCollide = not open
			door.LocalTransparencyModifier = if open then 1 else 0
			for _, d in door:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = door.LocalTransparencyModifier
				end
			end
		end
	end
end

-- The Gold Key opens the Terrace all year: on a holder's screen its doors let them through.
local function terrace()
	local open = Workspace:GetAttribute("TerraceOpen") == true
	for _, door in CollectionService:GetTagged("TerraceDoor") do
		if door:IsA("BasePart") and not open then
			local mine = Closet.goldKey
			door.CanCollide = not mine
			door.LocalTransparencyModifier = if mine then 0.8 else 0
		end
	end
end
SuiteView.terrace = terrace

-- Other guests in the Suite aren't drawn here: each guest's Suite is their own.
local function setHidden(other: Player, hide: boolean)
	local character = other.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if hide then 1 else 0
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = if hide then 1 else 0
		elseif d:IsA("BillboardGui") then
			d.Enabled = not hide
		end
	end
	hidden[other] = if hide then true else nil
end

local function privacy()
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local there = root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "suite"
			if there and not hidden[other] then
				setHidden(other, true)
			elseif not there and hidden[other] then
				setHidden(other, false)
			end
		end
	end
end

function SuiteView.start()
	doors()
	terrace()
	Workspace:GetAttributeChangedSignal("TerraceOpen"):Connect(terrace)
	Closet.Changed:Connect(function()
		doors()
		terrace()
		if inside then
			draw()
		end
	end)
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local now = root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "suite"
			if now and not inside then
				inside = true
				draw()
			elseif not now and inside then
				inside = false
				clear()
			end
			privacy()
			task.wait(0.25)
		end
	end)
end

return SuiteView
