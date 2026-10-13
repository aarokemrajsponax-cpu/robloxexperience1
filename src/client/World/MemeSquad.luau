--!strict
-- The Meme Takeover's own cast from your Collection: your brainrot squad (CurioState.squad) drops
-- into the show and stars in it. They land in a line in front of you, lead the dance, run rings
-- round you in the rain, stand guard when the boss comes down, and in the chaos your best one,
-- the champion, fights the boss: it charges on the beat, every hit a shockwave, the boss's bar
-- draining across the top of the screen until the finale's K.O. Over it all, the meme words pop
-- on the beat (BRUH, SHEESH, ABSOLUTE CINEMA...), an AURA count climbs in the corner, and the
-- camera punches in on the big hits. With no squad yet, the house lends you a champion.
-- Drawn on this screen only; nothing in it is a prize (the squad's Meme Frenzy is the server's).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Ease = require(ReplicatedStorage.Shared.Ease)
local CurioState = require(script.Parent.Parent.CurioState)

local MemeSquad = {}

local rgb = Color3.fromRGB
local IMPACT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 80, 120)),
	ColorSequenceKeypoint.new(0.25, rgb(255, 210, 70)),
	ColorSequenceKeypoint.new(0.5, rgb(90, 240, 140)),
	ColorSequenceKeypoint.new(0.75, rgb(80, 170, 255)),
	ColorSequenceKeypoint.new(1, rgb(200, 100, 255)),
})
-- The words that pop on the beat (clean, every one).
local WORDS = {
	"BRUH",
	"SHEESH",
	"W",
	"NO WAY",
	"LET'S GOOO",
	"ABSOLUTE CINEMA",
	"SIGMA",
	"+1000 AURA",
	"BIG W",
	"SLAY",
	"UNREAL",
	"MAIN CHARACTER",
	"GOATED",
	"VIBE CHECK",
	"LEGENDARY",
	"OHHHH",
	"CRAZY",
	"HE'S COOKING",
}
local HITS = { "HIT!", "CRIT!", "COMBO!", "BOOM!", "POW!", "x2!", "OOF!" }
local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }

export type Opts = {
	folder: Instance,
	gui: ScreenGui,
	palette: { Color3 },
	floorY: number,
	ceiling: number,
	front: Vector3,
	right: Vector3,
	bossName: string,
	bossSize: number,
	burst: (at: Vector3, n: number) -> (),
	shockwave: (at: Vector3, colour: Color3, reach: number) -> (),
	caption: (text: string, hold: number, kicker: string?) -> (),
	sound: (name: string, volume: number, at: number?, pitch: number?) -> (),
	shake: (strength: number, seconds: number) -> (),
}

type Member = {
	id: string,
	part: Part,
	gui: BillboardGui,
	glyph: TextLabel,
	size: number,
	at: Vector3,
	landed: boolean,
	dropAt: number,
	ring: UIGradient?,
}

export type Squad = {
	act: (self: Squad, n: number, t: number) -> (),
	beat: (self: Squad, n: number, act: number) -> (),
	step: (self: Squad, t: number, dt: number, you: Vector3, bossAt: Vector3?, act: number, inAct: number) -> (),
	finish: (self: Squad) -> (),
	state: (self: Squad) -> { [string]: any },
}

local last: { [string]: any }? = nil

local function corner(f: GuiObject, scale: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 1, 0)
	c.Parent = f
end

