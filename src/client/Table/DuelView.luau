--!strict
-- The Library on the guest's screen, beyond their own felt: the rival's pieces on the far half
-- of the long table (filed into the rival's cases as they go), sealed parcels sliding across
-- with a burning fuse, the two lamps brightening for whoever takes a hand, and the dial showing
-- hands won. Everything here is local decoration; the server decides every piece of it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Layout = require(ReplicatedStorage.Shared.Layout)
local PieceModels = require(ReplicatedStorage.Shared.PieceModels)
local Voice = require(ReplicatedStorage.Shared.Voice)

local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Toast = require(script.Parent.Parent.UI.Toast)
local Counter = require(script.Parent.Counter)
local RoundCard = require(script.Parent.RoundCard)

local DuelView = {}

local T = Layout.Table
local RIVAL_SCALE = 0.85

type RivalPiece = { model: Model, slot: CFrame, case: string }
type Parcel = { id: number, to: string, model: Model, fuse: BasePart?, label: TextLabel?, spark: ParticleEmitter?, count: number }

local ownModel: Model? = nil
local rivalModel: Model? = nil
local ownFrame = CFrame.new()
local rivalFrame = CFrame.new()
local side = "a"
local rivalName = "Your rival"
local rivalCount: number? = nil
local rivalPieces: { [number]: RivalPiece } = {}
local parcels: { [number]: Parcel } = {}
local waitingPlate: BillboardGui? = nil

local folder = Instance.new("Folder")
folder.Name = "Duel"

local function localFolder(): Instance
	local f = Workspace:FindFirstChild("MaisonLocal")
	if not f then
		f = Instance.new("Folder")
		f.Name = "MaisonLocal"
		f.Parent = Workspace
	end
	if folder.Parent ~= f then
		folder.Parent = f
	end
	return folder
end

local function other(key: string): string
	return if key == "a" then "b" else "a"
end

local function frameOf(key: string): CFrame
	return if key == side then ownFrame else rivalFrame
end

local function glide(model: Model, goal: CFrame, seconds: number, style: Enum.EasingStyle?): Tween
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local t = TweenService:Create(value, Ease.scaled(TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out)), { Value = goal })
	t.Completed:Once(function()
		value:Destroy()
	end)
	t:Play()
	return t
end

local function lampOf(model: Model?): SpotLight?
	local bulb = model and model:FindFirstChild("Bulb")
	local light = bulb and bulb:FindFirstChild("TableLight")
	return if light and light:IsA("SpotLight") then light else nil
end

local function lampTo(model: Model?, brightness: number, seconds: number)
	local light = lampOf(model)
	if light then
		TweenService:Create(light, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Brightness = brightness }):Play()
	end
end

local function clearRival()
	for _, p in rivalPieces do
		p.model:Destroy()
	end
	rivalPieces = {}
end

local function clearParcels()
	for _, parcel in parcels do
		parcel.model:Destroy()
	end
	parcels = {}
end

local function setWaiting(on: boolean)
	if waitingPlate then
		waitingPlate:Destroy()
		waitingPlate = nil
	end
	local model = rivalModel
	if not on or not model then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "WaitingAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = rivalFrame * CFrame.new(0, T.topY + 1.6, -0.5)
	anchor.Parent = localFolder()
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 34)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = anchor
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.FontFace = Brand.Fonts.display
	l.TextScaled = true
	l.TextColor3 = Brand.Colours.lightGold
	l.TextTransparency = 0.2
	l.Text = Voice.Library.waiting
	l.Parent = gui
	-- A slow breath, so it reads as waiting rather than broken.
	TweenService:Create(l, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextTransparency = 0.65 }):Play()
	waitingPlate = gui
	gui.Destroying:Once(function()
		anchor:Destroy()
	end)
end

-- The rival's felt, laid out exactly as theirs is (the same slots in their frame).
local function layRival(list: { { [string]: any } }, fromParcel: Vector3?)
	local total = 0
	for _ in rivalPieces do
		total += 1
	end
	local slots = Layout.pieceSlots(rivalFrame, total + #list)
	local i = 0
	local uids = {}
	for uid in rivalPieces do
		table.insert(uids, uid)
	end
	table.sort(uids)
	for _, uid in uids do
		i += 1
		local p = rivalPieces[uid]
		p.slot = CFrame.new(slots[i]) * p.slot.Rotation
		glide(p.model, p.slot, 0.35)
	end
	local rng = Random.new(#list * 17 + total)
	for j, data in list do
		i += 1
		local model = PieceModels.build(data.id, Brand.Colours.felt)
		model:ScaleTo(RIVAL_SCALE)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		local slot = CFrame.new(slots[i]) * rivalFrame.Rotation * CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), 0)
		model:PivotTo(if fromParcel then CFrame.new(fromParcel) else slot + Vector3.new(0, 3, -1.5))
		model.Parent = localFolder()
		rivalPieces[data.uid] = { model = model, slot = slot, case = data.case }
		task.delay((j - 1) * 0.05, function()
			if model.Parent then
				glide(model, slot, 0.5, if fromParcel then Enum.EasingStyle.Back else nil)
			end
		end)
	end
