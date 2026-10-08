--!strict
-- One folder of remotes. The server creates them; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER = "MaisonRemotes"

Remotes.Events = {
	"Table", -- server -> client table state; client -> server table actions
	"Dialogue", -- server -> client lines and choices
	"DialogueChoice", -- client -> server
	"Guest", -- server -> client profile / settings / season
	"Setting", -- client -> server setting change
	"Funnel", -- client -> server first-evening funnel steps that only the client can see
	"Board", -- server -> client leaderboard refresh
	"Shop", -- server -> client: what you own and wear, Gilt, the Ledger, gifts
	"Curio", -- server -> client: a curio found or given, your Gems, a trade's state
	"Salute", -- server -> client: a salute for the whole house; the owner's events
	"Errors", -- server -> the owner's screen: anything that broke on the server
	"Tour", -- server -> client: the Concierge's tour starts; client -> server: it started, it ended
	"Purchase", -- server -> client: perks and credits, decrees, rains, revive results
	"PianoNote", -- client -> server: a note played at the Foyer's piano; server -> clients: play it
}

Remotes.Functions = {
	"GetBoard",
	"QuickSit",
	"ShopAsk", -- client -> server: the Boutique's shelves, choosing, equipping, the Ledger
	"AdminAsk", -- client -> server: the owner's House controls (checked on the server every time)
	"PerkAsk", -- client -> server: perks (prompt by product key, write a decree, start a rain)
	"PianoAsk", -- client -> server: the Foyer's piano (sit, get up, buy time)
	"SitAsk", -- client -> server: sit on a seat in the house or your Suite, or get up
	"BarAsk", -- client -> server: the Terrace bar (the menu, order a treat, put it down)
	"CurioAsk", -- client -> server: your curios, stars, the Cabinet (curios for Gems), Gem packs
	"TradeAsk", -- client -> server: trading curios with another guest
	"SpectacleAsk", -- client -> server: Suite spectacles (the list, buy one, play one)
	"SuiteAsk", -- client -> server: your friends' Suites (the list, visit one, go home)
}

local folder: Folder? = nil

local function getFolder(): Folder
	local cached = folder
	if cached then
		return cached
	end
	local result: Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER)
		if existing and existing:IsA("Folder") then
			result = existing
		else
			result = Instance.new("Folder")
			result.Name = FOLDER
			result.Parent = ReplicatedStorage
		end
		for _, name in Remotes.Events do
			if not result:FindFirstChild(name) then
				local e = Instance.new("RemoteEvent")
				e.Name = name
				e.Parent = result
			end
		end
		for _, name in Remotes.Functions do
			if not result:FindFirstChild(name) then
				local f = Instance.new("RemoteFunction")
				f.Name = name
				f.Parent = result
			end
		end
	else
		result = ReplicatedStorage:WaitForChild(FOLDER) :: Folder
	end
	folder = result
	return result
end

function Remotes.event(name: string): RemoteEvent
	local f = getFolder()
	return f:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	local f = getFolder()
	return f:WaitForChild(name) :: RemoteFunction
end

return Remotes
