--!strict
-- Companions (the Gem Shop): a little friend floating at the shoulder of every guest who has one,
-- drawn on this screen for each of them from what the server says they wear (the "Companion"
-- attribute). Its glyph sits in a soft glow of its own colour, bobbing and leaning as it follows,
-- with sparkles, embers or every colour falling from it; some wear a crown of stars, and the
-- finest gives off light of its own. Nothing about it changes a score.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GemList = require(ReplicatedStorage.Shared.GemShop)

local Companions = {}

-- (Further than this from the camera, a companion is out of sight: it waits, and catches up.)
local FAR = 220

local rgb = Color3.fromRGB
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 70, 120)),
	ColorSequenceKeypoint.new(0.25, rgb(255, 200, 60)),
	ColorSequenceKeypoint.new(0.5, rgb(90, 240, 140)),
	ColorSequenceKeypoint.new(0.75, rgb(80, 170, 255)),
	ColorSequenceKeypoint.new(1, rgb(190, 100, 255)),
})

type Pet = {
	id: string,
	part: Part,
	glyph: TextLabel,
	halo: Frame,
	root: BasePart,
	at: Vector3,
	phase: number,
	stars: { Part },
	big: boolean,
}
local pets: { [Player]: Pet } = {}

local function holder(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

local function clear(p: Player)
	local pet = pets[p]
	if not pet then
		return
	end
	pets[p] = nil
	pet.part:Destroy()
	for _, s in pet.stars do
		s:Destroy()
	end
end

local function round(f: GuiObject)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
end

local function build(p: Player)
	clear(p)
	local id = p:GetAttribute("Companion")
	local item = if type(id) == "string" then GemList.byId[id] else nil
	local character = p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not item or item.kind ~= "companion" or not root or not root:IsA("BasePart") then
		return
	end
	local style = item.style
	local big = style.big == true
	local part = Instance.new("Part")
	part.Name = "Companion"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = root.CFrame * CFrame.new(2.2, 1.6, 0.6)
	part:SetAttribute("Owner", p.UserId)
	part:SetAttribute("Item", item.id)
	-- The glyph in its glow.
	local bb = Instance.new("BillboardGui")
	bb.Name = "Face"
	bb.Size = UDim2.fromScale(if big then 2.4 else 1.9, if big then 2.4 else 1.9)
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.Parent = part
	local glowColour = if typeof(style.glow) == "Color3" then style.glow :: Color3 else rgb(255, 230, 180)
	local halo = Instance.new("Frame")
	halo.Name = "Glow"
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(1.15, 1.15)
	halo.BackgroundColor3 = glowColour
	halo.BackgroundTransparency = 0.55
	halo.BorderSizePixel = 0
	halo.Parent = bb
	round(halo)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Rotation = 90
	fade.Parent = halo
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromScale(0.86, 0.86)
	glyph.TextScaled = true
	glyph.Text = tostring(style.glyph or item.glyph)
	glyph.Parent = bb
	-- What falls from it.
	local att = Instance.new("Attachment")
	att.Parent = part
	local e = Instance.new("ParticleEmitter")
	e.Name = "Trail"
	e.Texture = if style.fire then FIRE else SPARKLES
	e.Rate = tonumber(style.rate) or 8
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(0.2, 0.9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, if style.fire then 1.5 else -0.6, 0)
	e.LightEmission = 0.85
	e.Size = if style.fire then NumberSequence.new(0.35, 0) else NumberSequence.new(0.22, 0)
	if style.rainbow then
		e.Color = RAINBOW
	elseif style.fire then
		e.Color = ColorSequence.new(rgb(255, 210, 90), rgb(255, 90, 40))
	elseif type(style.colours) == "table" and #style.colours >= 2 then
		e.Color = ColorSequence.new(style.colours[1], style.colours[2])
	else
		e.Color = ColorSequence.new(glowColour)
	end
	e.Parent = att
	-- The finest gives off light of its own.
	if typeof(style.light) == "Color3" then
		local l = Instance.new("PointLight")
		l.Color = style.light
		l.Brightness = 1.4
		l.Range = 9
		l.Shadows = false
		l.Parent = part
	end
	part.Parent = holder()
	-- A crown of stars turning over its head.
	local stars: { Part } = {}
	if style.crown then
		for _ = 1, 5 do
			local s = Instance.new("Part")
			s.Name = "CompanionStar"
			s.Anchored = true
			s.CanCollide = false
			s.CanQuery = false
			s.CanTouch = false
			s.CastShadow = false
			s.Transparency = 1
			s.Size = Vector3.new(0.1, 0.1, 0.1)
			local sb = Instance.new("BillboardGui")
			sb.Size = UDim2.fromScale(0.45, 0.45)
			sb.LightInfluence = 0
			sb.MaxDistance = 80
			sb.Parent = s
			local st = Instance.new("TextLabel")
			st.BackgroundTransparency = 1
			st.Size = UDim2.fromScale(1, 1)
			st.TextScaled = true
			st.Text = "⭐"
			st.Parent = sb
			s.Parent = holder()
			table.insert(stars, s)
		end
	end
	pets[p] = {
		id = item.id,
		part = part,
		glyph = glyph,
		halo = halo,
		root = root,
		at = part.CFrame.Position,
		phase = (p.UserId % 97) / 97 * math.pi * 2,
		stars = stars,
		big = big,
	}
end

local function watch(p: Player)
	p:GetAttributeChangedSignal("Companion"):Connect(function()
		build(p)
	end)
	p.CharacterAdded:Connect(function()
		task.wait(0.5)
		build(p)
	end)
	if p.Character then
		build(p)
	end
end

function Companions.start()
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	-- Each follows its guest: to a place at the shoulder, gently, bobbing, leaning into its way.
	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		local k = 1 - math.exp(-5 * math.min(dt, 0.1))
		-- (Only the companions near enough to be seen move; the rest catch up as their guest comes
		-- into view. Every part moved in one call to the engine.)
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else nil
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		for p, pet in pets do
			if not pet.root.Parent or not pet.part.Parent then
				clear(p)
				continue
			end
			if eye and (pet.root.Position - eye).Magnitude > FAR then
				continue
			end
			local bob = math.sin(t * 2.2 + pet.phase) * 0.35
			local goal = (pet.root.CFrame * CFrame.new(if pet.big then 2.6 else 2.2, (if pet.big then 2.2 else 1.6) + bob, 0.7)).Position
			local before = pet.at
			pet.at = before:Lerp(goal, k)
			table.insert(parts, pet.part)
			table.insert(frames, CFrame.new(pet.at))
			local lean = math.clamp((pet.at - before).Magnitude * 18, 0, 14)
			pet.glyph.Rotation = math.sin(t * 1.7 + pet.phase) * 6 + lean * (if math.sin(t + pet.phase) > 0 then 1 else -1) * 0.4
			pet.halo.BackgroundTransparency = 0.5 + 0.15 * math.sin(t * 3 + pet.phase)
			for i, s in pet.stars do
				local a = t * 1.5 + i / #pet.stars * math.pi * 2
				table.insert(parts, s)
				table.insert(frames, CFrame.new(pet.at + Vector3.new(math.cos(a) * 0.7, 1.1, math.sin(a) * 0.7)))
			end
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

-- For tests: the companion floating by a guest, if any.
function Companions.of(p: Player): Part?
	local pet = pets[p]
	return if pet then pet.part else nil
end

return Companions