end

local function rivalFiled(uid: number, caseId: string, correct: boolean)
	local p = rivalPieces[uid]
	if not p then
		return
	end
	if correct then
		rivalPieces[uid] = nil
		local index = Catalogue.caseIndex[caseId] or 1
		local c = Layout.caseCentre(rivalFrame, index)
		local goal = CFrame.new(c + Vector3.new(0, 0.18, 0)) * p.slot.Rotation
		local model = p.model
		glide(model, goal, 0.3)
		task.delay(0.32, function()
			if model.Parent then
				model:ScaleTo(model:GetScale() * 0.7)
			end
		end)
		task.delay(4, function()
			model:Destroy()
		end)
	else
		-- A wrong case: the piece comes back to the felt with a small knock.
		glide(p.model, p.slot * CFrame.new(0, 0.5, 0), 0.12)
		task.delay(0.14, function()
			if p.model.Parent then
				glide(p.model, p.slot, 0.3, Enum.EasingStyle.Bounce)
			end
		end)
	end
end

-- Where a parcel waits on a guest's felt: the near-left corner, stacked if several arrive.
local function dock(key: string, n: number): CFrame
	local frame = frameOf(key)
	return frame * CFrame.new(-T.width / 2 + 0.75, T.topY + 0.32, T.feltMinZ + 0.4 + (n - 1) * 0.85)
end

local function waitingOn(key: string): number
	local n = 0
	for _, parcel in parcels do
		if parcel.to == key then
			n += 1
		end
	end
	return n
end

