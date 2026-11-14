--!strict
-- The brainrots as figures (Build 82): each one built of parts, in the round, with a face and a
-- character of its own, for wherever one stands in the world (beside its guest: World/
-- BrainrotWalkers). Every one is the house's own design: a body shaped like what it is (a
-- croissant curls, a baguette stands tall, a cheese is a wedge with holes, a frog sits low and wide),
-- big cartoon eyes with a glint in them, a mouth and brows for its mood, little arms and legs where
-- it has none of its own, and what it wears or carries from its accent (a top hat, a crown, a
-- microphone, a tutu, a jetpack, pearls...).
--
-- BrainrotFigure.build(id, height) returns a Model standing on its feet at the origin, facing -Z
-- (Roblox's forward), `height` studs tall, with its root (the part at its feet, "Root", anchored)
-- as PrimaryPart and every other part welded to it: move the root and the figure goes with it.
-- Nothing in it collides, is hit by a ray or touched.

local BrainrotFigure = {}

local rgb = Color3.fromRGB
local WHITE = rgb(250, 250, 250)
local INK = rgb(20, 16, 20)
local SHOE = rgb(30, 24, 26)
local GLOVE = rgb(248, 246, 240)
local GOLD = rgb(242, 190, 70)

export type Spec = {
	body: string, -- the shape it's built as
	colour: Color3?, -- its main colour (default: the curio's own)
	second: Color3?, -- a second colour (spots, a shell, a mane...)
	mood: string?, -- "happy", "angry", "smug", "sleepy", "proud", "shy"
	wear: { string }?, -- what it wears or carries
	feature: { [string]: any }?, -- the shape's own options
}

-- Each brainrot: what it's built as, its mood, and what it wears.
BrainrotFigure.Specs = {
	croissantino = { body = "crescent", mood = "angry", wear = {} },
	baguettone = { body = "loaf", mood = "proud", wear = { "flex" } },
	pigeonetto = { body = "critter", colour = rgb(140, 150, 170), second = rgb(110, 170, 150), mood = "smug", wear = { "tophat" }, feature = { beak = true, wings = true } },
	fromaggio = { body = "wedge", colour = rgb(246, 206, 80), mood = "sleepy", wear = { "ghost" }, feature = { holes = true } },
	teacupo = { body = "cup", colour = rgb(200, 226, 236), second = rgb(120, 70, 40), mood = "happy", wear = { "swirl" } },
	moustachio = { body = "head", colour = rgb(236, 196, 160), second = rgb(70, 46, 34), mood = "proud", wear = { "tophat", "moustache", "monocle" } },
	gelato = { body = "scoops", colour = rgb(250, 190, 210), mood = "happy", wear = { "mic" } },
	chatCouture = { body = "critter", colour = rgb(60, 50, 70), second = rgb(230, 120, 170), mood = "smug", wear = { "dress", "pearls" }, feature = { ears = "cat", tail = "thin", whiskers = true } },
	macaronMaestro = { body = "macaron", colour = rgb(240, 150, 180), mood = "happy", wear = { "baton", "bowtie" } },
	snailExpress = { body = "critter", colour = rgb(170, 200, 120), second = rgb(150, 110, 70), mood = "happy", wear = { "jetpack", "goggles" }, feature = { shell = true, low = true, stalks = true } },
	lobsterLuxe = { body = "critter", colour = rgb(220, 70, 60), mood = "smug", wear = { "pearls" }, feature = { claws = true, stalks = true } },
	pianoPanda = { body = "critter", colour = rgb(240, 240, 240), second = rgb(28, 28, 32), mood = "sleepy", wear = { "keys", "bowtie" }, feature = { ears = "round", patches = true } },
	goldenGoose = { body = "critter", colour = rgb(244, 196, 70), mood = "proud", wear = { "sparkles" }, feature = { beak = true, neck = 0.35, wings = true } },
	frogKing = { body = "critter", colour = rgb(90, 170, 80), second = rgb(220, 240, 180), mood = "proud", wear = { "crown", "cape" }, feature = { low = true, bigEyes = true } },
	moonCheese = { body = "moon", colour = rgb(250, 230, 150), mood = "sleepy", wear = { "nightcap" } },
	bananino = { body = "banana", colour = rgb(250, 220, 90), mood = "happy", wear = { "tutu" } },
	spaghettone = { body = "plate", colour = rgb(240, 200, 120), second = rgb(200, 60, 40), mood = "happy", wear = { "mask" } },
	espressivo = { body = "cup", colour = rgb(250, 248, 244), second = rgb(70, 40, 24), mood = "angry", wear = { "bolt" }, feature = { small = true } },
	giraffa = { body = "critter", colour = rgb(240, 196, 110), second = rgb(170, 110, 50), mood = "happy", wear = { "cone" }, feature = { neck = 0.75, spots = true, ears = "nub" } },
	tartaruga = { body = "critter", colour = rgb(110, 180, 110), second = rgb(70, 110, 60), mood = "proud", wear = { "goggles", "scarf" }, feature = { shell = true, low = true } },
	pizzaVolante = { body = "wedge", colour = rgb(246, 196, 90), second = rgb(200, 60, 40), mood = "happy", wear = { "wings" }, feature = { pizza = true } },
	polpoPostino = { body = "critter", colour = rgb(230, 110, 150), mood = "happy", wear = { "postcap", "letters" }, feature = { tentacles = true } },
	coccodrillo = { body = "critter", colour = rgb(70, 140, 80), second = rgb(230, 230, 210), mood = "smug", wear = { "bowtie", "tray" }, feature = { snout = "long", teeth = true } },
	fenicottero = { body = "critter", colour = rgb(250, 130, 170), mood = "smug", wear = { "briefcase", "tie" }, feature = { beak = true, neck = 0.6, legs = "long" } },
	gattinoGalattico = { body = "critter", colour = rgb(90, 80, 170), second = rgb(200, 220, 255), mood = "sleepy", wear = { "helmet" }, feature = { ears = "cat", tail = "thin" } },
	unicornetto = { body = "critter", colour = rgb(244, 230, 252), second = rgb(220, 150, 250), mood = "happy", wear = { "swirl", "sparkles" }, feature = { horn = true, mane = true, ears = "nub" } },
	dragoDorato = { body = "critter", colour = rgb(230, 170, 40), second = rgb(180, 60, 40), mood = "smug", wear = { "coins" }, feature = { wings = true, horns = true, snout = "short", tail = "spike" } },
	reginaBallo = { body = "queen", colour = rgb(120, 40, 90), second = rgb(240, 214, 190), mood = "proud", wear = { "crown", "pearls" } },
	ladroLussuoso = { body = "critter", colour = rgb(90, 90, 96), second = rgb(30, 30, 34), mood = "smug", wear = { "tophat", "bowtie", "bag" }, feature = { ears = "round", mask = true, tail = "ringed" } },
	gattoGioielliere = { body = "critter", colour = rgb(228, 196, 120), second = rgb(140, 210, 255), mood = "smug", wear = { "monocle", "gem" }, feature = { ears = "cat", tail = "thin", whiskers = true } },
	topoTesoriere = { body = "critter", colour = rgb(130, 110, 100), second = rgb(60, 140, 80), mood = "proud", wear = { "visor", "coins" }, feature = { ears = "round", snout = "short" } },
	dirigenteSupremo = { body = "case", colour = rgb(60, 40, 30), second = rgb(40, 44, 60), mood = "proud", wear = { "tie" } },
	pavoneDoro = { body = "critter", colour = rgb(214, 170, 60), second = rgb(60, 160, 140), mood = "proud", wear = { "sparkles" }, feature = { beak = true, neck = 0.3, fan = true } },
	banchiereBianco = { body = "head", colour = rgb(236, 200, 170), second = rgb(240, 240, 244), mood = "smug", wear = { "tophat", "monocle", "cash" } },
	uovoMezzanotte = { body = "egg", colour = rgb(40, 40, 90), second = GOLD, mood = "sleepy", wear = { "moon", "jewels" } },
	tazzaImperiale = { body = "cup", colour = rgb(200, 220, 230), second = rgb(110, 150, 90), mood = "proud", wear = { "crown" } },
	orologioRe = { body = "watch", colour = rgb(200, 160, 70), mood = "proud", wear = { "crown" } },
	lupoBorsa = { body = "critter", colour = rgb(90, 90, 100), second = rgb(220, 220, 226), mood = "smug", wear = { "waistcoat", "tie" }, feature = { ears = "pointed", snout = "long" } },
	cignoInverno = { body = "critter", colour = rgb(220, 240, 255), second = rgb(150, 210, 255), mood = "shy", wear = { "snow" }, feature = { beak = true, neck = 0.6, wings = true } },
	coniglioPrimavera = { body = "critter", colour = rgb(244, 220, 230), second = rgb(220, 180, 90), mood = "happy", wear = { "waistcoat", "flower" }, feature = { ears = "long" } },
	zuccaArgento = { body = "pumpkin", colour = rgb(200, 200, 212), mood = "smug", wear = { "candle" } },
	midnightOwl = { body = "critter", colour = rgb(50, 50, 80), second = rgb(220, 200, 120), mood = "sleepy", wear = { "moon" }, feature = { beak = true, bigEyes = true, tufts = true, wings = true } },
} :: { [string]: Spec }

---------------------------------------------------------------------------------------------------
-- The pieces
---------------------------------------------------------------------------------------------------
type Ctx = { model: Model, root: BasePart, s: number, flex: boolean }

local function weld(c: Ctx, p: BasePart)
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = c.root
	w.Part1 = p
	w.Parent = p
	p.Parent = c.model
end

-- A part of the figure: `size` and `at` in the figure's units (its height is 1).
local function piece(c: Ctx, name: string, shape: string, size: Vector3, at: CFrame, colour: Color3, material: Enum.Material?): BasePart
	local s = c.s
	local p: BasePart
	if shape == "wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if shape == "cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif shape == "ball" then
			part.Shape = Enum.PartType.Ball
		end
		p = part
	end
	p.Name = name
	p.Size = Vector3.new(math.max(0.05, size.X * s), math.max(0.05, size.Y * s), math.max(0.05, size.Z * s))
	p.CFrame = c.root.CFrame * CFrame.new(at.Position * s) * at.Rotation
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "egg" then
		-- (An ellipsoid: a block worn as a sphere of its own size.)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	weld(c, p)
	return p
end

local function V(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end
-- A cylinder standing up (Roblox's cylinders lie along X).
local function upright(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
end

local function shade(c: Color3, by: number): Color3
	return c:Lerp(rgb(0, 0, 0), by)
end
local function light(c: Color3, by: number): Color3
	return c:Lerp(rgb(255, 255, 255), by)
end

-- The face: two big eyes with a glint, brows for its mood, a mouth. `centre`: the middle of the
-- face, on its front surface; `r`: how big the face is.
local function face(c: Ctx, centre: Vector3, r: number, mood: string, big: boolean?, beak: boolean?)
	local eye = r * (if big then 0.62 else 0.48)
	local gap = r * 0.42
	for _, side in { -1, 1 } do
		local e = centre + V(side * gap, r * 0.12, 0)
		piece(c, "Eye", "egg", V(eye * 0.86, eye, eye * 0.5), at(e.X, e.Y, e.Z), WHITE)
		local look = if mood == "smug" then V(side * 0.04 * r, -0.05 * r, 0) else V(0, 0, 0)
		local pupil = e + look + V(0, mood == "sleepy" and -0.08 * r or 0, -eye * 0.22)
		piece(c, "Pupil", "egg", V(eye * 0.46, eye * (if mood == "sleepy" then 0.28 else 0.52), eye * 0.2), at(pupil.X, pupil.Y, pupil.Z), INK)
		piece(c, "Glint", "ball", V(eye * 0.16, eye * 0.16, eye * 0.16), at(pupil.X + eye * 0.1, pupil.Y + eye * 0.12, pupil.Z - eye * 0.1), WHITE, Enum.Material.Neon)
		-- Brows: down at the middle when angry, up when proud or shy, half-shut lids when sleepy.
		local brow = e + V(0, eye * 0.62, -eye * 0.15)
		local tilt = if mood == "angry" then -side * 24 elseif mood == "proud" or mood == "shy" then side * 12 elseif mood == "smug" then side * 6 else 0
		piece(c, "Brow", "block", V(eye * 0.8, eye * 0.13, eye * 0.12), at(brow.X, brow.Y, brow.Z) * CFrame.Angles(0, 0, math.rad(tilt)), INK)
		if mood == "sleepy" then
			piece(c, "Lid", "egg", V(eye * 0.92, eye * 0.5, eye * 0.56), at(e.X, e.Y + eye * 0.26, e.Z - 0.005), shade(WHITE, 0.25))
		end
	end
	-- The mouth: a grin, a grimace, a smirk, an o. (A bird's beak is its mouth.)
	local m = centre + V(0, -r * 0.34, -0.01)
	if beak then
		local _ = m
	elseif mood == "angry" then
		piece(c, "Mouth", "block", V(r * 0.42, r * 0.07, r * 0.06), at(m.X, m.Y, m.Z) * CFrame.Angles(0, 0, math.rad(-4)), INK)
	elseif mood == "smug" then
		piece(c, "Mouth", "block", V(r * 0.34, r * 0.06, r * 0.06), at(m.X + r * 0.08, m.Y + r * 0.03, m.Z) * CFrame.Angles(0, 0, math.rad(14)), INK)
	elseif mood == "sleepy" or mood == "shy" then
		piece(c, "Mouth", "egg", V(r * 0.16, r * 0.12, r * 0.06), at(m.X, m.Y, m.Z), INK)
	else
		piece(c, "Mouth", "egg", V(r * 0.46, r * 0.24, r * 0.08), at(m.X, m.Y, m.Z), INK)
		piece(c, "Tongue", "egg", V(r * 0.24, r * 0.1, r * 0.08), at(m.X, m.Y - r * 0.06, m.Z - 0.004), rgb(230, 90, 110))
	end
	-- Cheeks, a little blush.
	if mood == "happy" or mood == "shy" then
		for _, side in { -1, 1 } do
			piece(c, "Blush", "egg", V(r * 0.2, r * 0.1, r * 0.04), at(centre.X + side * r * 0.62, centre.Y - r * 0.2, centre.Z + 0.005), rgb(255, 140, 150), Enum.Material.Neon).Transparency = 0.5
		end
	end
end

-- Little legs with shoes, and arms with white gloves, for a figure with none of its own.
-- `hip`: where the legs join (their height); `shoulder`: the arms' height; `wide`: how far apart.
local function limbs(c: Ctx, hip: number, shoulder: number, wide: number)
	local flex = c.flex
	for _, side in { -1, 1 } do
		local x = side * wide * 0.45
		piece(c, "Leg", "cylinder", V(hip, 0.05, 0.05), upright(x, hip / 2, 0), INK)
		piece(c, "Shoe", "egg", V(0.12, 0.07, 0.17), at(x, 0.035, -0.03), SHOE)
		local ax = side * (wide * 0.5 + 0.06)
		local arm = if flex then CFrame.Angles(0, 0, math.rad(side * 70)) else CFrame.Angles(0, 0, math.rad(side * 25))
		piece(c, "Arm", "cylinder", V(0.2, 0.04, 0.04), at(ax, shoulder, 0) * arm, INK)
		local hand = if flex then V(ax + side * 0.02, shoulder + 0.12, 0) else V(ax + side * 0.08, shoulder - 0.07, 0)
		piece(c, "Glove", "ball", V(0.08, 0.08, 0.08), at(hand.X, hand.Y, hand.Z), GLOVE)
		if flex then
			piece(c, "Muscle", "egg", V(0.09, 0.07, 0.07), at(ax + side * 0.01, shoulder + 0.05, 0), light(INK, 0.15))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The bodies (each returns its face's middle on its front, the face's size, and the top of it)
---------------------------------------------------------------------------------------------------
type Shape = (c: Ctx, sp: Spec, col: Color3, two: Color3) -> (Vector3, number, number)

local BODIES: { [string]: Shape } = {}

BODIES.crescent = function(c, _sp, col, _two)
	-- A croissant: five segments round a curl, fattest in the middle, darker at the folds.
	for i = -2, 2 do
		local a = math.rad(i * 26)
		local fat = 0.36 - math.abs(i) * 0.07
		local p = V(math.sin(a) * 0.32, 0.42 + math.cos(a) * 0.06 - math.abs(i) * 0.03, math.cos(a) * 0.02)
		piece(c, "Crust", "egg", V(fat * 0.95, fat, fat), at(p.X, p.Y, p.Z) * CFrame.Angles(0, 0, -a), if i % 2 == 0 then col else shade(col, 0.15))
	end
	limbs(c, 0.24, 0.42, 0.5)
	return V(0, 0.46, -0.17), 0.26, 0.62
end

BODIES.loaf = function(c, _sp, col, _two)
	-- A baguette, standing tall, with its scores.
	piece(c, "Loaf", "cylinder", V(0.62, 0.26, 0.26), upright(0, 0.55, 0), col)
	piece(c, "Top", "ball", V(0.26, 0.26, 0.26), at(0, 0.86, 0), col)
	piece(c, "End", "ball", V(0.26, 0.26, 0.26), at(0, 0.24, 0), shade(col, 0.05))
	for i = 0, 2 do
		piece(c, "Score", "block", V(0.16, 0.03, 0.03), at(0, 0.38 + i * 0.13, -0.125) * CFrame.Angles(0, 0, math.rad(30)), light(col, 0.3))
	end
	limbs(c, 0.2, 0.5, 0.3)
	return V(0, 0.74, -0.13), 0.13, 0.98
end

BODIES.wedge = function(c, sp, col, two)
	-- A wedge of cheese with its holes, or a slice of pizza with its toppings.
	local pizza = sp.feature and sp.feature.pizza
	piece(c, "Wedge", "wedge", V(0.56, 0.5, 0.5), at(0, 0.45, 0) * CFrame.Angles(0, math.rad(180), 0), col)
	if pizza then
		piece(c, "Crust", "cylinder", V(0.58, 0.09, 0.09), at(0, 0.72, 0.24), shade(col, 0.25))
		for _, p in { V(-0.12, 0.42, -0.02), V(0.12, 0.55, 0.06), V(0.02, 0.3, -0.14) } do
			piece(c, "Pepperoni", "cylinder", V(0.02, 0.11, 0.11), at(p.X, p.Y, p.Z - 0.02) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(45), 0, 0), two)
		end
	elseif sp.feature and sp.feature.holes then
		for _, p in { V(-0.16, 0.36, -0.08), V(0.17, 0.5, 0.04), V(0.0, 0.62, 0.12), V(-0.2, 0.58, 0.1) } do
			piece(c, "Hole", "ball", V(0.09, 0.09, 0.09), at(p.X, p.Y, p.Z - 0.04), shade(col, 0.3))
		end
	end
	limbs(c, 0.2, 0.36, 0.5)
	return V(0, 0.42, -0.2), 0.2, 0.7
end

BODIES.banana = function(c, _sp, col, _two)
	for i = 0, 3 do
		local a = math.rad(-20 + i * 14)
		piece(c, "Peel", "egg", V(0.24, 0.28, 0.22), at(math.sin(a) * 0.18, 0.28 + i * 0.17, 0) * CFrame.Angles(0, 0, -a), if i == 3 then shade(col, 0.1) else col)
	end
	piece(c, "Tip", "ball", V(0.07, 0.07, 0.07), at(0.12, 0.85, 0), rgb(90, 60, 30))
	limbs(c, 0.2, 0.45, 0.32)
	return V(0, 0.55, -0.11), 0.13, 0.88
end

BODIES.plate = function(c, _sp, col, two)
	piece(c, "Plate", "cylinder", V(0.06, 0.74, 0.74), upright(0, 0.22, 0), WHITE)
	piece(c, "Noodles", "egg", V(0.6, 0.42, 0.56), at(0, 0.44, 0), col)
	for i = 1, 6 do
		local a = i * 1.05
		piece(c, "Strand", "cylinder", V(0.42, 0.04, 0.04), at(math.cos(a) * 0.12, 0.48 + (i % 3) * 0.06, math.sin(a) * 0.12) * CFrame.Angles(0, a, math.rad(20)), light(col, 0.15))
	end
	piece(c, "Meatball", "ball", V(0.17, 0.17, 0.17), at(0.1, 0.68, 0.04), two)
	limbs(c, 0.2, 0.4, 0.6)
	return V(0, 0.46, -0.26), 0.18, 0.76
end

BODIES.scoops = function(c, _sp, col, _two)
	-- A cone of three scoops: strawberry, vanilla, its own colour on top.
	for i = 0, 3 do
		local w = 0.3 - i * 0.065
		piece(c, "Cone", "cylinder", V(0.09, w, w), upright(0, 0.3 - i * 0.07, 0), rgb(210, 150, 80))
	end
	piece(c, "Scoop", "ball", V(0.32, 0.32, 0.32), at(0, 0.44, 0), rgb(250, 240, 220))
	piece(c, "Scoop", "ball", V(0.3, 0.3, 0.3), at(0, 0.66, 0), rgb(240, 120, 150))
	piece(c, "Scoop", "ball", V(0.28, 0.28, 0.28), at(0, 0.86, 0), col)
	piece(c, "Cherry", "ball", V(0.08, 0.08, 0.08), at(0, 1.0, 0), rgb(220, 30, 40))
	limbs(c, 0.16, 0.44, 0.32)
	return V(0, 0.68, -0.14), 0.14, 1
end

BODIES.macaron = function(c, _sp, col, _two)
	piece(c, "Shell", "egg", V(0.66, 0.24, 0.6), at(0, 0.36, 0), col)
	piece(c, "Cream", "cylinder", V(0.09, 0.6, 0.6), upright(0, 0.52, 0), WHITE)
	piece(c, "Shell", "egg", V(0.66, 0.24, 0.6), at(0, 0.68, 0), col)
	limbs(c, 0.24, 0.5, 0.62)
	return V(0, 0.52, -0.3), 0.2, 0.8
end

BODIES.cup = function(c, sp, col, two)
	local small = sp.feature and sp.feature.small
	local k = if small then 0.8 else 1
	piece(c, "Saucer", "cylinder", V(0.05, 0.72 * k, 0.72 * k), upright(0, 0.22, 0), light(col, 0.3))
	piece(c, "Cup", "cylinder", V(0.42 * k, 0.5 * k, 0.5 * k), upright(0, 0.25 + 0.21 * k, 0), col)
	piece(c, "Brew", "cylinder", V(0.02, 0.44 * k, 0.44 * k), upright(0, 0.25 + 0.42 * k, 0), two)
	piece(c, "Handle", "cylinder", V(0.06, 0.2 * k, 0.2 * k), at(0.29 * k, 0.25 + 0.22 * k, 0) * CFrame.Angles(0, math.rad(90), 0), col)
	piece(c, "Rim", "cylinder", V(0.03, 0.52 * k, 0.52 * k), upright(0, 0.25 + 0.42 * k, 0), GOLD, Enum.Material.Metal)
	limbs(c, 0.2, 0.25 + 0.2 * k, 0.5 * k)
	return V(0, 0.25 + 0.2 * k, -0.25 * k), 0.17 * k, 0.25 + 0.44 * k
end

BODIES.head = function(c, _sp, col, two)
	-- A gentleman who is mostly head: a round face over a suit.
	piece(c, "Suit", "egg", V(0.4, 0.36, 0.32), at(0, 0.3, 0), two)
	piece(c, "Shirt", "egg", V(0.16, 0.26, 0.04), at(0, 0.32, -0.15), WHITE)
	piece(c, "Head", "ball", V(0.5, 0.5, 0.5), at(0, 0.66, 0), col)
	limbs(c, 0.14, 0.36, 0.36)
	return V(0, 0.66, -0.24), 0.2, 0.92
end

BODIES.egg = function(c, _sp, col, two)
	piece(c, "Egg", "egg", V(0.56, 0.78, 0.56), at(0, 0.5, 0), col)
	for i = 0, 2 do
		piece(c, "Band", "cylinder", V(0.03, 0.5 - math.abs(i - 1) * 0.08, 0.5 - math.abs(i - 1) * 0.08), upright(0, 0.34 + i * 0.16, 0), two, Enum.Material.Metal)
	end
	limbs(c, 0.18, 0.46, 0.5)
	return V(0, 0.56, -0.27), 0.19, 0.9
end

BODIES.case = function(c, _sp, col, two)
	piece(c, "Case", "block", V(0.62, 0.46, 0.22), at(0, 0.48, 0), col, Enum.Material.Leather)
	for i = -2, 2 do
		piece(c, "Pinstripe", "block", V(0.008, 0.44, 0.01), at(i * 0.1, 0.48, -0.112), light(two, 0.4))
	end
	piece(c, "Handle", "block", V(0.22, 0.05, 0.05), at(0, 0.76, 0), shade(col, 0.3))
	piece(c, "Clasp", "block", V(0.08, 0.05, 0.02), at(-0.18, 0.66, -0.115), GOLD, Enum.Material.Metal)
	piece(c, "Clasp", "block", V(0.08, 0.05, 0.02), at(0.18, 0.66, -0.115), GOLD, Enum.Material.Metal)
	limbs(c, 0.25, 0.48, 0.62)
	return V(0, 0.48, -0.115), 0.17, 0.78
end

BODIES.watch = function(c, _sp, col, _two)
	piece(c, "Strap", "block", V(0.2, 0.86, 0.06), at(0, 0.48, 0.05), rgb(70, 40, 30), Enum.Material.Leather)
	piece(c, "Case", "cylinder", V(0.1, 0.56, 0.56), at(0, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0), col, Enum.Material.Metal)
	piece(c, "Dial", "cylinder", V(0.02, 0.48, 0.48), at(0, 0.5, -0.055) * CFrame.Angles(0, math.rad(90), 0), rgb(250, 246, 236))
	piece(c, "Hand", "block", V(0.02, 0.18, 0.01), at(0, 0.56, -0.068), INK)
	piece(c, "Hand", "block", V(0.13, 0.02, 0.01), at(0.06, 0.5, -0.068), INK)
	piece(c, "Crown", "cylinder", V(0.06, 0.08, 0.08), at(0.32, 0.5, 0), col, Enum.Material.Metal)
	limbs(c, 0.2, 0.5, 0.56)
	return V(0, 0.44, -0.07), 0.16, 0.8
end

BODIES.pumpkin = function(c, _sp, col, _two)
	for i = -2, 2 do
		piece(c, "Rib", "egg", V(0.26, 0.5, 0.5 - math.abs(i) * 0.04), at(i * 0.12, 0.42, 0), if i % 2 == 0 then col else shade(col, 0.12), Enum.Material.Metal)
	end
	piece(c, "Stem", "cylinder", V(0.14, 0.06, 0.06), upright(0, 0.72, 0), rgb(80, 110, 60))
	limbs(c, 0.18, 0.42, 0.6)
	return V(0, 0.42, -0.25), 0.2, 0.78
end

BODIES.moon = function(c, _sp, col, _two)
	piece(c, "Moon", "ball", V(0.7, 0.7, 0.7), at(0, 0.5, 0), col)
	for _, p in { V(-0.2, 0.7, -0.24), V(0.22, 0.32, -0.22), V(0.24, 0.66, -0.18), V(-0.24, 0.3, -0.2) } do
		piece(c, "Crater", "cylinder", V(0.03, 0.12, 0.12), at(p.X, p.Y, p.Z) * CFrame.Angles(0, math.rad(90), 0), shade(col, 0.18))
	end
	limbs(c, 0.16, 0.48, 0.6)
	return V(0, 0.5, -0.34), 0.22, 0.86
end

BODIES.queen = function(c, _sp, col, two)
	-- A ball gown in tiers, her face above it.
	for i = 0, 3 do
		local w = 0.74 - i * 0.14
		piece(c, "Gown", "cylinder", V(0.14, w, w), upright(0, 0.07 + i * 0.13, 0), if i % 2 == 0 then col else shade(col, 0.15))
	end
	piece(c, "Bodice", "egg", V(0.26, 0.24, 0.2), at(0, 0.6, 0), col)
	piece(c, "Head", "ball", V(0.3, 0.3, 0.3), at(0, 0.82, 0), two)
	piece(c, "Hair", "egg", V(0.32, 0.22, 0.3), at(0, 0.9, 0.03), rgb(60, 30, 20))
	for _, side in { -1, 1 } do
		piece(c, "Arm", "cylinder", V(0.22, 0.04, 0.04), at(side * 0.18, 0.56, 0) * CFrame.Angles(0, 0, math.rad(side * 40)), two)
	end
	return V(0, 0.8, -0.145), 0.1, 0.98
end

-- An animal: a round body and a head, and whatever it has of its own.
BODIES.critter = function(c, sp, col, two)
	local f: { [string]: any } = sp.feature or {}
	local low = f.low == true
	local neck = tonumber(f.neck) or 0
	local legsLong = f.legs == "long"
	local bodyY = if low then 0.24 elseif legsLong then 0.46 else 0.32
	local bodyR = if low then 0.5 else 0.44
	piece(c, "Body", "egg", V(bodyR, bodyR * 0.82, bodyR * 0.9), at(0, bodyY, 0.03), col)
	piece(c, "Belly", "egg", V(bodyR * 0.62, bodyR * 0.58, 0.06), at(0, bodyY - 0.02, -bodyR * 0.43), if f.patches then WHITE else light(col, 0.35))
	-- Its feet (or legs, for a flamingo; tentacles for an octopus).
	if f.tentacles then
		for i = 0, 7 do
			local a = i * math.pi / 4
			piece(c, "Tentacle", "egg", V(0.08, 0.3, 0.08), at(math.cos(a) * 0.17, 0.1, math.sin(a) * 0.17) * CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6), shade(col, 0.08))
		end
	elseif legsLong then
		for _, side in { -1, 1 } do
			piece(c, "Leg", "cylinder", V(0.4, 0.035, 0.035), upright(side * 0.07, 0.2, 0), shade(col, 0.2))
			piece(c, "Foot", "egg", V(0.1, 0.03, 0.12), at(side * 0.07, 0.015, -0.03), shade(col, 0.2))
		end
	else
		for _, side in { -1, 1 } do
			piece(c, "Foot", "egg", V(0.15, 0.08, 0.2), at(side * bodyR * 0.3, 0.04, -0.06), if f.beak then rgb(240, 150, 50) else shade(col, 0.15))
		end
	end
	if f.shell then
		piece(c, "Shell", "egg", V(bodyR * 1.05, bodyR * 0.9, bodyR * 1.0), at(0, bodyY + 0.12, 0.12), two)
		for i = 0, 2 do
			piece(c, "ShellRing", "cylinder", V(0.02, 0.3 - i * 0.09, 0.3 - i * 0.09), at(0, bodyY + 0.14, 0.12 + bodyR * 0.48 + i * 0.005) * CFrame.Angles(0, math.rad(90), 0), shade(two, 0.25))
		end
	end
	if f.spots then
		for _, p in { V(-0.12, bodyY + 0.06, -0.15), V(0.14, bodyY + 0.1, -0.1), V(0.0, bodyY - 0.08, -0.18) } do
			piece(c, "Spot", "egg", V(0.1, 0.08, 0.03), at(p.X, p.Y, p.Z), two)
		end
	end
	-- The head, on its neck.
	local headR = if f.bigEyes then 0.4 elseif low then 0.36 else 0.32
	local headY = bodyY + bodyR * 0.4 + headR * 0.42 + neck * 0.5
	if neck > 0 then
		piece(c, "Neck", "cylinder", V(neck * 0.6, 0.1, 0.1), upright(0, bodyY + bodyR * 0.3 + neck * 0.25, -0.04), col)
	end
	if low and not f.bigEyes then
		headY = bodyY + 0.12
	end
	local headZ = if low then -bodyR * 0.36 else -0.02
	piece(c, "Head", "egg", V(headR, headR * 0.92, headR * 0.9), at(0, headY, headZ), col)
	if f.patches then
		for _, side in { -1, 1 } do
			piece(c, "Patch", "egg", V(headR * 0.36, headR * 0.42, 0.04), at(side * headR * 0.2, headY + headR * 0.04, headZ - headR * 0.41), two)
		end
	end
	if f.mask then
		piece(c, "Mask", "egg", V(headR * 0.95, headR * 0.3, 0.04), at(0, headY + headR * 0.06, headZ - headR * 0.42), two)
	end
	-- Ears.
	local ears = f.ears
	if ears then
		for _, side in { -1, 1 } do
			local ex = side * headR * 0.32
			local ey = headY + headR * 0.42
			if ears == "cat" or ears == "pointed" then
				piece(c, "Ear", "wedge", V(0.04, 0.14, 0.12), at(ex, ey + 0.04, headZ) * CFrame.Angles(0, math.rad(90), 0), if ears == "cat" then col else shade(col, 0.1))
			elseif ears == "round" then
				piece(c, "Ear", "ball", V(0.12, 0.12, 0.12), at(ex * 1.15, ey, headZ), if f.patches then two else shade(col, 0.1))
			elseif ears == "long" then
				piece(c, "Ear", "egg", V(0.07, 0.34, 0.06), at(ex * 0.7, ey + 0.15, headZ + 0.02) * CFrame.Angles(0, 0, math.rad(-side * 8)), col)
				piece(c, "EarIn", "egg", V(0.04, 0.26, 0.02), at(ex * 0.7, ey + 0.15, headZ - 0.015) * CFrame.Angles(0, 0, math.rad(-side * 8)), rgb(250, 190, 200))
			elseif ears == "nub" then
				piece(c, "Ear", "egg", V(0.06, 0.1, 0.05), at(ex, ey, headZ), col)
			end
		end
	end
	if f.tufts then
		for _, side in { -1, 1 } do
			piece(c, "Tuft", "wedge", V(0.03, 0.12, 0.1), at(side * headR * 0.36, headY + headR * 0.48, headZ) * CFrame.Angles(0, math.rad(90), math.rad(-side * 15)), shade(col, 0.2))
		end
	end
	if f.horn then
		for i = 0, 2 do
			piece(c, "Horn", "cylinder", V(0.06, 0.07 - i * 0.02, 0.07 - i * 0.02), upright(0, headY + headR * 0.5 + i * 0.055, headZ - 0.04), GOLD, Enum.Material.Metal)
		end
	end
	if f.horns then
		for _, side in { -1, 1 } do
			piece(c, "Horn", "wedge", V(0.03, 0.14, 0.07), at(side * headR * 0.28, headY + headR * 0.5, headZ + 0.03), rgb(240, 230, 210))
		end
	end
	if f.mane then
		for i = 0, 3 do
			piece(c, "Mane", "ball", V(0.1, 0.1, 0.1), at(0, headY + headR * 0.36 - i * 0.06, headZ + headR * 0.3 + i * 0.04), if i % 2 == 0 then two else light(two, 0.3))
		end
	end
	if f.stalks then
		for _, side in { -1, 1 } do
			piece(c, "Stalk", "cylinder", V(0.16, 0.03, 0.03), upright(side * headR * 0.22, headY + headR * 0.55, headZ), col)
		end
	end
	-- Its snout or beak.
	local faceZ = headZ - headR * 0.45
	if f.beak then
		piece(c, "Beak", "wedge", V(0.1, 0.06, 0.12), at(0, headY - headR * 0.12, faceZ - 0.04) * CFrame.Angles(0, math.rad(180), 0), rgb(245, 160, 50))
	elseif f.snout == "long" then
		piece(c, "Snout", "egg", V(headR * 0.6, headR * 0.34, headR * 0.9), at(0, headY - headR * 0.18, faceZ - headR * 0.2), shade(col, 0.05))
		piece(c, "Nose", "ball", V(0.05, 0.05, 0.05), at(0, headY - headR * 0.06, faceZ - headR * 0.62), INK)
		if f.teeth then
			for i = -1, 1 do
				piece(c, "Tooth", "wedge", V(0.02, 0.03, 0.02), at(i * 0.05, headY - headR * 0.33, faceZ - headR * 0.3), WHITE)
			end
		end
	elseif f.snout == "short" then
		piece(c, "Snout", "egg", V(headR * 0.4, headR * 0.26, headR * 0.3), at(0, headY - headR * 0.18, faceZ), light(col, 0.2))
		piece(c, "Nose", "ball", V(0.045, 0.045, 0.045), at(0, headY - headR * 0.1, faceZ - headR * 0.14), INK)
	elseif not f.tentacles then
		piece(c, "Nose", "egg", V(0.05, 0.035, 0.03), at(0, headY - headR * 0.1, faceZ - 0.005), shade(col, 0.5))
	end
	if f.whiskers then
		for _, side in { -1, 1 } do
			for k = -1, 1 do
				piece(c, "Whisker", "block", V(0.14, 0.006, 0.006), at(side * headR * 0.38, headY - headR * 0.12 + k * 0.025, faceZ + 0.01) * CFrame.Angles(0, 0, math.rad(k * 10 * side)), WHITE)
			end
		end
	end
	-- Wings, a tail, claws, a fan.
	if f.wings then
		for _, side in { -1, 1 } do
			piece(c, "Wing", "egg", V(0.08, bodyR * 0.62, bodyR * 0.7), at(side * bodyR * 0.48, bodyY + 0.04, 0.05) * CFrame.Angles(0, 0, math.rad(side * 12)), if sp.wear and table.find(sp.wear, "sparkles") then light(col, 0.15) else shade(col, 0.12))
		end
	end
	if f.claws then
		for _, side in { -1, 1 } do
			piece(c, "Arm", "cylinder", V(0.18, 0.05, 0.05), at(side * bodyR * 0.55, bodyY + 0.02, -0.08) * CFrame.Angles(0, 0, math.rad(side * 20)), col)
			piece(c, "Claw", "wedge", V(0.05, 0.12, 0.14), at(side * bodyR * 0.72, bodyY + 0.1, -0.1), col)
			piece(c, "Claw", "wedge", V(0.05, 0.08, 0.1), at(side * bodyR * 0.72, bodyY + 0.02, -0.1) * CFrame.Angles(math.rad(180), 0, 0), shade(col, 0.1))
		end
	end
	local tail = f.tail
	if tail == "thin" or tail == "ringed" then
		for i = 0, 3 do
			piece(c, "Tail", "ball", V(0.07, 0.07, 0.07), at(0.04 * i, bodyY - 0.05 + i * 0.07, bodyR * 0.48 + i * 0.05), if tail == "ringed" and i % 2 == 1 then two else col)
		end
	elseif tail == "spike" then
		piece(c, "Tail", "wedge", V(0.05, 0.12, 0.2), at(0, bodyY - 0.08, bodyR * 0.55), two)
	end
	if f.fan then
		for i = -3, 3 do
			local a = math.rad(i * 18)
			piece(c, "Plume", "egg", V(0.12, 0.62, 0.04), at(math.sin(a) * 0.3, bodyY + 0.32 + math.cos(a) * 0.2, bodyR * 0.55) * CFrame.Angles(0, 0, -a), if i % 2 == 0 then two else col)
			piece(c, "Eye", "ball", V(0.05, 0.05, 0.05), at(math.sin(a) * 0.52, bodyY + 0.32 + math.cos(a) * 0.42, bodyR * 0.53), GOLD, Enum.Material.Neon)
		end
	end
	return V(0, headY, faceZ), headR * 0.62, headY + headR * 0.5
end

---------------------------------------------------------------------------------------------------
-- What it wears (placed from its face's middle `fc`, the face's size `r` and the top of it `top`)
---------------------------------------------------------------------------------------------------
local WEAR: { [string]: (c: Ctx, fc: Vector3, r: number, top: number, col: Color3, two: Color3) -> () } = {}

WEAR.tophat = function(c, fc, r, top)
	piece(c, "HatBrim", "cylinder", V(0.025, r * 1.9, r * 1.9), upright(fc.X, top + 0.01, fc.Z + r * 0.4), INK)
	piece(c, "Hat", "cylinder", V(r * 1.2, r * 1.15, r * 1.15), upright(fc.X, top + r * 0.6, fc.Z + r * 0.4), INK)
	piece(c, "HatBand", "cylinder", V(r * 0.22, r * 1.18, r * 1.18), upright(fc.X, top + r * 0.18, fc.Z + r * 0.4), rgb(160, 30, 40))
end
WEAR.crown = function(c, fc, r, top)
	local z = fc.Z + r * 0.45
	piece(c, "CrownBand", "cylinder", V(r * 0.4, r * 1.1, r * 1.1), upright(fc.X, top + r * 0.15, z), GOLD, Enum.Material.Metal)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		local p = V(fc.X + math.cos(a) * r * 0.5, top + r * 0.48, z + math.sin(a) * r * 0.5)
		piece(c, "CrownPoint", "wedge", V(r * 0.12, r * 0.36, r * 0.2), at(p.X, p.Y, p.Z) * CFrame.Angles(0, -a, 0), GOLD, Enum.Material.Metal)
		piece(c, "Jewel", "ball", V(r * 0.12, r * 0.12, r * 0.12), at(p.X, p.Y + r * 0.2, p.Z), if i % 2 == 0 then rgb(220, 40, 70) else rgb(70, 140, 255), Enum.Material.Neon)
	end
end
WEAR.nightcap = function(c, fc, r, top)
	piece(c, "Cap", "egg", V(r * 1.3, r * 0.9, r * 1.2), at(fc.X, top + r * 0.1, fc.Z + r * 0.6) * CFrame.Angles(0, 0, math.rad(-20)), rgb(70, 80, 160))
	piece(c, "Pompom", "ball", V(r * 0.35, r * 0.35, r * 0.35), at(fc.X + r * 0.7, top + r * 0.4, fc.Z + r * 0.6), WHITE)
end
WEAR.postcap = function(c, fc, r, top)
	piece(c, "Cap", "cylinder", V(r * 0.4, r * 1.1, r * 1.1), upright(fc.X, top + r * 0.1, fc.Z + r * 0.4), rgb(40, 60, 140))
	piece(c, "Peak", "egg", V(r * 0.8, r * 0.1, r * 0.5), at(fc.X, top - r * 0.08, fc.Z - r * 0.2), INK)
end
WEAR.helmet = function(c, fc, r)
	local h = piece(c, "Helmet", "ball", V(r * 2.5, r * 2.5, r * 2.5), at(fc.X, fc.Y + r * 0.1, fc.Z + r * 0.55), rgb(200, 230, 255), Enum.Material.Glass)
	h.Transparency = 0.6
	piece(c, "HelmetRing", "cylinder", V(r * 0.2, r * 1.7, r * 1.7), upright(fc.X, fc.Y - r * 1.05, fc.Z + r * 0.55), rgb(220, 220, 230), Enum.Material.Metal)
end
WEAR.visor = function(c, fc, r, top)
	local v = piece(c, "Visor", "egg", V(r * 1.6, r * 0.12, r * 0.9), at(fc.X, top - r * 0.1, fc.Z - r * 0.15), rgb(60, 180, 90))
	v.Transparency = 0.25
end
WEAR.moustache = function(c, fc, r)
	for _, side in { -1, 1 } do
		piece(c, "Moustache", "egg", V(r * 0.7, r * 0.24, r * 0.16), at(fc.X + side * r * 0.32, fc.Y - r * 0.2, fc.Z - r * 0.05) * CFrame.Angles(0, 0, math.rad(side * 14)), rgb(70, 46, 34))
		piece(c, "Curl", "ball", V(r * 0.16, r * 0.16, r * 0.16), at(fc.X + side * r * 0.68, fc.Y - r * 0.06, fc.Z - r * 0.05), rgb(70, 46, 34))
	end
end
WEAR.monocle = function(c, fc, r)
	local m = piece(c, "Monocle", "cylinder", V(r * 0.05, r * 0.62, r * 0.62), at(fc.X + r * 0.42, fc.Y + r * 0.12, fc.Z - r * 0.32) * CFrame.Angles(0, math.rad(90), 0), GOLD, Enum.Material.Metal)
	m.Transparency = 0.1
	piece(c, "Chain", "block", V(r * 0.03, r * 0.6, r * 0.03), at(fc.X + r * 0.6, fc.Y - r * 0.25, fc.Z - r * 0.3), GOLD, Enum.Material.Metal)
end
WEAR.goggles = function(c, fc, r)
	for _, side in { -1, 1 } do
		piece(c, "Goggle", "cylinder", V(r * 0.2, r * 0.5, r * 0.5), at(fc.X + side * r * 0.42, fc.Y + r * 0.62, fc.Z - r * 0.15) * CFrame.Angles(0, math.rad(90), 0), rgb(120, 90, 60), Enum.Material.Metal)
		piece(c, "Lens", "cylinder", V(r * 0.05, r * 0.38, r * 0.38), at(fc.X + side * r * 0.42, fc.Y + r * 0.62, fc.Z - r * 0.26) * CFrame.Angles(0, math.rad(90), 0), rgb(120, 200, 255), Enum.Material.Glass)
	end
	piece(c, "Strap", "block", V(r * 2.0, r * 0.12, r * 0.08), at(fc.X, fc.Y + r * 0.62, fc.Z + r * 0.3), rgb(60, 40, 30))
end
WEAR.mask = function(c, fc, r)
	piece(c, "Mask", "egg", V(r * 1.5, r * 0.5, r * 0.12), at(fc.X, fc.Y + r * 0.14, fc.Z - r * 0.12), rgb(40, 20, 60))
	piece(c, "MaskTrim", "egg", V(r * 1.56, r * 0.06, r * 0.1), at(fc.X, fc.Y + r * 0.38, fc.Z - r * 0.12), GOLD, Enum.Material.Metal)
end
WEAR.bowtie = function(c, fc, r)
	local y = fc.Y - r * 1.25
	for _, side in { -1, 1 } do
		piece(c, "Bowtie", "wedge", V(r * 0.12, r * 0.34, r * 0.36), at(fc.X + side * r * 0.2, y, fc.Z + r * 0.05) * CFrame.Angles(0, math.rad(side * 90), 0), rgb(170, 20, 40))
	end
	piece(c, "Knot", "ball", V(r * 0.16, r * 0.16, r * 0.16), at(fc.X, y, fc.Z), rgb(130, 14, 30))
end
WEAR.tie = function(c, fc, r)
	piece(c, "Tie", "block", V(r * 0.24, r * 0.9, r * 0.06), at(fc.X, fc.Y - r * 1.6, fc.Z + r * 0.02) * CFrame.Angles(0, 0, math.rad(3)), rgb(150, 20, 36))
	piece(c, "Knot", "ball", V(r * 0.22, r * 0.22, r * 0.22), at(fc.X, fc.Y - r * 1.12, fc.Z + r * 0.02), rgb(120, 14, 28))
end
WEAR.scarf = function(c, fc, r)
	piece(c, "Scarf", "cylinder", V(r * 0.3, r * 1.9, r * 1.9), upright(fc.X, fc.Y - r * 1.0, fc.Z + r * 0.6), rgb(220, 50, 50))
	piece(c, "ScarfEnd", "block", V(r * 0.3, r * 0.9, r * 0.08), at(fc.X + r * 0.6, fc.Y - r * 1.4, fc.Z + r * 1.4) * CFrame.Angles(math.rad(-40), 0, 0), rgb(220, 50, 50))
end
WEAR.pearls = function(c, fc, r)
	for i = 0, 8 do
		local a = math.rad(-80 + i * 20)
		piece(c, "Pearl", "ball", V(r * 0.16, r * 0.16, r * 0.16), at(fc.X + math.sin(a) * r * 0.75, fc.Y - r * 1.2 - math.cos(a) * r * 0.2, fc.Z + r * 0.05 + (1 - math.cos(a)) * r * 0.2), rgb(250, 246, 240))
	end
end
WEAR.dress = function(c, fc, r, _top, _col, two)
	piece(c, "Dress", "cylinder", V(r * 1.2, r * 2.6, r * 2.6), upright(fc.X, fc.Y - r * 2.2, fc.Z + r * 0.7), two)
	piece(c, "DressTrim", "cylinder", V(r * 0.12, r * 2.7, r * 2.7), upright(fc.X, fc.Y - r * 2.8, fc.Z + r * 0.7), WHITE)
end
WEAR.waistcoat = function(c, fc, r, _top, _col, two)
	piece(c, "Waistcoat", "egg", V(r * 2.2, r * 1.8, r * 0.4), at(fc.X, fc.Y - r * 2.0, fc.Z + r * 0.15), two)
	for i = 0, 2 do
		piece(c, "Button", "ball", V(r * 0.12, r * 0.12, r * 0.12), at(fc.X, fc.Y - r * 1.6 - i * r * 0.3, fc.Z - r * 0.05), GOLD, Enum.Material.Metal)
	end
end
WEAR.cape = function(c, fc, r)
	piece(c, "Cape", "block", V(r * 2.2, r * 2.0, r * 0.08), at(fc.X, fc.Y - r * 1.0, fc.Z + r * 1.8) * CFrame.Angles(math.rad(-12), 0, 0), rgb(150, 20, 50))
	piece(c, "CapeFur", "egg", V(r * 2.3, r * 0.3, r * 0.6), at(fc.X, fc.Y - r * 0.1, fc.Z + r * 1.4), WHITE)
end
WEAR.tutu = function(c, fc, r)
	for i = 0, 1 do
		local t = piece(c, "Tutu", "cylinder", V(r * 0.16, r * 2.6 - i * 0.3 * r, r * 2.6 - i * 0.3 * r), upright(fc.X, fc.Y - r * 1.9 + i * r * 0.12, fc.Z + r * 0.6), rgb(255, 170, 210), Enum.Material.Neon)
		t.Transparency = 0.35
	end
end
WEAR.mic = function(c, fc, r)
	piece(c, "Mic", "cylinder", V(r * 0.7, r * 0.16, r * 0.16), at(fc.X + r * 1.5, fc.Y - r * 0.6, fc.Z - r * 0.2) * CFrame.Angles(0, 0, math.rad(70)), INK)
	piece(c, "MicHead", "ball", V(r * 0.36, r * 0.36, r * 0.36), at(fc.X + r * 1.38, fc.Y - r * 0.2, fc.Z - r * 0.2), rgb(190, 190, 200), Enum.Material.Metal)
end
WEAR.baton = function(c, fc, r)
	piece(c, "Baton", "cylinder", V(r * 1.4, r * 0.06, r * 0.06), at(fc.X + r * 1.6, fc.Y + r * 0.2, fc.Z - r * 0.3) * CFrame.Angles(0, 0, math.rad(50)), WHITE)
end
WEAR.flex = function(_c, _fc, _r) end -- (its arms: limbs(flex))
WEAR.cone = function(c, fc, r)
	piece(c, "Cone", "cylinder", V(r * 0.6, r * 0.32, r * 0.32), at(fc.X + r * 1.6, fc.Y - r * 1.2, fc.Z - r * 0.2) * CFrame.Angles(0, 0, math.rad(90)), rgb(210, 150, 80))
	piece(c, "Scoop", "ball", V(r * 0.42, r * 0.42, r * 0.42), at(fc.X + r * 1.6, fc.Y - r * 0.82, fc.Z - r * 0.2), rgb(250, 200, 220))
end
WEAR.keys = function(c, fc, r)
	piece(c, "Keyboard", "block", V(r * 2.2, r * 0.16, r * 0.6), at(fc.X, fc.Y - r * 2.4, fc.Z - r * 1.0), INK)
	for i = -4, 4 do
		piece(c, "Key", "block", V(r * 0.2, r * 0.05, r * 0.4), at(fc.X + i * r * 0.23, fc.Y - r * 2.3, fc.Z - r * 1.05), WHITE)
	end
end
WEAR.jetpack = function(c, fc, r)
	for _, side in { -1, 1 } do
		local x = fc.X + side * r * 0.5
		piece(c, "Jet", "cylinder", V(r * 1.4, r * 0.5, r * 0.5), upright(x, fc.Y - r * 0.8, fc.Z + r * 2.4), rgb(200, 200, 210), Enum.Material.Metal)
		local flame = piece(c, "Flame", "egg", V(r * 0.36, r * 0.7, r * 0.36), at(x, fc.Y - r * 1.85, fc.Z + r * 2.4), rgb(255, 150, 40), Enum.Material.Neon)
		flame.Transparency = 0.2
	end
end
WEAR.wings = function(c, fc, r)
	for _, side in { -1, 1 } do
		piece(c, "Wing", "egg", V(r * 2.0, r * 1.1, r * 0.16), at(fc.X + side * r * 1.9, fc.Y + r * 0.6, fc.Z + r * 0.8) * CFrame.Angles(0, 0, math.rad(side * 25)), WHITE)
	end
end
WEAR.swirl = function(c, fc, r)
	for i = 0, 5 do
		local a = i * math.pi / 3
		local s = piece(c, "Swirl", "ball", V(r * 0.22, r * 0.22, r * 0.22), at(fc.X + math.cos(a) * r * 2.2, fc.Y - r * (1.6 - i * 0.18), fc.Z + r * 0.6 + math.sin(a) * r * 2.2), rgb(180, 220, 255), Enum.Material.Neon)
		s.Transparency = 0.4
	end
end
WEAR.bolt = function(c, fc, r)
	piece(c, "Bolt", "wedge", V(r * 0.12, r * 0.7, r * 0.4), at(fc.X + r * 1.2, fc.Y + r * 1.4, fc.Z) * CFrame.Angles(0, 0, math.rad(20)), rgb(255, 220, 60), Enum.Material.Neon)
	piece(c, "Bolt", "wedge", V(r * 0.12, r * 0.7, r * 0.4), at(fc.X + r * 1.0, fc.Y + r * 0.8, fc.Z) * CFrame.Angles(math.rad(180), 0, math.rad(20)), rgb(255, 220, 60), Enum.Material.Neon)
end
WEAR.ghost = function(c, fc, r)
	for i = 0, 2 do
		local g = piece(c, "Wisp", "egg", V(r * (0.7 - i * 0.15), r * (0.9 - i * 0.2), r * 0.6), at(fc.X - r * 1.5 - i * r * 0.4, fc.Y + r * (0.8 + i * 0.5), fc.Z + r * 0.8), WHITE, Enum.Material.Neon)
		g.Transparency = 0.6 + i * 0.1
	end
end
WEAR.sparkles = function(c, fc, r)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		piece(c, "Sparkle", "ball", V(r * 0.16, r * 0.16, r * 0.16), at(fc.X + math.cos(a) * r * 2.4, fc.Y + r * 1.4 + math.sin(a * 2) * r * 0.3, fc.Z + math.sin(a) * r * 2.4), rgb(255, 230, 140), Enum.Material.Neon)
	end
end
WEAR.snow = function(c, fc, r)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		local f = piece(c, "Snowflake", "block", V(r * 0.16, r * 0.02, r * 0.16), at(fc.X + math.cos(a) * r * 2.2, fc.Y + r * 1.2 + (i % 2) * r * 0.4, fc.Z + math.sin(a) * r * 2.2) * CFrame.Angles(0, a, math.rad(45)), rgb(220, 240, 255), Enum.Material.Neon)
		f.Transparency = 0.2
	end
end
WEAR.moon = function(c, fc, r)
	piece(c, "Moon", "ball", V(r * 0.6, r * 0.6, r * 0.6), at(fc.X - r * 1.6, fc.Y + r * 1.8, fc.Z + r * 0.4), rgb(250, 236, 170), Enum.Material.Neon)
	piece(c, "MoonShade", "ball", V(r * 0.56, r * 0.56, r * 0.56), at(fc.X - r * 1.42, fc.Y + r * 1.9, fc.Z + r * 0.35), rgb(40, 40, 90))
end
WEAR.jewels = function(c, fc, r)
	for i = -1, 1 do
		piece(c, "Jewel", "ball", V(r * 0.22, r * 0.22, r * 0.22), at(fc.X + i * r * 0.5, fc.Y - r * 1.15, fc.Z + r * 0.02), if i == 0 then rgb(220, 40, 70) else rgb(70, 160, 255), Enum.Material.Neon)
	end
end
WEAR.gem = function(c, fc, r)
	local g = piece(c, "Diamond", "wedge", V(r * 0.5, r * 0.5, r * 0.5), at(fc.X + r * 1.5, fc.Y - r * 0.9, fc.Z - r * 0.3), rgb(180, 230, 255), Enum.Material.Glass)
	g.Transparency = 0.15
end
WEAR.flower = function(c, fc, r)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		piece(c, "Petal", "ball", V(r * 0.26, r * 0.26, r * 0.26), at(fc.X - r * 0.9 + math.cos(a) * r * 0.22, fc.Y + r * 1.0 + math.sin(a) * r * 0.22, fc.Z), rgb(255, 170, 200))
	end
	piece(c, "FlowerHeart", "ball", V(r * 0.2, r * 0.2, r * 0.2), at(fc.X - r * 0.9, fc.Y + r * 1.0, fc.Z - r * 0.06), rgb(255, 220, 90))
end
WEAR.candle = function(c, _fc, _r, top)
	piece(c, "Candle", "cylinder", V(0.14, 0.06, 0.06), upright(0, top + 0.07, 0), rgb(250, 246, 230))
	local flame = piece(c, "Flame", "egg", V(0.05, 0.09, 0.05), at(0, top + 0.19, 0), rgb(255, 180, 60), Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = rgb(255, 190, 110)
	glow.Brightness = 0.8
	glow.Range = 8
	glow.Parent = flame
end
WEAR.letters = function(c, fc, r)
	for i = 0, 2 do
		piece(c, "Letter", "block", V(r * 0.7, r * 0.46, r * 0.04), at(fc.X + r * (1.4 + i * 0.1), fc.Y - r * (0.6 + i * 0.4), fc.Z - r * 0.3) * CFrame.Angles(0, 0, math.rad(-10 + i * 12)), WHITE)
	end
end
WEAR.tray = function(c, fc, r)
	piece(c, "Tray", "cylinder", V(r * 0.08, r * 1.6, r * 1.6), upright(fc.X + r * 1.8, fc.Y + r * 0.3, fc.Z - r * 0.2), rgb(200, 200, 210), Enum.Material.Metal)
	piece(c, "Cloche", "ball", V(r * 0.9, r * 0.9, r * 0.9), at(fc.X + r * 1.8, fc.Y + r * 0.55, fc.Z - r * 0.2), rgb(220, 220, 230), Enum.Material.Metal)
end
WEAR.briefcase = function(c, fc, r)
	piece(c, "Briefcase", "block", V(r * 1.1, r * 0.8, r * 0.3), at(fc.X + r * 1.8, fc.Y - r * 2.2, fc.Z - r * 0.2), rgb(60, 40, 30), Enum.Material.Leather)
	piece(c, "Clasp", "block", V(r * 0.2, r * 0.1, r * 0.05), at(fc.X + r * 1.8, fc.Y - r * 1.95, fc.Z - r * 0.37), GOLD, Enum.Material.Metal)
end
WEAR.bag = function(c, fc, r)
	piece(c, "Swag", "ball", V(r * 1.0, r * 1.0, r * 1.0), at(fc.X - r * 1.4, fc.Y - r * 1.6, fc.Z + r * 0.6), rgb(230, 222, 200))
	piece(c, "Dollar", "block", V(r * 0.3, r * 0.4, r * 0.04), at(fc.X - r * 1.4, fc.Y - r * 1.6, fc.Z + r * 0.08), rgb(60, 140, 70))
end
WEAR.coins = function(c, fc, r)
	for i = 0, 3 do
		piece(c, "Coin", "cylinder", V(r * 0.08, r * 0.5, r * 0.5), upright(fc.X + r * (1.4 + (i % 2) * 0.05), fc.Y - r * 2.6 + i * r * 0.1, fc.Z - r * 0.4), GOLD, Enum.Material.Metal)
	end
end
WEAR.cash = function(c, fc, r)
	for i = 0, 2 do
		piece(c, "Note", "block", V(r * 0.9, r * 0.08, r * 0.45), at(fc.X + r * 1.6, fc.Y - r * 1.6 + i * r * 0.09, fc.Z - r * 0.3), rgb(80, 160, 90))
	end
end

---------------------------------------------------------------------------------------------------
-- Building one
---------------------------------------------------------------------------------------------------
-- Builds the brainrot `id` (a meme curio), `height` studs tall. `colour`: its curio's colour (or
-- its mutation's, which tints it). Nil if it has no figure (a curio that isn't a brainrot).
function BrainrotFigure.build(id: string, height: number, colour: Color3?, tint: Color3?): Model?
	local sp = BrainrotFigure.Specs[id]
	if not sp then
		return nil
	end
	local body = BODIES[sp.body]
	if not body then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "BrainrotFigure"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local wear: { string } = sp.wear or {}
	local c: Ctx = { model = model, root = root, s = height, flex = table.find(wear, "flex") ~= nil }
	local col = sp.colour or colour or rgb(220, 180, 110)
	if tint then
		col = col:Lerp(tint, 0.45)
	end
	local two = sp.second or shade(col, 0.35)
	local fc, r, top = body(c, sp, col, two)
	if sp.body ~= "queen" then
		face(c, fc, r, sp.mood or "happy", sp.feature ~= nil and sp.feature.bigEyes == true, sp.feature ~= nil and sp.feature.beak == true)
	else
		face(c, fc, r, sp.mood or "proud")
	end
	for _, w in wear do
		local f = WEAR[w]
		if f then
			pcall(f, c, fc, r, top, col, two)
		end
	end
	model:SetAttribute("Brainrot", id)
	model:SetAttribute("Height", height)
	return model
end

-- Stands a figure just built (at the origin) at `cf`: every part of it moved there at once (so it
-- needs no physics to follow its root, as in a model that's never simulated).
function BrainrotFigure.place(model: Model, cf: CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = cf * d.CFrame
		end
	end
end

return BrainrotFigure
