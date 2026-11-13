--!strict
-- The Flex Studio (Build 81), in the middle of the Grand Ballroom's nave: the house's take on the
-- "flex reel", the short vertical video where someone shows off what they have. A guest stands on
-- the mark, picks something they really own (a brainrot, a rare curio, a Wardrobe piece, their
-- Fortune, the Gold Key), a set (a private jet, a penthouse at night, the supercar garage, a yacht
-- deck at sunset) and a caption, and their screen shoots a seven-second reel round them. It goes up
-- on the Flex Wall, where everyone in the hall can see it and like it: one like each, never your
-- own. Captions are the house's own lines, never typed, so nothing needs filtering.
--
-- Shared by the builder, the server (which checks every item is really the guest's, keeps the
-- wall and counts every like) and the screens. Its Gilt is small and capped, on the lowest rungs of
-- the house's ladder: the Grand Ballroom is for fun.

local Flex = {}

local v3 = Vector3.new
local rgb = Color3.fromRGB

-- Where it stands in the Grand Ballroom (from the hall's origin): the platform, the mark where a
-- guest stands (facing the camera, down the nave), the camera's tripod, the Flex Wall behind.
Flex.STUDIO = { centre = v3(0, 0, 58), minX = -11, maxX = 11, minZ = 49, maxZ = 67, top = 0.6 }
Flex.MARK = CFrame.lookAt(v3(0, 0.6, 60), v3(0, 0.6, 0))
Flex.TRIPOD = v3(0, 0, 51)
Flex.WALL = v3(0, 0, 68.5) -- the foot of the Flex Wall, facing down the nave
Flex.REACH = 9 -- how near the mark a guest must stand to shoot

Flex.REEL_SECONDS = 7 -- the reel itself
Flex.COOLDOWN = 20 -- seconds between one guest's reels
Flex.WALL_SIZE = 24 -- reels the wall keeps (the newest first)

-- Gilt (low on the house's ladder; within the Grand Ballroom's day's cap).
Flex.REWARDS = {
	firstReel = 10, -- the first reel of the day
	like = 3, -- each like a reel of yours is given, by another guest
	likesPaid = 20, -- likes a day that pay
}

export type Set = { id: string, name: string, line: string, sky: Color3, accent: Color3, glyph: string }
Flex.Sets = {
	{ id = "jet", name = "The Private Jet", line = "Cream leather, a window full of clouds.", sky = rgb(150, 196, 240), accent = rgb(236, 220, 190), glyph = "✈️" },
	{ id = "penthouse", name = "The Penthouse at Night", line = "Glass, the skyline, a city that's yours.", sky = rgb(16, 20, 44), accent = rgb(255, 196, 110), glyph = "🌃" },
	{ id = "garage", name = "The Supercar Garage", line = "Polished concrete, strips of neon, the car.", sky = rgb(14, 14, 18), accent = rgb(255, 70, 170), glyph = "🏎️" },
	{ id = "yacht", name = "The Yacht at Sunset", line = "Teak decks, chrome rails, the sun going down.", sky = rgb(255, 140, 90), accent = rgb(250, 230, 200), glyph = "🛥️" },
} :: { Set }
Flex.setById = {} :: { [string]: Set }
for _, s in Flex.Sets do
	Flex.setById[s.id] = s
end

-- The captions, the house's own (never typed): {item} is what's being flexed.
export type Caption = { id: string, text: string }
Flex.Captions = {
	{ id = "woke", text = "I woke up with {item}." },
	{ id = "pov", text = "POV: you walk into the Maison with {item}." },
	{ id = "day", text = "A day in my life: {item} edition." },
	{ id = "rate", text = "Rate my {item}, one to ten." },
	{ id = "quiet", text = "Quiet luxury? Not today. {item}." },
	{ id = "post", text = "{item}. That's the post." },
} :: { Caption }
Flex.captionById = {} :: { [string]: Caption }
for _, c in Flex.Captions do
	Flex.captionById[c.id] = c
end

-- A caption with the item in it.
function Flex.caption(id: string, item: string): string?
	local c = Flex.captionById[id]
	if not c then
		return nil
	end
	return (string.gsub(c.text, "{item}", function()
		return item
	end))
end

-- What can be flexed, by kind: where it comes from, in words (for the picker's headings).
Flex.KindNames = {
	brainrot = "Your brainrots",
	curio = "Rare curios",
	wardrobe = "Your Wardrobe",
	fortune = "Your Fortune",
	key = "Keys and cards",
} :: { [string]: string }
Flex.KIND_ORDER = { "fortune", "key", "brainrot", "curio", "wardrobe" }

-- Whether a point (from the hall's origin) is near enough the mark to shoot.
function Flex.onMark(p: Vector3): boolean
	local m = Flex.MARK.Position
	return Vector3.new(p.X - m.X, 0, p.Z - m.Z).Magnitude <= Flex.REACH
end

return Flex
