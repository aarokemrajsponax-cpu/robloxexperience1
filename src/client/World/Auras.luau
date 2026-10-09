--!strict
-- Auras (the Gem Shop): a glow round every guest who wears one, drawn on this screen for each of
-- them from what the server says they wear (the "Aura" attribute). Sparkles, mist, embers or
-- smoke in the aura's colours, or little glyphs circling them (hearts, clovers, a crown of stars).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GemList = require(ReplicatedStorage.Shared.GemShop)

local Auras = {}

local rgb = Color3.fromRGB
local TEXTURES = {
	sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 70, 120)),
	ColorSequenceKeypoint.new(0.25, rgb(255, 200, 60)),
	ColorSequenceKeypoint.new(0.5, rgb(90, 240, 140)),
	ColorSequenceKeypoint.new(0.75, rgb(80, 170, 255)),
	ColorSequenceKeypoint.new(1, rgb(190, 100, 255)),
})

type Worn = { id: string, attachment: Attachment?, orbit: { BasePart }, crown: boolean, root: BasePart }
local worn: { [Player]: Worn } = {}

local function holder(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

local function clear(p: Player)
	local w = worn[p]
	if not w then
		return
	end
	worn[p] = nil
	if w.attachment then
		w.attachment:Destroy()
	end
	for _, part in w.orbit do
		part:Destroy()
	end
end

local function build(p: Player)
	clear(p)
	local id = p:GetAttribute("Aura")
	local item = if type(id) == "string" then GemList.byId[id] else nil
	local character = p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not item or item.kind ~= "aura" or not root or not root:IsA("BasePart") then
		return
	end
	local style = item.style
	local w: Worn = { id = item.id, attachment = nil, orbit = {}, crown = style.crown == true, root = root }
	if style.particle then
		local att = Instance.new("Attachment")
		att.Name = "MaisonAura"
		att.Position = Vector3.new(0, -1, 0)
		att.Parent = root
		w.attachment = att
		local e = Instance.new("ParticleEmitter")
		e.Name = "Aura"
		e.Texture = TEXTURES[style.particle] or TEXTURES.sparkles
		e.Rate = style.rate or 16
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Speed = NumberRange.new(0.6, 2.2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, if style.particle == "fire" then 3 else 1.2, 0)
		e.LightEmission = if style.particle == "smoke" then 0 else 0.8
		e.Size = if style.particle == "smoke" then NumberSequence.new(1.6, 3) elseif style.particle == "fire" then NumberSequence.new(0.6, 0) else NumberSequence.new(0.45, 0)
		e.Transparency = if style.particle == "smoke" then NumberSequence.new(0.55, 1) else NumberSequence.new(0, 1)
		if style.rainbow then
			e.Color = RAINBOW
		elseif type(style.colours) == "table" and #style.colours >= 2 then
			e.Color = ColorSequence.new(style.colours[1], style.colours[2])
		elseif type(style.colours) == "table" and #style.colours == 1 then
			e.Color = ColorSequence.new(style.colours[1])
		end
		-- (Round the whole body, not a point.)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Parent = att
		if typeof(style.mist) == "Color3" then
			local m = Instance.new("ParticleEmitter")
			m.Name = "Mist"
			m.Texture = TEXTURES.smoke
			m.Rate = 4
			m.Lifetime = NumberRange.new(1.5, 2.5)
			m.Speed = NumberRange.new(0.3, 0.8)
			m.Size = NumberSequence.new(1.4, 3)
			m.Transparency = NumberSequence.new(0.7, 1)
			m.Color = ColorSequence.new(style.mist)
			m.Parent = att
		end
	end
	if type(style.glyph) == "string" then
		for _ = 1, (style.orbit or 5) do
			local part = Instance.new("Part")
			part.Name = "AuraGlyph"
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Size = Vector3.new(0.2, 0.2, 0.2)
			part.CFrame = root.CFrame
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(1.1, 1.1)
			bb.LightInfluence = 0
			bb.MaxDistance = 80
			bb.Parent = part
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.TextScaled = true
			t.Text = style.glyph
			t.Parent = bb
			part.Parent = holder()
			table.insert(w.orbit, part)
		end
	end
	worn[p] = w
end

local function watch(p: Player)
	p:GetAttributeChangedSignal("Aura"):Connect(function()
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

function Auras.start()
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	-- The circling glyphs go round.
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for p, w in worn do
			if #w.orbit > 0 then
				if not w.root.Parent then
					clear(p)
					continue
				end
				local centre = w.root.Position
				local n = #w.orbit
				for i, part in w.orbit do
					local a = t * (if w.crown then 1.2 else 1.6) + i / n * math.pi * 2
					local r = if w.crown then 1.1 else 2.6
					local y = if w.crown then 3.3 else math.sin(t * 2 + i) * 0.8
					part.CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * r, y, math.sin(a) * r))
				end
			end
		end
	end)
end

Auras.build = build

return Auras
