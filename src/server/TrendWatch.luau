--!strict
-- Trend Watch (THE MAISON — LIVE OPERATIONS, in the owner's console): what's popular in the house,
-- from the house's own numbers, and the owner's own trend ideas.
--   The house's own trends   what guests did most today, from every server, beside yesterday:
--                            visits, each attraction, the Grand Ballroom's activities, races,
--                            trades, curios found... Each server counts as things happen and
--                            adds its counts to its part of the day's record every two minutes
--                            (one write; the parts are added together when they're read).
--   Ideas                    the owner's notes on trends worth borrowing from (an event format, a
--                            collectible theme, a seasonal look), each an idea until the owner
--                            approves or declines it. Nothing here ever becomes part of the game by
--                            itself: an approved idea is a note for the people who build it.
-- No outside trend source is connected, and the console says so: nothing here claims to know
-- what's trending anywhere else. (Should one be connected, it would come through here, cached and
-- rate-limited, and its ideas would still wait for the owner's approval.)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Gate = require(script.Parent.Gate)

local TrendWatch = {}

TrendWatch.now = os.time
TrendWatch.FLUSH = 120 -- seconds between a server's writes of its counts
TrendWatch.SHARDS = 8 -- the day's record is kept in this many parts, each server writing to one
TrendWatch.NOTES = 40 -- ideas kept
TrendWatch.SOURCE = nil :: string? -- a connected external trend source, if any (none)

-- What each count is called on the console (anything else by its own name).
local LABELS: { [string]: string } = {
	visits = "Visits to the house",
	["attraction:luxe"] = "Steal a Luxe: visits",
	["attraction:basement"] = "The Maison Basement: visits",
	["attraction:executive"] = "The Executive Suite: visits",
	["attraction:island"] = "Luxury Island: visits",
	["attraction:gala"] = "The Grand Ballroom: visits",
	["did:file"] = "Pieces filed at the tables",
	["did:rounds"] = "Rounds cleared at the tables",
	["did:flawless"] = "Flawless rounds",
	["did:nightly"] = "Tonight's tables played",
	["did:library"] = "Library matches played",
	["did:ballroom"] = "Lights Out evenings played",
	["did:luxeBank"] = "Hauls banked in Steal a Luxe",
	["did:basementClear"] = "Basement Treasuries reached",
	["did:executiveWin"] = "The Executive beaten",
	["did:race"] = "Grand Prix races finished",
	["did:raceWin"] = "Grand Prix races won",
	["did:trivia"] = "Luxury Trivia rounds played",
	["did:runway"] = "Runway shows walked",
	["did:arena"] = "Daily Arena rounds played",
	trade = "Trades made",
	curio = "Curios collected",
	salute = "Salutes given",
	admire = "Guests admired",
	guestBook = "Signatures in the Livre d'Or",
	runBanked = "Runs banked at the tables",
	soiree = "Soirée games played",
	badge = "Badges earned",
	boutique = "Boutique items received",
	goldKey = "Gold Keys bought",
}
TrendWatch.LABELS = LABELS

local counts: { [string]: number } = {}
local cache: { day: number, today: { [string]: number }, yesterday: { [string]: number }, unread: boolean, at: number }? = nil

local function day(): number
	return math.floor(TrendWatch.now() / 86400)
end

local function store(): any
	return DataStoreService:GetDataStore("MaisonTrends_v1")
end

-- This server's part of a day's record (servers spread across the parts by their JobId, so no one
-- key is written by every server in the house).
function TrendWatch.shard(): number
	local id = tostring(game.JobId or "")
	local h = 0
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 1000003
	end
	return h % TrendWatch.SHARDS + 1
end

-- The key of a day's part.
function TrendWatch.key(d: number, part: number): string
	return tostring(d) .. "/" .. tostring(part)
end

-- Counts something that happened in this server (written with the next flush).
function TrendWatch.count(key: string, n: number?)
	if #key > 60 then
		return
	end
	counts[key] = (counts[key] or 0) + (n or 1)
end

-- The house's analytics events Trend Watch counts, by name (server/Analytics; each counted once
-- per event). Anything not here isn't counted.
local EVENTS: { [string]: string } = {
	Trade = "trade",
	["Salute given"] = "salute",
	["Admired a guest"] = "admire",
	["Signed the Livre d'Or"] = "guestBook",
	["Run banked"] = "runBanked",
	["Soirée result"] = "soiree",
	Badge = "badge",
	["Boutique item granted"] = "boutique",
	["Gold Key bought"] = "goldKey",
}
TrendWatch.EVENTS = EVENTS

-- Something the house logged (set as Analytics.observed by Main).
function TrendWatch.event(name: string, fields: { [any]: any }?)
	if name == "Attraction entered" then
		local id = if type(fields) == "table" then fields.attraction else nil
		if type(id) == "string" then
			TrendWatch.count("attraction:" .. id)
		end
		return
	end
	if name == "Curio" then
		-- (One found or won, not one changing hands in a trade.)
		local source = if type(fields) == "table" then fields.source else nil
		if source ~= "trade" then
			TrendWatch.count("curio")
		end
		return
	end
	local key = EVENTS[name]
	if key then
		TrendWatch.count(key)
	end
end

-- Something a Commission might count (set as Collection.observed by Main): once each time.
local SKIP_KINDS = { luxeWorth = true, stride = true } -- (amounts, not happenings)
function TrendWatch.did(kind: string, _amount: number?)
	if type(kind) == "string" and not SKIP_KINDS[kind] then
		TrendWatch.count("did:" .. kind)
	end
end

