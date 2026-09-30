--!strict
-- Notifications (§13): Roblox experience notifications through Open Cloud. At most one a day per
-- guest: your rival passed you on tonight's table, the Soirée has started, the Term ends in three
-- days. Tapping one lands the guest at the right spot (launch data). Roblox itself only delivers
-- to guests who opted in (13+); the house asks for the opt-in only after a first Nightly (the
-- client does the asking). The API key lives in the experience's secrets, never in code.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rating = require(ReplicatedStorage.Shared.Rating)
local Soiree = require(ReplicatedStorage.Shared.Soiree)
local Private = require(script.Parent.Private)

local Notify = {}

local function cfg()
	return Config.data.Notifications
end

local function today(): number
	return math.floor(os.time() / 86400)
end

-- The request itself (replaced in tests). Returns true when Roblox accepted it.
Notify.post = function(userId: number, messageId: string, params: { [string]: string }, launch: string, category: string): boolean
	local okSecret, secret = pcall(function()
		return HttpService:GetSecret(cfg().secret)
	end)
	if not okSecret then
		return false
	end
	local parameters = {}
	for k, v in params do
		parameters[k] = { stringValue = v }
	end
	local body = HttpService:JSONEncode({
		source = { universe = "universes/" .. tostring(game.GameId) },
		payload = { type = "MOMENT", messageId = messageId, parameters = parameters, joinExperience = { launchData = launch } },
		analyticsData = { category = category },
	})
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = "https://apis.roblox.com/cloud/v2/users/" .. tostring(userId) .. "/notifications",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = secret :: any },
			Body = body,
		})
	end)
	return ok and type(response) == "table" and (response :: any).Success == true
end

-- Claims today's one notification for a guest (every server agrees through UpdateAsync).
Notify.claimDay = function(userId: number): boolean
	local day = today()
	local ok, got = pcall(function()
		local store = DataStoreService:GetDataStore("MaisonNoir_Notify")
		return store:UpdateAsync(tostring(userId), function(old: any): number?
			if old == day then
				return nil
			end
			return day
		end)
	end)
	return ok and got == day
end

-- Sends one kind of notification, if its template is set and the guest hasn't had one today.
function Notify.send(userId: number, kind: string, params: { [string]: string }, launch: string): boolean
	if not cfg().enabled then
		return false
	end
	local messageId = (cfg().messages :: any)[kind]
	if type(messageId) ~= "string" or messageId == "" then
		return false
	end
	if not Notify.claimDay(userId) then
		return false
	end
	return Notify.post(userId, messageId, params, launch, kind)
end

-- After a Nightly: if the guest is now ahead of their rival, the rival hears about it.
function Notify.rivalPassed(player: Player, rivalUserId: number, ahead: boolean)
	if not ahead or rivalUserId == 0 or Players:GetPlayerByUserId(rivalUserId) then
		return -- (a rival in the same house sees the plate turn instead)
	end
	task.spawn(Notify.send, rivalUserId, "rivalPassed", { name = player.DisplayName }, "nightly")
end

-- Guests seen lately (so the Soirée and the Term's end reach them).
local function recentMap(): MemoryStoreSortedMap?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap("MaisonNoir_RecentGuests")
	end)
	return if ok then map else nil
end

function Notify.seen(player: Player)
	local map = recentMap()
	if map then
		task.spawn(function()
			pcall(function()
				(map :: MemoryStoreSortedMap):SetAsync(tostring(player.UserId), os.time(), cfg().recentDays * 86400)
			end)
		end)
	end
end

-- One server claims a broadcast (the Soirée's start, the Term's last days) and sends it.
local function claim(job: string): boolean
	local ok, got = pcall(function()
		local store = DataStoreService:GetDataStore("MaisonNoir_Notify")
		return store:UpdateAsync("job:" .. job, function(old: any): number?
			if old then
				return nil
			end
			return os.time()
		end)
	end)
	return ok and type(got) == "number"
end

local function broadcast(kind: string, launch: string, params: { [string]: string })
	local map = recentMap()
	if not map then
		return
	end
	local ok, items = pcall(function()
		return (map :: MemoryStoreSortedMap):GetRangeAsync(Enum.SortDirection.Descending, cfg().maxBatch)
	end)
	if not ok or type(items) ~= "table" then
		return
	end
	local sent = 0
	for _, item in items :: { any } do
		local userId = tonumber(item.key)
		if userId and Notify.send(userId, kind, params, launch) then
			sent += 1
		end
		task.wait(0.1)
	end
	print(string.format("[Maison] %d %s notifications sent", sent, kind))
end

-- The first day of the next Term, and whether we're in the last three days before it.
function Notify.termEnding(time: number): (boolean, string)
	local term = Rating.term(time)
	local later = Rating.term(time + 3 * 86400)
	return later.id ~= term.id, term.id
end

local function check()
	if not cfg().enabled or not Private.records() then
		return
	end
	local now = os.time()
	local weekend = Soiree.at(now)
	if weekend.active and claim("soiree:" .. weekend.key) then
		broadcast("soiree", "soiree", { name = weekend.name })
	end
	local ending, termId = Notify.termEnding(now)
	if ending and claim("term:" .. termId) then
		broadcast("termEnding", "ledger", { term = Rating.term(now).name })
	end
end

function Notify.start()
	Players.PlayerAdded:Connect(Notify.seen)
	task.spawn(function()
		while true do
			task.wait(cfg().checkSeconds)
			check()
		end
	end)
end

return Notify
