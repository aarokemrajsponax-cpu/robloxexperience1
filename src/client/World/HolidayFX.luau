--!strict
-- How the holidays look on this screen while one is on (the server runs them: AdminService):
--   All Hallows'   a violet-and-orange evening, bats wheeling overhead
--   Thanksgiving   amber light, autumn leaves falling
--   Christmas      snow falling, a cool clear light
--   New Year       a gold glow, and confetti every so often
--   Valentine's    a rosy light, hearts drifting down
--   St Patrick's   a green light, and a rainbow arching down to the pot of gold
--   Easter         soft pastel light, petals on the air
-- And for every hunt: a tall beam of gold light over its golden prize, so it can be found from
-- across the house. Nothing here is frightening: the All Hallows' bats are cartoon bats.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HouseEvents = require(game:GetService("ReplicatedStorage").Shared.HouseEvents)
local Flakes = require(script.Parent.Flakes)

local HolidayFX = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB

local function holder(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

local function rootPos(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- A soft tint over the picture while it's on.
local function tint(colour: Color3, amount: number, saturation: number?): () -> ()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "HolidayTint"
	cc.TintColor = Color3.new(1, 1, 1):Lerp(colour, amount)
	cc.Saturation = saturation or 0
	cc.Parent = Lighting
	return function()
		cc:Destroy()
	end
end

-- Glyphs drifting down round the guest (hearts), or wheeling overhead (bats).
local function glyphs(glyph: string, count: number, mode: "fall" | "wheel"): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "HolidayGlyphs"
	folder.Parent = holder()
	local rng = Random.new()
	type G = { part: Part, offset: Vector3, speed: number, phase: number }
	local list: { G } = {}
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		local bb = Instance.new("BillboardGui")
		local s = rng:NextNumber(1.4, 2.6)
		bb.Size = UDim2.fromScale(s, s)
		bb.LightInfluence = 0
		bb.MaxDistance = 140
		bb.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.TextScaled = true
		t.Text = glyph
		t.Parent = bb
		p.Parent = folder
		table.insert(list, { part = p, offset = Vector3.new(rng:NextNumber(-30, 30), rng:NextNumber(0, 30), rng:NextNumber(-30, 30)), speed = rng:NextNumber(2, 5), phase = rng:NextNumber(0, math.pi * 2) })
	end
	local conn = RunService.RenderStepped:Connect(function(dt: number)
		local centre = rootPos()
		if not centre then
			return
		end
		local t = os.clock()
		for _, g in list do
			if mode == "fall" then
				local y = g.offset.Y - g.speed * dt
				if y < -6 then
					y = 30
				end
				g.offset = Vector3.new(g.offset.X, y, g.offset.Z)
				g.part.CFrame = CFrame.new(centre + g.offset + Vector3.new(math.sin(t + g.phase) * 1.5, 0, 0))
			else
				local a = t * 0.4 * g.speed / 3 + g.phase
				local r = 18 + g.offset.X * 0.3
				g.part.CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * r, 22 + math.sin(t * 2 + g.phase) * 3, math.sin(a) * r))
			end
		end
	end)
	return function()
		conn:Disconnect()
		folder:Destroy()
	end
end

local function shower(colours: { Color3 }, size: Vector3, fall: number, flutter: number): () -> ()
	return Flakes.fall({
		seconds = 3600,
		centre = rootPos,
		colours = colours,
		material = Enum.Material.SmoothPlastic,
		size = size,
		count = 70,
		radius = 30,
		height = 26,
		fall = fall,
		flutter = flutter,
	})
end

-- A rainbow arching from the sky down to a point.
local function rainbowTo(target: Vector3): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "Rainbow"
	folder.Parent = holder()
	local bands = { rgb(255, 70, 90), rgb(255, 160, 60), rgb(255, 230, 80), rgb(90, 220, 120), rgb(80, 160, 255), rgb(150, 100, 255) }
	local from = target + Vector3.new(-90, 0, 40)
	local steps = 22
	for b, colour in bands do
		local lift = (b - 1) * 1.6
		local prev: Vector3? = nil
		for i = 0, steps do
			local f = i / steps
			local at = from:Lerp(target, f) + Vector3.new(0, math.sin(f * math.pi) * 70 + lift * (1 - f), 0)
			local last = prev
			if last then
				local seg = Instance.new("Part")
				seg.Anchored = true
				seg.CanCollide = false
				seg.CanQuery = false
				seg.CanTouch = false
				seg.CastShadow = false
				seg.Material = Enum.Material.Neon
				seg.Color = colour
				seg.Transparency = 0.25
				seg.Size = Vector3.new(1.5, 1.5, (at - last).Magnitude + 0.4)
				seg.CFrame = CFrame.lookAt((at + last) / 2, at)
				seg.Parent = folder
			end
			prev = at
		end
	end
	return function()
		folder:Destroy()
	end
