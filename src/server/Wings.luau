--!strict
-- (Build 102) Every guest's own Suite and Vault, and the elevator that is the only way into them.
--
-- Each guest has a private wing (Shared/Wing): a real copy of the house's Suite and Vault, high
-- above the house, made when they first need it and taken away when they leave. Nobody can walk
-- there; the elevator takes a guest to their own Suite or Vault (5.5 seconds), to a friend's Suite
-- when that friend allows it (6.5 seconds), or back down to the house. The server decides every
-- journey: where a guest rides from, whether they may go where they ask, one journey at a time,
-- and where they step out. Riding with someone takes nobody along: each guest rides alone.
--
-- And it keeps watch: anyone found in a wing that isn't theirs (and isn't a friend's they were
-- let into) is taken straight home, and anyone found inside the house's own Suite or Vault (the
-- doors are sealed now; those rooms are only the pattern the wings are made from) is put back
-- outside the door. Other guests, their brainrots and their pets are never in your wing, because
-- they are somewhere else entirely, not because they are hidden.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Wing = require(ReplicatedStorage.Shared.Wing)
local Friends = require(script.Parent.Friends)
local Integrity = require(script.Parent.Integrity)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Wings = {}

-- Set by Main: whether a host lets this guest into their Suite now (server/Showcase: friends,
-- invited friends only, or nobody).
Wings.mayVisit = function(_host: Player, _visitor: Player): (boolean, string?)
	return false, "Their Suite isn't open just now."
end
-- Set by Main: whether a guest is busy where a journey can't start (seated at a table, inside an
-- attraction, on the jet): the reason, or nil.
Wings.busy = function(_player: Player): string?
	return nil
