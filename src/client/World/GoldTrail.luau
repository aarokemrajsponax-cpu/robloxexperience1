--!strict
-- A golden trail on the floor, drawn on this guest's screen only: small glowing gold discs along a
-- route (a list of points at the feet's height), a shimmer running through them in the direction
-- of travel. The Concierge's tour lays one from where he is to the next stop (Build 87), so the
-- way is on the floor as well as in the air. One trail at a time; nothing on it collides, can be
-- touched or is hit by a ray.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GoldTrail = {}

local GAP = 3.2 -- studs between discs
local MOST = 70 -- discs at most (the rest of a long route is in the arc of light)
local GOLD = Color3.fromRGB(255, 206, 110)

local folder: Folder? = nil
local discs: { BasePart } = {}
local used = 0
local connection: RBXScriptConnection? = nil

-- (For tests: how many discs are showing.)
function GoldTrail.count(): number
	return used
end

local function disc(i: number): BasePart
	local d = discs[i]
	if d then
		return d
	end
	local f = folder
	if not f then
		local made = Instance.new("Folder")
		made.Name = "MaisonGoldTrail"
		made.Parent = Workspace
		folder = made
		f = made
	end
	local p = Instance.new("Part")
	p.Name = "TrailDisc"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.08, 0.9, 0.9)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Transparency = 1
	p.Parent = f
	discs[i] = p
	return p
end

local function shimmer()
	local t = os.clock()
	for i = 1, used do
		local d = discs[i]
		if d then
			-- (The bright crest runs from the first disc to the last: the way to go.)
			local wave = math.sin(t * 5 - i * 0.55)
			d.Transparency = 0.12 + 0.5 * (0.5 - 0.5 * wave)
		end
	end
end

-- The trail along `points` (at least two), each disc dropped to `floor` if given (the floor under
-- a point: each step of a stair), else at the point's own height.
function GoldTrail.set(points: { Vector3 }, floor: ((Vector3) -> number)?)
	local n = 0
	local carry = 0
	for k = 1, #points - 1 do
		local a, b = points[k], points[k + 1]
		local seg = (b - a)
		local len = Vector3.new(seg.X, 0, seg.Z).Magnitude
		local s = GAP - carry
		while s <= len and n < MOST do
			local p = a:Lerp(b, if len > 0 then s / len else 0)
			local y = if floor then floor(p) else p.Y
			n += 1
			local d = disc(n)
			d.CFrame = CFrame.new(p.X, y + 0.08, p.Z) * CFrame.Angles(0, 0, math.rad(90))
			s += GAP
		end
		carry = math.max(0, len - (s - GAP))
		if n >= MOST then
			break
		end
	end
	for i = n + 1, used do
		local d = discs[i]
		if d then
			d.Transparency = 1
		end
	end
	used = n
	if not connection and n > 0 then
		connection = RunService.Heartbeat:Connect(shimmer)
	end
	shimmer()
end

function GoldTrail.clear()
	for i = 1, used do
		local d = discs[i]
		if d then
			d.Transparency = 1
		end
	end
	used = 0
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return GoldTrail