-- Who's in the show: your squad (rarest first, the champion at the front), else a house champion.
local function castOf(): ({ string }, { [string]: string }, boolean)
	local s = CurioState.squad
	local ids: { string } = {}
	local mut: { [string]: string } = {}
	if s and type(s.ids) == "table" then
		for _, id in s.ids do
			if type(id) == "string" and Brainrots.is(id) then
				table.insert(ids, id)
			end
		end
		if type(s.mut) == "table" then
			for id, m in s.mut do
				if type(id) == "string" and type(m) == "string" then
					mut[id] = m
				end
			end
		end
	end
	local own = #ids > 0
	if not own then
		ids = { "croissantino", "pizzaVolante", "frogKing" }
	end
	table.sort(ids, function(a, b)
		local ra = RANK[Curios.byId[a].rarity] or 0
		local rb = RANK[Curios.byId[b].rarity] or 0
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	while #ids > 6 do
		table.remove(ids)
	end
	return ids, mut, own
end

local function member(o: Opts, id: string, mutKey: string?, size: number, at: Vector3, champion: boolean): Member
	local c = Curios.byId[id]
	local mut = if mutKey then Brainrots.Mutations[mutKey] else nil
	local colour = if mut then mut.colour else (Curios.RarityColour[c.rarity] or rgb(255, 210, 90))
	local p = Instance.new("Part")
	p.Name = if champion then "SquadChampion" else "SquadMember"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(at)
	p:SetAttribute("Curio", id)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Body"
	bb.Size = UDim2.fromScale(size, size)
	bb.LightInfluence = 0
	bb.MaxDistance = 220
	bb.Parent = p
	local aura = Instance.new("Frame")
	aura.Name = "Aura"
	aura.AnchorPoint = Vector2.new(0.5, 0.5)
	aura.Position = UDim2.fromScale(0.5, 0.5)
	aura.Size = UDim2.fromScale(1.08, 1.08)
	aura.BackgroundColor3 = colour
	aura.BackgroundTransparency = 0.55
	aura.BorderSizePixel = 0
	aura.Parent = bb
	corner(aura)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Rotation = 90
	fade.Parent = aura
	local ringGrad: UIGradient? = nil
	if mut then
		local ring = Instance.new("Frame")
		ring.Name = "Mutation"
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(1, 1)
		ring.BackgroundTransparency = 1
		ring.Parent = bb
		corner(ring)
		local st = Instance.new("UIStroke")
		st.Thickness = 5
		st.Color = if mutKey == "rainbow" then Color3.new(1, 1, 1) else mut.colour
		st.Parent = ring
		if mutKey == "rainbow" then
			local g = Instance.new("UIGradient")
			g.Color = RAINBOW
			g.Parent = st
			ringGrad = g
		end
	end
	local g = Instance.new("TextLabel")
	g.Name = "Glyph"
	g.BackgroundTransparency = 1
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.5)
	g.Size = UDim2.fromScale(0.9, 0.9)
	g.TextScaled = true
	g.Text = c.glyph
	g.Parent = bb
	if c.accent ~= "" then
		local a = Instance.new("TextLabel")
		a.Name = "Accent"
		a.BackgroundTransparency = 1
		a.AnchorPoint = Vector2.new(0.5, 0.5)
		a.Position = UDim2.fromScale(0.84, 0.18)
		a.Size = UDim2.fromScale(0.4, 0.4)
		a.TextScaled = true
		a.Text = c.accent
		a.Parent = g
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(240, 44)
	tag.StudsOffset = Vector3.new(0, size * 0.55 + 0.6, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 120
	tag.Parent = p
	local kicker = Instance.new("TextLabel")
	kicker.BackgroundTransparency = 1
	kicker.Size = UDim2.new(1, 0, 0, 16)
	kicker.Text = if champion then "★ CHAMPION ★" else "YOUR SQUAD"
	kicker.FontFace = IMPACT
	kicker.TextSize = 13
	kicker.TextColor3 = rgb(255, 222, 120)
	kicker.TextStrokeTransparency = 0.3
	kicker.Parent = tag
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(0, 16)
	name.Size = UDim2.new(1, 0, 0, 24)
	name.Text = c.name
	name.FontFace = IMPACT
	name.TextSize = 19
	name.TextColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.3)
	name.TextStrokeTransparency = 0.2
	name.Parent = tag
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate = if champion then 40 else 14
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(1, 4)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Color = if mutKey == "rainbow" then RAINBOW else ColorSequence.new(colour)
	sparks.Parent = p
	p.Parent = o.folder
	return { id = id, part = p, gui = bb, glyph = g, size = size, at = at, landed = false, dropAt = 0, ring = ringGrad }
end

