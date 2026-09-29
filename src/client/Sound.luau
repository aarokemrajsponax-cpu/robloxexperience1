--!strict
-- Music, effects and ambience, each with its own volume; the signature chime that climbs with
-- a streak; per-space acoustics; and the dip under round cards and panels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Sound = {}

local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		return g
	end
	local ng = Instance.new("SoundGroup")
	ng.Name = name
	ng.Parent = SoundService
	return ng
end

local music = group("MaisonMusic")
local effects = group("MaisonEffects")
local ambience = group("MaisonAmbience")

local levels = { music = 0.65, effects = 0.85, ambience = 0.7 }
local dipped = false

local function applyVolumes()
	local m = if State.get("music") == "On" then (State.get("musicLevel") :: number) / 100 else 0
	local e = if State.get("effects") == "On" then (State.get("effectsLevel") :: number) / 100 else 0
	local a = if State.get("ambience") == "On" then (State.get("ambienceLevel") :: number) / 100 else 0
	levels.music, levels.effects, levels.ambience = m, e, a
	TweenService:Create(music, TweenInfo.new(0.4), { Volume = if dipped then m * 0.45 else m }):Play()
	effects.Volume = e
	ambience.Volume = a
end

for _, key in { "music", "musicLevel", "effects", "effectsLevel", "ambience", "ambienceLevel" } do
	State.watch(key, function()
		applyVolumes()
	end)
end

function Sound.dip(on: boolean)
	dipped = on
	TweenService:Create(music, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Volume = if on then levels.music * 0.45 else levels.music }):Play()
end

-- A short dip for round cards (about three seconds).
function Sound.briefDip(seconds: number?)
	Sound.dip(true)
	task.delay(seconds or 3, function()
		Sound.dip(false)
	end)
end

-- Effects: one pool of sounds per id so nothing is created per frame.
local pool: { [string]: { Sound } } = {}
local warned: { [string]: boolean } = {}

local function idFor(name: string): string
	local id = (Config.data.Assets.Sounds :: any)[name]
	return if type(id) == "string" then id else ""
end

local function take(name: string): Sound?
	local id = idFor(name)
	if id == "" then
		return nil
	end
	local list = pool[name]
	if not list then
		list = {}
		pool[name] = list
	end
	for _, s in list do
		if not s.IsPlaying then
			if s.SoundId ~= id then
				s.SoundId = id
			end
			return s
		end
	end
	if #list >= 6 then
		return list[1]
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.SoundGroup = effects
	s.Parent = SoundService
	s.Loaded:Once(function() end)
	table.insert(list, s)
	return s
end

function Sound.play(name: string, volume: number?, pitch: number?)
	local s = take(name)
	if not s then
		if not warned[name] then
			warned[name] = true
		end
		return
	end
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.TimePosition = 0
	s:Play()
end

-- The chime rings one step higher with each correct filing in a streak.
local STEPS = { 0, 2, 4, 7, 9, 12, 14, 16, 19, 21 }
local CHIMES = {
	Bells = { base = 1.0, volume = 0.55 },
	Marimba = { base = 0.78, volume = 0.6 },
	Crystal = { base = 1.26, volume = 0.45 },
	Soft = { base = 0.9, volume = 0.3 },
}

function Sound.chime(streak: number)
	local index = math.clamp(streak, 1, #STEPS)
	local semis = STEPS[index]
	local voice = CHIMES[State.get("chime")] or CHIMES.Bells
	Sound.play("chime", voice.volume, voice.base * 2 ^ (semis / 12))
end

-- Rare pieces add a bright three-note shimmer on top.
function Sound.shimmer()
	local voice = CHIMES[State.get("chime")] or CHIMES.Bells
	for i, semis in { 24, 28, 31 } do
		task.delay((i - 1) * 0.07, function()
			Sound.play("chime", voice.volume * 0.5, voice.base * 2 ^ (semis / 12))
		end)
	end
end

function Sound.wrong()
	Sound.play("wrong", 0.35, 0.7)
end

function Sound.ui()
	Sound.play("ui", 0.25, 1.1)
end

-- Each space has its own acoustics.
local REVERB: { [string]: Enum.ReverbType } = {
	street = Enum.ReverbType.City,
	foyer = Enum.ReverbType.Auditorium,
	salon = Enum.ReverbType.LivingRoom,
	velvet = Enum.ReverbType.Room,
	obsidian = Enum.ReverbType.StoneRoom,
	midnight = Enum.ReverbType.PaddedCell,
	club = Enum.ReverbType.Hallway,
	library = Enum.ReverbType.LivingRoom,
	ballroom = Enum.ReverbType.ConcertHall,
	none = Enum.ReverbType.Room,
}

-- Music per space, crossfading as you move. Ids live in Config.Assets.Music.
local tracks: { [string]: Sound } = {}
local function track(zone: string): Sound?
	local id = (Config.data.Assets.Music :: any)[zone]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local s = tracks[zone]
	if not s then
		local ns = Instance.new("Sound")
		ns.Name = "Music_" .. zone
		ns.SoundId = id
		ns.Looped = true
		ns.Volume = 0
		ns.SoundGroup = music
		ns.Parent = SoundService
		tracks[zone] = ns
		s = ns
	end
	return s
end

local currentZone = ""
function Sound.enterZone(zone: string)
	if zone == currentZone then
		return
	end
	currentZone = zone
	pcall(function()
		SoundService.AmbientReverb = REVERB[zone] or Enum.ReverbType.Room
	end)
	for name, s in tracks do
		if name ~= zone then
			local t = TweenService:Create(s, TweenInfo.new(2.5), { Volume = 0 })
			t:Play()
			t.Completed:Once(function()
				if currentZone ~= name then
					s:Pause()
				end
			end)
		end
	end
	local s = track(zone)
	if s then
		if not s.IsPlaying then
			s:Resume()
			if not s.IsPlaying then
				s:Play()
			end
		end
		TweenService:Create(s, TweenInfo.new(2.5), { Volume = 0.5 }):Play()
	end
end

applyVolumes()

return Sound
