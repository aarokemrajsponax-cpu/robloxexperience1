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
