--!strict
-- Builds the Maison into the Workspace when the server starts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Flush = require(script.Parent.Flush)
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

local Build = {}

-- A black marble sill across a doorway's wall, a hair above the floors either side and running
-- just onto them (so no seam shows), edged with brass where it meets each floor.
local function sill(parent: Instance, d: Layout.Doorway)
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

function Build.run(): Folder
	local existing = Workspace:FindFirstChild("Maison")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Maison"
	Street.build(root)
	Foyer.build(root)
	Salon.build(root)
	Velvet.build(root)
	Obsidian.build(root)
	Midnight.build(root)
	Library.build(root)
	Ballroom.build(root)
	BoutiqueRoom.build(root)
	VaultRoom.build(root)
	Terrace.build(root)
	SuiteRoom.build(root)
	local sills = Kit.folder(root, "Sills")
	for _, d in Layout.Doorways do
		if d.sill then
			sill(sills, d)
		end
	end
	-- Surfaces laid flush in one plane flicker as the camera moves: lift each clear.
	Flush.settle(root)
	root.Parent = Workspace
	return root
end

return Build
