--!strict
-- Every line the house speaks (§5). Short, specific, dry, warm. No exclamation marks.
-- Never "game", "level", "loot", "match", "battle".

local Voice = {}

Voice.Concierge = {
	speaker = "THE CONCIERGE",
	firstVisit = "Good evening. The tables are set.",
	returning = "Good to see you again, {name}.",
	rare = "Now that one I'd keep an eye on.",
	mythic = "Nobody touch anything.",
	midnightUnlocked = "The last room is open to you. Mind the dark.",
	midnightLocked = "The Midnight Room opens once you've reached round IV in Obsidian.",
	tonightLaid = "Tonight's table is laid.",
	noticed = "The house has noticed.",
	waiting = "A table is being laid for you.",
	libraryWin = "Well played. They'll want another.",
	libraryLoss = "Close. The house saw every piece of it.",
	ballroomOpens = "Twenty tables. One lamp at the end of the night.",
	lastLamp = "The last lamp in the house is yours.",
	wall = "Your name goes on the wall.",
	thisWay = "This way.",
	arrived = "The Salon. Any table you like.",
	arrivedIn = {
		salon = "The Salon. Any table you like.",
		velvet = "The Velvet Room. The clock waits for your first piece.",
		obsidian = "The Obsidian Room. Every case is open from the first deal.",
		midnight = "The Midnight Room. Mind the dark.",
	},
	whichRoom = "Which room this evening?",
	closedRoom = "Not tonight. The Salon is open.",
	lost = "The Salon is through there, if you'd like me to walk you.",
	goodNight = "Good night.",
	choices = {
		takeMe = "Take me to a room",
		how = "How does this work",
		bye = "Good night",
	},
}

Voice.Doorman = {
	speaker = "THE DOORMAN",
	evening = "Evening.",
}

Voice.Archivist = { speaker = "THE ARCHIVIST", kept = "Everything you've found is kept here." }
Voice.Tailor = { speaker = "THE TAILOR", time = "Take your time. It changes at midnight." }

Voice.HowToPlay = {
	"Pick one up",
	"Put it where it belongs",
	"The light will show you",
	"Three in a row pays",
	"Then pick your room",
}

Voice.Table = {
	sit = "Sit",
	leave = "Leave",
	nextRound = "Next round",
	bank = "Bank the run",
	straightToTable = "Straight to the table",
	clockRanOut = "The clock ran out in round {round}.",
}

Voice.Foyer = {
	tonight = "TONIGHT",
	wall = "THE WALL OF NAMES",
	foundingTerm = "The Founding Term",
	livre = "LIVRE D'OR",
	stair = "THE CLUB FLOOR",
	boutique = "THE BOUTIQUE",
	closed = "Closed this evening.",
}

function Voice.fill(line: string, values: { [string]: string }): string
	return (string.gsub(line, "{(%w+)}", function(key)
		return values[key] or ("{" .. key .. "}")
	end))
end

-- Roman numerals for round cards.
function Voice.roman(n: number): string
	local numerals: { { any } } = { { 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" } }
	local out = ""
	local value = math.max(1, math.floor(n))
	for _, pair in numerals do
		while value >= pair[1] do
			out ..= pair[2]
			value -= pair[1]
		end
	end
	return out
end

local words = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten" }

function Voice.roundLabel(n: number, style: string): string
	if style == "4" then
		return tostring(n)
	elseif style == "Four" then
		return words[n] or tostring(n)
	end
	return Voice.roman(n)
end

return Voice
