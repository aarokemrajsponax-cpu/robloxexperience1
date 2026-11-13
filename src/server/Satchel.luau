--!strict
-- The Satchel: what a guest carries, as real items in their Roblox inventory (the hotbar).
--   * the Executive Suite's stun pistol, once it's taken from the Quartermaster: carried
--     everywhere, but it only fires in the Suite's fight (every shot is still the Suite's to
--     judge, server-side, through the same AttractionFire it always used);
--   * a decoy, while one is packed for the next run or carried in this one: thrown only in the
--     Suite's hallway (through the Suite's own "decoy" request);
--   * the brainrots in the guest's squad, then their starred curios, rarest first: held up for
--     everyone near to see, and flexed (a burst over their head, in the style of the Victory
--     Flourish they wear, if any).
-- What the satchel holds is decided here from the guest's saved data, every time; a screen can
-- only ask to flex what the server already put in its hand, no more than once every few seconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local BrainrotList = require(ReplicatedStorage.Shared.Brainrots)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Profiles = require(script.Parent.Profiles)
local Curios = require(script.Parent.Curios)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Satchel = {}

Satchel.FLEX_MOST = 7 -- flexable things in the hotbar (with the two pieces of gear: nine keys)
Satchel.COOLDOWN = 3 -- seconds between flexes
Satchel.REACH = 160 -- studs: who sees a flex

export type Carried = { sidearm: boolean, decoy: boolean }
export type Entry = {
	key: string,
	kind: "gear" | "flex",
	id: string,
	name: string,
	tip: string,
	rarity: string?,
	glyph: string?,
	mut: string?,
}

