--!strict
-- The Grand Ballroom: the house's great hall of entertainments, through the gilded doors at the
-- far end of the Ballroom (where Lights Out is still played at the twenty tables). One vast
-- colonnaded hall under three chandeliers:
--   The Dance Floor        glass tiles that light to the beat, the DJ's jukebox (vote the next
--                          track), seven moves to dance and a little Gilt a minute on the floor
--   The Salon of Wits      Luxury Trivia: seven questions, eight podiums, quickest right wins
--   The Runway             a themed fashion show: walk the catwalk, strike a pose, the room votes
--   The Daily Arena        a quick challenge that changes every day (three in turn)
--   The photo sets         the Gilded Frame, the Rose Arch and the Moonlit Terrace, with poses
--   The Achievement Gallery  your own Badge Book, framed along the colonnades
--   The Exchange           four trading stands: Gilt, Gems, brainrots and curios with any guest
--   The Hall of Fame       six boards of the house's best: Fortune, Gilt, Gems, brainrots,
--                          the Wardrobe and the collection
-- Pure plan and content, shared by the builder, the server (which decides everything: who is
-- where, every answer, vote and point, every reward) and the screens. Every reward is modest and
-- capped for the day; none of it is ever sold.

local Gala = {}

Gala.ID = "gala"

local rgb = Color3.fromRGB
local v3 = Vector3.new

