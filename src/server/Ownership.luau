--!strict
-- Who owns the house: whoever owns the experience on Roblox, worked out on the server and nowhere
-- else, and every owner's power follows them.
--
--   An experience owned by a user        that user (game.CreatorId).
--   An experience owned by a group       the group's owner (GroupService:GetGroupInfoAsync's Owner):
--                                        the owner only, never the group's admins, ranks or members.
--
-- Read when the server starts and again every few minutes, so a change of owner on Roblox reaches
-- every server and every place of the experience by itself: the new owner has every owner's power,
-- the one before has none. No UserId written into the game decides it (Config.Admin.ownerUserId is
-- only the name AJKR goes by while that account is the owner). Nothing is saved: never a DataStore,
-- never a guest's record, nothing a screen sends.
--
-- If the owner can't be found out (Roblox doesn't answer, an unpublished place), nobody has the
-- owner's powers until it can: it's tried again soon, and nothing sensitive is done meanwhile.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Ownership = {}

export type State = {
	userId: number?, -- the owner now (nil: not known)
	kind: string, -- "user", "group" or "unknown"
	creatorId: number,
	name: string?,
	verified: boolean,
	checkedAt: number, -- os.clock() of the last answer
	why: string?, -- why it isn't known, when it isn't
}

local state: State = { userId = nil, kind = "unknown", creatorId = 0, name = nil, verified = false, checkedAt = -math.huge, why = "Not checked yet." }
-- (newOwnerId, previousOwnerId): the owner changed (or was found, or lost). Its listeners are
-- called at once, in order, before refresh returns.
type Listener = (number?, number?) -> ()
local listeners: { Listener } = {}
Ownership.Changed = {
	Connect = function(_self: any, fn: Listener)
		table.insert(listeners, fn)
		return {
			Disconnect = function()
				local i = table.find(listeners, fn)
				if i then
					table.remove(listeners, i)
				end
			end,
		}
	end,
}

Ownership.EVERY = 300 -- seconds between checks while the owner is known
Ownership.RETRY = 20 -- seconds between checks while they aren't

-- Where the answers come from (set by tests).
Ownership.source = function(): (Enum.CreatorType, number)
	return game.CreatorType, game.CreatorId
end
Ownership.groupOwner = function(groupId: number): number?
	local info = GroupService:GetGroupInfoAsync(groupId)
	local owner = info and (info :: any).Owner
	local id = owner and owner.Id
	return if type(id) == "number" then id else nil
end
Ownership.displayName = function(userId: number): string?
	local okPlayer, player = pcall(function()
		return Players:GetPlayerByUserId(userId)
	end)
	if okPlayer and player then
		return player.DisplayName
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync({ userId })
	end)
	if ok and type(infos) == "table" and infos[1] and type(infos[1].DisplayName) == "string" then
		return infos[1].DisplayName
	end
	return nil
end

-- The name the owner goes by in the house: AJKR while that account is the owner; anyone else by
-- their own display name.
local function houseName(userId: number): string
	local admin = Config.data.Admin
	if type(admin.ownerUserId) == "number" and admin.ownerUserId > 0 and userId == admin.ownerUserId and type(admin.ownerName) == "string" and admin.ownerName ~= "" then
		return admin.ownerName
	end
	return Ownership.displayName(userId) or "The Owner"
end

local function publish()
	-- (Every screen reads who the owner is from here: their name on the nameplate and the panel.)
	pcall(function()
		-- (As words: a UserId can be larger than an attribute's number keeps exactly everywhere.)
		Workspace:SetAttribute("MaisonOwnerId", tostring(state.userId or 0))
		Workspace:SetAttribute("MaisonOwnerName", state.name)
		Workspace:SetAttribute("MaisonOwnerKind", state.kind)
		Workspace:SetAttribute("MaisonOwnerVerified", state.verified)
	end)
end

-- Finds out who owns the experience now. Returns whether it's known.
function Ownership.refresh(): boolean
	local before = if state.verified then state.userId else nil
	local okSource, kind, creatorId = pcall(Ownership.source)
	local found: number? = nil
	local how = "unknown"
	local why: string? = nil
	if not okSource or type(creatorId) ~= "number" or creatorId <= 0 then
		why = "This place isn't published, so it has no owner on Roblox."
	elseif kind == Enum.CreatorType.User then
		found, how = creatorId, "user"
	elseif kind == Enum.CreatorType.Group then
		how = "group"
		local ok, owner = pcall(Ownership.groupOwner, creatorId)
		if ok and type(owner) == "number" and owner > 0 then
			found = owner
		else
			why = "Roblox didn't say who owns the group just now."
		end
	else
		why = "The experience's owner is neither a user nor a group."
	end
	state.kind = how
	state.creatorId = if type(creatorId) == "number" then creatorId else 0
	state.checkedAt = os.clock()
	if found then
		state.userId = found
		state.verified = true
		state.why = nil
		if found ~= before or not state.name then
			state.name = houseName(found)
		end
	else
		-- (Not known: nobody has the owner's powers until it is.)
		state.userId = nil
		state.verified = false
		state.name = nil
		state.why = why
	end
	publish()
	local now = if state.verified then state.userId else nil
	if now ~= before then
		for _, fn in table.clone(listeners) do
			local ok, err = pcall(fn :: any, now, before)
			if not ok then
				warn("[Maison] After the owner changed: " .. tostring(err))
			end
		end
	end
	return state.verified
end

-- Whether this guest is the owner now (false whenever it isn't known).
function Ownership.isOwner(player: Player): boolean
	return state.verified and state.userId ~= nil and player.UserId == state.userId
end

function Ownership.ownerId(): number?
	return if state.verified then state.userId else nil
end

-- What the owner's panel shows about it.
function Ownership.current(): { [string]: any }
	return {
		userId = if state.verified then state.userId else nil,
		name = state.name,
		kind = state.kind,
		creatorId = state.creatorId,
		verified = state.verified,
		why = state.why,
		checkedAgo = if state.checkedAt > -math.huge then math.floor(os.clock() - state.checkedAt) else nil,
	}
end

function Ownership.start()
	Ownership.refresh()
	task.spawn(function()
		while true do
			task.wait(if state.verified then Ownership.EVERY else Ownership.RETRY)
			pcall(Ownership.refresh)
		end
	end)
end

return Ownership
