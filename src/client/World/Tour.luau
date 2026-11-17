--!strict
-- The Concierge's tour, on the guest's own screen. The Concierge walks them round the whole
-- house: the Salon, Tonight's board, the Vault, the Boutique, then up the Grand Stair to the
-- Library, the Ballroom, the Terrace and their Suite. At each stop the Concierge turns and
-- explains it on a card, with a gold pin over the thing they mean; between stops a gold line
-- from the guest shows the way.
--
-- The guide is the guest's own: a copy of the Concierge drawn only on their screen (the house's
-- Concierge is hidden from them meanwhile, and stays at the lectern for everyone else), so any
-- number of guests can take the tour at once and nobody waits. It walks a fixed route at an easy
-- pace (Layout.Tour), waits when the guest falls behind, and passes through nothing solid, so it
-- never gets stuck.
--
-- Build 87, never stuck: a guest who hangs back is fetched (he walks back the way he came, never
-- through a wall, until they're close, then on again); at a stop the card shows once the guest is
-- near the stop or near him, or after a few seconds whatever (its pin shows what's meant); and the
-- way line always has a key to skip on to the stop. A gold trail on the floor runs from him to the
-- next stop (World/GoldTrail). When the tour ends, however it ends, he walks back to the lectern the
-- way he came (quickly, and never longer than Config.Tour.homeWithin seconds) and only then is the
-- house's Concierge back in his place on this screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Dialogue = require(script.Parent.Parent.UI.Dialogue)
local Toast = require(script.Parent.Parent.UI.Toast)
local GoldTrail = require(script.Parent.GoldTrail)
local Waypoint = require(script.Parent.Waypoint)

local Tour = {}

-- Set by Main: a tour has ended (the guest has been shown the house).
Tour.ended = function() end

-- Set by Main: sit the guest at a Salon table (the last card's "Take me to a table"), and
-- whether they're at a table now (the tour steps aside).
Tour.toTable = function() end
-- Set by Main: the Maison Directory, every attraction (the last card's "Show me the attractions").
Tour.toDirectory = function() end
Tour.isSeated = function(): boolean
	return false
end
-- Set by Main: the screen is clear for the tour to begin (no title, intro or welcome on it).
Tour.isClear = function(): boolean
	return true
end

type Card = { stop: string, title: string, line: string, place: string?, hand: string? }

-- Set by Main (Build 87): the guiding hand pointed at something on the screen for a card (`what`:
-- "collection"), or put away (nil).
Tour.pointAt = function(_what: string?) end

local player = Players.LocalPlayer
local V = Voice.Concierge
local stops = Layout.Tour.stops
local cards = Voice.Tour :: { Card }

local active = false
local state = "walking" -- "walking" | "arriving" | "card"
local stopIndex = 1
local cardIndex = 1
local path: { Vector3 } = {}
local pathIndex = 1
local pos = Vector3.zero -- where the guide's feet are
local feetY = 0
local facing = Vector3.new(0, 0, 1)
local paused = false
local lostFor = 0
local guide: Model? = nil
local guideRoot: BasePart? = nil
local hipHeight = 3
local walkTrack: AnimationTrack? = nil
local idleTrack: AnimationTrack? = nil
-- The guide's joints, for a walk drawn by hand when the walk animation can't load, and the gait's
-- own sway either way.
local gaitJoints: { [string]: { motor: Motor6D, base: CFrame } } = {}
local gaitPhase = 0
local gaitAmount = 0 -- 0 standing, 1 in full stride (eased)
local gaitAnimated = false -- the walk animation is playing (it has its own rise and fall)
local hidden: { { inst: Instance, prop: string, value: any } } = {}
local connection: RBXScriptConnection? = nil
local rayParams: RaycastParams? = nil
local rayRefresh = 0
-- (Build 87) The way he's come (each corner of the route he's passed, from the lectern on), for
-- fetching a guest who hangs back and for the walk home; how long he's waited for them, or stood
-- at a stop; where home is; and the walk home after the tour (its own frame loop).
local crumbs: { Vector3 } = {}
local fetching = false
local waitedFor = 0
local arrivedFor = 0
local home = Vector3.zero
local trailRefresh = 0
local holdFor = 0 -- after fetching a guest: a moment beside them before walking on
local holdFrom = Vector3.zero
local returning: RBXScriptConnection? = nil

local function guestRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function stopIndexOf(id: string): number
	for i, s in stops do
		if s.id == id then
			return i
		end
	end
	return 1
end

function Tour.active(): boolean
	return active
end

-- Where the tour is (for tests): the stop, the card, and what the guide is doing.
function Tour.where(): (string, number, string, Vector3)
	return stops[stopIndex].id, cardIndex, state, pos
end

Dialogue.isBusy = function(): boolean
	return active
end

---------------------------------------------------------------------------------------------------
-- The guide
---------------------------------------------------------------------------------------------------

-- The house's Concierge, found by the attribute every staff rig carries.
local function findConcierge(): Model?
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Staff") == "Concierge" then
			return d
		end
	end
	return nil
end

-- Hidden on this screen only (everyone else still sees the Concierge at the lectern).
local function hide(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			local ok, was = pcall(function()
				return (d :: any).LocalTransparencyModifier
			end)
			table.insert(hidden, { inst = d :: Instance, prop = "LocalTransparencyModifier", value = if ok then was else 0 })
			;(d :: any).LocalTransparencyModifier = 1
		elseif d:IsA("ProximityPrompt") then
			table.insert(hidden, { inst = d :: Instance, prop = "Enabled", value = d.Enabled :: any })
			d.Enabled = false
		end
	end
end

local function unhide()
	for _, h in hidden do
		pcall(function()
			(h.inst :: any)[h.prop] = h.value
		end)
	end
	hidden = {}
end

-- A copy of the Concierge for this guest's tour: nothing on it collides, nothing can be pressed,
-- and it moves by being placed, so nothing can stop it.
local function buildGuide(from: Model): Model?
	local ok, copy = pcall(function()
		return from:Clone()
	end)
	if not ok or not copy then
		return nil
	end
	local m = copy :: Model
	m.Name = "MaisonTourGuide"
	m:SetAttribute("Staff", "TourGuide")
	for _, d in m:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("BaseScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = d.Name == "HumanoidRootPart"
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		end
	end
	local root = m:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		m:Destroy()
		return nil
	end
	guideRoot = root
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	hipHeight = root.Size.Y / 2 + 2
	walkTrack, idleTrack = nil, nil
	-- (Into the world first: Roblox only loads animations onto a rig that's in the world. Loaded
	-- before, they failed, and the guide glided along in its standing pose.)
	m.Parent = Workspace
	gaitJoints = {}
	for _, name in { "LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "Waist", "Neck" } do
		local joint = m:FindFirstChild(name, true)
		if joint and joint:IsA("Motor6D") then
			gaitJoints[name] = { motor = joint, base = joint.C0 }
		end
	end
	if humanoid then
		pcall(function()
			humanoid.EvaluateStateMachine = false
		end)
		hipHeight = humanoid.HipHeight + root.Size.Y / 2
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			local a = Instance.new("Animator")
			a.Parent = humanoid
			animator = a
		end
		local anims = Config.data.Assets.Animations
		local function load(id: string, priority: Enum.AnimationPriority): AnimationTrack?
			if id == "" then
				return nil
			end
			local okLoad, track = pcall(function()
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				return (animator :: Animator):LoadAnimation(anim)
			end)
			if okLoad and track then
				track.Priority = priority
				track.Looped = true
				return track
			end
			return nil
		end
		idleTrack = load(anims.idle, Enum.AnimationPriority.Idle)
		walkTrack = load(anims.walk, Enum.AnimationPriority.Movement)
		if idleTrack then
			idleTrack:Play(0.2)
		end
	end
	return m
end

local function removeGuide()
	local m = guide
	guide = nil
	guideRoot = nil
	walkTrack, idleTrack = nil, nil
	if not m then
		return
	end
	-- A quick fade, then gone.
	for i = 1, 4 do
		task.delay(0.08 * i, function()
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					(d :: any).LocalTransparencyModifier = i / 4
				end
			end
			if i == 4 then
				m:Destroy()
			end
		end)
	end
end

-- The guide's pace just now (studs a second): never slower than the guest's own walk, quicker
-- when the guest is ahead of him, so he keeps in step with whoever he's showing round.
local pace = 0

local function walking(on: boolean)
	local walk, idle = walkTrack, idleTrack
	if walk then
		if on and not walk.IsPlaying then
			walk:Play(0.2)
			walk:AdjustSpeed(math.clamp((if pace > 0 then pace else Config.data.Tour.speed) / 16, 0.6, 2))
		elseif on then
			-- (The legs keep time with the pace as it changes.)
			walk:AdjustSpeed(math.clamp((if pace > 0 then pace else Config.data.Tour.speed) / 16, 0.6, 2))
		elseif not on and walk.IsPlaying then
			walk:Stop(0.25)
		end
	end
	if idle then
		if not on and not idle.IsPlaying then
			idle:Play(0.3)
		elseif on and idle.IsPlaying then
			idle:Stop(0.2)
		end
	end
end

-- The floor under the guide's feet (each step of the stair), or the route's own height.
local function floorAt(p: Vector3): number
	local params = rayParams
	if not params then
		return p.Y
	end
	local ok, hit = pcall(function()
		return Workspace:Raycast(p + Vector3.new(0, 2.6, 0), Vector3.new(0, -6, 0), params)
	end)
	if ok and hit and math.abs(hit.Position.Y - p.Y) < 2.5 then
		return hit.Position.Y
	end
	return p.Y
end

local function refreshRays()
	local params = rayParams
	if not params then
		return
	end
	-- Only the house's floors: never a guest, a member of staff or the guide itself.
	local skip: { Instance } = {}
	if guide then
		table.insert(skip, guide)
	end
	local maison = Workspace:FindFirstChild("Maison")
	local staff = maison and maison:FindFirstChild("Staff")
	if staff then
		table.insert(skip, staff)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	pcall(function()
		params.FilterDescendantsInstances = skip
	end)
end

-- The gait: a walker's rise and fall and a little sway from foot to foot, eased in as the guide
-- sets off and out as they stop; and, if the walk animation didn't load, the legs and arms swung
-- by hand so the guide never glides.
local function gait(dt: number, moving: boolean)
	gaitAmount += ((if moving then 1 else 0) - gaitAmount) * (1 - math.exp(-6 * dt))
	-- Two steps a stride; a stride of about two and a half studs.
	gaitPhase = (gaitPhase + dt * (if moving then (if pace > 0 then pace else Config.data.Tour.speed) / 2.6 else 0) * math.pi) % (math.pi * 2)
	local animated = walkTrack ~= nil and (walkTrack :: AnimationTrack).IsPlaying
	gaitAnimated = animated
	if animated then
		return
	end
	local a = gaitAmount
	local swing = math.sin(gaitPhase)
	local function pose(name: string, rx: number, ry: number, rz: number)
		local j = gaitJoints[name]
		if j and j.motor.Parent then
			j.motor.C0 = j.base * CFrame.Angles(rx * a, ry * a, rz * a)
		end
	end
	pose("LeftHip", math.rad(28) * swing, 0, 0)
	pose("RightHip", -math.rad(28) * swing, 0, 0)
	pose("LeftKnee", -math.rad(22) * math.max(0, -swing), 0, 0)
	pose("RightKnee", -math.rad(22) * math.max(0, swing), 0, 0)
	pose("LeftShoulder", -math.rad(20) * swing, 0, 0)
	pose("RightShoulder", math.rad(20) * swing, 0, 0)
	pose("LeftElbow", math.rad(12), 0, 0)
	pose("RightElbow", math.rad(12), 0, 0)
	pose("Waist", 0, math.rad(6) * swing, 0)
end

local function place(dt: number)
	local root = guideRoot
	feetY += (floorAt(pos) - feetY) * (1 - math.exp(-14 * dt))
	if not root then
		return
	end
	-- The rise and fall of each step, and a sway from foot to foot (a breath while standing).
	local a = gaitAmount * (if gaitAnimated then 0.35 else 1)
	local bob = math.abs(math.sin(gaitPhase)) * 0.12 * a + math.sin(os.clock() * 1.6) * 0.02 * (1 - gaitAmount)
	local sway = math.sin(gaitPhase) * 0.07 * a
	local at = Vector3.new(pos.X, feetY + hipHeight + bob, pos.Z)
	local side = facing:Cross(Vector3.new(0, 1, 0))
	root.CFrame = CFrame.lookAt(at + side * sway, at + side * sway + facing) * CFrame.Angles(0, 0, math.rad(2.2) * math.sin(gaitPhase) * a)
end

local function turnTo(dir: Vector3, dt: number)
	local f = flat(dir)
	if f.Magnitude < 0.05 then
		return
	end
	local blended = facing:Lerp(f.Unit, 1 - math.exp(-9 * dt))
	if blended.Magnitude > 0.01 then
		facing = blended.Unit
	end
end

---------------------------------------------------------------------------------------------------
-- The cards
---------------------------------------------------------------------------------------------------

local showCard: (i: number) -> ()

-- While walking: where we're going, with the pin on ahead at the next stop (and the line of
-- light from the guest to it), and a key to end the tour on the way.
local skipAhead: () -> ()

local function wayLine(line: string, stop: Layout.TourStop)
	Dialogue.show(V.speaker, line, { { id = "skip", text = Voice.TourKeys.skip }, { id = "done", text = Voice.TourKeys.done } }, function(id: string)
		if id == "skip" then
			skipAhead()
		else
			Tour.stop("done")
		end
	end, nil, { point = stop.stand, pointName = stop.name, sticky = true })
end

local function walkTo(index: number)
	local stop = stops[index]
	stopIndex = index
	path = table.clone(stop.via)
	table.insert(path, stop.stand)
	pathIndex = 1
	paused = false
	fetching = false
	waitedFor, arrivedFor, holdFor = 0, 0, 0
	state = "walking"
	pcall(Tour.pointAt, nil)
	wayLine((Voice.TourWalk :: any)[stop.id] or "This way.", stop)
end

local function choose(i: number, id: string)
	if not active then
		return
	end
	if id == "next" then
		local nextCard = cards[i + 1]
		if not nextCard then
			Tour.stop("done")
		elseif nextCard.stop == cards[i].stop then
			showCard(i + 1)
		else
			cardIndex = i + 1
			walkTo(stopIndexOf(nextCard.stop))
		end
	elseif id == "back" then
		showCard(math.max(1, i - 1))
	elseif id == "attractions" then
		Tour.stop("attractions")
	elseif id == "table" then
		Tour.stop("table")
	else
		Tour.stop("done")
	end
end

showCard = function(i: number)
	cardIndex = i
	state = "card"
	GoldTrail.clear()
	local card = cards[i]
	local K = Voice.TourKeys
	local choices: { Dialogue.Choice }
	if i == #cards then
		choices = { { id = "attractions", text = K.attractions }, { id = "explore", text = K.explore } }
	else
		choices = { { id = "next", text = K.next } }
		if i > 1 then
			table.insert(choices, { id = "back", text = K.back })
		end
		table.insert(choices, { id = "done", text = K.done })
	end
	local point = if card.place then Layout.Tour.points[card.place] else nil
	pcall(Tour.pointAt, card.hand)
	Dialogue.show(V.speaker, card.line, choices, function(id: string)
		choose(i, id)
	end, nil, {
		title = card.title,
		step = string.format("%d of %d", i, #cards),
		point = point,
		pointName = if point and card.place then (Voice.TourPlaces :: any)[card.place] else nil,
		sticky = true,
	})
end

-- On to the stop at once (the way line's Skip key): he's there, the corners on the way are
-- passed, and the card shows wherever the guest is (its pin shows what's meant).
skipAhead = function()
	if not active or state == "card" then
		return
	end
	for k = pathIndex, #path do
		table.insert(crumbs, path[k])
	end
	pathIndex = #path + 1
	local stop = stops[stopIndex]
	pos = stop.stand
	feetY = stop.stand.Y
	walking(false)
	fetching, paused = false, false
	showCard(cardIndex)
end

-- The gold trail on the floor: from him along the rest of the way to the stop.
local function layTrail()
	if state == "card" then
		GoldTrail.clear()
		return
	end
	local points = { pos }
	for k = pathIndex, #path do
		table.insert(points, path[k])
	end
	if #points < 2 then
		GoldTrail.clear()
		return
	end
	GoldTrail.set(points, floorAt)
end

---------------------------------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------------------------------

local function step(dt: number)
	if not active then
		return
	end
	local T = Config.data.Tour
	local root = guestRoot()
	if Tour.isSeated() then
		Tour.stop("seated")
		return
	end
	rayRefresh -= dt
	if rayRefresh <= 0 then
		rayRefresh = 1
		refreshRays()
	end
	local guest = if root then root.Position else nil
	local feet = Vector3.new(pos.X, feetY, pos.Z)
	-- A guest who wanders far off (or whose character is gone) has left the tour.
	local apart = if guest then (guest - feet).Magnitude else math.huge
	if apart > T.lostBeyond then
		lostFor += dt
		if lostFor > (if guest then T.lostAfter else 3) then
			Tour.stop("lost")
			return
		end
	else
		lostFor = 0
	end
	local stop = stops[stopIndex]
	trailRefresh -= dt
	if trailRefresh <= 0 then
		trailRefresh = 0.25
		layTrail()
	end
	if state == "walking" then
		local behind = false
		if guest then
			if paused or fetching then
				behind = apart > T.resumeWithin
			else
				-- Behind, not ahead: further from where we're going than the Concierge is.
				behind = apart > T.waitBeyond and (guest - stop.stand).Magnitude > (pos - stop.stand).Magnitude
			end
		end
		local wasFetching = fetching
		waitedFor = if behind then waitedFor + dt else 0
		-- (He waits a moment; then, if they're still hanging back, he goes back for them the way
		-- he came, as long as that brings him nearer to them.)
		fetching = false
		if behind and guest and waitedFor > T.fetchAfter and #crumbs > 0 then
			-- (Only while the corner behind him is nearer to them than he is.)
			fetching = (flat(guest - crumbs[#crumbs])).Magnitude < (flat(guest - pos)).Magnitude
		end
		paused = behind and not fetching
		if wasFetching and not fetching and not behind and guest then
			-- (He's with them again: a moment beside them, on again as soon as they move.)
			holdFor, holdFrom = T.holdAfterFetch, guest
		end
		if holdFor > 0 and guest then
			holdFor -= dt
			if (flat(guest - holdFrom)).Magnitude > 4 then
				holdFor = 0
			end
		end
		if holdFor > 0 and guest and not behind then
			walking(false)
			gait(dt, false)
			turnTo(guest - feet, dt)
		elseif fetching and guest then
			pace = math.max(T.speed, pace)
			walking(true)
			gait(dt, true)
			local left = pace * dt
			while left > 0 and #crumbs > 0 do
				local target = crumbs[#crumbs]
				local d = target - pos
				local dist = d.Magnitude
				turnTo(d, dt)
				if dist <= left then
					pos = target
					left -= dist
					-- (Back past this corner: the way on goes through it again.)
					table.remove(crumbs)
					table.insert(path, pathIndex, target)
					if #crumbs == 0 or (flat(guest - crumbs[#crumbs])).Magnitude >= (flat(guest - pos)).Magnitude then
						left = 0
					end
				else
					pos += d / dist * left
					left = 0
				end
			end
		elseif paused and guest then
			walking(false)
			gait(dt, false)
			turnTo(guest - feet, dt)
		else
			-- His pace: the house's own, or the guest's walk if that's quicker; and a little
			-- quicker again while the guest is ahead of him, eased so he never jerks.
			local want = T.speed
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local theirs = if humanoid then humanoid.WalkSpeed else 0
			want = math.max(want, theirs * 0.95)
			if guest and (guest - stop.stand).Magnitude < (pos - stop.stand).Magnitude - 4 then
				want = math.max(want, theirs * 1.15)
			end
			want = math.min(want, 48)
			pace = if pace <= 0 then want else pace + (want - pace) * (1 - math.exp(-4 * dt))
			walking(true)
			gait(dt, true)
			local left = pace * dt
			while left > 0 and pathIndex <= #path do
				local target = path[pathIndex]
				local d = target - pos
				local dist = d.Magnitude
				turnTo(d, dt)
				if dist <= left then
					pos = target
					left -= dist
					table.insert(crumbs, target)
					pathIndex += 1
				else
					pos += d / dist * left
					left = 0
				end
			end
			if pathIndex > #path then
				state = "arriving"
				arrivedFor = 0
				walking(false)
			end
		end
	elseif state == "arriving" then
		gait(dt, false)
		arrivedFor += dt
		-- At the stop: face the guest; the card once they're near the stop or near him, or after
		-- a few seconds whatever (never a wait on a guest who can't find the spot).
		if guest then
			turnTo(guest - feet, dt)
			if (guest - stop.stand).Magnitude <= T.arriveWithin or apart <= T.arriveWithin or arrivedFor > T.cardAfter then
				showCard(cardIndex)
			end
		elseif arrivedFor > T.cardAfter then
			showCard(cardIndex)
		end
	elseif state == "card" then
		gait(dt, false)
		-- Explaining: half to the guest, half to the thing on the card.
		local toGuest = if guest then flat(guest - feet) else Vector3.zero
		local toThing = flat(stop.face - feet)
		local look = (if toGuest.Magnitude > 0.1 then toGuest.Unit else Vector3.zero) + (if toThing.Magnitude > 0.1 then toThing.Unit * 0.6 else Vector3.zero)
		turnTo(look, dt)
	end
	place(dt)
end

---------------------------------------------------------------------------------------------------
-- Start and stop
---------------------------------------------------------------------------------------------------

-- Home at once: the walk back (if he's on it) ends, his copy goes, the house's Concierge is back.
local function homeNow()
	if returning then
		returning:Disconnect()
		returning = nil
	end
	removeGuide()
	unhide()
end

function Tour.start()
	if active then
		-- Already on the tour: the card where we are, again.
		if state == "card" then
			showCard(cardIndex)
		end
		return
	end
	homeNow()
	local root = guestRoot()
	if not root or Tour.isSeated() then
		return
	end
	active = true
	stopIndex, cardIndex, lostFor, paused = 1, 1, 0, false
	fetching, waitedFor, arrivedFor, trailRefresh, holdFor = false, 0, 0, 0, 0
	local params = RaycastParams.new()
	pcall(function()
		params.FilterType = Enum.RaycastFilterType.Exclude
	end)
	rayParams = params
	local first = stops[1]
	local startAt = first.stand
	local real = findConcierge()
	if real then
		guide = buildGuide(real)
		local ok, pivot = pcall(function()
			return real:GetPivot()
		end)
		if ok and guide then
			startAt = Vector3.new(pivot.Position.X, pivot.Position.Y - hipHeight, pivot.Position.Z)
		end
		-- The house's Concierge steps out of sight only once the guest's own is there to take
		-- over (if the copy couldn't be made, the pins and the line still show the way).
		if guide then
			hide(real)
		end
	end
	pos = startAt
	feetY = startAt.Y
	home = startAt
	crumbs = { startAt }
	facing = if flat(root.Position - startAt).Magnitude > 0.1 then flat(root.Position - startAt).Unit else Vector3.new(0, 0, 1)
	refreshRays()
	rayRefresh = 1
	path = { first.stand }
	pathIndex = 1
	state = "walking"
	place(0)
	connection = RunService.RenderStepped:Connect(step)
	pcall(function()
		Remotes.event("Tour"):FireServer({ op = "start" })
	end)
	wayLine(Voice.TourWalk.start, first)
end

-- Ends the tour: "done" (the guest ended it), "table" (take me to a table), "lost" (wandered
-- off), "seated" (sat down somewhere), or nil (quietly).
function Tour.stop(reason: string?)
	if not active then
		return
	end
	active = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
	Dialogue.close()
	Waypoint.clear()
	GoldTrail.clear()
	pcall(Tour.pointAt, nil)
	Tour.walkHome()
	pcall(function()
		Remotes.event("Tour"):FireServer({ op = "end" })
	end)
	pcall(Tour.ended)
	if reason == "table" then
		Tour.toTable()
	elseif reason == "attractions" then
		Tour.toDirectory()
	elseif reason == "done" then
		Dialogue.show(V.speaker, V.tourEnd, nil, nil, 3)
	elseif reason == "lost" then
		Toast.show("The tour", Voice.TourWalk.lost, 5)
	end
end

-- After the tour (however it ended): he turns and walks back to the lectern the way he came,
-- briskly, and fades there (or wherever he is when Config.Tour.homeWithin seconds are up); then the
-- house's Concierge is in his place again on this screen. (Without a copy, he's simply back.)
function Tour.walkHome()
	if returning then
		returning:Disconnect()
		returning = nil
	end
	if not guide then
		unhide()
		return
	end
	local T = Config.data.Tour
	local way = table.clone(crumbs)
	table.insert(way, 1, home)
	local started = os.clock()
	local speed = math.max(T.speed, 30)
	pace = speed
	walking(true)
	returning = RunService.RenderStepped:Connect(function(dt: number)
		local left = speed * dt
		while left > 0 and #way > 0 do
			local target = way[#way]
			local d = target - pos
			local dist = d.Magnitude
			turnTo(d, dt)
			if dist <= left then
				pos = target
				left -= dist
				table.remove(way)
			else
				pos += d / dist * left
				left = 0
			end
		end
		gait(dt, #way > 0)
		place(dt)
		if #way == 0 or os.clock() - started > T.homeWithin then
			homeNow()
		end
	end)
end

-- Whether he's on his way back to the lectern after a tour (for tests).
function Tour.homeward(): boolean
	return returning ~= nil
end

-- The server says when (the guest asked the Concierge to show them round, or it's their very
-- first evening). It begins once the screen is clear: no title, intro or welcome on it.
function Tour.listen()
	Remotes.event("Tour").OnClientEvent:Connect(function(message: any)
		if type(message) == "table" and message.op == "start" then
			task.spawn(function()
				for _ = 1, 60 do
					if Tour.isClear() then
						break
					end
					task.wait(0.25)
				end
				Tour.start()
			end)
		end
	end)
end

return Tour