-- Adds this server's counts to the day's record (all servers' counts, one record a day).
function TrendWatch.flush()
	if next(counts) == nil then
		return
	end
	local batch = counts
	counts = {}
	local key = TrendWatch.key(day(), TrendWatch.shard())
	local ok = Gate.write("trends", function()
		store():UpdateAsync(key, function(old: any): any
			local t = if type(old) == "table" then old else {}
			for k, n in batch do
				t[k] = (tonumber(t[k]) or 0) + n
			end
			return t
		end)
	end)
	if not ok then
		-- (Not written: kept for the next try.)
		for k, n in batch do
			counts[k] = (counts[k] or 0) + n
		end
	end
end

-- A day's record: every part, added together (and whether a part couldn't be read).
local function read(d: number): ({ [string]: number }, boolean)
	local sum: { [string]: number } = {}
	local unread = false
	for part = 1, TrendWatch.SHARDS do
		local ok, v = Gate.read("trends", function()
			return store():GetAsync(TrendWatch.key(d, part))
		end)
		if not ok then
			unread = true
		elseif type(v) == "table" then
			for k, n in v do
				if type(k) == "string" then
					sum[k] = (sum[k] or 0) + (tonumber(n) or 0)
				end
			end
		end
	end
	return sum, unread
end

-- The house's own trends: today's counts against yesterday's, the largest first.
function TrendWatch.trends(): { { [string]: any } }
	local today = day()
	local c = cache
	if not c or c.day ~= today or os.clock() - c.at > 60 then
		local now, a = read(today)
		local before, b = read(today - 1)
		c = { day = today, today = now, yesterday = before, unread = a or b, at = os.clock() }
		cache = c
	end
	local before = (c :: any).yesterday
	-- (Today's record, with this server's counts not yet written added in.)
	local now: { [string]: number } = {}
	for k, n in (c :: any).today do
		now[k] = tonumber(n) or 0
	end
	for k, n in counts do
		now[k] = (now[k] or 0) + n
	end
	local rows = {}
	for k, n in now do
		local was = tonumber(before[k]) or 0
		table.insert(rows, {
			key = k,
			name = LABELS[k] or k,
			today = n,
			yesterday = was,
			change = if was > 0 then math.floor((n - was) / was * 100 + 0.5) else nil,
		})
	end
	table.sort(rows, function(a, b)
		return a.today > b.today
	end)
	return rows
end

---------------------------------------------------------------------------------------------------
-- The owner's trend ideas
---------------------------------------------------------------------------------------------------
local function notesStore(): any
	return DataStoreService:GetDataStore("MaisonTrendNotes_v1")
end

function TrendWatch.notes(): { any }
	local ok, v = Gate.read("trendNotes", function()
		return notesStore():GetAsync("notes")
	end)
	return if ok and type(v) == "table" then v else {}
end

local STATUSES = { idea = true, approved = true, declined = true }

-- Changes the ideas (`change` edits the list it's given; the stored list is replaced with it).
local function edit(change: ({ any }) -> (boolean, string?)): (boolean, string?)
	local why: string? = nil
	local done = false
	local ok = Gate.write("trendNotes", function()
		notesStore():UpdateAsync("notes", function(old: any): any
			local list = if type(old) == "table" then old else {}
			local changed, reason = change(list)
			why = reason
			if not changed then
				return nil
			end
			done = true
			return list
		end)
	end)
	if not ok then
		return false, "The ideas couldn't be written just now."
	end
	return done, why
end

function TrendWatch.addNote(text: string, by: string): (boolean, string?)
	text = string.gsub(text, "%c", " ")
	text = string.sub(text, 1, 160)
	if string.match(text, "^%s*$") then
		return false, "Write the idea first."
	end
	return edit(function(list: { any }): (boolean, string?)
		local id = 1
		for _, n in list do
			id = math.max(id, (tonumber(n.id) or 0) + 1)
		end
		table.insert(list, 1, { id = id, text = text, status = "idea", by = by, at = TrendWatch.now() })
		while #list > TrendWatch.NOTES do
			table.remove(list)
		end
		return true, nil
	end)
end

function TrendWatch.setStatus(id: number, status: string): (boolean, string?)
	if not STATUSES[status] then
		return false, "That isn't one of the choices."
	end
	return edit(function(list: { any }): (boolean, string?)
		for _, n in list do
			if n.id == id then
				n.status = status
				return true, nil
			end
		end
		return false, "That idea isn't on the list."
	end)
end

function TrendWatch.remove(id: number): (boolean, string?)
	return edit(function(list: { any }): (boolean, string?)
		for i, n in list do
			if n.id == id then
				table.remove(list, i)
				return true, nil
			end
		end
		return false, "That idea isn't on the list."
	end)
end

-- What the console shows (the owner's).
function TrendWatch.view(): { [string]: any }
	local rows = TrendWatch.trends()
	return {
		ok = true,
		trends = rows,
		-- (Some of the record couldn't be read just now: the console says these are partial.)
		partial = if cache then (cache :: any).unread == true else false,
		notes = TrendWatch.notes(),
		source = TrendWatch.SOURCE,
	}
end

function TrendWatch.start()
	Players.PlayerAdded:Connect(function()
		TrendWatch.count("visits")
	end)
	task.spawn(function()
		-- (Servers started together don't write together: each begins at its own moment.)
		task.wait(math.random() * TrendWatch.FLUSH)
		while true do
			pcall(TrendWatch.flush)
			task.wait(TrendWatch.FLUSH)
		end
	end)
	game:BindToClose(function()
		pcall(TrendWatch.flush)
	end)
end

return TrendWatch
