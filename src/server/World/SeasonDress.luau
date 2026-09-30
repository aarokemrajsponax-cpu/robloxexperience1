--!strict
-- The house dresses for the season (§10): lanterns and embers for All Hallows (and Lights Out by
-- candlelight), garlands and a wreath for Yuletide, copper and candles for The Long Table, the
-- Terrace doors open in High Summer, and flowers in the season's colour on the lectern and the
-- piano all year. Rebuilt whenever the season turns; nothing here is lit by a light of its own
-- (the glow is Neon), so the house's light budget holds.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Kit = require(script.Parent.Kit)
local Terrace = require(script.Parent.Terrace)

local L = Kit.Looks
local F = Layout.Foyer
local FLOOR = Layout.FLOOR

local SeasonDress = {}

local PUMPKIN = { color = Color3.fromRGB(214, 104, 30), material = Enum.Material.SmoothPlastic }
local FLAME = { color = Color3.fromRGB(255, 170, 70), material = Enum.Material.Neon }
local PINE = { color = Color3.fromRGB(24, 58, 36), material = Enum.Material.Grass }
local COPPER = { color = Color3.fromRGB(184, 104, 58), material = Enum.Material.Metal, reflectance = 0.2 }
local CANDLE_LIGHT = Color3.fromRGB(255, 150, 70)

local function noHit(): { [string]: any }
	return { collide = false, query = false, shadow = false }
end

-- A carved lantern on the ground: a pumpkin-round body with a glow inside.
local function lantern(m: Instance, at: Vector3)
	Kit.ball(m, "Lantern", 1.6, at + Vector3.new(0, 0.7, 0), PUMPKIN, noHit())
	Kit.ball(m, "LanternGlow", 0.9, at + Vector3.new(0, 0.75, -0.45), FLAME, noHit())
	Kit.post(m, "LanternStem", 0.35, 0.2, at + Vector3.new(0, 1.45, 0), L.darkWood, noHit())
end

-- A garland swag of pine between two points, with a bauble every third sprig.
local function garland(m: Instance, a: Vector3, b: Vector3, count: number)
	for i = 0, count do
		local t = i / count
		local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 1.6, 0)
		Kit.ball(m, "Garland", 0.9, p, PINE, noHit())
		if i % 3 == 1 then
			Kit.ball(m, "Bauble", 0.45, p - Vector3.new(0, 0.55, 0), { color = if i % 2 == 0 then Color3.fromRGB(150, 22, 32) else Color3.fromRGB(216, 176, 90), material = Enum.Material.Glass, reflectance = 0.3 }, noHit())
		end
	end
end

local function wreath(m: Instance, centre: Vector3, facing: Vector3)
	local right = facing:Cross(Vector3.yAxis).Unit
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		Kit.ball(m, "Wreath", 0.8, centre + right * math.cos(a) * 1.4 + Vector3.yAxis * math.sin(a) * 1.4, PINE, noHit())
	end
	Kit.ball(m, "WreathBow", 0.6, centre - Vector3.yAxis * 1.4, { color = Color3.fromRGB(150, 22, 32), material = Enum.Material.Fabric }, noHit())
end

-- A copper floor candelabrum with three lit candles.
local function candelabrum(m: Instance, at: Vector3)
	Kit.post(m, "Candelabrum", 5, 0.35, at, COPPER, { collide = true })
	Kit.part(m, "CandelabrumArm", Vector3.new(2.2, 0.2, 0.2), CFrame.new(at + Vector3.new(0, 5, 0)), COPPER, noHit())
	for i = -1, 1 do
		local base = at + Vector3.new(i * 1, 5.1, 0)
		Kit.post(m, "Candle", 0.8, 0.22, base, L.bone, noHit())
		Kit.ball(m, "Flame", 0.22, base + Vector3.new(0, 1, 0), FLAME, noHit())
	end
end

-- Flowers in the season's colour: a small vase of blooms.
local function vase(m: Instance, at: Vector3, colour: Color3)
	Kit.post(m, "Vase", 0.8, 0.5, at, L.blackLacquer, noHit())
	Kit.ball(m, "Blooms", 0.9, at + Vector3.new(0, 1.1, 0), { color = colour, material = Enum.Material.Fabric }, noHit())
end

-- The Ballroom's table lamps burn candle-coloured on All Hallows (their tint is kept as the
-- lamp's BaseColor, which the season's grade leans on).
local function candlelight(on: boolean)
	for _, tableModel in CollectionService:GetTagged("MaisonTable") do
		if tableModel:GetAttribute("Room") ~= "ballroom" then
			continue
		end
		for _, light in tableModel:GetDescendants() do
			if light:IsA("SpotLight") then
				local house = light:GetAttribute("HouseColor")
				if typeof(house) ~= "Color3" then
					house = light:GetAttribute("BaseColor") or light.Color
					light:SetAttribute("HouseColor", house)
				end
				local colour = if on then CANDLE_LIGHT else house :: Color3
				light:SetAttribute("BaseColor", colour)
				light.Color = colour
			end
		end
	end
	Workspace:SetAttribute("Candlelight", on)
end

function SeasonDress.apply(id: string)
	local maison = Workspace:FindFirstChild("Maison")
	if not maison then
		return
	end
	local old = maison:FindFirstChild("SeasonDress")
	if old then
		old:Destroy()
	end
	local m = Kit.model(maison, "SeasonDress")
	local season = Seasons.byId[id]
	-- Flowers on the lectern and on the piano, all year.
	if season then
		vase(m, (F.lectern * CFrame.new(1, 4.1, -0.3)).Position, season.weatherColours[1])
		vase(m, (F.piano * CFrame.new(-1.6, 4.05, 1.5)).Position, season.weatherColours[2] or season.weatherColours[1])
	end
	if id == "hallows" then
		for _, p in { Vector3.new(-7, 0, -17), Vector3.new(7, 0, -17), Vector3.new(-10.5, 0, -18.5), Vector3.new(10.5, 0, -18.5) } do
			lantern(m, p)
		end
		for _, p in { Vector3.new(-27, FLOOR, -5), Vector3.new(27, FLOOR, -5), Vector3.new(4.5, FLOOR, 23), Vector3.new(11.5, FLOOR, 23) } do
			lantern(m, p)
		end
	elseif id == "yule" then
		local y = FLOOR + 17
		for _, run in { { Vector3.new(-29.4, y, -6), Vector3.new(-29.4, y, 14) }, { Vector3.new(-29.4, y, 20), Vector3.new(-29.4, y, 40) }, { Vector3.new(29.4, y, -6), Vector3.new(29.4, y, 14) }, { Vector3.new(29.4, y, 20), Vector3.new(29.4, y, 40) } } do
			garland(m, run[1], run[2], 14)
		end
		-- Over the front door, and a wreath on it.
		garland(m, Vector3.new(-7, 16, -10.8), Vector3.new(7, 16, -10.8), 12)
		wreath(m, Vector3.new(0, 11, -10.9), Vector3.new(0, 0, -1))
	elseif id == "longtable" then
		for _, p in { Vector3.new(-26, FLOOR, -4), Vector3.new(26, FLOOR, -4), Vector3.new(-26, FLOOR, 38), Vector3.new(26, FLOOR, 30) } do
			candelabrum(m, p)
		end
	end
	candlelight(id == "hallows")
	Terrace.setOpen(id == "summer")
	Workspace:SetAttribute("TerraceOpen", id == "summer")
end

return SeasonDress
