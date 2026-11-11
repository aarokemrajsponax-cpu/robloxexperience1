--!strict
-- The Maison Directory: every game in the house on one card each (UI/DirectoryPanel draws them),
-- and the short "how it works" a guest is shown the first time they go into one (UI/FirstVisit).
-- Every line here is the house's real rule (server/Attractions and its games, server/Auction), and
-- each figure in braces is filled from the server's own numbers when the card is drawn, never
-- written down twice. Nothing here opens, prices or pays anything: the server does all of that.

local Config = require(script.Parent.Config)
local Fortune = require(script.Parent.Fortune)
local GalaRules = require(script.Parent.Gala)

local Directory = {}

export type Entry = {
	id: string,
	attraction: string?, -- its attraction (shared/Attractions), or nil (the Grand Auction, in the Library)
	place: string, -- where Travel takes a guest and the Concierge's arrows lead: the room its way in is in
	room: string, -- that room, as the house calls it
	name: string,
	tagline: string,
	short: string, -- the tagline in a few words, for a small card
	piece: string, -- the treasure drawn on its card (shared/PieceArt)
	glyph: string,
	accent: Color3,
	deep: Color3, -- the colour its card's picture falls away to
	mood: string, -- the light of its card's closer look (UI/Theme moods)
	steps: { string }, -- how it plays, in three lines
	rewards: string, -- what it pays
	unlock: string?, -- how a guest opens it, where it's closed to them (one sentence, for a card)
	waysLead: string?, -- what opens it, plainly (the line before its ways)
	ways: { string }?, -- each way to open it, numbered on its closer look and in How to play
	waysAfter: string?, -- what comes after it's open
	intro: { string }, -- the first time inside: three short lines
}

local rgb = Color3.fromRGB

