--!strict
-- Music, effects and ambience, each with its own volume; the signature chime that climbs with
-- a streak; per-space acoustics; and the dip under round cards and panels.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Music = require(ReplicatedStorage.Shared.Music)
local SoundSheet = require(ReplicatedStorage.Shared.SoundSheet)
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

-- Effects. Each one comes from, in order:
--   1. a sound set for that name in Config.Assets.Sounds (yours wins);
--   2. the house's sound sheet: one uploaded file holding every table sound, each in several
--      takes (Config.Assets.SoundSheet; where each take sits is in Shared.SoundSheet);
--   3. real recordings from Roblox's licensed sound library (Config.Assets.LibrarySounds), free
--      in any experience, so the table sounds right with nothing uploaded;
--   4. Roblox's own built-in sounds, softened, last of all.
-- Every play picks a different take from last time and drifts a little in pitch and volume, so
-- the same action never sounds exactly the same twice.
local PING = "rbxasset://sounds/electronicpingshort.wav"
local GET_UP = "rbxasset://sounds/action_get_up.mp3"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
-- The stand-ins, each with the pitch and level that make it closest to the real thing.
local BUILT_IN: { [string]: { id: string, pitch: number, volume: number } } = {
	chime = { id = PING, pitch = 1, volume = 1 },
	round = { id = PING, pitch = 0.9, volume = 1 },
	complete = { id = PING, pitch = 0.8, volume = 1 },
	combo = { id = PING, pitch = 1.5, volume = 0.8 },
	low = { id = PING, pitch = 0.6, volume = 1 },
	pickup = { id = GET_UP, pitch = 1.1, volume = 0.8 },
	chair = { id = GET_UP, pitch = 1, volume = 1 },
	enter = { id = GET_UP, pitch = 0.9, volume = 0.6 },
	place = { id = LAND, pitch = 1.1, volume = 0.8 },
	drop = { id = LAND, pitch = 1, volume = 1 },
	deal = { id = LAND, pitch = 1.3, volume = 0.6 },
	wrong = { id = LAND, pitch = 0.7, volume = 0.8 },
}
-- How far each sound may drift per play: pitch as a fraction, volume as a fraction. Tuned sounds
-- (the chime, which climbs in steps) keep their pitch.
local DRIFT: { [string]: { pitch: number, volume: number } } = {
	chime = { pitch = 0, volume = 0.06 },
	combo = { pitch = 0, volume = 0.05 },
	round = { pitch = 0, volume = 0.05 },
	complete = { pitch = 0, volume = 0.05 },
	low = { pitch = 0, volume = 0.05 },
	slide = { pitch = 0.08, volume = 0.25 },
	deal = { pitch = 0.07, volume = 0.2 },
	hover = { pitch = 0.05, volume = 0.15 },
}
local DEFAULT_DRIFT = { pitch = 0.045, volume = 0.12 }

local pool: { [string]: { Sound } } = {}
local lastTake: { [string]: number } = {}

local function idFor(name: string): string
	local sounds = Config.data.Assets.Sounds :: any
	-- "chime:harp" is a chime from the Boutique.
	local chime = string.match(name, "^chime:(%w+)$")
	local id = if chime then (sounds.chimes or {})[chime] else sounds[name]
	return if type(id) == "string" then id else ""
end

-- The house's own audio, found by name: import the four files in Studio's Asset Manager and
-- drop them into SoundService, and they're used without copying a single id. An id set in
-- Config always wins.
local found: { [string]: string } = {}
local foundAt = -math.huge
local function findUploaded(name: string): string
	if os.clock() - foundAt > 5 then
		found = {}
		foundAt = os.clock()
	end
	local hit = found[name]
	if hit then
		return hit
	end
	local id = ""
	for _, where in { SoundService, Workspace } do
		local ok, s = pcall(function()
			return where:FindFirstChild(name, true)
		end)
		if ok and s and s:IsA("Sound") and s.SoundId ~= "" then
			id = s.SoundId
			break
		end
	end
	found[name] = id
	return id
