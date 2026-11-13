--!strict
-- Builds the Maison into the Workspace when the server starts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Breathe = require(ReplicatedStorage.Shared.Breathe)
local LayoutModule = require(ReplicatedStorage.Shared.Layout)
local Layout = LayoutModule.raw -- (the house as drawn: see World/Grand)
local Flush = require(script.Parent.Flush)
local Grand = require(script.Parent.Grand)
local Kit = require(script.Parent.Kit)

local Street = require(script.Parent.Street)
local Circuit = require(script.Parent.Circuit)
local Foyer = require(script.Parent.Foyer)
local Salon = require(script.Parent.Salon)
local Velvet = require(script.Parent.Velvet)
local Obsidian = require(script.Parent.Obsidian)
local Midnight = require(script.Parent.Midnight)
local Library = require(script.Parent.Library)
local Ballroom = require(script.Parent.Ballroom)
local BoutiqueRoom = require(script.Parent.Boutique)
local VaultRoom = require(script.Parent.Vault)
local Terrace = require(script.Parent.Terrace)
local SuiteRoom = require(script.Parent.Suite)
local SuiteFinish = require(script.Parent.SuiteFinish)
local Passages = require(script.Parent.Passages)
local Lobbies = require(script.Parent.Lobbies)

local Build = {}

-- A black marble sill across a doorway's wall, a hair above the floors either side and running
-- just onto them (so no seam shows), edged with brass where it meets each floor.
local function sill(parent: Instance, d: LayoutModule.Doorway)
	local wall = d.wall :: { number }
	local a, b = wall[1] - 0.15, wall[2] + 0.15
	local half = d.width / 2 + 0.6
	local c = d.centre
	local y = d.floorY
	local function box(name: string, from: number, to: number, y0: number, y1: number, look: Kit.Look, opts: { [string]: any }?)
		if d.axis == "x" then
			Kit.span(parent, name, Vector3.new(from, y0, c.Z - half), Vector3.new(to, y1, c.Z + half), look, opts)
		else
			Kit.span(parent, name, Vector3.new(c.X - half, y0, from), Vector3.new(c.X + half, y1, to), look, opts)
		end
	end
	box("Sill", a, b, y - 1, y + 0.05, Kit.Looks.blackMarble)
	local trim = { collide = false, query = false, shadow = false }
	box("SillEdge", a, a + 0.12, y + 0.05, y + 0.08, Kit.Looks.brass, trim)
	box("SillEdge", b - 0.12, b, y + 0.05, y + 0.08, Kit.Looks.brass, trim)
end

export type Options = {
	-- Put the house up as soon as it's built and do the flicker fix just after (guests can
	-- spawn meanwhile: it moves a few thousand surfaces by a hair, nothing anyone sees move).
	polishLater: boolean?,
}