Directory.List = {
	{
		id = "luxe",
		attraction = "luxe",
		place = "velvet",
		room = "the Luxe Lounge",
		name = "Steal a Luxe",
		tagline = "Slip into a great residence, carry out what you can, and bank it at the getaway car.",
		short = "Carry out a fortune and bank it at the car.",
		piece = "looseDiamond",
		glyph = "💎",
		accent = rgb(232, 74, 104),
		deep = rgb(46, 10, 20),
		mood = "ruby",
		steps = {
			"Walk round the residence and pick up the treasures you can carry. The fuller your bag, the slower you walk.",
			"Keep out of the guards' sight. If one catches you, you lose what's in your bag.",
			"Carry it out to the getaway car to bank it: banked loot is yours for good. Then go back for more.",
		},
		rewards = "Every haul grows your Estate, and a fifth of it comes to your purse as Gilt. A haul of {inviteHaul} or more earns an invitation to the Executive Suite.",
		intro = {
			"Pick up what you can carry. The fuller the bag, the slower you go.",
			"Keep out of the guards' sight. Caught, the bag is lost, but what's banked is safe.",
			"Bank it at the getaway car. Upgrades and Stride are at the Luxe Lounge.",
		},
	},
	{
		id = "basement",
		attraction = "basement",
		place = "obsidian",
		room = "the Basement Stair",
		name = "The Maison Basement",
		tagline = "Sixteen stages under the house, chamber by chamber, down to the Treasury.",
		short = "Sixteen stages down to the Treasury.",
		piece = "goldBar",
		glyph = "🏁",
		accent = rgb(244, 182, 66),
		deep = rgb(44, 26, 6),
		mood = "thanksgiving",
		steps = {
			"Jump, climb and dodge down sixteen stages, one after another.",
			"Step on each stage's checkpoint pad. If you fall, you go back to the last pad you reached.",
			"Each of the four chambers pays when you reach its way out, and the Treasury at the bottom pays the most.",
		},
		rewards = "A little Gilt at each new checkpoint, a purse to your Estate at the end of each chamber, the Treasury's Gems, and an invitation to the Executive Suite when you clear it.",
		intro = {
			"Stand on each checkpoint's pad. Fall, and you go back to the last one.",
			"Each chamber's way out pays its purse to your Estate. Leave by a lift any time and keep it.",
			"Stuck? A skip costs Gems, more on deeper stages, and a skipped run isn't timed.",
		},
	},
	{
		id = "executive",
		attraction = "executive",
		place = "midnight",
		room = "the Executive's Anteroom",
		name = "The Executive Suite",
		tagline = "By invitation only: past the security, through the code door, face to face with the Executive.",
		short = "Security, a code door, then the Executive.",
		piece = "keyCard",
		glyph = "🕴️",
		accent = rgb(124, 196, 255),
		deep = rgb(8, 20, 40),
		mood = "midnight",
		steps = {
			"Up the lift with your stun pistol: four terminals in the hallway each show one digit of the door's code. Keep out of the cameras' and guards' sight.",
			"Type the code at the door. Inside the Office: shoot the three generators, stun his four bodyguards, then stun the Executive.",
			"Beat him and the safe opens: take it, then the lift down.",
		},
		rewards = "Beat him and everyone in the Office is paid to their Estate, with Gems and his brainrot the first time. The safe pays once more.",
		unlock = "You need an invitation: finish the Maison Basement, carry {inviteHaul} of loot out of Steal a Luxe in one trip, or buy one for {invitePrice} Gilt.",
		waysLead = "You need an invitation to go up. Each of these gets you one:",
		ways = {
			"Finish the Maison Basement: reach the Treasury at the very bottom.",
			"In Steal a Luxe, carry loot worth {inviteHaul} or more to the getaway car in a single trip.",
			"Or buy one from the Quartermaster, in the Executive's Anteroom, for {invitePrice} Gilt.",
		},
		waysAfter = "Then take your free stun pistol from the Quartermaster and ride the lift up. Each trip up uses one invitation, and you can hold up to {most}.",
		intro = {
			"Cameras and guards raise the alert. Fill it, and security shows you out.",
			"Each terminal holds a digit of the door's code. Three wrong tries and the alert jumps.",
			"In the Office: the generators, his bodyguards, then the Executive himself.",
		},
	},
	{
		id = "gala",
		attraction = "gala",
		place = "ballroom",
		room = "the Ballroom",
		name = "The Grand Ballroom",
		tagline = "The dance floor, Luxury Trivia, the Runway, the Daily Arena and the Hall of Fame.",
		short = "Trivia, the Runway and the Daily Arena.",
		piece = "pearlNecklace",
		glyph = "💃",
		accent = rgb(255, 196, 120),
		deep = rgb(40, 22, 30),
		mood = "amethyst",
		steps = {
			"Through the great doors at the far end of the Ballroom.",
			"Play Luxury Trivia, walk the Runway's theme and vote, or join the Daily Arena.",
			"Dance to the jukebox, pose on the photo sets, and trade at the Exchange.",
		},
		rewards = "A little Gilt for all of it, up to {galaGilt} a day, and a place on the Hall of Fame's boards.",
		intro = {
			"Luxury Trivia, the Runway and the Daily Arena each have their own part of the hall.",
			"Vote for the jukebox's next track, dance on the floor, and pose at the three photo sets.",
			"The Exchange's stands are for trading: nothing moves until you both confirm.",
		},
	},
	{
		id = "auction",
		attraction = nil,
		place = "library",
		room = "the Library",
		name = "The Grand Auction",
		tagline = "The week's rare lots, bid for by guests in every server at once.",
		short = "Rare lots, bid for in every server.",
		piece = "objetEgg",
		glyph = "🔨",
		accent = rgb(110, 214, 160),
		deep = rgb(6, 32, 22),
		mood = "emerald",
		steps = {
			"See the week's lots at the rostrum in the Library.",
			"Bid in Gilt or Gems, at least the least next bid. It's held from your purse.",
			"Outbid? It comes straight back. The highest bid when the week closes wins.",
		},
		rewards = "Rare curios for your collection, delivered to you wherever you are.",
		intro = {
			"A bid is held from your purse while it stands. Outbid, it comes straight back.",
			"Every lot shows the least the next bid may be, and when it closes.",
			"The highest bid when the week closes wins, in any server.",
		},
	},
	{
		id = "island",
		attraction = "island",
		place = "terrace",
		room = "the Jet Lounge, on the Terrace",
		name = "Luxury Island",
		tagline = "The private jet to the house's own island: villas, a lagoon and the Sunset Lookout.",
		short = "The private jet, pearls and sunsets.",
		piece = "blueMoonPearl",
		glyph = "🏝️",
		accent = rgb(96, 214, 232),
		deep = rgb(4, 30, 40),
		mood = "sea",
		steps = {
			"Board the private jet in the Jet Lounge, on the Terrace.",
			"Bring up the day's five pearls from the lagoon, and toast the sunset at the Lookout.",
			"Choose your jet's livery and your villa's theme.",
		},
		rewards = "Gilt for each pearl and for the day's toast (more with friends), and Gems for all five pearls.",
		unlock = "You need the Island Key: reach the rank of {keyRank} ({keyRankAt} Fortune), then buy it at the Jet Lounge for {keyGilt} Gilt or {keyGems} Gems.",
		waysLead = "You need the Island Key, once. It's yours for good:",
		ways = {
			"Grow your Fortune to {keyRankAt}: that's the rank of {keyRank}.",
			"Then buy the Island Key at the Jet Lounge's desk, on the Terrace: {keyGilt} Gilt or {keyGems} Gems.",
		},
		waysAfter = "After that, the private jet in the Jet Lounge flies you there whenever you like.",
		intro = {
			"Five pearls lie on the lagoon's floor today. Go close to one to bring it up.",
			"The sunset toast at the Lookout pays once a day, and more for each friend who toasts with you.",
			"Your jet waits on the airstrip to fly you home.",
		},
	},
} :: { Entry }

