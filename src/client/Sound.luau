--!strict
-- Music, effects and ambience, each with its own volume; the signature chime that climbs with
-- a streak; per-space acoustics; and the dip under round cards and panels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Music = require(ReplicatedStorage.Shared.Music)
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
	local sounds = Config.data.Assets.Sounds :: any
	-- "chime:harp" is a chime from the Boutique.
	local chime = string.match(name, "^chime:(%w+)$")
	local id = if chime then (sounds.chimes or {})[chime] else sounds[name]
	return if type(id) == "string" then id else ""
end

-- The chime a guest wears from the Boutique (set by Main from the Closet), or nil.
Sound.wornChime = function(): string?
	return nil
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
	local worn = Sound.wornChime()
	if worn and idFor("chime:" .. worn) ~= "" then
		Sound.play("chime:" .. worn, voice.volume, 2 ^ (semis / 12))
		return
	end
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
	boutique = Enum.ReverbType.LivingRoom,
	vault = Enum.ReverbType.StoneRoom,
	terrace = Enum.ReverbType.Plain,
	none = Enum.ReverbType.Room,
}

-- Music per space, crossfading as you move (ids in Config.Assets.Music). The Foyer's music comes
-- from the piano itself, so it carries, muffled, into the street and up the stair. A room's
-- music fills out as the run builds; the Ballroom band thins as lamps go out.
local mix = { zone = "", intensity = nil :: number?, lit = nil :: number?, soiree = false }
local loops: { [string]: Sound? } = {}
local targets: { [string]: number } = {}

local function loop(key: string, id: string, into: SoundGroup, parent: Instance?): Sound?
	if id == "" then
		return nil
	end
	local s = loops[key]
	if s and s.SoundId ~= id then
		s:Destroy()
		loops[key] = nil
		s = nil
	end
	if not s then
		local ns = Instance.new("Sound")
		ns.Name = key
		ns.SoundId = id
		ns.Looped = true
		ns.Volume = 0
		ns.SoundGroup = into
		ns.Parent = parent or SoundService
		loops[key] = ns
		s = ns
	end
	return s
end

local function asset(tree: string, key: string): string
	local t = (Config.data.Assets :: any)[tree]
	local id = if type(t) == "table" then t[key] else nil
	return if type(id) == "string" then id else ""
end

-- The piano's sound source: the Foyer's grand piano, once it has streamed in.
local function pianoPart(): BasePart?
	local maison = Workspace:FindFirstChild("Maison")
	local piano = maison and maison:FindFirstChild("GrandPiano", true)
	local case = piano and piano:FindFirstChild("Case")
	return if case and case:IsA("BasePart") then case else nil
end

local PIANO_HEARD = { foyer = true, street = true, club = true, boutique = true }

local function fadeTo(s: Sound, volume: number)
	local key = s.Name
	if targets[key] == volume and (volume == 0 or s.IsPlaying) then
		return
	end
	targets[key] = volume
	if volume > 0 and not s.IsPlaying then
		s:Resume()
		if not s.IsPlaying then
			s:Play()
		end
	end
	local t = TweenService:Create(s, TweenInfo.new(Config.data.Music.crossfade), { Volume = volume })
	t:Play()
	if volume == 0 then
		t.Completed:Once(function()
			if targets[key] == 0 then
				s:Pause()
			end
		end)
	end
end

