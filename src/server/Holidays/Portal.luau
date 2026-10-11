--!strict
-- The way home from a holiday place: an archway of black iron with gold finials, a warm light
-- hanging in it like a curtain, and over it, in gold on black, BACK TO THE MAISON. Walk up and press
-- (or walk through the light): home. The light is the part the prompt hangs on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Kit = require(script.Parent.Parent.World.Kit)

local Portal = {}

local rgb = Color3.fromRGB
local L = Kit.Looks
local GOLD = rgb(226, 178, 74)

-- `cf`: the archway's middle on the ground, facing the way a guest walks through it. `place`: the
-- place's name (on the prompt). `use`: what happens when a guest asks to go (the server's own check
-- that they're in the place comes first, in `use`).
function Portal.build(parent: Instance, cf: CFrame, place: string, use: (player: Player) -> ()): BasePart
	local width, height = 10, 12
	local m = Kit.model(parent, "WayHomeArch")
	-- The posts, each with a gold finial.
	for _, sx in { -1, 1 } do
		local at = (cf * CFrame.new(sx * (width / 2 + 0.7), 0, 0)).Position
		Kit.post(m, "Post", height + 0.6, 1.4, at, L.blackLacquer)
		Kit.part(m, "PostFoot", Vector3.new(2.2, 0.8, 2.2), CFrame.new(at + Vector3.new(0, 0.4, 0)), L.blackLacquer, { shadow = false })
		HolidayProps.ball(m, "Finial", 1.1, at + Vector3.new(0, height + 1.5, 0), GOLD, Enum.Material.Metal)
	end
	-- The arch over them, in iron.
	local segs = 12
	local r = width / 2 + 0.7
	for k = 0, segs - 1 do
		local a0 = math.pi * k / segs
		local a1 = math.pi * (k + 1) / segs
		local p0 = (cf * CFrame.new(math.cos(a0) * r, height + 0.3 + math.sin(a0) * 3.2, 0)).Position
		local p1 = (cf * CFrame.new(math.cos(a1) * r, height + 0.3 + math.sin(a1) * 3.2, 0)).Position
		HolidayProps.rod(m, "Arch", p0, p1, 0.45, rgb(14, 14, 16), Enum.Material.Metal)
	end
	-- The sign, read from both sides.
	local board = Kit.part(m, "Sign", Vector3.new(width - 1, 1.7, 0.3), cf * CFrame.new(0, height - 0.6, 0), L.blackLacquer, { collide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Kit.engrave(board, face, {
			{ text = "BACK TO THE MAISON", size = 0.62, font = Brand.Fonts.display, color = rgb(255, 214, 140) },
		}, { ppu = 60, lit = false, brightness = 1.6, maxDistance = 160 })
	end
	-- The light, hanging in the arch.
	local veil = Kit.part(m, "WayHome", Vector3.new(width, height - 1.6, 0.3), cf * CFrame.new(0, (height - 1.6) / 2, 0), { color = rgb(255, 214, 140), material = Enum.Material.Neon, transparency = 0.62 }, { collide = false, shadow = false })
	veil.CanQuery = true
	Kit.pointLight(veil, 1.4, 22, rgb(255, 210, 150))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WayHome"
	prompt.ActionText = "Back to the Maison"
	prompt.ObjectText = place
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = veil
	prompt.Triggered:Connect(use)
	return veil
end

return Portal