end

local function sheetId(): string
	local id = (Config.data.Assets :: any).SoundSheet
	if type(id) == "string" and id ~= "" then
		return id
	end
	return findUploaded("maison-sounds")
end

-- The sheet's cue for a name ("chime:harp" is the cue "chime_harp").
local function cueName(name: string): string
	return (string.gsub(name, ":", "_"))
end

type Source = { id: string, region: { number }?, soften: boolean, pitch: number, volume: number }

local function source(name: string): Source?
	local own = idFor(name)
	if own ~= "" then
		return { id = own, region = nil, soften = false, pitch = 1, volume = 1 }
	end
	local sheet = sheetId()
	local takes = SoundSheet.cues[cueName(name)]
	if sheet ~= "" and takes and #takes > 0 then
		local n = #takes
		local pick = math.random(1, n)
		if n > 1 and pick == lastTake[name] then
			pick = pick % n + 1
		end
		lastTake[name] = pick
		return { id = sheet, region = takes[pick], soften = false, pitch = 1, volume = 1 }
	end
	local library = (Config.data.Assets :: any).LibrarySounds
	local lib = if type(library) == "table" then library[name] else nil
	if type(lib) == "table" and #lib > 0 then
		local n = #lib
		local pick = math.random(1, n)
		if n > 1 and pick == lastTake[name] then
			pick = pick % n + 1
		end
		lastTake[name] = pick
		local t = lib[pick]
		if type(t) == "table" and type(t.id) == "string" and t.id ~= "" then
			return { id = t.id, region = nil, soften = false, pitch = tonumber(t.pitch) or 1, volume = tonumber(t.volume) or 1 }
		end
	end
	local fallback = BUILT_IN[name]
	if fallback then
		return { id = fallback.id, region = nil, soften = true, pitch = fallback.pitch, volume = fallback.volume }
	end
	return nil
end

-- Whether a sound has anything to play (the Boutique only sells a chime that does).
function Sound.has(name: string): boolean
	return idFor(name) ~= "" or (sheetId() ~= "" and SoundSheet.cues[cueName(name)] ~= nil)
end

-- The chime a guest wears from the Boutique (set by Main from the Closet), or nil.
Sound.wornChime = function(): string?
	return nil
end

-- One pool of sounds per name, so nothing is created per play.
local function take(name: string, id: string): Sound
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
		local oldest = list[1]
		oldest.SoundId = id
		return oldest
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.SoundGroup = effects
	s.Parent = SoundService
	table.insert(list, s)
	return s
end

-- Roblox's built-in stand-ins are bright and electronic: a low shelf takes the edge off them.
local function soften(s: Sound, on: boolean)
	local eq = s:FindFirstChild("Soften")
	if on and not eq then
		local e = Instance.new("EqualizerSoundEffect")
		e.Name = "Soften"
		e.HighGain = -12
		e.MidGain = -3
		e.LowGain = 2
		e.Parent = s
	elseif eq and eq:IsA("EqualizerSoundEffect") then
		eq.Enabled = on
	end
end

function Sound.play(name: string, volume: number?, pitch: number?)
	local src = source(name)
	if not src then
		return
	end
	local s = take(name, src.id)
	local drift = DRIFT[name] or DEFAULT_DRIFT
	s.Volume = (volume or 0.6) * src.volume * (1 + (math.random() * 2 - 1) * drift.volume)
	s.PlaybackSpeed = (pitch or 1) * src.pitch * (1 + (math.random() * 2 - 1) * drift.pitch)
	local region = src.region
	if region then
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[2])
		s.TimePosition = region[1]
	else
		s.PlaybackRegionsEnabled = false
		s.TimePosition = 0
	end
	soften(s, src.soften)
	s:Play()
end

