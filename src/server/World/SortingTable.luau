--!strict
-- One sorting table, shared by all four rooms: the top and felt, six smoked-glass cases with
-- engraved plates, the brass counter and multiplier dial, the clock rail, the chair with its
-- prompts, and the room's own lamp. Each room passes its style.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local T = Layout.Table

local SortingTable = {}

export type Style = {
	roomName: string,
	top: Kit.Look, -- the table's edge
	legs: Kit.Look,
	felt: Kit.Look,
	caseBase: Kit.Look,
	caseRim: Kit.Look,
	chair: Kit.Look,
	lamp: "pendant" | "cord" | "key" | "single",
	lampColor: Color3,
	lampBrightness: number,
	ceiling: number, -- the room's ceiling height (world Y), for cords
}

-- The camera looks down at the table from above the chair; plates and the counter face it.
local TOWARD_CAMERA = Vector3.new(0, 0.9, -0.42).Unit
local UP_TOWARD_CASES = Vector3.new(0, 0, 1)

local function casePlate(parent: Model, index: number, caseId: string, centre: Vector3)
	local case = Catalogue.caseById[caseId]
	local c = Layout.caseCentre(centre, index)
	local pos = c + Vector3.new(0, 0.12, -T.caseDepth / 2 - 0.28)
	local plate = Kit.part(parent, "CasePlate" .. index, Vector3.new(T.caseWidth - 0.16, 0.42, 0.05), CFrame.lookAt(pos, pos + TOWARD_CAMERA, UP_TOWARD_CASES), L.brass, { collide = false, shadow = false })
	Kit.engrave(plate, Enum.NormalId.Front, {
		{ text = string.upper(case.name), size = 0.52, font = Brand.Fonts.display, color = Color3.fromRGB(34, 26, 10) },
		{ text = case.subtitle, size = 0.3, font = Brand.Fonts.body, color = Color3.fromRGB(56, 42, 16) },
	}, { ppu = 120, brightness = 1, maxDistance = 40 })
end

local function smokedCase(parent: Model, index: number, centre: Vector3, style: Style)
	local caseId = Catalogue.Cases[index].id
	local c = Layout.caseCentre(centre, index)
	local w, d = T.caseWidth, T.caseDepth
	local h = 0.55
	local glass = L.smokedGlass
	local base = Kit.part(parent, "Case" .. index, Vector3.new(w, 0.12, d), CFrame.new(c + Vector3.new(0, 0.06, 0)), style.caseBase)
	base:SetAttribute("CaseId", caseId)
	base:SetAttribute("Index", index)
	CollectionService:AddTag(base, "MaisonCase")
	Kit.part(parent, "CaseWallN", Vector3.new(w, h, 0.06), CFrame.new(c + Vector3.new(0, h / 2, d / 2)), glass, { collide = false, shadow = false })
	Kit.part(parent, "CaseWallS", Vector3.new(w, h * 0.6, 0.06), CFrame.new(c + Vector3.new(0, h * 0.3, -d / 2)), glass, { collide = false, shadow = false })
	Kit.part(parent, "CaseWallW", Vector3.new(0.06, h, d), CFrame.new(c + Vector3.new(-w / 2, h / 2, 0)), glass, { collide = false, shadow = false })
	Kit.part(parent, "CaseWallE", Vector3.new(0.06, h, d), CFrame.new(c + Vector3.new(w / 2, h / 2, 0)), glass, { collide = false, shadow = false })
	-- Gold only on the edges
	Kit.part(parent, "CaseRimN", Vector3.new(w + 0.06, 0.05, 0.08), CFrame.new(c + Vector3.new(0, h, d / 2)), style.caseRim, { collide = false, shadow = false })
	Kit.part(parent, "CaseRimW", Vector3.new(0.08, 0.05, d), CFrame.new(c + Vector3.new(-w / 2, h, 0)), style.caseRim, { collide = false, shadow = false })
	Kit.part(parent, "CaseRimE", Vector3.new(0.08, 0.05, d), CFrame.new(c + Vector3.new(w / 2, h, 0)), style.caseRim, { collide = false, shadow = false })
	-- The inner glow, lit once by the client when a piece is filed correctly
	local glow = Kit.part(parent, "CaseGlow" .. index, Vector3.new(w - 0.2, 0.04, d - 0.2), CFrame.new(c + Vector3.new(0, 0.14, 0)), { color = Brand.Colours.lightGold, material = Enum.Material.Neon, transparency = 1 }, { collide = false, shadow = false, query = false })
	local light = Instance.new("PointLight")
	light.Enabled = false
	light.Brightness = 0
	light.Range = 5
	light.Color = Brand.Colours.lightGold
	light.Parent = glow
	-- The lid, shown when this case is closed for the round
	local lid = Kit.part(parent, "CaseLid" .. index, Vector3.new(w, 0.06, d), CFrame.new(c + Vector3.new(0, h + 0.03, 0)), { color = Color3.fromRGB(20, 20, 24), material = Enum.Material.Glass, reflectance = 0.3, transparency = 1 }, { collide = false, shadow = false, query = false })
	lid:SetAttribute("CaseId", caseId)
	casePlate(parent, index, caseId, centre)
