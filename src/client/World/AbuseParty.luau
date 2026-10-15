--!strict
-- Admin Abuse's party, on this screen: while Admin Abuse or Mega Abuse is on, the house dances to
-- the music, beat by beat (each dance track's beat is known: Config.Assets.AbuseMusic's bpm and
-- beat, read against how far into the track the music is).
--   the floor     the Foyer's black-and-bone marble lights up as a dance floor, a new pattern every
--                 few bars (a checkerboard, ripples, a sweep, a spinning wheel, sparkles)
--   the stair     its brass nosings light up the stair in a run, like a piano's keys; the
--                 balusters bob to the beat
--   the ceiling   every so often the coffers drop out of the ceiling and fly round the room, the
--                 ceiling itself lifts away to the sky, and everything drops back into place
--   the ball      a mirror ball under the chandelier, its beams turning over the floor
--   the crew      brainrots dance round you wherever you go (your squad first), and a conga line
--                 of them hops round the Foyer
--   the beat      on every beat something: confetti cannons from the walls, sparks out of the
--                 floor, a flash of light, a shower from the ceiling on the big ones
--   the games     the Gold Tile (a tile lit gold, with a marker to find it from anywhere) and the
--                 Piñata (hanging under the chandelier, its bar filling as everyone hits it)
-- At a table, the sorting screen dances instead (AbuseParty.tableBeat: SortScreen.partyBeat).
-- Everything is put back exactly as it was when it ends. Nothing here is kept or pays: the server
-- checks the games and pays (server/AbuseParty).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CurioState = require(script.Parent.Parent.CurioState)
local Quality = require(script.Parent.Parent.Quality)
local Sound = require(script.Parent.Parent.Sound)

local AbuseParty = {}

-- Hooks (set by Main).
AbuseParty.isBusy = function(): boolean
	return false -- at a table: the sorting screen dances instead
end
AbuseParty.tableBeat = function(_beat: number, _colour: Color3, _mega: boolean) end
AbuseParty.tableStop = function() end
AbuseParty.toast = function(_title: string, _line: string) end
AbuseParty.shake = function(_size: number, _seconds: number) end

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
-- (The party's lights: hot pink, sky blue, gold, violet, mint and tangerine. Mega Abuse: every
-- colour, turning.)
local PARTY = { rgb(255, 64, 150), rgb(70, 200, 255), rgb(255, 206, 70), rgb(160, 90, 255), rgb(90, 255, 170), rgb(255, 140, 60) }
local GOLD = rgb(255, 204, 84)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function abusing(): boolean
	local ends = Workspace:GetAttribute("AbuseUntil")
	return type(ends) == "number" and ends > Workspace:GetServerTimeNow()
end

local function isMega(): boolean
	return Workspace:GetAttribute("AbuseMega") == true
end

local function sound(name: string, volume: number?, pitch: number?)
	pcall(Sound.play, name, volume or 0.6, pitch)
end

---------------------------------------------------------------------------------------------------
-- The beat
---------------------------------------------------------------------------------------------------
type Tempo = { bpm: number, beat: number }
local tempos: { [string]: Tempo }? = nil

local function tempoOf(id: string): Tempo?
	local t = tempos
	if not t then
		local made: { [string]: Tempo } = {}
		local lists = (Config.data.Assets :: any).AbuseMusic or {}
		for _, list in lists do
			if type(list) == "table" then
				for _, song in list do
					if type(song) == "table" and type(song.id) == "string" and type(song.bpm) == "number" and song.bpm > 0 then
						made[song.id] = { bpm = song.bpm, beat = if type(song.beat) == "number" then song.beat else 0 }
					end
				end
			end
		end
		tempos = made
		t = made
	end
	return (t :: { [string]: Tempo })[id]
end

-- The beat now: a running count (its fraction is how far through this beat) and a beat's length
-- in seconds. On the track playing when its beat is known (a very fast one, drum and bass, counts
-- every other beat); else a steady 124 to the minute.
function AbuseParty.beatNow(): (number, number)
	local id, at = Sound.scoreNow()
	if id and at then
		local t = tempoOf(id)
		if t then
			local period = 60 / t.bpm
			if t.bpm > 150 then
				period *= 2
			end
			return (at - t.beat) / period, period
		end
	end
	local period = 60 / 124
	return Workspace:GetServerTimeNow() / period, period
end

