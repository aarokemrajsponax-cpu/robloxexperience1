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

-- The owner's house name.
function Names.owner(): string
	local name = told("MaisonOwnerName")
	if type(name) == "string" and name ~= "" then
		return name
	end
	local n = Config.data.Admin.ownerName
	return if type(n) == "string" and n ~= "" then n else "AJKR"
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
	local shown = if displayName and displayName ~= "" then displayName else (username or "A guest")
	local mine = plain(Names.owner())
	if #mine > 0 and string.find(plain(shown), mine, 1, true) then
		return "@" .. (if username and username ~= "" then username else shown)
	end
	return shown
end

-- The name to show for a guest in the house.
function Names.of(player: Player): string
	if Names.isOwner(player) then
		return Names.owner()
	end
	return Names.forUser(player.UserId, player.DisplayName, player.Name)
end

return Names