Directory.byId = {} :: { [string]: Entry }
Directory.byAttraction = {} :: { [string]: Entry }
Directory.byPlace = {} :: { [string]: Entry }
for _, e in Directory.List do
	Directory.byId[e.id] = e
	Directory.byPlace[e.place] = e
	if e.attraction then
		Directory.byAttraction[e.attraction] = e
	end
end

-- The first-time cards for places that aren't attractions (the Vault: how a collection is kept).
Directory.Rooms = {
	vault = {
		name = "The Vault",
		glyph = "🏛️",
		lines = {
			"The console under the four domes keeps every curio you own.",
			"Set four under the domes, and arrange the rest by rarity, family, newest or starred.",
			"Choose who may look round: everyone, your friends, or only you.",
		},
	},
} :: { [string]: { name: string, glyph: string, lines: { string } } }

-- A line with its {figures} filled in (any figure not given is left out, words and all, never
-- shown as braces).
function Directory.fill(text: string, figures: { [string]: string }?): string
	local f = figures or {}
	local out = string.gsub(text, "{(%w+)}", function(k: string): string
		return f[k] or "\0"
	end)
	if string.find(out, "\0", 1, true) then
		-- (A sentence with a figure the house didn't give is dropped rather than shown half-said.)
		local kept = {}
		for sentence in string.gmatch(out .. " ", "(.-%.)%s") do
			if not string.find(sentence, "\0", 1, true) then
				table.insert(kept, sentence)
			end
		end
		out = table.concat(kept, " ")
	end
	return out
end

-- The figures the words quote: the server's own (a Directory answer's cards, where there is one),
-- else the house's settings (shared/Config), so a line is never shown with a figure missing.
local function formatted(v: any): string?
	return if type(v) == "number" then Fortune.format(v) else nil
end
function Directory.figures(cards: { [string]: any }?): { [string]: string }
	local a = (Config.data :: any).Attractions or {}
	local ex, isl = a.executive or {}, a.island or {}
	local rank = Fortune.Ranks[tonumber(isl.keyRank) or 6] or Fortune.Ranks[#Fortune.Ranks]
	local f: { [string]: string } = {
		inviteHaul = Fortune.format(tonumber(ex.inviteHaul) or 8000),
		invitePrice = Fortune.format(tonumber(ex.invitePrice) or 25000),
		galaGilt = Fortune.format(tonumber((a.gala or {}).dailyGilt) or tonumber((GalaRules.REWARDS :: any).dailyGilt) or 2500),
		keyRank = rank.name,
		keyRankAt = Fortune.format(rank.at),
		keyGilt = Fortune.format(tonumber(isl.keyGilt) or 25000),
		keyGems = tostring(math.floor(tonumber(isl.keyGems) or 250)),
		most = tostring(math.floor(tonumber(ex.maxInvites) or 5)),
	}
	local c: { [string]: any } = cards or {}
	local e, g, i = c.executive, c.gala, c.island
	if type(e) == "table" then
		f.inviteHaul = formatted(e.inviteHaul) or f.inviteHaul
		f.invitePrice = formatted(e.invitePrice) or f.invitePrice
		f.most = if type(e.most) == "number" then tostring(math.floor(e.most)) else f.most
	end
	if type(g) == "table" then
		f.galaGilt = formatted(g.galaGilt) or f.galaGilt
	end
	if type(i) == "table" then
		f.keyRank = if type(i.keyRank) == "string" then i.keyRank else f.keyRank
		f.keyRankAt = formatted(i.keyRankAt) or f.keyRankAt
		f.keyGilt = formatted(i.keyGilt) or f.keyGilt
		f.keyGems = if type(i.keyGems) == "number" then tostring(math.floor(i.keyGems)) else f.keyGems
	end
	return f
end

-- The guide cards the server keeps a note of (shown once, ever): the attractions and the rooms.
function Directory.isGuide(id: string): boolean
	return Directory.byAttraction[id] ~= nil or Directory.Rooms[id] ~= nil or id == "auction"
end

return Directory
