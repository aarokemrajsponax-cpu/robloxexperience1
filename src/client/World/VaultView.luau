--!strict
-- The Vault's vitrines, filled on this guest's screen with the pieces they have filed (each guest
-- sees their own). The centre vitrine holds their Mythics, each with its serial number; the eight
-- domes of the display by the east wall, their featured curios.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local BrainrotFigure = require(ReplicatedStorage.Shared.BrainrotFigure)
local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local CurioRules = require(ReplicatedStorage.Shared.Curios)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Layout = require(ReplicatedStorage.Shared.Layout)
local PieceModels = require(ReplicatedStorage.Shared.PieceModels)
local Wing = require(ReplicatedStorage.Shared.Wing)
local Closet = require(script.Parent.Parent.Closet)
local CurioState = require(script.Parent.Parent.CurioState)

local VaultView = {}

local player = Players.LocalPlayer
local folder: Folder? = nil
local inside = false

-- Where the pieces stand in a vitrine, in its own frame: its shelves (as the vitrine says; three
-- of four in an older one), four to a shelf, each turned a little towards the middle.
type Shelves = { count: number, first: number, step: number, span: number }
local function shelvesOf(cabinet: Instance): Shelves
	local function num(name: string, default: number): number
		local v = cabinet:GetAttribute(name)
		return if type(v) == "number" then v else default
	end
	return { count = num("SlotShelves", 3), first = num("SlotFirstY", 2.8), step = num("SlotStepY", 2), span = num("SlotSpan", 2.4) }
end
local function slot(s: Shelves, i: number): CFrame
	local shelf = math.floor((i - 1) / 4)
	local col = (i - 1) % 4
	return CFrame.new(-s.span / 2 + col * s.span / 3, s.first + shelf * s.step + 0.25, 0.1) * CFrame.Angles(0, math.rad(20 - col * 13), 0)
end

-- (Build 105) The wing this guest stands in (nil in the house): only the cabinets and domes of
-- the Vault they're in are filled, never the house's sealed one or a friend's wing drawn nearby.
local function hereSlot(): number?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then Wing.slotAt(root.CFrame.Position) else nil
end

local function place(parent: Instance, pieceId: string, at: CFrame, gilded: boolean): Model?
	local ok, model = pcall(PieceModels.build, pieceId, Brand.Colours.felt)
	if not ok or not model then
		return nil
	end
	if gilded then
		PieceModels.gild(model)
	end
	model:ScaleTo(0.85)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = true
		end
	end
	model:PivotTo(at)
	model.Parent = parent
	return model
end