end

-- A beam of gold light over each hunt's golden prize.
local function pillars(): () -> ()
	local made: { [Instance]: Part } = {}
	local conn = RunService.Heartbeat:Connect(function()
		for _, p in CollectionService:GetTagged("HuntJackpot") do
			if p:IsA("BasePart") and not made[p] then
				local beam = Instance.new("Part")
				beam.Name = "PrizeLight"
				beam.Anchored = true
				beam.CanCollide = false
				beam.CanQuery = false
				beam.CanTouch = false
				beam.CastShadow = false
				beam.Shape = Enum.PartType.Cylinder
				beam.Material = Enum.Material.Neon
				beam.Color = rgb(255, 214, 110)
				beam.Transparency = 0.55
				beam.Size = Vector3.new(120, 1.6, 1.6)
				beam.Parent = holder()
				made[p] = beam
			end
		end
		for p, beam in made do
			if p.Parent and p:IsA("BasePart") then
				beam.CFrame = CFrame.new(p.Position + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90))
			else
				beam:Destroy()
				made[p] = nil
			end
		end
	end)
	return function()
		conn:Disconnect()
		for _, beam in made do
			beam:Destroy()
		end
	end
end

local LOOKS: { [string]: () -> { () -> () } } = {
	halloween = function()
		return { tint(rgb(170, 90, 255), 0.18, 0.1), glyphs("🦇", 14, "wheel") }
	end,
	thanksgiving = function()
		return { tint(rgb(255, 170, 70), 0.14, 0.1), shower({ rgb(220, 110, 30), rgb(190, 60, 30), rgb(240, 170, 50), rgb(140, 80, 30) }, Vector3.new(0.6, 0.03, 0.45), 4, 1.2) }
	end,
	christmas = function()
		return { tint(rgb(200, 225, 255), 0.12, -0.05), shower({ rgb(255, 255, 255), rgb(235, 245, 255) }, Vector3.new(0.25, 0.25, 0.25), 3, 0.5) }
	end,
	newYear = function()
		return { tint(rgb(255, 214, 120), 0.14, 0.15) }
	end,
	valentine = function()
		return { tint(rgb(255, 120, 170), 0.16, 0.1), glyphs("💖", 18, "fall") }
	end,
	stPatrick = function()
		return { tint(rgb(120, 255, 150), 0.14, 0.1) }
	end,
	easter = function()
		return { tint(rgb(255, 220, 240), 0.12, 0.05), shower({ rgb(255, 190, 220), rgb(255, 240, 160), rgb(180, 220, 255), rgb(200, 255, 200) }, Vector3.new(0.4, 0.03, 0.3), 2.5, 1) }
	end,
}

local running: { [string]: { () -> () } } = {}
local rainbow: (() -> ())? = nil
local prizes: (() -> ())? = nil

local function on(id: string): boolean
	local ends = Workspace:GetAttribute(HouseEvents.attribute(id))
	return type(ends) == "number" and ends > Workspace:GetServerTimeNow()
end

local function update()
	local anyHunt = false
	for _, id in HouseEvents.Holidays do
		local isOn = on(id)
		if isOn and id ~= "newYear" then
			anyHunt = true
		end
		if isOn and not running[id] then
			local make = LOOKS[id]
			local ok, stops = pcall(function()
				return if make then make() else {}
			end)
			running[id] = if ok then stops else {}
		elseif not isOn and running[id] then
			for _, stop in running[id] do
				pcall(stop)
			end
			running[id] = nil
		end
	end
	-- St Patrick's rainbow ends at the pot of gold (while it hasn't been found).
	local pot: BasePart? = nil
	if on("stPatrick") then
		for _, p in CollectionService:GetTagged("HuntJackpot") do
			if p:IsA("BasePart") and p:GetAttribute("Hunt") == "stPatrick" then
				pot = p
			end
		end
	end
	if pot and not rainbow then
		rainbow = rainbowTo(pot.Position - Vector3.new(0, 3, 0))
	elseif not pot and rainbow then
		rainbow()
		rainbow = nil
	end
	if anyHunt and not prizes then
		prizes = pillars()
	elseif not anyHunt and prizes then
		prizes()
		prizes = nil
	end
end

function HolidayFX.start()
	for _, id in HouseEvents.Holidays do
		Workspace:GetAttributeChangedSignal(HouseEvents.attribute(id)):Connect(update)
	end
	task.spawn(function()
		while true do
			pcall(update)
			task.wait(1)
		end
	end)
end

HolidayFX.update = update

return HolidayFX
