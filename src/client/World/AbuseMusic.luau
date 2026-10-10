--!strict
-- Music for Admin Abuse and the owner's effects: while Admin Abuse is on, a run of dance tracks
-- (Mega Abuse: harder ones, dubstep and drum and bass); while an effect is switched on, its own
-- (the galaxy: something cosmic; a meteor shower or a black hole: something epic; the dance
-- party: disco; the blizzard: winter; the gold wave: a brass fanfare; the blackout: spy jazz).
-- Whichever was started last plays; when they're all over, the house's own music comes back.
-- Every track is a real recording from Roblox's licensed library (Config.Assets.AbuseMusic).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Sound = require(script.Parent.Parent.Sound)

local AbuseMusic = {}

local current = ""
local stopCurrent: (() -> ())? = nil
local holdUntil = 0 -- (Admin Abuse's opening: its music waits for the drop)

local function assets(): { [string]: any }
	return Config.data.Assets :: any
end

-- Which music should play now ("" for the house's own).
function AbuseMusic.choose(): string
	local themes = assets().AbuseThemes or {}
	local best, bestAt = "", -math.huge
	local ends = Workspace:GetAttribute("AbuseUntil")
	if type(ends) == "number" and ends > Workspace:GetServerTimeNow() then
		local since = Workspace:GetAttribute("AbuseSince")
		-- (The night's own music, if the house has it: the cosmos, a brass band, spy jazz...)
		local lists = assets().AbuseMusic or {}
		local own = Workspace:GetAttribute("AbuseMusic")
		best = if type(own) == "string" and type(lists[own]) == "table" then own elseif Workspace:GetAttribute("AbuseMega") == true then "mega" else "abuse"
		bestAt = if type(since) == "number" then since else 0
	end
	for _, e in HouseEvents.Effects do
		local since = Workspace:GetAttribute(HouseEvents.fxAttribute(e.id))
		local theme = themes[e.id]
		-- (Switched on after Admin Abuse began, or at the same moment: the effect's music.)
		if type(since) == "number" and type(theme) == "string" and since >= bestAt then
			best, bestAt = theme, since
		end
	end
	return best
end

function AbuseMusic.current(): string
	return current
end

local function apply()
	local want = AbuseMusic.choose()
	if want == current then
		return
	end
	if (want == "abuse" or want == "mega") and os.clock() < holdUntil then
		return -- (the opening's drop starts it: AbuseMusic.holdFor)
	end
	current = want
	local stop = stopCurrent
	stopCurrent = nil
	if stop then
		stop()
	end
	local lists = assets().AbuseMusic or {}
	local songs = lists[want]
	if want ~= "" and type(songs) == "table" and #songs > 0 then
		-- (Admin Abuse's night starts its playlist at a track of its own: not the same song first
		-- every night.)
		local first = Workspace:GetAttribute("AbuseTrack")
		local order = songs
		if type(first) == "number" and AbuseMusic.choose() == want and Workspace:GetAttribute("AbuseUntil") ~= nil then
			order = {}
			for i = 1, #songs do
				table.insert(order, songs[((math.floor(first) - 1 + i - 1) % #songs) + 1])
			end
		end
		stopCurrent = Sound.scoreList(order, assets().AbuseMusicVolume or 0.85)
	end
end

-- Admin Abuse's opening: its music starts at the drop, `seconds` from now, not before.
function AbuseMusic.holdFor(seconds: number)
	holdUntil = os.clock() + seconds
	task.delay(seconds + 0.05, apply)
end

function AbuseMusic.start()
	for _, name in { "AbuseUntil", "AbuseMega", "AbuseSince", "AbuseMusic" } do
		Workspace:GetAttributeChangedSignal(name):Connect(apply)
	end
	for _, e in HouseEvents.Effects do
		Workspace:GetAttributeChangedSignal(HouseEvents.fxAttribute(e.id)):Connect(apply)
	end
	apply()
	-- (Admin Abuse ends at a time, not with a change: look now and then.)
	task.spawn(function()
		while true do
			task.wait(2)
			apply()
		end
	end)
end

return AbuseMusic
