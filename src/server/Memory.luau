--!strict
-- The house remembers you. The Concierge's welcome carries one thing from last time (a Flawless
-- round, the last lamp, a win in the Library), how long you've been away, how many guests admired
-- you, and your milestones (your 10th night, your 50th...). The table you sit at most becomes
-- your usual: while you're in the house, a small brass plate by it carries your name, and the
-- Concierge offers it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Names = require(ReplicatedStorage.Shared.Names)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Profiles = require(script.Parent.Profiles)

local Memory = {}

local V = Voice.Concierge.memory
local MILESTONES = { 3, 7, 10, 25, 50, 100, 200, 365, 500, 1000 }
local USUAL_ROUNDS = 5 -- rounds at one table before it's your usual
local HIGHLIGHT_DAYS = 21

-- A line for the Tonight board's feed (set by Main).
Memory.note = function(_text: string) end

-- What each guest was like when they arrived (so the welcome can speak of last time).
local arrival: { [Player]: { lastSeen: number, highlight: string, highlightAt: number, admiredSince: number } } = {}

function Memory.ordinal(n: number): string
	local last2 = n % 100
	local suffix = if last2 >= 11 and last2 <= 13 then "th" elseif n % 10 == 1 then "st" elseif n % 10 == 2 then "nd" elseif n % 10 == 3 then "rd" else "th"
	return tostring(n) .. suffix
end

-- Remembers the last thing worth mentioning ("you kept the last lamp in the Ballroom").
function Memory.highlight(player: Player, text: string)
	local data = Profiles.get(player)
	if data then
		data.memory.highlight = text
		data.memory.highlightAt = os.time()
	end
end

-- A round at a table (the table you sit at most becomes your usual).
function Memory.round(player: Player, tableId: string?)
	local data = Profiles.get(player)
	if data and tableId and tableId ~= "" then
		data.memory.tables[tableId] = (data.memory.tables[tableId] or 0) + 1
	end
end

function Memory.usual(data: Profiles.Data): string?
	local best, bestRounds = nil, USUAL_ROUNDS - 1
	for id, rounds in data.memory.tables do
		if rounds > bestRounds then
			best, bestRounds = id, rounds
		end
	end
	return best
end

local function tableModel(id: string): Model?
	for _, m in CollectionService:GetTagged("MaisonTable") do
		if m:IsA("Model") and m:GetAttribute("TableId") == id then
			return m
		end
	end
	return nil
end

-- The room of a guest's usual table (for the Concierge to walk them there), or nil.
function Memory.usualRoom(player: Player): string?
	local data = Profiles.get(player)
	local id = data and Memory.usual(data)
	local m = id and tableModel(id)
	local room = m and m:GetAttribute("Room")
	return if type(room) == "string" then room else nil
end

-- While a guest is in the house, their usual table carries their name (unless a guest who
-- arrived earlier holds it).
local function claim(player: Player, data: Profiles.Data)
	local id = Memory.usual(data)
	local m = id and tableModel(id)
	if m and m:GetAttribute("RegularId") == nil then
		m:SetAttribute("RegularId", player.UserId)
		m:SetAttribute("Regular", Names.of(player))
	end
end

local function release(player: Player)
	for _, m in CollectionService:GetTagged("MaisonTable") do
		if m:GetAttribute("RegularId") == player.UserId then
			m:SetAttribute("RegularId", nil)
			m:SetAttribute("Regular", nil)
		end
	end
end

-- The welcome's second sentence for a returning guest, or nil.
function Memory.greeting(player: Player): string?
	local data = Profiles.get(player)
	local was = arrival[player]
	if not data or not was then
		return nil
	end
	local n = data.nights.count
	if table.find(MILESTONES, n) then
		if n >= 10 then
			Memory.note(string.format("%s's %s night at the house.", Names.of(player), Memory.ordinal(n)))
		end
		return (string.gsub(V.milestone, "{n}", Memory.ordinal(n)))
	end
	if was.lastSeen > 0 and os.time() - was.lastSeen > 7 * 86400 then
		return if Memory.usual(data) then V.away else V.awayNoTable
	end
	if was.admiredSince > 1 then
		return (string.gsub(V.admired, "{n}", tostring(was.admiredSince)))
	elseif was.admiredSince == 1 then
		return V.admiredOne
	end
	if was.highlight ~= "" and os.time() - was.highlightAt < HIGHLIGHT_DAYS * 86400 then
		return (string.gsub(V.lastTime, "{highlight}", was.highlight))
	end
	return nil
end

-- A guest admired another (Social): counted for their next welcome.
function Memory.admired(target: Player)
	local data = Profiles.get(target)
	if data then
		data.memory.admired += 1
		data.memory.admiredSince += 1
	end
end

function Memory.start()
	Profiles.Loaded:Connect(function(player: Player, data: Profiles.Data)
		local m = data.memory
		arrival[player] = { lastSeen = m.lastSeen, highlight = m.highlight, highlightAt = m.highlightAt, admiredSince = m.admiredSince }
		m.lastSeen = os.time()
		m.admiredSince = 0
		claim(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local data = Profiles.get(player)
		if data then
			data.memory.lastSeen = os.time()
		end
		release(player)
		arrival[player] = nil
		-- Someone else in the house may now hold that table.
		for _, other in Players:GetPlayers() do
			local od = if other ~= player then Profiles.get(other) else nil
			if od then
				claim(other, od)
			end
		end
	end)
end

return Memory
