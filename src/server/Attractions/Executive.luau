--!strict
-- The Executive Suite on the server: invitations, the Quartermaster's gear, and the run (shared by
-- everyone up there at once). Everything is judged here: where the server sees each guest, where
-- its own cameras, guards and the Executive look and stand, and what each shot hits (a ray from the
-- guest's own head, never a hit a screen claims).
--
--   Invitations   one is spent going up. Earned: the Maison Basement cleared (one), a haul of
--                 Config executive.inviteHaul or more banked in Steal a Luxe (one); bought for
--                 Gilt at the Quartermaster's desk; or given by the owner. A guest holds a few at
--                 most. No chance, no Robux.
--   Gear          the sidearm, free, taken before going up (no sidearm, no lift). The rest, for
--                 Gilt, is packed for the next run and works only in the Suite.
--   The hallway   seen by a camera or a guard, the alert rises (slower in a disguise; nobody looks
--                 at anyone while a decoy is out); full, security shows you out. Four terminals:
--                 a digit of the door's code each, to whoever reads it.
--   The door      its code, made new each run, at the keypad; three wrong tries, and the alert
--                 jumps. Right, it opens for everyone up there.
--   The Office    the Executive's three phases (shared/Executive.Phases). His briefcases and the
--                 bodyguards' fists take composure; none left, and you're escorted out. Beaten:
--                 everyone in the Office is paid (the Estate, Gems within the day's cap, his brainrot
--                 the first time), the safe opens (once each) and the lift down.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Fortune = require(ReplicatedStorage.Shared.Fortune)
local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local Plan = require(ReplicatedStorage.Shared.Executive)
local RemoteGuard = require(script.Parent.Parent.RemoteGuard)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ExecutiveBuild = require(script.Parent.ExecutiveBuild)
local Types = require(script.Parent.Types)
local okAnalytics, Analytics = pcall(function()
	return require(script.Parent.Parent.Analytics) :: any
end)

-- (What guests do up here, for the owner's analytics: how far they get, where they're shown out.)
local function note(player: Player, name: string, props: { [string]: any }?)
	if okAnalytics and Analytics and Analytics.custom then
		pcall(Analytics.custom, player, name, 1, props)
	end
end

local Executive = {}

local ID = "executive"

-- The server's clock (set by tests).
Executive.clock = function(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end
-- What a shot hits: the ExecTarget of the first thing in its way, or nil (set by tests).
Executive.ray = function(from: Vector3, toward: Vector3, ignore: { Instance }): string?
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		return Workspace:Raycast(from, toward, params)
	end)
	if not ok or not hit then
		return nil
	end
	local part: Instance? = (hit :: RaycastResult).Instance
	while part and part ~= Workspace do
		local tag = part:GetAttribute("ExecTarget")
		if type(tag) == "string" then
			return tag
		end
		part = part.Parent
	end
	return nil
end
-- What blocks sight in the hallway: its walls, the maze's partitions and the door (set at build).
-- Only walls: a guest is hidden behind a wall, never behind another guest or a lectern, exactly as
-- every screen draws the guards' and cameras' sight on the floor (World/ExecutiveSight).
local sightWalls: { Instance } = {}
-- Whether no wall stands between two points (set by tests).
Executive.clear = function(from: Vector3, to: Vector3, _ignore: { Instance }): boolean
	if #sightWalls == 0 then
		return true
	end
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = sightWalls
		return Workspace:Raycast(from, to - from, params)
	end)
	return not ok or hit == nil
end
-- How a guard or the Executive walks (set by tests).
Executive.walk = function(actor: any, target: Vector3, speed: number)
	local h = actor.humanoid
	if h then
		h.WalkSpeed = speed
		h:MoveTo(target)
	end
end
-- Security's armour, on a figure built by the staff rig: a helmet with a dark visor, a plate
-- carrier marked SECURITY front and back, shoulder and knee pads, a belt and a radio. No weapon of
-- any kind: the Suite's security never shoots (they notice, they chase, they escort). Every piece
-- is welded on, weightless and walked through, and never in the way of a sight line.
local ARMOUR = Color3.fromRGB(34, 38, 44)
local ARMOUR_DARK = Color3.fromRGB(20, 22, 26)
function Executive.armour(model: Model)
	for _, name in { "CoatTails", "Tie", "ShirtFront", "LapelKey", "LapelKeyBow" } do
		local old = model:FindFirstChild(name, true)
		if old then
			old:Destroy()
		end
	end
	local function on(partName: string, name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material?): BasePart?
		local body = model:FindFirstChild(partName)
		if not body or not body:IsA("BasePart") then
			return nil
		end
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.Anchored = false
		p.CastShadow = true
		p.CFrame = body.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local hs = head.Size
		local helmet = on("Head", "Helmet", Vector3.new(hs.X * 1.18, hs.Y * 0.62, hs.Z * 1.22), CFrame.new(0, hs.Y * 0.32, -hs.Z * 0.02), ARMOUR_DARK)
		if helmet then
			local dome = Instance.new("SpecialMesh")
			dome.MeshType = Enum.MeshType.Sphere
			dome.Parent = helmet
		end
		on("Head", "HelmetBrim", Vector3.new(hs.X * 1.2, hs.Y * 0.08, hs.Z * 0.3), CFrame.new(0, hs.Y * 0.12, -hs.Z * 0.6), ARMOUR_DARK)
		local visor = on("Head", "Visor", Vector3.new(hs.X * 1.02, hs.Y * 0.26, hs.Z * 0.12), CFrame.new(0, hs.Y * 0.04, -hs.Z * 0.52), Color3.fromRGB(8, 10, 14), Enum.Material.Glass)
		if visor then
			visor.Reflectance = 0.35
			visor.Transparency = 0.08
		end
	end
	local torso = model:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		local ts = torso.Size
		local vest = on("UpperTorso", "Vest", Vector3.new(ts.X * 1.12, ts.Y * 0.92, ts.Z * 1.35), CFrame.new(0, -ts.Y * 0.02, 0), ARMOUR, Enum.Material.Fabric)
		if vest then
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local gui = Instance.new("SurfaceGui")
				gui.Name = "Mark" .. face.Name
				gui.Face = face
				gui.CanvasSize = Vector2.new(240, 120)
				gui.LightInfluence = 0.6
				local word = Instance.new("TextLabel")
				word.BackgroundTransparency = 1
				word.Position = UDim2.fromScale(0.08, 0.3)
				word.Size = UDim2.fromScale(0.84, 0.32)
				word.Font = Enum.Font.GothamBlack
				word.TextScaled = true
				word.TextColor3 = Color3.fromRGB(232, 226, 212)
				word.Text = "SECURITY"
				word.Parent = gui
				gui.Parent = vest
			end
		end
		on("UpperTorso", "Plate", Vector3.new(ts.X * 0.7, ts.Y * 0.5, ts.Z * 0.18), CFrame.new(0, ts.Y * 0.12, -ts.Z * 0.72), ARMOUR_DARK)
		on("UpperTorso", "Radio", Vector3.new(ts.X * 0.14, ts.Y * 0.24, ts.Z * 0.18), CFrame.new(-ts.X * 0.38, ts.Y * 0.32, -ts.Z * 0.74), Color3.fromRGB(12, 12, 14))
	end
	local lower = model:FindFirstChild("LowerTorso")
	if lower and lower:IsA("BasePart") then
		local ls = lower.Size
		on("LowerTorso", "Belt", Vector3.new(ls.X * 1.1, ls.Y * 0.32, ls.Z * 1.3), CFrame.new(0, ls.Y * 0.2, 0), ARMOUR_DARK)
	end
	for _, side in { "Left", "Right" } do
		local arm = model:FindFirstChild(side .. "UpperArm")
		if arm and arm:IsA("BasePart") then
			local a = arm.Size
			on(side .. "UpperArm", side .. "Shoulder", Vector3.new(a.X * 1.35, a.Y * 0.42, a.Z * 1.35), CFrame.new(0, a.Y * 0.28, 0), ARMOUR)
		end
		local shin = model:FindFirstChild(side .. "LowerLeg")
		if shin and shin:IsA("BasePart") then
			local l = shin.Size
			on(side .. "LowerLeg", side .. "Knee", Vector3.new(l.X * 1.25, l.Y * 0.32, l.Z * 0.45), CFrame.new(0, l.Y * 0.32, -l.Z * 0.45), ARMOUR_DARK)
		end
	end
end

