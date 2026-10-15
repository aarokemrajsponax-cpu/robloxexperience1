--!strict
-- Admin Abuse's party games, on the server: something to do in the Foyer while the house dances
-- (World/AbuseParty draws the dancing).
--   the Gold Tile  every so often one tile of the Foyer's marble floor turns gold for a few seconds
--                  (Workspace's PartyTile, PartyTileSize, PartyTileUntil): everyone standing on it
--                  when the time's up is paid. The server picks the tile and checks who's on it.
--   the Piñata     a golden piñata hangs under the chandelier; everyone in reach hits it (its Hit
--                  prompt) until it bursts, and everyone who hit it is paid (the last hit a little
--                  more). Nobody breaks it in time, and it floats away.
-- Gilt only, multiplied like any other Gilt; nothing here is sold, nothing is random in what it
-- pays (Config.Admin.party).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)

local AbuseParty = {}

AbuseParty.PINATA = "PartyPinata"

-- Set by Main: whether a guest's movement is trusted (Integrity), and where a guest stands.
AbuseParty.trusted = function(_player: Player): boolean
	return true
end
AbuseParty.rootOf = function(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root :: any
end

local function cfg(): { [string]: any }
	return (Config.data.Admin :: any).party
end

local function abusing(): boolean
	local ends = Workspace:GetAttribute("AbuseUntil")
	return type(ends) == "number" and ends > os.time()
end

local function tell(player: Player, message: { [string]: any })
	Remotes.event("Salute"):FireClient(player, message)
end

local function broadcast(message: { [string]: any })
	Remotes.event("Salute"):FireAllClients(message)
end

---------------------------------------------------------------------------------------------------
-- The Foyer's floor
---------------------------------------------------------------------------------------------------
export type Tile = { centre: Vector3, size: Vector3 }

-- The Foyer's marble tiles a Gold Tile may be (as World/Foyer lays them, grown to the Grand
-- house): every one in the open, none under the stair, the piano, the lectern, a column or the
-- guest book's stand, nor in the front door's way.
function AbuseParty.tiles(): { Tile }
	local raw = Layout.raw
	local F = raw.Foyer
	local S = Layout.SCALE
	local tile = 6
	local nx = math.floor((F.maxX - F.minX) / tile)
	local nz = math.ceil((F.maxZ - F.minZ) / tile)
	local dz = (F.maxZ - F.minZ) / nz
	-- (Points to keep clear, each with how far: in the house's drawn numbers.)
	local clear = {
		{ 9, 1.5, 4 }, -- the lectern
		{ 9, -1, 3 }, -- where guests arrive
		{ 18, 20, 5 }, -- the piano
		{ 13, 20, 3 }, -- its bench
		{ -22, 8, 3 },
		{ 22, 8, 3 },
		{ -22, 28, 3 },
		{ 22, 28, 3 }, -- the columns
		{ -19, 36, 3 }, -- the guest book
		{ 0, -8, 6 }, -- the front door
	}
	local st = F.stair
	local out: { Tile } = {}
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local x = F.minX + tile * (ix + 0.5)
			local z = F.minZ + dz * (iz + 0.5)
			local x0, x1, z0, z1 = x - tile / 2, x + tile / 2, z - dz / 2, z + dz / 2
			local ok = ix > 0 and ix < nx - 1 and iz < nz - 1
			-- (The stair and its landing.)
			if x1 > st.x - 5.5 and x0 < st.x + 5.5 and z1 > st.fromZ - 1 then
				ok = false
			end
			for _, c in clear do
				local px = math.clamp(c[1], x0, x1)
				local pz = math.clamp(c[2], z0, z1)
				if (Vector3.new(px - c[1], 0, pz - c[2])).Magnitude < c[3] then
					ok = false
				end
			end
			if ok then
				table.insert(out, { centre = Vector3.new(x * S, raw.FLOOR * S, z * S), size = Vector3.new(tile * S, 0, dz * S) })
			end
		end
	end
	return out
end

-- Whether a guest stands on a tile (on the floor over it, not flying above it).
function AbuseParty.onTile(player: Player, t: Tile): boolean
	local root = AbuseParty.rootOf(player)
	if not root then
		return false
	end
	local p = root.Position
	local d = p - t.centre
	return math.abs(d.X) <= t.size.X / 2 + 0.6 and math.abs(d.Z) <= t.size.Z / 2 + 0.6 and d.Y > -1 and d.Y < 9
end

local function pay(player: Player, amount: number, why: string): number
	local data = Profiles.get(player)
	if not data or amount <= 0 then
		return 0
	end
	return Gilt.pay(player, data, amount, why)
end

---------------------------------------------------------------------------------------------------
-- The Gold Tile
---------------------------------------------------------------------------------------------------
local current: Tile? = nil
local currentUntil = 0

local function setTile(t: Tile?, untilAt: number?)
	current = t
	currentUntil = untilAt or 0
	Workspace:SetAttribute("PartyTile", if t then t.centre else nil)
	Workspace:SetAttribute("PartyTileSize", if t then t.size else nil)
	Workspace:SetAttribute("PartyTileUntil", untilAt)
end

-- One Gold Tile: lit now, paid out `window` seconds from now (unless the night ends first).
function AbuseParty.goldTile(t: Tile, window: number)
	setTile(t, os.time() + window)
	broadcast({ op = "partyTile", stage = "start", at = t.centre, seconds = window })
end

-- Time's up: everyone on it is paid.
function AbuseParty.closeTile(): { Player }
	local t = current
	setTile(nil, nil)
	if not t then
		return {}
	end
	local winners: { Player } = {}
	local names: { string } = {}
	for _, p in Players:GetPlayers() do
		if AbuseParty.onTile(p, t) and AbuseParty.trusted(p) then
			local paid = pay(p, cfg().tileGilt, "Admin Abuse · the Gold Tile")
			table.insert(winners, p)
			table.insert(names, Names.of(p))
			tell(p, { op = "partyPaid", what = "tile", gilt = paid })
		end
	end
	broadcast({ op = "partyTile", stage = "end", at = t.centre, winners = names, count = #winners })
	return winners
end

---------------------------------------------------------------------------------------------------
-- The Piñata
---------------------------------------------------------------------------------------------------
type Pinata = { model: Model, body: BasePart, needed: number, hits: number, hitters: { [Player]: number }, last: { [Player]: number }, expires: number }
local pinata: Pinata? = nil

-- Where it hangs: under the chandelier, over the runner, at a height every guest can reach.
function AbuseParty.pinataAt(): Vector3
	local raw = Layout.raw
	local S = Layout.SCALE
	return Vector3.new(0, (raw.FLOOR + 5) * S, 16 * S)
end

local function part(model: Model, name: string, size: Vector3, cf: CFrame, colour: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- The piñata: a golden star (a round body, six points tipped with paper pom-poms in party
-- colours), streamers hanging from it, on a gold cord up to the chandelier.
local function build(at: Vector3): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = AbuseParty.PINATA
	local rgb = Color3.fromRGB
	local body = part(m, "Body", Vector3.new(4.6, 4.6, 4.6), CFrame.new(at), rgb(246, 196, 72), Enum.PartType.Ball)
	body.Material = Enum.Material.Foil
	local tips = { rgb(255, 72, 140), rgb(70, 190, 255), rgb(120, 230, 110), rgb(255, 150, 50), rgb(190, 110, 255), rgb(255, 230, 90) }
	for i = 1, 6 do
		local a = (i - 1) * math.pi / 3
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		local mid = at + dir * 3.1
		part(m, "Point", Vector3.new(2.4, 1.1, 1.1), CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, math.pi / 2, 0), rgb(236, 176, 60), Enum.PartType.Cylinder)
		part(m, "Tassel", Vector3.new(1.3, 1.3, 1.3), CFrame.new(at + dir * 4.5), tips[i], Enum.PartType.Ball)
	end
	for i = 1, 5 do
		local x = (i - 3) * 0.7
		part(m, "Streamer", Vector3.new(0.25, 3.2, 0.05), CFrame.new(at + Vector3.new(x, -3.6, 0.6)), tips[i], nil)
	end
	local top = at.Y + 2.3
	-- (Up to the chandelier's lowest ring: the chandelier keeps its true size, grown in place.)
	local ceiling = Layout.Foyer.chandelier.Y - 1.2
	part(m, "Cord", Vector3.new(0.18, math.max(1, ceiling - top), 0.18), CFrame.new(at.X, (top + ceiling) / 2, at.Z), rgb(214, 170, 80), nil)
	m.PrimaryPart = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HitPrompt"
	prompt.ActionText = "Hit it"
	prompt.ObjectText = "The Piñata"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = cfg().reach
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Offset", 0)
	prompt.Parent = body
	return m, body
end

function AbuseParty.pinata(): Model?
	local p = pinata
	return if p then p.model else nil
end

-- A new piñata (the one before it, unbroken, goes).
function AbuseParty.hang(): Model
	local old = pinata
	if old then
		old.model:Destroy()
	end
	local c = cfg()
	local n = #Players:GetPlayers()
	local needed = math.clamp(c.hits.base + c.hits.perGuest * n, c.hits.base, c.hits.most)
	local at = AbuseParty.pinataAt()
	local model, body = build(at)
	model:SetAttribute("Hits", 0)
	model:SetAttribute("Needed", needed)
	model.Parent = Workspace
	local p: Pinata = { model = model, body = body, needed = needed, hits = 0, hitters = {}, last = {}, expires = os.time() + c.pinataSeconds }
	pinata = p
	local prompt = body:FindFirstChild("HitPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		pcall(function()
			prompt.Triggered:Connect(function(player: Player)
				AbuseParty.hit(player)
			end)
		end)
	end
	broadcast({ op = "pinata", stage = "hung", at = at, needed = needed, seconds = c.pinataSeconds })
	return model
end

local function burst(by: Player)
	local p = pinata
	if not p then
		return
	end
	pinata = nil
	local at = p.body.CFrame.Position
	p.model:Destroy()
	local c = cfg()
	local paidCount = 0
	for player in p.hitters do
		if player.Parent == Players then
			local amount = c.pinataGilt + (if player == by then c.pinataFinal else 0)
			local paid = pay(player, amount, "Admin Abuse · the Piñata")
			paidCount += 1
			tell(player, { op = "partyPaid", what = "pinata", gilt = paid, final = player == by })
		end
	end
	broadcast({ op = "pinata", stage = "burst", at = at, by = Names.of(by), count = paidCount })
end

-- A hit: in reach, not too fast, Admin Abuse still on. Returns whether it counted.
function AbuseParty.hit(player: Player): boolean
	local p = pinata
	if not p or not abusing() or not AbuseParty.trusted(player) then
		return false
	end
	local root = AbuseParty.rootOf(player)
	if not root or (root.Position - p.body.CFrame.Position).Magnitude > cfg().reach + 4 then
		return false
	end
	local now = os.clock()
	local last = p.last[player]
	if last and now - last < 1 / cfg().hitRate then
		return false
	end
	p.last[player] = now
	p.hits += 1
	p.hitters[player] = (p.hitters[player] or 0) + 1
	p.model:SetAttribute("Hits", p.hits)
	if p.hits >= p.needed then
		burst(player)
	end
	return true
end

local function letGo(quietly: boolean)
	local p = pinata
	if not p then
		return
	end
	pinata = nil
	local at = p.body.CFrame.Position
	p.model:Destroy()
	if not quietly then
		broadcast({ op = "pinata", stage = "away", at = at })
	end
end

---------------------------------------------------------------------------------------------------
-- The night
---------------------------------------------------------------------------------------------------
local runToken = 0

-- Admin Abuse (or Mega Abuse) has begun, `since` then: the Gold Tile and the Piñata at their
-- times, counted from when it began, while it's on.
function AbuseParty.began(mega: boolean, since: number?)
	runToken += 1
	local my = runToken
	local start = since or os.time()
	local c = cfg()
	local tileEvery = math.max(12, if mega then c.tileEvery.mega else c.tileEvery.abuse)
	local pinataEvery = math.max(30, if mega then c.pinataEvery.mega else c.pinataEvery.abuse)
	local tiles = AbuseParty.tiles()
	local rng = Random.new(start)
	task.spawn(function()
		local nextTile = start + c.tileFirst
		while nextTile < os.time() do
			nextTile += tileEvery
		end
		local nextPinata = start + c.pinataFirst
		while nextPinata < os.time() do
			nextPinata += pinataEvery
		end
		local lastTile = 0
		local hanging = false
		while runToken == my and abusing() do
			local now = os.time()
			if current and now >= currentUntil then
				AbuseParty.closeTile()
			end
			if not current and now >= nextTile and #tiles > 0 then
				nextTile = now + tileEvery
				local k = rng:NextInteger(1, #tiles)
				if k == lastTile then
					k = k % #tiles + 1
				end
				lastTile = k
				AbuseParty.goldTile(tiles[k], c.tileWindow)
			end
			-- (The next piñata comes `pinataEvery` seconds after the last one burst or floated away.)
			local p = pinata
			if p and now >= p.expires then
				letGo(false)
			end
			if hanging and not pinata then
				nextPinata = now + pinataEvery
			end
			hanging = pinata ~= nil
			if not pinata and now >= nextPinata then
				AbuseParty.hang()
				hanging = true
			end
			task.wait(0.25)
		end
		if runToken == my then
			setTile(nil, nil)
			letGo(true)
		end
	end)
end

-- Stopped (Stop everything): the tile and the piñata go at once.
function AbuseParty.stopped()
	runToken += 1
	setTile(nil, nil)
	letGo(true)
end

function AbuseParty.start()
	Players.PlayerRemoving:Connect(function(player)
		local p = pinata
		if p then
			p.hitters[player] = nil
			p.last[player] = nil
		end
	end)
end

return AbuseParty