end

local function prompt(parent: Instance, name: string, action: string, object: string, key: Enum.KeyCode, pad: Enum.KeyCode, offset: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = key
	p.GamepadKeyCode = pad
	p.HoldDuration = 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Offset", offset)
	p.Parent = parent
	return p
end

local function lamp(model: Model, centre: Vector3, style: Style)
	local lampPos = centre + Vector3.new(0, T.lampY, 0.2)
	local bulb: Part
	if style.lamp == "key" then
		-- One hard key light from high above: a small black canister, almost invisible.
		local high = centre + Vector3.new(0, style.ceiling - centre.Y - 1.2, 0.2)
		Kit.part(model, "Lamp", Vector3.new(0.9, 1.2, 0.9), CFrame.new(high), L.blackLacquer, { collide = false, query = false })
		Kit.part(model, "LampRim", Vector3.new(0.95, 0.08, 0.95), CFrame.new(high - Vector3.new(0, 0.6, 0)), L.brass, { collide = false, query = false, shadow = false })
		bulb = Kit.part(model, "Bulb", Vector3.new(0.5, 0.1, 0.5), CFrame.new(high - Vector3.new(0, 0.66, 0)), { color = Color3.fromRGB(255, 240, 220), material = Enum.Material.Neon }, { collide = false, shadow = false, query = false })
		local down = Kit.spotLight(bulb, Enum.NormalId.Bottom, style.lampBrightness, (high.Y - centre.Y) + 6, 32, style.lampColor)
		down.Name = "TableLight"
		return
	end
	if style.lamp == "single" then
		-- The Midnight Room: one small brass lamp on the table itself.
		local base = centre + Vector3.new(-4.6, T.topY, 3.1)
		Kit.part(model, "LampFoot", Vector3.new(0.7, 0.12, 0.7), CFrame.new(base + Vector3.new(0, 0.06, 0)), L.brass, { collide = false })
		Kit.post(model, "LampStem", 1.8, 0.1, base, L.brass, { collide = false })
		Kit.part(model, "Lamp", Vector3.new(1.2, 0.7, 1.2), CFrame.new(base + Vector3.new(0, 2.1, 0)), { color = Color3.fromRGB(28, 40, 34), material = Enum.Material.Glass, reflectance = 0.2, transparency = 0.15 }, { collide = false, query = false })
		bulb = Kit.part(model, "Bulb", Vector3.new(0.3, 0.2, 0.3), CFrame.new(base + Vector3.new(0, 1.85, 0)), { color = Color3.fromRGB(255, 214, 150), material = Enum.Material.Neon }, { collide = false, shadow = false, query = false })
		local down = Kit.spotLight(bulb, Enum.NormalId.Bottom, style.lampBrightness, 10, 120, style.lampColor)
		down.Name = "TableLight"
		down.Shadows = false
		local glow = Kit.pointLight(bulb, 0.35, 7, style.lampColor)
		glow.Name = "LampGlow"
		return
	end
	-- Pendant lamps: a short brass shade (Salon) or a green glass shade on a long cord (Velvet).
	local cordTop = style.ceiling
	Kit.cylinder(model, "Cord", cordTop - lampPos.Y, 0.08, CFrame.new(lampPos.X, (cordTop + lampPos.Y) / 2, lampPos.Z) * CFrame.Angles(0, 0, math.rad(90)), L.ink, { collide = false, shadow = false, query = false })
	local shadeLook = if style.lamp == "cord" then { color = Color3.fromRGB(26, 70, 48), material = Enum.Material.Glass, reflectance = 0.25, transparency = 0.1 } else L.brass
	local shadeSize = if style.lamp == "cord" then Vector3.new(1.2, 2.2, 2.2) else Vector3.new(0.9, 3.4, 3.4)
	local shade = Kit.part(model, "Lamp", shadeSize, CFrame.new(lampPos) * CFrame.Angles(0, 0, math.rad(90)), shadeLook, { collide = false, shape = Enum.PartType.Cylinder, query = false })
	shade.CastShadow = true
	if style.lamp == "cord" then
		Kit.part(model, "LampRim", Vector3.new(0.1, 2.3, 2.3), CFrame.new(lampPos - Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), L.brass, { collide = false, shape = Enum.PartType.Cylinder, query = false, shadow = false })
	end
	bulb = Kit.part(model, "Bulb", Vector3.new(0.6, 0.3, 0.6), CFrame.new(lampPos - Vector3.new(0, 0.5, 0)), { color = Color3.fromRGB(255, 220, 160), material = Enum.Material.Neon }, { collide = false, shadow = false, query = false })
	local down = Kit.spotLight(bulb, Enum.NormalId.Bottom, style.lampBrightness, 16, 72, style.lampColor)
	down.Name = "TableLight"
end

function SortingTable.build(parent: Instance, roomId: string, index: number, centre: Vector3, style: Style): Model
	local id = roomId .. "-" .. index
	local model = Kit.model(parent, string.upper(string.sub(roomId, 1, 1)) .. string.sub(roomId, 2) .. "Table" .. index)
	Kit.persist(model)
	model:SetAttribute("TableId", id)
	model:SetAttribute("Room", roomId)
	model:SetAttribute("Centre", centre)
	model:SetAttribute("Score", 0)
	model:SetAttribute("Multiplier", 1)
	CollectionService:AddTag(model, "MaisonTable")

	local top = centre.Y + T.topY
	for _, o in { { -4.9, -3.1 }, { 4.9, -3.1 }, { -4.9, 3.1 }, { 4.9, 3.1 } } do
		Kit.part(model, "Leg", Vector3.new(0.5, T.topY - 0.3, 0.5), CFrame.new(centre + Vector3.new(o[1], (T.topY - 0.3) / 2, o[2])), style.legs)
	end
	Kit.part(model, "Apron", Vector3.new(T.width - 0.6, 0.6, T.depth - 0.6), CFrame.new(centre.X, top - 0.55, centre.Z), style.top)
	Kit.part(model, "Top", Vector3.new(T.width, 0.3, T.depth), CFrame.new(centre.X, top - 0.15, centre.Z), style.top)
	Kit.part(model, "Inlay", Vector3.new(T.width - 0.5, 0.02, T.depth - 0.5), CFrame.new(centre.X, top + 0.005, centre.Z), L.brass, { collide = false, shadow = false })
	local felt = Kit.part(model, "Felt", Vector3.new(T.width - 0.7, 0.03, T.depth - 0.7), CFrame.new(centre.X, top + 0.01, centre.Z), style.felt, { collide = false })
	felt:SetAttribute("Top", top + 0.025)

	for i = 1, #Catalogue.Cases do
		smokedCase(model, i, centre, style)
	end

	-- The brass counter, set into the near edge and angled up at the guest
	local counterPos = centre + Vector3.new(0, T.topY + 0.2, T.counterZ)
	local counter = Kit.part(model, "Counter", Vector3.new(3.4, 0.62, 0.08), CFrame.lookAt(counterPos, counterPos + TOWARD_CAMERA, UP_TOWARD_CASES), L.brass, { collide = false, shadow = false })
	counter.Material = Enum.Material.Metal
	local dialPos = counterPos + Vector3.new(2.2, 0, 0)
	local dial = Kit.part(model, "Dial", Vector3.new(0.08, 0.62, 0.62), CFrame.lookAt(dialPos, dialPos + TOWARD_CAMERA, UP_TOWARD_CASES) * CFrame.Angles(0, math.rad(90), 0), { color = Color3.fromRGB(236, 228, 210), material = Enum.Material.SmoothPlastic }, { collide = false, shadow = false, shape = Enum.PartType.Cylinder })
	dial.Name = "Dial"
	-- The clock rail along the far edge; the client fills it in timed rooms.
	local railPos = centre + Vector3.new(0, T.topY + 0.12, T.depth / 2 - 0.12)
	local rail = Kit.part(model, "ClockRail", Vector3.new(T.width - 1, 0.2, 0.04), CFrame.lookAt(railPos, railPos + TOWARD_CAMERA, UP_TOWARD_CASES), { color = Color3.fromRGB(30, 26, 18), material = Enum.Material.Metal, reflectance = 0.1, transparency = 1 }, { collide = false, shadow = false, query = false })
	rail:SetAttribute("Timed", false)

	-- Chair: the guest faces +Z, toward the cases
	local seatPos = centre + Vector3.new(0, T.seatY, T.chairZ)
	local seat = Instance.new("Seat")
	seat.Name = "Chair"
	seat.Anchored = true
	seat.Size = Vector3.new(2.4, 0.5, 2.2)
	seat.CFrame = CFrame.lookAt(seatPos, seatPos + Vector3.new(0, 0, 1))
	seat.Color = style.chair.color
	seat.Material = style.chair.material
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.CanTouch = false -- nobody sits by walking into it; the prompt seats you
	seat.Parent = model
	Kit.part(model, "ChairBack", Vector3.new(2.4, 3, 0.4), CFrame.new(seatPos + Vector3.new(0, 1.6, -1.2)), style.chair, { collide = false })
	Kit.part(model, "ChairFrame", Vector3.new(2.6, 0.2, 2.4), CFrame.new(seatPos + Vector3.new(0, -0.3, 0)), style.legs, { collide = false })
	for _, o in { { -1.1, -1 }, { 1.1, -1 }, { -1.1, 1 }, { 1.1, 1 } } do
		Kit.part(model, "ChairLeg", Vector3.new(0.25, T.seatY - 0.3, 0.25), CFrame.new(centre + Vector3.new(o[1], (T.seatY - 0.3) / 2, T.chairZ + o[2])), style.legs, { collide = false })
	end
	prompt(seat, "SitPrompt", "Sit", style.roomName, Enum.KeyCode.E, Enum.KeyCode.ButtonX, 2.2)
	prompt(seat, "NightlyPrompt", "Tonight's table", "The Nightly", Enum.KeyCode.F, Enum.KeyCode.ButtonY, 3.5)

	lamp(model, centre, style)
	return model
end

return SortingTable
