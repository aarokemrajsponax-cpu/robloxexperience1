--!strict
-- God-Mode Luck: 2.5× Gilt and 2.5× Ledger pages for 30 minutes of play (ProductConfig
-- godModeLuck). Never scores, Mythic odds or anything on a board: only the two systems named in
-- the catalog (Reward.Systems), which validation keeps to "gilt" and "ledger".
--
-- The server owns the time. The profile keeps the seconds left (perks.luck.remaining); while the
-- guest is in the house it counts down on the server's clock, so it's only spent in play, and
-- it survives a rejoin or another server. Buying again while it runs extends it by the full
-- duration (Rules.Stack = "extend"); the house doesn't offer more than Rules.MaxSeconds held at
-- once. When it reaches zero it's removed, the guest's screen is told, and an Expired event is
-- logged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)
local Telemetry = require(script.Parent.Telemetry)

local Luck = {}

local KEY = "godModeLuck"
local ends: { [Player]: number } = {} -- os.clock() when this session's Luck runs out
local datas: { [Player]: Profiles.Data } = {} -- each guest's profile data while they're here

local function entry(): ProductConfig.Entry
	return ProductConfig.byKey[KEY]
end

-- Seconds of Luck a guest has left (live while they're here).
function Luck.remaining(player: Player, data: Profiles.Data?): number
	local e = ends[player]
	if e then
		return math.max(0, e - os.clock())
	end
	return if data then math.max(0, data.perks.luck.remaining) else 0
end

-- The multiplier Luck gives a guest for a system ("gilt" or "ledger"); 1 without Luck.
function Luck.multiplier(player: Player, system: string): number
	local e = ends[player]
	if not e or e <= os.clock() then
		return 1
	end
	local reward = entry().Reward
	for _, s in reward.Systems do
		if s == system then
			return reward.Multiplier
		end
	end
	return 1
end

-- Starts this session's countdown from the profile.
local function arm(player: Player, data: Profiles.Data)
	local left = math.max(0, data.perks.luck.remaining)
	if left > 0 then
		ends[player] = os.clock() + left
	else
		ends[player] = nil
	end
end

-- Writes the time left back into the profile (so it's saved, and kept across servers).
local function store(player: Player, data: Profiles.Data)
	local e = ends[player]
	data.perks.luck.remaining = if e then math.max(0, math.floor(e - os.clock())) else 0
end

local function grant(ctx: Grants.Context)
	local reward = ctx.product.Reward
	local player, data = ctx.player, ctx.data
	-- Every purchase adds its full time. MaxSeconds is how much the house will *offer* (a prompt
	-- isn't shown beyond it); a purchase made anyway (a screen can open Roblox's window itself)
	-- is still granted in full: paid time is never cut.
	local total = Luck.remaining(player, data) + reward.DurationSeconds
	data.perks.luck.remaining = total
	-- The live countdown moves with it, in the same step: otherwise the countdown's own writes
	-- (or its expiry) could overwrite the new time while the receipt's save is on its way.
	if datas[player] == data then
		ends[player] = os.clock() + total
	end
	ctx:after(function()
		if ends[player] == nil then
			arm(player, data)
		end
		Perks.push(player)
		Perks.tell(player, { op = "notice", title = "Luck Booster", line = string.format("2.5× Gilt and Ledger pages: %d minutes of play left.", math.floor(Luck.remaining(player, data) / 60 + 0.5)) })
	end)
end

local function expire(player: Player)
	ends[player] = nil
	local data = Profiles.get(player)
	if data then
		data.perks.luck.remaining = 0
	end
	Telemetry.log(player, Telemetry.Events.Expired, KEY, "time_up")
	Perks.push(player)
	Perks.tell(player, { op = "notice", title = "Luck Booster", line = "Your Luck has run its course." })
end

function Luck.start()
	Grants.register("luck", grant)
	Store.eligibility[KEY] = function(player: Player, data: Profiles.Data): (boolean, string?)
		local e = entry()
		if Luck.remaining(player, data) + e.Reward.DurationSeconds > e.Rules.MaxSeconds then
			return false, string.format("You hold as much Luck as the house allows (%d hours).", math.floor(e.Rules.MaxSeconds / 3600))
		end
		return true, nil
	end
	Perks.contributors.luck = function(player: Player, data: Profiles.Data): any
		local reward = entry().Reward
		return { remaining = math.floor(Luck.remaining(player, data)), multiplier = reward.Multiplier, systems = reward.Systems }
	end
	Profiles.Loaded:Connect(function(player: Player, data: Profiles.Data)
		datas[player] = data
		arm(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		-- (The data table kept from arrival: the profile may already be closing.)
		local data = datas[player] or Profiles.get(player)
		if data then
			store(player, data)
		end
		ends[player] = nil
		datas[player] = nil
	end)
	-- The countdown, on the server's clock: expiry is checked every second, the time left written
	-- into the profile every few seconds (ProductConfig.Settings.LuckWriteSeconds).
	local tick, write = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		tick += dt
		write += dt
		if tick < 1 then
			return
		end
		tick = 0
		local saveNow = write >= ProductConfig.Settings.LuckWriteSeconds
		if saveNow then
			write = 0
		end
		for player, e in ends do
			if e <= os.clock() then
				expire(player)
			elseif saveNow then
				local data = Profiles.get(player)
				if data then
					store(player, data)
				end
			end
		end
	end)
end

return Luck
