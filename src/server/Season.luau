--!strict
-- The house follows the calendar. The server reads the UTC date, so everyone in a server shares
-- one season and nobody can farm pieces with their device clock. It re-checks every minute and
-- turns by itself: lighting crossfades slowly, never snaps.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Seasons = require(ReplicatedStorage.Shared.Seasons)

local Season = {}

local current: Seasons.Season? = nil
local grade: ColorCorrectionEffect? = nil

local BASE_AMBIENT = Color3.fromRGB(14, 14, 18)
local BASE_OUTDOOR = Color3.fromRGB(24, 26, 34)

local function effect<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	local e = Instance.new(className :: any)
	e.Name = name
	e.Parent = Lighting
	return e :: any
end

-- Night lighting. The place file's own Lighting children (from the Baseplate template) are
-- replaced for the running session only; nothing in the saved place changes.
local function setupLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("SunRaysEffect") or child:IsA("Clouds") then
			if not string.find(child.Name, "^Maison") then
				child:Destroy()
			end
		elseif child:IsA("PostEffect") and not string.find(child.Name, "^Maison") then
			child.Enabled = false
		end
	end
	Lighting.ClockTime = 0.2
	Lighting.GeographicLatitude = 41.7
	Lighting.Brightness = 0.6
	Lighting.Ambient = BASE_AMBIENT
	Lighting.OutdoorAmbient = BASE_OUTDOOR
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.FogEnd = 100000

	local sky = effect("Sky", "MaisonSky") :: Sky
	sky.CelestialBodiesShown = false
	sky.StarCount = 1600
	local air = effect("Atmosphere", "MaisonAir") :: Atmosphere
	-- A light night air: deep enough to give the street distance, thin enough that rooms stay
	-- crisp (a heavy haze washes the interiors out grey).
	air.Density = 0.26
	air.Offset = 0.05
	air.Color = Color3.fromRGB(46, 50, 64)
	air.Decay = Color3.fromRGB(20, 22, 32)
	air.Glare = 0
	air.Haze = 0.6
	local bloom = effect("BloomEffect", "MaisonBloom") :: BloomEffect
	bloom.Intensity = 0.4
	bloom.Size = 30
	bloom.Threshold = 1.1
	local cc = effect("ColorCorrectionEffect", "MaisonGrade") :: ColorCorrectionEffect
	cc.Contrast = 0.16
	cc.Saturation = -0.12
	cc.Brightness = 0.01
	cc.TintColor = Color3.new(1, 1, 1)
	grade = cc
end

local function tintLamps(key: Color3, seconds: number)
	for _, light in CollectionService:GetTagged("HouseLamp") do
		if light:IsA("Light") then
			local base = light:GetAttribute("BaseColor")
			if typeof(base) == "Color3" then
				local goal = base:Lerp(key, 0.16)
				TweenService:Create(light, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Color = goal }):Play()
			end
		end
	end
end

local function apply(s: Seasons.Season, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	if grade then
		TweenService:Create(grade, info, { TintColor = Color3.new(1, 1, 1):Lerp(s.grade, 0.1) }):Play()
	end
	TweenService:Create(Lighting, info, {
		Ambient = BASE_AMBIENT:Lerp(s.fill, 0.08),
		OutdoorAmbient = BASE_OUTDOOR:Lerp(s.fill, 0.12),
	}):Play()
	tintLamps(s.key, seconds)
end

-- Dresses the house for a season (set by Main: SeasonDress.apply).
Season.dress = function(_id: string) end

local function publish(s: Seasons.Season)
	local ok, err = pcall(function()
		Season.dress(s.id)
	end)
	if not ok then
		warn("[Maison] Dressing the house for the season failed:", err)
	end
	Workspace:SetAttribute("Season", s.id)
	Workspace:SetAttribute("SeasonName", s.name)
	Workspace:SetAttribute("SeasonLine", s.line)
	Workspace:SetAttribute("SeasonWeather", s.weather)
end

function Season.current(): Seasons.Season
	return current or Seasons.now()
end

-- The owner's panel can dress the house in another season for a while; it turns back by itself.
local forcedUntil = 0
function Season.force(id: string, seconds: number): boolean
	local s = Seasons.byId[id]
	if not s then
		return false
	end
	forcedUntil = os.time() + seconds
	current = s
	publish(s)
	apply(s, 4)
	return true
end

function Season.start()
	setupLighting()
	local s = Seasons.now()
	current = s
	publish(s)
	apply(s, 0.1)
	task.spawn(function()
		while true do
			task.wait(60)
			local now = Seasons.now()
			if os.time() >= forcedUntil and (current == nil or now.id ~= current.id) then
				current = now
				publish(now)
				apply(now, 8)
			end
		end
	end)
	-- Late-built lamps (tables, staff lamps) pick up the tint too.
	CollectionService:GetInstanceAddedSignal("HouseLamp"):Connect(function(light)
		if light:IsA("Light") and current then
			local base = light:GetAttribute("BaseColor")
			if typeof(base) == "Color3" then
				light.Color = base:Lerp(current.key, 0.16)
			end
		end
	end)
end

return Season