-- How a figure is made (set by tests).
Executive.makeFigure = function(parent: Instance, name: string, at: CFrame, kind: string): (Model, BasePart, Humanoid?)
	local ok, staff = pcall(function()
		local Rig = require(script.Parent.Parent.Staff.Rig) :: any
		local spec = Rig.look(if kind == "boss" then "Concierge" else "Guard")
		spec.coat = if kind == "boss" then Color3.fromRGB(20, 22, 40) else ARMOUR_DARK
		local built = Rig.build(name, spec, at, parent)
		-- (Security in armour; the Executive himself in his suit.)
		if kind ~= "boss" then
			pcall(Executive.armour, built.model)
		end
		return built
	end)
	if ok and staff then
		return staff.model, staff.root, staff.humanoid
	end
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = if kind == "boss" then Vector3.new(3, 4, 2) else Vector3.new(2, 3, 1)
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = at + Vector3.new(0, 3, 0)
	root.Color = if kind == "boss" then Color3.fromRGB(20, 22, 40) else Color3.fromRGB(14, 14, 16)
	root.Parent = m
	m.PrimaryPart = root
	m.Parent = parent
	return m, root, nil
end

type Actor = { id: string, kind: string, model: Model, root: BasePart, humanoid: Humanoid?, hp: number, max: number, index: number, lastHit: number, points: { Vector3 }? }
type Guest = {
	alert: number,
	composure: number,
	max: number,
	gear: { [string]: boolean },
	decoyUsed: boolean,
	digits: { [number]: boolean },
	tries: number,
	lastShot: number,
	paid: boolean,
	safe: boolean,
	looted: { [string]: boolean }?, -- (Build 94) the Office's other loot, raided this run
	hits: { [string]: boolean },
	out: boolean,
	extracted: boolean?, -- (Build 78) away down the lift within the extraction's minute
	everSeen: boolean?, -- (Build 90) seen at all in the hallway this run (the Ghost challenge)
	wrongs: number?, -- (Build 90) wrong tries at the vault door this run, never reset (Steady Hand)
	seen: string?, -- (Build 81) who has eyes on them right now: "camera", "guard", or nil
	sentAlert: number?, -- the alert their screen was last told
	-- (Build 82) Chronos Defiance: the moment after being caught (where, until when, whether
	-- Roblox's purchase window is open, the countdown left when it opened), the revives spent this
	-- run, and a moment untouchable after one.
	revive: { where: string, deadline: number, prompting: boolean, left: number }?,
	revives: number?,
	safeUntil: number?,
	held: boolean?, -- (Build 98) anchored where they were caught, until a revive or leaving
}
type Shot = { id: string, from: Vector3, dir: Vector3, speed: number, born: number, radius: number, damage: number, life: number }
type Wave = { id: string, at: Vector3, born: number, speed: number, width: number, damage: number, life: number }

local origin = Vector3.zero
local built: ExecutiveBuild.Built? = nil
local guests: { [Player]: Guest } = {}
local run = {
	code = "0000",
	open = false,
	phase = "hall" :: string, -- "hall", "shield", "detail", "boss", "won"
	generators = {} :: { [string]: number },
	genMax = {} :: { [string]: number }, -- (Build 87) each generator's full charge, for its bar
	actors = {} :: { [string]: Actor },
	shots = {} :: { Shot },
	waves = {} :: { Wave },
	nextAttack = 0,
	attackIndex = 0,
	decoyUntil = -math.huge,
	decoyAt = Vector3.zero,
	wonAt = 0,
	serial = 0,
	hallGuards = {} :: { Actor },
	-- Build 78: the attack he's winding up (fires at `fireAt`), his finale, the extraction's end.
	pending = nil :: { kind: string, fireAt: number, from: Vector3, to: Vector3?, at: Vector3? }?,
	finale = false,
	extractUntil = 0,
	-- (Build 90) This run's look and challenge, and when the vault door opened.
	look = "midnight",
	challenge = "ghost",
	openedAt = 0,
	-- (Build 94) The beaten Executive on his way out (Executive.step).
	exit = nil :: { actor: Actor, door: Vector3, goneAt: number }?,
}
local rng = Random.new()

-- (Build 90) Which look and challenge the next run has (tests set their own).
Executive.pick = function(): (string, string)
	return Plan.Looks[rng:NextInteger(1, #Plan.Looks)].id, Plan.Challenges[rng:NextInteger(1, #Plan.Challenges)].id
end
-- The season now (tests set their own).
Executive.seasonNow = function(): string?
	local t = os.date("!*t") :: any
	local house = Workspace:GetAttribute("Season")
	return Plan.seasonOf(HolidayGames.byCalendar(), t.month, if type(house) == "string" then house else nil)
end

local function cfg(ctx: Types.Ctx): { [string]: any }
	return ctx.cfg(ID)
end

local function page(ctx: Types.Ctx, data: any): { [string]: any }
	local p = ctx.saved(data, ID)
	p.invites = if type(p.invites) == "number" then math.max(0, math.floor(p.invites)) else 0
	p.sidearm = p.sidearm == true
	p.kit = if type(p.kit) == "table" then p.kit else {}
	p.wins = if type(p.wins) == "number" then p.wins else 0
	p.firstWin = p.firstWin == true
	return p
end

local function scale(): number
	local n = 0
	for _, g in guests do
		if not g.out then
			n += 1
		end
	end
	return 1 + 0.5 * math.max(0, n - 1)
end

local function broadcast(ctx: Types.Ctx, message: { [string]: any })
	for player in guests do
		ctx.send(player, message)
	end
end

-- (Build 90) Whether a guest still meets (or, once he's beaten, met) this run's challenge.
function Executive.onCourse(g: Guest, t: number): boolean
	local id = run.challenge
	if id == "ghost" then
		return g.everSeen ~= true
	elseif id == "steady" then
		return (g.wrongs or 0) == 0
	elseif id == "untouchable" then
		return g.composure >= g.max and (g.revives or 0) == 0
	elseif id == "swift" then
		local done = if run.phase == "won" then run.wonAt else t
		return run.openedAt <= 0 or done - run.openedAt <= Plan.SWIFT_SECONDS
	end
	return false
end

local function status(ctx: Types.Ctx, player: Player): { [string]: any }
	local g = guests[player]
	local bossHp, bossMax = 0, 1
	local boss = run.actors.boss
	if boss then
		bossHp, bossMax = boss.hp, boss.max
	end
	local gens, guardsLeft = 0, 0
	for _, hp in run.generators do
		if hp > 0 then
			gens += 1
		end
	end
	for _, a in run.actors do
		if a.kind == "guard" and a.hp > 0 then
			guardsLeft += 1
		end
	end
	local digits = {}
	if g then
		for k = 1, 4 do
			digits[k] = if g.digits[k] then string.sub(run.code, k, k) else "_"
		end
	end
	return {
		op = "executive",
		phase = run.phase,
		open = run.open,
		alert = if g then math.floor(g.alert * 100 + 0.5) / 100 else 0,
		composure = if g then g.composure else 0,
		max = if g then g.max else 100,
		gear = if g then g.gear else {},
		decoy = if g then not g.decoyUsed and g.gear.decoy == true else false,
		digits = table.concat(digits, " "),
		generators = gens,
		guards = guardsLeft,
		boss = bossHp,
		bossMax = bossMax,
		finale = run.finale,
		extractUntil = if run.phase == "won" then run.extractUntil else nil,
		seen = if g then g.seen else nil,
		-- (Build 90) Tonight's look and challenge, and whether this guest is still on course for it.
		look = run.look,
		lookName = (Plan.lookById[run.look] or Plan.Looks[1]).name,
		challenge = run.challenge,
		challengeName = (Plan.challengeById[run.challenge] or Plan.Challenges[1]).name,
		challengeLine = (Plan.challengeById[run.challenge] or Plan.Challenges[1]).line,
		challengeGilt = (Plan.challengeById[run.challenge] or Plan.Challenges[1]).gilt,
		onCourse = if g then Executive.onCourse(g, Executive.clock()) else false,
	}
end

local function push(ctx: Types.Ctx, player: Player)
	ctx.send(player, status(ctx, player))
end

local function pushAll(ctx: Types.Ctx)
	for player in guests do
		push(ctx, player)
	end
end

---------------------------------------------------------------------------------------------------
-- The run: made new when the Suite is empty
---------------------------------------------------------------------------------------------------
local function clearActors()
	for _, a in run.actors do
		if a.model then
			a.model:Destroy()
		end
	end
	run.actors = {}
end

local function fresh(_ctx: Types.Ctx)
	local b = built
	if not b then
		return
	end
	run.code = string.format("%04d", rng:NextInteger(0, 9999))
	run.open = false
	run.phase = "hall"
	run.shots, run.waves = {}, {}
	run.decoyUntil = -math.huge
	run.wonAt = 0
	run.pending = nil
	run.finale = false
	run.extractUntil = 0
	run.openedAt = 0
	run.exit = nil
	-- (Build 90) A look and a challenge for this run, and the season's dressing.
	local lookId, challengeId = Executive.pick()
	local theme = Plan.lookById[lookId] or Plan.Looks[1]
	run.look = theme.id
	run.challenge = if Plan.challengeById[challengeId] then challengeId else Plan.Challenges[1].id
	pcall(ExecutiveBuild.style, b, origin, theme)
	pcall(ExecutiveBuild.tonight, b, theme, Plan.challengeById[run.challenge])
	pcall(ExecutiveBuild.season, b, origin, Executive.seasonNow())
	b.root:SetAttribute("SuiteChallenge", run.challenge)
	clearActors()
	run.generators = {}
	run.genMax = {}
	for i, part in b.generators do
		run.generators["gen" .. i] = 100
		run.genMax["gen" .. i] = 100
		part.Transparency = 0
		part:SetAttribute("Hp", nil)
		part:SetAttribute("HpMax", nil)
	end
	ExecutiveBuild.door(b, true)
	b.shield.CanCollide = true
	b.shield.Transparency = 0.3
	b.safe.Enabled = false
	b.liftDown.Enabled = false
	-- (Build 94) The rest of the loot shut away again until he's next beaten.
	for _, pr in b.loot do
		pr.Enabled = false
	end
	for _, glow in b.lootGlow do
		glow.Enabled = false
	end
	b.dropped.Parent = nil
	-- The hallway's guards, on their rounds.
	for _, a in run.hallGuards do
		if a.model then
			a.model:Destroy()
		end
	end
	run.hallGuards = {}
	for i, round in Plan.GuardRounds do
		local points = {}
		for _, p in round do
			table.insert(points, origin + p)
		end
		if theme.reverse and #points > 1 then
			-- (This look: the same round, walked the other way.)
			local back = {}
			for k = #points, 1, -1 do
				table.insert(back, points[k])
			end
			points = back
		end
		local model, root, humanoid = Executive.makeFigure(b.actors, "HallGuard" .. i, CFrame.lookAt(points[1], points[2]), "guard")
		table.insert(run.hallGuards, { id = "hall" .. i, kind = "hallGuard", model = model, root = root, humanoid = humanoid, hp = 1, max = 1, index = 2, lastHit = 0, points = points })
	end
	-- The Executive at his desk, behind the shield.
	local model, root, humanoid = Executive.makeFigure(b.actors, "TheExecutive", CFrame.lookAt(origin + Plan.Desk + Vector3.new(0, 0, 3), origin + Plan.Desk + Vector3.new(0, 0, -10)), "boss")
	-- (Tagged on the whole figure: a shot hits his body, not just his middle.)
	root:SetAttribute("ExecTarget", "boss")
	model:SetAttribute("ExecTarget", "boss")
	run.actors.boss = { id = "boss", kind = "boss", model = model, root = root, humanoid = humanoid, hp = 1, max = 1, index = 1, lastHit = 0 }
end

---------------------------------------------------------------------------------------------------
-- Damage and phases
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Caught, and Chronos Defiance
---------------------------------------------------------------------------------------------------
-- The revives (set at boot from Purchases/Revive; tests set their own): how many the guest holds,
-- whether Chronos Defiance is on sale and its price (shown on the key, never hidden), spending one
-- held, and Roblox's purchase window. The Suite owns the moment: only the server decides a guest
-- was caught and opens the window; a screen can only ask to revive, never say it may.
Executive.revives = {
	held = function(_player: Player): number
		return 0
	end,
	onSale = function(): boolean
		return false
	end,
	price = function(): number?
		return nil
	end,
	spend = function(_player: Player): boolean
		return false
	end,
	offer = function(_player: Player, _context: string): (boolean, string?)
		return false, "That isn't on sale yet."
	end,
}
-- How long the moment stands (the run ends with it), how long it waits while Roblox's window is
-- open and then for the receipt, and the most revives one run takes.
Executive.REVIVE = { window = 15, promptWait = 60, receiptWait = 25, most = 3 }

local suite: Types.Ctx? = nil -- (the attraction's context, for the purchase's own callbacks)

local function reviveMessage(player: Player, g: Guest, op: string): { [string]: any }
	local r = g.revive
	local used = g.revives or 0
	return {
		op = op,
		where = if r then r.where else nil,
		left = if r then math.max(0, r.deadline - Executive.clock()) else 0,
		prompting = if r then r.prompting else false,
		held = Executive.revives.held(player),
		onSale = Executive.revives.onSale(),
		price = Executive.revives.price(),
		used = used,
		usesLeft = Executive.REVIVE.most - used,
	}
end

-- Caught (the alarm in the hall, or no composure left in the Office): the moment for a revive, if
-- one can be had (one held, or Chronos Defiance on sale) and this run hasn't used its last;
-- otherwise security shows them out at once.
-- (Build 98) Held where they stand while caught: the server anchors their character (it replicates;
-- no client asks), so nobody walks on, reads digits or lines up the Executive while the revive
-- moment is open. Let go on a revive or on leaving the Suite.
local function still(ctx: Types.Ctx, player: Player, g: Guest?, on: boolean)
	local root = ctx.rootOf(player)
	if g then
		if not on and not g.held then
			return
		end
		g.held = if on then true else nil
	end
	if root then
		pcall(function()
			root.Anchored = on
			root.AssemblyLinearVelocity = Vector3.zero
		end)
	end
end

local function caught(ctx: Types.Ctx, player: Player, g: Guest, where: string)
	g.out = true
	g.seen = nil
	still(ctx, player, g, true)
	local used = g.revives or 0
	local can = run.phase ~= "won" and used < Executive.REVIVE.most and (Executive.revives.held(player) > 0 or Executive.revives.onSale())
	ctx.send(player, { op = if where == "office" then "escorted" else "alarm", revive = can })
	if can then
		g.revive = { where = where, deadline = Executive.clock() + Executive.REVIVE.window, prompting = false, left = Executive.REVIVE.window }
		ctx.send(player, reviveMessage(player, g, "caught"))
		return
	end
	ctx.sendHome(player, ID)
end

-- Spends a revive on the open moment: back in the run where it stood (the hall's lift lobby with
-- the digits already read, or just inside the Office's door), the alert down, composure full, and
-- a moment untouchable. True if revived.
local function revive(ctx: Types.Ctx, player: Player): boolean
	local g = guests[player]
	local r = g and g.revive
	if not g or not r or not g.out or run.phase == "won" or ctx.inside(player) ~= ID then
		return false
	end
	if not Executive.revives.spend(player) then
		return false
	end
	local used = (g.revives or 0) + 1
	g.revive = nil
	g.revives = used
	g.out = false
	g.alert = 0
	g.sentAlert = 0
	g.seen = nil
	g.composure = g.max
	g.safeUntil = Executive.clock() + 3
	local back = if r.where == "office" then Plan.OfficeEntry else Plan.Arrival
	ctx.teleport(player, CFrame.new(origin + back))
	still(ctx, player, g, false)
	ctx.send(player, { op = "revived", where = r.where, composure = g.composure, held = Executive.revives.held(player), used = used, usesLeft = Executive.REVIVE.most - used })
	note(player, "Executive revived", { phase = run.phase, where = r.where })
	push(ctx, player)
	return true
end

-- For Purchases/Revive (a revive moment of its own, beside the tables'): open, spend, closed.
function Executive.reviveOpen(player: Player): boolean
	local g = guests[player]
	return g ~= nil and g.revive ~= nil and run.phase ~= "won"
end

function Executive.reviveNow(player: Player): boolean
	return suite ~= nil and revive(suite :: Types.Ctx, player)
end

function Executive.reviveClosed(player: Player, purchased: boolean)
	local g = guests[player]
	local r = g and g.revive
	if not g or not r or not r.prompting or not suite then
		return
	end
	r.prompting = false
	-- Bought: wait for Roblox's receipt (it revives the moment it's granted). Not bought: the
	-- countdown resumes where it stood.
	r.deadline = Executive.clock() + (if purchased then Executive.REVIVE.receiptWait else r.left)
	;(suite :: Types.Ctx).send(player, reviveMessage(player, g, "caughtUpdate"))
end

local function hurt(ctx: Types.Ctx, player: Player, g: Guest, amount: number, why: string)
	if g.out or (g.safeUntil and Executive.clock() < g.safeUntil) then
		return
	end
	g.composure = math.max(0, g.composure - amount)
	ctx.send(player, { op = "hurt", amount = amount, why = why, composure = g.composure })
	if g.composure <= 0 then
		note(player, "Executive escorted", { phase = run.phase, why = why })
		caught(ctx, player, g, "office")
	end
end

-- (Build 87) What's left of a target, on the target itself (its part's or model's "Hp" and "HpMax"
-- attributes), for every screen's health bar over it. Only the server writes them.
local function showHp(target: string)
	local b = built
	if string.sub(target, 1, 3) == "gen" then
		local part = b and b.generators[tonumber(string.sub(target, 4)) or 0]
		if part then
			part:SetAttribute("Hp", run.generators[target] or 0)
			part:SetAttribute("HpMax", run.genMax[target] or 100)
			part:SetAttribute("ExecTarget", target)
			CollectionService:AddTag(part, "ExecHp")
		end
	else
		local a = run.actors[target]
		if a and a.model and a.model.Parent then
			a.model:SetAttribute("Hp", a.hp)
			a.model:SetAttribute("HpMax", a.max)
			CollectionService:AddTag(a.model, "ExecHp")
		end
	end
end
Executive.showHp = showHp

local function startPhase(ctx: Types.Ctx, phase: string)
	run.phase = phase
	local b = built :: ExecutiveBuild.Built
	local s = scale()
	if phase == "shield" then
		for id in run.generators do
			run.generators[id] = math.floor((tonumber(cfg(ctx).generatorHp) or 120) * s)
			run.genMax[id] = run.generators[id]
			showHp(id)
		end
		run.nextAttack = Executive.clock() + 3
	elseif phase == "detail" then
		b.shield.CanCollide = false
		b.shield.Transparency = 1
		for i, at in Plan.GuardDoors do
			local model, root, humanoid = Executive.makeFigure(b.actors, "Bodyguard" .. i, CFrame.new(origin + at), "guard")
			root:SetAttribute("ExecTarget", "guard" .. i)
			model:SetAttribute("ExecTarget", "guard" .. i)
			run.actors["guard" .. i] = { id = "guard" .. i, kind = "guard", model = model, root = root, humanoid = humanoid, hp = math.floor((tonumber(cfg(ctx).guardHp) or 75) * s), max = math.floor((tonumber(cfg(ctx).guardHp) or 75) * s), index = 1, lastHit = 0 }
			showHp("guard" .. i)
		end
	elseif phase == "boss" then
		local boss = run.actors.boss
		if boss then
			boss.hp = math.floor((tonumber(cfg(ctx).bossHp) or 560) * s)
			boss.max = boss.hp
			showHp("boss")
		end
		run.nextAttack = Executive.clock() + 2
		run.attackIndex = 0
	elseif phase == "won" then
		run.wonAt = Executive.clock()
		run.pending = nil
		-- The extraction: the lift down within the minute, for a clean getaway's bonus.
		run.extractUntil = run.wonAt + (tonumber(cfg(ctx).extractSeconds) or 60)
		b.safe.Enabled = true
		b.liftDown.Enabled = true
		for _, pr in b.loot do
			pr.Enabled = true
		end
		for _, glow in b.lootGlow do
			glow.Enabled = true
		end
		b.dropped.Parent = b.root
		-- (Build 94) He's had enough: no more attacks, no more targets. He runs for the nearest of
		-- his bodyguards' doors and is gone through it (Executive.step finishes the exit).
		local boss = run.actors.boss
		if boss and boss.model.Parent then
			boss.hp = 0
			;(boss :: any).leaving = true
			boss.root:SetAttribute("ExecTarget", nil)
			boss.model:SetAttribute("ExecTarget", nil)
			local from = boss.root.CFrame.Position
			local best, bestD = Plan.GuardDoors[1], math.huge
			for _, at in Plan.GuardDoors do
				local d = Vector2.new(origin.X + at.X - from.X, origin.Z + at.Z - from.Z).Magnitude
				if d < bestD then
					best, bestD = at, d
				end
			end
			-- (Right up to the doors' leaves, a stud inside the wall's face.)
			local door = origin + best + Vector3.new(if best.X < 0 then -1.5 else 1.5, 0, 0)
			run.exit = { actor = boss, door = door, goneAt = run.wonAt + Plan.EXIT_SECONDS }
			Executive.walk(boss, door, Plan.EXIT_SPEED)
		end
	end
	local def = nil
	for _, p in Plan.Phases do
		if p.id == phase then
			def = p
		end
	end
	broadcast(ctx, { op = "phase", phase = phase, name = def and def.name, line = def and def.line, say = if def then def.say elseif phase == "won" then Plan.EXIT_SAY else nil })
	for player, g in guests do
		if not g.out then
			note(player, "Executive phase", { phase = phase })
		end
	end
	if phase == "shield" then
		-- (The way in: a moment's look at the man behind the desk, on every screen.)
		broadcast(ctx, { op = "intro", at = origin + Plan.Desk + Vector3.new(0, 4, 3), say = def and def.say })
	elseif phase == "won" then
		broadcast(ctx, { op = "extract", seconds = tonumber(cfg(ctx).extractSeconds) or 60, untilAt = run.extractUntil, gilt = tonumber(cfg(ctx).extractGilt) or 2500 })
	end
	pushAll(ctx)
end

local function win(ctx: Types.Ctx)
	local c = cfg(ctx)
	for player, g in guests do
		local at = ctx.at(player, ID)
		if not g.out and at and Plan.inOffice(at) and not g.paid then
			g.paid = true
			local data = ctx.data(player)
			if data then
				local p = page(ctx, data)
				p.wins += 1
				local worth = tonumber(c.prize) or 25000
				ctx.estate(player, worth, "The Executive Suite")
				local gilt = ctx.prize(player, tonumber(c.prizeGilt) or 600, "The Executive Suite: the prize")
				local brainrot = nil
				local first = not p.firstWin
				if first then
					p.firstWin = true
					if ctx.curio(player, "dirigenteSupremo", "The Executive Suite") then
						brainrot = "dirigenteSupremo"
					end
					ctx.herald(player, { kind = "executive", title = "The Executive beaten", line = "beat the Executive in his own office", glyph = "🕴️", worth = worth, everywhere = true })
				end
				ctx.award(player, "executiveBoss")
				ctx.tally(player, "executiveWins", 1)
				ctx.progress(player, "executiveWin", 1)
				-- (Build 90) This run's challenge, met: its Gilt, once.
				local ch = Plan.challengeById[run.challenge]
				local met = ch ~= nil and run.openedAt > 0 and Executive.onCourse(g, Executive.clock())
				local chGilt = 0
				if ch and met then
					chGilt = ctx.prize(player, ch.gilt, "The Executive Suite: " .. ch.name)
					ctx.tally(player, "executiveChallenges", 1)
					note(player, "Executive challenge", { challenge = ch.id })
				end
				ctx.send(player, { op = "won", worth = worth, gilt = gilt, brainrot = brainrot, first = first, challenge = if ch then ch.name else nil, challengeMet = met, challengeGilt = chGilt })
			end
		end
	end
	startPhase(ctx, "won")
end

-- A target is hit (by a guest's shot).
local function strike(ctx: Types.Ctx, target: string, damage: number)
	if string.sub(target, 1, 3) == "gen" then
		if run.phase ~= "shield" then
			return
		end
		local hp = run.generators[target]
		if not hp or hp <= 0 then
			return
		end
		run.generators[target] = math.max(0, hp - damage)
		showHp(target)
		if run.generators[target] <= 0 then
			local b = built :: ExecutiveBuild.Built
			local part = b.generators[tonumber(string.sub(target, 4)) or 0]
			if part then
				part.Transparency = 0.85
			end
			broadcast(ctx, { op = "down", target = target })
			local left = 0
			for _, v in run.generators do
				if v > 0 then
					left += 1
				end
			end
			if left == 0 then
				startPhase(ctx, "detail")
			end
		end
		pushAll(ctx)
	else
		local a = run.actors[target]
		if not a or a.hp <= 0 then
			return
		end
		local wanted = if a.kind == "guard" then "detail" elseif a.kind == "boss" then "boss" else nil
		if wanted and run.phase ~= wanted then
			return
		end
		a.hp = math.max(0, a.hp - damage)
		showHp(target)
		if a.hp <= 0 then
			broadcast(ctx, { op = "down", target = target })
			if a.kind == "guard" then
				if a.model then
					a.model:Destroy()
				end
				local left = 0
				for _, other in run.actors do
					if other.kind == "guard" and other.hp > 0 then
						left += 1
					end
				end
				if left == 0 then
					startPhase(ctx, "boss")
				end
			elseif a.kind == "boss" then
				win(ctx)
			end
		end
		pushAll(ctx)
	end
end

-- (Build 87) The target this phase is about that a shot from `from` along `dir` passes closest to,
-- within a little of it (more for a big target, and a touch more the further it is) and with no wall
-- in between; nil if none.
function Executive.assist(from: Vector3, dir: Vector3, range: number, ignore: { Instance }?): string?
	local best, bestAlong = nil, math.huge
	local function consider(id: string, at: Vector3, radius: number)
		local rel = at - from
		local along = rel:Dot(dir)
		if along <= 0 or along > range then
			return
		end
		local miss = (rel - dir * along).Magnitude
		-- (And the straight line to it really reaches it: nothing solid, his shield included, between.)
		if miss <= radius + along * 0.02 and along < bestAlong and Executive.ray(from, (at - from) * 1.02, ignore or {}) == id then
			best, bestAlong = id, along
		end
	end
	if run.phase == "shield" then
		local b = built
		for id, hp in run.generators do
			local part = b and b.generators[tonumber(string.sub(id, 4)) or 0]
			if hp > 0 and part then
				consider(id, part.CFrame.Position, math.max(part.Size.X, part.Size.Z) / 2 + 1.5)
			end
		end
	else
		local wanted = if run.phase == "detail" then "guard" elseif run.phase == "boss" then "boss" else nil
		for id, a in run.actors do
			if a.kind == wanted and a.hp > 0 and a.root.Parent then
				consider(id, a.root.CFrame.Position, 2.5)
			end
		end
	end
	return best
end

-- A guest fires their sidearm toward `dir` (from their own head, as the server sees it).
function Executive.fire(ctx: Types.Ctx, player: Player, dir: unknown): boolean
	local g = guests[player]
	if not g or g.out or not g.gear.sidearm then
		return false
	end
	if run.phase ~= "shield" and run.phase ~= "detail" and run.phase ~= "boss" then
		return false
	end
	if typeof(dir) ~= "Vector3" then
		return false
	end
	local d = dir :: Vector3
	if d.Magnitude < 0.5 or d.Magnitude > 1.5 or d.X ~= d.X or d.Y ~= d.Y or d.Z ~= d.Z then
		return false
	end
	local now = os.clock()
	if now - g.lastShot < (tonumber(cfg(ctx).fireGap) or 0.3) then
		return false
	end
	local at = ctx.at(player, ID)
	local root = ctx.rootOf(player)
	if not at or not root or not Plan.inOffice(at) then
		return false
	end
	g.lastShot = now
	local from = root.CFrame.Position + Vector3.new(0, 1.5, 0)
	-- (Build 87: a shot passes through every guest, not only the one firing: another guest
	-- stepping in front never swallows it.)
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local range = tonumber(cfg(ctx).range) or 140
	local target = Executive.ray(from, d.Unit * range, ignore)
	if not target then
		-- (Build 87) A near miss on what this phase is about (a generator, a bodyguard, the
		-- Executive) still counts when the shot passes close by with no wall in between: a hand
		-- on a phone, or a target moving, shouldn't make a fair shot miss.
		target = Executive.assist(from, d.Unit, range, ignore)
	end
	broadcast(ctx, { op = "shot", from = from, dir = d.Unit, by = player.UserId, hit = target })
	if target then
		strike(ctx, target, tonumber(cfg(ctx).damage) or 10)
	end
	return target ~= nil
end

---------------------------------------------------------------------------------------------------
-- The hallway
---------------------------------------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- (The rule every screen draws: in range, inside the angle, and no wall between.)
local function seenFrom(eye: Vector3, look: Vector3, range: number, angle: number, at: Vector3, ignore: { Instance }): boolean
	if not Plan.inSight(eye, look, range, angle, at) then
		return false
	end
	return Executive.clear(eye, at, ignore)
end

-- The nearest point on a guard's round to where it is (it walks its round's straight lines).
local function onRound(a: Actor): Vector3
	local points = a.points :: { Vector3 }
	local goal = points[a.index]
	local from = points[(a.index - 2) % #points + 1]
	local p = a.root.CFrame.Position
	local d = flat(goal - from)
	if d.Magnitude < 1e-3 then
		return Vector3.new(goal.X, p.Y, goal.Z)
	end
	local t = math.clamp(flat(p - from):Dot(d) / d:Dot(d), 0, 1)
	local q = from + d * t
	return Vector3.new(q.X, p.Y, q.Z)
end

local function hallStep(ctx: Types.Ctx, dt: number, t: number)
	local c = cfg(ctx)
	-- The guards walk their rounds (along the maze's open lanes: each round is straight lines
	-- with nothing in the way). While a decoy is out they stop where they are and watch it; and
	-- one pushed off its round (a crowd of guests) is put back on it, so it never walks into a wall.
	for _, a in run.hallGuards do
		local points = a.points :: { Vector3 }
		local goal = points[a.index]
		if flat(goal - a.root.CFrame.Position).Magnitude < 2 then
			a.index = a.index % #points + 1
			goal = points[a.index]
		end
		local back = onRound(a)
		if flat(back - a.root.CFrame.Position).Magnitude > 3 then
			-- (The root carries the whole figure with it.)
			a.root.CFrame = a.root.CFrame + (back - a.root.CFrame.Position)
		end
		if t < run.decoyUntil then
			Executive.walk(a, a.root.CFrame.Position, 0)
		else
			Executive.walk(a, goal, tonumber(c.guardSpeed) or 9)
		end
	end
	for player, g in guests do
		local at = ctx.at(player, ID)
		if g.out or not at or not Plan.inHall(at) then
			continue
		end
		local world = origin + at
		local seen: string? = nil
		-- (The lift's lobby is safe: nobody watches anyone there.)
		if t >= run.decoyUntil and not Plan.inLobby(at) then
			local ignore: { Instance } = {}
			if player.Character then
				table.insert(ignore, player.Character)
			end
			for _, cam in Plan.Cameras do
				if seenFrom(origin + cam.at, Plan.cameraLook(cam, t), tonumber(c.cameraRange) or 40, tonumber(c.cameraAngle) or 30, world, ignore) then
					seen = "camera"
				end
			end
			for _, a in run.hallGuards do
				local look = a.root.CFrame.LookVector
				if seenFrom(a.root.CFrame.Position + Vector3.new(0, 1.5, 0), look, tonumber(c.guardRange) or 26, tonumber(c.guardAngle) or 55, world, ignore) then
					seen = "guard"
				end
			end
		end
		local changed = seen ~= g.seen
		g.seen = seen
		if seen and not g.everSeen then
			g.everSeen = true
			changed = true
		end
		local before = g.alert
		if seen then
			local rate = 1 / (tonumber(c.noticeSeconds) or 2.2)
			if g.gear.disguise then
				rate *= tonumber(c.disguise) or 0.6
			end
			g.alert = math.min(1, g.alert + dt * rate)
		else
			g.alert = math.max(0, g.alert - dt * (tonumber(c.alertFade) or 0.1))
		end
		if g.alert >= 1 then
			note(player, "Executive alarm", nil)
			ctx.tally(player, "executiveCaught", 1)
			caught(ctx, player, g, "hall")
		elseif changed or math.abs(g.alert - (g.sentAlert or 0)) > 0.04 or (g.alert == 0 and before > 0) then
			g.sentAlert = g.alert
			push(ctx, player)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The Office
---------------------------------------------------------------------------------------------------
local function playersInOffice(ctx: Types.Ctx): { { player: Player, g: Guest, at: Vector3 } }
	local out = {}
	for player, g in guests do
		local at = ctx.at(player, ID)
		if not g.out and at and Plan.inOffice(at) then
			table.insert(out, { player = player, g = g, at = at })
		end
	end
	return out
end

local function throw(ctx: Types.Ctx, from: Vector3, toward: Vector3, damage: number, t: number)
	run.serial += 1
	local dir = flat(toward - from)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(0, 0, -1)
	end
	local shot: Shot = { id = "s" .. run.serial, from = from, dir = dir.Unit, speed = 42, born = t, radius = 2.6, damage = damage, life = 3 }
	table.insert(run.shots, shot)
	broadcast(ctx, { op = "throw", id = shot.id, from = origin + shot.from, dir = shot.dir, speed = shot.speed, born = shot.born, life = shot.life })
end

local function officeStep(ctx: Types.Ctx, _dt: number, t: number)
	local c = cfg(ctx)
	local here = playersInOffice(ctx)
	if #here == 0 then
		return
	end
	local boss = run.actors.boss
	-- Thrown things: each hits each guest once.
	for k = #run.shots, 1, -1 do
		local s = run.shots[k]
		local age = t - s.born
		if age > s.life then
			table.remove(run.shots, k)
			continue
		end
		local pos = s.from + s.dir * s.speed * age
		for _, h in here do
			if not h.g.hits[s.id] and flat(h.at - pos).Magnitude <= s.radius and h.at.Y < 6 then
				h.g.hits[s.id] = true
				hurt(ctx, h.player, h.g, s.damage, "briefcase")
			end
		end
	end
	-- Shockwaves: jump them (in the air as it passes, it misses).
	for k = #run.waves, 1, -1 do
		local w = run.waves[k]
		local age = t - w.born
		if age > w.life then
			table.remove(run.waves, k)
			continue
		end
		local r = w.speed * age
		for _, h in here do
			local d = flat(h.at - w.at).Magnitude
			if not h.g.hits[w.id] and math.abs(d - r) <= w.width / 2 and h.at.Y < 4.2 then
				h.g.hits[w.id] = true
				hurt(ctx, h.player, h.g, w.damage, "shockwave")
			end
		end
	end
	if run.phase == "shield" and boss then
		if t >= run.nextAttack then
			run.nextAttack = t + 3
			local h = here[rng:NextInteger(1, #here)]
			throw(ctx, Plan.Desk + Vector3.new(0, 3, -4), h.at, tonumber(c.memoDamage) or 8, t)
		end
	elseif run.phase == "detail" then
		for _, a in run.actors do
			if a.kind ~= "guard" or a.hp <= 0 then
				continue
			end
			local pos = a.root.CFrame.Position - origin
			local nearest, best = nil, math.huge
			for _, h in here do
				local d = flat(h.at - pos).Magnitude
				if d < best then
					nearest, best = h, d
				end
			end
			if nearest then
				if best <= 4.5 then
					if t - a.lastHit >= 1.2 then
						a.lastHit = t
						hurt(ctx, nearest.player, nearest.g, tonumber(c.punch) or 12, "bodyguard")
					end
				else
					Executive.walk(a, origin + nearest.at, tonumber(c.bodyguardSpeed) or 14)
				end
			end
		end
	elseif run.phase == "boss" and boss then
		local enraged = boss.hp < boss.max / 2
		-- The finale: at the last of his composure he goes all in (said once, on every screen).
		if not run.finale and boss.hp <= boss.max * (tonumber(c.finaleAt) or 0.3) then
			run.finale = true
			broadcast(ctx, { op = "finale", say = Plan.FINALE_SAY })
			pushAll(ctx)
		end
		local pending = run.pending
		if pending and t >= pending.fireAt then
			run.pending = nil
			if pending.kind == "volley" then
				-- A volley of briefcases, one at each of up to three guests, where they are now.
				for i = 1, math.min(3, #here) do
					throw(ctx, pending.from + Vector3.new(0, 2, 0), here[i].at, tonumber(c.briefcase) or 15, t)
				end
				broadcast(ctx, { op = "attack", kind = "volley" })
			elseif pending.kind == "spin" then
				-- (Build 94) Briefcases flung out all round him, eight (ten in his finale): stand in
				-- the gap between two, or well back where the gaps are wide.
				local turn = rng:NextNumber(0, math.pi * 2)
				local n = if run.finale then 10 else 8
				local from = pending.from + Vector3.new(0, 2, 0)
				for k = 0, n - 1 do
					local a = turn + k * math.pi * 2 / n
					throw(ctx, from, from + Vector3.new(math.cos(a), 0, math.sin(a)) * 10, tonumber(c.briefcase) or 15, t)
				end
				broadcast(ctx, { op = "attack", kind = "spin" })
			elseif pending.kind == "wave" then
				-- (In the finale, a second ring behind the first.)
				for k = 0, if run.finale then 1 else 0 do
					run.serial += 1
					local w: Wave = { id = "w" .. run.serial, at = pending.at or Vector3.zero, born = t + k * 0.6, speed = 26, width = 3, damage = tonumber(c.shockwave) or 20, life = 2.2 + k * 0.6 }
					table.insert(run.waves, w)
					broadcast(ctx, { op = "wave", id = w.id, at = origin + w.at, born = w.born, speed = w.speed, width = w.width, life = w.life })
				end
			else
				-- His dash, down the lane he showed: whoever is still in it is knocked aside.
				local to = pending.to or pending.from
				Executive.walk(boss, origin + to, 40)
				local lane = flat(to - pending.from)
				for _, h in here do
					local rel = flat(h.at - pending.from)
					local along = if lane.Magnitude > 1e-3 then math.clamp(rel:Dot(lane.Unit), 0, lane.Magnitude) else 0
					local off = (rel - (if lane.Magnitude > 1e-3 then lane.Unit * along else Vector3.zero)).Magnitude
					if off <= 3.2 and h.at.Y < 6 then
						hurt(ctx, h.player, h.g, tonumber(c.dash) or 18, "dash")
					end
				end
				broadcast(ctx, { op = "attack", kind = "dash" })
			end
		elseif not pending and t >= run.nextAttack then
			-- The next attack, wound up first where everyone can see it.
			run.attackIndex += 1
			-- (Build 94) At half his composure he adds his spin: briefcases flung out all round.
			local kinds = if enraged then { "volley", "wave", "dash", "spin" } else { "volley", "wave", "dash" }
			local kind = kinds[(run.attackIndex - 1) % #kinds + 1]
			local windup = if run.finale then (tonumber(c.windupFinale) or 0.7) elseif enraged then (tonumber(c.windupEnraged) or 0.85) else (tonumber(c.windup) or 1.1)
			local bpos = boss.root.CFrame.Position - origin
			local next: { kind: string, fireAt: number, from: Vector3, to: Vector3?, at: Vector3? } = { kind = kind, fireAt = t + windup, from = bpos }
			if kind == "wave" then
				next.at = Vector3.new(bpos.X, 0, bpos.Z)
			elseif kind == "dash" then
				local spot = Plan.BossSpots[rng:NextInteger(1, #Plan.BossSpots)]
				if flat(spot - bpos).Magnitude < 4 then
					spot = Plan.BossSpots[(table.find(Plan.BossSpots, spot) or 1) % #Plan.BossSpots + 1]
				end
				next.to = spot
			end
			run.pending = next
			run.nextAttack = t + windup + (if run.finale then (tonumber(c.attackGapFinale) or 1.0) elseif enraged then (tonumber(c.attackGapEnraged) or 1.4) else (tonumber(c.attackGap) or 2.1))
			broadcast(ctx, { op = "windup", kind = kind, seconds = windup, from = origin + bpos, at = if next.at then origin + next.at else nil, to = if next.to then origin + next.to else nil, line = Plan.Windups[kind], finale = run.finale })
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The attraction
---------------------------------------------------------------------------------------------------
function Executive.build(ctx: Types.Ctx, parent: Instance)
	suite = ctx
	origin = AttractionList.origin(ID)
	built = ExecutiveBuild.build(parent, origin, function(player: Player)
		if ctx.inside(player) == ID then
			ctx.sendHome(player, ID)
		end
	end)
	local b = built :: ExecutiveBuild.Built
	sightWalls = b.sight
	-- (How far and how wide the guards and cameras see, for every screen's drawing of it.)
	local c = cfg(ctx)
	b.root:SetAttribute("GuardRange", tonumber(c.guardRange) or 26)
	b.root:SetAttribute("GuardAngle", tonumber(c.guardAngle) or 55)
	b.root:SetAttribute("CameraRange", tonumber(c.cameraRange) or 40)
	b.root:SetAttribute("CameraAngle", tonumber(c.cameraAngle) or 30)
	-- (Every press is answered: what it did, or why not. A refusal said nowhere looked like a
	-- broken E.)
	local function answered(player: Player, title: string, r: any)
		if type(r) == "table" and r.ok ~= true and type(r.why) == "string" then
			ctx.send(player, { op = "notice", title = title, line = r.why })
		end
	end
	for i, p in b.terminals do
		p.Triggered:Connect(function(player: Player)
			answered(player, "Terminal " .. i, Executive.ask(ctx, player, { act = "terminal", n = i }))
		end)
	end
	b.keypad.Triggered:Connect(function(player: Player)
		if guests[player] and not run.open then
			ctx.send(player, { op = "keypad" })
		end
	end)
	b.safe.Triggered:Connect(function(player: Player)
		answered(player, "The safe", Executive.ask(ctx, player, { act = "safe" }))
	end)
	for id, pr in b.loot do
		pr.Triggered:Connect(function(player: Player)
			answered(player, Plan.lootById[id].name, Executive.ask(ctx, player, { act = "loot", what = id }))
		end)
	end
	b.liftDown.Triggered:Connect(function(player: Player)
		Executive.extract(ctx, player)
	end)
	-- The sidearm: a guest's screen sends where they aimed; the server decides what was hit.
	RemoteGuard.event(Remotes.event("AttractionFire"), "attractionFire", function(player: Player, dir: unknown)
		Executive.fire(ctx, player, dir)
	end)
	fresh(ctx)
end

-- The lift down after he's beaten: home, and within the extraction's minute a clean getaway's bonus
-- (once a run, for a guest who was in the fight).
function Executive.extract(ctx: Types.Ctx, player: Player): boolean
	if ctx.inside(player) ~= ID or run.phase ~= "won" then
		return false
	end
	local g = guests[player]
	if g and g.paid and not g.extracted and Executive.clock() <= run.extractUntil then
		g.extracted = true
		local gilt = ctx.gilt(player, tonumber(cfg(ctx).extractGilt) or 2500, "The Executive Suite: a clean getaway")
		ctx.send(player, { op = "extracted", gilt = gilt })
		note(player, "Executive extracted", nil)
		ctx.tally(player, "executiveExtractions", 1)
	end
	ctx.sendHome(player, ID)
	return true
end

function Executive.enter(ctx: Types.Ctx, player: Player): (CFrame?, string?)
	local data = ctx.data(player)
	if not data then
		return nil, "Your ledger is still being opened."
	end
	local p = page(ctx, data)
	if not p.sidearm then
		return nil, "First take your free stun pistol from the Quartermaster, at his desk in this room."
	end
	if p.invites <= 0 then
		local c = cfg(ctx)
		return nil, string.format("You need an invitation to go up. Finish the Maison Basement, carry %s of loot out of Steal a Luxe in one trip, or buy one from the Quartermaster here for %s Gilt.", Fortune.format(tonumber(c.inviteHaul) or 8000), Fortune.format(tonumber(c.invitePrice) or 25000))
	end
	if run.phase == "won" then
		return nil, "The Executive has just been beaten: the Suite opens again in a moment."
	end
	p.invites -= 1
	local gear: { [string]: boolean } = { sidearm = true }
	for id, on in p.kit do
		if on == true and Plan.byGear[id] then
			gear[id] = true
		end
	end
	p.kit = {}
	local max = if gear.vest then 150 else 100
	guests[player] = { alert = 0, composure = max, max = max, gear = gear, decoyUsed = false, digits = {}, tries = 0, lastShot = -math.huge, paid = false, safe = false, hits = {}, out = false }
	task.defer(function()
		if guests[player] then
			push(ctx, player)
		end
	end)
	ctx.tally(player, "executiveVisits", 1)
	note(player, "Executive entered", { invites = p.invites })
	Executive.carriedChanged(player)
	return CFrame.new(Plan.Arrival), nil
end

function Executive.leave(ctx: Types.Ctx, player: Player, why: string)
	local was = guests[player] ~= nil
	if was then
		still(ctx, player, guests[player], false)
	end
	if was then
		note(player, "Executive left", { phase = run.phase, why = why })
	end
	guests[player] = nil
	if was then
		Executive.carriedChanged(player)
	end
	-- The Suite empty: a new run for whoever comes up next.
	if next(guests) == nil then
		fresh(ctx)
	end
end

-- What the guest carries from here, for their inventory (server/Satchel): the sidearm once it's
-- taken, and a decoy while one is packed or carried in this run and not yet thrown.
function Executive.carried(ctx: Types.Ctx, player: Player): { sidearm: boolean, decoy: boolean }
	local data = ctx.data(player)
	if not data then
		return { sidearm = false, decoy = false }
	end
	local p = page(ctx, data)
	local g = guests[player]
	local decoy = p.kit.decoy == true or (g ~= nil and g.gear.decoy == true and not g.decoyUsed)
	return { sidearm = p.sidearm == true, decoy = decoy }
end
-- Told whenever that changes (set at boot: the Satchel repacks).
Executive.carriedChanged = function(_player: Player) end

function Executive.step(ctx: Types.Ctx, dt: number)
	if not built then
		return
	end
	local t = Executive.clock()
	-- A revive's moment over (or the Executive beaten meanwhile): security shows them out.
	local over: { Player } = {}
	for player, g in guests do
		local r = g.revive
		if r and (t >= r.deadline or run.phase == "won") then
			g.revive = nil
			table.insert(over, player)
		end
	end
	for _, player in over do
		ctx.send(player, { op = "caughtEnd" })
		ctx.sendHome(player, ID)
	end
	hallStep(ctx, dt, t)
	-- (Build 94) The beaten Executive's exit: at the door (or out of time), he's gone through it.
	local ex = run.exit
	if ex then
		local a = ex.actor
		local there = a.root.Parent ~= nil and flat(a.root.CFrame.Position - ex.door).Magnitude <= 3
		if t >= ex.goneAt or there or a.model.Parent == nil then
			run.exit = nil
			local at = if a.root.Parent then a.root.CFrame.Position else ex.door
			if a.model.Parent then
				a.model:Destroy()
			end
			if run.actors.boss == a then
				(run.actors :: any).boss = nil
			end
			broadcast(ctx, { op = "bossGone", at = at, door = ex.door })
		end
	end
	-- Into the Office through the open door: the Executive is waiting.
	if run.phase == "hall" and run.open and #playersInOffice(ctx) > 0 then
		startPhase(ctx, "shield")
	end
	if run.phase ~= "hall" and run.phase ~= "won" then
		officeStep(ctx, dt, t)
	end
end

-- The Quartermaster and the Suite's own requests.
function Executive.state(ctx: Types.Ctx, player: Player): { [string]: any }
	local data = ctx.data(player)
	if not data then
		return {}
	end
	local p = page(ctx, data)
	local c = cfg(ctx)
	local gear = {}
	for _, g in Plan.Gear do
		table.insert(gear, { id = g.id, name = g.name, line = g.line, price = g.price, glyph = g.glyph, free = g.free == true, packed = if g.id == "sidearm" then p.sidearm else p.kit[g.id] == true })
	end
	local out: { [string]: any } = {
		invites = p.invites,
		most = tonumber(c.maxInvites) or 5,
		invitePrice = tonumber(c.invitePrice) or 25000,
		inviteHaul = tonumber(c.inviteHaul) or 8000,
		sidearm = p.sidearm,
		gear = gear,
		wins = p.wins,
	}
	if guests[player] then
		out.run = status(ctx, player)
	end
	return out
end

function Executive.ask(ctx: Types.Ctx, player: Player, r: { [string]: unknown }): any
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local p = page(ctx, data)
	local c = cfg(ctx)
	local act = r.act
	if act == "sidearm" then
		p.sidearm = true
		Executive.carriedChanged(player)
		return { ok = true, state = Executive.state(ctx, player) }
	elseif act == "gear" then
		local id = r.what
		local g = if type(id) == "string" then Plan.byGear[id] else nil
		if not g or g.free then
			return { ok = false, why = "There's no such gear." }
		end
		if p.kit[g.id] then
			return { ok = false, why = "That's already packed for your next run." }
		end
		if not ctx.spend(player, g.price, 0, "executive_" .. g.id) then
			return { ok = false, short = "Gilt", why = string.format("That's %s Gilt.", Fortune.format(g.price)) }
		end
		p.kit[g.id] = true
		Executive.carriedChanged(player)
		return { ok = true, state = Executive.state(ctx, player) }
	elseif act == "invite" then
		local most = tonumber(c.maxInvites) or 5
		if p.invites >= most then
			return { ok = false, why = string.format("You hold %d invitations: the most there is.", most) }
		end
		local price = tonumber(c.invitePrice) or 25000
		if not ctx.spend(player, price, 0, "executive_invite") then
			return { ok = false, short = "Gilt", why = string.format("An invitation is %s Gilt.", Fortune.format(price)) }
		end
		p.invites += 1
		return { ok = true, state = Executive.state(ctx, player) }
	end
	-- In the Suite.
	local g = guests[player]
	if act == "revive" or act == "leaveCaught" then
		local moment = g and g.revive
		if not g or not moment or ctx.inside(player) ~= ID then
			return { ok = false, why = "There's no revive to take just now." }
		end
		if act == "leaveCaught" then
			g.revive = nil
			ctx.sendHome(player, ID)
			return { ok = true }
		end
		if moment.prompting then
			return { ok = false, why = "The purchase window is already open." }
		end
		if Executive.revives.held(player) > 0 then
			if revive(ctx, player) then
				return { ok = true }
			end
			return { ok = false, why = "That revive couldn't be used just now. Try again." }
		end
		local opened, why = Executive.revives.offer(player, "executive")
		if g.revive ~= moment then
			return { ok = false, why = "The moment passed: a revive bought now is kept for your next run." }
		end
		if not opened then
			return { ok = false, why = why or "Not just now." }
		end
		-- The countdown waits while Roblox's window is open (up to promptWait).
		moment.left = math.max(3, moment.deadline - Executive.clock())
		moment.prompting = true
		moment.deadline = Executive.clock() + Executive.REVIVE.promptWait
		ctx.send(player, reviveMessage(player, g, "caughtUpdate"))
		return { ok = true, prompting = true }
	end
	if g and g.out then
		return { ok = false, why = "You were caught: security is showing you out." }
	end
	if not g or ctx.inside(player) ~= ID then
		return { ok = false, why = "You're not in the Executive Suite." }
	end
	local at = ctx.at(player, ID)
	if act == "terminal" then
		local n = tonumber(r.n)
		local spot = n and Plan.Terminals[n]
		if not spot or not at then
			return { ok = false, why = "Not that." }
		end
		-- (Measured from the terminal's screen, as its prompt is: a little past the prompt's own
		-- reach, so whoever the prompt answers is never refused for distance.)
		local screen = spot + Vector3.new(if spot.X < 0 then 1.4 else -1.4, 0, 0)
		if (flat(at - screen)).Magnitude > 13 then
			return { ok = false, why = "Get closer to the terminal." }
		end
		-- (Never through a wall of the maze: from its own side, in front of it.)
		if not Executive.clear(origin + Vector3.new(at.X, 3, at.Z), origin + screen + Vector3.new(0, 4.1, 0), {}) then
			return { ok = false, why = "Get closer to the terminal: it's on the other side of the wall." }
		end
		g.digits[n :: number] = true
		ctx.send(player, { op = "digit", n = n, digit = string.sub(run.code, n :: number, n :: number) })
		push(ctx, player)
		return { ok = true }
	elseif act == "code" then
		if run.open then
			return { ok = true }
		end
		if not at or flat(at - Vector3.new(0, 0, Plan.Door.z)).Magnitude > 12 then
			return { ok = false, why = "Enter it at the keypad by the door." }
		end
		local code = r.code
		if type(code) ~= "string" or #code ~= 4 or not string.match(code, "^%d%d%d%d$") then
			return { ok = false, why = "Four digits." }
		end
		if code ~= run.code then
			g.tries += 1
			g.wrongs = (g.wrongs or 0) + 1
			if g.tries >= 3 then
				g.tries = 0
				g.alert = math.min(0.99, g.alert + 0.5)
				push(ctx, player)
				return { ok = false, why = "Wrong, and the alarm is close: careful." }
			end
			return { ok = false, why = "That's not the code." }
		end
		run.open = true
		run.openedAt = Executive.clock()
		local b = built :: ExecutiveBuild.Built
		ExecutiveBuild.door(b, false)
		broadcast(ctx, { op = "doorOpen" })
		pushAll(ctx)
		return { ok = true }
	elseif act == "decoy" then
		if not g.gear.decoy or g.decoyUsed then
			return { ok = false, why = "You've no decoy left." }
		end
		if not at or not Plan.inHall(at) then
			return { ok = false, why = "A decoy works in the hallway." }
		end
		g.decoyUsed = true
		Executive.carriedChanged(player)
		run.decoyUntil = Executive.clock() + (tonumber(c.decoySeconds) or 8)
		run.decoyAt = origin + at
		broadcast(ctx, { op = "decoy", at = origin + at, seconds = tonumber(c.decoySeconds) or 8 })
		push(ctx, player)
		return { ok = true }
	elseif act == "safe" then
		if run.phase ~= "won" then
			return { ok = false, why = "Not while the Executive is watching." }
		end
		if g.safe then
			return { ok = false, why = "You've had your share of the safe." }
		end
		if not at or flat(at - Plan.Safe).Magnitude > 10 then
			return { ok = false, why = "Get closer to it." }
		end
		g.safe = true
		local worth = tonumber(c.safe) or 10000
		ctx.estate(player, worth, "The Executive Suite")
		ctx.send(player, { op = "safe", worth = worth })
		return { ok = true, worth = worth }
	elseif act == "loot" then
		-- (Build 94) The rest of the Office, raided: once each a guest a run, close enough to it,
		-- and only once he's gone. What it pays is the house's figure.
		local spot = Plan.lootById[tostring(r.what)]
		if not spot then
			return { ok = false, why = "That isn't something the house does." }
		end
		if run.phase ~= "won" then
			return { ok = false, why = "Not while the Executive is watching." }
		end
		local looted = g.looted or {}
		g.looted = looted
		if looted[spot.id] then
			return { ok = false, why = "You've already been through that." }
		end
		if not at or flat(at - spot.at).Magnitude > 10 then
			return { ok = false, why = "Get closer to it." }
		end
		looted[spot.id] = true
		local table_ = (c.loot or {})[spot.id] or {}
		local worth = math.max(0, math.floor(tonumber(table_.estate) or 0))
		local giltWant = math.max(0, math.floor(tonumber(table_.gilt) or 0))
		if worth > 0 then
			ctx.estate(player, worth, "The Executive Suite")
		end
		local gilt = if giltWant > 0 then ctx.prize(player, giltWant, "The Executive Suite: " .. spot.name) else 0
		ctx.send(player, { op = "loot", loot = spot.id, name = spot.name, worth = worth, gilt = gilt })
		return { ok = true, worth = worth, gilt = gilt }
	end
	return { ok = false, why = "That isn't something the house does." }
end

-- Its card in the Maison Directory: open while the guest holds an invitation (one is spent going
-- up); how many they hold, whether they have their sidearm, and the figures for how to earn one.
function Executive.directory(ctx: Types.Ctx, player: Player): { [string]: any }
	local c = cfg(ctx)
	local out: { [string]: any } = {
		open = false,
		inviteHaul = tonumber(c.inviteHaul) or 8000,
		invitePrice = tonumber(c.invitePrice) or 25000,
		most = tonumber(c.maxInvites) or 5,
	}
	local data = ctx.data(player)
	if data then
		local p = page(ctx, data)
		out.invites = p.invites
		out.open = p.invites > 0
		out.sidearm = p.sidearm == true
		out.wins = p.wins
	end
	return out
end

-- An invitation, earned (the Basement, a great haul) or given (the owner). Returns whether it fit.
function Executive.invite(ctx: Types.Ctx, player: Player, why: string): boolean
	local data = ctx.data(player)
	if not data then
		return false
	end
	local p = page(ctx, data)
	local most = tonumber(cfg(ctx).maxInvites) or 5
	if p.invites >= most then
		return false
	end
	p.invites += 1
	ctx.send(player, { op = "invited", why = why, invites = p.invites })
	return true
end

-- For tests.
Executive.guests = guests
Executive.run = run
Executive.page = page
Executive.origin = function(): Vector3
	return origin
end
Executive.built = function(): ExecutiveBuild.Built?
	return built
end
Executive.fresh = fresh

return Executive
