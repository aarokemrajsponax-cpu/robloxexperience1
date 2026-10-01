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
	smoke = Color3.fromHex("AAB0B9"),
	dim = Color3.fromHex("868D97"),
	gold = Color3.fromRGB(198, 160, 82),
	lightGold = Color3.fromRGB(236, 216, 166),
	deepGold = Color3.fromRGB(111, 87, 34),
	felt = Color3.fromRGB(16, 17, 20),
	burgundy = Color3.fromRGB(74, 22, 32),
	glass = Color3.fromRGB(24, 28, 34),
}

-- The house face is Gotham: clean, wide and quiet, set in letter-spaced capitals for labels and
-- light weights for large numbers. The Lettering setting can swap the display face.
local GOTHAM = Font.fromEnum(Enum.Font.Gotham).Family

Brand.Fonts = {
	display = Font.new(GOTHAM, Enum.FontWeight.Regular),
	body = Font.new(GOTHAM, Enum.FontWeight.Regular),
	bodyMedium = Font.new(GOTHAM, Enum.FontWeight.Medium),
	bodyBold = Font.new(GOTHAM, Enum.FontWeight.Bold),
	light = Font.new(GOTHAM, Enum.FontWeight.Light),
	-- An engraved serif, for the few things that are engraved (a signet, a coin).
	serif = Font.fromEnum(Enum.Font.Merriweather),
}

Brand.Lettering = {
	Editorial = Brand.Fonts.display,
	Book = Font.fromEnum(Enum.Font.Garamond),
	Modern = Font.new(GOTHAM, Enum.FontWeight.Light),
	Ledger = Font.fromEnum(Enum.Font.Merriweather),
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
