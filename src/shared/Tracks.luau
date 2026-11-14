--!strict
-- The house's circuits, for timed laps (and the Grand Prix's races on the first):
--   The Grand Boulevard   the street circuit in front of the house (shared/GrandPrix's geometry)
--   The Coastal Circuit   on Luxury Island: a ribbon of road along the airstrip, round the Jet
--                         Gallery and back past the gardens (its line below, from the island's
--                         origin; drawn as a smooth curve through the points, in this order)
-- Pure geometry, shared by the server (which times every lap and checks every gate) and every
-- screen. A lap counts only when its gates are passed in order, on the road, in a time no car can
-- beat; racing points climb the racing ranks.

local Config = require(script.Parent.Config)
local GrandPrix = require(script.Parent.GrandPrix)

local Tracks = {}

local rgb = Color3.fromRGB

export type Track = {
	id: string,
	name: string,
	line: string,
	place: string, -- "street" or "island"
	width: number,
	gates: number, -- the lap's gates, in order
	ace: number, -- seconds: the Lap Ace badge's mark
	badge: string,
}

Tracks.List = {
	{ id = "boulevard", name = "The Grand Boulevard", line = "The street circuit before the house: two straights, two hairpins, a boost pad on each straight.", place = "street", width = GrandPrix.TRACK.width, gates = 16, ace = 12, badge = "lapAce" },
	{ id = "coast", name = "The Coastal Circuit", line = "Luxury Island's road: down the airstrip, round the Jet Gallery and back through the gardens' bends.", place = "island", width = 28, gates = 16, ace = 11, badge = "coastAce" },
} :: { Track }
Tracks.byId = {} :: { [string]: Track }
for _, t in Tracks.List do
	Tracks.byId[t.id] = t
end

-- The Coastal Circuit's line, from the island's origin (on its lowland), driven in this order;
-- the start line is at the first point, heading east along the airstrip.
Tracks.COAST_POINTS = {
	Vector3.new(-40, 0, -178), Vector3.new(60, 0, -178), Vector3.new(124, 0, -162), Vector3.new(140, 0, -128),
	Vector3.new(124, 0, -96), Vector3.new(80, 0, -80), Vector3.new(34, 0, -90), Vector3.new(0, 0, -70),
	Vector3.new(-50, 0, -54), Vector3.new(-98, 0, -68), Vector3.new(-122, 0, -102), Vector3.new(-118, 0, -142),
	Vector3.new(-88, 0, -170),
} :: { Vector3 }
Tracks.COAST_GROUND = 6 -- the island's lowland (shared/Island.GROUND)
Tracks.ROAD = 0.3 -- the road's surface above it

-- The island's cars for the Coastal Circuit (they drive exactly like every other car).
Tracks.COAST_CARS = {
	{ id = "coastSpyder", name = "Riviera Spyder", paint = rgb(236, 236, 230), trim = rgb(36, 96, 168), glass = rgb(20, 24, 30), style = "hyper", track = "coast" },
	{ id = "coastCoral", name = "Coral Roadster", paint = rgb(232, 112, 104), trim = rgb(240, 232, 214), glass = rgb(24, 20, 20), style = "tourer", track = "coast" },
	{ id = "coastLagoon", name = "Lagoon GT", paint = rgb(40, 150, 160), trim = rgb(214, 176, 96), glass = rgb(16, 22, 24), style = "saloon", track = "coast" },
}

local function islandOrigin(): Vector3
	local o = ((Config.data :: any).Attractions.island or {}).origin
	if type(o) == "table" then
		return Vector3.new(o[1], o[2], o[3])
	end
	return Vector3.zero
end

-- The height a car's centre rides at on a track's surface.
function Tracks.ride(id: string): number
	if id == "coast" then
		return islandOrigin().Y + Tracks.COAST_GROUND + Tracks.ROAD + GrandPrix.RIDE
	end
	return GrandPrix.RIDE
end

-- The island's bay `i` for its cars: beside the start straight, nose east.
function Tracks.bay(i: number): CFrame
	local o = islandOrigin()
	local y = Tracks.ride("coast")
	local at = Vector3.new(o.X - 50 + (i - 1) * 18, y, o.Z - 150)
	return CFrame.lookAt(at, at + Vector3.new(1, 0, 0))
end

---------------------------------------------------------------------------------------------------
-- The Coastal Circuit's curve: a smooth line through its points, sampled every few studs.
---------------------------------------------------------------------------------------------------
type Curve = { samples: { Vector3 }, cum: { number }, length: number }
local coastCurve: Curve? = nil

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	-- (Every vector on the left of a product: the same sum, in a form every engine reads.)
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end

local function coast(): Curve
	local c = coastCurve
	if c then
		return c
	end
	local o = islandOrigin() + Vector3.new(0, Tracks.COAST_GROUND + Tracks.ROAD, 0)
	local pts = Tracks.COAST_POINTS
	local n = #pts
	local samples: { Vector3 } = {}
	for i = 1, n do
		local p0, p1, p2, p3 = pts[(i - 2) % n + 1], pts[i], pts[i % n + 1], pts[(i + 1) % n + 1]
		local steps = math.max(4, math.ceil((p2 - p1).Magnitude / 3))
		for k = 0, steps - 1 do
			table.insert(samples, o + catmull(p0, p1, p2, p3, k / steps))
		end
	end
	local cum = { 0 }
	for i = 2, #samples do
		cum[i] = cum[i - 1] + (samples[i] - samples[i - 1]).Magnitude
	end
	local made: Curve = { samples = samples, cum = cum, length = cum[#samples] + (samples[1] - samples[#samples]).Magnitude }
	coastCurve = made
	return made
end

-- (For a test that moves the island: the curve is worked out again.)
function Tracks.reset()
	coastCurve = nil
end

function Tracks.length(id: string): number
	if id == "coast" then
		return coast().length
	end
	return GrandPrix.length()
end

-- The point `s` round a track (on its surface) and the way the road runs there.
function Tracks.point(id: string, s: number): (Vector3, Vector3)
	if id ~= "coast" then
		local p, dir = GrandPrix.point(s)
		return p, dir
	end
	local c = coast()
	s = s % c.length
	local lo, hi = 1, #c.samples
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if c.cum[mid] <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local a = c.samples[lo]
	local b = c.samples[lo % #c.samples + 1]
	local seg = (b - a).Magnitude
	local f = if seg > 0 then (s - c.cum[lo]) / seg else 0
	local dir = if seg > 0 then (b - a) / seg else Vector3.new(1, 0, 0)
	return a:Lerp(b, f), dir
end

-- Where a position is on a track: the distance round (`s`) of the nearest point of the road's
-- middle, and how far from that middle it is (flat).
function Tracks.progress(id: string, pos: Vector3): (number, number)
	if id ~= "coast" then
		local s, off = GrandPrix.progress(pos)
		return s, off
	end
	local c = coast()
	local best, bestS = math.huge, 0
	local n = #c.samples
	local px, pz = pos.X, pos.Z
	for i = 1, n do
		local a = c.samples[i]
		local b = c.samples[i % n + 1]
		local dx, dz = b.X - a.X, b.Z - a.Z
		local l2 = dx * dx + dz * dz
		local t = if l2 > 0 then math.clamp(((px - a.X) * dx + (pz - a.Z) * dz) / l2, 0, 1) else 0
		local qx, qz = a.X + dx * t, a.Z + dz * t
		local d = (px - qx) * (px - qx) + (pz - qz) * (pz - qz)
		if d < best then
			best = d
			bestS = c.cum[i] + math.sqrt(l2) * t
		end
	end
	return bestS % c.length, math.sqrt(best)
end

-- Which of a track's gates `s` lies in (0 at the start line, then in order).
function Tracks.gate(id: string, s: number): number
	local t = Tracks.byId[id]
	local n = if t then t.gates else 16
	local L = Tracks.length(id)
	return math.clamp(math.floor((s % L) / L * n), 0, n - 1)
end

-- The quickest lap any car could drive (every stud at top speed): quicker than this is impossible.
function Tracks.quickest(id: string): number
	return Tracks.length(id) / GrandPrix.CAR.top
end

-- The road's samples (for building the Coastal Circuit's road).
function Tracks.samples(id: string): { Vector3 }
	if id == "coast" then
		return coast().samples
	end
	local out = {}
	local L = GrandPrix.length()
	for s = 0, L - 1, 4 do
		local p = GrandPrix.point(s)
		table.insert(out, p)
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Racing points and the racing ranks (a racer's rank paints the stripes of whatever car they
-- drive, for everyone to see)
---------------------------------------------------------------------------------------------------
Tracks.POINTS = { finish = 3, podium = 3, win = 6, best = 2, lap = 1, lapsADay = 20 }

export type Rank = { name: string, at: number, stripe: Color3?, line: string }
Tracks.RANKS = {
	{ name = "Rookie", at = 0, line = "Every legend starts on the back row." },
	{ name = "Club Racer", at = 40, stripe = rgb(236, 234, 228), line = "White racing stripes on any car you drive." },
	{ name = "Pro", at = 150, stripe = rgb(200, 206, 214), line = "Silver stripes on any car you drive." },
	{ name = "Ace", at = 400, stripe = rgb(240, 196, 90), line = "Gold stripes on any car you drive." },
	{ name = "Champion", at = 1000, stripe = rgb(206, 32, 52), line = "Crimson stripes on any car you drive." },
	{ name = "Legend", at = 2500, stripe = rgb(150, 110, 255), line = "Violet stripes, alive with light, on any car you drive." },
} :: { Rank }

-- The rank `points` stand at (its number, 1 = Rookie), and the next.
function Tracks.rank(points: number): (Rank, number, Rank?)
	local at = 1
	for i, r in Tracks.RANKS do
		if points >= r.at then
			at = i
		end
	end
	return Tracks.RANKS[at], at, Tracks.RANKS[at + 1]
end

-- A lap time as the boards show it: 11.48 (or 1:02.31).
function Tracks.clock(seconds: number): string
	if seconds >= 60 then
		local m = math.floor(seconds / 60)
		return string.format("%d:%05.2f", m, seconds - m * 60)
	end
	return string.format("%.2f", seconds)
end

return Tracks
