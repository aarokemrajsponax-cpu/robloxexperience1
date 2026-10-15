--!strict
-- Going straight to a place in the house: How to play's Go keys, and the what's-next card's "Take
-- me there". Only to the places named here (never a point a screen names), never from a table, a
-- seat or a car, and not twice in a moment. The server moves the guest (Integrity.teleport, so
-- the watch on how guests move knows it was the house).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GrandPrix = require(ReplicatedStorage.Shared.GrandPrix)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Integrity = require(script.Parent.Integrity)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Travel = {}

-- Set by Main: whether the guest is at a table (in any room).
Travel.isBusy = function(_player: Player): boolean
	return false
end

local GAP = 2 -- seconds between two journeys

export type Place = { name: string, at: CFrame }

local function facing(at: Vector3, toward: Vector3): CFrame
	return CFrame.lookAt(at, Vector3.new(toward.X, at.Y, toward.Z))
end

local function stop(id: string): any
	for _, s in Layout.Tour.stops do
		if s.id == id then
			return s
		end
	end
	return nil
end

-- The places (the house is grown by Layout.SCALE already; the street's circuit is laid in world
-- units). Rooms are met at their doors, facing in.
local function places(): { [string]: Place }
	local out: { [string]: Place } = {}
	local function fromStop(id: string, name: string)
		local s = stop(id)
		if s then
			out[id] = { name = name, at = facing(s.stand, s.face) }
		end
	end
	out.foyer = { name = "The Foyer", at = Layout.Foyer.spawn }
	-- (The Concierge: where guests arrive, in front of the desk, facing the Concierge.)
	out.concierge = { name = "The Concierge", at = Layout.Foyer.spawn }
	out.salon = { name = "The Salon", at = facing(Layout.Salon.arrival, Layout.Salon.arrival - Vector3.new(10, 0, 0)) }
	out.velvet = { name = "The Velvet Room", at = facing(Layout.Velvet.arrival, Layout.Velvet.arrival - Vector3.new(10, 0, 0)) }
	out.obsidian = { name = "The Obsidian Room", at = facing(Layout.Obsidian.arrival, Layout.Obsidian.arrival + Vector3.new(10, 0, 0)) }
	out.midnight = { name = "The Midnight Room", at = facing(Layout.Midnight.arrival, Layout.Midnight.arrival + Vector3.new(10, 0, 0)) }
	fromStop("tonight", "Tonight's table")
	fromStop("vault", "The Vault")
	fromStop("boutique", "The Boutique")
	fromStop("library", "The Library")
	fromStop("ballroom", "The Ballroom")
	fromStop("terrace", "The Terrace")
	fromStop("suite", "Your Suite")
	-- The Grand Prix: on the pavement by the garage, looking at the cars.
	local first = GrandPrix.bay(1).Position
	out.grandPrix = { name = "The Grand Prix", at = facing(Vector3.new(first.X + 8, 4, first.Z + 10), Vector3.new(first.X + 8, 4, first.Z)) }
	return out
end

local PLACES: { [string]: Place } = places()
local last: { [Player]: number } = {}
local remote: RemoteEvent? = nil

function Travel.places(): { [string]: Place }
	return PLACES
end

-- Takes the guest to the place `id`. Returns whether it did, and why not.
function Travel.go(player: Player, id: string): (boolean, string?)
	local place = PLACES[id]
	if not place then
		return false, "There's no such place."
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root then
		return false, "Not just now."
	end
	if (humanoid :: any).SeatPart ~= nil or Travel.isBusy(player) then
		return false, "Stand up first."
	end
	local t = os.clock()
	if last[player] and t - (last[player] :: number) < GAP then
		return false, "One moment."
	end
	last[player] = t
	Integrity.teleport(player, character :: Model, place.at + Vector3.new(0, 1, 0))
	return true, nil
end

function Travel.start()
	remote = Remotes.event("Travel") :: any
	RemoteGuard.event(remote :: RemoteEvent, "travel", function(player: Player, message: unknown)
		if type(message) ~= "table" then
			return
		end
		local m = message :: { [string]: unknown }
		if m.op ~= "go" or type(m.place) ~= "string" or #(m.place :: string) > 24 then
			return
		end
		local id = m.place :: string
		local ok, why = Travel.go(player, id)
		local r = remote :: RemoteEvent
		if ok then
			r:FireClient(player, { op = "arrived", place = id, name = PLACES[id].name })
		else
			r:FireClient(player, { op = "refused", why = why })
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		last[player] = nil
	end)
end

return Travel
