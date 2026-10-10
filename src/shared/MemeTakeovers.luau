--!strict
-- The Meme Takeover's editions. Each time a guest plays their Meme Takeover the server picks an
-- edition they haven't seen lately (Purchases/Spectacles), so it's never the same show twice in a
-- row. Each edition has its own colours, cast, boss, music and words, and its own way through the
-- six acts: how the memes arrive, how they dance, what rains down, how the boss shows off, how the
-- chaos goes, and how it ends (World/MemeTakeover draws them). The show costs the same whichever
-- comes, and nothing in it is a prize: it's a show, not a draw.
--   opening   siren | glitch | countdown | blackout
--   entrance  portal | drop | fountain | march | swirl
--   dance     conga | tornado | orbit | wave | bounce | duel | stack
--   rain      the glyphs that fall (rainUp: they rise, like bubbles); none: little memes
--   bossMove  lasers | stomp | spin | split | halo
--   chaos     frenzy | zeroG | rainbow | slowmo
--   finale    burst | implode | freeze | rockets | bow | gold
--   music     a list in Config.Assets.AbuseMusic ("" for the Meme Takeover's own track)

local MemeTakeovers = {}

export type Variant = {
	id: string,
	name: string,
	glyph: string,
	line: string,
	palette: { Color3 },
	captions: { string },
	opening: string,
	entrance: string,
	dance: string,
	rain: { string }?,
	rainUp: boolean?,
	boss: string,
	bossMove: string,
	chaos: string,
	finale: string,
	cast: { string }?,
	music: string,
	sounds: { open: { string }, boss: { string }, finale: { string } },
}

local rgb = Color3.fromRGB

MemeTakeovers.Openings = { siren = true, glitch = true, countdown = true, blackout = true }
MemeTakeovers.Entrances = { portal = true, drop = true, fountain = true, march = true, swirl = true }
MemeTakeovers.Dances = { conga = true, tornado = true, orbit = true, wave = true, bounce = true, duel = true, stack = true }
MemeTakeovers.BossMoves = { lasers = true, stomp = true, spin = true, split = true, halo = true }
MemeTakeovers.Chaos = { frenzy = true, zeroG = true, rainbow = true, slowmo = true }
MemeTakeovers.Finales = { burst = true, implode = true, freeze = true, rockets = true, bow = true, gold = true }

MemeTakeovers.List = {
	{
		id = "classic",
		name = "THE CLASSIC",
		glyph = "🗿",
		line = "The original. Every meme, every act.",
		palette = { rgb(255, 60, 200), rgb(60, 200, 255), rgb(120, 255, 90), rgb(255, 220, 60), rgb(170, 80, 255), rgb(255, 90, 60) },
		captions = { "⚠️ MEME TAKEOVER ⚠️", "THE PORTAL IS OPEN", "CONGA LINE!!", "IT'S RAINING MEMES", "THE BIG CHEESE HAS ARRIVED", "MAXIMUM BRAINROT", "GG · MEME TAKEOVER COMPLETE" },
		opening = "siren",
		entrance = "portal",
		dance = "conga",
		boss = "moonCheese",
		bossMove = "lasers",
		chaos = "frenzy",
		finale = "burst",
		music = "",
		sounds = { open = { "airHorn", "recordScratch" }, boss = { "slideWhistle", "kazoo" }, finale = { "airHorn", "partyHorn" } },
	},
	{
		id = "cosmic",
		name = "COSMIC MEMES",
		glyph = "🪐",
		line = "They came from space. They brought snacks.",
		palette = { rgb(120, 90, 255), rgb(60, 140, 255), rgb(90, 240, 255), rgb(255, 120, 230), rgb(200, 180, 255), rgb(40, 60, 160) },
		captions = { "📡 INCOMING TRANSMISSION", "THEY CAME FROM SPACE", "ORBIT LOCKED IN", "IT'S RAINING STARS", "THE MOON HAS LANDED", "ZERO GRAVITY", "SUPERNOVA · GG" },
		opening = "blackout",
		entrance = "swirl",
		dance = "orbit",
		rain = { "⭐", "✨", "🌟", "💫" },
		boss = "moonCheese",
		bossMove = "halo",
		chaos = "zeroG",
		finale = "implode",
		music = "cosmic",
		sounds = { open = { "warpBuild", "warpBurst" }, boss = { "heavenly", "magicZoom" }, finale = { "sonicBoom", "shimmerFall" } },
	},
	{
		id = "glitch",
		name = "NEON GLITCH",
		glyph = "💾",
		line = "Something is wrong with the Suite. It's perfect.",
		palette = { rgb(0, 255, 230), rgb(255, 0, 200), rgb(170, 255, 0), rgb(120, 60, 255), rgb(255, 240, 80), rgb(0, 140, 255) },
		captions = { "ERR0R: T00 MANY MEMES", "LOADING MEMES... 99%", "THE WAVE.EXE", "DATA STORM", "THE FASTEST SNAIL ONLINE", "RAINBOW OVERFLOW", "SYSTEM REBOOTED · GG" },
		opening = "glitch",
		entrance = "march",
		dance = "wave",
		rain = { "💾", "⚡", "🔋", "📟" },
		boss = "snailExpress",
		bossMove = "split",
		chaos = "rainbow",
		finale = "freeze",
		music = "mega",
		sounds = { open = { "glitch", "subHit" }, boss = { "glitch", "warpBurst" }, finale = { "glitch", "crystal" } },
	},
	{
		id = "solidGold",
		name = "SOLID GOLD",
		glyph = "🪙",
		line = "Everything touches gold. Even the memes.",
		palette = { rgb(255, 214, 90), rgb(255, 180, 40), rgb(255, 240, 170), rgb(214, 150, 40), rgb(255, 255, 220), rgb(180, 120, 30) },
		captions = { "3 · 2 · 1 · GOLD", "THE GOLD FOUNTAIN", "STACK THEM UP", "COINS FROM THE CEILING", "THE GOLDEN GOOSE", "GOLD FRENZY", "SOLID GOLD · GG" },
		opening = "countdown",
		entrance = "fountain",
		dance = "stack",
		rain = { "🪙", "💰", "✨" },
		boss = "goldenGoose",
		bossMove = "spin",
		chaos = "frenzy",
		finale = "gold",
		music = "gold",
		sounds = { open = { "kaching", "coinDrop" }, boss = { "regalFanfare", "bellTree" }, finale = { "kaching", "shimmerFall" } },
	},
	{
		id = "discoInferno",
		name = "DISCO INFERNO",
		glyph = "🪩",
		line = "The floor is on fire. Keep dancing.",
		palette = { rgb(255, 70, 40), rgb(255, 150, 30), rgb(255, 50, 150), rgb(255, 220, 90), rgb(200, 40, 255), rgb(255, 110, 110) },
		captions = { "🔥 DISCO INFERNO 🔥", "THE MEMES ARE DROPPING IN", "DANCE-OFF!!", "DISCO BALLS FROM THE SKY", "THE BAGUETTE BODYBUILDER", "RAINBOW FEVER", "LAST DANCE · GG" },
		opening = "siren",
		entrance = "drop",
		dance = "duel",
		rain = { "🪩", "🔥", "💃", "🕺" },
		boss = "baguettone",
		bossMove = "spin",
		chaos = "rainbow",
		finale = "rockets",
		music = "party",
		sounds = { open = { "partyHorn", "recordScratch" }, boss = { "stinger", "partyHorn" }, finale = { "fireworkBoom", "crowdCheer" } },
	},
	{
		id = "frostbite",
		name = "FROSTBITE",
		glyph = "❄️",
		line = "A blizzard of memes. Wrap up warm.",
		palette = { rgb(170, 220, 255), rgb(90, 170, 255), rgb(230, 245, 255), rgb(140, 120, 255), rgb(120, 255, 240), rgb(60, 110, 200) },
		captions = { "❄️ THE TEMPERATURE IS DROPPING", "MEMES ON ICE", "THE BLIZZARD SPIN", "SNOW DAY", "THE GELATO GIANT", "SLOW... MOTION...", "FREEZE! · GG" },
		opening = "blackout",
		entrance = "drop",
		dance = "tornado",
		rain = { "❄️", "🧊", "⛄" },
		boss = "gelato",
		bossMove = "stomp",
		chaos = "slowmo",
		finale = "freeze",
		music = "winter",
		sounds = { open = { "crystal", "shimmerFall" }, boss = { "lowHit", "crystal" }, finale = { "crystal", "shimmerFall" } },
	},
	{
		id = "jungle",
		name = "JUNGLE JAM",
		glyph = "🌿",
		line = "Vines in the Suite. Something is drumming.",
		palette = { rgb(90, 220, 90), rgb(255, 220, 70), rgb(40, 160, 90), rgb(255, 150, 50), rgb(180, 255, 120), rgb(120, 90, 40) },
		captions = { "3 · 2 · 1 · JUNGLE", "THE MEMES MARCH IN", "BOUNCE TO THE DRUMS", "BANANA RAIN", "THE FROG KING", "JUNGLE FRENZY", "TAKE A BOW · GG" },
		opening = "countdown",
		entrance = "march",
		dance = "bounce",
		rain = { "🍌", "🍃", "🥥", "🌺" },
		boss = "frogKing",
		bossMove = "stomp",
		chaos = "frenzy",
		finale = "bow",
		music = "hero",
		sounds = { open = { "subHit", "partyHorn" }, boss = { "lowHit", "regalFanfare" }, finale = { "applause", "crowdCheer" } },
	},
	{
		id = "sugarRush",
		name = "SUGAR RUSH",
		glyph = "🍭",
		line = "Too much sugar. Way too much.",
		palette = { rgb(255, 120, 200), rgb(255, 200, 230), rgb(140, 220, 255), rgb(255, 240, 140), rgb(190, 140, 255), rgb(255, 90, 140) },
		captions = { "🍬 SUGAR RUSH INCOMING", "THE CANDY FOUNTAIN", "THE SUGAR WAVE", "SWEETS FROM THE CEILING", "THE MACARON MAESTRO", "SUGAR FRENZY", "SUGAR CRASH · GG" },
		opening = "siren",
		entrance = "fountain",
		dance = "wave",
		rain = { "🍬", "🍭", "🍩", "🧁" },
		boss = "macaronMaestro",
		bossMove = "split",
		chaos = "frenzy",
		finale = "burst",
		music = "party",
		sounds = { open = { "partyHorn", "slideWhistle" }, boss = { "bellTree", "kazoo" }, finale = { "partyHorn", "applause" } },
	},
	{
		id = "arcade",
		name = "RETRO ARCADE",
		glyph = "👾",
		line = "Insert coin. Actually, it's free.",
		palette = { rgb(80, 255, 120), rgb(255, 60, 220), rgb(255, 240, 60), rgb(60, 220, 255), rgb(255, 120, 40), rgb(150, 90, 255) },
		captions = { "3 · 2 · 1 · GO!", "PLAYER ONE: MEMES", "STACK ATTACK", "PIXEL RAIN", "BOSS LEVEL: PIGEONETTO", "BONUS ROUND", "HIGH SCORE! · GG" },
		opening = "countdown",
		entrance = "march",
		dance = "stack",
		rain = { "👾", "🕹️", "⭐", "💥" },
		boss = "pigeonetto",
		bossMove = "lasers",
		chaos = "rainbow",
		finale = "rockets",
		music = "mega",
		sounds = { open = { "tick", "stinger" }, boss = { "glitch", "stinger" }, finale = { "fireworkBoom", "applause" } },
	},
	{
		id = "royalCourt",
		name = "THE ROYAL COURT",
		glyph = "👑",
		line = "The court is in session. The memes rule.",
		palette = { rgb(255, 210, 110), rgb(150, 60, 200), rgb(220, 40, 70), rgb(255, 245, 210), rgb(110, 40, 160), rgb(255, 170, 60) },
		captions = { "👑 THE COURT IS IN SESSION", "THE ROYAL PROCESSION", "THE GRAND CONGA", "ROSES AND JEWELS", "HER MAJESTY LE CHAT", "SLOW... AND... REGAL...", "LONG LIVE THE MEMES · GG" },
		opening = "blackout",
		entrance = "march",
		dance = "conga",
		rain = { "👑", "💎", "🌹" },
		boss = "chatCouture",
		bossMove = "halo",
		chaos = "slowmo",
		finale = "bow",
		music = "hero",
		sounds = { open = { "regalFanfare", "gong" }, boss = { "heavenly", "regalFanfare" }, finale = { "applause", "bellTree" } },
	},
	{
		id = "deepSea",
		name = "DEEP SEA DISCO",
		glyph = "🫧",
		line = "The Suite sank. The party didn't.",
		palette = { rgb(40, 220, 220), rgb(30, 120, 220), rgb(120, 255, 210), rgb(70, 70, 200), rgb(200, 255, 255), rgb(20, 180, 160) },
		captions = { "🌊 THE SUITE IS SINKING", "SWIMMING IN", "THE CURRENT", "BUBBLES!", "THE LOBSTER OF LUXURY", "WEIGHTLESS", "BUBBLE POP · GG" },
		opening = "blackout",
		entrance = "swirl",
		dance = "orbit",
		rain = { "🫧" },
		rainUp = true,
		boss = "lobsterLuxe",
		bossMove = "spin",
		chaos = "zeroG",
		finale = "implode",
		music = "cosmic",
		sounds = { open = { "riseWhoosh", "subHit" }, boss = { "magicZoom", "lowHit" }, finale = { "sparklePass", "shimmerFall" } },
	},
	{
		id = "pastry",
		name = "PASTRY PANIC",
		glyph = "🥐",
		line = "The bakery has escaped. Hide the butter.",
		palette = { rgb(255, 200, 120), rgb(220, 140, 70), rgb(255, 230, 180), rgb(255, 150, 160), rgb(200, 110, 60), rgb(255, 245, 210) },
		captions = { "🥐 THE OVEN IS OPEN", "FRESH FROM THE OVEN", "THE DOUGH TORNADO", "IT'S RAINING BREAD", "CROISSANTINO IS FURIOUS", "PASTRY FRENZY", "BON APPÉTIT · GG" },
		opening = "siren",
		entrance = "drop",
		dance = "tornado",
		rain = { "🥐", "🥖", "🧀", "🥨" },
		boss = "croissantino",
		bossMove = "stomp",
		chaos = "frenzy",
		finale = "burst",
		music = "party",
		sounds = { open = { "airHorn", "kazoo" }, boss = { "lowHit", "kazoo" }, finale = { "partyHorn", "crowdCheer" } },
	},
	{
		id = "midnight",
		name = "MIDNIGHT OWL",
		glyph = "🦉",
		line = "Only the night shift is awake. And the memes.",
		palette = { rgb(110, 120, 255), rgb(210, 220, 255), rgb(150, 90, 230), rgb(80, 200, 255), rgb(255, 230, 150), rgb(40, 50, 140) },
		captions = { "🌙 IT'S PAST MIDNIGHT", "THE NIGHT SHIFT ARRIVES", "THE MOONLIGHT WAVE", "STARS AND MOONS", "THE OWL WHO NEVER SLEEPS", "SLOW... DREAMY...", "GOODNIGHT · GG" },
		opening = "blackout",
		entrance = "swirl",
		dance = "wave",
		rain = { "🌙", "⭐", "✨" },
		boss = "midnightOwl",
		bossMove = "halo",
		chaos = "slowmo",
		finale = "freeze",
		music = "spy",
		sounds = { open = { "gong", "shimmerFall" }, boss = { "heavenly", "bellTree" }, finale = { "crystal", "bellTree" } },
	},
	{
		id = "teatime",
		name = "TEATIME TORNADO",
		glyph = "🫖",
		line = "Four o'clock sharp. Spill nothing.",
		palette = { rgb(140, 230, 190), rgb(255, 255, 240), rgb(255, 190, 210), rgb(214, 172, 92), rgb(170, 210, 255), rgb(100, 190, 150) },
		captions = { "3 · 2 · 1 · TEATIME", "THE TEA PARTY ARRIVES", "THE TEACUP TORNADO", "CAKE FROM THE CEILING", "TEACUPO TORNADO", "TEA FRENZY", "MORE TEA? · GG" },
		opening = "countdown",
		entrance = "swirl",
		dance = "tornado",
		rain = { "🫖", "🍰", "🍵", "🍪" },
		boss = "teacupo",
		bossMove = "spin",
		chaos = "frenzy",
		finale = "rockets",
		music = "party",
		sounds = { open = { "bellTree", "partyHorn" }, boss = { "riseWhoosh", "kazoo" }, finale = { "fireworkBoom", "applause" } },
	},
	{
		id = "pandaPiano",
		name = "PANDA PIANO PARTY",
		glyph = "🐼",
		line = "Three in the morning. The panda's at the keys.",
		palette = { rgb(255, 255, 255), rgb(30, 30, 40), rgb(255, 214, 90), rgb(255, 120, 180), rgb(120, 200, 255), rgb(200, 200, 220) },
		captions = { "🎹 THE KEYS ARE PLAYING THEMSELVES", "NOTES FALLING IN", "BOUNCE ON THE BEAT", "MUSIC FROM THE CEILING", "PANDA PIANISSIMO", "RAINBOW RHAPSODY", "ENCORE! · GG" },
		opening = "countdown",
		entrance = "drop",
		dance = "bounce",
		rain = { "🎵", "🎶", "🎹" },
		boss = "pianoPanda",
		bossMove = "stomp",
		chaos = "rainbow",
		finale = "bow",
		music = "spy",
		sounds = { open = { "bellTree", "stinger" }, boss = { "lowHit", "bellTree" }, finale = { "applause", "crowdCheer" } },
	},
} :: { Variant }

MemeTakeovers.byId = {} :: { [string]: Variant }
for _, v in MemeTakeovers.List do
	MemeTakeovers.byId[v.id] = v
end

-- An edition by id (the classic for anything unknown).
function MemeTakeovers.get(id: any): Variant
	return (if type(id) == "string" then MemeTakeovers.byId[id] else nil) or MemeTakeovers.List[1]
end

-- Picks an edition not among `recent` (the ones seen last, newest last), using `rng` (a number from
-- 0 to 1). With every edition seen lately, the one seen longest ago.
function MemeTakeovers.pick(recent: { string }, roll: number): string
	local seen: { [string]: boolean } = {}
	for _, id in recent do
		seen[id] = true
	end
	local fresh = {}
	for _, v in MemeTakeovers.List do
		if not seen[v.id] then
			table.insert(fresh, v.id)
		end
	end
	if #fresh == 0 then
		return recent[1] or MemeTakeovers.List[1].id
	end
	local i = math.clamp(math.floor(roll * #fresh) + 1, 1, #fresh)
	return fresh[i]
end

return MemeTakeovers