-- A word punched onto the screen: big, tilted, in the show's colours, then gone.
local function pop(o: Opts, layer: Frame, text: string, big: boolean?)
	local l = Instance.new("TextLabel")
	l.Name = "MemeWord"
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	-- (Between the caption and the foot of the screen, clear of the dock on the left; the big
	-- ones, FIGHT! and K.O.!, in the middle.)
	l.Position = if big then UDim2.fromScale(0.54, 0.54) else UDim2.fromScale(0.34 + math.random() * 0.4, 0.46 + math.random() * 0.2)
	l.Size = UDim2.fromOffset(if big then 640 else 420, if big then 120 else 80)
	l.Text = text
	l.FontFace = IMPACT
	l.TextScaled = true
	l.TextColor3 = o.palette[math.random(1, #o.palette)]:Lerp(Color3.new(1, 1, 1), 0.25)
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0
	l.Rotation = math.random(-14, 14)
	l.ZIndex = 40
	l.Parent = layer
	local s = Instance.new("UIScale")
	s.Scale = 0.3
	s.Parent = l
	TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
	task.delay(0.18, function()
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end
	end)
	task.delay(if big then 1.4 else 0.75, function()
		if l.Parent then
			TweenService:Create(l, TweenInfo.new(0.25), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(s, TweenInfo.new(0.25), { Scale = 1.4 }):Play()
			task.delay(0.3, function()
				l:Destroy()
			end)
		end
	end)
end

local function commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

function MemeSquad.start(o: Opts): Squad
	local ids, mut, own = castOf()
	local champId = ids[1]
	local champName = Curios.byId[champId].name
	local members: { Member } = {}
	local hp = 1
	local aura = 0
	local hits = 0
	local words = 0
	local koDone = false
	local camera = Workspace.CurrentCamera
	local baseFov = if camera then camera.FieldOfView else 70
	local charge = 0 -- 0..1 of the champion's run at the boss
	local lastHit = 0

	-- The overlay: words, the AURA count, the boss's bar.
	local layer = Instance.new("Frame")
	layer.Name = "MemeSquad"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 38
	layer.Parent = o.gui
	local auraLabel = Instance.new("TextLabel")
	auraLabel.Name = "Aura"
	auraLabel.BackgroundTransparency = 1
	auraLabel.AnchorPoint = Vector2.new(0, 1)
	auraLabel.Position = UDim2.new(0, 24, 1, -90)
	auraLabel.Size = UDim2.fromOffset(360, 44)
	auraLabel.Text = ""
	auraLabel.FontFace = IMPACT
	auraLabel.TextSize = 34
	auraLabel.TextXAlignment = Enum.TextXAlignment.Left
	auraLabel.TextColor3 = rgb(255, 230, 120)
	auraLabel.TextStrokeTransparency = 0
	auraLabel.ZIndex = 41
	auraLabel.Parent = layer
	local bar = Instance.new("Frame")
	bar.Name = "BossBar"
	-- (At the foot of the screen, in the middle: the top is the Gilt bar's and the keys'.)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -36)
	bar.Size = UDim2.new(0.4, 0, 0, 46)
	local barMax = Instance.new("UISizeConstraint")
	barMax.MaxSize = Vector2.new(520, 46)
	barMax.Parent = bar
	bar.BackgroundTransparency = 1
	bar.Visible = false
	bar.ZIndex = 41
	bar.Parent = layer
	local barTitle = Instance.new("TextLabel")
	barTitle.Name = "Title"
	barTitle.BackgroundTransparency = 1
	barTitle.Size = UDim2.new(1, 0, 0, 20)
	barTitle.Text = string.upper(o.bossName)
	barTitle.FontFace = IMPACT
	barTitle.TextSize = 18
	barTitle.TextColor3 = Color3.new(1, 1, 1)
	barTitle.TextStrokeTransparency = 0.2
	barTitle.ZIndex = 42
	barTitle.Parent = bar
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(0, 24)
	track.Size = UDim2.new(1, 0, 0, 18)
	track.BackgroundColor3 = rgb(20, 10, 14)
	track.BorderSizePixel = 0
	track.ZIndex = 42
	track.Parent = bar
	corner(track, 0.5)
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = 2
	edge.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.ZIndex = 43
	fill.Parent = track
	corner(fill, 0.5)
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new(rgb(255, 70, 90), rgb(255, 170, 60))
	fg.Parent = fill

	local function addAura(n: number)
		aura += n
		auraLabel.Text = "AURA  " .. commas(aura)
	end

	local function slot(k: number, you: Vector3, ahead: number): Vector3
		local n = #members
		return you + o.front * ahead + o.right * ((k - (n + 1) / 2) * 4.6)
	end

	local function punch(strength: number)
		local cam = Workspace.CurrentCamera
		if not cam or Ease.motionScale < 0.5 then
			return
		end
		cam.FieldOfView = baseFov - strength
		TweenService:Create(cam, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { FieldOfView = baseFov }):Play()
	end

	local self = {} :: any

	function self.act(_: Squad, n: number, t: number)
		if n == 2 then
			-- They drop in, one after another, in a line in front of you.
			for k, id in ids do
				local champion = k == 1
				local size = (if champion then 7.5 else 5.2) + (RANK[Curios.byId[id].rarity] or 1) * 0.25
				local m = member(o, id, mut[id], size, Vector3.new(0, o.ceiling + 6, 0), champion)
				m.dropAt = t + 1.2 + (k - 1) * 0.55
				table.insert(members, m)
			end
			task.delay(1.2, function()
				if layer.Parent then
					o.caption(if own then "YOUR SQUAD HAS ARRIVED" else "THE HOUSE LENDS YOU A CHAMPION", 2.6, if own then string.format("%d BRAINROTS  ·  LED BY %s", #ids, string.upper(champName)) else "PUT BRAINROTS IN YOUR SQUAD AND THEY STAR IN THE SHOW")
				end
			end)
			addAura(0)
		elseif n == 5 then
			bar.Visible = true
			o.sound("airHorn", 0.6, 0.3, 0.9)
		elseif n == 6 then
			o.caption(string.upper(champName) .. "  VS  " .. string.upper(o.bossName), 2.6, "THE SQUAD BATTLE")
			pop(o, layer, "FIGHT!", true)
			o.sound("airHorn", 0.9, 0)
			punch(10)
		elseif n == 7 and not koDone then
			koDone = true
			hp = 0
			fill.Size = UDim2.fromScale(0, 1)
			barTitle.Text = string.upper(o.bossName) .. "  ·  DEFEATED"
			for _, w in layer:GetChildren() do
				if w.Name == "MemeWord" then
					w:Destroy()
				end
			end
			pop(o, layer, "K.O.!", true)
			-- (Its own banner: the finale's words come at the same moment and keep the caption.)
			local win = Instance.new("TextLabel")
			win.Name = "Winner"
			win.BackgroundTransparency = 1
			win.AnchorPoint = Vector2.new(0.5, 0.5)
			win.Position = UDim2.fromScale(0.54, 0.7)
			win.Size = UDim2.new(0.7, 0, 0, 64)
			win.Text = string.upper(champName) .. " WINS!"
			win.FontFace = IMPACT
			win.TextScaled = true
			win.TextColor3 = rgb(255, 226, 110)
			win.TextStrokeTransparency = 0
			win.ZIndex = 44
			win.Parent = layer
			local ws = Instance.new("UIScale")
			ws.Scale = 0.4
			ws.Parent = win
			TweenService:Create(ws, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			task.delay(3.2, function()
				if win.Parent then
					TweenService:Create(win, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				end
			end)
			o.sound("fireworkBoom", 1, 0, 0.7)
			o.shake(0.8, 0.6)
			punch(14)
			auraLabel.Text = "AURA  ∞"
			for _, m in members do
				o.burst(m.at, 40)
			end
		end
	end

	function self.beat(_: Squad, n: number, act: number)
		if act >= 2 and act <= 6 then
			addAura(if act == 6 then 2500 else 100 * act)
		end
		local every = if act == 6 then 2 else 4
		if act >= 3 and act <= 6 and n % every == 0 then
			words += 1
			pop(o, layer, WORDS[(words * 7 + n) % #WORDS + 1])
		end
		if act >= 5 and act <= 6 and n % 8 == 0 then
			punch(if act == 6 then 8 else 5)
		end
	end

	function self.step(_: Squad, t: number, dt: number, you: Vector3, bossAt: Vector3?, act: number, inAct: number)
		local k = math.min(1, dt * 5)
		for i, m in members do
			if not m.part.Parent then
				continue
			end
			local home = slot(i, you, 6)
			local goal: Vector3 = home
			local hop = 0
			if not m.landed then
				-- Dropping in: from the ceiling straight down to its place, then a thud.
				if t < m.dropAt then
					m.at = Vector3.new(home.X, o.ceiling + 4, home.Z)
				else
					local y = m.at.Y - dt * 60
					local floor = o.floorY + m.size / 2
					if y <= floor then
						y = floor
						m.landed = true
						o.shockwave(Vector3.new(home.X, o.floorY + 0.3, home.Z), o.palette[i % #o.palette + 1], m.size * 1.6)
						o.burst(Vector3.new(home.X, o.floorY + 1, home.Z), 30)
						o.sound("subHit", 0.8, 0, 0.9 + i * 0.05)
						o.shake(0.25, 0.2)
					end
					m.at = Vector3.new(home.X, y, home.Z)
				end
				m.part.CFrame = CFrame.new(m.at)
				continue
			end
			if act == 3 then
				-- Leading the dance: hopping on the beat, a twirl now and then.
				hop = math.abs(math.sin(t * 4.2 + i)) * 2.2
			elseif act == 4 then
				-- Rings round you in the rain.
				local ang = t * 1.8 + i / #members * math.pi * 2
				goal = you + Vector3.new(math.cos(ang) * 5.5, 0, math.sin(ang) * 5.5)
				hop = math.abs(math.sin(t * 6 + i)) * 1.2
			elseif (act == 5 or act == 6) and bossAt then
				-- On guard between you and the boss; in the chaos, the champion charges it.
				local to = Vector3.new(bossAt.X - you.X, 0, bossAt.Z - you.Z)
				local dir = if to.Magnitude > 0.5 then to.Unit else o.front
				local side = dir:Cross(Vector3.new(0, 1, 0))
				goal = you + dir * (to.Magnitude * 0.38) + side * ((i - (#members + 1) / 2) * 4.6)
				hop = math.abs(math.sin(t * 5 + i)) * 1.4
				if act == 6 and i == 1 then
					charge = (inAct * 1.1) % 1
					local reach = bossAt - dir * (o.bossSize * 0.45 + m.size * 0.4)
					local sweep = math.sin(charge * math.pi)
					goal = goal:Lerp(Vector3.new(reach.X, goal.Y, reach.Z), sweep)
					hop = sweep * 3
					if charge > 0.45 and charge < 0.55 and t - lastHit > 0.5 then
						lastHit = t
						hits += 1
						hp = math.max(0.04, hp - 0.075)
						TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(hp, 1) }):Play()
						o.shockwave(Vector3.new(reach.X, o.floorY + 0.4, reach.Z), Color3.new(1, 1, 1), 12)
						o.burst(reach + Vector3.new(0, 2, 0), 35)
						o.sound("subHit", 1, 0, 1.1)
						o.shake(0.45, 0.25)
						pop(o, layer, HITS[hits % #HITS + 1])
						addAura(5000)
					end
				end
			elseif act == 7 then
				-- The bow.
				hop = 0
			end
			local floor = o.floorY + m.size / 2
			local target = Vector3.new(goal.X, floor + hop, goal.Z)
			m.at = m.at:Lerp(target, if act == 6 and i == 1 then math.min(1, dt * 12) else k)
			m.part.CFrame = CFrame.new(m.at)
			local squash = 1 + math.sin(t * 9 + i) * 0.06
			local grow = if i == 1 and act >= 5 then 1 + math.min(0.3, (if act == 5 then inAct else 10) * 0.03) else 1
			m.gui.Size = UDim2.fromScale(m.size * squash * grow, m.size / squash * grow)
			m.glyph.Rotation = if act == 3 and (math.floor(t * 0.5 + i) % 3 == 0) then (t * 360) % 360 else math.sin(t * 6 + i) * 10
			local ring = m.ring
			if ring then
				ring.Rotation = (t * 120) % 360
			end
		end
		last = { champion = champId, hp = hp, aura = aura, hits = hits, words = words, members = #members, own = own }
	end

	function self.finish(_: Squad)
		local cam = Workspace.CurrentCamera
		if cam then
			cam.FieldOfView = baseFov
		end
		for _, m in members do
			m.part:Destroy()
		end
		table.clear(members)
		layer:Destroy()
	end

	function self.state(_: Squad): { [string]: any }
		return { champion = champId, hp = hp, aura = aura, hits = hits, words = words, members = #members, own = own }
	end

	last = { champion = champId, hp = hp, aura = 0, hits = 0, words = 0, members = 0, own = own }
	return self :: Squad
end

-- For tests: the last show's squad (its champion, the boss's bar, the AURA, hits and words).
function MemeSquad.last(): { [string]: any }?
	return last
end

return MemeSquad