-- The colour of the light for a place on the floor and a beat.
local function hue(k: number, b: number, mega: boolean): Color3
	if mega then
		return Color3.fromHSV((k * 0.07 + b * 0.045) % 1, 0.8, 1)
	end
	return PARTY[(math.floor(k) + b) % #PARTY + 1]
end

---------------------------------------------------------------------------------------------------
-- What's borrowed from the house (and put back exactly)
---------------------------------------------------------------------------------------------------
type Saved = { color: Color3, material: Enum.Material, cf: CFrame, transparency: number }
local saved: { [BasePart]: Saved } = {}
local lightsWere: { [Light]: Color3 } = {}

local function keep(p: BasePart)
	if not saved[p] then
		saved[p] = { color = p.Color, material = p.Material, cf = p.CFrame, transparency = p.Transparency }
	end
end

local function light(p: BasePart, colour: Color3)
	keep(p)
	p.Color = colour
	p.Material = Enum.Material.Neon
end

local function unlight(p: BasePart)
	local s = saved[p]
	if s then
		p.Color = s.color
		p.Material = s.material
	end
end

local function restoreAll()
	for p, s in saved do
		if p.Parent then
			p.Color = s.color
			p.Material = s.material
			p.CFrame = s.cf
			p.Transparency = s.transparency
		end
	end
	table.clear(saved)
	for l, c in lightsWere do
		if l.Parent then
			l.Color = c
		end
	end
	table.clear(lightsWere)
end

type Tile = { part: BasePart, ix: number, iz: number }
type Foyer = {
	tiles: { Tile },
	nx: number,
	nz: number,
	nosings: { BasePart },
	balusters: { BasePart },
	coffers: { BasePart },
	ceilings: { BasePart },
	lights: { Light },
	centre: Vector3,
	floorY: number,
	top: number,
	min: Vector3,
	max: Vector3,
}
local foyer: Foyer? = nil
local scannedAt = -math.huge

local function scan()
	scannedAt = os.clock()
	local maison = Workspace:FindFirstChild("Maison")
	local f = maison and maison:FindFirstChild("Foyer")
	if not f then
		foyer = nil
		return
	end
	local tiles: { Tile } = {}
	local first: BasePart? = nil
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	local floorY = 0
	local coffers: { BasePart } = {}
	local ceilings: { BasePart } = {}
	local top = 0
	for _, d in f:GetChildren() do
		if d:IsA("BasePart") then
			if d.Name == "Tile" then
				local p = d.CFrame.Position
				first = first or d
				minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
				minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
				floorY = p.Y + d.Size.Y / 2
				table.insert(tiles, { part = d, ix = 0, iz = 0 })
			elseif d.Name == "Coffer" or d.Name == "CofferEdge" then
				table.insert(coffers, d)
			elseif d.Name == "Ceiling" then
				table.insert(ceilings, d)
				top = math.max(top, d.CFrame.Position.Y - d.Size.Y / 2)
			end
		end
	end
	local tw = if first then first.Size.X else 1
	local td = if first then first.Size.Z else 1
	local nx, nz = 1, 1
	for _, t in tiles do
		local p = t.part.CFrame.Position
		t.ix = math.floor((p.X - minX) / tw + 0.5)
		t.iz = math.floor((p.Z - minZ) / td + 0.5)
		nx = math.max(nx, t.ix + 1)
		nz = math.max(nz, t.iz + 1)
	end
	local nosings: { BasePart } = {}
	local balusters: { BasePart } = {}
	local stair = f:FindFirstChild("GrandStair")
	if stair then
		for _, d in stair:GetChildren() do
			if d:IsA("BasePart") then
				if d.Name == "Nosing" then
					table.insert(nosings, d)
				elseif d.Name == "Baluster" then
					table.insert(balusters, d)
				end
			end
		end
		table.sort(nosings, function(a, b)
			return a.CFrame.Position.Z < b.CFrame.Position.Z
		end)
	end
	local lights: { Light } = {}
	for _, d in f:GetDescendants() do
		if d:IsA("Light") then
			table.insert(lights, d)
		end
	end
	local chandelier = f:FindFirstChild("Chandelier")
	local centre = Vector3.new((minX + maxX) / 2, floorY, (minZ + maxZ) / 2)
	if chandelier and chandelier:IsA("Model") then
		local boss = chandelier:FindFirstChild("Boss")
		if boss and boss:IsA("BasePart") then
			centre = Vector3.new(boss.CFrame.Position.X, floorY, boss.CFrame.Position.Z)
		end
	end
	foyer = {
		tiles = tiles,
		nx = nx,
		nz = nz,
		nosings = nosings,
		balusters = balusters,
		coffers = coffers,
		ceilings = ceilings,
		lights = lights,
		centre = centre,
		floorY = floorY,
		top = if top > 0 then top else floorY + 40,
		min = Vector3.new(minX - tw / 2, floorY, minZ - td / 2),
		max = Vector3.new(maxX + tw / 2, floorY, maxZ + td / 2),
	}
end

---------------------------------------------------------------------------------------------------
-- The party's own things (on this screen only)
---------------------------------------------------------------------------------------------------
local stage: Folder? = nil

local function stageFolder(): Folder
	local s = stage
	if s and s.Parent then
		return s
	end
	local f = Instance.new("Folder")
	f.Name = "AbuseParty"
	f.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	stage = f
	return f
end

local function localPart(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Parent = stageFolder()
	return p
end

local function emitter(parent: Instance, colours: { Color3 }, speed: NumberRange, life: NumberRange, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Rate = 0
	e.Speed = speed
	e.Lifetime = life
	e.SpreadAngle = Vector2.new(22, 22)
	e.Acceleration = Vector3.new(0, -26, 0)
	e.Drag = 1.2
	e.RotSpeed = NumberRange.new(-260, 260)
	e.Rotation = NumberRange.new(0, 360)
	e.LightEmission = 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(0.8, size * 0.8), NumberSequenceKeypoint.new(1, 0) })
	local keys = {}
	for i, c in colours do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colours - 1), c))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, colours[1]))
	end
	e.Color = ColorSequence.new(keys)
	e.Parent = parent
	return e