-- Loads the sheet (or, until it's set, the library's recordings) as the guest arrives, so the
-- first pickup plays at once.
function Sound.preload()
	local id = sheetId()
	local ids: { string } = {}
	if id ~= "" then
		table.insert(ids, id)
	else
		local library = (Config.data.Assets :: any).LibrarySounds
		if type(library) == "table" then
			for _, takes in library do
				for _, t in takes do
					if type(t) == "table" and type(t.id) == "string" and t.id ~= "" and not table.find(ids, t.id) then
						table.insert(ids, t.id)
					end
				end
			end
		end
	end
	if #ids == 0 then
		return
	end
	local sounds = {}
	for i, sid in ids do
		table.insert(sounds, take("preload" .. i, sid))
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
	end)
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
	if worn and Sound.has("chime:" .. worn) then
		Sound.play("chime:" .. worn, voice.volume, 2 ^ (semis / 12))
		return
	end
	Sound.play("chime", voice.volume, voice.base * 2 ^ (semis / 12))
end

-- Rare pieces add a bright three-note shimmer on top.
function Sound.shimmer()
	if Sound.has("shimmer") then
		Sound.play("shimmer", 0.35)
		return
	end
	local voice = CHIMES[State.get("chime")] or CHIMES.Bells
	for i, semis in { 24, 28, 31 } do
		task.delay((i - 1) * 0.07, function()
			Sound.play("chime", voice.volume * 0.5, voice.base * 2 ^ (semis / 12))
		end)
	end
end

function Sound.wrong()
	Sound.play("wrong", 0.45)
end

function Sound.ui()
	Sound.play("click", 0.3)
end

function Sound.hover()
	Sound.play("tick", 0.1)
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
	suite = Enum.ReverbType.LivingRoom,
	none = Enum.ReverbType.Room,
}

-- Music per space, crossfading as you move. The Foyer's music comes from the piano itself, so it
-- carries, muffled, into the street and up the stair. A room's music fills out as the run builds;
-- the Ballroom band thins as lamps go out. Each space plays a playlist (Config.Assets.Playlists)
-- or a single track set for it.
type Song = { id: string, gain: number }
type Deck = { songs: { Song }, at: number, name: string }

local mix = { zone = "", intensity = nil :: number?, lit = nil :: number?, soiree = false }
local loops: { [string]: Sound? } = {}
local decks: { [string]: Deck } = {}
local targets: { [string]: number } = {}

local function one(id: string): { Song }
	return if id == "" then {} else { { id = id, gain = 1 } }
end

local function deckName(songs: { Song }): string
	local ids = {}
	for _, song in songs do
		table.insert(ids, song.id)
	end
	return table.concat(ids, ",")
end

local function gainOf(key: string): number
	local d = decks[key]
	return if d then d.songs[d.at].gain else 1
end

-- The next song in a playlist, after a breath of quiet.
local function advance(key: string)
	local s, d = loops[key], decks[key]
	if not s or not d or #d.songs < 2 then
		return
	end
	d.at = d.at % #d.songs + 1
	s.SoundId = d.songs[d.at].id
	s.TimePosition = 0
	s.Volume = (targets[key] or 0) * gainOf(key)
	task.delay(Config.data.Music.gap, function()
		if loops[key] == s and (targets[key] or 0) > 0 and not s.IsPlaying then
			s:Play()
		end
	end)
end

