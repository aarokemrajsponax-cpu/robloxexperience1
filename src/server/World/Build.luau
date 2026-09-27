--!strict
-- Builds the Maison into the Workspace when the server starts.

local Workspace = game:GetService("Workspace")

local Street = require(script.Parent.Street)
local Foyer = require(script.Parent.Foyer)
local Salon = require(script.Parent.Salon)

local Build = {}

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
	root.Parent = Workspace
	return root
end

return Build
