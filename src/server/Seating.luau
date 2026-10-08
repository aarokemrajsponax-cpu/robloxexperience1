--!strict
-- Sitting down anywhere in the house: the sofas and chairs of the public rooms, the Terrace's
-- loungers, and every seat in a guest's own Suite. (The sorting tables keep their own chairs.)
--
-- A guest's screen walks them up to a seat and asks; the server checks the seat is real, near
-- and free, and sits them in a seat of their own, made for the moment at that place and taken
-- away when they get up, so two guests in their own Suites (which share one place in the world)
-- never fight over a sofa. Nothing a guest's screen sends is trusted: a public seat is named by
-- the number the server gave it, a Suite seat by its spot and which seat of the piece it is, and
-- the server works out where that is from the guest's own Suite.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Furniture = require(ReplicatedStorage.Shared.Furniture)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Suite = require(ReplicatedStorage.Shared.Suite)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Seating = {}

local REACH = 14 -- studs from a guest to the seat they ask for

-- The public seats, by the number each was given.
local spots: { [number]: BasePart } = {}
local nextId = 0
-- Who sits where: the guest's own seat, and the public spot it took (if any).
type Sitting = { seat: Seat, spot: BasePart? }
local sitting: { [Player]: Sitting } = {}
local taken: { [BasePart]: Player } = {}

local folder: Folder? = nil
local function seatsFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "GuestSeats"
	nf.Parent = Workspace
	folder = nf
	return nf
end

local function register(part: Instance)
	if part:IsA("BasePart") and part.Name == "SitSpot" and part:GetAttribute("SeatId") == nil then
		nextId += 1
		part:SetAttribute("SeatId", nextId)
		spots[nextId] = part
		CollectionService:AddTag(part, "SitSpot")
	end
end

local function characterOf(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

-- Gets a guest up from their seat (if they're in one of ours), freeing it.
function Seating.release(player: Player)
	local s = sitting[player]
	if not s then
		return
	end
	sitting[player] = nil
	if s.spot and taken[s.spot] == player then
		taken[s.spot] = nil
		s.spot:SetAttribute("Taken", nil)
	end
	local weld = s.seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	s.seat:Destroy()
end

-- Whether a guest sits in one of the house's seats now.
function Seating.isSeated(player: Player): boolean
	return sitting[player] ~= nil
end

-- Sits `player` at `at` (where they sit: the top of the seat, facing its front).
local function sitAt(player: Player, humanoid: Humanoid, at: CFrame, spot: BasePart?): boolean
	Seating.release(player)
	local seat = Instance.new("Seat")
	seat.Name = "GuestSeat"
	seat.Size = Vector3.new(2, 0.2, 2)
	seat.CFrame = at * CFrame.new(0, -0.1, 0)
	seat.Anchored = true
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.Transparency = 1
	seat:SetAttribute("UserId", player.UserId)
	seat.Parent = seatsFolder()
	sitting[player] = { seat = seat, spot = spot }
	if spot then
		taken[spot] = player
		spot:SetAttribute("Taken", player.UserId)
	end
	seat:Sit(humanoid)
	-- Up again (a jump, or anything else): the seat goes.
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == nil then
			task.defer(function()
				local s = sitting[player]
				if s and s.seat == seat then
					Seating.release(player)
				elseif seat.Parent then
					seat:Destroy()
				end
			end)
		end
	end)
	return true
end

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 4, 0)
	if not r then
		RemoteGuard.reject(player, "sitAsk", "malformed")
		return { ok = false }
	end
	if r.op == "stand" then
		local s = sitting[player]
		local humanoid = characterOf(player)
		Seating.release(player)
		if s and humanoid then
			humanoid.Sit = false
		end
		return { ok = true }
	elseif r.op ~= "sit" then
		return { ok = false }
	end
	local humanoid, root = characterOf(player)
	if not humanoid or not root then
		return { ok = false, why = "Not just now." }
	end
	local at: CFrame? = nil
	local spot: BasePart? = nil
	local id = RemoteGuard.number(r.seat, 1, 1e6, true)
	if id then
		-- A public seat: real, still in the house, and free.
		local part = spots[id]
		if not part or not part:IsDescendantOf(Workspace) then
			return { ok = false, why = "That seat isn't there any more." }
		end
		-- The Terrace cabana is the Gold Key's.
		if part:GetAttribute("GoldKey") == true then
			local data = Profiles.get(player)
			if not data or not data.goldKey then
				return { ok = false, why = "The cabana is for Gold Key holders." }
			end
		end
		local holder = taken[part]
		if holder and holder ~= player and holder.Parent then
			return { ok = false, why = "Someone is sitting there." }
		end
		spot = part
		at = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	else
		-- A seat of the guest's own Suite: worked out from what stands in their Suite.
		local spotId = RemoteGuard.string(r.suite, 40)
		local index = RemoteGuard.number(r.index, 1, 16, true)
		local data = Profiles.get(player)
		if not spotId or not index or not data then
			RemoteGuard.reject(player, "sitAsk", "malformed")
			return { ok = false }
		end
		if Layout.zoneAt(root.Position) ~= "suite" then
			return { ok = false, why = "That's in your Suite." }
		end
		local style = Suite.pieces(data.suite, data.goldKey)[spotId]
		local kind = style and Suite.kindOf(spotId, style)
		local frame = Layout.Suite.spots[spotId]
		if not style or not kind or not frame then
			return { ok = false, why = "Nothing stands there to sit on." }
		end
		local seats = Furniture.seatsOf(kind, style, Layout.SUITE_FURNITURE)
		local seatAt = seats[index]
		if not seatAt then
			return { ok = false, why = "Nothing stands there to sit on." }
		end
		at = frame * seatAt
	end
	local target = at :: CFrame
	if (target.Position - root.Position).Magnitude > REACH then
		return { ok = false, why = "Come a little closer." }
	end
	return { ok = sitAt(player, humanoid, target, spot) }
end

function Seating.start()
	local maison = Workspace:FindFirstChild("Maison")
	if maison then
		for _, d in maison:GetDescendants() do
			register(d)
		end
		maison.DescendantAdded:Connect(register)
	end
	RemoteGuard.invoke(Remotes.func("SitAsk"), "sitAsk", onAsk)
	Players.PlayerRemoving:Connect(Seating.release)
	-- A guest who dies or changes character in a seat leaves it.
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterRemoving:Connect(function()
			Seating.release(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterRemoving:Connect(function()
			Seating.release(player)
		end)
	end
end

return Seating