end

local function emit(e: ParticleEmitter?, n: number)
	if e and e.Parent then
		pcall(function()
			e:Emit(math.max(1, Quality.count(n)))
		end)
	end
end

type Dancer = { part: Part, glyph: TextLabel, medal: Frame, disc: Part, move: number, k: number, crew: boolean }
type Rig = {
	cannons: { ParticleEmitter },
	sparks: ParticleEmitter?,
	sparkPart: Part?,
	shower: ParticleEmitter?,
	near: ParticleEmitter?,
	nearPart: Part?,
	ball: Part?,
	beams: { { beam: Beam, end_: Attachment } },
	dancers: { Dancer },
	pulse: ColorCorrectionEffect?,
	marker: Part?,
	markerGui: BillboardGui?,
	column: Part?,
	pinataGui: BillboardGui?,
	burst: ParticleEmitter?,
	burstPart: Part?,
}
local rig: Rig? = nil

-- A brainrot to dance: its medallion (its colour, its big glyph and its accent) on a billboard,
-- over a disc of light on the floor.
local function dancer(id: string, crew: boolean, k: number): Dancer
	local c = Curios.byId[id]
	local part = localPart("Dancer", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, -200, 0), Color3.new(), nil, 1)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Dance"
	gui.Size = UDim2.fromScale(4.2, 4.2)
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = part
	local medal = Instance.new("Frame")
	medal.Name = "Medal"
	medal.AnchorPoint = Vector2.new(0.5, 0.5)
	medal.Position = UDim2.fromScale(0.5, 0.5)
	medal.Size = UDim2.fromScale(0.86, 0.86)
	medal.BackgroundColor3 = if c then c.colour else GOLD
	medal.BorderSizePixel = 0
	medal.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = medal
	local rim = Instance.new("UIStroke")
	rim.Color = if c then Curios.RarityColour[c.rarity] or GOLD else GOLD
	rim.Thickness = 3
	rim.Parent = medal
	local shine = Instance.new("UIGradient")
	shine.Rotation = 120
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(120, 120, 120))
	shine.Parent = medal
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.52)
	glyph.Size = UDim2.fromScale(0.8, 0.8)
	glyph.TextScaled = true
	glyph.Text = if c then c.glyph else "✨"
	glyph.Parent = medal
	if c and c.accent then
		local accent = Instance.new("TextLabel")
		accent.Name = "Accent"
		accent.BackgroundTransparency = 1
		accent.AnchorPoint = Vector2.new(0.5, 0.5)
		accent.Position = UDim2.fromScale(0.86, 0.16)
		accent.Size = UDim2.fromScale(0.36, 0.36)
		accent.TextScaled = true
		accent.Text = c.accent
		accent.Parent = medal
	end
	local disc = localPart("DanceDisc", Vector3.new(0.12, 3.6, 3.6), CFrame.new(0, -200, 0) * CFrame.Angles(0, 0, math.pi / 2), if c then c.colour else GOLD, Enum.Material.Neon, 0.45)
	disc.Shape = Enum.PartType.Cylinder
	return { part = part, glyph = glyph, medal = medal, disc = disc, move = (k % 4) + 1, k = k, crew = crew }
end