---------------------------------------------------------------------------------------------------
-- The hall (from its origin: the middle of its floor; the floor's top is y = 0)
---------------------------------------------------------------------------------------------------
Gala.HALL = { minX = -130, maxX = 130, minZ = -110, maxZ = 110, height = 56 }
Gala.NAVE = 46 -- the colonnades stand at x = ±46
Gala.COLUMNS = { -90, -72, -54, -36, -18, 0, 18, 36, 54, 72, 90 } -- along each colonnade (z)

-- Where a guest arrives (inside the doors home, facing up the hall) and the doors themselves.
Gala.ARRIVAL = CFrame.lookAt(v3(0, 0, -96), v3(0, 0, 0))
Gala.DOORS = v3(0, 0, -110)

-- The Dance Floor (a circle), the DJ's booth to its north.
Gala.DANCE = { centre = v3(0, 0, -20), radius = 26 }
Gala.DJ = v3(0, 0, 16)

-- The Achievement Gallery: eight frames along the colonnades, facing the nave.
Gala.FRAMES = {
	CFrame.lookAt(v3(-39, 0, 27), v3(0, 0, 27)), CFrame.lookAt(v3(-39, 0, 45), v3(0, 0, 45)),
	CFrame.lookAt(v3(-39, 0, 63), v3(0, 0, 63)), CFrame.lookAt(v3(-39, 0, 81), v3(0, 0, 81)),
	CFrame.lookAt(v3(39, 0, 27), v3(0, 0, 27)), CFrame.lookAt(v3(39, 0, 45), v3(0, 0, 45)),
	CFrame.lookAt(v3(39, 0, 63), v3(0, 0, 63)), CFrame.lookAt(v3(39, 0, 81), v3(0, 0, 81)),
} :: { CFrame }

-- The Hall of Fame: six boards on the north wall, three either side of the Moonlit Terrace.
Gala.BOARD_X = { -42, -31, -20, 20, 31, 42 }
Gala.BOARD_Y = 18 -- their middle
Gala.TERRACE = { minX = -12, maxX = 12, minZ = 96, maxZ = 110, top = 2.4 }
Gala.MOON = v3(0, 33, 109.3)

-- The Salon of Wits (Luxury Trivia): the screen on the west wall, the host, eight podiums.
Gala.TRIVIA = { screen = v3(-129.4, 18, 58), host = v3(-116, 0, 58), centre = v3(-120, 0, 58), radius = 34 }
Gala.PODIUMS = 8
function Gala.podium(i: number): CFrame
	local a = math.rad(-52.5 + 15 * (i - 1))
	local c = Gala.TRIVIA.centre
	local at = c + v3(math.cos(a) * Gala.TRIVIA.radius, 0, math.sin(a) * Gala.TRIVIA.radius)
	return CFrame.lookAt(at, v3(c.X, 0, c.Z))
end
-- Where a guest at podium `i` stands: behind it, facing the screen.
function Gala.podiumStand(i: number): CFrame
	return Gala.podium(i) * CFrame.new(0, 0, 3)
end

-- The Runway: the catwalk up the east wing, the stage behind it, the marks.
Gala.RUNWAY = {
	x = 88, width = 8, top = 2.4, fromZ = 14, toZ = 88, -- the catwalk
	stage = { minX = 70, maxX = 106, minZ = 88, maxZ = 108 },
	start = CFrame.lookAt(v3(88, 2.4, 92), v3(88, 2.4, 0)),
	finish = v3(88, 2.4, 19),
	wait = CFrame.lookAt(v3(100, 2.4, 100), v3(88, 2.4, 100)), -- the models' row, backstage
	board = v3(88, 38, 107.6),
	book = v3(76, 2.4, 100), -- the book models sign
}

-- The Daily Arena.
Gala.ARENA = { centre = v3(-88, 0, -58), radius = 30, dais = 5, board = v3(-129.4, 16, -58), gate = v3(-54, 0, -58) }

-- The Exchange: four stands.
Gala.STANDS = { v3(70, 0, -36), v3(106, 0, -36), v3(70, 0, -80), v3(106, 0, -80) } :: { Vector3 }
Gala.EXCHANGE_BOARD = v3(129.4, 16, -58)

-- The photo sets: where a guest poses (facing the camera) and where the camera stands.
export type PhotoSet = { id: string, name: string, line: string, mark: CFrame, camera: Vector3, look: Vector3 }
Gala.PhotoSets = {
	{ id = "frame", name = "The Gilded Frame", line = "Step into the great gold frame: a portrait for the house's walls.", mark = CFrame.lookAt(v3(-30, 0, -103), v3(-30, 0, 0)), camera = v3(-30, 6.2, -87), look = v3(-30, 4.6, -103) },
	{ id = "rose", name = "The Rose Arch", line = "Under the arch of roses, with the petals falling.", mark = CFrame.lookAt(v3(30, 0, -103), v3(30, 0, 0)), camera = v3(30, 6.2, -87), look = v3(30, 4.6, -103) },
	{ id = "moon", name = "The Moonlit Terrace", line = "On the terrace, the great moon rising behind you.", mark = CFrame.lookAt(v3(0, 2.4, 101), v3(0, 2.4, 0)), camera = v3(0, 5.4, 80), look = v3(0, 13, 104) },
} :: { PhotoSet }
Gala.photoById = {} :: { [string]: PhotoSet }
for _, s in Gala.PhotoSets do
	Gala.photoById[s.id] = s
end

-- The parts of the hall, for the screens (where a guest is) and the server's checks.
export type Zone = { id: string, name: string, minX: number, maxX: number, minZ: number, maxZ: number }
Gala.Zones = {
	{ id = "trivia", name = "The Salon of Wits", minX = -130, maxX = -46, minZ = 6, maxZ = 110 },
	{ id = "arena", name = "The Daily Arena", minX = -130, maxX = -46, minZ = -110, maxZ = -6 },
	{ id = "runway", name = "The Runway", minX = 46, maxX = 130, minZ = 0, maxZ = 110 },
	{ id = "exchange", name = "The Exchange", minX = 46, maxX = 130, minZ = -110, maxZ = -6 },
	{ id = "gallery", name = "The Achievement Gallery", minX = -46, maxX = 46, minZ = 24, maxZ = 94 },
	{ id = "terrace", name = "The Hall of Fame", minX = -46, maxX = 46, minZ = 94, maxZ = 110 },
	{ id = "entrance", name = "The Entrance Hall", minX = -46, maxX = 46, minZ = -110, maxZ = -52 },
} :: { Zone }

-- Which part of the hall a point (from the origin) is in: "dance" on the floor itself.
function Gala.zoneAt(p: Vector3): string
	if Gala.onFloor(p) then
		return "dance"
	end
	for _, z in Gala.Zones do
		if p.X >= z.minX and p.X <= z.maxX and p.Z >= z.minZ and p.Z <= z.maxZ then
			return z.id
		end
	end
	return "hall"
end

function Gala.zoneName(id: string): string
	if id == "dance" then
		return "The Dance Floor"
	end
	for _, z in Gala.Zones do
		if z.id == id then
			return z.name
		end
	end
	return "The Grand Ballroom"
end

local function flat(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
Gala.flat = flat

-- On the dance floor (standing on it, not flying over it).
function Gala.onFloor(p: Vector3): boolean
	return flat(p, Gala.DANCE.centre) <= Gala.DANCE.radius - 0.5 and p.Y > -4 and p.Y < 10
end

-- In the Daily Arena's ring.
function Gala.inArena(p: Vector3): boolean
	return flat(p, Gala.ARENA.centre) <= Gala.ARENA.radius and p.Y > -4 and p.Y < 12
end

-- On the catwalk's end mark (posing).
function Gala.atFinish(p: Vector3): boolean
	return flat(p, Gala.RUNWAY.finish) <= 4.5 and p.Y > Gala.RUNWAY.top - 2 and p.Y < Gala.RUNWAY.top + 9
end

---------------------------------------------------------------------------------------------------
-- The day (UTC), and the Arena's challenge for it
---------------------------------------------------------------------------------------------------
function Gala.day(t: number?): number
	return math.floor((t or os.time()) / 86400)
end

export type Challenge = { id: string, name: string, line: string, how: string, glyph: string, colour: Color3 }
Gala.Challenges = {
	{ id = "spotlight", name = "Spotlight Chase", glyph = "🔦", colour = rgb(255, 226, 150), line = "A spotlight drifts across the Arena floor.", how = "Keep inside the light: two points every second you're in it." },
	{ id = "coins", name = "The Gilded Rush", glyph = "💰", colour = rgb(255, 204, 90), line = "Gold coins scattered across the floor, and more as each one goes.", how = "Run through the coins: a point each, first come first served." },
	{ id = "dais", name = "Hold the Dais", glyph = "👑", colour = rgb(240, 120, 150), line = "The golden dais in the middle of the ring.", how = "Stand on the dais alone: a point every second. Share it and nobody scores." },
} :: { Challenge }
Gala.challengeById = {} :: { [string]: Challenge }
for _, c in Gala.Challenges do
	Gala.challengeById[c.id] = c
end

function Gala.challengeFor(day: number): Challenge
	return Gala.Challenges[(day % #Gala.Challenges) + 1]
end

---------------------------------------------------------------------------------------------------
-- The Runway's themes (the show's, chosen as it opens)
---------------------------------------------------------------------------------------------------
export type Theme = { id: string, name: string, line: string, colour: Color3 }
Gala.Themes = {
	{ id = "midnight", name = "Midnight Gala", line = "Dark, dramatic, dressed for the last waltz.", colour = rgb(120, 140, 255) },
	{ id = "riviera", name = "Riviera Summer", line = "Sun on the water, linen and gold.", colour = rgb(110, 220, 236) },
	{ id = "oldMoney", name = "Old Money", line = "Quiet, perfect, inherited.", colour = rgb(214, 190, 140) },
	{ id = "neon", name = "Neon Couture", line = "Loud colour after dark.", colour = rgb(255, 90, 200) },
	{ id = "gold", name = "All That Glitters", line = "As much gold as you dare.", colour = rgb(255, 204, 90) },
	{ id = "mono", name = "Black and White", line = "Two colours. No excuses.", colour = rgb(236, 236, 236) },
	{ id = "garden", name = "Garden Party", line = "Florals, pastels, a long lunch.", colour = rgb(150, 220, 150) },
	{ id = "winter", name = "Winter Ball", line = "Frost, velvet and silver.", colour = rgb(190, 220, 255) },
	{ id = "street", name = "Street Luxe", line = "The city, dressed up.", colour = rgb(255, 150, 90) },
	{ id = "masquerade", name = "Masquerade", line = "Mystery first, the outfit second.", colour = rgb(200, 90, 120) },
	{ id = "red", name = "Red Carpet", line = "The cameras are waiting.", colour = rgb(230, 60, 70) },
	{ id = "yacht", name = "Yacht Week", line = "Deck shoes optional. Style is not.", colour = rgb(90, 160, 230) },
} :: { Theme }

---------------------------------------------------------------------------------------------------
-- The dance moves (Roblox's own R15 emotes, which every avatar has) and the jukebox
---------------------------------------------------------------------------------------------------
export type Move = { id: string, name: string, glyph: string, anim: string, loop: boolean }
Gala.Moves = {
	{ id = "groove", name = "Groove", glyph = "🕺", anim = "dance", loop = true },
	{ id = "shuffle", name = "Shuffle", glyph = "💃", anim = "dance2", loop = true },
	{ id = "swing", name = "Swing", glyph = "🎶", anim = "dance3", loop = true },
	{ id = "cheer", name = "Cheer", glyph = "🙌", anim = "cheer", loop = false },
	{ id = "wave", name = "Wave", glyph = "👋", anim = "wave", loop = false },
	{ id = "point", name = "Point", glyph = "👉", anim = "point", loop = false },
	{ id = "laugh", name = "Laugh", glyph = "😄", anim = "laugh", loop = false },
} :: { Move }
Gala.moveById = {} :: { [string]: Move }
for _, m in Gala.Moves do
	Gala.moveById[m.id] = m
end

-- The jukebox's records: the house's dance tracks (Config.Assets.AbuseMusic.abuse, by number),
-- with the names the DJ gives them.
Gala.TRACK_NAMES = { "Feeling", "Skyhook", "Stadium Rave", "Funky Disco Beats", "Digital Dawn", "Bang On" }

---------------------------------------------------------------------------------------------------
-- Luxury Trivia: the questions (the first answer is the right one; the server shuffles them)
---------------------------------------------------------------------------------------------------
export type Question = { q: string, a: { string } }
Gala.Questions = {
	{ q = "Which city is home to the Louvre?", a = { "Paris", "London", "Rome", "Vienna" } },
	{ q = "Champagne comes from a region of which country?", a = { "France", "Italy", "Spain", "Portugal" } },
	{ q = "Which gemstone is red?", a = { "Ruby", "Sapphire", "Emerald", "Topaz" } },
	{ q = "How many carats is pure gold?", a = { "24", "18", "22", "14" } },
	{ q = "Which is the hardest natural mineral?", a = { "Diamond", "Ruby", "Quartz", "Emerald" } },
	{ q = "How many keys does a standard piano have?", a = { "88", "76", "92", "64" } },
	{ q = "What colour is an emerald?", a = { "Green", "Blue", "Red", "Violet" } },
	{ q = "Which is the largest ocean?", a = { "The Pacific", "The Atlantic", "The Indian", "The Arctic" } },
	{ q = "Which planet is called the Red Planet?", a = { "Mars", "Venus", "Jupiter", "Mercury" } },
	{ q = "True caviar is the roe of which fish?", a = { "Sturgeon", "Salmon", "Tuna", "Cod" } },
	{ q = "Geneva is in which country?", a = { "Switzerland", "France", "Austria", "Belgium" } },
	{ q = "What does a sommelier look after?", a = { "Wine", "Cheese", "Bread", "Perfume" } },
	{ q = "How many sides does a hexagon have?", a = { "Six", "Five", "Seven", "Eight" } },
	{ q = "Who painted the Mona Lisa?", a = { "Leonardo da Vinci", "Michelangelo", "Raphael", "Rembrandt" } },
	{ q = "Which city is famous for its gondolas?", a = { "Venice", "Florence", "Milan", "Naples" } },
	{ q = "In which city is the Colosseum?", a = { "Rome", "Athens", "Naples", "Madrid" } },
	{ q = "How many beats are in a bar of a waltz?", a = { "Three", "Two", "Four", "Six" } },
	{ q = "What was the largest gem-quality rough diamond ever found?", a = { "The Cullinan", "The Hope", "The Koh-i-Noor", "The Regent" } },
	{ q = "A tiara is worn on the...", a = { "Head", "Wrist", "Ankle", "Neck" } },
	{ q = "A cravat is worn around the...", a = { "Neck", "Wrist", "Waist", "Ankle" } },
	{ q = "What is a monocle?", a = { "A single eyeglass lens", "A small top hat", "A walking cane", "A cufflink" } },
	{ q = "Who composed The Four Seasons?", a = { "Vivaldi", "Mozart", "Bach", "Chopin" } },
	{ q = "Which composer wrote his Ninth Symphony while almost completely deaf?", a = { "Beethoven", "Mozart", "Haydn", "Handel" } },
	{ q = "Which ballet has a Sugar Plum Fairy?", a = { "The Nutcracker", "Swan Lake", "Giselle", "Coppélia" } },
	{ q = "In which year did the Eiffel Tower open?", a = { "1889", "1789", "1925", "1850" } },
	{ q = "Which is the smallest country in the world?", a = { "Vatican City", "Monaco", "San Marino", "Liechtenstein" } },
	{ q = "Monte Carlo is in which country?", a = { "Monaco", "France", "Italy", "Spain" } },
	{ q = "Which sea is Monaco on?", a = { "The Mediterranean", "The Baltic", "The North Sea", "The Black Sea" } },
	{ q = "The famous race at Le Mans lasts how long?", a = { "24 hours", "12 hours", "6 hours", "48 hours" } },
	{ q = "What is the fastest land animal?", a = { "The cheetah", "The lion", "The horse", "The greyhound" } },
	{ q = "Most of the world's silk is made by...", a = { "Silkworms", "Spiders", "Bees", "Sheep" } },
	{ q = "Linen is woven from which plant?", a = { "Flax", "Cotton", "Bamboo", "Hemp" } },
	{ q = "Cashmere comes from which animal?", a = { "Goats", "Sheep", "Rabbits", "Alpacas" } },
	{ q = "Which creature makes pearls?", a = { "Oysters", "Crabs", "Starfish", "Jellyfish" } },
	{ q = "The traditional gift for a 25th wedding anniversary is...", a = { "Silver", "Gold", "Pearl", "Ruby" } },
	{ q = "The traditional gift for a 50th wedding anniversary is...", a = { "Gold", "Silver", "Diamond", "Ruby" } },
	{ q = "How many minutes are in a day?", a = { "1,440", "1,240", "1,640", "2,400" } },
	{ q = "What does RSVP ask you to do?", a = { "Reply to the invitation", "Arrive early", "Dress formally", "Bring a gift" } },
	{ q = "\"Black tie\" on an invitation means...", a = { "Formal evening dress", "Wear only black", "Come as you are", "Fancy dress" } },
	{ q = "Prosecco is a sparkling wine from which country?", a = { "Italy", "France", "Spain", "Germany" } },
	{ q = "Sushi comes from which country?", a = { "Japan", "China", "Korea", "Thailand" } },
	{ q = "A truffle is a kind of...", a = { "Fungus", "Berry", "Nut", "Root" } },
	{ q = "What is the main ingredient of guacamole?", a = { "Avocado", "Tomato", "Lime", "Pea" } },
	{ q = "Which planet has the most famous rings?", a = { "Saturn", "Jupiter", "Mars", "Neptune" } },
	{ q = "How many pieces does each player start with in chess?", a = { "16", "12", "14", "18" } },
	{ q = "Which chess piece moves only diagonally?", a = { "The bishop", "The rook", "The knight", "The king" } },
	{ q = "How many squares are on a chessboard?", a = { "64", "32", "81", "100" } },
	{ q = "Which city joins Paris, London and New York as one of fashion's four great capitals?", a = { "Milan", "Berlin", "Madrid", "Vienna" } },
	{ q = "Which famous blue diamond is kept at the Smithsonian in Washington?", a = { "The Hope Diamond", "The Cullinan", "The Koh-i-Noor", "The Orlov" } },
	{ q = "Which is the largest planet in our solar system?", a = { "Jupiter", "Saturn", "Neptune", "Earth" } },
	{ q = "How many strings does a violin have?", a = { "Four", "Five", "Six", "Three" } },
	{ q = "The Burj Khalifa stands in which city?", a = { "Dubai", "Abu Dhabi", "Doha", "Riyadh" } },
	{ q = "On a yacht, the left side facing forward is called...", a = { "Port", "Starboard", "Stern", "Bow" } },
	{ q = "The front of a ship is called the...", a = { "Bow", "Stern", "Keel", "Mast" } },
	{ q = "Which is the largest island in the Mediterranean?", a = { "Sicily", "Sardinia", "Cyprus", "Crete" } },
	{ q = "Which country is shaped like a boot?", a = { "Italy", "Greece", "Portugal", "Chile" } },
	{ q = "Mix blue and yellow paint and you get...", a = { "Green", "Purple", "Orange", "Brown" } },
	{ q = "Bronze is mostly which metal?", a = { "Copper", "Iron", "Silver", "Zinc" } },
	{ q = "Sterling silver is how much silver?", a = { "92.5%", "75%", "85%", "99.9%" } },
	{ q = "Something handed down in a family for generations is an...", a = { "Heirloom", "Heritage", "Archive", "Antique" } },
	{ q = "A dinner jacket is another name for a...", a = { "Tuxedo", "Tailcoat", "Blazer", "Frock coat" } },
	{ q = "A jeweller's loupe is used to...", a = { "Look closely at small things", "Weigh gold", "Cut gems", "Polish silver" } },
	{ q = "Which gem is fossilised tree resin?", a = { "Amber", "Jet", "Opal", "Jade" } },
	{ q = "Haute couture means...", a = { "Made-to-measure high fashion", "Ready-to-wear clothes", "A silk fabric", "A hairstyle" } },
	{ q = "What is the capital of Japan?", a = { "Tokyo", "Kyoto", "Osaka", "Nagoya" } },
	{ q = "Which bird can fly backwards?", a = { "The hummingbird", "The swallow", "The eagle", "The parrot" } },
	{ q = "How many days are in a leap year?", a = { "366", "365", "364", "367" } },
	{ q = "How many continents are there?", a = { "Seven", "Five", "Six", "Eight" } },
	{ q = "In the Maison, Steal a Luxe begins in which room?", a = { "The Luxe Lounge", "The Library", "The Salon", "The Vault" } },
	{ q = "In the Maison, what waits at the very bottom of the Basement?", a = { "The Treasury", "The Wine Cellar", "The Boiler", "The Vault" } },
	{ q = "In the Maison, where does the jet to Luxury Island leave from?", a = { "The Jet Lounge on the Terrace", "The Foyer", "The Street", "The Library" } },
	{ q = "In the Maison, what do you need to visit Luxury Island?", a = { "The Island Key", "A Black Card", "A boarding pass", "A yacht" } },
} :: { Question }

---------------------------------------------------------------------------------------------------
-- The timings (seconds), and the rewards (Gilt unless it says otherwise; Config can change them)
---------------------------------------------------------------------------------------------------
Gala.TRIVIA_QUESTIONS = 7
Gala.TRIVIA_LOBBY = 15
Gala.TRIVIA_ANSWER = 12
Gala.TRIVIA_REVEAL = 4
Gala.TRIVIA_RESULTS = 9

Gala.RUNWAY_SIGNUP = 40
Gala.RUNWAY_EXTRA = 30 -- once, while there's only one model
Gala.RUNWAY_WALK = 15
Gala.RUNWAY_VOTE = 20
Gala.RUNWAY_RESULTS = 10
Gala.RUNWAY_MODELS = 6

Gala.ARENA_COUNTDOWN = 10
Gala.ARENA_PLAY = 45
Gala.ARENA_RESULTS = 9
Gala.ARENA_PLAYERS = 12
Gala.ARENA_COINS = 14

Gala.TRACK_SECONDS = 150 -- each record plays this long, then the most-voted goes on

Gala.REWARDS = {
	-- (Low on the Gilt ladder, as the owner set it: the Grand Ballroom is for fun, its Gilt a
	-- little thank-you. Sorting and the Grand Prix pay more; the attractions far more.)
	dailyGilt = 1200, -- all the Grand Ballroom's Gilt a guest can earn in a day
	danceMinute = 4, -- a minute on the dance floor
	danceMinutes = 10, -- minutes a day that pay
	triviaCorrect = 6, -- each right answer
	triviaWin = 90,
	runwayWalk = 12,
	runwayWin = 100,
	runwayVote = 4,
	arenaTakePart = 12,
	arenaPoint = 1,
	arenaPoints = 40, -- most points that pay in one round
	arenaWin = 90,
	photoSet = 10, -- the first pose at each set, every day
}

-- A trivia answer's score: right answers only, more for the quicker.
function Gala.triviaScore(correct: boolean, left: number): number
	if not correct then
		return 0
	end
	return 100 + math.floor(50 * math.clamp(left / Gala.TRIVIA_ANSWER, 0, 1))
end

-- The spotlight's place at `t` seconds into a round (a slow figure of eight inside the ring).
function Gala.spotlightAt(t: number): Vector3
	local c = Gala.ARENA.centre
	local r = Gala.ARENA.radius * 0.62
	return c + v3(math.sin(t * 0.42) * r, 0, math.sin(t * 0.84) * r * 0.7)
end
Gala.SPOT_RADIUS = 7

function Gala.commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

---------------------------------------------------------------------------------------------------
-- The Hall of Fame's boards
---------------------------------------------------------------------------------------------------
export type Board = { id: string, name: string, line: string, glyph: string, colour: Color3 }
Gala.Boards = {
	{ id = "fortune", name = "The Wealthiest", line = "Fortune earned", glyph = "👑", colour = rgb(255, 204, 90) },
	{ id = "gilt", name = "Gilt in Hand", line = "Gilt held", glyph = "💰", colour = rgb(240, 196, 90) },
	{ id = "gems", name = "The Gem Keepers", line = "Gems held", glyph = "💎", colour = rgb(130, 200, 255) },
	{ id = "brainrots", name = "The Brainrot Squad", line = "Brainrots held", glyph = "🐈", colour = rgb(240, 120, 150) },
	{ id = "cosmetics", name = "The Best Dressed", line = "Wardrobe pieces owned", glyph = "👗", colour = rgb(200, 150, 255) },
	{ id = "items", name = "The Collectors", line = "Curios held", glyph = "🏺", colour = rgb(150, 220, 170) },
} :: { Board }

return Gala