-- (Build 105) The Brainrot Gallery: a stand of black marble in three gold-edged steps against the
-- Vault's south wall, west of its door, with every brainrot this guest holds standing on it in
-- the round, rarest first (twelve at most), each with its name and how many they hold; spotlit,
-- with its name over it. Built on this guest's screen, in the Vault they stand in.
local GALLERY_MOST = 12 -- (four a step on a long wall, three on a short one: nine)
local function gallery(parent: Instance, vault: Instance)
	local floor = vault:FindFirstChild("Floor")
	local jamb = vault:FindFirstChild("DoorJambL")
	if not floor or not floor:IsA("BasePart") or not jamb or not jamb:IsA("BasePart") then
		return
	end
	local fc, fs = floor.CFrame.Position, floor.Size
	local top = fc.Y + fs.Y / 2
	local south = fc.Z - fs.Z / 2
	local west = fc.X - fs.X / 2 + 6
	local east = jamb.CFrame.Position.X - 3
	-- (Never over the elevator's doors on the same wall: it starts just past them.)
	local wing = vault.Parent or vault
	for _, d in wing:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "CallButton" or d.Name == "JambL" or d.Name == "JambR" or d.Name == "LiftSign") then
			local at = d.CFrame.Position
			if math.abs(at.Z - south) < 4 and math.abs(at.Y - top) < 14 and at.X > west - 8 and at.X < east then
				west = math.max(west, at.X + d.Size.X / 2 + 1.5)
			end
		end
	end
	local length = east - west
	if length < 8 then
		return
	end
	local cx = (west + east) / 2
	local m = Instance.new("Model")
	m.Name = "BrainrotGallery"
	local function block(name: string, size: Vector3, at: Vector3, colour: Color3, material: Enum.Material): Part
		local b = Instance.new("Part")
		b.Name = name
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.Size = size
		b.CFrame = CFrame.new(at)
		b.Color = colour
		b.Material = material
		b.TopSurface = Enum.SurfaceType.Smooth
		b.Parent = m
		return b
	end
	local BLACK = Color3.fromRGB(18, 16, 20)
	local GOLD = Color3.fromRGB(255, 206, 110)
	-- Three steps: the back one against the wall, tallest.
	local steps = {
		{ h = 3.4, z = south + 1.0 },
		{ h = 2.2, z = south + 2.8 },
		{ h = 1.0, z = south + 4.6 },
	}
	for i, st in steps do
		block("Step" .. i, Vector3.new(length, st.h, 1.8), Vector3.new(cx, top + st.h / 2, st.z), BLACK, Enum.Material.Marble)
		local edge = block("StepEdge" .. i, Vector3.new(length, 0.12, 0.12), Vector3.new(cx, top + st.h + 0.02, st.z + 0.85), GOLD, Enum.Material.Neon)
		edge.CastShadow = false
	end
	-- Its name on the wall above, lit.
	local board = block("GallerySign", Vector3.new(math.min(18, length), 1.8, 0.2), Vector3.new(cx, top + 6.6, south + 0.25), BLACK, Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Text = "THE BRAINROT GALLERY"
	title.TextScaled = true
	title.FontFace = Brand.Fonts.display
	title.TextColor3 = Brand.Colours.brightGold
	title.Parent = gui
	for i = 0, 2 do
		local lamp = block("GalleryLamp", Vector3.new(0.4, 0.4, 0.4), Vector3.new(cx - length / 3 + i * length / 3, top + 9.5, south + 5), GOLD, Enum.Material.Neon)
		local spotLight = Instance.new("SpotLight")
		spotLight.Face = Enum.NormalId.Bottom
		spotLight.Angle = 70
		spotLight.Range = 14
		spotLight.Brightness = 2.2
		spotLight.Color = Color3.fromRGB(255, 232, 196)
		spotLight.Parent = lamp
	end
	-- Every brainrot they hold, rarest first, four to a step (the back step first).
	local held: { string } = {}
	for id, n in CurioState.items do
		local c = CurioRules.byId[id]
		if c and c.family == "meme" and n > 0 then
			table.insert(held, id)
		end
	end
	table.sort(held, CurioRules.compare)
	local perStep = if length >= 16 then 4 else 3
	local squad = CurioState.squad
	local muts = if squad and type(squad.mut) == "table" then squad.mut else {}
	for i, id in held do
		if i > GALLERY_MOST then
			break
		end
		local c = CurioRules.byId[id]
		local row = math.floor((i - 1) / perStep) + 1
		local col = (i - 1) % perStep
		local st = steps[row]
		if not st then
			break
		end
		local x = west + length * (col + 0.5) / perStep
		local mut = Brainrots.Mutations[muts[id] or ""]
		local h = math.min(4.2, (Brainrots.Height[c.rarity] or 3.4) * 0.55)
		local ok, fig = pcall(BrainrotFigure.build, id, h, c.colour, if mut then mut.colour else nil)
		if ok and fig then
			BrainrotFigure.place(fig, CFrame.lookAt(Vector3.new(x, top + st.h, st.z), Vector3.new(x, top + st.h, st.z + 10)))
			fig.Parent = m
			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromOffset(150, 34)
			tag.StudsOffsetWorldSpace = Vector3.new(0, h + 0.8, 0)
			local figRoot = fig.PrimaryPart
			if figRoot then
				tag.Adornee = figRoot
			end
			tag.MaxDistance = 26
			tag.LightInfluence = 0
			tag.Parent = fig
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.TextScaled = true
			label.FontFace = Brand.Fonts.heavy
			label.TextColor3 = (CurioRules.RarityColour[c.rarity] or Brand.Colours.gold):Lerp(Color3.new(1, 1, 1), 0.3)
			label.TextStrokeTransparency = 0.3
			local n = CurioState.items[id] or 1
			label.Text = string.format("%s%s", c.name, if n > 1 then string.format("  ×%d", n) else "")
			label.Parent = tag
		end
	end
	m.Parent = parent
end
VaultView.gallery = gallery

local function fill(view: { [string]: any })
	local old = folder
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Vault"
	f.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	folder = f
	local register = view.register or {}
	local here = hereSlot()
	local galleryDone = false
	for _, cabinet in CollectionService:GetTagged("VaultCabinet") do
		local frame = cabinet:GetAttribute("Frame")
		if typeof(frame) == "CFrame" and Wing.slotAt(frame.Position) == here then
			local vault = cabinet.Parent
			if not galleryDone and vault then
				galleryDone = true
				pcall(gallery, f, vault)
			end
			local shelves = shelvesOf(cabinet)
			local room = shelves.count * 4
			local caseId = cabinet:GetAttribute("Case")
			if type(caseId) == "string" then
				local found = {}
				for _, p in Catalogue.coreForCase(caseId) do
					if register[p.id] then
						table.insert(found, p.id)
					end
				end
				for _, p in Catalogue.Seasonal do
					if p.case == caseId and register[p.id] then
						table.insert(found, p.id)
					end
				end
				for i, id in found do
					if i <= room then
						place(f, id, frame * slot(shelves, i), false)
					end
				end
			else
				for i, m in view.mythics or {} do
					if i <= room then
						local model = place(f, m.id, frame * slot(shelves, i), true)
						local primary = model and model.PrimaryPart
						if model and primary then
							local gui = Instance.new("BillboardGui")
							gui.Size = UDim2.fromOffset(120, 22)
							gui.StudsOffset = Vector3.new(0, 0.9, 0)
							gui.MaxDistance = 18
							gui.LightInfluence = 0
							gui.Adornee = primary
							gui.Parent = model
							local l = Instance.new("TextLabel")
							l.BackgroundTransparency = 1
							l.Size = UDim2.fromScale(1, 1)
							l.FontFace = Brand.Fonts.display
							l.TextScaled = true
							l.TextColor3 = Brand.Colours.lightGold
							l.Text = string.format("No. %05d", m.serial or 0)
							l.Parent = gui
						end
					end
				end
			end
		end
	end
end

-- The eight domes of the Vault's display (two rows of four): each with this guest's featured curio standing in it
-- (its glyph on a medallion in its rarity's colour, its name beneath), or empty.
local Curios = require(ReplicatedStorage.Shared.Curios)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

function VaultView.featured(ids: { string })
	local here = hereSlot()
	for _, medal in CollectionService:GetTagged("VaultFeature") do
		if medal:IsA("BasePart") and Wing.slotAt(medal.CFrame.Position) == here then
			local old = medal:FindFirstChild("Featured")
			if old then
				old:Destroy()
			end
			local i = tonumber(medal:GetAttribute("Index")) or 0
			local id = ids[i]
			local c = id and Curios.byId[id]
			if c then
				local gui = Instance.new("SurfaceGui")
				gui.Name = "Featured"
				gui.Face = Enum.NormalId.Front
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 120
				gui.LightInfluence = 0
				gui.Brightness = 1.4
				gui.MaxDistance = 40
				gui.Parent = medal
				local disc = Instance.new("Frame")
				disc.Size = UDim2.fromScale(1, 1)
				disc.BackgroundColor3 = (c :: any).colour or Color3.fromRGB(40, 30, 20)
				disc.BorderSizePixel = 0
				disc.Parent = gui
				local round = Instance.new("UICorner")
				round.CornerRadius = UDim.new(0.5, 0)
				round.Parent = disc
				local ring = Instance.new("UIStroke")
				ring.Color = Curios.RarityColour[(c :: any).rarity] or Brand.Colours.gold
				ring.Thickness = 4
				ring.Parent = disc
				local glyph = Instance.new("TextLabel")
				glyph.BackgroundTransparency = 1
				glyph.Size = UDim2.fromScale(1, 1)
				glyph.Text = (c :: any).glyph or "✨"
				glyph.TextScaled = true
				glyph.FontFace = Brand.Fonts.body
				glyph.Parent = disc
				local pad = Instance.new("UIPadding")
				pad.PaddingTop = UDim.new(0.16, 0)
				pad.PaddingBottom = UDim.new(0.16, 0)
				pad.Parent = glyph
			end
		end
	end
end

local function askFeatured()
	task.spawn(function()
		local ok, r = pcall(function()
			return Remotes.func("ShowcaseAsk"):InvokeServer({ op = "state" })
		end)
		if ok and type(r) == "table" and r.ok == true and inside then
			VaultView.featured(if type(r.featured) == "table" then r.featured else {})
		end
	end)
end

-- Set by Main: a guest has just walked into the Vault (the first time ever, its guide card).
VaultView.entered = function() end

function VaultView.start()
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local now = root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "vault"
			if now and not inside then
				inside = true
				task.spawn(VaultView.entered)
				task.spawn(function()
					local view = Closet.ask({ op = "register" })
					if inside and type(view) == "table" and view.register then
						fill(view)
					end
				end)
				askFeatured()
			elseif not now and inside then
				inside = false
				local f = folder
				if f then
					f:Destroy()
					folder = nil
				end
			end
			task.wait(0.5)
		end
	end)
end

return VaultView
