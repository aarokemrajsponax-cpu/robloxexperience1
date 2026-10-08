--!strict
-- How the owner's events look on this screen (the server runs them: AdminService). Disco Night:
-- a mirror ball turns under the Ballroom's ceiling, throwing coloured light, and the Ballroom's
-- lamps cycle through colours (put back as they were when it ends). The Brainrot Parade: the
-- meme curios loose in the house bob and turn.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Layout = require(ReplicatedStorage.Shared.Layout)

local EventFX = {}

local COLOURS = { Color3.fromRGB(255, 80, 160), Color3.fromRGB(80, 160, 255), Color3.fromRGB(120, 255, 140), Color3.fromRGB(255, 210, 80), Color3.fromRGB(190, 110, 255) }

local disco: { ball: Model, lamps: { Light }, conn: RBXScriptConnection }? = nil

-- (Each lamp's own colour is kept on the lamp, "DiscoWas", shared with the House Party
-- (World/DiscoHouse): whichever ends last puts it back, so a lamp is never left in a disco colour.)
local function partyOn(): boolean
	local ends = Workspace:GetAttribute(HouseEvents.attribute("discoHouse"))
	return type(ends) == "number" and ends > Workspace:GetServerTimeNow()
end

local function ballroomLights(): { Light }
	local out = {}
	local maison = Workspace:FindFirstChild("Maison")
	local room = maison and maison:FindFirstChild("Ballroom")
	if room then
		for _, d in room:GetDescendants() do
			if d:IsA("Light") then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function startDisco()
	if disco then
		return
	end
	local B = Layout.Ballroom
	local model = Instance.new("Model")
	model.Name = "DiscoBall"
	local centre = B.centre + Vector3.new(0, B.height - 6, 0)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(5, 5, 5)
	ball.Material = Enum.Material.Glass
	ball.Reflectance = 0.6
	ball.Color = Color3.fromRGB(220, 220, 230)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CFrame = CFrame.new(centre)
	ball.Parent = model
	local chain = Instance.new("Part")
	chain.Size = Vector3.new(0.2, 5, 0.2)
	chain.Material = Enum.Material.Metal
	chain.Color = Color3.fromRGB(170, 132, 64)
	chain.Anchored = true
	chain.CanCollide = false
	chain.CFrame = CFrame.new(centre + Vector3.new(0, 5, 0))
	chain.Parent = model
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Shadows = false
	light.Parent = ball
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 30
	sparkle.Speed = NumberRange.new(10, 18)
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Parent = ball
	model.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	local lamps = ballroomLights()
	for _, l in lamps do
		if l:GetAttribute("DiscoWas") == nil then
			l:SetAttribute("DiscoWas", l.Color)
		end
	end
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		ball.CFrame = CFrame.new(centre) * CFrame.Angles(0, t * 0.8, 0)
		local i = math.floor(t * 1.5)
		local c = COLOURS[i % #COLOURS + 1]
		light.Color = c
		sparkle.Color = ColorSequence.new(c)
		for _, l in lamps do
			if l.Parent then
				l.Color = COLOURS[(i + #l.Name) % #COLOURS + 1]
			end
		end
	end)
	disco = { ball = model, lamps = lamps, conn = conn }
end

local function stopDisco()
	local d = disco
	if not d then
		return
	end
	disco = nil
	d.conn:Disconnect()
	d.ball:Destroy()
	-- The House Party still on: it puts the lamps back when it ends.
	if partyOn() then
		return
	end
	for _, l in d.lamps do
		local was = l:GetAttribute("DiscoWas")
		if typeof(was) == "Color3" then
			l.Color = was
		end
		l:SetAttribute("DiscoWas", nil)
	end
end

local function watchDisco()
	if Workspace:GetAttribute(HouseEvents.attribute("disco")) ~= nil then
		startDisco()
	else
		stopDisco()
	end
end

function EventFX.start()
	Workspace:GetAttributeChangedSignal(HouseEvents.attribute("disco")):Connect(watchDisco)
	watchDisco()
	-- The parade's memes bob and turn.
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, p in CollectionService:GetTagged("ParadeMeme") do
			if p:IsA("BasePart") then
				local bb = p:FindFirstChildOfClass("BillboardGui")
				if bb then
					bb.StudsOffset = Vector3.new(0, math.sin(t * 2 + p.Position.X) * 0.6, 0)
				end
			end
		end
	end)
end

return EventFX
