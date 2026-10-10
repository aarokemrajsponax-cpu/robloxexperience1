--!strict
-- The name the house shows for a guest, wherever it shows one (headlines, giveaways, gifts,
-- nameplates, chat, boards, trades, notices).
--   The owner always goes by their house name, AJKR (Config.Admin.ownerName), never their Roblox
--   username: whatever they do in the house, it's AJKR doing it.
--   Nobody else can pass for the owner: a guest whose display name reads as the owner's house name
--   ("AJKR", "a.j.k.r", "AJKR_") is shown by their @username instead.

local Config = require(script.Parent.Config)

local Names = {}

-- The owner's house name.
function Names.owner(): string
	local n = Config.data.Admin.ownerName
	return if type(n) == "string" and n ~= "" then n else "AJKR"
end

-- Letters and digits only, lower case (so "A.J.K.R" and "ajkr_" read the same as "AJKR").
local function plain(s: string): string
	return (string.gsub(string.lower(s), "[^%w]", ""))
end

local function ownerId(): number
	local id = Config.data.Admin.ownerUserId
	return if type(id) == "number" then id else 0
end

-- Whether this is the owner: by UserId (never a name, which can change), or the stand-in owner
-- the server has marked (Studio's first test player, or a group's owner).
function Names.isOwner(player: Player): boolean
	local id = ownerId()
	if id > 0 and player.UserId == id then
		return true
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