-- Who dances: your squad first (your best in front), then the house's own brainrots.
local function castIds(n: number): { string }
	local ids: { string } = {}
	local s = CurioState.squad
	if s and type(s.ids) == "table" then
		for _, id in s.ids do
			if type(id) == "string" and Brainrots.is(id) and #ids < n then
				table.insert(ids, id)
			end
		end
	end
	local pool: { string } = {}
	for _, c in Curios.List do
		if c.family == "meme" then
			table.insert(pool, c.id)
		end
	end
	local i = 0
	while #ids < n and #pool > 0 do
		i += 1
		table.insert(ids, pool[(i * 7) % #pool + 1])
	end
	return ids
end

local function buildRig(): Rig
	local r: Rig = { cannons = {}, beams = {}, dancers = {} }
	local f = foyer
	local mega = isMega()
	local rich = Quality.rich()
	if f then
		-- Confetti cannons in the four corners, aimed into the room.
		for _, corner in { Vector3.new(f.min.X + 3, 0, f.min.Z + 3), Vector3.new(f.max.X - 3, 0, f.min.Z + 3), Vector3.new(f.min.X + 3, 0, f.max.Z - 8), Vector3.new(f.max.X - 3, 0, f.max.Z - 8) } do
			local at = Vector3.new(corner.X, f.floorY + 3, corner.Z)
			local aim = Vector3.new(f.centre.X, f.floorY + 18, f.centre.Z)
			local p = localPart("Cannon", Vector3.new(0.5, 0.5, 0.5), CFrame.lookAt(at, aim) * CFrame.Angles(-math.pi / 2, 0, 0), Color3.new(), nil, 1)
			local e = emitter(p, PARTY, NumberRange.new(55, 85), NumberRange.new(2.2, 3.4), 0.55)
			e.EmissionDirection = Enum.NormalId.Top
			e.SpreadAngle = Vector2.new(14, 14)
			table.insert(r.cannons, e)
		end
		-- Sparks out of the floor (moved to a lit tile each time).
		local sp = localPart("FloorSparks", Vector3.new(4, 0.2, 4), CFrame.new(f.centre), Color3.new(), nil, 1)
		local se = emitter(sp, { GOLD, Color3.new(1, 1, 1) }, NumberRange.new(14, 26), NumberRange.new(0.8, 1.4), 0.4)
		se.EmissionDirection = Enum.NormalId.Top
		se.Acceleration = Vector3.new(0, -12, 0)
		r.sparks, r.sparkPart = se, sp
		-- A shower from the ceiling on the big beats.
		local size = f.max - f.min
		local sh = localPart("Shower", Vector3.new(math.max(4, size.X - 8), 0.2, math.max(4, size.Z - 8)), CFrame.new(f.centre.X, f.top - 2, f.centre.Z), Color3.new(), nil, 1)
		local she = emitter(sh, PARTY, NumberRange.new(2, 6), NumberRange.new(4, 6), 0.6)
		she.EmissionDirection = Enum.NormalId.Bottom
		she.Acceleration = Vector3.new(0, -8, 0)
		she.Shape = Enum.ParticleEmitterShape.Box
		r.shower = she
		-- The mirror ball under the chandelier, and its beams turning over the floor.
		local ballAt = Vector3.new(f.centre.X, f.top - 13, f.centre.Z)
		local ball = localPart("MirrorBall", Vector3.new(3.4, 3.4, 3.4), CFrame.new(ballAt), rgb(220, 224, 232), Enum.Material.Foil)
		ball.Shape = Enum.PartType.Ball
		ball.Reflectance = 0.5
		r.ball = ball
		local glint = emitter(ball, { Color3.new(1, 1, 1) }, NumberRange.new(0, 0), NumberRange.new(0.25, 0.5), 0.35)
		glint.Rate = if rich then 14 else 5
		glint.Acceleration = Vector3.zero
		if rich then
			local from = Instance.new("Attachment")
			from.Parent = ball
			for k = 1, if mega then 8 else 6 do
				local holder = localPart("BeamEnd", Vector3.new(0.2, 0.2, 0.2), CFrame.new(f.centre), Color3.new(), nil, 1)
				local to = Instance.new("Attachment")
				to.Parent = holder
				local beam = Instance.new("Beam")
				beam.Attachment0 = from
				beam.Attachment1 = to
				beam.Width0 = 0.25
				beam.Width1 = 2.6
				beam.LightEmission = 1
				beam.FaceCamera = true
				beam.Color = ColorSequence.new(hue(k, 0, mega))
				beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.85) })
				beam.Parent = ball
				table.insert(r.beams, { beam = beam, end_ = to })
			end
		end
		-- The conga line round the Foyer.
		local conga = Quality.count(if mega then 10 else 7, 3)
		for k, id in castIds(conga) do
			table.insert(r.dancers, dancer(id, false, k))
		end
	end
	-- Confetti round you, wherever you are.
	local np = localPart("NearConfetti", Vector3.new(1, 1, 1), CFrame.new(0, -200, 0), Color3.new(), nil, 1)
	local ne = emitter(np, PARTY, NumberRange.new(22, 34), NumberRange.new(1.6, 2.4), 0.45)
	ne.EmissionDirection = Enum.NormalId.Top
	ne.SpreadAngle = Vector2.new(40, 40)
	r.near, r.nearPart = ne, np
	-- Your crew: brainrots dancing round you.
	local crew = Quality.count(if mega then 7 else 5, 2)
	for k, id in castIds(crew) do
		table.insert(r.dancers, dancer(id, true, k))
	end
	-- The light, pulsing on the beat.
	local pulse = Instance.new("ColorCorrectionEffect")
	pulse.Name = "PartyPulse"
	pulse.Parent = Lighting
	r.pulse = pulse
	-- The piñata's burst.
	local bp = localPart("PinataBurst", Vector3.new(1, 1, 1), CFrame.new(0, -200, 0), Color3.new(), nil, 1)
	local be = emitter(bp, { rgb(255, 72, 140), rgb(70, 190, 255), rgb(120, 230, 110), rgb(255, 150, 50), rgb(190, 110, 255), GOLD }, NumberRange.new(30, 60), NumberRange.new(2, 3.4), 0.7)
	be.SpreadAngle = Vector2.new(180, 180)
	r.burst, r.burstPart = be, bp
	return r
end

local function clearRig()
	local r = rig
	rig = nil
	if r and r.pulse then
		r.pulse:Destroy()
	end
	local s = stage
	stage = nil
	if s then
		s:Destroy()
	end
end

---------------------------------------------------------------------------------------------------
-- The Gold Tile and the Piñata (drawn; the server runs them)
---------------------------------------------------------------------------------------------------
local goldTile: Tile? = nil

local function tileNear(at: Vector3): Tile?
	local f = foyer
	if not f then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, t in f.tiles do
		local p = t.part.CFrame.Position
		local d = (Vector3.new(p.X - at.X, 0, p.Z - at.Z)).Magnitude
		if d < bestD then
			best, bestD = t, d
		end
	end
	return if bestD < 6 then best else nil
