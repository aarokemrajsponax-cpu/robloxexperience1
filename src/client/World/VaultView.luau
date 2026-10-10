--!strict
-- The Vault's vitrines, filled on this guest's screen with the pieces they have filed (each guest
-- sees their own). The centre vitrine holds their Mythics, each with its serial number.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Layout = require(ReplicatedStorage.Shared.Layout)
local PieceModels = require(ReplicatedStorage.Shared.PieceModels)
local Closet = require(script.Parent.Parent.Closet)

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
	for _, cabinet in CollectionService:GetTagged("VaultCabinet") do
		local frame = cabinet:GetAttribute("Frame")
		if typeof(frame) == "CFrame" then
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

function VaultView.start()
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local now = root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "vault"
			if now and not inside then
				inside = true
				task.spawn(function()
					local view = Closet.ask({ op = "register" })
					if inside and type(view) == "table" and view.register then
						fill(view)
					end
				end)
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
