--!strict
-- The Foyer piano's keys, for the screen that plays them: each key's name, whether it's a black
-- key, and the computer keys that play it. Key 1 is the lowest (Config.Piano.lowest, C3).
--
-- Two rows of the keyboard, laid out like a piano: Z to / is C3 up to E4 (the black keys on S D G
-- H J L ;), and Q to ] is C4 up to G5 (the black keys on 2 3 5 6 7 9 0 =). The keys above G5
-- are played on the screen.

local Config = require(script.Parent.Config)

local PianoKeys = {}

local NAMES = { "C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B" }
local BLACK = { [1] = true, [3] = true, [6] = true, [8] = true, [10] = true }

export type Key = { index: number, midi: number, name: string, black: boolean }

PianoKeys.list = {} :: { Key }
for i = 1, Config.data.Piano.keys do
	local midi = Config.data.Piano.lowest + i - 1
	local step = midi % 12
	table.insert(PianoKeys.list, { index = i, midi = midi, name = NAMES[step + 1] .. tostring(midi // 12 - 1), black = BLACK[step] == true })
end

-- Computer keys (Enum.KeyCode names) to piano keys, counted in semitones from key 1.
local LOWER = { "Z", "S", "X", "D", "C", "V", "G", "B", "H", "N", "J", "M", "Comma", "L", "Period", "Semicolon", "Slash" }
local UPPER = { "Q", "Two", "W", "Three", "E", "R", "Five", "T", "Six", "Y", "Seven", "U", "I", "Nine", "O", "Zero", "P", "LeftBracket", "Equals", "RightBracket" }

PianoKeys.byKeyCode = {} :: { [string]: number }
for i, code in LOWER do
	PianoKeys.byKeyCode[code] = i
end
for i, code in UPPER do
	PianoKeys.byKeyCode[code] = 12 + i
end

-- The label shown on a key for the computer key that plays it ("" if none).
local SHOWN: { [string]: string } = {
	Comma = ",", Period = ".", Semicolon = ";", Slash = "/", LeftBracket = "[", RightBracket = "]",
	Equals = "=", Two = "2", Three = "3", Five = "5", Six = "6", Seven = "7", Nine = "9", Zero = "0",
}
PianoKeys.label = {} :: { [number]: string }
for code, index in PianoKeys.byKeyCode do
	-- Keys on both rows (C4 to E4) show the upper row's letter.
	if not PianoKeys.label[index] or index > 12 and table.find(UPPER, code) then
		PianoKeys.label[index] = SHOWN[code] or code
	end
end

-- How much to retune a recording of key `from` to sound as key `to` (a speed ratio).
function PianoKeys.ratio(from: number, to: number): number
	return 2 ^ ((to - from) / 12)
end

return PianoKeys