end

-- A marker over the Gold Tile that shows through walls (so it can be found from anywhere): the
-- words, the seconds left in a gold ring, and a column of light on the tile.
local function marker(r: Rig, at: Vector3, seconds: number)
	local holder = r.marker
	if not holder then
		holder = localPart("GoldTileMarker", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at + Vector3.new(0, 9, 0)), Color3.new(), nil, 1)
		r.marker = holder
		local gui = Instance.new("BillboardGui")
		gui.Name = "Marker"
		gui.AlwaysOnTop = true
		gui.Size = UDim2.fromOffset(170, 92)
		gui.LightInfluence = 0
		gui.MaxDistance = 400
		gui.Parent = holder
		r.markerGui = gui
		local ring = Instance.new("TextLabel")
		ring.Name = "Seconds"
		ring.AnchorPoint = Vector2.new(0.5, 0)
		ring.Position = UDim2.fromScale(0.5, 0)
		ring.Size = UDim2.fromOffset(40, 40)
		ring.BackgroundColor3 = rgb(24, 18, 8)
		ring.TextColor3 = GOLD
		ring.Font = Enum.Font.GothamBlack
		ring.TextSize = 20
		ring.Text = ""
		ring.Parent = gui
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(1, 0)
		rc.Parent = ring
		local rs = Instance.new("UIStroke")
		rs.Color = GOLD
		rs.Thickness = 2.5
		rs.Parent = ring
		local words = Instance.new("TextLabel")
		words.Name = "Words"
		words.BackgroundTransparency = 1
		words.AnchorPoint = Vector2.new(0.5, 0)
		words.Position = UDim2.fromOffset(85, 44)
		words.Size = UDim2.new(1, 0, 0, 24)
		words.Font = Enum.Font.GothamBlack
		words.TextSize = 17
		words.TextColor3 = GOLD
		words.TextStrokeTransparency = 0.35
		words.Text = "GOLD TILE"
		words.Parent = gui
		local how = Instance.new("TextLabel")
		how.Name = "How"
		how.BackgroundTransparency = 1
		how.AnchorPoint = Vector2.new(0.5, 0)
		how.Position = UDim2.fromOffset(85, 68)
		how.Size = UDim2.new(1, 0, 0, 18)
		how.Font = Enum.Font.GothamBold
		how.TextSize = 13
		how.TextColor3 = Color3.new(1, 1, 1)
		how.TextStrokeTransparency = 0.4
		how.Text = "Stand on it"
		how.Parent = gui
		local column = localPart("GoldColumn", Vector3.new(30, 6, 6), CFrame.new(at + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.Material.Neon, 0.82)
		column.Shape = Enum.PartType.Cylinder
		r.column = column
	end
	(holder :: Part).CFrame = CFrame.new(at + Vector3.new(0, 9, 0))
	local gui = r.markerGui
	local secondsLabel = gui and gui:FindFirstChild("Seconds")
	if secondsLabel and secondsLabel:IsA("TextLabel") then
		secondsLabel.Text = tostring(math.max(0, math.ceil(seconds)))
	end
	local column = r.column
	if column then
		column.CFrame = CFrame.new(at + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	end
end

local function dropMarker(r: Rig)
	if r.marker then
		r.marker:Destroy()
		r.marker = nil
		r.markerGui = nil
	end
	if r.column then
		r.column:Destroy()
		r.column = nil
	end
end

-- The piñata's bar over it (through walls too): its name, how close it is to bursting, and what
-- to do.
local function pinataBar(r: Rig, body: BasePart, hits: number, needed: number)
	local gui = r.pinataGui
	if not gui or gui.Parent ~= body then
		if gui then
			gui:Destroy()
		end
		local g = Instance.new("BillboardGui")
		g.Name = "PinataBar"
		g.AlwaysOnTop = true
		g.Size = UDim2.fromOffset(200, 64)
		g.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
		g.LightInfluence = 0
		g.MaxDistance = 400
		g.Parent = body
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 22)
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 17
		title.TextColor3 = GOLD
		title.TextStrokeTransparency = 0.35
		title.Text = "THE PIÑATA"
		title.Parent = g
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Position = UDim2.fromOffset(10, 26)
		track.Size = UDim2.new(1, -20, 0, 12)
		track.BackgroundColor3 = rgb(20, 16, 10)
		track.BorderSizePixel = 0
		track.Parent = g
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(1, 0)
		tc.Parent = track
		local ts = Instance.new("UIStroke")
		ts.Color = GOLD
		ts.Thickness = 1.5
		ts.Parent = track
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		fill.BorderSizePixel = 0
		fill.Parent = track
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = fill
		local fg = Instance.new("UIGradient")
		fg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 72, 140)), ColorSequenceKeypoint.new(0.5, GOLD), ColorSequenceKeypoint.new(1, rgb(70, 200, 255)) })
		fg.Parent = fill
		local line = Instance.new("TextLabel")
		line.Name = "Line"
		line.BackgroundTransparency = 1
		line.Position = UDim2.fromOffset(0, 42)
		line.Size = UDim2.new(1, 0, 0, 18)
		line.Font = Enum.Font.GothamBold
		line.TextSize = 13
		line.TextColor3 = Color3.new(1, 1, 1)
		line.TextStrokeTransparency = 0.4
		line.Text = "Hit it to break it open"
		line.Parent = g
		r.pinataGui = g
		gui = g
	end
	local track = (gui :: BillboardGui):FindFirstChild("Track")
	local fill = track and track:FindFirstChild("Fill")
	if fill and fill:IsA("Frame") then
		fill.Size = UDim2.fromScale(math.clamp(hits / math.max(1, needed), 0, 1), 1)
	end
