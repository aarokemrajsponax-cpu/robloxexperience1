--!strict
-- The house's herald: feats worth telling, told to everyone in the house in gold across the top of
-- their screens (client UI/Herald). A rare brainrot found, a great haul carried out of Steal a
-- Luxe, the Maison Basement finished, the Executive beaten, an auction won, a new wealth rank.
--   * Only what the server itself saw happen is ever told: nothing is made up, and no screen can ask
--     for a feat.
--   * A guest who has turned "Show my Fortune and feats" off in Settings is told their own feat and
--     nobody else is.
--   * It never floods: each guest's feats of one kind at most once in Config.Herald.kindGap seconds,
--     and the house hears at most one feat every Config.Herald.gap seconds (the rest wait, a few at
--     most; the oldest of too many are let go).
--   * The very greatest (the Crown Jewel, the Executive beaten for the first time, an auction won)
--     are told in every server of the game too (MessagingService), at most one a server every
--     Config.Herald.farGap seconds; a server hearing one tells it like its own, gap and all.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Profiles = require(script.Parent.Profiles)

local Herald = {}

export type Feat = {
	kind: string, -- "rank", "haul", "basement", "executive", "auction", "find", "record"
	title: string, -- a few words in capitals ("A GREAT HAUL")
	line: string, -- what happened, without the guest's name ("carried the Crown Jewel out of Steal a Luxe")
	glyph: string?, -- an emoji for its medallion
	worth: number?, -- a figure to show with it
	colour: Color3?,
	everywhere: boolean?, -- told in every server of the game too
}

local TOPIC = "MaisonHerald"
local lastFar = -math.huge
-- Sends a feat to every other server (set by tests).
Herald.publish = function(message: { [string]: any })
	pcall(function()
		MessagingService:PublishAsync(TOPIC, message)
	end)
end

local function cfg(): { [string]: any }
	return (Config.data :: any).Herald
end

local lastOfKind: { [Player]: { [string]: number } } = {}
local queue: { { [string]: any } } = {}
local lastTold = -math.huge
local draining = false

local function drain()
	if draining then
		return
	end
	draining = true
	task.spawn(function()
		while #queue > 0 do
			local wait = lastTold + (tonumber(cfg().gap) or 6) - os.clock()
			if wait > 0 then
				task.wait(wait)
			end
			local message = table.remove(queue, 1)
			if message then
				lastTold = os.clock()
				Remotes.event("Empire"):FireAllClients(message)
			end
		end
		draining = false
	end)
end

-- Tells a feat. Returns whether the whole house will hear it (false: only the guest, or not now).
function Herald.feat(player: Player, feat: Feat): boolean
	local data = Profiles.get(player)
	if not data then
		return false
	end
	local message: { [string]: any } = {
		op = "feat",
		kind = feat.kind,
		title = feat.title,
		line = feat.line,
		glyph = feat.glyph,
		worth = feat.worth,
		colour = feat.colour,
		name = Names.of(player),
		userId = player.UserId,
		seconds = tonumber(cfg().seconds) or 5,
	}
	local now = os.clock()
	local kinds = lastOfKind[player] or {}
	lastOfKind[player] = kinds
	local private = (data.settings :: any).showFortune == "Off"
	local tooSoon = kinds[feat.kind] ~= nil and now - kinds[feat.kind] < (tonumber(cfg().kindGap) or 45)
	if private or tooSoon then
		message.own = true
		Remotes.event("Empire"):FireClient(player, message)
		return false
	end
	kinds[feat.kind] = now
	if feat.everywhere and now - lastFar >= (tonumber(cfg().farGap) or 30) then
		lastFar = now
		local far = table.clone(message)
		far.colour = nil -- (Color3 doesn't travel between servers)
		far.far = true
		far.server = game.JobId
		task.spawn(Herald.publish, far)
	end
	table.insert(queue, message)
	while #queue > (tonumber(cfg().queue) or 6) do
		table.remove(queue, 1)
	end
	drain()
	return true
end

function Herald.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		lastOfKind[player] = nil
	end)
	-- Another server's great feat: told here like our own (never this server's own, again).
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(packet: any)
			Herald.hear(packet and packet.Data)
		end)
	end)
end

-- A feat from another server.
function Herald.hear(m: any)
	if type(m) ~= "table" or m.op ~= "feat" or m.server == game.JobId then
		return
	end
	if type(m.title) ~= "string" or type(m.line) ~= "string" or type(m.name) ~= "string" then
		return
	end
	local message = { op = "feat", kind = tostring(m.kind), title = m.title, line = m.line, glyph = m.glyph, worth = tonumber(m.worth), name = m.name, userId = tonumber(m.userId), seconds = tonumber(cfg().seconds) or 5, far = true }
	table.insert(queue, message)
	while #queue > (tonumber(cfg().queue) or 6) do
		table.remove(queue, 1)
	end
	drain()
end

-- For tests: what's waiting to be told.
function Herald.waiting(): number
	return #queue
end

return Herald