local function remix()
	local c = Config.data.Music
	local zone = mix.zone
	local level = c.level
	local wanted: { [string]: number } = {}
	local function want(key: string, id: string, volume: number, into: SoundGroup, parent: Instance?)
		local s = loop(key, id, into, parent)
		if s then
			wanted[key] = volume
		end
	end

	-- The Foyer: the piano, heard in the room and, muffled, from the spaces around it.
	local part = pianoPart()
	local foyerId = asset("Music", "foyer")
	if part and foyerId ~= "" then
		local s = loop("Piano", foyerId, music, part)
		if s then
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 12
			s.RollOffMaxDistance = c.pianoReach
			local eq = s:FindFirstChildOfClass("EqualizerSoundEffect")
			if not eq then
				local ne = Instance.new("EqualizerSoundEffect")
				ne.Parent = s
				eq = ne
			end
			local high = if zone == "foyer" then (if mix.soiree then c.soireeBrighter else 0) else c.muffled
			TweenService:Create(eq :: EqualizerSoundEffect, TweenInfo.new(c.crossfade), { HighGain = high, MidGain = if zone == "foyer" then 0 else high / 3 }):Play()
			wanted.Piano = if PIANO_HEARD[zone] then level * 1.6 else 0
		end
	elseif zone == "foyer" then
		want("Music_foyer", foyerId, level, music)
	end

	-- Every other space: its own track, filling out as the run builds.
	local intensity = mix.intensity
	if zone ~= "foyer" and zone ~= "ballroom" then
		local layer = asset("MusicLayers", zone)
		local base = if intensity and layer == "" then 0.7 + 0.3 * intensity else 1
		want("Music_" .. zone, asset("Music", zone), level * base, music)
		if intensity and layer ~= "" then
			want("Layer_" .. zone, layer, level * intensity, music)
		end
	end

	-- The Ballroom: the band in stems when they are set, thinning as lamps go out.
	if zone == "ballroom" then
		local band = Music.band(mix.lit or Config.data.Ballroom.tables)
		local stems = Music.stems(band)
		local any = false
		for _, stem in { "full", "bass", "piano", "clock" } do
			if asset("Band", stem) ~= "" then
				any = true
			end
		end
		if any then
			for stem, share in stems do
				want("Band_" .. stem, asset("Band", stem), level * share, music)
			end
		else
			local lit = mix.lit or Config.data.Ballroom.tables
			want("Music_ballroom", asset("Music", "ballroom"), level * (0.55 + 0.45 * math.clamp(lit / Config.data.Ballroom.tables, 0, 1)), music)
		end
	end

	-- Ambience: the space's own, and the season's layer beneath it.
	want("Ambience_" .. zone, asset("Ambience", zone), 0.5, ambience)
	local season = tostring(Workspace:GetAttribute("Season") or "")
	want("Season_" .. season, asset("SeasonAmbience", season), 0.3, ambience)

	for key, s in loops do
		if s then
			fadeTo(s, wanted[key] or 0)
		end
	end
end

function Sound.enterZone(zone: string)
	if zone == mix.zone then
		return
	end
	mix.zone = zone
	pcall(function()
		SoundService.AmbientReverb = REVERB[zone] or Enum.ReverbType.Room
	end)
	remix()
end

-- How far the run has built (Music.intensity), or nil away from a table.
function Sound.setIntensity(intensity: number?)
	if intensity ~= mix.intensity then
		mix.intensity = intensity
		remix()
	end
end

-- Lamps still lit in the Ballroom, or nil between evenings.
function Sound.setLamps(lit: number?)
	if lit ~= mix.lit then
		local before = if mix.lit then Music.band(mix.lit) else nil
		mix.lit = lit
		if not lit or not before or Music.band(lit) ~= before or asset("Band", "full") == "" then
			remix()
		end
	end
end

local function watchWorld()
	mix.soiree = Workspace:GetAttribute("SoireeActive") == true
	Workspace:GetAttributeChangedSignal("SoireeActive"):Connect(function()
		mix.soiree = Workspace:GetAttribute("SoireeActive") == true
		remix()
	end)
	Workspace:GetAttributeChangedSignal("Season"):Connect(remix)
	-- The piano streams in after the guest arrives: hand the Foyer's music to it once it does.
	task.spawn(function()
		for _ = 1, 60 do
			if pianoPart() then
				local old = loops.Music_foyer
				if old then
					old:Destroy()
					loops.Music_foyer = nil
				end
				remix()
				return
			end
			task.wait(1)
		end
	end)
end
watchWorld()

applyVolumes()

return Sound