end

---------------------------------------------------------------------------------------------------
-- Every beat, and every frame
---------------------------------------------------------------------------------------------------
local PATTERNS = { "checker", "ripple", "sweep", "wheel", "sparkle", "cross" }
local lastBeat = -math.huge
local roofFrom = -math.huge
local roofSeconds = 0
local pinataHits = 0
local pinataSwing = 0

local function onFloor(t: Tile, pattern: string, b: number, f: Foyer): boolean
	local cx, cz = (f.nx - 1) / 2, (f.nz - 1) / 2
	if pattern == "checker" then
		return (t.ix + t.iz + b) % 2 == 0
	elseif pattern == "ripple" then
		local d = math.floor(math.sqrt((t.ix - cx) ^ 2 + (t.iz - cz) ^ 2) + 0.5)
		return (d - b) % 4 == 0
	elseif pattern == "sweep" then
		return (t.ix + t.iz - b) % 5 == 0
	elseif pattern == "wheel" then
		local a = math.atan2(t.iz - cz, t.ix - cx)
		local seg = math.floor((a / (2 * math.pi) + 0.5) * 8)
		return (seg - b) % 4 == 0
	elseif pattern == "sparkle" then
		return ((t.ix * 73 + t.iz * 151 + b * 37) % 7) < 2
	end
	return t.ix == b % f.nx or t.iz == b % f.nz
end

