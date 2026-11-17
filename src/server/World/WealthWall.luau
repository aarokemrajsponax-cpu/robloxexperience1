--!strict
-- (Build 93) The Wealthiest boards on the Foyer's back wall, built at the grown size (World/Build,
-- after the Grand Scale) so they stand tall in the grown room: high either side of the Grand
-- Stair, over the Vault's door and the Boutique's, facing the front door. Each is a black lacquer
-- backplate in a brass frame under a brass cornice, lit by its own picture light; its face is
-- written by the server (server/WealthBoards: "In this house now" and "Of all time").

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout) -- the grown house
local Kit = require(script.Parent.Kit)

local WealthWall = {}

local L = Kit.Looks
local LACQUER: Kit.Look = { color = Color3.fromRGB(10, 10, 12), material = Enum.Material.SmoothPlastic, reflectance = 0.06 }

WealthWall.BOARDS = {
	{ kind = "wealthHere", name = "WealthHereBoard" },
	{ kind = "wealthAll", name = "WealthAllBoard" },
}

-- Where a board's face stands (its middle, its frame facing into the Foyer).
function WealthWall.frameOf(kind: string): CFrame
	local F = Layout.Foyer
	local at: Vector3 = if kind == "wealthHere" then F.wealthHere else F.wealthAll
	local wallZ = F.maxZ -- the back wall's face, in the grown room
	local p = Vector3.new(at.X, at.Y, wallZ - 0.2)
	return CFrame.lookAt(p, p - Vector3.new(0, 0, 1))
end

function WealthWall.build(root: Instance): { BasePart }
	local F = Layout.Foyer
	local w, h = F.wealthW, F.wealthH -- (numbers in Layout grow with the house)
	local model = Kit.model(root, "WealthWall")
	local faces: { BasePart } = {}
	for _, b in WealthWall.BOARDS do
		local cf = WealthWall.frameOf(b.kind)
		local m = Kit.model(model, b.name)
		Kit.part(m, "Backplate", Vector3.new(w + 2.6, h + 2.6, 0.4), cf, LACQUER)
		Kit.part(m, "Frame", Vector3.new(w + 1.2, h + 1.2, 0.5), cf * CFrame.new(0, 0, -0.3), L.brass)
		local face = Kit.part(m, "Face", Vector3.new(w, h, 0.2), cf * CFrame.new(0, 0, -0.6), L.ink)
		face:SetAttribute("Board", b.name)
		face:SetAttribute("Kind", b.kind)
		CollectionService:AddTag(face, "MaisonBoard")
		table.insert(faces, face)
		-- The cornice over it, and a picture light hung from it.
		Kit.part(m, "Cornice", Vector3.new(w + 3.4, 0.9, 1.4), cf * CFrame.new(0, h / 2 + 1.75, -0.5), L.brass)
		Kit.part(m, "CorniceShadow", Vector3.new(w + 2.8, 0.25, 1.1), cf * CFrame.new(0, h / 2 + 1.2, -0.45), LACQUER, { collide = false })
		local lamp = Kit.part(m, "PictureLight", Vector3.new(w * 0.6, 0.35, 0.5), cf * CFrame.new(0, h / 2 + 0.95, -1.9), L.brass, { collide = false, query = false })
		for _, x in { -w * 0.22, w * 0.22 } do
			Kit.part(m, "LampArm", Vector3.new(0.16, 0.16, 1.4), cf * CFrame.new(x, h / 2 + 1.0, -1.2), L.brass, { collide = false, query = false, shadow = false })
		end
		Kit.spotLight(lamp, Enum.NormalId.Bottom, 1.8, h + 6, 80)
		-- A plinth-like ledge under it, so it reads as part of the wall.
		Kit.part(m, "Ledge", Vector3.new(w + 3, 0.6, 1), cf * CFrame.new(0, -h / 2 - 1.6, -0.4), L.brass)
	end
	return faces
end

return WealthWall