local function parcelModel(count: number): (Model, BasePart, TextLabel, ParticleEmitter)
	local m = Instance.new("Model")
	m.Name = "Parcel"
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = Vector3.new(0.72, 0.5, 0.6)
	box.Color = Color3.fromRGB(26, 22, 20)
	box.Material = Enum.Material.Leather
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Parent = m
	m.PrimaryPart = box
	-- Gold ribbon, both ways round the box.
	local ribbons: { Vector3 } = { Vector3.new(0.1, 0.52, 0.62), Vector3.new(0.74, 0.52, 0.1) }
	for _, size in ribbons do
		local ribbon = Instance.new("Part")
		ribbon.Name = "Ribbon"
		ribbon.Size = size
		ribbon.Color = Brand.Colours.gold
		ribbon.Material = Enum.Material.Metal
		ribbon.Anchored = true
		ribbon.CanCollide = false
		ribbon.CanQuery = false
		ribbon.CanTouch = false
		ribbon.CFrame = box.CFrame
		ribbon.Parent = m
	end
	local seal = Instance.new("Part")
	seal.Name = "Seal"
	seal.Shape = Enum.PartType.Cylinder
	seal.Size = Vector3.new(0.05, 0.22, 0.22)
	seal.Color = Color3.fromRGB(128, 22, 30)
	seal.Material = Enum.Material.SmoothPlastic
	seal.Anchored = true
	seal.CanCollide = false
	seal.CanQuery = false
	seal.CFrame = box.CFrame * CFrame.new(0, 0.27, 0) * CFrame.Angles(0, 0, math.rad(90))
	seal.Parent = m
	-- The fuse: a short cord from the seal that burns down.
	local fuse = Instance.new("Part")
	fuse.Name = "Fuse"
	fuse.Size = Vector3.new(0.05, 0.05, 0.6)
	fuse.Color = Color3.fromRGB(214, 190, 150)
	fuse.Material = Enum.Material.Fabric
	fuse.Anchored = true
	fuse.CanCollide = false
	fuse.CanQuery = false
	fuse.CFrame = box.CFrame * CFrame.new(0, 0.3, -0.3 - 0.3)
	fuse.Parent = m
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0, -0.3)
	tip.Parent = fuse
	local spark = Instance.new("ParticleEmitter")
	spark.Rate = 40
	spark.Lifetime = NumberRange.new(0.15, 0.3)
	spark.Speed = NumberRange.new(1, 2.5)
	spark.SpreadAngle = Vector2.new(180, 180)
	spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07), NumberSequenceKeypoint.new(1, 0) })
	spark.Color = ColorSequence.new(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 120, 60))
	spark.LightEmission = 1
	spark.Enabled = false
	spark.Parent = tip
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 170, 90)
	glow.Brightness = 1.2
	glow.Range = 3
	glow.Parent = tip
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(44, 26)
	gui.StudsOffset = Vector3.new(0, 0.7, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Adornee = box
	gui.Parent = m
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
	label.BackgroundTransparency = 0.2
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Brand.Fonts.display
	label.TextScaled = true
	label.TextColor3 = Brand.Colours.lightGold
	label.Text = "×" .. tostring(count)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = label
	return m, fuse, label, spark
end

local function onParcel(message: { [string]: any })
	local from, to = message.from :: string, message.to :: string
	local count = message.count :: number
	local fuseSeconds = message.fuse :: number
	local model, fuse, label, spark = parcelModel(count)
	-- It leaves from between the sender's cases, slides over the middle of the long table and
	-- settles in the receiver's near corner.
	local start = frameOf(from) * CFrame.new(0, T.topY + 1.2, T.caseRowZ + 0.2)
	local goal = dock(to, waitingOn(to) + 1)
	model:PivotTo(start)
	model.Parent = localFolder()
	local parcel: Parcel = { id = message.id, to = to, model = model, fuse = fuse, label = label, spark = spark, count = count }
	parcels[message.id] = parcel
	local travel = math.min(0.6, fuseSeconds * 0.3)
	glide(model, goal, travel, Enum.EasingStyle.Sine)
	task.delay(travel, function()
		if not model.Parent then
			return
		end
		spark.Enabled = true
		-- The fuse burns toward the seal for the rest of the time.
		local burn = math.max(0.1, fuseSeconds - travel)
		local tip = fuse:FindFirstChild("Tip") :: Attachment?
		local value = Instance.new("NumberValue")
		value.Value = 1
		value.Changed:Connect(function(v)
			local box = model.PrimaryPart
			if fuse.Parent and box then
				local length = math.max(0.02, 0.6 * v)
				fuse.Size = Vector3.new(0.05, 0.05, length)
				fuse.CFrame = box.CFrame * CFrame.new(0, 0.3, -0.3 - length / 2)
				if tip then
					tip.Position = Vector3.new(0, 0, -length / 2)
				end
			end
		end)
		local t = TweenService:Create(value, TweenInfo.new(burn, Enum.EasingStyle.Linear), { Value = 0 })
		t.Completed:Once(function()
			value:Destroy()
		end)
		t:Play()
	end)
	if to == side then
		Sound.play("low", 0.35, 0.8)
		RoundCard.clear()
	else
		Sound.play("round", 0.25, 1.4)
	end
end

local function burst(parcel: Parcel)
	local model = parcel.model
	local box = model.PrimaryPart
	if box then
		local a = Instance.new("Attachment")
		a.Parent = box
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Color = ColorSequence.new(Brand.Colours.lightGold)
		e.LightEmission = 1
		e.Lifetime = NumberRange.new(0.3, 0.6)
		e.Speed = NumberRange.new(2, 4)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0) })
		e.Parent = a
		e:Emit(if State.get("glow") == "Off" then 4 else 16)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		elseif d:IsA("ParticleEmitter") and d.Rate > 0 then
			d.Enabled = false
		elseif d:IsA("BillboardGui") then
			d.Enabled = false
		elseif d:IsA("PointLight") then
			d.Enabled = false
		end
	end
	task.delay(0.8, function()
		model:Destroy()
	end)
end

-- Re-stacks the parcels still waiting on a felt after one leaves.
local function restack(key: string)
	local ids = {}
	for id, parcel in parcels do
		if parcel.to == key then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for i, id in ids do
		glide(parcels[id].model, dock(key, i), 0.25)
	end
end

local function dialText(wins: { [string]: number }?)
	local model = ownModel
	if model and wins then
		Counter.setDialText(model, string.format("%d–%d", wins[side] or 0, wins[other(side)] or 0))
	end
end

