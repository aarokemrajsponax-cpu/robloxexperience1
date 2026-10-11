--!strict
-- Costumes for the holiday games' hosts, and Santa and his elves: hats, masks, capes, gowns and
-- beards made of parts and welded to a rig built by Staff/Rig (each sized from the rig's own head
-- and torso, so it fits whatever the rig turned out to be). Nothing here is ever frightening.

local Dress = {}

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local GOLD = rgb(226, 178, 74)
Dress.GOLD = GOLD

function Dress.attach(to: BasePart, name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material, shape: Enum.PartType?, mesh: boolean?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = to.CFrame * offset
	p.Color = colour
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if mesh then
		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.Sphere
		sm.Parent = p
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
	p.Parent = to
	return p
end


-- A long skirt from the waist to the floor (a ball gown, a robe), in stacked rounds.
function Dress.skirt(rig: Model, colour: Color3, hem: Color3, wide: number)
	local lower = rig:FindFirstChild("LowerTorso")
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not lower or not lower:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return
	end
	local hipY = lower.CFrame.Position.Y
	local floorY = root.CFrame.Position.Y - (rig:FindFirstChildOfClass("Humanoid") :: Humanoid).HipHeight - root.Size.Y / 2
	local height = hipY - floorY
	local tiers = 4
	for i = 0, tiers - 1 do
		local f = (i + 0.5) / tiers
		local d = lower.Size.X * (1.05 + f * wide)
		local y = hipY - height * f
		Dress.attach(lower, "Skirt", Vector3.new(height / tiers + 0.05, d, d), CFrame.new(0, y - hipY, 0) * CFrame.Angles(0, 0, math.pi / 2), colour, Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
	Dress.attach(lower, "Hem", Vector3.new(0.18, lower.Size.X * (1.08 + wide), lower.Size.X * (1.08 + wide)), CFrame.new(0, floorY + 0.12 - hipY, 0) * CFrame.Angles(0, 0, math.pi / 2), hem, Enum.Material.Fabric, Enum.PartType.Cylinder)
end

-- A tall pointed hat (a witch's, a wizard's): a brim and a cone, banded.
function Dress.pointedHat(head: BasePart, colour: Color3, band: Color3, height: number, brim: number)
	local hs = head.Size.Y
	Dress.attach(head, "HatBrim", Vector3.new(0.1, hs * brim, hs * brim), CFrame.new(0, hs * 0.48, 0) * CFrame.Angles(0, 0, math.pi / 2), colour, Enum.Material.Fabric, Enum.PartType.Cylinder)
	local tiers = 5
	for i = 0, tiers - 1 do
		local f = i / tiers
		local d = hs * (1.05 * (1 - f) + 0.12)
		local h = hs * height / tiers
		Dress.attach(head, "Hat", Vector3.new(h + 0.02, d, d), CFrame.new(0, hs * 0.52 + h * (i + 0.5), f * f * hs * 0.35) * CFrame.Angles(0, 0, math.pi / 2), colour, Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
	Dress.attach(head, "HatBand", Vector3.new(hs * 0.16, hs * 1.08, hs * 1.08), CFrame.new(0, hs * 0.62, 0) * CFrame.Angles(0, 0, math.pi / 2), band, Enum.Material.Fabric, Enum.PartType.Cylinder)
end

function Dress.topHat(head: BasePart, at: CFrame?)
	local hs = head.Size.Y
	local base = at or CFrame.new(0, hs * 0.5, 0)
	Dress.attach(head, "HatBrim", Vector3.new(0.1, hs * 1.6, hs * 1.6), base * CFrame.Angles(0, 0, math.pi / 2), rgb(16, 16, 18), Enum.Material.Fabric, Enum.PartType.Cylinder)
	Dress.attach(head, "Hat", Vector3.new(hs * 1.1, hs * 1.0, hs * 1.0), base * CFrame.new(0, hs * 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(16, 16, 18), Enum.Material.Fabric, Enum.PartType.Cylinder)
	Dress.attach(head, "HatBand", Vector3.new(hs * 0.2, hs * 1.02, hs * 1.02), base * CFrame.new(0, hs * 0.16, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(220, 110, 30), Enum.Material.Fabric, Enum.PartType.Cylinder)
end

function Dress.mask(head: BasePart, colour: Color3, feathers: number)
	local hs = head.Size.Y
	Dress.attach(head, "Mask", Vector3.new(hs * 1.06, hs * 0.3, 0.08), CFrame.new(0, hs * 0.1, -hs * 0.52), colour, Enum.Material.Foil)
	for _, sx in { -1, 1 } do
		Dress.attach(head, "MaskEye", Vector3.new(hs * 0.24, hs * 0.14, 0.04), CFrame.new(sx * hs * 0.22, hs * 0.1, -hs * 0.57), rgb(12, 10, 14), Enum.Material.SmoothPlastic, nil, true)
	end
	for k = 1, feathers do
		local a = math.rad(-20 + (k - 1) * 18)
		Dress.attach(head, "Feather", Vector3.new(0.08, hs * 1.1, hs * 0.3), CFrame.new(hs * 0.5, hs * 0.55, -hs * 0.35) * CFrame.Angles(0, 0, a), if k % 2 == 0 then rgb(90, 30, 120) else rgb(16, 14, 20), Enum.Material.Fabric, nil, true)
	end
end

function Dress.tiara(head: BasePart)
	local hs = head.Size.Y
	Dress.attach(head, "Tiara", Vector3.new(hs * 0.12, hs * 0.9, hs * 0.9), CFrame.new(0, hs * 0.45, 0.05) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
	for k = -1, 1 do
		Dress.attach(head, "TiaraPoint", Vector3.new(hs * 0.16, hs * 0.16, hs * 0.16), CFrame.new(k * hs * 0.22, hs * 0.62, -hs * 0.36 + math.abs(k) * hs * 0.06), rgb(240, 236, 255), Enum.Material.Glass, Enum.PartType.Ball)
	end
end

function Dress.cape(upper: BasePart, outside: Color3, lining: Color3, collar: boolean)
	local w, h = upper.Size.X, upper.Size.Y
	Dress.attach(upper, "Cape", Vector3.new(w * 1.25, h * 2.6, 0.12), CFrame.new(0, -h * 0.75, upper.Size.Z * 0.5 + 0.1), outside, Enum.Material.Fabric)
	Dress.attach(upper, "CapeLining", Vector3.new(w * 1.2, h * 2.5, 0.06), CFrame.new(0, -h * 0.72, upper.Size.Z * 0.5 + 0.02), lining, Enum.Material.Fabric)
	if collar then
		for _, sx in { -1, 1 } do
			Dress.attach(upper, "Collar", Vector3.new(w * 0.5, h * 0.8, 0.1), CFrame.new(sx * w * 0.38, h * 0.62, upper.Size.Z * 0.3) * CFrame.Angles(math.rad(-12), 0, sx * math.rad(18)), lining, Enum.Material.Fabric)
		end
	end
end


-- Sits a rig down where it stands (its hips and knees bent): Santa on his sleigh.
function Dress.sit(rig: Model)
	for _, name in { "LeftHip", "RightHip" } do
		local joint = rig:FindFirstChild(name, true)
		if joint and joint:IsA("Motor6D") then
			joint.C0 = joint.C0 * CFrame.Angles(math.rad(90), 0, 0)
		end
	end
	for _, name in { "LeftKnee", "RightKnee" } do
		local joint = rig:FindFirstChild(name, true)
		if joint and joint:IsA("Motor6D") then
			joint.C0 = joint.C0 * CFrame.Angles(math.rad(-90), 0, 0)
		end
	end
end

-- Father Christmas: a white beard and moustache, a red hat trimmed in white with its pompom,
-- white fur at the cuffs and hem, a black belt with a gold buckle.
function Dress.santa(rig: Model)
	local head = rig:FindFirstChild("Head")
	local upper = rig:FindFirstChild("UpperTorso")
	local lower = rig:FindFirstChild("LowerTorso")
	if not head or not head:IsA("BasePart") then
		return
	end
	local hs = head.Size.Y
	local fur = rgb(246, 244, 240)
	Dress.attach(head, "Beard", Vector3.new(hs * 1.05, hs * 1.15, hs * 0.6), CFrame.new(0, -hs * 0.55, -hs * 0.3), fur, Enum.Material.Fabric, nil, true)
	Dress.attach(head, "Moustache", Vector3.new(hs * 0.8, hs * 0.22, hs * 0.3), CFrame.new(0, -hs * 0.12, -hs * 0.5), fur, Enum.Material.Fabric, nil, true)
	for _, sx in { -1, 1 } do
		Dress.attach(head, "Brow", Vector3.new(hs * 0.3, hs * 0.1, hs * 0.1), CFrame.new(sx * hs * 0.2, hs * 0.22, -hs * 0.5), fur, Enum.Material.Fabric, nil, true)
	end
	Dress.attach(head, "HatFur", Vector3.new(hs * 0.3, hs * 1.12, hs * 1.12), CFrame.new(0, hs * 0.44, 0) * CFrame.Angles(0, 0, math.pi / 2), fur, Enum.Material.Fabric, Enum.PartType.Cylinder)
	local tiers = 4
	for i = 0, tiers - 1 do
		local f = i / tiers
		Dress.attach(head, "Hat", Vector3.new(hs * 0.32, hs * (1.0 - f * 0.75), hs * (1.0 - f * 0.75)), CFrame.new(f * hs * 0.32, hs * (0.66 + i * 0.26), f * hs * 0.2) * CFrame.Angles(0, 0, math.pi / 2 - f * 0.5), rgb(196, 24, 36), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
	Dress.attach(head, "Pompom", Vector3.new(hs * 0.34, hs * 0.34, hs * 0.34), CFrame.new(hs * 0.5, hs * 1.55, hs * 0.3), fur, Enum.Material.Fabric, Enum.PartType.Ball)
	if lower and lower:IsA("BasePart") then
		Dress.attach(lower, "Belt", Vector3.new(lower.Size.X * 1.08, lower.Size.Y * 0.45, lower.Size.Z * 1.12), CFrame.new(0, lower.Size.Y * 0.3, 0), rgb(18, 16, 16), Enum.Material.Leather)
		Dress.attach(lower, "Buckle", Vector3.new(lower.Size.X * 0.36, lower.Size.Y * 0.4, 0.1), CFrame.new(0, lower.Size.Y * 0.3, -lower.Size.Z * 0.58), GOLD, Enum.Material.Metal)
	end
	if upper and upper:IsA("BasePart") then
		Dress.attach(upper, "FurTrim", Vector3.new(upper.Size.X * 0.24, upper.Size.Y * 1.02, 0.12), CFrame.new(0, 0, -upper.Size.Z * 0.52), fur, Enum.Material.Fabric)
		Dress.attach(upper, "Belly", Vector3.new(upper.Size.X * 1.06, upper.Size.Y * 0.9, upper.Size.Z * 1.5), CFrame.new(0, -upper.Size.Y * 0.18, -upper.Size.Z * 0.12), rgb(196, 24, 36), Enum.Material.Fabric, nil, true)
	end
	for _, name in { "LeftHand", "RightHand" } do
		local hand = rig:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			Dress.attach(hand, "Cuff", Vector3.new(hand.Size.X * 1.3, hand.Size.Y * 0.4, hand.Size.Z * 1.3), CFrame.new(0, hand.Size.Y * 0.45, 0), fur, Enum.Material.Fabric)
		end
	end
end

-- An elf: a green pointed hat with a gold bell, a red collar of points, curled shoes.
function Dress.elf(rig: Model)
	local head = rig:FindFirstChild("Head")
	local upper = rig:FindFirstChild("UpperTorso")
	if not head or not head:IsA("BasePart") then
		return
	end
	local hs = head.Size.Y
	Dress.pointedHat(head, rgb(30, 120, 60), rgb(200, 30, 40), 1.5, 1.3)
	Dress.attach(head, "HatBell", Vector3.new(hs * 0.28, hs * 0.28, hs * 0.28), CFrame.new(0, hs * 2.1, hs * 0.5), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
	for _, sx in { -1, 1 } do
		Dress.attach(head, "Ear", Vector3.new(hs * 0.1, hs * 0.32, hs * 0.22), CFrame.new(sx * hs * 0.55, hs * 0.1, 0) * CFrame.Angles(0, 0, sx * math.rad(-50)), rgb(240, 200, 170), Enum.Material.SmoothPlastic, nil, true)
	end
	if upper and upper:IsA("BasePart") then
		for k = -2, 2 do
			Dress.attach(upper, "Collar", Vector3.new(upper.Size.X * 0.22, upper.Size.Y * 0.3, 0.12), CFrame.new(k * upper.Size.X * 0.2, upper.Size.Y * 0.36, -upper.Size.Z * 0.52) * CFrame.Angles(0, 0, math.rad(45)), if k % 2 == 0 then rgb(200, 30, 40) else WHITE, Enum.Material.Fabric)
		end
	end
	for _, name in { "LeftFoot", "RightFoot" } do
		local foot = rig:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			Dress.attach(foot, "Curl", Vector3.new(foot.Size.X * 0.6, foot.Size.X * 0.6, foot.Size.Z * 0.6), CFrame.new(0, foot.Size.Y * 0.5, -foot.Size.Z * 0.62), rgb(200, 30, 40), Enum.Material.Fabric, Enum.PartType.Ball)
		end
	end
end


return Dress