-- The house's lamps arrive with the house. The world streams in by distance, so on a guest's
-- first seconds a room's far lamps could arrive after its walls (a dark room that lights up a few
-- seconds later). Each lamp's own fixture (a chandelier, a sconce, a standard lamp: a model no
-- more than FIXTURE_MOST studs across) is sent to every guest the moment they join and never
-- streamed away. Returns how many lamps that covers, and how many there are.
local FIXTURE_MOST = 40
function Build.persistLamps(root: Instance): (number, number)
	local judged: { [Model]: boolean } = {}
	local covered, lamps = 0, 0
	for _, d in root:GetDescendants() do
		if d:IsA("Light") then
			lamps += 1
			local model = d:FindFirstAncestorWhichIsA("Model")
			if model and model ~= root then
				local keep = judged[model]
				if keep == nil then
					local lo, hi = nil :: Vector3?, nil :: Vector3?
					for _, p in model:GetDescendants() do
						if p:IsA("BasePart") then
							local ok, at, size = pcall(function()
								return p.CFrame.Position, p.Size
							end)
							if ok then
								local half = (size :: Vector3) / 2
								local a, b = (at :: Vector3) - half, (at :: Vector3) + half
								lo = if lo then lo:Min(a) else a
								hi = if hi then hi:Max(b) else b
							end
						end
					end
					local span = if lo and hi then hi - lo else Vector3.zero
					-- (A table is kept whole whatever its size: the game finds its lamp, the Bulb's
					-- TableLight, by name, to dim it, flicker it and dress it.)
					keep = math.max(span.X, span.Z) <= FIXTURE_MOST or model:GetAttribute("TableId") ~= nil
					judged[model] = keep
					if keep then
						pcall(function()
							model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
						end)
					end
				end
				if keep then
					covered += 1
					continue
				end
			end
			-- A lamp built into the room itself: its light moves onto an unseen copy of its lamp (the
			-- same name, place and size), in a small kept model in the same room, so it's still the
			-- room's own (the disco finds it, the season tints it) and the lamp itself is untouched.
			local part = d.Parent
			local room = d:FindFirstAncestorWhichIsA("Model") or (part and part.Parent)
			if part and part:IsA("BasePart") and room then
				local holder = room:FindFirstChild("Lamplight")
				if not (holder and holder:IsA("Model")) then
					local m = Instance.new("Model")
					m.Name = "Lamplight"
					pcall(function()
						m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
					end)
					m.Parent = room
					holder = m
				end
				local carrier = Instance.new("Part")
				carrier.Name = part.Name
				carrier.Anchored = true
				carrier.CanCollide = false
				carrier.CanQuery = false
				carrier.CanTouch = false
				carrier.CastShadow = false
				carrier.Transparency = 1
				carrier.Size = part.Size
				carrier.CFrame = part.CFrame
				carrier.Parent = holder
				d.Parent = carrier
				covered += 1
			end
		end
	end
	return covered, lamps
end

function Build.run(options: Options?): Folder
	local existing = Workspace:FindFirstChild("Maison")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Maison"
	-- Each part of the house is built on its own: one that fails is reported in Output and the
	-- rest of the house still stands.
	local function step(name: string, fn: () -> ())
		local ok, err = pcall(fn :: any)
		if not ok then
			warn(string.format("[Maison] Building %s failed: %s", name, tostring(err)))
		end
		Breathe.now() -- (see Breathe: the script timeout)
	end
	step("the Street", function() Street.build(root) end)
	step("the Foyer", function() Foyer.build(root) end)
	step("the Salon", function() Salon.build(root) end)
	step("the Velvet Room", function() Velvet.build(root) end)
	step("the Obsidian Room", function() Obsidian.build(root) end)
	step("the Midnight Room", function() Midnight.build(root) end)
	step("the Library", function() Library.build(root) end)
	step("the Ballroom", function() Ballroom.build(root) end)
	step("the Boutique", function() BoutiqueRoom.build(root) end)
	step("the Vault", function() VaultRoom.build(root) end)
	step("the Terrace", function() Terrace.build(root) end)
	step("the Suite", function() SuiteRoom.build(root) end)
	step("the Vault door and the lift", function() Passages.build(root) end)
	step("the doorway sills", function()
		local sills = Kit.folder(root, "Sills")
		for _, d in Layout.Doorways do
			if d.sill then
				sill(sills, d)
			end
		end
	end)
	-- The Grand Scale: every room opened out, the furniture moved with it (World/Grand).
	step("the Grand Scale", function() Grand.apply(root, require(ReplicatedStorage.Shared.Layout).SCALE) end)
	-- Built at the grown size: the Suite's fireplace and its front doors.
	step("the Suite's fireplace and doors", function() SuiteFinish.build(root) end)
	-- Built at the grown size: the attractions' rooms off the Foyer (their entrances, the Luxe
	-- Lounge's treadmills).
	step("the attractions' rooms", function() Lobbies.build(root) end)
	-- The Grand Prix's circuit, on the street (laid at the grown size).
	step("the Grand Prix circuit", function() Circuit.build(root) end)
	step("the lamps, kept on every screen", function()
		Build.persistLamps(root)
	end)
	-- Surfaces laid flush in one plane flicker as the camera moves: lift each clear.
	local function polish()
		step("the flicker fix", function() Flush.settle(root) end)
	end
	if options and options.polishLater then
		root.Parent = Workspace
		task.spawn(polish)
	else
		polish()
		root.Parent = Workspace
	end
	return root
end

return Build
