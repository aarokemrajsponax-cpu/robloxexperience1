--!strict
-- Things that flutter down, drawn on this screen only: gold leaf (the Shower of Gold Leaf, the
-- Golden Transformation) and rose petals (the Encore). Each flake is a thin leaf of metal or a petal
-- that sways, turns over and over as it falls (catching the light as gold leaf does), and drifts
-- round a centre that can move (a guest walking on). Flakes that land, or are left behind, start
-- again from above until the shower ends; then the last of them fall and go.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Flakes = {}

export type Spec = {
	seconds: number,
	centre: () -> Vector3?, -- where they fall round (nil: nowhere just now)
	colours: { Color3 },
	material: Enum.Material?,
	reflectance: number?,
	size: Vector3?, -- one flake
	count: number, -- falling at once
	radius: number, -- how far round the centre
	height: number, -- how high above it they start
	fall: number, -- studs a second
	below: number?, -- how far under the centre they go
}

type Flake = { part: Part, pos: Vector3, phase: number, sway: number, spin: Vector3, rate: number, speed: number }

local function holder(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

-- Starts a shower; returns a function that ends it early.
function Flakes.fall(spec: Spec): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "Flakes"
	folder.Parent = holder()
	local flakes: { Flake } = {}
	local rng = Random.new()
	local size = spec.size or Vector3.new(0.5, 0.03, 0.4)
	local below = spec.below or 5
	local function place(f: Flake, centre: Vector3, anywhere: boolean)
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * spec.radius
		local y = if anywhere then rng:NextNumber(-below, spec.height) else spec.height + rng:NextNumber(0, 3)
		f.pos = centre + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
	end
	local start = (spec.centre()) or Vector3.zero
	for i = 1, spec.count do
		local p = Instance.new("Part")
		p.Name = "Flake"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size * rng:NextNumber(0.75, 1.25)
		p.Material = spec.material or Enum.Material.Metal
		p.Reflectance = spec.reflectance or 0.35
		p.Color = spec.colours[(i - 1) % #spec.colours + 1]
		p.Parent = folder
		local f: Flake = {
			part = p,
			pos = Vector3.zero,
			phase = rng:NextNumber(0, math.pi * 2),
			sway = rng:NextNumber(0.6, 1.6),
			spin = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit,
			rate = rng:NextNumber(1.5, 4),
			speed = spec.fall * rng:NextNumber(0.7, 1.3),
		}
		place(f, start, true)
		table.insert(flakes, f)
	end
	local t = 0
	local ending = false
	local connection: RBXScriptConnection? = nil
	local function finish()
		local c = connection
		if c then
			c:Disconnect()
			connection = nil
		end
		folder:Destroy()
	end
	connection = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		if t >= spec.seconds then
			ending = true
		end
		local centre = spec.centre()
		local alive = 0
		for _, f in flakes do
			local p = f.part
			if p.Parent == nil then
				continue
			end
			f.pos -= Vector3.new(0, f.speed * dt, 0)
			local gone = centre ~= nil and (f.pos.Y < centre.Y - below or (Vector3.new(f.pos.X, 0, f.pos.Z) - Vector3.new(centre.X, 0, centre.Z)).Magnitude > spec.radius * 1.6)
			if gone and centre then
				if ending then
					p.Parent = nil
					continue
				end
				place(f, centre, false)
			end
			alive += 1
			-- A leaf falls in swings, turning over as it goes.
			local swing = Vector3.new(math.sin(t * f.sway + f.phase) * 1.4, 0, math.cos(t * f.sway * 0.8 + f.phase) * 1.1)
			p.CFrame = CFrame.new(f.pos + swing) * CFrame.fromAxisAngle(f.spin, t * f.rate + f.phase)
		end
		if ending and (alive == 0 or t > spec.seconds + 8) then
			finish()
		end
	end)
	return function()
		ending = true
	end
end

return Flakes
