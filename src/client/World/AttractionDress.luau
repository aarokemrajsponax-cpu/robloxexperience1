--!strict
-- The holidays inside the attractions, on this guest's screen (World/HolidayFX dresses the house
-- itself): while a holiday is on and this guest is in an attraction (Steal a Luxe's residence,
-- the Maison Basement, the Executive Suite, Luxury Island, the Grand Ballroom), its pieces stand
-- round where they came in, never in the way: either side of the way in and a little ahead, each
-- set on the floor beneath it (looked for, never guessed) and only where the way to it is open.
--   All Hallows'  carved pumpkins, lit from inside
--   Thanksgiving  hay bales, corn and pumpkins
--   Christmas     trees and presents, candy canes
--   New Year      golden bells and gold presents
--   Valentine's   hearts of gold and great red hearts
--   St Patrick's  four-leaf clovers and pots of gold
--   Easter        giant painted eggs
-- Built on this screen alone, gone on leaving (or when the holiday ends); nothing here can be
-- touched or stood on, and nothing changes a score.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)

local AttractionDress = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB

local folder: Folder? = nil
local dressed: string? = nil -- "<attraction>:<holiday>"

-- The holiday on now, if any (the server's attributes on Workspace, as HolidayFX reads them).
function AttractionDress.holiday(): string?
	local now = Workspace:GetServerTimeNow()
	for _, id in HouseEvents.Holidays do
		local ends = Workspace:GetAttribute(HouseEvents.attribute(id))
		if type(ends) == "number" and ends > now then
			return id
		end
	end
	return nil
end

local function params(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	local f = folder
	if f then
		table.insert(skip, f)
	end
	p.FilterDescendantsInstances = skip
	return p
end

-- Where a piece may stand: the floor under `spot`, if the way to it from `from` is open and the
-- floor is near the height they came in at.
local function floorAt(from: Vector3, spot: Vector3, rp: RaycastParams): Vector3?
	local chest = Vector3.new(0, 2.5, 0)
	local blocked = Workspace:Raycast(from + chest, (spot + chest) - (from + chest), rp)
	if blocked then
		return nil
	end
	local hit = Workspace:Raycast(spot + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), rp)
	if not hit or math.abs(hit.Position.Y - (from.Y - 3)) > 6 then
		return nil
	end
	return hit.Position
end

-- One piece of the holiday, standing at `base` and facing `facing`.
local function piece(parent: Instance, holiday: string, base: Vector3, facing: Vector3, i: number)
	local look = CFrame.lookAt(base, base + facing)
	if holiday == "halloween" then
		HolidayProps.pumpkin(parent, base, 2.4 + (i % 3) * 0.5, facing, true, true)
	elseif holiday == "thanksgiving" then
		if i % 3 == 0 then
			HolidayProps.cornShock(parent, base, 6)
		elseif i % 3 == 1 then
			HolidayProps.hayBale(parent, look * CFrame.new(0, 1.1, 0), Vector3.new(4, 2.2, 2.4))
		else
			HolidayProps.pumpkin(parent, base, 2.2, facing, false, false, { rgb(214, 120, 40), rgb(190, 96, 28) })
		end
	elseif holiday == "christmas" then
		if i % 3 == 0 then
			HolidayProps.fir(parent, base, 9, false)
		elseif i % 3 == 1 then
			local wrap = HolidayProps.WRAPS[(i % #HolidayProps.WRAPS) + 1]
			HolidayProps.gift(parent, look * CFrame.new(0, 0.9, 0), Vector3.new(2.4, 1.8, 2.4), wrap[1], wrap[2])
		else
			HolidayProps.candyCane(parent, base, 4.5, facing)
		end
	elseif holiday == "newYear" then
		if i % 2 == 0 then
			HolidayProps.goldenBell(parent, look * CFrame.new(0, 1.6, 0), 2.6)
		else
			HolidayProps.gift(parent, look * CFrame.new(0, 0.9, 0), Vector3.new(2.2, 1.8, 2.2), rgb(232, 182, 70), rgb(30, 26, 22))
		end
	elseif holiday == "valentine" then
		if i % 2 == 0 then
			HolidayProps.heartOfGold(parent, look * CFrame.new(0, 2.2, 0), 3)
		else
			local m = Instance.new("Model")
			m.Name = "Heart"
			m.Parent = parent
			HolidayProps.heart(m, "Heart", look * CFrame.new(0, 2.6, 0), 4.2, 1, rgb(214, 40, 70), Enum.Material.SmoothPlastic)
		end
	elseif holiday == "stPatrick" then
		if i % 2 == 0 then
			HolidayProps.clover(parent, look * CFrame.new(0, 2.4, 0), 3.4, true)
		else
			HolidayProps.potOfGold(parent, look * CFrame.new(0, 0, 0), 2.6)
		end
	elseif holiday == "easter" then
		HolidayProps.egg(parent, look, 3.2 + (i % 2) * 0.8, HolidayProps.EGGS[(i % #HolidayProps.EGGS) + 1], false)
	end
end

AttractionDress.piece = piece -- (for tests: each holiday's pieces, built)

local function clear()
	local f = folder
	folder = nil
	dressed = nil
	if f then
		f:Destroy()
	end
end

-- Dresses the place this guest has just come into, round where they stand.
local function dress(attraction: string, holiday: string)
	clear()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "AttractionDress"
	f.Parent = Workspace
	folder = f
	dressed = attraction .. ":" .. holiday
	local from = root.Position
	local ahead = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	ahead = if ahead.Magnitude > 0.01 then ahead.Unit else Vector3.new(0, 0, 1)
	local side = Vector3.new(-ahead.Z, 0, ahead.X)
	local rp = params()
	local placed = 0
	-- Either side of the way in, then further along it, then a wider ring.
	local spots: { { number } } = {
		{ -8, 3 }, { 8, 3 }, { -9, 12 }, { 9, 12 }, { -12, 22 }, { 12, 22 }, { -16, 6 }, { 16, 6 }, { -14, 32 }, { 14, 32 },
	}
	for i, s in spots do
		local spot = from + side * s[1] + ahead * s[2]
		local floor = floorAt(from, spot, rp)
		if floor then
			-- (Facing back towards the way in, as if to greet them.)
			local facing = Vector3.new(from.X - floor.X, 0, from.Z - floor.Z)
			pcall(piece, f, holiday, floor, if facing.Magnitude > 0.01 then facing.Unit else -ahead, i)
			placed += 1
		end
		if placed >= 8 then
			break
		end
	end
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

local function follow()
	local id = player:GetAttribute(AttractionList.ATTRIBUTE)
	local holiday = AttractionDress.holiday()
	if type(id) ~= "string" or not holiday then
		if dressed then
			clear()
		end
		return
	end
	local want = id .. ":" .. holiday
	if dressed ~= want then
		-- (A moment after arriving: they're standing where they came in.)
		task.delay(1.2, function()
			if player:GetAttribute(AttractionList.ATTRIBUTE) == id and AttractionDress.holiday() == holiday and dressed ~= want then
				dress(id, holiday)
			end
		end)
	end
end
AttractionDress.follow = follow

function AttractionDress.dressed(): string?
	return dressed
end

function AttractionDress.start()
	player:GetAttributeChangedSignal(AttractionList.ATTRIBUTE):Connect(follow)
	for _, id in HouseEvents.Holidays do
		Workspace:GetAttributeChangedSignal(HouseEvents.attribute(id)):Connect(follow)
	end
	task.spawn(function()
		-- (A holiday ends at a time, not with a change: look now and then.)
		while true do
			task.wait(5)
			follow()
		end
	end)
	follow()
end

return AttractionDress
