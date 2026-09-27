--!strict
-- Settings (Appendix F). The first option is the default unless `default` says otherwise.
-- A setting can make the table harder for yourself, never easier than the room allows.

local Settings = {}

export type Definition = {
	key: string,
	group: string,
	label: string,
	options: { string }?, -- choice settings
	range: { number }?, -- {min, max} for level settings
	default: any,
	note: string?,
	wired: boolean, -- true when Delivery 1 actually applies it
}

local function choice(key: string, group: string, label: string, options: { string }, wired: boolean, note: string?): Definition
	return { key = key, group = group, label = label, options = options, default = options[1], wired = wired, note = note }
end

local function level(key: string, group: string, label: string, default: number, wired: boolean): Definition
	return { key = key, group = group, label = label, range = { 0, 100 }, default = default, wired = wired }
end

Settings.Groups = { "The room", "The table", "The guide", "The Club", "Sound" }

Settings.Definitions = {
	-- The room
	choice("houseStyle", "The room", "House style", { "Luxury Black", "Luxury Gold", "Emerald Club", "Bordeaux", "Platinum", "Ivory Suite" }, true),
	choice("lettering", "The room", "Lettering", { "Editorial", "Book", "Modern", "Ledger" }, true),
	choice("textSize", "The room", "Text size", { "Normal", "Large", "Largest", "Small" }, true),
	choice("roundNumbers", "The room", "Round numbers", { "IV", "4", "Four" }, true),
	choice("atmosphere", "The room", "Atmosphere", { "Full", "Light", "Off" }, true, "dust in the lamplight, the city beyond the glass, weather density"),
	choice("movement", "The room", "Movement", { "Full", "Calm", "Still" }, true),
	choice("glow", "The room", "Glow and sparks", { "Full", "Subtle", "Off" }, true),
	-- The table
	choice("caseStyle", "The table", "Case style", { "Trays", "Boxes", "Plates" }, false),
	choice("pieceSize", "The table", "Piece size", { "Normal", "Large", "Largest", "Small" }, true),
	choice("wrongCase", "The table", "A wrong case", { "Costs the streak", "Costs points too" }, true, "four rooms only"),
	choice("pieceNames", "The table", "Piece names", { "On pick-up", "Always on", "Never" }, true),
	choice("tapToSort", "The table", "Tap to sort", { "On", "Off" }, true, "dragging always works"),
	choice("vibration", "The table", "Vibration", { "On", "Off" }, true),
	-- The guide
	choice("showTheWay", "The guide", "Show the way", { "Always", "After a moment", "Never" }, true, "four rooms only"),
	choice("trail", "The guide", "Trail", { "Sparkles", "Ribbon", "Comet", "Runway", "Case only" }, true),
	choice("trailColour", "The guide", "Trail colour", { "House", "Ice", "Rose", "Mint", "Violet" }, true),
	choice("trailPace", "The guide", "Trail pace", { "Normal", "Lively", "Calm" }, true),
	-- The Club
	choice("showMark", "The Club", "Show my Mark on my nameplate", { "On", "Off" }, false),
	choice("showCrest", "The Club", "Show my Circle's crest", { "On", "Off" }, false),
	choice("parcelsTo", "The Club", "Ballroom parcels go to", { "Random", "Rivals", "Leader", "Nearly out" }, false),
	choice("rivalUpdates", "The Club", "Rival updates in the house", { "On", "Off" }, false),
	choice("offerStandIn", "The Club", "Offer a Stand-in while I wait", { "Yes", "No" }, false),
	-- Sound
	choice("music", "Sound", "Music", { "On", "Off" }, true),
	level("musicLevel", "Sound", "Music volume", 65, true),
	choice("effects", "Sound", "Effects", { "On", "Off" }, true),
	level("effectsLevel", "Sound", "Effects volume", 85, true),
	choice("ambience", "Sound", "Ambience", { "On", "Off" }, true),
	level("ambienceLevel", "Sound", "Ambience volume", 70, true),
	choice("chime", "Sound", "Sorting chime", { "Bells", "Marimba", "Crystal", "Soft" }, true),
} :: { Definition }

Settings.byKey = {} :: { [string]: Definition }
for _, d in Settings.Definitions do
	Settings.byKey[d.key] = d
end

function Settings.defaults(): { [string]: any }
	local out = {}
	for _, d in Settings.Definitions do
		out[d.key] = d.default
	end
	return out
end

function Settings.validate(key: string, value: any): boolean
	local d = Settings.byKey[key]
	if d == nil then
		return false
	end
	if d.options then
		if type(value) ~= "string" then
			return false
		end
		return table.find(d.options, value) ~= nil
	end
	if d.range then
		if type(value) ~= "number" then
			return false
		end
		return value >= d.range[1] and value <= d.range[2] and value == math.floor(value)
	end
	return false
end

-- Fills gaps and drops unknown or invalid values.
function Settings.sanitize(stored: { [string]: any }?): { [string]: any }
	local out = Settings.defaults()
	if type(stored) == "table" then
		for key, value in stored do
			if Settings.validate(key, value) then
				out[key] = value
			end
		end
	end
	return out
end

-- The text-size setting as a scale for interface type.
function Settings.textScale(size: string): number
	if size == "Small" then
		return 0.9
	elseif size == "Large" then
		return 1.15
	elseif size == "Largest" then
		return 1.3
	end
	return 1
end

function Settings.pieceScale(size: string): number
	if size == "Small" then
		return 0.85
	elseif size == "Large" then
		return 1.15
	elseif size == "Largest" then
		return 1.3
	end
	return 1
end

return Settings
