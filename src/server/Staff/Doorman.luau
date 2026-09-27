--!strict
-- The Doorman stands on the top step. Clients open the doors and hear "Evening." as they approach.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Rig = require(script.Parent.Rig)

local Doorman = {}

function Doorman.spawn(parent: Instance)
	local z = Layout.Street.facadeZ - 1.1
	local pos = Vector3.new(Layout.Door.width / 2 + 1.8, Layout.FLOOR, z)
	local home = CFrame.lookAt(pos, pos + Vector3.new(-0.35, 0, -1))
	local s = Rig.build("Doorman", Rig.look("Doorman"), home, parent)
	s.model:SetAttribute("Staff", "Doorman")
	return s
end

return Doorman
