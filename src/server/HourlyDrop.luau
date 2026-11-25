--!strict
-- The Hourly Drop on the server (Build 91; shared/HourlyDrop has the hours). In the Foyer, west of
-- the runner, a black marble plinth ringed in brass. On the hour, every hour, by the clock (the
-- same moment in every server), the courier's case comes down onto it and stays for
-- Config.HourlyDrop.openMinutes; then it's gone until the next hour.
--
-- Each guest opens it once an hour, in person (its prompt, in reach of the case), and everything
-- is checked here: that the case is open by the server's clock, that the guest is standing by it,
-- and that this hour's case isn't already opened in their record (kept with their profile, so
-- rejoining, or another server, never opens it twice). It pays Gilt and, the first time they open
-- a case with that piece, the hour's piece (a curio: six in turn, each back every six hours).
-- Nothing is sent from a guest's screen but "what's the state": no amounts, no pieces, no hours.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local GiltScale = require(ReplicatedStorage.Shared.Fortune)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Plan = require(ReplicatedStorage.Shared.HourlyDrop)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Achievements = require(script.Parent.Achievements)
local Curios = require(script.Parent.Curios)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Kit = require(script.Parent.World.Kit)

local HourlyDrop = {}

HourlyDrop.NAME = "HourlyDrop"
HourlyDrop.STAT = "hourlyDrops"

local function cfg(): { [string]: any }
	return (Config.data :: any).HourlyDrop or {}
end

-- The clock (set for tests).
HourlyDrop.now = function(): number
	return os.time()
end
-- Whether a guest's movement is to be believed (set by Main: Integrity).
HourlyDrop.trusted = function(_player: Player): boolean
	return true
end
-- Counts the case in the guest's record, once for `once` (set by Main: with its XP). Whether it
-- counted.
HourlyDrop.tally = function(player: Player, stat: string, n: number, once: string?): boolean
	return Achievements.tally(player, stat, n, once)
