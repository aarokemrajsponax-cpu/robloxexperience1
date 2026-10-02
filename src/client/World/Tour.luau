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
local Waypoint = require(script.Parent.Waypoint)

local Tour = {}

-- Set by Main: sit the guest at a Salon table (the last card's "Take me to a table"), and
-- whether they're at a table now (the tour steps aside).
Tour.toTable = function() end
Tour.isSeated = function(): boolean
	return false
end

type Card = { stop: string, title: string, line: string, place: string? }

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
local hidden: { { inst: Instance, prop: string, value: any } } = {}
local connection: RBXScriptConnection? = nil
local rayParams: RaycastParams? = nil
local rayRefresh = 0

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
	m.Parent = Workspace
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

local function walking(on: boolean)
	local walk, idle = walkTrack, idleTrack
	if walk then
		if on and not walk.IsPlaying then
			walk:Play(0.2)
			walk:AdjustSpeed(Config.data.Tour.speed / 12)
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

local function place(dt: number)
	local root = guideRoot
	feetY += (floorAt(pos) - feetY) * (1 - math.exp(-14 * dt))
	if not root then
		return
	end
	local at = Vector3.new(pos.X, feetY + hipHeight, pos.Z)
	root.CFrame = CFrame.lookAt(at, at + facing)
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
local function wayLine(line: string, stop: Layout.TourStop)
	Dialogue.show(V.speaker, line, { { id = "done", text = Voice.TourKeys.done } }, function()
		Tour.stop("done")
	end, nil, { point = stop.stand, pointName = stop.name, sticky = true })
end

local function walkTo(index: number)
	local stop = stops[index]
	stopIndex = index
	path = table.clone(stop.via)
	table.insert(path, stop.stand)
	pathIndex = 1
	paused = false
	state = "walking"
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
	elseif id == "table" then
		Tour.stop("table")
	else
		Tour.stop("done")
	end
end

showCard = function(i: number)
	cardIndex = i
	state = "card"
	local card = cards[i]
	local K = Voice.TourKeys
	local choices: { Dialogue.Choice }
	if i == #cards then
		choices = { { id = "table", text = K.table }, { id = "explore", text = K.explore } }
	else
		choices = { { id = "next", text = K.next } }
		if i > 1 then
			table.insert(choices, { id = "back", text = K.back })
		end
		table.insert(choices, { id = "done", text = K.done })
	end
	local point = if card.place then Layout.Tour.points[card.place] else nil
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
	if state == "walking" then
		if guest then
			if paused then
				paused = apart > T.resumeWithin
			else
				-- Behind, not ahead: further from where we're going than the Concierge is.
				paused = apart > T.waitBeyond and (guest - stop.stand).Magnitude > (pos - stop.stand).Magnitude
			end
		end
		if paused and guest then
			walking(false)
			turnTo(guest - feet, dt)
		else
			walking(true)
			local left = T.speed * dt
			while left > 0 and pathIndex <= #path do
				local target = path[pathIndex]
				local d = target - pos
				local dist = d.Magnitude
				turnTo(d, dt)
				if dist <= left then
					pos = target
					left -= dist
					pathIndex += 1
				else
					pos += d / dist * left
					left = 0
				end
			end
			if pathIndex > #path then
				state = "arriving"
				walking(false)
			end
		end
	elseif state == "arriving" then
		-- At the stop: face the guest until they're close, then the card.
		if guest then
			turnTo(guest - feet, dt)
			if (guest - stop.stand).Magnitude <= T.arriveWithin then
				showCard(cardIndex)
			end
		end
	elseif state == "card" then
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

function Tour.start()
	if active then
		-- Already on the tour: the card where we are, again.
		if state == "card" then
			showCard(cardIndex)
		end
		return
	end
	local root = guestRoot()
	if not root or Tour.isSeated() then
		return
	end
	active = true
	stopIndex, cardIndex, lostFor, paused = 1, 1, 0, false
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
	removeGuide()
	unhide()
	pcall(function()
		Remotes.event("Tour"):FireServer({ op = "end" })
	end)
	if reason == "table" then
		Tour.toTable()
	elseif reason == "done" then
		Dialogue.show(V.speaker, V.tourEnd, nil, nil, 3)
	elseif reason == "lost" then
		Toast.show("The tour", Voice.TourWalk.lost, 5)
	end
end

-- The server says when (the guest asked the Concierge to show them round).
function Tour.listen()
	Remotes.event("Tour").OnClientEvent:Connect(function(message: any)
		if type(message) == "table" and message.op == "start" then
			Tour.start()
		end
	end)
end

return Tour
