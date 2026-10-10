--!strict
-- Admin Abuse's nights: no two the same.
--
-- Every Admin Abuse (and Mega Abuse) is one of the house's nights, each its own show: how it opens
-- (a transmission, a countdown, a vault door, a hyperspace jump, a hijacked signal...), how its
-- title lands, its colours, the realm the house goes to, which surprises come and in what order,
-- whether two land at once, how fast they come, its music, its physical twist (giants, tiny guests,
-- moon gravity), its treasure hunts and how it ends. On top of that, every effect has its own
-- looks (ice comets or golden meteors, a crimson vortex or a white hole, pink invaders or a golden
-- saucer), chosen each time it comes.
--
-- One number decides all of it: the night's seed. The server that starts it picks the seed (the
-- Owner Remote's commands get theirs from the command's own id), sends it to every server with the
-- command and writes it down with the night, and every server and every screen works the same
-- night out of it with the same arithmetic. So whatever night it is, it's the same night, in the
-- same order, at the same moments, in every server of the game.

local AbuseNights = {}

local rgb = Color3.fromRGB

---------------------------------------------------------------------------------------------------
-- The same numbers from the same seed, everywhere (Park and Miller's generator: whole numbers
-- only, exact in Luau's numbers, so every server and every screen gets the very same sequence).
---------------------------------------------------------------------------------------------------
local MOD = 2147483647
local SEED_MAX = 16000000 -- (seeds stay below 2^24: exact even where a number is kept as a float)

export type Rng = { state: number }

function AbuseNights.rng(seed: number): Rng
	local s = math.floor(math.abs(seed)) % MOD
	if s == 0 then
		s = 1
	end
	local r = { state = s }
	for _ = 1, 4 do
		r.state = (r.state * 48271) % MOD
	end
	return r
end

-- A number from 0 up to (not including) 1.
function AbuseNights.next(r: Rng): number
	r.state = (r.state * 48271) % MOD
	return (r.state - 1) / (MOD - 1)
end

-- A whole number from a to b.
function AbuseNights.int(r: Rng, a: number, b: number): number
	return math.min(b, a + math.floor(AbuseNights.next(r) * (b - a + 1)))
end

function AbuseNights.pick<T>(r: Rng, list: { T }): T
	return list[AbuseNights.int(r, 1, #list)]
end

-- A shuffled copy.
function AbuseNights.shuffle<T>(r: Rng, list: { T }): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = AbuseNights.int(r, 1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- A seed from any text (an Owner Remote command's id): the same text, the same seed, everywhere.
function AbuseNights.seedOf(text: string): number
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % MOD
	end
	return 1 + h % SEED_MAX
end

-- A fresh seed (the server starting a night picks it).
function AbuseNights.newSeed(): number
	return math.random(1, SEED_MAX)
end

-- A seed as the server will take it from a message (nil if it isn't one).
function AbuseNights.cleanSeed(v: any): number?
	if type(v) == "number" and v == v and v >= 1 and v <= SEED_MAX then
		return math.floor(v)
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- The palettes (the night's colours: its title, its shockwaves, its confetti, its cards).
---------------------------------------------------------------------------------------------------
export type Palette = { main: Color3, light: Color3, deep: Color3, accent: Color3, rainbow: boolean? }

AbuseNights.Palettes = {
	gold = { main = rgb(255, 204, 110), light = rgb(255, 240, 196), deep = rgb(196, 136, 40), accent = rgb(255, 255, 255) },
	neon = { main = rgb(80, 255, 240), light = rgb(210, 255, 252), deep = rgb(255, 60, 220), accent = rgb(255, 240, 80) },
	inferno = { main = rgb(255, 128, 44), light = rgb(255, 226, 160), deep = rgb(210, 36, 24), accent = rgb(255, 238, 120) },
	ice = { main = rgb(150, 222, 255), light = rgb(238, 250, 255), deep = rgb(60, 120, 225), accent = rgb(255, 255, 255) },
	royal = { main = rgb(196, 128, 255), light = rgb(240, 220, 255), deep = rgb(112, 44, 205), accent = rgb(255, 214, 90) },
	toxic = { main = rgb(150, 255, 90), light = rgb(228, 255, 205), deep = rgb(36, 165, 60), accent = rgb(255, 255, 120) },
	candy = { main = rgb(255, 128, 210), light = rgb(255, 224, 242), deep = rgb(110, 196, 255), accent = rgb(255, 245, 150) },
	ocean = { main = rgb(70, 205, 255), light = rgb(205, 244, 255), deep = rgb(20, 92, 175), accent = rgb(120, 255, 222) },
	sunset = { main = rgb(255, 146, 92), light = rgb(255, 224, 184), deep = rgb(205, 58, 145), accent = rgb(255, 214, 92) },
	noir = { main = rgb(244, 244, 244), light = rgb(255, 255, 255), deep = rgb(96, 96, 108), accent = rgb(255, 62, 84) },
	rainbow = { main = rgb(255, 214, 80), light = rgb(255, 255, 255), deep = rgb(190, 90, 255), accent = rgb(80, 255, 200), rainbow = true },
	emerald = { main = rgb(84, 232, 152), light = rgb(212, 255, 232), deep = rgb(20, 132, 84), accent = rgb(255, 214, 110) },
	crimson = { main = rgb(255, 72, 92), light = rgb(255, 205, 210), deep = rgb(150, 20, 44), accent = rgb(255, 214, 110) },
	cosmic = { main = rgb(166, 146, 255), light = rgb(228, 222, 255), deep = rgb(62, 40, 175), accent = rgb(120, 222, 255) },
} :: { [string]: Palette }

---------------------------------------------------------------------------------------------------
-- The ways a night can open, its title can land, and it can end (World/AbuseShow draws them).
---------------------------------------------------------------------------------------------------
AbuseNights.Openings = {
	"transmission", -- AJKR's crest in a ring of gold, LIVE, an incoming transmission, the glitch
	"countdown", -- 3, 2, 1 slammed onto the screen, each bigger, each its own colour
	"blackout", -- the lights go out; one spotlight hunts the dark, finds the middle
	"skyCrack", -- the screen cracks, wider and wider, and shatters outwards
	"vault", -- a vault door: the wheel spins, the bolts slide, gold light floods out
	"warp", -- hyperspace: stars streak past faster and faster, then a white flash
	"hijack", -- static, a hijacked signal, error windows popping up everywhere
	"curtain", -- velvet curtains, a drumroll, a spotlight, the curtains part
	"breaking", -- BREAKING NEWS: the bars, the ticker, the anchor's line
	"terminal", -- a hacker's terminal: the command types itself, ACCESS GRANTED
	"portal", -- a portal opens in the middle of the screen, swirling, pulling everything in
	"pulse", -- the bass hits, the screen pumps with it, faster and faster, colours strobing
}
AbuseNights.TitleStyles = {
	"slam", -- huge, slammed down, ghosts closing in
	"drop", -- falls from the top and bounces
	"stamp", -- letter by letter, each stamped
	"zoom", -- from a dot, spinning, to full size
	"split", -- two halves sliding in from either side, locking together
	"flicker", -- a neon sign buzzing to life
}
AbuseNights.Finales = {
	"fireworks", -- the house's fireworks, the haul
	"goldShower", -- gold raining down the screen, coins, the haul
	"credits", -- a film's closing credits, starring: you
	"supernova", -- a flash of white light, rings racing out
	"confettiStorm", -- confetti from every side
	"curtainCall", -- the curtains close, THANK YOU, a bow
}

---------------------------------------------------------------------------------------------------
-- The physical twists and the hunts a night brings (on top of its boosts, which every night has:
-- double Gilt, Mythic luck, double XP, the Page-Turner and curios twice as often).
---------------------------------------------------------------------------------------------------
AbuseNights.Boosts = { "goldenHour", "luckyHour", "doubleXP", "pageTurner", "curioHour", "disco", "discoHouse" }
AbuseNights.Bodies = {
	classic = { "giants", "quickstep", "featherlight" },
	giants = { "giants", "quickstep" },
	tiny = { "tiny", "featherlight" },
	moon = { "featherlight" },
	speed = { "quickstep" },
	free = {},
} :: { [string]: { string } }
AbuseNights.Hunts = {
	all = { "goldRain", "treasure", "parade" },
	gold = { "goldRain" },
	keys = { "treasure" },
	memes = { "parade" },
	goldKeys = { "goldRain", "treasure" },
} :: { [string]: { string } }

---------------------------------------------------------------------------------------------------
-- The nights
---------------------------------------------------------------------------------------------------
export type Night = {
	id: string,
	name: string,
	glyph: string,
	line: string,
	opening: { string },
	title: { string },
	palette: string,
	realm: string,
	pool: { string },
	pace: string, -- "calm" | "normal" | "wild"
	combo: number, -- how likely a surprise brings a second at once
	music: string,
	finale: string,
	body: string,
	hunts: string,
	gifts: number?, -- the owner's gifts this much more often (1: as usual)
	giant: boolean?, -- AJKR's giant stands over the house (a few nights only)
}

AbuseNights.List = {
	{ id = "classic", name = "THE CLASSIC", glyph = "👑", line = "The original. Everything you came for.", opening = { "transmission", "countdown" }, title = { "slam" }, palette = "gold", realm = "gilded", pool = { "confetti", "meteor", "fireworks", "dance", "goldWave", "storm", "titan", "galaxy" }, pace = "normal", combo = 0.1, music = "abuse", finale = "fireworks", body = "classic", hunts = "all" },
	{ id = "midasHeist", name = "THE MIDAS HEIST", glyph = "🪙", line = "AJKR cracked the vault. Everything is gold.", opening = { "vault" }, title = { "stamp", "slam" }, palette = "gold", realm = "midas", pool = { "goldWave", "confetti", "fireworks", "shockwave", "blackout", "rainbow" }, pace = "normal", combo = 0.15, music = "gold", finale = "goldShower", body = "speed", hunts = "goldKeys", gifts = 1.3 },
	{ id = "cosmicTakeover", name = "COSMIC TAKEOVER", glyph = "🪐", line = "The house has left the planet.", opening = { "warp", "portal" }, title = { "zoom" }, palette = "cosmic", realm = "cosmos", pool = { "galaxy", "aurora", "blackHole", "ufo", "meteor", "zeroG" }, pace = "normal", combo = 0.2, music = "cosmic", finale = "supernova", body = "moon", hunts = "keys" },
	{ id = "brainrotApocalypse", name = "BRAINROT APOCALYPSE", glyph = "🗿", line = "The memes have escaped. Nobody is safe.", opening = { "hijack" }, title = { "split", "slam" }, palette = "toxic", realm = "neon", pool = { "memeRain", "titan", "spin", "dance", "confetti", "rainbow" }, pace = "wild", combo = 0.3, music = "party", finale = "confettiStorm", body = "classic", hunts = "memes" },
	{ id = "hotDisco", name = "HOT HOT DISCO", glyph = "🪩", line = "The dance floor is on fire. Keep dancing.", opening = { "pulse" }, title = { "flicker", "drop" }, palette = "inferno", realm = "inferno", pool = { "dance", "fireIce", "fireworks", "confetti", "rainbow", "blackout" }, pace = "normal", combo = 0.2, music = "party", finale = "fireworks", body = "speed", hunts = "all" },
	{ id = "frostbiteFrenzy", name = "FROSTBITE FRENZY", glyph = "❄️", line = "Winter came early. And it brought friends.", opening = { "skyCrack", "warp" }, title = { "drop" }, palette = "ice", realm = "frost", pool = { "blizzard", "aurora", "fireIce", "zeroG", "bubbles", "fireworks" }, pace = "calm", combo = 0.15, music = "winter", finale = "supernova", body = "moon", hunts = "keys" },
	{ id = "candyChaos", name = "CANDY CHAOS", glyph = "🍭", line = "Too much sugar. Way too much.", opening = { "curtain", "pulse" }, title = { "drop", "zoom" }, palette = "candy", realm = "candy", pool = { "bubbles", "confetti", "rainbow", "dance", "spin", "memeRain" }, pace = "wild", combo = 0.25, music = "party", finale = "confettiStorm", body = "tiny", hunts = "all" },
	{ id = "neonOverdrive", name = "NEON OVERDRIVE", glyph = "🌃", line = "Every light in the house turned up to eleven.", opening = { "terminal", "pulse" }, title = { "flicker" }, palette = "neon", realm = "neon", pool = { "rainbow", "dance", "blackout", "ufo", "storm", "spin" }, pace = "wild", combo = 0.2, music = "mega", finale = "fireworks", body = "speed", hunts = "all" },
	{ id = "deepDive", name = "THE DEEP DIVE", glyph = "🐙", line = "The house sank. The party didn't.", opening = { "portal" }, title = { "zoom", "drop" }, palette = "ocean", realm = "abyss", pool = { "bubbles", "tornado", "zeroG", "aurora", "storm", "goldWave" }, pace = "calm", combo = 0.15, music = "cosmic", finale = "supernova", body = "moon", hunts = "goldKeys" },
	{ id = "thunderPalace", name = "THUNDER PALACE", glyph = "⛈️", line = "Two storms walk into a house.", opening = { "breaking", "skyCrack" }, title = { "slam" }, palette = "royal", realm = "thunder", pool = { "storm", "earthquake", "shockwave", "meteor", "blackout", "tornado" }, pace = "normal", combo = 0.25, music = "epic", finale = "fireworks", body = "giants", hunts = "keys" },
	{ id = "meteorMadness", name = "METEOR MADNESS", glyph = "☄️", line = "Look up. No, really, look up.", opening = { "skyCrack" }, title = { "slam", "drop" }, palette = "inferno", realm = "inferno", pool = { "meteor", "earthquake", "shockwave", "fireworks", "meteor", "storm" }, pace = "normal", combo = 0.2, music = "epic", finale = "supernova", body = "classic", hunts = "gold" },
	{ id = "singularity", name = "THE SINGULARITY", glyph = "🕳️", line = "Gravity is optional tonight.", opening = { "portal", "warp" }, title = { "zoom" }, palette = "cosmic", realm = "cosmos", pool = { "blackHole", "galaxy", "zeroG", "meteor", "aurora" }, pace = "calm", combo = 0.2, music = "epic", finale = "supernova", body = "moon", hunts = "keys" },
	{ id = "alienInvasion", name = "ALIEN INVASION", glyph = "🛸", line = "They came in peace. Mostly.", opening = { "hijack", "breaking" }, title = { "flicker", "split" }, palette = "toxic", realm = "matrix", pool = { "ufo", "galaxy", "zeroG", "blackout", "ufo", "memeRain" }, pace = "normal", combo = 0.2, music = "scifi", finale = "supernova", body = "tiny", hunts = "memes" },
	{ id = "royalBall", name = "THE ROYAL BALL", glyph = "👗", line = "Dress code: fabulous. Gravity: optional.", opening = { "curtain" }, title = { "stamp" }, palette = "royal", realm = "gilded", pool = { "dance", "fireworks", "confetti", "aurora", "goldWave", "bubbles" }, pace = "calm", combo = 0.1, music = "party", finale = "curtainCall", body = "free", hunts = "keys" },
	{ id = "aboveTheClouds", name = "ABOVE THE CLOUDS", glyph = "☁️", line = "The house is floating above the clouds.", opening = { "warp", "curtain" }, title = { "zoom", "drop" }, palette = "ice", realm = "heaven", pool = { "aurora", "bubbles", "zeroG", "confetti", "goldWave", "fireworks" }, pace = "calm", combo = 0.15, music = "hero", finale = "goldShower", body = "moon", hunts = "goldKeys" },
	{ id = "jungleRumble", name = "JUNGLE RUMBLE", glyph = "🌿", line = "Vines in the ballroom. Something is drumming.", opening = { "pulse", "breaking" }, title = { "drop", "slam" }, palette = "emerald", realm = "jungle", pool = { "tornado", "storm", "bubbles", "memeRain", "earthquake", "dance" }, pace = "normal", combo = 0.2, music = "epic", finale = "confettiStorm", body = "giants", hunts = "all" },
	{ id = "pharaohsGold", name = "THE PHARAOH'S GOLD", glyph = "🏺", line = "The sands have shifted. The gold is real.", opening = { "vault", "portal" }, title = { "stamp" }, palette = "sunset", realm = "desert", pool = { "goldWave", "tornado", "meteor", "fireworks", "shockwave" }, pace = "normal", combo = 0.15, music = "epic", finale = "goldShower", body = "speed", hunts = "gold", gifts = 1.2 },
	{ id = "cherryBlossom", name = "CHERRY BLOSSOM NIGHT", glyph = "🌸", line = "Soft, pink, and a little bit magical.", opening = { "curtain", "warp" }, title = { "zoom" }, palette = "candy", realm = "sakura", pool = { "blizzard", "bubbles", "aurora", "fireworks", "zeroG", "confetti" }, pace = "calm", combo = 0.1, music = "cosmic", finale = "goldShower", body = "moon", hunts = "keys" },
	{ id = "retrowave", name = "RETROWAVE '86", glyph = "🌆", line = "Pink sun. Chrome everything. Maximum volume.", opening = { "warp", "terminal" }, title = { "flicker", "split" }, palette = "sunset", realm = "synthwave", pool = { "rainbow", "blackout", "dance", "ufo", "galaxy", "spin" }, pace = "normal", combo = 0.2, music = "mega", finale = "credits", body = "speed", hunts = "all" },
	{ id = "theGlitch", name = "THE GLITCH", glyph = "💾", line = "Something is wrong with the house. Everything is wrong. It's great.", opening = { "terminal", "hijack" }, title = { "split", "flicker" }, palette = "toxic", realm = "matrix", pool = { "blackout", "spin", "memeRain", "zeroG", "rainbow", "titan" }, pace = "wild", combo = 0.3, music = "scifi", finale = "credits", body = "tiny", hunts = "memes" },
	{ id = "rocketNight", name = "ROCKET NIGHT", glyph = "🚀", line = "3, 2, 1... everybody up.", opening = { "countdown" }, title = { "zoom", "slam" }, palette = "sunset", realm = "gilded", pool = { "launch", "fireworks", "shockwave", "zeroG", "meteor", "launch" }, pace = "normal", combo = 0.15, music = "hero", finale = "fireworks", body = "moon", hunts = "keys" },
	{ id = "zeroGravityGala", name = "ZERO GRAVITY GALA", glyph = "🌙", line = "A black-tie dinner. In orbit.", opening = { "warp" }, title = { "zoom" }, palette = "cosmic", realm = "cosmos", pool = { "zeroG", "galaxy", "bubbles", "aurora", "ufo", "zeroG" }, pace = "calm", combo = 0.15, music = "cosmic", finale = "supernova", body = "moon", hunts = "keys" },
	{ id = "confettiCannonade", name = "THE CONFETTI CANNONADE", glyph = "🎉", line = "We bought too much confetti. All of it goes tonight.", opening = { "countdown", "curtain" }, title = { "drop" }, palette = "rainbow", realm = "candy", pool = { "confetti", "fireworks", "dance", "rainbow", "bubbles", "confetti" }, pace = "wild", combo = 0.2, music = "party", finale = "confettiStorm", body = "classic", hunts = "all" },
	{ id = "titanShowdown", name = "TITAN SHOWDOWN", glyph = "🗿", line = "Two giant memes. One house. Pick a side.", opening = { "breaking" }, title = { "slam", "split" }, palette = "crimson", realm = "thunder", pool = { "titan", "earthquake", "shockwave", "meteor", "storm", "titan" }, pace = "normal", combo = 0.2, music = "epic", finale = "fireworks", body = "giants", hunts = "memes" },
	{ id = "lightsOutParty", name = "LIGHTS OUT PARTY", glyph = "🔦", line = "Who turned the lights off? (We did.)", opening = { "blackout" }, title = { "flicker" }, palette = "noir", realm = "neon", pool = { "blackout", "dance", "rainbow", "fireworks", "ufo", "storm" }, pace = "normal", combo = 0.2, music = "party", finale = "fireworks", body = "speed", hunts = "keys" },
	{ id = "midnightAgent", name = "MIDNIGHT AGENT", glyph = "🕶️", line = "Your mission tonight: total chaos.", opening = { "blackout", "terminal" }, title = { "stamp" }, palette = "noir", realm = "gilded", pool = { "blackout", "shockwave", "spin", "goldWave", "fireworks", "titan" }, pace = "normal", combo = 0.15, music = "spy", finale = "credits", body = "speed", hunts = "keys" },
	{ id = "tornadoAlley", name = "TORNADO ALLEY", glyph = "🌪️", line = "Hold on to something. Anything.", opening = { "skyCrack", "breaking" }, title = { "drop" }, palette = "sunset", realm = "desert", pool = { "tornado", "storm", "earthquake", "memeRain", "tornado", "goldWave" }, pace = "normal", combo = 0.2, music = "epic", finale = "confettiStorm", body = "giants", hunts = "gold" },
	{ id = "goldRushHour", name = "GOLD RUSH HOUR", glyph = "💰", line = "Gold in the hallways. Gold on the stairs. Grab it.", opening = { "countdown", "vault" }, title = { "slam" }, palette = "gold", realm = "midas", pool = { "goldWave", "confetti", "fireworks", "shockwave", "goldWave" }, pace = "wild", combo = 0.2, music = "gold", finale = "goldShower", body = "speed", hunts = "gold", gifts = 1.5 },
	{ id = "fireAndIce", name = "FIRE & ICE", glyph = "🔥", line = "Half the house is burning. The other half is frozen.", opening = { "skyCrack", "portal" }, title = { "split" }, palette = "inferno", realm = "frost", pool = { "fireIce", "blizzard", "meteor", "aurora", "fireIce" }, pace = "normal", combo = 0.25, music = "epic", finale = "supernova", body = "classic", hunts = "keys" },
	{ id = "bubbleMania", name = "BUBBLE MANIA", glyph = "🫧", line = "Pop them all. There are millions.", opening = { "portal", "curtain" }, title = { "drop", "zoom" }, palette = "ocean", realm = "abyss", pool = { "bubbles", "zeroG", "rainbow", "confetti", "bubbles" }, pace = "calm", combo = 0.15, music = "party", finale = "confettiStorm", body = "tiny", hunts = "all" },
	{ id = "rainbowRiot", name = "RAINBOW RIOT", glyph = "🌈", line = "Every colour. All at once. On purpose.", opening = { "pulse" }, title = { "zoom", "flicker" }, palette = "rainbow", realm = "candy", pool = { "rainbow", "confetti", "bubbles", "dance", "aurora", "rainbow" }, pace = "wild", combo = 0.25, music = "party", finale = "confettiStorm", body = "classic", hunts = "all" },
	{ id = "memeLords", name = "RISE OF THE MEME LORDS", glyph = "🤡", line = "The memes have taken over the house. They seem nice.", opening = { "hijack", "breaking" }, title = { "split" }, palette = "toxic", realm = "neon", pool = { "titan", "memeRain", "spin", "dance", "memeRain" }, pace = "wild", combo = 0.3, music = "party", finale = "credits", body = "giants", hunts = "memes" },
	{ id = "supernova", name = "SUPERNOVA", glyph = "💥", line = "A star is about to go off. Front row seats.", opening = { "warp" }, title = { "zoom", "slam" }, palette = "cosmic", realm = "cosmos", pool = { "galaxy", "blackHole", "meteor", "aurora", "fireworks" }, pace = "normal", combo = 0.2, music = "epic", finale = "supernova", body = "moon", hunts = "keys" },
	{ id = "endOfTheWorld", name = "END OF THE WORLD PARTY", glyph = "🌋", line = "If it's the end, we're ending it dancing.", opening = { "breaking", "skyCrack" }, title = { "slam" }, palette = "crimson", realm = "inferno", pool = { "meteor", "earthquake", "storm", "blackHole", "tornado", "fireworks" }, pace = "wild", combo = 0.3, music = "epic", finale = "fireworks", body = "classic", hunts = "all" },
	{ id = "galaxyBrain", name = "GALAXY BRAIN", glyph = "🧠", line = "Big thoughts. Bigger effects.", opening = { "portal", "terminal" }, title = { "zoom" }, palette = "neon", realm = "cosmos", pool = { "galaxy", "titan", "ufo", "memeRain", "zeroG" }, pace = "normal", combo = 0.2, music = "scifi", finale = "supernova", body = "tiny", hunts = "memes" },
	{ id = "wizardsTower", name = "THE WIZARD'S TOWER", glyph = "🧙", line = "Somebody read the spellbook out loud.", opening = { "portal", "curtain" }, title = { "stamp", "zoom" }, palette = "royal", realm = "heaven", pool = { "aurora", "storm", "zeroG", "bubbles", "galaxy", "shockwave" }, pace = "calm", combo = 0.2, music = "hero", finale = "supernova", body = "moon", hunts = "keys" },
	{ id = "kingOfTheHouse", name = "KING OF THE HOUSE", glyph = "👑", line = "AJKR, standing over the house. Bow.", opening = { "curtain", "transmission" }, title = { "slam" }, palette = "gold", realm = "gilded", pool = { "goldWave", "fireworks", "confetti", "shockwave", "titan" }, pace = "normal", combo = 0.15, music = "hero", finale = "curtainCall", body = "giants", hunts = "all", giant = true },
	{ id = "ajkrsArmy", name = "AJKR'S ARMY", glyph = "🕺", line = "One AJKR wasn't enough.", opening = { "breaking", "transmission" }, title = { "split" }, palette = "gold", realm = "gilded", pool = { "ownerArmy", "dance", "confetti", "fireworks", "ownerArmy" }, pace = "normal", combo = 0.15, music = "party", finale = "confettiStorm", body = "classic", hunts = "all", giant = true },
	{ id = "colossusRises", name = "THE COLOSSUS RISES", glyph = "🗽", line = "Something enormous is standing behind the house.", opening = { "skyCrack", "transmission" }, title = { "slam" }, palette = "gold", realm = "thunder", pool = { "earthquake", "shockwave", "titan", "meteor", "fireworks" }, pace = "normal", combo = 0.2, music = "hero", finale = "fireworks", body = "giants", hunts = "keys", giant = true },
	{ id = "arcadeMode", name = "ARCADE MODE", glyph = "🕹️", line = "Insert coin. Actually, it's free. Go.", opening = { "countdown", "terminal" }, title = { "flicker", "drop" }, palette = "neon", realm = "synthwave", pool = { "spin", "rainbow", "launch", "confetti", "zeroG", "memeRain" }, pace = "wild", combo = 0.25, music = "mega", finale = "credits", body = "tiny", hunts = "all" },
	{ id = "stormChasers", name = "STORM CHASERS", glyph = "🌩️", line = "Breaking: every weather, at once, indoors.", opening = { "breaking" }, title = { "drop" }, palette = "ocean", realm = "thunder", pool = { "storm", "tornado", "blizzard", "earthquake", "aurora" }, pace = "normal", combo = 0.25, music = "epic", finale = "fireworks", body = "giants", hunts = "keys" },
	{ id = "greenRoom", name = "THE GREEN ROOM", glyph = "🍀", line = "Backstage, everything is green and lucky.", opening = { "curtain" }, title = { "stamp" }, palette = "emerald", realm = "jungle", pool = { "aurora", "bubbles", "fireworks", "confetti", "dance" }, pace = "calm", combo = 0.1, music = "party", finale = "curtainCall", body = "free", hunts = "goldKeys", gifts = 1.2 },
	{ id = "vipLounge", name = "THE VIP LOUNGE", glyph = "🥂", line = "Velvet ropes, gold lights. Everybody's on the list.", opening = { "blackout", "vault" }, title = { "stamp", "flicker" }, palette = "gold", realm = "gilded", pool = { "dance", "fireworks", "goldWave", "blackout", "confetti" }, pace = "calm", combo = 0.1, music = "spy", finale = "curtainCall", body = "free", hunts = "goldKeys", gifts = 1.3 },
	{ id = "carnivalNight", name = "CARNIVAL NIGHT", glyph = "🎪", line = "Step right up! Everything spins!", opening = { "curtain", "countdown" }, title = { "drop", "zoom" }, palette = "rainbow", realm = "candy", pool = { "confetti", "dance", "fireworks", "bubbles", "spin", "launch" }, pace = "wild", combo = 0.2, music = "party", finale = "confettiStorm", body = "classic", hunts = "all" },
	{ id = "hyperdrive", name = "HYPERDRIVE", glyph = "🌠", line = "Punch it.", opening = { "warp" }, title = { "zoom", "split" }, palette = "ice", realm = "cosmos", pool = { "launch", "zeroG", "galaxy", "meteor", "ufo" }, pace = "wild", combo = 0.2, music = "scifi", finale = "supernova", body = "speed", hunts = "keys" },
	{ id = "volcanoNight", name = "VOLCANO NIGHT", glyph = "🌋", line = "The floor is lava. (It isn't. Keep sorting.)", opening = { "skyCrack", "pulse" }, title = { "slam" }, palette = "inferno", realm = "inferno", pool = { "earthquake", "meteor", "fireIce", "shockwave", "fireworks" }, pace = "normal", combo = 0.2, music = "epic", finale = "fireworks", body = "giants", hunts = "gold" },
	{ id = "snowGlobe", name = "THE SNOW GLOBE", glyph = "🔮", line = "Someone picked up the house and shook it.", opening = { "portal" }, title = { "drop" }, palette = "ice", realm = "frost", pool = { "blizzard", "bubbles", "aurora", "zeroG", "fireworks", "blizzard" }, pace = "calm", combo = 0.1, music = "winter", finale = "goldShower", body = "tiny", hunts = "keys" },
	{ id = "dreamland", name = "DREAMLAND", glyph = "💤", line = "You fell asleep at the table. This is the dream.", opening = { "warp", "portal" }, title = { "zoom" }, palette = "candy", realm = "heaven", pool = { "bubbles", "aurora", "zeroG", "galaxy", "confetti" }, pace = "calm", combo = 0.15, music = "cosmic", finale = "supernova", body = "moon", hunts = "goldKeys" },
	{ id = "finalBoss", name = "THE FINAL BOSS", glyph = "⚔️", line = "BOSS INCOMING. It's a meme. It's enormous.", opening = { "countdown", "breaking" }, title = { "slam" }, palette = "crimson", realm = "thunder", pool = { "titan", "shockwave", "earthquake", "meteor", "blackHole" }, pace = "normal", combo = 0.25, music = "epic", finale = "credits", body = "giants", hunts = "keys" },
	{ id = "theHack", name = "THE HACK", glyph = "💻", line = "AJKR typed one command. The house did the rest.", opening = { "terminal" }, title = { "flicker", "stamp" }, palette = "toxic", realm = "matrix", pool = { "blackout", "spin", "ufo", "memeRain", "rainbow" }, pace = "wild", combo = 0.25, music = "scifi", finale = "credits", body = "speed", hunts = "memes" },
	{ id = "goldenAge", name = "THE GOLDEN AGE", glyph = "🏛️", line = "The house at its most magnificent.", opening = { "curtain", "vault" }, title = { "stamp" }, palette = "gold", realm = "gilded", pool = { "goldWave", "aurora", "fireworks", "confetti", "bubbles" }, pace = "calm", combo = 0.1, music = "hero", finale = "goldShower", body = "free", hunts = "goldKeys", gifts = 1.2 },
	{ id = "chaosTheory", name = "CHAOS THEORY", glyph = "🎲", line = "No plan. No order. Everything.", opening = { "hijack", "pulse", "skyCrack" }, title = { "split", "slam", "zoom" }, palette = "rainbow", realm = "neon", pool = { "meteor", "blackHole", "ufo", "tornado", "memeRain", "titan", "rainbow", "galaxy", "storm", "spin", "launch", "fireIce" }, pace = "wild", combo = 0.4, music = "mega", finale = "confettiStorm", body = "classic", hunts = "all" },
	{ id = "masquerade", name = "MIDNIGHT MASQUERADE", glyph = "🎭", line = "Masks on. Lights low. Music loud.", opening = { "curtain", "blackout" }, title = { "stamp" }, palette = "royal", realm = "gilded", pool = { "dance", "blackout", "fireworks", "aurora", "confetti" }, pace = "calm", combo = 0.1, music = "spy", finale = "curtainCall", body = "free", hunts = "keys" },
	{ id = "palmBeach", name = "PALM BEACH NIGHTS", glyph = "🌴", line = "Pool party. In a mansion. At midnight.", opening = { "pulse", "warp" }, title = { "drop" }, palette = "sunset", realm = "synthwave", pool = { "bubbles", "dance", "fireworks", "confetti", "rainbow" }, pace = "normal", combo = 0.15, music = "party", finale = "fireworks", body = "speed", hunts = "all" },
	{ id = "wildWest", name = "WILD WEST SHOWDOWN", glyph = "🤠", line = "This house ain't big enough for all these effects.", opening = { "countdown", "breaking" }, title = { "stamp", "slam" }, palette = "sunset", realm = "desert", pool = { "tornado", "goldWave", "shockwave", "fireworks", "earthquake" }, pace = "normal", combo = 0.15, music = "hero", finale = "credits", body = "speed", hunts = "gold" },
} :: { Night }

AbuseNights.byId = {} :: { [string]: Night }
for _, n in AbuseNights.List do
	AbuseNights.byId[n.id] = n
end

---------------------------------------------------------------------------------------------------
-- Each effect's looks: chosen each time it comes (by the night, or by the owner's switch), so
-- the same effect can be ice comets one night and golden meteors the next. `banner`: the words
-- slammed onto the screen; `colour`: theirs; `colours`: the effect's own colours. Some carry more
-- (memes: what falls; titan: which meme; spin: how fast).
---------------------------------------------------------------------------------------------------
export type Variant = { banner: string, colour: Color3, colours: { Color3 }, [string]: any }

local RAINBOW = { rgb(255, 60, 140), rgb(80, 140, 255), rgb(90, 255, 170), rgb(255, 214, 80), rgb(190, 90, 255), rgb(255, 120, 40), rgb(60, 230, 255) }
local GOLDS = { rgb(255, 204, 110), rgb(255, 230, 160), rgb(246, 186, 70), rgb(255, 250, 220) }
local PASTEL = { rgb(255, 190, 220), rgb(190, 230, 255), rgb(200, 255, 220), rgb(255, 240, 180), rgb(225, 200, 255) }
local NEONS = { rgb(80, 255, 240), rgb(255, 60, 220), rgb(190, 255, 60), rgb(255, 240, 80), rgb(120, 120, 255) }
AbuseNights.RAINBOW = RAINBOW

AbuseNights.Variants = {
	launch = {
		{ banner = "LIFT OFF!", colour = rgb(255, 120, 60), colours = { rgb(255, 200, 120), rgb(255, 204, 110) } },
		{ banner = "ROCKET RAINBOW!", colour = rgb(255, 214, 80), colours = RAINBOW },
		{ banner = "BLAST OFF!", colour = rgb(90, 200, 255), colours = { rgb(140, 220, 255), rgb(60, 140, 255) } },
		{ banner = "TO THE MOON!", colour = rgb(230, 230, 255), colours = { rgb(255, 255, 255), rgb(200, 210, 255) } },
	},
	dance = {
		{ banner = "DANCE PARTY!", colour = rgb(255, 80, 200), colours = RAINBOW },
		{ banner = "DISCO FEVER!", colour = rgb(255, 120, 220), colours = { rgb(255, 90, 200), rgb(170, 80, 255), rgb(255, 214, 90) } },
		{ banner = "NEON RAVE!", colour = rgb(80, 255, 240), colours = NEONS },
		{ banner = "GOLDEN GROOVE!", colour = rgb(255, 204, 110), colours = GOLDS },
	},
	storm = {
		{ banner = "LIGHTNING STORM", colour = rgb(190, 215, 255), colours = { rgb(210, 225, 255) } },
		{ banner = "PURPLE THUNDER", colour = rgb(200, 140, 255), colours = { rgb(210, 160, 255) } },
		{ banner = "RED LIGHTNING", colour = rgb(255, 110, 110), colours = { rgb(255, 140, 130) } },
		{ banner = "GOLDEN THUNDER", colour = rgb(255, 214, 110), colours = { rgb(255, 226, 150) } },
	},
	memeRain = {
		{ banner = "BRAINROT STORM", colour = rgb(120, 255, 120), colours = RAINBOW, glyphs = "memes" },
		{ banner = "IT'S RAINING FOOD", colour = rgb(255, 170, 80), colours = RAINBOW, glyphs = { "🍕", "🍔", "🌮", "🍩", "🍟", "🍣", "🧁", "🍉", "🥨", "🍦" } },
		{ banner = "ANIMAL STAMPEDE", colour = rgb(255, 220, 120), colours = RAINBOW, glyphs = { "🐸", "🐱", "🦆", "🐶", "🐼", "🦄", "🐧", "🐵", "🐹", "🦖" } },
		{ banner = "MONEY RAIN", colour = rgb(120, 255, 140), colours = GOLDS, glyphs = { "💸", "💰", "💎", "🪙", "💵", "👑" } },
		{ banner = "EMOJI STORM", colour = rgb(255, 230, 90), colours = RAINBOW, glyphs = { "😂", "🤣", "😎", "🤩", "🥳", "😜", "🤯", "😹", "🫠", "🤪" } },
	},
	confetti = {
		{ banner = "CONFETTI!", colour = rgb(255, 214, 80), colours = RAINBOW },
		{ banner = "GOLD CONFETTI!", colour = rgb(255, 204, 110), colours = GOLDS },
		{ banner = "PASTEL PARTY!", colour = rgb(255, 190, 220), colours = PASTEL },
		{ banner = "NEON CONFETTI!", colour = rgb(80, 255, 240), colours = NEONS },
	},
	shockwave = {
		{ banner = "SHOCKWAVE!", colour = rgb(255, 204, 110), colours = { rgb(255, 204, 110) } },
		{ banner = "PLASMA WAVE!", colour = rgb(80, 230, 255), colours = { rgb(80, 230, 255) } },
		{ banner = "PINK BLAST!", colour = rgb(255, 90, 210), colours = { rgb(255, 90, 210) } },
		{ banner = "SHOCKWAVE!", colour = rgb(255, 255, 255), colours = { rgb(255, 255, 255) } },
	},
	spin = {
		{ banner = "SPIN!", colour = rgb(90, 230, 255), colours = RAINBOW, speed = 14 },
		{ banner = "TURBO SPIN!", colour = rgb(255, 120, 60), colours = RAINBOW, speed = 24 },
		{ banner = "SLOW-MO SPIN", colour = rgb(190, 160, 255), colours = RAINBOW, speed = 6 },
		{ banner = "REVERSE SPIN!", colour = rgb(120, 255, 160), colours = RAINBOW, speed = -14 },
	},
	meteor = {
		{ banner = "METEOR SHOWER!", colour = rgb(255, 150, 60), colours = { rgb(255, 250, 220), rgb(255, 180, 70), rgb(190, 50, 20) }, sky = rgb(255, 222, 200) },
		{ banner = "ICE COMETS!", colour = rgb(150, 220, 255), colours = { rgb(240, 252, 255), rgb(120, 210, 255), rgb(40, 90, 210) }, sky = rgb(210, 230, 255) },
		{ banner = "GOLDEN METEORS!", colour = rgb(255, 214, 90), colours = { rgb(255, 252, 230), rgb(255, 214, 90), rgb(190, 120, 20) }, sky = rgb(255, 236, 190) },
		{ banner = "COSMIC METEORS!", colour = rgb(200, 140, 255), colours = { rgb(250, 235, 255), rgb(200, 120, 255), rgb(90, 30, 190) }, sky = rgb(225, 205, 255) },
		{ banner = "RAINBOW METEORS!", colour = rgb(255, 120, 200), colours = { rgb(255, 255, 255), rgb(255, 120, 200), rgb(90, 140, 255) }, sky = rgb(240, 225, 255), rainbow = true },
	},
	blackHole = {
		{ banner = "BLACK HOLE!", colour = rgb(190, 120, 255), colours = { rgb(255, 120, 40), rgb(255, 190, 90), rgb(170, 90, 255) } },
		{ banner = "CRIMSON VORTEX!", colour = rgb(255, 80, 90), colours = { rgb(255, 60, 60), rgb(255, 150, 90), rgb(160, 20, 60) } },
		{ banner = "GOLDEN SINGULARITY!", colour = rgb(255, 214, 90), colours = { rgb(255, 214, 90), rgb(255, 245, 200), rgb(200, 130, 30) } },
		{ banner = "WHITE HOLE!", colour = rgb(200, 240, 255), colours = { rgb(120, 220, 255), rgb(240, 250, 255), rgb(90, 120, 255) } },
	},
	aurora = {
		{ banner = "AURORA", colour = rgb(120, 255, 200), colours = { rgb(80, 255, 170), rgb(120, 200, 255), rgb(120, 255, 140), rgb(190, 110, 255) } },
		{ banner = "PINK AURORA", colour = rgb(255, 150, 220), colours = { rgb(255, 120, 200), rgb(200, 120, 255), rgb(255, 180, 230), rgb(140, 120, 255) } },
		{ banner = "GOLDEN AURORA", colour = rgb(255, 214, 110), colours = { rgb(255, 214, 110), rgb(255, 160, 80), rgb(255, 240, 180), rgb(255, 120, 90) } },
		{ banner = "RAINBOW AURORA", colour = rgb(255, 255, 255), colours = RAINBOW },
	},
	galaxy = {
		{ banner = "TO THE STARS", colour = rgb(170, 150, 255), colours = { rgb(160, 80, 255), rgb(60, 140, 255) }, planet = rgb(220, 150, 90) },
		{ banner = "CRIMSON NEBULA", colour = rgb(255, 120, 110), colours = { rgb(255, 70, 90), rgb(255, 150, 60) }, planet = rgb(110, 170, 255) },
		{ banner = "EMERALD GALAXY", colour = rgb(110, 255, 190), colours = { rgb(40, 220, 160), rgb(60, 160, 255) }, planet = rgb(200, 130, 255) },
		{ banner = "GOLDEN GALAXY", colour = rgb(255, 214, 110), colours = { rgb(255, 190, 80), rgb(255, 120, 60) }, planet = rgb(240, 240, 255) },
	},
	ufo = {
		{ banner = "ABDUCTED!", colour = rgb(120, 255, 140), colours = { rgb(140, 255, 160) } },
		{ banner = "PINK INVADERS!", colour = rgb(255, 120, 220), colours = { rgb(255, 130, 220) } },
		{ banner = "THE GOLDEN SAUCER!", colour = rgb(255, 214, 90), colours = { rgb(255, 214, 110) } },
		{ banner = "BLUE BEAM!", colour = rgb(90, 210, 255), colours = { rgb(110, 220, 255) } },
	},
	blizzard = {
		{ banner = "BLIZZARD!", colour = rgb(220, 240, 255), colours = { rgb(255, 255, 255) }, tint = rgb(225, 240, 255) },
		{ banner = "PETAL STORM", colour = rgb(255, 170, 210), colours = { rgb(255, 190, 220), rgb(255, 150, 200) }, tint = rgb(255, 230, 240) },
		{ banner = "GOLD GLITTER STORM", colour = rgb(255, 214, 110), colours = { rgb(255, 220, 120), rgb(255, 250, 220) }, tint = rgb(255, 242, 214) },
		{ banner = "DIAMOND DUST", colour = rgb(160, 235, 255), colours = { rgb(200, 245, 255), rgb(150, 220, 255) }, tint = rgb(220, 245, 255) },
	},
	earthquake = {
		{ banner = "EARTHQUAKE!", colour = rgb(230, 170, 110), colours = { rgb(170, 150, 120) } },
		{ banner = "MAGMA QUAKE!", colour = rgb(255, 110, 50), colours = { rgb(200, 90, 60), rgb(255, 140, 60) } },
		{ banner = "CRYSTAL QUAKE!", colour = rgb(150, 230, 255), colours = { rgb(170, 220, 255), rgb(220, 240, 255) } },
	},
	rainbow = {
		{ banner = "RAINBOW MODE!", colour = rgb(255, 255, 255), colours = RAINBOW },
		{ banner = "PASTEL MODE!", colour = rgb(255, 210, 235), colours = PASTEL },
		{ banner = "NEON MODE!", colour = rgb(80, 255, 240), colours = NEONS },
	},
	bubbles = {
		{ banner = "BUBBLE PARTY!", colour = rgb(160, 220, 255), colours = RAINBOW },
		{ banner = "GOLDEN BUBBLES!", colour = rgb(255, 214, 110), colours = GOLDS },
		{ banner = "LOVE BUBBLES!", colour = rgb(255, 130, 180), colours = { rgb(255, 120, 170), rgb(255, 180, 210), rgb(255, 90, 120) } },
		{ banner = "OCEAN BUBBLES!", colour = rgb(90, 210, 255), colours = { rgb(120, 220, 255), rgb(90, 255, 220), rgb(60, 150, 255) } },
	},
	goldWave = {
		{ banner = "GOLD WAVE!", colour = rgb(255, 204, 110), colours = GOLDS, glyph = "🪙" },
		{ banner = "DIAMOND WAVE!", colour = rgb(170, 230, 255), colours = { rgb(200, 240, 255), rgb(255, 255, 255), rgb(140, 210, 255) }, glyph = "💎" },
		{ banner = "RUBY WAVE!", colour = rgb(255, 90, 110), colours = { rgb(255, 80, 100), rgb(255, 160, 170), rgb(200, 30, 60) }, glyph = "♦️" },
		{ banner = "EMERALD WAVE!", colour = rgb(90, 240, 150), colours = { rgb(80, 230, 140), rgb(190, 255, 210), rgb(30, 150, 90) }, glyph = "💚" },
	},
	fireIce = {
		{ banner = "FIRE & ICE", colour = rgb(255, 140, 100), colours = { rgb(255, 120, 40), rgb(120, 200, 255) } },
		{ banner = "GOLD & SHADOW", colour = rgb(255, 214, 110), colours = { rgb(255, 214, 90), rgb(150, 90, 255) } },
		{ banner = "NEON CLASH", colour = rgb(190, 255, 90), colours = { rgb(150, 255, 70), rgb(255, 80, 210) } },
	},
	blackout = {
		{ banner = "BLACKOUT!", colour = rgb(240, 240, 240), colours = { rgb(255, 250, 230) } },
		{ banner = "RED ALERT!", colour = rgb(255, 80, 80), colours = { rgb(255, 70, 70), rgb(80, 120, 255) } },
		{ banner = "RAVE LIGHTS!", colour = rgb(255, 120, 220), colours = NEONS },
		{ banner = "GOLDEN SPOTLIGHT", colour = rgb(255, 214, 110), colours = GOLDS },
	},
	tornado = {
		{ banner = "TORNADO!", colour = rgb(200, 190, 170), colours = { rgb(190, 180, 160) } },
		{ banner = "FIRENADO!", colour = rgb(255, 120, 50), colours = { rgb(255, 120, 40), rgb(255, 200, 90) } },
		{ banner = "RAINBOW TWISTER!", colour = rgb(255, 150, 220), colours = RAINBOW },
		{ banner = "WATERSPOUT!", colour = rgb(90, 200, 255), colours = { rgb(120, 210, 255), rgb(200, 240, 255) } },
	},
	fireworks = {
		{ banner = "FIREWORKS!", colour = rgb(255, 214, 110), colours = GOLDS },
		{ banner = "HANABI!", colour = rgb(255, 150, 200), colours = RAINBOW, act = "hanabi" },
		{ banner = "LIBERTY LIGHTS", colour = rgb(255, 255, 255), colours = RAINBOW, act = "liberty" },
		{ banner = "MAJESTY", colour = rgb(255, 204, 110), colours = GOLDS, act = "majesty" },
	},
	titan = {
		{ banner = "TITAN MEME", colour = rgb(200, 200, 210), colours = RAINBOW, glyph = "🗿" },
		{ banner = "TITAN CLOWN", colour = rgb(255, 120, 120), colours = RAINBOW, glyph = "🤡" },
		{ banner = "TITAN FROG", colour = rgb(120, 255, 120), colours = RAINBOW, glyph = "🐸" },
		{ banner = "TITAN CAT", colour = rgb(255, 214, 110), colours = RAINBOW, glyph = "😹" },
		{ banner = "TITAN DUCK", colour = rgb(255, 230, 90), colours = RAINBOW, glyph = "🦆" },
	},
	zeroG = {
		{ banner = "ZERO GRAVITY", colour = rgb(190, 200, 255), colours = { rgb(200, 210, 255) }, gravity = 12, hop = 28 },
		{ banner = "MOON BOUNCE!", colour = rgb(230, 230, 255), colours = { rgb(240, 240, 255) }, gravity = 20, hop = 45 },
		{ banner = "SPACE WALK", colour = rgb(150, 140, 255), colours = { rgb(170, 150, 255) }, gravity = 6, hop = 18 },
	},
	ownerArmy = {
		{ banner = "AJKR'S ARMY!", colour = rgb(255, 204, 110), colours = GOLDS },
		{ banner = "AJKR'S RAINBOW ARMY!", colour = rgb(255, 150, 220), colours = RAINBOW },
	},
} :: { [string]: { Variant } }

-- An effect's looks (the first if `v` isn't one of its own).
function AbuseNights.variant(id: string, v: number?): Variant?
	local list = AbuseNights.Variants[id]
	if not list or #list == 0 then
		return nil
	end
	local i = if type(v) == "number" then math.floor(v) else 1
	return list[if i >= 1 and i <= #list then i else 1]
end

function AbuseNights.variantCount(id: string): number
	local list = AbuseNights.Variants[id]
	return if list then #list else 0
end

---------------------------------------------------------------------------------------------------
-- The owner's lines: what AJKR says on every screen as each surprise lands (picked by the night).
---------------------------------------------------------------------------------------------------
AbuseNights.Quips = {
	any = { "You're welcome. 😎", "Nobody asked. I did it anyway.", "Admin powers: ON. Chill: OFF.", "Did somebody say MORE?", "Watch this. 👀", "I could stop... but I won't.", "Hope you're ready, because I'm not. 🔥", "This one's my favourite.", "Again? AGAIN.", "No refunds. It's free anyway.", "Is this too much? No. More.", "Clip this. 🎥" },
	launch = { "Everybody UP! 🚀", "Gravity is a suggestion." },
	dance = { "Dance or I double it. 💃", "Hit the floor! 🪩" },
	storm = { "Weather report: chaos. ⚡", "Did anyone else hear thunder? Indoors?" },
	memeRain = { "Brainrot incoming! 🗿", "Umbrellas won't help you now." },
	confetti = { "Confetti budget: unlimited. 🎉", "POP POP POP!" },
	shockwave = { "Stand back... 💥", "Stand clear... BOOM." },
	spin = { "Round and round! 🌀", "Dizzy yet?" },
	meteor = { "Heads up! ☄️", "Look UP!" },
	blackHole = { "Hold onto something. 🕳️", "Gravity just got personal." },
	aurora = { "Look at the sky... 🌌", "Pretty, right?" },
	galaxy = { "To infinity... 🪐", "The house is in space now. Normal." },
	ufo = { "Beam me up! 🛸", "They're friendly. Probably." },
	blizzard = { "Winter is HERE. ❄️", "Hope you packed a scarf." },
	earthquake = { "Do you feel that? 🌋", "That's not the bass. That's the floor." },
	rainbow = { "Every colour, all at once! 🌈", "Colour overload!" },
	bubbles = { "Pop them all! 🫧", "Bubble time." },
	goldWave = { "Make it RAIN gold! 🪙", "Surf's up. In gold." },
	fireIce = { "Hot AND cold. 🔥❄️", "Pick a side!" },
	blackout = { "Who turned off the lights? 🔦", "Shhh... ." },
	tornado = { "Spin cycle! 🌪️", "Hold your hats!" },
	fireworks = { "Light it UP! 🎆", "Look at THAT!" },
	titan = { "He's BIG. 🗿", "Don't make eye contact." },
	zeroG = { "Float with me. 🌙", "Weightless!" },
	ownerArmy = { "Meet the family. 🕺", "There's more of me now." },
}

-- What AJKR says for a surprise (the same line everywhere for the same night and moment).
function AbuseNights.quip(id: string, r: Rng): string
	local own = AbuseNights.Quips[id]
	if own and AbuseNights.next(r) < 0.6 then
		return AbuseNights.pick(r, own)
	end
	return AbuseNights.pick(r, AbuseNights.Quips.any)
end

---------------------------------------------------------------------------------------------------
-- A night worked out from its seed: the same everywhere.
---------------------------------------------------------------------------------------------------
-- Effects that move a guest (never two at once: they'd fight over them).
AbuseNights.MOVERS = { launch = true, shockwave = true, spin = true, blackHole = true, ufo = true, tornado = true, zeroG = true, earthquake = true }
-- Seconds between surprises.
AbuseNights.PACE = {
	calm = { abuse = 55, mega = 30 },
	normal = { abuse = 44, mega = 25 },
	wild = { abuse = 34, mega = 20 },
} :: { [string]: { abuse: number, mega: number } }
-- Mega Abuse brings these too, whatever the night (every effect, in the end).
AbuseNights.MEGA_EXTRA = { "meteor", "blackHole", "ufo", "tornado", "galaxy", "titan", "fireworks", "earthquake", "aurora", "memeRain", "rainbow", "launch" }
AbuseNights.MEGA_MUSIC = { "mega", "mega", "mega", "epic", "party" }

export type Beat = { at: number, id: string, v: number, line: string, also: string?, alsoV: number? }
export type Plan = {
	seed: number,
	mega: boolean,
	night: Night,
	opening: string,
	title: string,
	palette: string,
	finale: string,
	music: string,
	track: number,
	realms: { string },
	realmSeconds: number,
	beats: { Beat },
	giftEvery: number,
	giant: boolean,
	events: { string },
}

-- Which night a seed gives (or the one asked for).
function AbuseNights.nightFor(seed: number, asked: string?): Night
	if asked and AbuseNights.byId[asked] then
		return AbuseNights.byId[asked]
	end
	local r = AbuseNights.rng(seed)
	return AbuseNights.pick(r, AbuseNights.List)
end

-- The whole night: `seconds` long (for its surprises), `giant` as the house allows the owner's
-- giant ("never", "rare": the nights made for it, "always"), `realmSeconds` and `giftEvery` the
-- house's own (Config.Admin.show).
function AbuseNights.plan(seed: number, mega: boolean, seconds: number, asked: string?, options: { [string]: any }?): Plan
	local o: { [string]: any } = options or {}
	local night = AbuseNights.nightFor(seed, asked)
	-- (Its own stream, so the same night asked for by name still differs with its seed.)
	local r = AbuseNights.rng(seed * 7 + 3)
	local opening = AbuseNights.pick(r, night.opening)
	local title = AbuseNights.pick(r, night.title)
	-- Mega Abuse: harder music, a new realm every so often (the night's first), more surprises.
	local music = if mega then AbuseNights.pick(r, AbuseNights.MEGA_MUSIC) else night.music
	local track = AbuseNights.int(r, 1, 6)
	local realms = { night.realm }
	if mega then
		local others = {}
		for _, id in o.realms or {} do
			if id ~= night.realm then
				table.insert(others, id)
			end
		end
		for _, id in AbuseNights.shuffle(r, others) do
			table.insert(realms, id)
		end
	end
	-- The surprises: the night's own, shuffled (Mega Abuse adds more), none twice in a row.
	local pool = table.clone(night.pool)
	if mega then
		for _, id in AbuseNights.shuffle(r, AbuseNights.MEGA_EXTRA) do
			if not table.find(pool, id) and #pool < #night.pool + 6 then
				table.insert(pool, id)
			end
		end
	end
	local function allowed(id: string): boolean
		return AbuseNights.Variants[id] ~= nil and (id ~= "ownerArmy" or o.giant ~= "never")
	end
	local usable = {}
	for _, id in pool do
		if allowed(id) then
			table.insert(usable, id)
		end
	end
	if #usable == 0 then
		usable = { "confetti", "fireworks" }
	end
	local pace = AbuseNights.PACE[night.pace] or AbuseNights.PACE.normal
	local every = if mega then pace.mega else pace.abuse
	local beats: { Beat } = {}
	local order: { string } = {}
	local last = ""
	local t = 10 + every * 0.5
	while t < seconds - 6 do
		if #order == 0 then
			order = AbuseNights.shuffle(r, usable)
		end
		-- (Never the one just played: the next different one comes first; if only it is left in
		-- this round, the next round begins.)
		local function different(): boolean
			for j = 1, #order do
				if order[j] ~= last then
					order[1], order[j] = order[j], order[1]
					return true
				end
			end
			return false
		end
		if not different() then
			order = AbuseNights.shuffle(r, usable)
			different()
		end
		local id = table.remove(order, 1) :: string
		last = id
		local beat: Beat = { at = math.floor(t), id = id, v = AbuseNights.int(r, 1, math.max(1, AbuseNights.variantCount(id))), line = AbuseNights.quip(id, r) }
		if AbuseNights.next(r) < night.combo + (if mega then 0.1 else 0) then
			-- A second at once: never a second that moves guests, nor the same.
			local partners = {}
			for _, other in usable do
				if other ~= id and not (AbuseNights.MOVERS[other] and AbuseNights.MOVERS[id]) then
					table.insert(partners, other)
				end
			end
			if #partners > 0 then
				local also = AbuseNights.pick(r, partners)
				beat.also = also
				beat.alsoV = AbuseNights.int(r, 1, math.max(1, AbuseNights.variantCount(also)))
			end
		end
		table.insert(beats, beat)
		t += every * (0.8 + AbuseNights.next(r) * 0.4)
	end
	-- What the night switches on: the boosts every night has, its body and its hunts.
	local events = table.clone(AbuseNights.Boosts)
	for _, id in AbuseNights.Bodies[night.body] or AbuseNights.Bodies.classic do
		table.insert(events, id)
	end
	for _, id in AbuseNights.Hunts[night.hunts] or AbuseNights.Hunts.all do
		table.insert(events, id)
	end
	local giftBase = if mega then (o.giftEvery and o.giftEvery.mega or 45) else (o.giftEvery and o.giftEvery.abuse or 75)
	local giant = (o.giant == "always") or (o.giant ~= "never" and night.giant == true)
	return {
		seed = seed,
		mega = mega,
		night = night,
		opening = opening,
		title = title,
		palette = night.palette,
		finale = night.finale,
		music = music,
		track = track,
		realms = realms,
		realmSeconds = (o.realmSeconds or 90) * (if night.pace == "wild" then 0.8 elseif night.pace == "calm" then 1.2 else 1),
		beats = beats,
		giftEvery = math.max(20, math.floor(giftBase / (night.gifts or 1))),
		giant = giant,
		events = events,
	}
end

return AbuseNights