-- What the guest carries from the Executive Suite (set at boot to the Suite's own reading).
Satchel.carried = function(_player: Player): Carried
	return { sidearm = false, decoy = false }
end

-- The clock (a test can set it).
Satchel.now = function(): number
	return os.clock()
end

local lastFlex: { [any]: number } = {}
local pending: { [any]: boolean } = {}

local function squadIds(data: Profiles.Data): ({ string }, { [string]: string })
	local s = (Curios.bag(data) :: any).squad
	local ids: { string } = {}
	local mut: { [string]: string } = {}
	if type(s) == "table" and type(s.ids) == "table" then
		for _, id in s.ids do
			if type(id) == "string" and BrainrotList.is(id) and Curios.count(data, id) > 0 and not table.find(ids, id) then
				table.insert(ids, id)
			end
		end
		if type(s.mut) == "table" then
			for id, m in s.mut do
				if type(id) == "string" and type(m) == "string" and BrainrotList.Mutations[m] then
					mut[id] = m
				end
			end
		end
	end
	return ids, mut
end

local function flexEntry(id: string, mut: string?): Entry?
	local c = CurioList.byId[id]
	if not c then
		return nil
	end
	local m = if mut then (BrainrotList.Mutations :: any)[mut] else nil
	return {
		key = "flex:" .. id,
		kind = "flex",
		id = id,
		name = if m then string.format("%s %s", m.name, c.name) else c.name,
		tip = "Hold it up; click to flex it for everyone near you.",
		rarity = c.rarity :: string,
		glyph = c.glyph,
		mut = mut,
	} :: Entry
end

-- What belongs in the satchel, in hotbar order: the gear, then the squad, then starred curios
-- (rarest first), never more than FLEX_MOST to flex.
function Satchel.wanted(data: Profiles.Data, carried: Carried): { Entry }
	local out: { Entry } = {}
	if carried.sidearm then
		table.insert(out, { key = "gear:sidearm", kind = "gear", id = "sidearm", name = "Stun Pistol", tip = "Fires in the Executive Suite's fight only." })
	end
	if carried.decoy then
		table.insert(out, { key = "gear:decoy", kind = "gear", id = "decoy", name = "Decoy", tip = "Throw it in the Executive Suite's hallway: the guards watch it." })
	end
	local flex = 0
	local seen: { [string]: boolean } = {}
	local ids, mut = squadIds(data)
	for _, id in ids do
		local e = if flex < Satchel.FLEX_MOST then flexEntry(id, mut[id]) else nil
		if e then
			table.insert(out, e)
			seen[id] = true
			flex += 1
		end
	end
	local starred: { string } = {}
	local bag = Curios.bag(data)
	for id, on in bag.favs do
		if on == true and not seen[id] and Curios.count(data, id) > 0 and CurioList.byId[id] then
			table.insert(starred, id)
		end
	end
	table.sort(starred, function(a: string, b: string): boolean
		local ra = CurioList.RarityRank[CurioList.byId[a].rarity] or 0
		local rb = CurioList.RarityRank[CurioList.byId[b].rarity] or 0
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	for _, id in starred do
		if flex >= Satchel.FLEX_MOST then
			break
		end
		local e = flexEntry(id, nil)
		if e then
			table.insert(out, e)
			flex += 1
		end
	end
	return out
end

-- Whether a flex of `key` is allowed now: it's in the satchel and the last was long enough ago.
function Satchel.check(data: Profiles.Data, carried: Carried, key: unknown, last: number?, now: number): (Entry?, string?)
	if type(key) ~= "string" or #key > 60 then
		return nil, "malformed"
	end
	if last and now - last < Satchel.COOLDOWN then
		return nil, "soon"
	end
	for _, e in Satchel.wanted(data, carried) do
		if e.key == key and e.kind == "flex" then
			return e, nil
		end
	end
	return nil, "not held"
end

-- ---------------------------------------------------------------- the tools themselves

local rgb = Color3.fromRGB
local GRAPHITE = rgb(24, 25, 30)
local CHROME = rgb(196, 200, 210)
local GOLD = rgb(232, 196, 108)
local ICE = rgb(120, 220, 255)
local NEON = rgb(255, 70, 170)

local function piece(tool: Tool, handle: BasePart, name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Color = colour
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = handle.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = p
	w.Parent = p
	p.Parent = tool
	return p
end

local function handleOf(tool: Tool, size: Vector3, colour: Color3, material: Enum.Material, transparency: number): BasePart
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = size
	h.Color = colour
	h.Material = material
	h.Transparency = transparency
	h.CanCollide = false
	h.CanQuery = false
	h.CanTouch = false
	h.Massless = true
	h.CastShadow = false
	h.Parent = tool
	return h
end

local function pistol(tool: Tool)
	-- A graphite stun pistol with a chrome slide, a gold line along the top and an ice-neon muzzle.
	local h = handleOf(tool, Vector3.new(0.28, 0.8, 0.42), GRAPHITE, Enum.Material.SmoothPlastic, 0)
	piece(tool, h, "Slide", Vector3.new(0.32, 0.36, 1.45), CFrame.new(0, 0.52, -0.42), CHROME, Enum.Material.Metal)
	piece(tool, h, "Line", Vector3.new(0.34, 0.06, 1.2), CFrame.new(0, 0.72, -0.42), GOLD, Enum.Material.Metal)
	piece(tool, h, "Muzzle", Vector3.new(0.2, 0.2, 0.1), CFrame.new(0, 0.52, -1.18), ICE, Enum.Material.Neon)
	piece(tool, h, "Guard", Vector3.new(0.3, 0.08, 0.5), CFrame.new(0, 0.14, -0.38), GRAPHITE, Enum.Material.Metal)
	tool.Grip = CFrame.new(0, -0.1, 0)
end

local function decoy(tool: Tool)
	-- A hot-pink neon balloon on a chrome grip: what the guards can't stop looking at.
	local h = handleOf(tool, Vector3.new(0.22, 0.6, 0.22), CHROME, Enum.Material.Metal, 0)
	piece(tool, h, "String", Vector3.new(0.04, 1.1, 0.04), CFrame.new(0, 0.85, 0), CHROME, Enum.Material.SmoothPlastic)
	piece(tool, h, "Balloon", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 1.85, 0), NEON, Enum.Material.Neon, Enum.PartType.Ball)
	tool.Grip = CFrame.new(0, -0.2, 0)
end

local function medallion(tool: Tool, e: Entry)
	-- Held up in the hand: the curio itself, on a disc in its rarity's colour, facing whoever looks.
	local h = handleOf(tool, Vector3.new(0.3, 0.3, 0.3), GOLD, Enum.Material.Metal, 1)
	local colour = (CurioList.RarityColour :: any)[e.rarity or ""] or GOLD
	local mut = if e.mut then (BrainrotList.Mutations :: any)[e.mut] else nil
	local ring = if mut and typeof(mut.colour) == "Color3" then mut.colour else colour
	local b = Instance.new("BillboardGui")
	b.Name = "Held"
	b.Size = UDim2.fromScale(2.1, 2.1)
	b.StudsOffset = Vector3.new(0, 1.15, 0)
	b.LightInfluence = 0
	b.MaxDistance = 90
	b.ResetOnSpawn = false
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = rgb(14, 15, 19)
	disc.BackgroundTransparency = 0.08
	disc.BorderSizePixel = 0
	disc.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = disc
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = ring
	stroke.Parent = disc
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(0.74, 0.74)
	glyph.Position = UDim2.fromScale(0.13, 0.13)
	glyph.Text = e.glyph or "✦"
	glyph.TextScaled = true
	glyph.TextColor3 = rgb(255, 255, 255)
	glyph.Font = Enum.Font.GothamBold
	glyph.Parent = disc
	b.Parent = h
	tool.Grip = CFrame.new(0, 0, 0)
end

local function make(e: Entry): Tool
	local tool = Instance.new("Tool")
	tool.Name = e.name
	tool.ToolTip = e.tip
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("SatchelKey", e.key)
	tool:SetAttribute("SatchelKind", e.kind)
	tool:SetAttribute("SatchelId", e.id)
	if e.rarity then
		tool:SetAttribute("Rarity", e.rarity)
	end
	if e.glyph then
		tool:SetAttribute("Glyph", e.glyph)
	end
	if e.mut then
		tool:SetAttribute("Mutation", e.mut)
	end
	local gear = e.kind == "gear"
	if gear and e.id == "sidearm" then
		pistol(tool)
	elseif gear and e.id == "decoy" then
		decoy(tool)
	else
		medallion(tool, e)
	end
	return tool
end
Satchel.make = make

-- Puts the satchel right: what's wanted and not there is added, what's there and not wanted
-- (or there twice) goes. Tools in the guest's hand count as theirs.
function Satchel.reconcile(player: Player)
	local data = Profiles.get(player)
	if not data or typeof(player) ~= "Instance" then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local want = Satchel.wanted(data, Satchel.carried(player))
	local byKey: { [string]: Entry } = {}
	for _, e in want do
		byKey[e.key] = e
	end
	local have: { [string]: Tool } = {}
	local holders: { Instance } = { backpack }
	if player.Character then
		table.insert(holders, player.Character :: Instance)
	end
	for _, holder in holders do
		do
			for _, t in holder:GetChildren() do
				local key = if t:IsA("Tool") then t:GetAttribute("SatchelKey") else nil
				if type(key) == "string" then
					local e = byKey[key]
					if have[key] or not e or t.Name ~= e.name then
						t:Destroy()
					else
						have[key] = t :: Tool
					end
				end
			end
		end
	end
	for _, e in want do
		if not have[e.key] then
			make(e).Parent = backpack
		end
	end
end

-- Asks for a reconcile soon (several changes at once make one).
function Satchel.refresh(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		if typeof(player) == "Instance" and player.Parent then
			local ok, err = pcall(function()
				Satchel.reconcile(player)
			end)
			if not ok then
				warn("[Maison] The satchel didn't pack: " .. tostring(err))
			end
		end
	end)
end

local function holding(player: Player, key: string): BasePart?
	local character = player.Character
	if typeof(character) ~= "Instance" then
		return nil
	end
	character = character :: Model
	for _, t in character:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("SatchelKey") == key then
			local head = character:FindFirstChild("Head")
			return if head and head:IsA("BasePart") then head else nil
		end
	end
	return nil
end

-- A flex: checked, then shown to everyone near.
function Satchel.flex(player: Player, key: unknown): boolean
	local data = Profiles.get(player)
	if not data then
		return false
	end
	local now = Satchel.now()
	local e, why = Satchel.check(data, Satchel.carried(player), key, lastFlex[player], now)
	if not e then
		if why == "malformed" or why == "not held" then
			RemoteGuard.reject(player, "satchel", why :: string)
		end
		return false
	end
	local head = holding(player, e.key)
	if not head then
		return false
	end
	lastFlex[player] = now
	local worn = (data :: any).equipped and (data :: any).equipped.flourish
	local style = if type(worn) == "string" and worn ~= "" then Wardrobe.get(worn) else nil
	local message = {
		op = "flex",
		userId = player.UserId,
		id = e.id,
		name = e.name,
		rarity = e.rarity,
		glyph = e.glyph,
		mut = e.mut,
		flourish = if style then style.id else nil,
	}
	local remote = Remotes.event("Satchel")
	local at = head.Position
	for _, other in Players:GetPlayers() do
		local c = other.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if other == player or (root and root:IsA("BasePart") and (root.Position - at).Magnitude <= Satchel.REACH) then
			remote:FireClient(other, message)
		end
	end
	return true
end

function Satchel.start()
	RemoteGuard.event(Remotes.event("Satchel"), "satchel", function(player: Player, request: unknown)
		local r = RemoteGuard.message(request, 2, 0)
		if not r or r.op ~= "flex" then
			RemoteGuard.reject(player, "satchel", "malformed")
			return
		end
		Satchel.flex(player, r.key)
	end)
	local function hello(player: Player)
		if typeof(player) ~= "Instance" then
			return
		end
		player.CharacterAdded:Connect(function()
			task.defer(function()
				-- (A new body has a new Backpack: wait for it, then pack.)
				local backpack = player:WaitForChild("Backpack", 10)
				if backpack and player.Parent then
					Satchel.refresh(player)
				end
			end)
		end)
		task.spawn(function()
			if Profiles.wait(player, 30) and player.Parent then
				Satchel.refresh(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hello)
	for _, p in Players:GetPlayers() do
		hello(p)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastFlex[player] = nil
		pending[player] = nil
	end)
end

return Satchel