local function beat(b: number, period: number)
	local mega = isMega()
	local r = rig
	if AbuseParty.isBusy() then
		AbuseParty.tableBeat(b, hue(b, b, mega), mega)
	end
	local f = foyer
	if f and r then
		-- The floor.
		local pattern = PATTERNS[(b // 16) % #PATTERNS + 1]
		local gold = goldTile
		for _, t in f.tiles do
			if gold and t == gold then
				continue
			end
			if onFloor(t, pattern, b, f) then
				-- (While a Gold Tile is lit, the floor dims to let it shine.)
				local c = hue(t.ix + t.iz, b, mega)
				light(t.part, if gold then c:Lerp(Color3.new(0.1, 0.1, 0.12), 0.55) else c)
			else
				unlight(t.part)
			end
		end
		-- The stair, a run of light up its nosings.
		for i, n in f.nosings do
			if (i - b) % 4 == 0 then
				light(n, hue(i, b, mega))
			else
				unlight(n)
			end
		end
		-- The lamps, colours chasing round the room.
		for i, l in f.lights do
			if not lightsWere[l] then
				lightsWere[l] = l.Color
			end
			l.Color = hue(i, b, mega)
		end
		-- Something on every beat.
		local cannons = r.cannons
		if #cannons > 0 then
			emit(cannons[b % #cannons + 1], if mega then 34 else 22)
		end
		local sp = r.sparkPart
		if sp and #f.tiles > 0 then
			local t = f.tiles[(b * 17) % #f.tiles + 1]
			sp.CFrame = CFrame.new(t.part.CFrame.Position + Vector3.new(0, t.part.Size.Y / 2 + 0.2, 0))
			emit(r.sparks, 14)
		end
		if b % 16 == 0 then
			emit(r.shower, if mega then 110 else 70)
		end
		-- The roof: every so often the coffers come down and fly round the room, the ceiling lifts
		-- away, and it all drops back into place.
		if b % (if mega then 32 else 64) == 8 and os.clock() > roofFrom + roofSeconds then
			roofFrom = os.clock()
			roofSeconds = period * 16
			sound("riseWhoosh", 0.5)
		end
		for k, item in r.beams do
			item.beam.Color = ColorSequence.new(hue(k, b, mega))
		end
	end
	-- Round you, wherever you are: a burst of confetti every few beats.
	if r and b % 4 == 0 and not AbuseParty.isBusy() then
		emit(r.near, if mega then 26 else 16)
	end
	if b % 32 == 0 then
		sound("partyHorn", 0.35)
	end
end

local function step()
	local r = rig
	if not r then
		return
	end
	local count, period = AbuseParty.beatNow()
	local b = math.floor(count)
	local frac = count - b
	if b ~= lastBeat then
		lastBeat = b
		beat(b, period)
	end
	local mega = isMega()
	local t = os.clock()
	local f = foyer
	-- The light: a kick on every other beat, fading through it.
	local pulse = r.pulse
	if pulse then
		local kick = if b % 2 == 0 then (1 - frac) ^ 3 else 0
		pulse.Brightness = 0.07 * kick
		pulse.Saturation = 0.12 + 0.1 * kick
		pulse.TintColor = Color3.new(1, 1, 1):Lerp(hue(b, b, mega), 0.08 * kick)
	end
	-- The Gold Tile, blinking gold, its marker over it (seen from anywhere in the house).
	local tileAt = Workspace:GetAttribute("PartyTile")
	if typeof(tileAt) == "Vector3" then
		local untilAt = Workspace:GetAttribute("PartyTileUntil")
		marker(r, tileAt, if type(untilAt) == "number" then untilAt - Workspace:GetServerTimeNow() else 0)
		local gold = goldTile
		if gold then
			light(gold.part, GOLD:Lerp(Color3.new(1, 1, 1), if frac < 0.5 then 0.35 else 0))
		end
	end
	if f then
		-- The balusters bobbing.
		if Quality.rich() then
			for i, p in f.balusters do
				keep(p)
				p.CFrame = saved[p].cf + Vector3.new(0, 0.28 * math.sin((count * 0.5 + i * 0.15) * math.pi * 2), 0)
			end
		end
		-- The roof's flight.
		local u = (t - roofFrom) / math.max(0.01, roofSeconds)
		if u >= 0 and u <= 1 then
			local ease = u * u * (3 - 2 * u)
			local lift = math.sin(u * math.pi)
			local centre = f.centre
			for i, p in f.coffers do
				keep(p)
				local s = saved[p]
				local rel = s.cf.Position - Vector3.new(centre.X, 0, centre.Z)
				local a = ease * math.pi * 2
				local turned = Vector3.new(rel.X * math.cos(a) - rel.Z * math.sin(a), rel.Y, rel.X * math.sin(a) + rel.Z * math.cos(a))
				local drop = lift * (7 + (i % 5))
				p.CFrame = CFrame.new(Vector3.new(centre.X, 0, centre.Z) + turned - Vector3.new(0, drop, 0)) * (s.cf - s.cf.Position) * CFrame.Angles(lift * math.sin(i) * 1.2, a, lift * math.cos(i) * 1.2)
			end
			for _, p in f.ceilings do
				keep(p)
				local s = saved[p]
				p.CFrame = s.cf + Vector3.new(0, lift * 46, 0)
			end
		elseif u > 1 and u < 1.5 then
			-- (Back in place, exactly.)
			for _, p in f.coffers do
				local s = saved[p]
				if s then
					p.CFrame = s.cf
				end
			end
			for _, p in f.ceilings do
				local s = saved[p]
				if s then
					p.CFrame = s.cf
				end
			end
			if u < 1.05 then
				AbuseParty.shake(0.25, 0.3)
			end
		end
		-- The mirror ball turning, its beams sweeping the floor.
		local ball = r.ball
		if ball then
			ball.CFrame = CFrame.new(ball.CFrame.Position) * CFrame.Angles(0, t * 1.4, 0)
			local n = #r.beams
			for k, item in r.beams do
				local a = t * 0.8 + k * (math.pi * 2 / n)
				local radius = 14 + 6 * math.sin(t * 0.6 + k)
				local holder = item.end_.Parent
				if holder and holder:IsA("BasePart") then
					holder.CFrame = CFrame.new(f.centre + Vector3.new(math.cos(a) * radius, 0.3, math.sin(a) * radius))
				end
			end
		end
	end
	-- The dancers.
	local busy = AbuseParty.isBusy()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local feet = if root and root:IsA("BasePart") then root.CFrame.Position - Vector3.new(0, 2.6, 0) else nil
	local crewN, congaN = 0, 0
	for _, d in r.dancers do
		if d.crew then
			crewN += 1
		else
			congaN += 1
		end
	end
	for _, d in r.dancers do
		local base: Vector3? = nil
		if d.crew then
			if feet and not busy then
				local a = d.k * (math.pi * 2 / math.max(1, crewN)) + t * 0.45
				base = feet + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8)
			end
		elseif f then
			local a = d.k * (math.pi * 2 / math.max(1, congaN)) - t * 0.32
			base = Vector3.new(f.centre.X + math.cos(a) * 17, f.floorY, f.centre.Z + math.sin(a) * 17)
		end
		if base then
			local hop = 0
			local spin = 0
			if d.move == 1 then
				hop = 1.5 * math.sin(frac * math.pi)
			elseif d.move == 2 then
				hop = 0.5 * math.sin(frac * math.pi)
				spin = ((b % 2) + frac) * 180
			elseif d.move == 3 then
				hop = 0.8 * math.sin(frac * math.pi)
				spin = 20 * math.sin((b + frac) * math.pi)
			else
				hop = 1.1 * math.abs(math.sin((b + frac) * math.pi))
				spin = if b % 2 == 0 then -12 else 12
			end
			d.part.CFrame = CFrame.new(base + Vector3.new(0, 2.3 + hop, 0))
			d.medal.Rotation = spin
			local squash = 1 + 0.12 * math.cos(frac * math.pi * 2)
			d.medal.Size = UDim2.fromScale(0.86 * (2 - squash), 0.86 * squash)
			d.disc.CFrame = CFrame.new(base + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			d.disc.Color = hue(d.k, b, mega)
		else
			d.part.CFrame = CFrame.new(0, -200, 0)
			d.disc.CFrame = CFrame.new(0, -200, 0)
		end
	end
	local np = r.nearPart
	if np then
		np.CFrame = if feet then CFrame.new(feet + Vector3.new(0, 0.5, 0)) else CFrame.new(0, -200, 0)
	end
	-- The piñata: swinging, harder when it's hit.
	local pinata = Workspace:FindFirstChild("PartyPinata")
	local body = pinata and pinata:FindFirstChild("Body")
	if pinata and body and body:IsA("BasePart") then
		local hits = tonumber(pinata:GetAttribute("Hits")) or 0
		local needed = tonumber(pinata:GetAttribute("Needed")) or 1
		if hits > pinataHits then
			pinataSwing = math.min(1, pinataSwing + 0.35)
			emit(r.sparks, 10)
			sound("subHit", 0.35, 0.9 + math.random() * 0.3)
		end
		pinataHits = hits
		pinataSwing = math.max(0.12, pinataSwing * 0.97)
		pinataBar(r, body, hits, needed)
		-- (It swings from the top of its cord, where it was hung: kept from before it moved.)
		keep(body)
		local cordTop = saved[body].cf.Position + Vector3.new(0, 30, 0)
		local swing = CFrame.new(cordTop) * CFrame.Angles(math.sin(t * 2.4) * 0.36 * pinataSwing, t * 0.6, math.cos(t * 2.1) * 0.3 * pinataSwing) * CFrame.new(-cordTop)
		for _, p in pinata:GetChildren() do
			if p:IsA("BasePart") then
				keep(p)
				p.CFrame = swing * saved[p].cf
			end
		end
	else
		pinataHits = 0
		pinataSwing = 0
		if r.pinataGui then
			r.pinataGui:Destroy()
			r.pinataGui = nil
		end
	end
end

---------------------------------------------------------------------------------------------------
-- On and off
---------------------------------------------------------------------------------------------------
local running = false
local conn: RBXScriptConnection? = nil

local function stop()
	if not running then
		return
	end
	running = false
	if conn then
		conn:Disconnect()
		conn = nil
	end
	goldTile = nil
	roofFrom = -math.huge
	restoreAll()
	clearRig()
	AbuseParty.tableStop()
end

local function begin()
	if running then
		return
	end
	running = true
	scan()
	rig = buildRig()
	lastBeat = -math.huge
	conn = RunService.Heartbeat:Connect(function()
		local ok, err = pcall(function()
			step()
		end)
		if not ok then
			warn("[Maison] Admin Abuse's party: " .. tostring(err))
		end
	end)
end

-- Whether the party is on this screen now (for tests and the sorting screen).
function AbuseParty.isOn(): boolean
	return running
end

-- The Gold Tile lit now (World/AbuseParty draws it from Workspace's PartyTile).
local function readTile()
	local at = Workspace:GetAttribute("PartyTile")
	local was = goldTile
	goldTile = if typeof(at) == "Vector3" and running then tileNear(at) else nil
	if was and was ~= goldTile then
		unlight(was.part)
	end
	local r = rig
	if r and typeof(at) ~= "Vector3" then
		dropMarker(r)
	end
end

local function check()
	if abusing() then
		begin()
		if os.clock() - scannedAt > 6 and (not foyer or #(foyer :: Foyer).tiles == 0) then
			-- (The Foyer may not have streamed in yet: look again, and build the room's part of
			-- the party once it's there.)
			scan()
			if foyer and rig and #(rig :: Rig).cannons == 0 then
				clearRig()
				rig = buildRig()
			end
		end
		readTile()
	else
		stop()
	end
end

function AbuseParty.start()
	for _, name in { "AbuseUntil", "AbuseMega", "PartyTile" } do
		Workspace:GetAttributeChangedSignal(name):Connect(check)
	end
	Remotes.event("Salute").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "partyTile" and m.stage == "start" then
			sound("slideWhistle", 0.5)
			check()
		elseif m.op == "partyTile" and m.stage == "end" then
			check()
		elseif m.op == "pinata" and m.stage == "hung" then
			sound("kazoo", 0.45)
		elseif m.op == "pinata" and m.stage == "burst" and typeof(m.at) == "Vector3" then
			local r = rig
			if r and r.burstPart then
				r.burstPart.CFrame = CFrame.new(m.at)
				emit(r.burst, 160)
			end
			sound("partyHorn", 0.7)
			sound("coinDrop", 0.6)
			AbuseParty.shake(0.5, 0.5)
		elseif m.op == "partyPaid" and type(m.gilt) == "number" then
			if m.what == "tile" then
				AbuseParty.toast("The Gold Tile", string.format("+%d Gilt. You were on it in time.", m.gilt))
			elseif m.what == "pinata" then
				AbuseParty.toast("The Piñata", if m.final then string.format("+%d Gilt. You broke it open.", m.gilt) else string.format("+%d Gilt for helping break it.", m.gilt))
			end
			sound("coinDrop", 0.6)
		end
	end)
	check()
	-- (Admin Abuse ends at a time, not with a change: look now and then.)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(check)
		end
	end)
end

return AbuseParty
