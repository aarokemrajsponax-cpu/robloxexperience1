--!nocheck
-- (Build 103) Sitting down (server/Seating) under Lune in the house's test harness: the seats of
-- the attractions (the Grand Ballroom's sofas, benches and bar stools stand in Workspace's
-- Attractions folder, not the house's) sit a guest like the house's own; a copy of a seat (a
-- private wing is a copy of the house's Suite) is a seat of its own, not its original; a seat
-- too far, taken, or not there is refused with a reason, never in silence; standing frees it.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/seats.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local module = H.module
local Instance, Vector3, CFrame = H.Instance, H.Vector3, H.CFrame

local Furniture = module("ReplicatedStorage", "Shared", "Furniture")
local Remotes = module("ReplicatedStorage", "Shared", "Remotes")
local Seating = module("ServerScriptService", "Server", "Seating")
local Workspace = H.game:GetService("Workspace")

-- The house, with a bench in a room.
local maison = Instance.new("Folder")
maison.Name = "Maison"
local room = Instance.new("Model")
room.Name = "Library"
room.Parent = maison
Furniture.seatsOn(room, "BenchSeats", { CFrame.new(0, 2, 0), CFrame.new(3, 2, 0) }, "The bench", 1.6)
maison.Parent = Workspace

-- The attractions, in their own folder: a Ballroom sofa (built as the Ballroom builds it) and a
-- bar stool.
local attractions = Instance.new("Folder")
attractions.Name = "Attractions"
local gala = Instance.new("Model")
gala.Name = "Gala"
gala.Parent = attractions
Furniture.build("sofa", gala, CFrame.lookAt(Vector3.new(200, 0, 0), Vector3.new(200, 0, 10)), { model = "chesterfield" }, false)
Furniture.seatsOn(gala, "StoolSeats", { CFrame.new(220, 3, 0) * CFrame.Angles(0, math.pi, 0) }, "The bar stool", 1.6)
attractions.Parent = Workspace

-- A copy of the house's bench (as a private wing copies the Suite), its seats carrying their
-- original's numbers.
Seating.start()
local wing = room:Clone()
wing.Name = "WingLibrary"
for _, d in wing:GetDescendants() do
	if d:IsA("BasePart") then
		d.CFrame = d.CFrame + Vector3.new(0, 2400, 0)
	end
end
wing.Parent = Workspace
Seating.start() -- (the harness has no DescendantAdded: a second look finds the copy, as the game's signal would)

local function spotsIn(parent)
	local out = {}
	for _, d in parent:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "SitSpot" then
			table.insert(out, d)
		end
	end
	return out
end

local ask = Remotes.funcs.SitAsk.OnServerInvoke
local function sitAs(player, request)
	advance(0.6) -- (a guest's taps, inside the sitting rate)
	local r
	run(function()
		r = ask(player, request)
	end)
	return r
end

local ann = H.guest("Ann", 9101)
ann.Character = ann.body
local bob = H.guest("Bob", 9102)
bob.Character = bob.body

local houseSpots = spotsIn(room)
local galaSpots = spotsIn(gala)
local wingSpots = spotsIn(wing)
check("the house's bench has its two seats, numbered", #houseSpots == 2 and type(houseSpots[1]:GetAttribute("SeatId")) == "number")
check("the Ballroom's sofa and bar stool (outside the house's folder) are numbered seats too", #galaSpots >= 2 and (function()
	for _, s in galaSpots do
		if type(s:GetAttribute("SeatId")) ~= "number" then
			return false
		end
	end
	return true
end)())
check("...every one with a Sit prompt", (function()
	local n = 0
	for _, d in gala:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "SeatPrompt" then
			n += 1
		end
	end
	return n == 2
end)())
check("a copy of a seat is given a number of its own, never its original's", #wingSpots == 2 and (function()
	local seen = {}
	for _, s in houseSpots do
		seen[s:GetAttribute("SeatId")] = true
	end
	for _, s in wingSpots do
		local id = s:GetAttribute("SeatId")
		if type(id) ~= "number" or seen[id] then
			return false
		end
	end
	return true
end)())

-- Ann walks up to the Ballroom's sofa and sits.
local sofaSeat = galaSpots[1]
ann.root.CFrame = sofaSeat.CFrame * CFrame.new(0, 0, -2)
local r = sitAs(ann, { op = "sit", seat = sofaSeat:GetAttribute("SeatId") })
check("a Ballroom sofa sits the guest", type(r) == "table" and r.ok == true and Seating.isSeated(ann) and ann.humanoid.SeatPart ~= nil)
check("...and the seat is marked taken", sofaSeat:GetAttribute("Taken") == ann.UserId)
bob.root.CFrame = sofaSeat.CFrame * CFrame.new(0, 0, -2)
r = sitAs(bob, { op = "sit", seat = sofaSeat:GetAttribute("SeatId") })
check("someone else asking for the same seat is told it's taken", type(r) == "table" and r.ok == false and r.why == "Someone is sitting there.")
r = sitAs(ann, { op = "stand" })
check("standing up frees it", type(r) == "table" and r.ok == true and not Seating.isSeated(ann) and sofaSeat:GetAttribute("Taken") == nil)
r = sitAs(bob, { op = "sit", seat = sofaSeat:GetAttribute("SeatId") })
check("...for the next guest", type(r) == "table" and r.ok == true and Seating.isSeated(bob))
sitAs(bob, { op = "stand" })

-- The bar stool.
local stool = nil
for _, s in galaSpots do
	if s.Parent.Name == "StoolSeats" then
		stool = s
	end
end
ann.root.CFrame = stool.CFrame * CFrame.new(0, 0, -2)
r = sitAs(ann, { op = "sit", seat = stool:GetAttribute("SeatId") })
check("a bar stool sits the guest", type(r) == "table" and r.ok == true and Seating.isSeated(ann))
sitAs(ann, { op = "stand" })

-- A wing's copy of the bench, from up in the wing.
local wingSeat = wingSpots[1]
ann.root.CFrame = wingSeat.CFrame * CFrame.new(0, 0, -2)
r = sitAs(ann, { op = "sit", seat = wingSeat:GetAttribute("SeatId") })
check("a seat in a copy (a private wing) sits the guest where it really is", type(r) == "table" and r.ok == true and Seating.isSeated(ann))
sitAs(ann, { op = "stand" })

-- Refusals always say why.
ann.root.CFrame = CFrame.new(500, 0, 500)
r = sitAs(ann, { op = "sit", seat = sofaSeat:GetAttribute("SeatId") })
check("too far: 'Come a little closer.'", type(r) == "table" and r.ok == false and r.why == "Come a little closer.")
r = sitAs(ann, { op = "sit", seat = 999999 })
check("a seat that isn't there: said so", type(r) == "table" and r.ok == false and r.why == "That seat isn't there any more.")
r = sitAs(ann, { op = "sit" })
check("a request naming no seat: refused with a reason, not in silence", type(r) == "table" and r.ok == false and type(r.why) == "string")

H.finish()