end
HourlyDrop.rootOf = function(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local model: Model? = nil
local case: Model? = nil
local shown = false -- the case is on the plinth now
local lastHour = -1

-- Where it stands: on the Foyer's floor, west of the runner (in the Grand house).
function HourlyDrop.spot(): Vector3
	return Layout.Foyer.dropPlinth
end

local function floorY(): number
	return Layout.FLOOR
end

-- Where the case rests (its centre), on top of the plinth.
function HourlyDrop.caseAt(): Vector3
	local p = HourlyDrop.spot()
	return Vector3.new(p.X, floorY() + 0.35 + 3 + 0.15 + 0.85, p.Z)
end

local L = Kit.Looks
local GOLD = { color = Color3.fromRGB(214, 168, 72), material = Enum.Material.Metal, reflectance = 0.2 }
local GLOW = { color = Color3.fromRGB(255, 206, 110), material = Enum.Material.Neon, transparency = 0.1 }
local LEATHER = { color = Color3.fromRGB(16, 14, 16), material = Enum.Material.Leather }
local SILK = { color = Color3.fromRGB(70, 16, 30), material = Enum.Material.Fabric }
local QUIET = { collide = false, query = false, shadow = false }

-- The plinth: black marble on a bone marble disc ringed in brass, a halo of light in the floor
-- (lit while the case is down), a brass plaque that says what it is.
local function plinth(m: Model)
	local p = HourlyDrop.spot()
	local y = floorY()
	local up = CFrame.Angles(0, 0, math.rad(90))
	Kit.cylinder(m, "Inlay", 0.06, 10.4, CFrame.new(p.X, y + 0.03, p.Z) * up, L.brass, QUIET)
	Kit.cylinder(m, "Disc", 0.08, 9.8, CFrame.new(p.X, y + 0.05, p.Z) * up, L.boneMarble, QUIET)
	local halo = Kit.cylinder(m, "Halo", 0.04, 8.6, CFrame.new(p.X, y + 0.1, p.Z) * up, GLOW, QUIET)
	halo.Transparency = 0.85
	Kit.cylinder(m, "HaloCore", 0.05, 8.2, CFrame.new(p.X, y + 0.11, p.Z) * up, L.boneMarble, QUIET)
	Kit.cylinder(m, "Foot", 0.35, 5.8, CFrame.new(p.X, y + 0.175, p.Z) * up, L.brass)
	Kit.cylinder(m, "Drum", 3, 5, CFrame.new(p.X, y + 0.35 + 1.5, p.Z) * up, L.blackMarble)
	for i, h in { 0.9, 2.1 } do
		Kit.cylinder(m, "Band" .. i, 0.08, 5.06, CFrame.new(p.X, y + 0.35 + h, p.Z) * up, L.brass, QUIET)
	end
	Kit.cylinder(m, "Collar", 0.22, 5.4, CFrame.new(p.X, y + 0.35 + 3 - 0.11, p.Z) * up, L.brass)
	Kit.cylinder(m, "Top", 0.15, 4.8, CFrame.new(p.X, y + 0.35 + 3 + 0.075, p.Z) * up, L.boneMarble)
	-- The plaque, on the side that faces the front door.
	-- (A plain CFrame faces -Z, the front door's way: the same in Studio and in every test.)
	local face = CFrame.new(p.X, y + 1.85, p.Z - 2.52)
	Kit.part(m, "PlaqueFrame", Vector3.new(3.1, 1.05, 0.06), face * CFrame.new(0, 0, 0.02), L.brass, QUIET)
	local plaque = Kit.part(m, "Plaque", Vector3.new(2.9, 0.85, 0.08), face, L.blackLacquer, QUIET)
	Kit.engrave(plaque, Enum.NormalId.Front, {
		{ text = "THE HOURLY DROP", size = 0.46, font = Brand.Fonts.display, color = Color3.fromRGB(232, 192, 108) },
		{ text = "on the hour, every hour", size = 0.3, font = Brand.Fonts.body, color = Color3.fromRGB(220, 212, 196) },
	}, { ppu = 120, lit = false, brightness = 1.3, oneLine = true })
	-- A warm light over it, and one glancing up the drum from the floor.
	local lamp = Kit.part(m, "Lamp", Vector3.new(0.4, 0.4, 0.4), CFrame.new(p.X, y + 9, p.Z), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, QUIET)
	Kit.spotLight(lamp, Enum.NormalId.Bottom, 2.2, 22, 50, Color3.fromRGB(255, 214, 150), true)
	-- (Where every screen hangs its sign: over the case.)
	local sign = Instance.new("Attachment")
	sign.Name = "SignAt"
	sign.Position = Vector3.new(0, 4.6, 0)
	local top = m:FindFirstChild("Top") :: BasePart
	sign.Parent = top
end

-- The courier's case: black leather, brass corners and clasp, a handle, a silk lining and a glow
-- inside (seen when its lid lifts on a guest's own screen). The lid is its own part, hinged at the
-- back, so a screen can lift it.
local function buildCase(): Model
	local c = Instance.new("Model")
	c.Name = "Case"
	local at = HourlyDrop.caseAt()
	local base = CFrame.new(at)
	local w, h, d = 3.4, 1.4, 2.3
	local body = Kit.part(c, "Body", Vector3.new(w, h, d), base, LEATHER)
	Kit.part(c, "Lining", Vector3.new(w - 0.3, 0.06, d - 0.3), base * CFrame.new(0, h / 2 - 0.02, 0), SILK, QUIET)
	local glow = Kit.part(c, "Glow", Vector3.new(w - 0.6, 0.05, d - 0.6), base * CFrame.new(0, h / 2 + 0.01, 0), GLOW, QUIET)
	glow.Transparency = 1
	local lid = Kit.part(c, "Lid", Vector3.new(w + 0.06, 0.34, d + 0.06), base * CFrame.new(0, h / 2 + 0.17, 0), LEATHER, QUIET)
	lid:SetAttribute("Hinge", base * CFrame.new(0, h / 2, d / 2 + 0.03))
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			for _, sy in { -1, 1 } do
				Kit.part(c, "Corner", Vector3.new(0.34, 0.34, 0.34), base * CFrame.new(sx * (w / 2 - 0.12), sy * (h / 2 - 0.1) + (if sy > 0 then 0.24 else 0), sz * (d / 2 - 0.12)), GOLD, QUIET)
			end
		end
	end
	-- The trim round the lid's edge and the clasp at the front.
	Kit.part(c, "Seam", Vector3.new(w + 0.1, 0.06, d + 0.1), base * CFrame.new(0, h / 2, 0), GOLD, QUIET)
	Kit.part(c, "Clasp", Vector3.new(0.5, 0.42, 0.08), base * CFrame.new(0, h / 2 - 0.05, -d / 2 - 0.05), GOLD, QUIET)
	Kit.part(c, "Monogram", Vector3.new(0.9, 0.04, 0.9), base * CFrame.new(0, h / 2 + 0.36, 0) * CFrame.Angles(0, math.rad(45), 0), GOLD, QUIET)
	-- The handle on top.
	for _, sx in { -1, 1 } do
		Kit.part(c, "HandlePost", Vector3.new(0.16, 0.32, 0.16), base * CFrame.new(sx * 0.6, h / 2 + 0.5, 0), GOLD, QUIET)
	end
	Kit.cylinder(c, "Handle", 1.36, 0.18, base * CFrame.new(0, h / 2 + 0.68, 0), GOLD, QUIET)
	for _, part in c:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	body.CanQuery = true
	c.PrimaryPart = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open the case"
	prompt.ObjectText = "The Hourly Drop"
	prompt.HoldDuration = 0.25 -- (Build 105: quicker to open)
	prompt.MaxActivationDistance = tonumber(cfg().reach) or 14
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = body
	pcall(function()
		prompt.Triggered:Connect(function(player: Player)
			HourlyDrop.open(player)
		end)
	end)
	return c
end

-- Builds the plinth (and the case, kept to show). Returns the model.
function HourlyDrop.build(parent: Instance?): Model
	if model then
		model:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = HourlyDrop.NAME
	Kit.persist(m)
	plinth(m)
	m.Parent = parent or Workspace
	model = m
	case = buildCase()
	shown = false
	return m
end

function HourlyDrop.model(): Model?
	return model
end

function HourlyDrop.case(): Model?
	return case
end

local function tell(player: Player, message: { [string]: any })
	message.op = "hourlyDrop"
	Remotes.event("Salute"):FireClient(player, message)
end

-- Puts the case on the plinth or takes it away, and says so on the Workspace for every screen:
-- DropOpen, DropHour, DropPiece (this hour's), DropNextPiece.
function HourlyDrop.step()
	local now = HourlyDrop.now()
	local open = Plan.isOpen(now)
	local hour = Plan.hourOf(now)
	local m, c = model, case
	if m and c then
		if open and not shown then
			c.Parent = m
			shown = true
		elseif not open and shown then
			c.Parent = nil
			shown = false
		end
		local halo = m:FindFirstChild("Halo")
		if halo and halo:IsA("BasePart") then
			halo.Transparency = if open then 0.1 else 0.85
		end
	end
	-- (The hour, not its times: a time this large isn't kept to the second as an attribute. Every
	-- screen works the times out from the hour, the same way, by the server's clock.)
	Workspace:SetAttribute("DropOpen", open)
	Workspace:SetAttribute("DropHour", hour)
	Workspace:SetAttribute("DropPiece", Plan.pieceOf(hour))
	Workspace:SetAttribute("DropNextPiece", Plan.pieceOf(hour + 1))
	if open and hour ~= lastHour then
		lastHour = hour
		-- (Only this server's guests, once an hour: a line in the corner, no headline.)
		for _, p in Players:GetPlayers() do
			tell(p, { stage = "down", hour = hour, piece = Plan.pieceOf(hour), closes = Plan.closesAt(now) })
		end
	end
end

local function opened(data: Profiles.Data, hour: number): boolean
	local once = (data :: any).tallyOnce
	return type(once) == "table" and once[HourlyDrop.STAT] == tostring(hour)
end

local function count(data: Profiles.Data): number
	local t = (data :: any).tally
	return if type(t) == "table" then tonumber(t[HourlyDrop.STAT]) or 0 else 0
end

local function held(data: Profiles.Data): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local items = (data :: any).curios and (data :: any).curios.items
	for _, id in Plan.Pieces do
		out[id] = type(items) == "table" and (tonumber(items[id]) or 0) > 0
	end
	return out
end

-- What a guest's screen shows: whether this hour's case is opened, how many they've opened, the
-- pieces they hold, and the hours.
function HourlyDrop.state(player: Player): { [string]: any }
	local data = Profiles.get(player)
	local now = HourlyDrop.now()
	local hour = Plan.hourOf(now)
	return {
		ok = data ~= nil,
		open = Plan.isOpen(now),
		hour = hour,
		piece = Plan.pieceOf(hour),
		closes = if Plan.isOpen(now) then Plan.closesAt(now) else nil,
		nextAt = Plan.nextAt(now),
		nextPiece = Plan.pieceOf(hour + 1),
		opened = if data then opened(data, hour) else false,
		count = if data then count(data) else 0,
		have = if data then held(data) else {},
		gilt = GiltScale.scaled(tonumber(cfg().gilt) or 250),
	}
end

-- A guest opens this hour's case. Everything checked here. Returns what happened.
function HourlyDrop.open(player: Player): { [string]: any }
	local now = HourlyDrop.now()
	if not Plan.enabled() then
		return { ok = false, why = "The courier is resting tonight." }
	end
	if not Plan.isOpen(now) then
		return { ok = false, why = "The case has gone. The next comes down at the top of the hour.", nextAt = Plan.nextAt(now) }
	end
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "One moment." }
	end
	local hour = Plan.hourOf(now)
	if opened(data, hour) then
		return { ok = false, why = "You've opened this hour's case. The next comes down at the top of the hour.", nextAt = Plan.nextAt(now) }
	end
	local root = HourlyDrop.rootOf(player)
	local reach = (tonumber(cfg().reach) or 14) + 4
	if not root or (root.Position - HourlyDrop.caseAt()).Magnitude > reach then
		return { ok = false, why = "Stand by the case to open it." }
	end
	if not HourlyDrop.trusted(player) then
		return { ok = false, why = "One moment." }
	end
	-- Counted first, once for this hour, in the guest's own record: never twice, here or anywhere.
	if not HourlyDrop.tally(player, HourlyDrop.STAT, 1, tostring(hour)) then
		return { ok = false, why = "You've opened this hour's case. The next comes down at the top of the hour.", nextAt = Plan.nextAt(now) }
	end
	local paid = Gilt.pay(player, data, math.max(0, math.floor(tonumber(cfg().gilt) or 250)), "The Hourly Drop")
	local piece = Plan.pieceOf(hour)
	local isNew = false
	local had = held(data)
	if not had[piece] and CurioList.byId[piece] then
		isNew = Curios.give(player, data, piece, 1, "event")
		if isNew then
			Curios.push(player)
		end
	end
	local out = HourlyDrop.state(player)
	out.ok = true
	out.paid = paid
	out.piece = piece
	out.new = isNew
	tell(player, { stage = "opened", paid = paid, piece = piece, new = isNew, count = out.count, have = out.have, nextAt = out.nextAt, nextPiece = out.nextPiece })
	return out
end

local function onAsk(player: Player, request: any): { [string]: any }
	if type(request) ~= "table" or request.op ~= "state" then
		RemoteGuard.reject(player, "hourlyDrop", "malformed")
		return { ok = false }
	end
	return HourlyDrop.state(player)
end

function HourlyDrop.start()
	RemoteGuard.invoke(Remotes.func("HourlyDropAsk"), "hourlyDrop", onAsk)
	if not model then
		pcall(HourlyDrop.build, Workspace)
	end
	task.spawn(function()
		while true do
			pcall(HourlyDrop.step)
			task.wait(1)
		end
	end)
end

return HourlyDrop
