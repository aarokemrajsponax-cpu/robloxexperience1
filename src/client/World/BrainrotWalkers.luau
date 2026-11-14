--!strict
-- The brainrots walking beside their guests: for everyone in the house whose squad has one out
-- (the "Brainrot" attribute the server sets), drawn on this screen at their side on the floor, as
-- tall as its rarity (a Common reaches your waist; a Mythic stands over you). It hops after its
-- guest when they move and bobs when they stop, on a little disc of light in its colour, with
-- sparks falling from it; a Gold, Diamond or Rainbow one shines in it, and the rarest give off
-- light. Over its head: its name, its stars and what it earns an hour. Nothing here changes a
-- score or a payment (the server keeps those).
-- Each has a character of its own: while its guest stands still it does its trick now and then
-- (dancers dance, the quick ones spin, the grand ones bow, the musical ones sway to a note, the
-- rarest flip), with a bubble over its head; left long enough it dozes off (and wakes when its
-- guest moves); it jumps for joy when its guest earns Gilt. A Legendary wears a gold halo; a
-- Mythic or a Secret, a crown. Your own one's tricks make a small sound.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BrainrotFigure = require(ReplicatedStorage.Shared.BrainrotFigure)
local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Sound = require(script.Parent.Parent.Sound)

local BrainrotWalkers = {}

-- Its trick, by its character (its accent first, then its rarity): what it does, and the bubble.
type Trick = { kind: string, bubble: string }
local BY_ACCENT: { [string]: Trick } = {
	["💃"] = { kind = "dance", bubble = "🎵" },
	["🎭"] = { kind = "dance", bubble = "🎵" },
	["🎤"] = { kind = "sway", bubble = "🎵" },
	["🎹"] = { kind = "sway", bubble = "🎵" },
	["🎼"] = { kind = "sway", bubble = "🎵" },
	["🚀"] = { kind = "spin", bubble = "💨" },
	["💨"] = { kind = "spin", bubble = "💨" },
	["🌪️"] = { kind = "spin", bubble = "💨" },
	["⚡"] = { kind = "spin", bubble = "⚡" },
	["🏎️"] = { kind = "spin", bubble = "💨" },
	["👑"] = { kind = "bow", bubble = "✨" },
	["🎩"] = { kind = "bow", bubble = "✨" },
	["💼"] = { kind = "bow", bubble = "💼" },
	["🕴️"] = { kind = "bow", bubble = "✨" },
	["💰"] = { kind = "boing", bubble = "💰" },
	["💵"] = { kind = "boing", bubble = "💰" },
	["📈"] = { kind = "boing", bubble = "📈" },
	["😠"] = { kind = "wiggle", bubble = "💢" },
	["👻"] = { kind = "spin", bubble = "👻" },
	["💪"] = { kind = "boing", bubble = "💪" },
}
local BY_RARITY: { [string]: Trick } = {
	Common = { kind = "boing", bubble = "❤️" },
	Uncommon = { kind = "wiggle", bubble = "❤️" },
	Rare = { kind = "spin", bubble = "✨" },
	Epic = { kind = "spin", bubble = "✨" },
	Legendary = { kind = "flip", bubble = "✨" },
	Mythic = { kind = "flip", bubble = "👑" },
	Secret = { kind = "flip", bubble = "🌙" },
}
local TRICK_TIME = 1.3 -- seconds a trick lasts
local DOZE_AFTER = 40 -- seconds of its guest standing still before it dozes

-- (Further than this from the camera, a walker is out of sight: it waits, and catches up.)
local FAR = 220

local rgb = Color3.fromRGB
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 80, 120)),
	ColorSequenceKeypoint.new(0.25, rgb(255, 210, 70)),
	ColorSequenceKeypoint.new(0.5, rgb(90, 240, 140)),
	ColorSequenceKeypoint.new(0.75, rgb(80, 170, 255)),
	ColorSequenceKeypoint.new(1, rgb(200, 100, 255)),
})
local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }

type Walker = {
	id: string,
	part: Part,
	body: BillboardGui,
	glyph: TextLabel,
	aura: Frame,
	shadow: Part,
	ring: Part,
	root: BasePart,
	humanoid: Humanoid?,
	at: Vector3,
	height: number,
	phase: number,
	rainbow: UIGradient?,
	trick: Trick,
	nextTrick: number, -- when it next does its trick (while its guest stands still)
	trickAt: number?, -- when the one it's doing began
	trickKind: string?,
	bubble: TextLabel,
	stillSince: number, -- since when its guest has stood still
	gilt: number?, -- its guest's Gilt, last seen (a rise: a jump for joy)
	mine: boolean,
	crown: TextLabel?,
	figure: Model?, -- (Build 82) the brainrot in the round (shared/BrainrotFigure), when it has one
}
local walkers: { [Player]: Walker } = {}

local function holder(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

local function round(f: GuiObject)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
end

local function clear(p: Player)
	local w = walkers[p]
	if not w then
		return
	end
	walkers[p] = nil
	w.part:Destroy()
	w.shadow:Destroy()
	w.ring:Destroy()
	local f = w.figure
	if f then
		f:Destroy()
	end
end

local function flat(name: string, size: number, colour: Color3, transparency: number, neon: boolean): Part
	local d = Instance.new("Part")
	d.Name = name
	d.Shape = Enum.PartType.Cylinder
	d.Anchored = true
	d.CanCollide = false
	d.CanQuery = false
	d.CanTouch = false
	d.CastShadow = false
	d.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	d.Color = colour
	d.Transparency = transparency
	d.Size = Vector3.new(0.08, size, size)
	d.Parent = holder()
	return d
end

local function build(p: Player)
	clear(p)
	local id = p:GetAttribute("Brainrot")
	local c = if type(id) == "string" then Curios.byId[id] else nil
	local character = p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not c or c.family ~= "meme" or not root or not root:IsA("BasePart") then
		return
	end
	local mutAttr = p:GetAttribute("BrainrotMut")
	local mut = if type(mutAttr) == "string" then Brainrots.Mutations[mutAttr] else nil
	local starsAttr = p:GetAttribute("BrainrotStars")
	local stars = if type(starsAttr) == "number" then starsAttr else 1
	local rateAttr = p:GetAttribute("BrainrotRate")
	local rate = if type(rateAttr) == "number" then rateAttr else 0
	local rank = RANK[c.rarity] or 1
	-- (Each star stands it a little taller.)
	local h = (Brainrots.Height[c.rarity] or 3.4) * (1 + 0.04 * math.max(0, stars - 1))
	local colour = if mut then mut.colour else (Curios.RarityColour[c.rarity] or Brand.Colours.gold)
	if c.rarity == "Secret" and not mut then
		colour = rgb(200, 190, 255)
	end
	local part = Instance.new("Part")
	part.Name = "Brainrot"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = root.CFrame * CFrame.new(-3.5, 0, 2.5)
	part:SetAttribute("Owner", p.UserId)
	part:SetAttribute("Curio", c.id)
	-- Its body: the character itself, big, in a soft aura of its colour.
	local body = Instance.new("BillboardGui")
	body.Name = "Body"
	body.Size = UDim2.fromScale(h, h)
	body.LightInfluence = 0
	body.MaxDistance = 180
	body.Parent = part
	local aura = Instance.new("Frame")
	aura.Name = "Aura"
	aura.AnchorPoint = Vector2.new(0.5, 0.5)
	aura.Position = UDim2.fromScale(0.5, 0.55)
	aura.Size = UDim2.fromScale(1.05, 1.05)
	aura.BackgroundColor3 = colour
	aura.BackgroundTransparency = 0.6
	aura.BorderSizePixel = 0
	aura.Parent = body
	round(aura)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.55, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Rotation = 90
	fade.Parent = aura
	local rainbow: UIGradient? = nil
	if mut then
		local ring = Instance.new("Frame")
		ring.Name = "Mutation"
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.55)
		ring.Size = UDim2.fromScale(0.98, 0.98)
		ring.BackgroundTransparency = 1
		ring.Parent = body
		round(ring)
		local st = Instance.new("UIStroke")
		st.Thickness = 4
		st.Color = if mutAttr == "rainbow" then Color3.new(1, 1, 1) else mut.colour
		st.Transparency = 0.15
		st.Parent = ring
		if mutAttr == "rainbow" then
			local g = Instance.new("UIGradient")
			g.Color = RAINBOW
			g.Parent = st
			rainbow = g
		end
	end
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.55)
	glyph.Size = UDim2.fromScale(0.9, 0.9)
	glyph.TextScaled = true
	glyph.Text = c.glyph
	glyph.Parent = body
	if c.accent ~= "" then
		local accent = Instance.new("TextLabel")
		accent.Name = "Accent"
		accent.BackgroundTransparency = 1
		accent.AnchorPoint = Vector2.new(0.5, 0.5)
		accent.Position = UDim2.fromScale(0.82, 0.2)
		accent.Size = UDim2.fromScale(0.4, 0.4)
		accent.TextScaled = true
		accent.Text = c.accent
		accent.Parent = glyph
	end
	-- A bubble for its moods (its trick, a doze, joy), over its shoulder.
	local bubble = Instance.new("TextLabel")
	bubble.Name = "Bubble"
	bubble.BackgroundTransparency = 1
	bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	bubble.Position = UDim2.fromScale(0.86, 0.02)
	bubble.Size = UDim2.fromScale(0.36, 0.36)
	bubble.TextScaled = true
	bubble.Text = ""
	bubble.TextTransparency = 1
	bubble.ZIndex = 3
	bubble.Parent = body
	-- The rarest, crowned; a Legendary, haloed.
	local crown: TextLabel? = nil
	if c.rarity == "Mythic" or c.rarity == "Secret" then
		local cr = Instance.new("TextLabel")
		cr.Name = "Crown"
		cr.BackgroundTransparency = 1
		cr.AnchorPoint = Vector2.new(0.5, 0.5)
		cr.Position = UDim2.fromScale(0.5, -0.02)
		cr.Size = UDim2.fromScale(0.34, 0.34)
		cr.TextScaled = true
		cr.Text = "👑"
		cr.ZIndex = 2
		cr.Parent = body
		crown = cr
	elseif c.rarity == "Legendary" then
		local halo = Instance.new("Frame")
		halo.Name = "Halo"
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromScale(0.5, 0.06)
		halo.Size = UDim2.fromScale(0.5, 0.12)
		halo.BackgroundTransparency = 1
		halo.ZIndex = 2
		halo.Parent = body
		round(halo)
		local hs = Instance.new("UIStroke")
		hs.Thickness = 3
		hs.Color = rgb(255, 214, 110)
		hs.Transparency = 0.05
		hs.Parent = halo
	end
	-- Over its head: its name, its stars and what it earns.
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(260, 52)
	tag.StudsOffset = Vector3.new(0, h * 0.55 + 0.9, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 70
	tag.Parent = part
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 26)
	name.Text = c.name
	name.FontFace = Brand.Fonts.heavy
	name.TextSize = 20
	name.TextColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.25)
	name.TextStrokeColor3 = rgb(10, 8, 12)
	name.TextStrokeTransparency = 0.2
	name.Parent = tag
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(0, 26)
	line.Size = UDim2.new(1, 0, 0, 22)
	line.Text = string.format("%s%s  ·  +%s Gilt/hr", Brainrots.starText(stars), if mut then "  ·  " .. string.upper(mut.name) else "", Brainrots.short(rate))
	line.FontFace = Brand.Fonts.heavy
	line.TextSize = 14
	line.TextColor3 = rgb(255, 222, 120)
	line.TextStrokeColor3 = rgb(10, 8, 12)
	line.TextStrokeTransparency = 0.25
	line.Parent = tag
	-- Sparks falling from it (more for the rarer), and light of its own for the rarest.
	local att = Instance.new("Attachment")
	att.Parent = part
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparks"
	e.Texture = SPARKLES
	e.Rate = 3 + rank * 3 + (if mut then 10 else 0)
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(0.4, 1.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -0.8, 0)
	e.LightEmission = 0.9
	e.Size = NumberSequence.new(0.18 + h * 0.03, 0)
	e.Color = if mutAttr == "rainbow" then RAINBOW else ColorSequence.new(colour)
	e.Parent = att
	if rank >= 5 or mut then
		local l = Instance.new("PointLight")
		l.Color = colour
		l.Brightness = 1.2
		l.Range = 6 + h
		l.Shadows = false
		l.Parent = part
	end
	part.Parent = holder()
	-- (Build 82) The brainrot in the round: built of parts, with its face and what it wears; the
	-- flat picture stays only for one with no figure (and its mood's bubble stays over it).
	local figure: Model? = nil
	local okFigure, built = pcall(BrainrotFigure.build, c.id, h, c.colour, if mut then mut.colour else nil)
	if okFigure and built then
		figure = built
		built.Parent = holder()
		glyph.Visible = false
		aura.Visible = false
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	walkers[p] = {
		id = c.id,
		part = part,
		body = body,
		glyph = glyph,
		aura = aura,
		shadow = flat("BrainrotShadow", h * 0.7, rgb(0, 0, 0), 0.55, false),
		ring = flat("BrainrotRing", h * 0.86, colour, 0.7, true),
		root = root,
		humanoid = humanoid,
		at = part.CFrame.Position,
		height = h,
		phase = (p.UserId % 89) / 89 * math.pi * 2,
		rainbow = rainbow,
		trick = BY_ACCENT[c.accent] or BY_RARITY[c.rarity] or BY_RARITY.Common,
		nextTrick = os.clock() + 4 + (p.UserId % 5),
		trickAt = nil,
		trickKind = nil,
		bubble = bubble,
		stillSince = os.clock(),
		gilt = tonumber(p:GetAttribute("Gilt")),
		mine = p == Players.LocalPlayer,
		crown = crown,
		figure = figure,
	}
end

-- Starts a trick (or a jump for joy) with its bubble.
local function perform(w: Walker, kind: string, bubble: string, t: number)
	w.trickAt = t
	w.trickKind = kind
	w.bubble.Text = bubble
	w.bubble.TextTransparency = 0
	if w.mine then
		pcall(Sound.play, if kind == "joy" then "coinDrop" else "pickup", 0.22, 1.1 + (w.phase % 0.4))
	end
end
BrainrotWalkers.perform = perform

-- Its guest earned Gilt: a jump for joy (never more than one every few seconds).
local function cheer(p: Player)
	local w = walkers[p]
	if not w then
		return
	end
	local g = tonumber(p:GetAttribute("Gilt"))
	local before = w.gilt
	w.gilt = g
	if g and before and g > before and (not w.trickAt or os.clock() - w.trickAt > 3) then
		w.stillSince = os.clock()
		perform(w, "joy", "💰", os.clock())
	end
end

local function watch(p: Player)
	for _, key in { "Brainrot", "BrainrotMut", "BrainrotStars", "BrainrotRate" } do
		p:GetAttributeChangedSignal(key):Connect(function()
			build(p)
		end)
	end
	p:GetAttributeChangedSignal("Gilt"):Connect(function()
		cheer(p)
	end)
	p.CharacterAdded:Connect(function()
		task.wait(0.5)
		build(p)
	end)
	if p.Character then
		build(p)
	end
end

-- Where its feet go: the floor under the guest (their hip height below the root).
local function floorOf(w: Walker): number
	local hip = if w.humanoid then w.humanoid.HipHeight else 2
	return w.root.Position.Y - w.root.Size.Y / 2 - hip
end

function BrainrotWalkers.start()
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		local k = 1 - math.exp(-4 * math.min(dt, 0.1))
		-- (Only the walkers near enough to be seen move; the rest catch up as their guest comes
		-- into view. Every part moved in one call to the engine.)
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else nil
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		for p, w in walkers do
			if not w.root.Parent or not w.part.Parent then
				clear(p)
				continue
			end
			if eye and (w.root.Position - eye).Magnitude > FAR then
				continue
			end
			local h = w.height
			-- Behind and to the left of its guest, further back the bigger it is.
			local side = (w.root.CFrame * CFrame.new(-(2.2 + h * 0.35), 0, 1.6 + h * 0.25)).Position
			local floor = floorOf(w)
			local goal = Vector3.new(side.X, floor, side.Z)
			local before = w.at
			w.at = Vector3.new(before.X, floor, before.Z):Lerp(goal, k)
			local speed = (Vector3.new(w.at.X, 0, w.at.Z) - Vector3.new(before.X, 0, before.Z)).Magnitude / math.max(dt, 1 / 240)
			local moving = math.clamp(speed / 10, 0, 1)
			-- Hopping after its guest, bobbing when still; squashing a little as it lands.
			local hop = math.abs(math.sin(t * 9 + w.phase)) * 0.55 * moving * (h / 4)
			local bob = math.sin(t * 2 + w.phase) * 0.1 * (1 - moving)
			local squash = math.sin(t * 18 + w.phase * 2) * 0.05 * moving + math.sin(t * 2 + w.phase) * 0.025
			local turn = math.sin(t * 1.6 + w.phase) * 4 + math.sin(t * 9 + w.phase) * 7 * moving
			local sway = 0
			-- Its character: tricks while its guest stands still, a doze when left long enough.
			if moving > 0.15 then
				w.stillSince = t
				if w.trickKind == "doze" then
					w.trickAt, w.trickKind = nil, nil
					w.bubble.TextTransparency = 1
				end
				w.nextTrick = math.max(w.nextTrick, t + 3)
			elseif not w.trickAt and t - w.stillSince > DOZE_AFTER then
				perform(w, "doze", "💤", t)
			elseif not w.trickAt and t >= w.nextTrick then
				perform(w, w.trick.kind, w.trick.bubble, t)
			end
			local at, kind = w.trickAt, w.trickKind
			if at and kind then
				local u = (t - at) / TRICK_TIME
				if kind == "doze" then
					-- Slow breaths, a tilt, the bubble drifting.
					squash = math.sin(t * 1.2) * 0.06
					turn = 14 + math.sin(t * 1.2) * 2
					bob = -0.12 * h / 4
					w.bubble.Position = UDim2.fromScale(0.86 + math.sin(t * 0.8) * 0.04, 0.0 - (t % 3) * 0.03)
				elseif u >= 1 then
					w.trickAt, w.trickKind = nil, nil
					w.bubble.TextTransparency = 1
					w.bubble.Position = UDim2.fromScale(0.86, 0.02)
					w.nextTrick = t + 6 + (w.phase * 1.7) % 5
				else
					local up = math.sin(u * math.pi)
					w.bubble.TextTransparency = math.clamp((u - 0.75) * 4, 0, 1)
					w.bubble.Position = UDim2.fromScale(0.86, 0.02 - up * 0.12)
					if kind == "spin" then
						turn = u * 360
						hop = up * 0.35 * (h / 4)
					elseif kind == "flip" then
						turn = -u * 360
						hop = up * 1.1 * (h / 4)
						squash = -0.08 * up
					elseif kind == "boing" or kind == "joy" then
						local bounces = if kind == "joy" then 2 else 3
						local b = math.abs(math.sin(u * math.pi * bounces))
						hop = b * (if kind == "joy" then 1.2 else 0.7) * (h / 4)
						squash = (0.5 - b) * 0.18
					elseif kind == "wiggle" then
						turn = math.sin(u * math.pi * 8) * 16
					elseif kind == "sway" then
						turn = math.sin(u * math.pi * 3) * 12
						sway = math.sin(u * math.pi * 3) * 0.35
					elseif kind == "dance" then
						turn = math.sin(u * math.pi * 4) * 14
						sway = math.sin(u * math.pi * 2) * 0.6
						hop = math.abs(math.sin(u * math.pi * 4)) * 0.4 * (h / 4)
					elseif kind == "bow" then
						turn = -up * 22
						bob -= up * 0.25 * (h / 4)
						squash = up * 0.08
					end
				end
			end
			local crown = w.crown
			if crown then
				crown.Position = UDim2.fromScale(0.5, -0.02 + math.sin(t * 2.4 + w.phase) * 0.02)
				crown.Rotation = math.sin(t * 1.3 + w.phase) * 6
			end
			local across = (w.root.CFrame.RightVector * sway)
			table.insert(parts, w.part)
			table.insert(frames, CFrame.new(w.at + across + Vector3.new(0, h * 0.5 + hop + bob, 0)))
			local fig = w.figure
			local figRoot = fig and fig.PrimaryPart
			if figRoot then
				-- Facing the way its guest faces; a spin turns it round, a flip turns it over
				-- backwards, a bow tips it forward, the rest sway it from side to side.
				local look = w.root.CFrame.LookVector
				local yaw = math.atan2(-look.X, -look.Z)
				local trickKind = w.trickKind
				local spinning = trickKind == "spin"
				local flipping = trickKind == "flip"
				local pitch = if trickKind == "bow" then math.rad(turn) elseif flipping then math.rad(turn) else 0
				local roll = if spinning or flipping or trickKind == "bow" then 0 else math.rad(turn) * 0.6
				local spin = if spinning then math.rad(turn) else 0
				local base = CFrame.new(w.at + across + Vector3.new(0, hop + bob, 0)) * CFrame.Angles(0, yaw + spin, 0)
				-- (A flip turns about its middle, not its feet.)
				local mid = CFrame.new(0, h * 0.45, 0)
				table.insert(parts, figRoot)
				table.insert(frames, base * mid * CFrame.Angles(pitch, 0, roll) * mid:Inverse())
			end
			w.body.Size = UDim2.fromScale(h * (1 + squash), h * (1 - squash))
			w.glyph.Rotation = turn
			w.aura.BackgroundTransparency = 0.55 + 0.12 * math.sin(t * 2.6 + w.phase)
			local disc = CFrame.new(w.at + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			table.insert(parts, w.shadow)
			table.insert(frames, disc)
			table.insert(parts, w.ring)
			table.insert(frames, disc * CFrame.new(-0.02, 0, 0))
			w.ring.Transparency = 0.62 + 0.12 * math.sin(t * 3 + w.phase)
			local rainbow = w.rainbow
			if rainbow then
				rainbow.Rotation = (t * 90) % 360
			end
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

-- For tests: what a guest's brainrot is doing (its trick, a doze, joy) and the bubble it shows.
function BrainrotWalkers.mood(p: Player): (string?, string?)
	local w = walkers[p]
	if not w or not w.trickKind then
		return nil, nil
	end
	return w.trickKind, w.bubble.Text
end

-- For tests: the brainrot's figure (Build 82), if it has one.
function BrainrotWalkers.figure(p: Player): Model?
	local w = walkers[p]
	return if w then w.figure else nil
end

-- For tests: the brainrot walking beside a guest, if any.
function BrainrotWalkers.of(p: Player): Part?
	local w = walkers[p]
	return if w then w.part else nil
end

return BrainrotWalkers