local function loop(key: string, songs: { Song }, into: SoundGroup, parent: Instance?): Sound?
	if #songs == 0 then
		return nil
	end
	local name = deckName(songs)
	local s = loops[key]
	if s and (decks[key] == nil or decks[key].name ~= name) then
		s:Destroy()
		loops[key] = nil
		decks[key] = nil
		s = nil
	end
	if not s then
		-- Every guest starts somewhere different in the list.
		local deck = { songs = songs, at = math.random(1, #songs), name = name }
		local ns = Instance.new("Sound")
		ns.Name = key
		ns.SoundId = songs[deck.at].id
		ns.Looped = #songs == 1
		ns.Volume = 0
		ns.SoundGroup = into
		ns.Parent = parent or SoundService
		ns.Ended:Connect(function()
			advance(key)
		end)
		loops[key] = ns
		decks[key] = deck
		s = ns
	end
	return s
end

local function asset(tree: string, key: string): string
	local t = (Config.data.Assets :: any)[tree]
	local id = if type(t) == "table" then t[key] else nil
	return if type(id) == "string" then id else ""
end

-- The house track a space plays when it has no music of its own. The street, the Club and the
-- Boutique hear the Foyer's piano instead.
local TRACK_FOR: { [string]: string } = {
	foyer = "lounge",
	vault = "lounge",
	suite = "lounge",
	terrace = "lounge",
	salon = "table",
	velvet = "table",
	obsidian = "table",
	midnight = "table",
	library = "table",
	ballroom = "ballroom",
}

local function playlist(track: string): { Song }
	local list = (Config.data.Assets :: any).Playlists
	local songs = if type(list) == "table" then list[track] else nil
	local out: { Song } = {}
	if type(songs) == "table" then
		for _, song in songs do
			if type(song) == "table" and type(song.id) == "string" and song.id ~= "" then
				table.insert(out, { id = song.id, gain = tonumber(song.gain) or 1 })
			end
		end
	end
	return out
end

-- In order: the space's own track, a track set for its kind, the playlist, and last a track
-- dropped into SoundService by name.
local function musicFor(zone: string): { Song }
	local own = asset("Music", zone)
	if own ~= "" then
		return one(own)
	end
	local track = TRACK_FOR[zone]
	if not track then
		return {}
	end
	local set = asset("Tracks", track)
	if set ~= "" then
		return one(set)
	end
	local songs = playlist(track)
	if #songs > 0 then
		return songs
	end
	return one(findUploaded("maison-" .. track))
end

-- Whether the house has any music to play (for telling the owner, in Studio, when it hasn't).
function Sound.hasMusic(): boolean
	for _, track in { "lounge", "table", "ballroom" } do
		if asset("Tracks", track) ~= "" or #playlist(track) > 0 or findUploaded("maison-" .. track) ~= "" then
			return true
		end
	end
	for _, id in (Config.data.Assets :: any).Music do
		if type(id) == "string" and id ~= "" then
			return true
		end
	end
	return false
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
	-- Each song in a playlist carries its own gain, so they all sit at one level.
	local t = TweenService:Create(s, TweenInfo.new(Config.data.Music.crossfade), { Volume = volume * gainOf(key) })
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
	local function want(key: string, songs: { Song }, volume: number, into: SoundGroup, parent: Instance?)
		local s = loop(key, songs, into, parent)
		if s then
			wanted[key] = volume
		end
	end

	-- The Foyer: the piano, heard in the room and, muffled, from the spaces around it.
	local part = pianoPart()
	local foyerSongs = musicFor("foyer")
	if part and #foyerSongs > 0 then
		local s = loop("Piano", foyerSongs, music, part)
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
		want("Music_foyer", foyerSongs, level, music)
	end

	-- Every other space: its own track, filling out as the run builds.
	local intensity = mix.intensity
	if zone ~= "foyer" and zone ~= "ballroom" then
		local layer = asset("MusicLayers", zone)
		local base = if intensity and layer == "" then 0.7 + 0.3 * intensity else 1
		want("Music_" .. zone, musicFor(zone), level * base, music)
		if intensity and layer ~= "" then
			want("Layer_" .. zone, one(layer), level * intensity, music)
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
				want("Band_" .. stem, one(asset("Band", stem)), level * share, music)
			end
		else
			local lit = mix.lit or Config.data.Ballroom.tables
			want("Music_ballroom", musicFor("ballroom"), level * (0.55 + 0.45 * math.clamp(lit / Config.data.Ballroom.tables, 0, 1)), music)
		end
	end

	-- Ambience: the space's own, and the season's layer beneath it.
	want("Ambience_" .. zone, one(asset("Ambience", zone)), 0.5, ambience)
	local season = tostring(Workspace:GetAttribute("Season") or "")
	want("Season_" .. season, one(asset("SeasonAmbience", season)), 0.3, ambience)

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
					decks["Music_foyer"] = nil
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