end
-- Set by Main: a guest has arrived in a friend's Suite (the Badge Book), and whose Suite a guest
-- is in now (SuiteVisits tells their screen how it's furnished).
Wings.visited = function(_visitor: Player, _host: Player) end
Wings.hostChanged = function(_player: Player, _host: Player?) end

-- The house machinery that must never act on a copy: the Vault's door to the Foyer and the old
-- lift between the floors (in a wing the lift's bell calls the elevator instead).
local OFF_TAGS = { "VaultDoor", "VaultDoorPart", "LiftCall", "LiftLeaf" }

local template: Folder? = nil
local holder: Folder? = nil
local own: { [Player]: number } = {}
local owner: { [number]: Player? } = {}
local built: { [number]: Model } = {}
local guestOf: { [Player]: Player } = {}
local rides: { [Player]: { to: string, ends: number } } = {}
local rested: { [Player]: number } = {}
local leaving: { [Player]: boolean } = {}

local REST = 1 -- seconds after arriving before another journey can start
local REACH = 16 -- how near the elevator's call a guest must stand to ride from it

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function notice(player: Player, title: string, line: string)
	Remotes.event("Shop"):FireClient(player, { op = "notice", title = title, line = line })
end

---------------------------------------------------------------------------------------------------
-- The pattern, and the wings made from it
---------------------------------------------------------------------------------------------------

local function wall(parent: Instance, name: string, from: Vector3, to: Vector3, visible: boolean)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = Vector3.new(math.abs(to.X - from.X), math.abs(to.Y - from.Y), math.abs(to.Z - from.Z))
	p.CFrame = CFrame.new((from + to) / 2)
	p.Material = Enum.Material.Wood
	p.Color = Color3.fromRGB(46, 30, 22)
	p.Transparency = if visible then 0 else 1
	p.CastShadow = visible
	p.Parent = parent
	return p
end

-- What the copies are made from: the house's own Suite, Vault and lift landings, with the
-- house's doorways closed (in a wing they would open onto nothing) and the house's machinery off.
function Wings.prepare(): boolean
	local maison = Workspace:FindFirstChild("Maison")
	if not maison then
		return false
	end
	local t = Instance.new("Folder")
	t.Name = "WingPattern"
	for _, name in { "Suite", "Vault", "Passages" } do
		local m = maison:FindFirstChild(name)
		if m then
			local ok, copy = pcall(function()
				return m:Clone()
			end)
			if ok and copy then
				copy.Parent = t
			end
		end
	end
	local passages = t:FindFirstChild("Passages")
	local door = passages and passages:FindFirstChild("VaultDoor")
	if door then
		door:Destroy()
	end
	for _, d in t:GetDescendants() do
		for _, tag in OFF_TAGS do
			if CollectionService:HasTag(d, tag) then
				CollectionService:RemoveTag(d, tag)
			end
		end
	end
	-- The Vault's south side is the Foyer's back wall in the house: a wall of its own here. And
	-- the gallery's far end, which opens onto the Club hall in the house.
	local V = Layout.Vault
	local seals = Instance.new("Folder")
	seals.Name = "Seals"
	seals.Parent = t
	wall(seals, "VaultSouth", Vector3.new(V.minX - 2, Layout.FLOOR - 1, 41.2), Vector3.new(V.maxX + 2, Layout.FLOOR + V.height + 1, 43.2), true)
	local d = Layout.Suite.door
	wall(seals, "GalleryEnd", Vector3.new(d.X - 0.4, d.Y - 1, d.Z - 5), Vector3.new(d.X + 0.6, Layout.Suite.floorY + Layout.Suite.height + 2, d.Z + 5), true)
	-- (Kept out of the world: only copies of it stand anywhere.)
	template = t
	return true
end

local function folder(): Folder
	local f = holder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "PrivateWings"
	nf.Parent = Workspace
	holder = nf
	return nf
end

-- Moves every part of a copy up to its wing.
local function lift(model: Instance, by: Vector3)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + by
			local closed = d:GetAttribute("Closed")
			if typeof(closed) == "CFrame" then
				d:SetAttribute("Closed", closed + by)
			end
		end
	end
end

-- The elevator's bell in a wing (the old lift's push): rings for the guest standing at it.
local function wireCalls(model: Model, slot: number)
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "LiftPrompt" then
			d.ActionText = "Elevator"
			d.ObjectText = "Choose a floor"
			d.Triggered:Connect(function(player: Player)
				Wings.menu(player, slot)
			end)
		end
	end
end

-- Wing `slot`, made if it isn't there yet.
function Wings.ensure(slot: number): Model?
	local m = built[slot]
	if m and m.Parent then
		return m
	end
	local t = template
	if not t then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Wing" .. slot
	model:SetAttribute("Wing", slot)
	for _, child in t:GetChildren() do
		child:Clone().Parent = model
	end
	lift(model, Wing.offset(slot))
	wireCalls(model, slot)
	model.Parent = folder()
	built[slot] = model
	return model
end

-- Each guest's own wing number, from the moment they arrive.
function Wings.slotOf(player: Player): number?
	return own[player]
end

local function claim(player: Player): number?
	local s = own[player]
	if s then
		return s
	end
	if leaving[player] then
		return nil
	end
	for k = 0, Wing.MAX - 1 do
		if owner[k] == nil then
			owner[k] = player
			own[player] = k
			-- (Their screen keeps their own wing drawn, always.)
			player:SetAttribute("Wing", k)
			return k
		end
	end
	return nil
end

-- Where a guest steps out: in front of the elevator's doors on that floor, facing into the room.
function Wings.arrival(slot: number, floor: string): CFrame
	local at = (Layout.Lift :: any)[floor] or Layout.Lift.suite
	local base: Vector3 = at.centre
	local out: Vector3 = at.out
	local spot = base + out * 3.5 + Vector3.new(0, 3, 0) + Wing.offset(slot)
	return CFrame.lookAt(spot, spot + out)
end

-- Where a guest stands back in the house: outside the Vault's door, facing the Foyer.
function Wings.houseArrival(): CFrame
	local d = Layout.Vault.door
	local spot = Vector3.new(d.X, Layout.FLOOR + 3, d.Z - 6)
	return CFrame.lookAt(spot, spot - Vector3.new(0, 0, 1))
end

-- The wing a guest stands in now (theirs, a friend's, or none), and the room there.
function Wings.where(player: Player): (number?, string?)
	local root = rootOf(player)
	if not root then
		return nil, nil
	end
	local _, k = Wing.toHouse(root.Position)
	if not k then
		return nil, nil
	end
	local zone = Layout.zoneAt(root.Position)
	return k, if zone == "suite" or zone == "vault" then zone else nil
end

-- Whose Suite a guest is visiting now (nil: their own, or none).
function Wings.hostOf(player: Player): Player?
	return guestOf[player]
end

---------------------------------------------------------------------------------------------------
-- The elevator
---------------------------------------------------------------------------------------------------

-- Where a guest stands in their own wing's Suite or Vault (the wing made ready), or nil.
function Wings.homeSpot(player: Player, floor: string?): CFrame?
	local slot = claim(player)
	if not slot or not Wings.ensure(slot) then
		return nil
	end
	guestOf[player] = nil
	return Wings.arrival(slot, floor or "suite")
end

-- Puts a guest straight into their own wing (a returning guest arriving, or sent home): no ride.
function Wings.place(player: Player, floor: string?): boolean
	local slot = claim(player)
	local character = player.Character
	if not slot or not character or not Wings.ensure(slot) then
		return false
	end
	guestOf[player] = nil
	Wings.hostChanged(player, nil)
	Integrity.teleport(player, character, Wings.arrival(slot, floor or "suite"))
	return true
end

-- Whether a journey is under way for this guest.
function Wings.riding(player: Player): boolean
	return rides[player] ~= nil
end

-- A guest asks to ride: `to` is "suite" or "vault" (their own), "friend" (with `host`), or
-- "house". Returns whether the journey began, and why not.
function Wings.ride(player: Player, to: string, host: Player?): (boolean, string?)
	local seconds = Wing.SECONDS[to]
	if not seconds then
		return false, "There's no such floor."
	end
	if rides[player] then
		return false, "You're already on your way."
	end
	if rested[player] and os.clock() - (rested[player] :: number) < REST then
		return false, "One moment."
	end
	local busy = Wings.busy(player)
	if busy then
		return false, busy
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or not rootOf(player) then
		return false, "Not just now."
	end
	local slot = claim(player)
	if not slot then
		return false, "The elevator is busy. Try again in a moment."
	end
	local destination: number = slot
	local floor = if to == "vault" then "vault" else "suite"
	if to == "friend" then
		if not host or host == player or host.Parent ~= Players then
			return false, "That guest has left the house."
		end
		if not Friends.are(player, host) then
			return false, "Only friends on Roblox may visit each other's Suites."
		end
		local may, why = Wings.mayVisit(host, player)
		if not may then
			return false, why or "Their Suite isn't open just now."
		end
		local hs = claim(host)
		if not hs then
			return false, "Their Suite isn't open just now."
		end
		destination = hs
	end
	if to ~= "house" and not Wings.ensure(destination) then
		return false, "Not just now."
	end
	local started = os.clock()
	rides[player] = { to = to, ends = started + seconds }
	-- (The friend's wing drawn on the visitor's screen before the doors open on it.)
	player:SetAttribute("WingVisit", if to == "friend" then destination else nil)
	Remotes.event("Guest"):FireClient(player, {
		op = "elevator",
		to = to,
		seconds = seconds,
		name = if to == "friend" and host then Names.of(host) .. "'s Suite" elseif to == "vault" then "Your Vault" elseif to == "house" then "The house" else "Your Suite",
		floor = if to == "house" then "L" elseif to == "vault" then "V" else "PH",
	})
	task.delay(seconds, function()
		local ride = rides[player]
		if not ride or player.Parent ~= Players then
			rides[player] = nil
			return
		end
		rides[player] = nil
		rested[player] = os.clock()
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if not c or not h or h.Health <= 0 then
			return
		end
		local at: CFrame
		local visiting: Player? = nil
		if to == "house" then
			at = Wings.houseArrival()
		elseif to == "friend" and host then
			-- (Asked again at the door: a host who closed their Suite on the way up closes it.)
			local still = host.Parent == Players and Friends.are(player, host) and (Wings.mayVisit(host, player))
			if still and own[host] then
				at = Wings.arrival(own[host] :: number, "suite")
				visiting = host
			else
				notice(player, "Your Suite", "Their Suite closed to visitors on the way up, so this is your own.")
				at = Wings.arrival(slot, "suite")
			end
		else
			at = Wings.arrival(slot, floor)
		end
		if visiting then
			guestOf[player] = visiting
		else
			guestOf[player] = nil
			player:SetAttribute("WingVisit", nil)
		end
		Wings.hostChanged(player, visiting)
		Integrity.teleport(player, c, at)
		Remotes.event("Guest"):FireClient(player, { op = "elevatorArrived", to = to })
		if visiting then
			notice(visiting, "A visitor", Names.of(player) .. " is visiting your Suite.")
			Wings.visited(player, visiting)
		end
	end)
	return true, nil
end

-- The floors this guest may choose, for the elevator's panel: their own Suite and Vault, the
-- house, and each friend in the house whose Suite is open to them.
function Wings.floors(player: Player): { [string]: any }
	local friends = {}
	for _, f in Friends.inServer(player) do
		local may = Wings.mayVisit(f, player)
		table.insert(friends, { userId = f.UserId, name = Names.of(f), open = may == true })
	end
	local k, room = Wings.where(player)
	local here = if k == nil then "house" elseif guestOf[player] then "friend" else room or "suite"
	return { here = here, friends = friends, seconds = Wing.SECONDS }
end

-- Shows the elevator's panel on a guest's screen (they pressed a call button).
function Wings.menu(player: Player, slot: number?)
	-- (A wing's own bell is for those allowed in that wing: its owner, or their visitor.)
	if slot ~= nil then
		local k = Wings.where(player)
		if k ~= slot then
			return
		end
	end
	Remotes.event("Guest"):FireClient(player, { op = "elevatorMenu", floors = Wings.floors(player) })
end

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 3, 0)
	if not r then
		RemoteGuard.reject(player, "elevatorAsk", "malformed")
		return { ok = false }
	end
	if r.op == "floors" then
		return { ok = true, floors = Wings.floors(player) }
	elseif r.op == "ride" then
		local to = RemoteGuard.string(r.to, 12)
		if to ~= "suite" and to ~= "vault" and to ~= "house" and to ~= "friend" then
			return { ok = false, why = "There's no such floor." }
		end
		local host: Player? = nil
		if to == "friend" then
			local id = RemoteGuard.number(r.userId, -1e15, 1e15, true)
			host = if id then Players:GetPlayerByUserId(id) else nil
		end
		local ok, why = Wings.ride(player, to :: string, host)
		return { ok = ok, why = why }
	end
	return { ok = false }
end

---------------------------------------------------------------------------------------------------
-- The watch
---------------------------------------------------------------------------------------------------

-- May this guest stand in wing `k`?
local function allowed(player: Player, k: number): boolean
	if own[player] == k then
		return true
	end
	local host = guestOf[player]
	if host and own[host] == k and host.Parent == Players and Friends.are(player, host) then
		return (Wings.mayVisit(host, player))
	end
	return false
end

-- Everyone where they may be. Returns how many were moved (for tests).
function Wings.watch(): number
	local moved = 0
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local character = player.Character
		if not root or not character or rides[player] or leaving[player] then
			continue
		end
		local house, k = Wing.toHouse(root.Position)
		if k then
			if not allowed(player, k) then
				moved += 1
				local was = guestOf[player]
				guestOf[player] = nil
				player:SetAttribute("WingVisit", nil)
				Wings.hostChanged(player, nil)
				local mine = claim(player)
				if mine and Wings.ensure(mine) then
					Integrity.teleport(player, character, Wings.arrival(mine, "suite"))
				else
					Integrity.teleport(player, character, Wings.houseArrival())
				end
				notice(player, "Your Suite", if was then "That Suite has closed to visitors, so you're back in your own." else "Every Suite is private: this one is yours.")
			end
		else
			-- The house's own Suite and Vault are sealed: nobody stands in them.
			local zone = Layout.zoneAt(house)
			if zone == "suite" or zone == "vault" then
				moved += 1
				Integrity.teleport(player, character, Wings.houseArrival())
				notice(player, "The elevator", "Your Suite and Vault are private: the elevator by the Vault's door takes you up.")
			elseif guestOf[player] then
				guestOf[player] = nil
				Wings.hostChanged(player, nil)
			end
		end
	end
	return moved
end

---------------------------------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------------------------------

-- The house's own doors become the elevator's: a call button by each (the Vault's door in the
-- Foyer, the Suite's on the Club Floor), and a seal in each doorway.
local function callButtons()
	local f = Instance.new("Folder")
	f.Name = "ElevatorCalls"
	f.Parent = Workspace:FindFirstChild("Maison") or Workspace
	local V = Layout.Vault
	local S = Layout.Suite
	wall(f, "VaultDoorSeal", Vector3.new(V.door.X - V.doorWidth / 2 - 0.2, Layout.FLOOR, 42.6), Vector3.new(V.door.X + V.doorWidth / 2 + 0.2, Layout.FLOOR + 11, 43.6), false)
	wall(f, "SuiteDoorSeal", Vector3.new(S.door.X - 1.2, S.door.Y - 0.5, S.door.Z - S.doorWidth / 2 - 0.2), Vector3.new(S.door.X - 0.2, S.door.Y + S.doorHeight + 0.5, S.door.Z + S.doorWidth / 2 + 0.2), false)
	local function call(name: string, at: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Transparency = 1
		p.Size = Vector3.new(2, 2, 2)
		p.CFrame = CFrame.new(at)
		p.Parent = f
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ElevatorPrompt"
		prompt.ActionText = "Elevator"
		prompt.ObjectText = "Your Suite and Vault"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = p
		prompt.Triggered:Connect(function(player: Player)
			local root = rootOf(player)
			if root and (root.Position - at).Magnitude <= REACH then
				Wings.menu(player, nil)
			end
		end)
	end
	call("VaultDoorCall", Vector3.new(V.door.X, Layout.FLOOR + 4, V.door.Z - 2))
	call("SuiteDoorCall", Vector3.new(S.door.X + 2, S.door.Y + 4, S.door.Z))
end

function Wings.start()
	Wings.prepare()
	pcall(callButtons)
	RemoteGuard.invoke(Remotes.func("ElevatorAsk"), "elevatorAsk", onAsk)
	for _, p in Players:GetPlayers() do
		claim(p)
	end
	Players.PlayerAdded:Connect(function(p: Player)
		leaving[p] = nil
		claim(p)
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		leaving[p] = true
		task.delay(30, function()
			leaving[p] = nil
		end)
		rides[p] = nil
		rested[p] = nil
		guestOf[p] = nil
		local slot = own[p]
		own[p] = nil
		if slot then
			owner[slot] = nil
			local m = built[slot]
			built[slot] = nil
			-- (Anyone visiting is taken home first, then the wing goes.)
			task.defer(function()
				pcall(Wings.watch)
				if m then
					m:Destroy()
				end
			end)
		end
		for v, h in guestOf do
			if h == p then
				guestOf[v] = nil
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.3)
			pcall(Wings.watch)
		end
	end)
end

-- For tests.
Wings.handle = onAsk

return Wings
