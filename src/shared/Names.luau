--!strict
-- The name the house shows for a guest, wherever it shows one (headlines, giveaways, gifts,
-- nameplates, chat, boards, trades, notices).
--   The owner (whoever owns the experience on Roblox: the server works it out, server/Ownership, and
--   tells every screen) goes by their house name: AJKR while AJKR's account is the owner
--   (Config.Admin.ownerName), anyone else by their own display name.
--   Nobody else can pass for the owner: a guest whose display name reads as the owner's house name
--   ("AJKR", "a.j.k.r", "AJKR_") is shown by their @username instead.

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Names = {}

-- What the server has told every screen about the owner (an attribute on the Workspace).
local function told(name: string): any
	local ok, value = pcall(function()
		return game:GetService("Workspace"):GetAttribute(name)
	end)
	return if ok then value else nil
end

-- A co-owner's house name (Config.Admin.coOwners: by UserId only), or nil.
function Names.coOwner(userId: number): string?
	local list = (Config.data.Admin :: any).coOwners
	if type(list) ~= "table" then
		return nil
	end
	for _, c in list do
		if type(c) == "table" and c.userId == userId and userId > 0 then
			return if type(c.name) == "string" and c.name ~= "" then c.name else nil
		end
	end
	return nil
end

-- The owner's house name.
function Names.owner(): string
	local name = told("MaisonOwnerName")
	if type(name) == "string" and name ~= "" then
		return name
	end
	local n = Config.data.Admin.ownerName
	return if type(n) == "string" and n ~= "" then n else "AJKR"
end

-- (Build 91) The house's host: the name everything started from the owner's panel goes out under
-- (Config.Admin.hostName: Tyler), or the owner's house name when none is set.
function Names.host(): string
	local h = (Config.data.Admin :: any).hostName
	if type(h) == "string" and h ~= "" then
		return string.sub(h, 1, 40)
	end
	return Names.owner()
end

-- The host's own account, when the host is a co-owner (by their house name in Config.Admin
-- coOwners), else nil: whose avatar the Abuse show's giant wears.
function Names.hostId(): number?
	local h = (Config.data.Admin :: any).hostName
	local list = (Config.data.Admin :: any).coOwners
	if type(h) ~= "string" or h == "" or type(list) ~= "table" then
		return nil
	end
	for _, c in list do
		if type(c) == "table" and c.name == h and type(c.userId) == "number" and c.userId > 0 then
			return c.userId
		end
	end
	return nil
end

-- Letters and digits only, lower case (so "A.J.K.R" and "ajkr_" read the same as "AJKR").
local function plain(s: string): string
	return (string.gsub(string.lower(s), "[^%w]", ""))
end

-- The owner's UserId, as the server says (0: not known: nobody is taken for the owner).
local function ownerId(): number
	local n = tonumber(told("MaisonOwnerId"))
	return if n then n else 0
end
Names.ownerId = ownerId

-- Whether this is the owner: by UserId only (never a name, which can change or be copied). In
-- Studio, also the pretend test player the server marked as standing in for the owner; never on
-- a live server, whatever a guest's screen says about them.
function Names.isOwner(player: Player): boolean
	local id = ownerId()
	if id > 0 and player.UserId == id then
		return true
	end
	if Names.coOwner(player.UserId) ~= nil then
		return true
	end
	if not RunService:IsStudio() then
		return false
	end
	local ok, marked = pcall(function()
		return player:GetAttribute("MaisonAdmin")
	end)
	return ok and marked == true
end

-- The name to show for someone not (or no longer) in the house: by their UserId and the names
-- Roblox gives for them.
function Names.forUser(userId: number, displayName: string?, username: string?): string
	local id = ownerId()
	if id > 0 and userId == id then
		return Names.owner()
	end
	local co = Names.coOwner(userId)
	if co then
		return co
	end
	local shown = if displayName and displayName ~= "" then displayName else (username or "A guest")
	local mine = plain(Names.owner())
	if #mine > 0 and string.find(plain(shown), mine, 1, true) then
		return "@" .. (if username and username ~= "" then username else shown)
	end
	-- (Nobody passes for a co-owner either: a display name that is exactly a co-owner's house name.)
	local list = (Config.data.Admin :: any).coOwners
	if type(list) == "table" then
		for _, c in list do
			if type(c) == "table" and type(c.name) == "string" and plain(shown) == plain(c.name) then
				return "@" .. (if username and username ~= "" then username else shown)
			end
		end
	end
	return shown
end

-- The name to show for a guest in the house.
function Names.of(player: Player): string
	local co = Names.coOwner(player.UserId)
	if co then
		return co
	end
	if Names.isOwner(player) then
		return Names.owner()
	end
	return Names.forUser(player.UserId, player.DisplayName, player.Name)
end

return Names
