--!strict
-- (Build 96) Money moves, drawn on this screen round whoever played one (the server says who and
-- which: server/Emotes). Cash raining, a gold burst and a shower of coins, a spinning ring of
-- chrome sparkle, a gold bag bursting over the head, diamonds falling. Everything here is local
-- and short; nothing touches the game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)

local EmoteFX = {}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"

local function holder(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

-- A glyph in the air (a billboard on an invisible anchored part), gone after `life` seconds.
local function glyph(text: string, at: CFrame, size: number, life: number): BasePart
	local part = Instance.new("Part")
	part.Name = "MoneyMove"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = at
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size, size)
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = part
	local t = Instance.new("TextLabel")
	t.Name = "Glyph"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Text = text
	t.Parent = bb
	part.Parent = holder()
	task.delay(life, function()
		part:Destroy()
	end)
	return part
end

-- `n` glyphs falling round `root` from above its head to its feet.
local function shower(root: BasePart, text: string, n: number, seconds: number, spread: number)
	local rng = Random.new()
	for i = 1, n do
		task.delay((i - 1) / n * seconds * 0.7, function()
			if not root.Parent then
				return
			end
			local x, z = rng:NextNumber(-spread, spread), rng:NextNumber(-spread, spread)
			local from = root.CFrame * CFrame.new(x, 7 + rng:NextNumber(0, 2), z)
			local fall = rng:NextNumber(1.1, 1.7)
			local p = glyph(text, from, rng:NextNumber(0.9, 1.4), fall + 0.1)
			local to = root.CFrame * CFrame.new(x * 1.2, -2.6, z * 1.2) * CFrame.Angles(0, rng:NextNumber(-3, 3), 0)
			TweenService:Create(p, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = to }):Play()
		end)
	end
end

-- A burst of sparkles in `colour` at `root`, and a light that flares and fades.
local function burst(root: BasePart, colour: Color3, count: number, seconds: number)
	local att = Instance.new("Attachment")
	att.Name = "MoneyMove"
	att.Position = Vector3.new(0, 1.5, 0)
	att.Parent = root
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLES
	e.Color = ColorSequence.new(colour, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.9, 0)
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -6, 0)
	e.Rate = 0
	e.Parent = att
	e:Emit(count)
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = 14
	light.Brightness = 4
	light.Parent = att
	TweenService:Create(light, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	task.delay(seconds + 1.6, function()
		att:Destroy()
	end)
end

-- A ring of `text` spinning round the waist for `seconds`.
local function ring(root: BasePart, text: string, n: number, seconds: number)
	local parts = {}
	for _ = 1, n do
		table.insert(parts, glyph(text, root.CFrame, 1, seconds))
	end
	local started = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > seconds or not root.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		for i, p in parts do
			local a = t * 4 + i / n * math.pi * 2
			local r = 3 + math.sin(t * 3) * 0.4
			p.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * r, math.sin(t * 5 + i) * 0.6, math.sin(a) * r))
		end
	end)
end

-- Plays money move `id` round guest `userId` (the server has checked they wear and own it).
function EmoteFX.play(userId: number, id: string): boolean
	local who = Players:GetPlayerByUserId(userId)
	local character = who and who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local item = Wardrobe.get(id)
	if not root or not root:IsA("BasePart") or not item or item.kind ~= "gesture" or type(item.style.fx) ~= "string" then
		return false
	end
	local fx = item.style.fx :: string
	local colour = if typeof(item.style.colour) == "Color3" then item.style.colour else Color3.fromRGB(255, 206, 80)
	local seconds = if type(item.style.seconds) == "number" then item.style.seconds else 4
	if fx == "cash" then
		shower(root, "💵", 26, seconds, 4.5)
		burst(root, colour, 30, seconds)
	elseif fx == "gold" then
		burst(root, colour, 70, 1.6)
		shower(root, "💰", 16, seconds, 3)
	elseif fx == "drip" then
		ring(root, "✨", 10, seconds)
		burst(root, colour, 40, seconds)
		task.delay(seconds - 0.4, function()
			if root.Parent then
				burst(root, Color3.new(1, 1, 1), 50, 0.5)
			end
		end)
	elseif fx == "bag" then
		local bag = glyph("💰", root.CFrame * CFrame.new(0, 5, 0), 1.2, 1.4)
		local bb = bag:FindFirstChildOfClass("BillboardGui")
		if bb then
			TweenService:Create(bb, TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(4, 4) }):Play()
		end
		task.delay(1.2, function()
			if root.Parent then
				burst(root, colour, 60, 1.4)
				shower(root, "💵", 22, seconds - 1.2, 4)
			end
		end)
	elseif fx == "diamond" then
		shower(root, "💎", 20, seconds, 4)
		burst(root, colour, 40, seconds)
	else
		return false
	end
	return true
end

function EmoteFX.start()
	Remotes.event("Emote").OnClientEvent:Connect(function(m: any)
		if type(m) == "table" and m.op == "emote" and type(m.userId) == "number" and type(m.id) == "string" then
			EmoteFX.play(m.userId, m.id)
		end
	end)
end

return EmoteFX
