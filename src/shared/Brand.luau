--!strict
-- Brand constants (Appendix G). Colours, type, voice. Nothing here is tunable at runtime.

local Brand = {}

Brand.Name = "MAISON NOIR"
Brand.Tagline = "A table covered in expensive things, and somewhere to put all of it."
Brand.Credit = "development of AJKR"
Brand.Owner = "AJKR"

Brand.Colours = {
	nearBlack = Color3.fromHex("060709"),
	room = Color3.fromHex("0E1116"),
	roomDeep = Color3.fromHex("050608"),
	bone = Color3.fromHex("F2ECE2"),
	-- (Secondary lines, raised for contrast on the black glass: never grey on grey.)
	smoke = Color3.fromHex("C2C7CF"),
	dim = Color3.fromHex("9EA5AF"),
	gold = Color3.fromRGB(198, 160, 82),
	lightGold = Color3.fromRGB(236, 216, 166),
	deepGold = Color3.fromRGB(111, 87, 34),
	felt = Color3.fromRGB(16, 17, 20),
	burgundy = Color3.fromRGB(74, 22, 32),
	glass = Color3.fromRGB(24, 28, 34),
	-- The 2070 light: the gold edge as it catches, and the glow behind it.
	brightGold = Color3.fromRGB(255, 226, 150),
	glow = Color3.fromRGB(255, 196, 92),
}

-- The house type (Build 56, "2070"): Michroma, a wide engineered face in the line of the space-age
-- display letters, for titles and headings (set in capitals); and Gotham SSm, a sans drawn for
-- screens, for everything else, crisp and even at any size on any screen. Both are Roblox's own
-- built-in faces: nothing to fetch, nothing thin, never a stand-in while they load. Playfair
-- Display's italic stays for the house's few quoted lines; the Lettering setting can swap the
-- display face back to a serif.
local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"
local MICHROMA = "rbxasset://fonts/families/Michroma.json"
local PLAYFAIR = "rbxassetid://12187374765"
local BASKERVILLE = "rbxassetid://12187365769"

Brand.FontAssets = { display = MICHROMA, ui = GOTHAM, book = BASKERVILLE, serif = PLAYFAIR }

Brand.Fonts = {
	display = Font.new(MICHROMA, Enum.FontWeight.Regular),
	displayItalic = Font.new(PLAYFAIR, Enum.FontWeight.Regular, Enum.FontStyle.Italic),
	-- Scores, clocks and prices: full-height figures, heavy enough to read at a glance.
	figures = Font.new(GOTHAM, Enum.FontWeight.Bold),
	body = Font.new(GOTHAM, Enum.FontWeight.Medium),
	bodyMedium = Font.new(GOTHAM, Enum.FontWeight.Bold),
	bodyBold = Font.new(GOTHAM, Enum.FontWeight.Bold),
	heavy = Font.new(GOTHAM, Enum.FontWeight.Heavy),
	light = Font.new(GOTHAM, Enum.FontWeight.Regular),
	-- For the few things that are engraved (a signet, a coin).
	serif = Font.new(PLAYFAIR, Enum.FontWeight.Bold),
}

Brand.Lettering = {
	Future = Brand.Fonts.display,
	Editorial = Font.new(PLAYFAIR, Enum.FontWeight.Regular),
	Book = Font.new(BASKERVILLE, Enum.FontWeight.Regular),
	Ledger = Font.fromEnum(Enum.Font.Merriweather),
	-- (An earlier choice, still read from saves.)
	Modern = Font.new(GOTHAM, Enum.FontWeight.Bold),
} :: { [string]: Font }

-- House style swatches (Appendix F): accent on base.
Brand.HouseStyles = {
	["Luxury Black"] = { accent = Color3.fromHex("C6A052"), base = Color3.fromHex("0E1116"), light = false },
	["Luxury Gold"] = { accent = Color3.fromHex("D8AE5A"), base = Color3.fromHex("17110A"), light = false },
	["Emerald Club"] = { accent = Color3.fromHex("CAA862"), base = Color3.fromHex("0A1912"), light = false },
	["Bordeaux"] = { accent = Color3.fromHex("DEA488"), base = Color3.fromHex("1C0C13"), light = false },
	["Platinum"] = { accent = Color3.fromHex("AAC4DC"), base = Color3.fromHex("0D131D"), light = false },
	["Ivory Suite"] = { accent = Color3.fromHex("96742E"), base = Color3.fromHex("F1EADE"), light = true },
}

Brand.TrailColours = {
	House = Color3.fromRGB(236, 216, 166),
	Ice = Color3.fromHex("DBEEFB"),
	Rose = Color3.fromHex("F6C2C8"),
	Mint = Color3.fromHex("BDF0D6"),
	Violet = Color3.fromHex("D2C4F6"),
}

-- The year is read from the clock, never typed.
function Brand.year(): number
	local now = os.date("!*t")
	return now.year
end

function Brand.copyright(): string
	return `© {Brand.year()} {Brand.Owner}`
end

return Brand