function DuelView.seated(model: Model, frame: CFrame)
	DuelView.clear()
	ownModel = model
	ownFrame = frame
	local s = model:GetAttribute("Side")
	side = if s == "b" then "b" else "a"
	local duelId = model:GetAttribute("Duel")
	rivalModel = nil
	for _, half in CollectionService:GetTagged("DuelHalf") do
		if half:IsA("Model") and half ~= model and half:GetAttribute("Duel") == duelId then
			rivalModel = half
		end
	end
	local rf = rivalModel and rivalModel:GetAttribute("Frame")
	rivalFrame = if typeof(rf) == "CFrame" then rf else frame * CFrame.new(0, 0, T.depth) * CFrame.Angles(0, math.pi, 0)
	localFolder()
	dialText({ a = 0, b = 0 })
end

function DuelView.mySide(): string
	return side
end

function DuelView.rivalRemaining(): number?
	return rivalCount
end

-- Handles one message from the Library table. Returns where a parcel burst, for pieces that
-- spill out of it onto the guest's own felt.
function DuelView.handle(message: { [string]: any }): Vector3?
	local op = message.op
	if ownModel == nil then
		return nil
	end
	if op == "duelWaiting" then
		clearRival()
		clearParcels()
		rivalCount = nil
		setWaiting(true)
		lampTo(rivalModel, 0.6, 1)
	elseif op == "duelStart" then
		setWaiting(false)
		rivalName = if type(message.rival) == "string" then message.rival else "Your rival"
		local kind = if message.standIn then Voice.Library.standIn elseif message.ranked then Voice.Library.ranked else Voice.Library.friendly
		Toast.show(Voice.Library.title, rivalName .. " · " .. kind, 4)
		lampTo(rivalModel, 2.2, 1.2)
		dialText({ a = 0, b = 0 })
	elseif op == "rivalDeal" then
		clearRival()
		clearParcels()
		local list = message.pieces :: { { [string]: any } }
		rivalCount = #list
		layRival(list, nil)
	elseif op == "rivalFiled" then
		rivalCount = message.remaining
		rivalFiled(message.uid, message.case, message.correct == true)
	elseif op == "parcel" then
		onParcel(message)
		if message.to == side then
			Toast.show(Voice.Library.parcelIn, string.format("%d from %s", message.count, rivalName), 1.6)
		end
	elseif op == "parcelShrink" then
		local parcel = parcels[message.id]
		if parcel then
			parcel.count = message.count
			if parcel.label then
				parcel.label.Text = "×" .. tostring(message.count)
			end
			local box = parcel.model.PrimaryPart
			if box then
				glide(parcel.model, parcel.model:GetPivot() * CFrame.new(0, 0.3, 0), 0.1)
				task.delay(0.12, function()
					if parcel.model.Parent then
						restack(parcel.to)
					end
				end)
			end
		end
	elseif op == "parcelCancel" then
		local parcel = parcels[message.id]
		if parcel then
			parcels[message.id] = nil
			burst(parcel)
			restack(parcel.to)
			Sound.play("chime", 0.3, 1.5)
		end
	elseif op == "parcelOpen" then
		local parcel = parcels[message.id]
		local at: Vector3? = nil
		if parcel then
			parcels[message.id] = nil
			at = parcel.model:GetPivot().Position
			burst(parcel)
			restack(parcel.to)
		end
		Sound.play("drop", 0.3, 0.8)
		if message.side ~= side then
			rivalCount = message.remaining
			layRival(message.pieces, at)
		end
		return at
	elseif op == "handEnd" then
		clearParcels()
		local won = message.winner == side
		dialText(message.wins)
		lampTo(if won then rivalModel else ownModel, 0.9, 0.8)
		lampTo(if won then ownModel else rivalModel, 3, 0.8)
		RoundCard.land(ownFrame, "Hand " .. tostring(message.hand), if won then Voice.Library.handWon else Voice.fill(Voice.Library.handLost, { name = rivalName }), string.format("%d – %d", message.wins[side] or 0, message.wins[other(side)] or 0))
		task.delay(0.9, clearRival)
	elseif op == "duelEnd" then
		clearRival()
		clearParcels()
		rivalCount = nil
		dialText(message.wins)
		lampTo(ownModel, if message.won then 3 else 1.2, 1)
		lampTo(rivalModel, if message.won then 1.2 else 3, 1)
	elseif op == "rematchAsked" then
		Toast.show(Voice.Library.title, Voice.fill(Voice.Library.rematchAsked, { name = tostring(message.by) }), 5)
	end
	return nil
end

function DuelView.clear()
	clearRival()
	clearParcels()
	setWaiting(false)
	rivalCount = nil
	if ownModel then
		Counter.setDialText(ownModel, "×1")
	end
	lampTo(rivalModel, 1.4, 1)
	ownModel = nil
	rivalModel = nil
end

return DuelView
