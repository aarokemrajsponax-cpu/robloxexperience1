--!strict
-- The table, on the guest's screen: the deal glides onto the felt, pieces lift by drag or tap
-- (or a gamepad), the guide light runs to the right case, correct filings chime and glow, and the
-- counter rolls. The phone predicts right or wrong instantly; the server confirms every filing.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Layout = require(ReplicatedStorage.Shared.Layout)
local PieceModels = require(ReplicatedStorage.Shared.PieceModels)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Scoring = require(ReplicatedStorage.Shared.Scoring)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Voice = require(ReplicatedStorage.Shared.Voice)

local CameraRig = require(script.Parent.Parent.Camera)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Root = require(script.Parent.Parent.UI.Root)
local Hud = require(script.Parent.Parent.UI.Hud)
local RoundPanel = require(script.Parent.Parent.UI.RoundPanel)
local NightlyCard = require(script.Parent.Parent.UI.NightlyCard)
local Toast = require(script.Parent.Parent.UI.Toast)
local Counter = require(script.Parent.Counter)
local Guide = require(script.Parent.Guide)
local Hands = require(script.Parent.Hands)
local RoundCard = require(script.Parent.RoundCard)

local TableClient = {}

local player = Players.LocalPlayer
local tableEvent = Remotes.event("Table")
local T = Layout.Table

type Piece = {
	uid: number,
	id: string,
	name: string,
	case: string,
	value: number,
	rare: boolean,
	seasonal: boolean,
	mythic: boolean,
	model: Model,
	slot: CFrame,
	filed: boolean,
	pending: boolean,
	label: BillboardGui?,
}

type Snapshot = { score: number, streak: number, runLength: number, lastCase: string?, multiplier: number }

local seatedModel: Model? = nil
local centre = Vector3.zero
local roomId = "salon"
local tableMode = "room" -- "room", "nightly" or "rehearsal"
local clockBudget: number? = nil
local lowPlayed = false
local rail: { gui: SurfaceGui, fill: Frame }? = nil
local round = 1
local openCases: { string } = {}
local pieces: { [number]: Piece } = {}
local order: { number } = {}
local playing = false
local server: Snapshot = { score = 0, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
local local_: Snapshot = { score = 0, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
local clockLeft: number? = nil
local clockRunning = false
local paused = false

-- Input state
local held: number? = nil
local heldMode: "drag" | "tap" | "pad" | nil = nil
local press: { uid: number, at: Vector2, input: InputObject }? = nil
local padIndex = 1
local padCase = 1
local highlight: Highlight? = nil
local controls: any = nil
local toTableCallbacks: { () -> () } = {}

TableClient.Seated = Instance.new("BindableEvent")
TableClient.Left = Instance.new("BindableEvent")

local function localFolder(): Folder
	local f = Workspace:FindFirstChild("MaisonLocal")
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "MaisonLocal"
	nf.Parent = Workspace
	return nf
end

local piecesFolder = Instance.new("Folder")
piecesFolder.Name = "Pieces"
piecesFolder.Parent = localFolder()

local function getControls(): any
	if controls then
		return controls
	end
	local ok, module = pcall(function()
		return require((player:WaitForChild("PlayerScripts") :: any):WaitForChild("PlayerModule") :: ModuleScript) :: any
	end)
	if ok and module then
		controls = module:GetControls()
	end
	return controls
end

local function feltTop(): number
	return centre.Y + T.topY + 0.03
end

local function room(): Rooms.Room
	return Rooms.get(roomId) or (Rooms.get("salon") :: Rooms.Room)
end

local function caseIndex(caseId: string): number
	return Catalogue.caseIndex[caseId] or 1
end

local function caseCentre(caseId: string): Vector3
	return Layout.caseCentre(centre, caseIndex(caseId))
end

local function isOpen(caseId: string): boolean
	return table.find(openCases, caseId) ~= nil
end

local function namesAllowed(): boolean
	return room().tuning.names and State.get("pieceNames") ~= "Never"
end

-- A small glass name plate over a piece.
local function nameLabel(p: Piece): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Name"
	gui.Size = UDim2.fromOffset(180, 30)
	gui.StudsOffset = Vector3.new(0, 1.1, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = p.model.PrimaryPart :: any
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
	l.BackgroundTransparency = 0.25
	l.FontFace = Brand.Fonts.display
	l.TextSize = math.floor(16 * Settings.textScale(State.get("textSize")))
	l.TextColor3 = if p.rare or p.mythic then Brand.Colours.lightGold else Brand.Colours.bone
	l.Text = (if p.mythic then "✦ " elseif p.rare then "Gilded " else "") .. p.name
	l.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 2)
	c.Parent = l
	local s = Instance.new("UIStroke")
	s.Color = Brand.Colours.gold
	s.Transparency = 0.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = l
	gui.Parent = p.model
	return gui
end

local function showName(p: Piece, on: boolean)
	if on and namesAllowed() then
		if not p.label then
			p.label = nameLabel(p)
		end
		(p.label :: BillboardGui).Enabled = true
	elseif p.label then
		p.label.Enabled = State.get("pieceNames") == "Always on" and namesAllowed() and not p.filed
	end
end

local function setHighlight(model: Model?)
	if not model then
		if highlight then
			highlight.Enabled = false
		end
		return
	end
	if not highlight then
		local h = Instance.new("Highlight")
		h.FillTransparency = 0.85
		h.FillColor = Brand.Colours.lightGold
		h.OutlineColor = Brand.Colours.gold
		h.OutlineTransparency = 0.1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = localFolder()
		highlight = h
	end
	local h = highlight :: Highlight
	h.Adornee = model
	h.Enabled = true
end

local function pieceScale(): number
	return Settings.pieceScale(State.get("pieceSize"))
end

local function glideTo(p: Piece, goal: CFrame, seconds: number, style: Enum.EasingStyle?)
	local model = p.model
	local startCF = model:GetPivot()
	local value = Instance.new("CFrameValue")
	value.Value = startCF
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
end

local function clearPieces()
	for _, p in pieces do
		p.model:Destroy()
	end
	pieces = {}
	order = {}
	held = nil
	heldMode = nil
	press = nil
	setHighlight(nil)
	Guide.hide()
	Hands.reach(nil)
end

local function tableLight(): SpotLight?
	local model = seatedModel
	if not model then
		return nil
	end
	local bulb = model:FindFirstChild("Bulb")
	local light = bulb and bulb:FindFirstChild("TableLight")
	return if light and light:IsA("SpotLight") then light else nil
end

local function lampTo(brightness: number, seconds: number)
	local light = tableLight()
	if light then
		TweenService:Create(light, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Brightness = brightness }):Play()
	end
end

local function caseGlow(caseId: string)
	local model = seatedModel
	if not model then
		return
	end
	local glowSetting = State.get("glow")
	if glowSetting == "Off" then
		return
	end
	local strength = if glowSetting == "Subtle" then 0.5 else 1
	local glow = model:FindFirstChild("CaseGlow" .. caseIndex(caseId))
	if glow and glow:IsA("BasePart") then
		glow.Transparency = 1 - 0.75 * strength
		TweenService:Create(glow, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Transparency = 1 }):Play()
		local light = glow:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 2.2 * strength
			TweenService:Create(light, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Brightness = 0 }):Play()
		end
		-- A small spark of gold
		local a = Instance.new("Attachment")
		a.Parent = glow
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Color = ColorSequence.new(Brand.Colours.lightGold)
		e.LightEmission = 1
		e.Lifetime = NumberRange.new(0.35, 0.6)
		e.Speed = NumberRange.new(1.5, 3)
		e.SpreadAngle = Vector2.new(35, 35)
		e.EmissionDirection = Enum.NormalId.Top
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0) })
		e.Acceleration = Vector3.new(0, -6, 0)
		e.Parent = a
		e:Emit(if glowSetting == "Subtle" then 5 else 12)
		task.delay(1, function()
			a:Destroy()
		end)
	end
end

-- The clock rail: a slim brass rail on the table's far edge that drains (timed rooms only).
local function railFor(model: Model): { gui: SurfaceGui, fill: Frame }?
	local part = model:FindFirstChild("ClockRail")
	if not part or not part:IsA("BasePart") then
		return nil
	end
	local gui = part:FindFirstChild("RailGui")
	if gui and gui:IsA("SurfaceGui") then
		local fill = gui:FindFirstChild("Fill")
		if fill and fill:IsA("Frame") then
			return { gui = gui, fill = fill }
		end
	end
	local g = Instance.new("SurfaceGui")
	g.Name = "RailGui"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0.3
	g.Brightness = 1.4
	g.Parent = part
	local track = Instance.new("Frame")
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundColor3 = Color3.fromRGB(26, 22, 14)
	track.BorderSizePixel = 0
	track.Parent = g
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Brand.Colours.gold
	fill.BorderSizePixel = 0
	fill.Parent = g
	return { gui = g, fill = fill }
end

local function showRail(on: boolean)
	local model = seatedModel
	if not model then
		return
	end
	local part = model:FindFirstChild("ClockRail")
	if part and part:IsA("BasePart") then
		part.LocalTransparencyModifier = 0
		part.Transparency = if on then 0 else 1
	end
	rail = if on then railFor(model) else nil
	if rail then
		rail.gui.Enabled = on
	end
end

local function updateRail()
	local r = rail
	if not r or not clockLeft or not clockBudget then
		return
	end
	local fraction = math.clamp((clockLeft :: number) / (clockBudget :: number), 0, 1)
	r.fill.Size = UDim2.fromScale(fraction, 1)
	local low = (clockLeft :: number) <= 10
	r.fill.BackgroundColor3 = if low then Color3.fromRGB(200, 96, 60) else Brand.Colours.gold
	if low and not lowPlayed and clockRunning then
		lowPlayed = true
		Sound.play("low", 0.4, 0.6)
	end
end

local function updateHudLine()
	Hud.setLine(RoundPanel.number(local_.score), local_.multiplier, if clockLeft then clockLeft else nil)
end

local function setScore(value: number, multiplier: number)
	local model = seatedModel
	if model then
		Counter.set(model, value)
		Counter.setMultiplier(model, multiplier)
	end
	updateHudLine()
end

-- Everything that follows a filing, predicted locally before the server answers.
local function predict(p: Piece, caseId: string): boolean
	local correct = p.case == caseId
	if correct then
		local_.streak += 1
		if local_.lastCase == caseId then
			local_.runLength += 1
		else
			local_.runLength = 1
		end
		local_.lastCase = caseId
		local mult = room().tuning.multiplier
		local_.score += Scoring.filingPoints(p, local_.streak, mult) + Scoring.setBonus(local_.runLength)
		local_.multiplier = Scoring.multiplier(local_.streak)
	else
		local_.streak = 0
		local_.runLength = 0
		local_.lastCase = nil
		local_.multiplier = 1
		if State.get("wrongCase") == "Costs points too" then
			local_.score = math.max(0, local_.score - Scoring.wrongPenalty(round))
		end
	end
	return correct
end

local function intoCase(p: Piece, caseId: string)
	p.filed = true
	showName(p, false)
	local c = caseCentre(caseId)
	local jitter = Vector3.new((p.uid % 5 - 2) * 0.18, 0, ((p.uid // 5) % 3 - 1) * 0.2)
	local goal = CFrame.new(c + Vector3.new(0, 0.18, 0) + jitter) * CFrame.Angles(0, math.rad(p.uid * 37 % 360), 0)
	glideTo(p, goal, 0.32)
	task.delay(0.3, function()
		if p.model.Parent then
			p.model:ScaleTo(p.model:GetScale() * 0.7)
		end
	end)
end

local function backToFelt(p: Piece)
	p.filed = false
	glideTo(p, p.slot, 0.45, Enum.EasingStyle.Quint)
	showName(p, false)
end

local function release()
	if held then
		local p = pieces[held]
		if p and not p.filed and not p.pending then
			backToFelt(p)
		end
	end
	held = nil
	heldMode = nil
	Guide.hide()
	Hands.reach(nil)
	if State.inputKind() ~= "gamepad" then
		setHighlight(nil)
	end
end

local function file(uid: number, caseId: string)
	local p = pieces[uid]
	if not p or p.filed or p.pending or not playing then
		return
	end
	if not isOpen(caseId) then
		release()
		return
	end
	held = nil
	heldMode = nil
	Guide.hide()
	p.pending = true
	local correct = predict(p, caseId)
	if correct then
		intoCase(p, caseId)
		Sound.chime(local_.streak)
		if p.rare or p.mythic then
			Sound.shimmer()
		end
		caseGlow(caseId)
		Hands.reach(caseCentre(caseId) + Vector3.new(0, 0.6, 0))
		task.delay(0.35, function()
			if held == nil then
				Hands.reach(nil)
			end
		end)
	else
		backToFelt(p)
		Sound.wrong()
		Hands.reach(nil)
	end
	setScore(local_.score, local_.multiplier)
	tableEvent:FireServer({ op = "file", uid = uid, case = caseId })
end

local function lift(uid: number, mode: "drag" | "tap" | "pad")
	local p = pieces[uid]
	if not p or p.filed or p.pending or not playing then
		return
	end
	if held and held ~= uid then
		release()
	end
	held = uid
	heldMode = mode
	local above = p.slot.Position + Vector3.new(0, 0.9, 0)
	if mode ~= "drag" then
		glideTo(p, CFrame.new(above) * p.slot.Rotation, 0.22)
	end
	showName(p, true)
	Sound.play("pickup", 0.35, 1)
	Guide.show(roomId, above, caseCentre(p.case) + Vector3.new(0, 0.7, 0))
	Hands.reach(above)
	setHighlight(p.model)
	tableEvent:FireServer({ op = "lift", uid = uid })
	RoundCard.clear()
end

-- Screen point to the plane just above the felt.
local function pointOnFelt(screen: Vector2, lift_: number): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	local y = feltTop() + lift_
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (y - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function pieceAt(screen: Vector2): number?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { piecesFolder }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 80, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model then
			local uid = model:GetAttribute("Uid")
			if type(uid) == "number" then
				return uid
			end
		end
	end
	-- Forgiving on phones: the nearest unfiled piece within reach of the tap.
	local point = pointOnFelt(screen, 0.1)
	if not point then
		return nil
	end
	local best, bestD = nil, 0.75 * pieceScale()
	for uid, p in pieces do
		if not p.filed and not p.pending then
			local d = (Vector3.new(p.slot.X, 0, p.slot.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
			if d < bestD then
				best, bestD = uid, d
			end
		end
	end
	return best
end

local function caseAt(screen: Vector2): string?
	local point = pointOnFelt(screen, 0.3)
	if not point then
		return nil
	end
	for _, c in Catalogue.Cases do
		local cc = caseCentre(c.id)
		local dx = math.abs(point.X - cc.X)
		local dz = point.Z - cc.Z
		if dx <= T.caseWidth / 2 + 0.08 and dz >= -T.caseDepth / 2 - 0.7 and dz <= T.caseDepth / 2 + 0.4 then
			return c.id
		end
	end
	return nil
end

local function unfiledOrder(): { number }
	local list = {}
	for _, uid in order do
		local p = pieces[uid]
		if p and not p.filed and not p.pending then
			table.insert(list, uid)
		end
	end
	return list
end

local function padHighlight()
	if held then
		local caseId = openCases[math.clamp(padCase, 1, #openCases)]
		if caseId then
			local model = seatedModel
			local case = model and model:FindFirstChild("Case" .. caseIndex(caseId))
			if case and case:IsA("BasePart") then
				local h = highlight
				if h then
					h.Adornee = case
					h.Enabled = true
				end
			end
		end
		return
	end
	local list = unfiledOrder()
	if #list == 0 then
		setHighlight(nil)
		return
	end
	padIndex = math.clamp(padIndex, 1, #list)
	local p = pieces[list[padIndex]]
	if p then
		setHighlight(p.model)
	end
end

-- Rendering a deal: pieces arrive one by one with a short staggered glide.
local function renderDeal(message: { [string]: any })
	clearPieces()
	round = message.round
	roomId = message.room or roomId
	tableMode = message.mode or "room"
	openCases = message.cases
	local list = message.pieces :: { { [string]: any } }
	local slots = Layout.pieceSlots(centre, #list)
	local scale = pieceScale()
	local rng = Random.new(message.round * 7919 + #list)
	local alwaysNames = State.get("pieceNames") == "Always on" and namesAllowed()
	for i, data in list do
		local model = PieceModels.build(data.id, Brand.Colours.felt)
		if data.rare or data.mythic then
			PieceModels.gild(model)
		end
		if scale ~= 1 then
			model:ScaleTo(scale)
		end
		model:SetAttribute("Uid", data.uid)
		local rot = CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), 0)
		local slot = CFrame.new(slots[i]) * rot
		model:PivotTo(slot + Vector3.new(0, 3, 1.5))
		model.Parent = piecesFolder
		local p: Piece = {
			uid = data.uid,
			id = data.id,
			name = data.name,
			case = data.case,
			value = data.value,
			rare = data.rare,
			seasonal = data.seasonal,
			mythic = data.mythic,
			model = model,
			slot = slot,
			filed = false,
			pending = false,
			label = nil,
		}
		pieces[p.uid] = p
		table.insert(order, p.uid)
		task.delay((i - 1) * 0.06, function()
			if pieces[p.uid] == p then
				glideTo(p, slot, 0.5)
				if (i - 1) % 3 == 0 then
					Sound.play("drop", 0.12, 1.3)
				end
			end
		end)
		if (data.rare or data.mythic) and State.get("glow") ~= "Off" then
			local a = Instance.new("Attachment")
			a.Parent = model.PrimaryPart
			local e = Instance.new("ParticleEmitter")
			e.Rate = if State.get("glow") == "Subtle" then 1.5 else 3
			e.Lifetime = NumberRange.new(0.6, 1)
			e.Speed = NumberRange.new(0, 0.2)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0) })
			e.Color = ColorSequence.new(Brand.Colours.lightGold)
			e.LightEmission = 1
			e.Parent = a
		end
		if alwaysNames then
			p.label = nameLabel(p)
		end
	end
	-- Order pieces left-to-right, back-to-front for the gamepad.
	table.sort(order, function(a, b)
		local pa, pb = pieces[a].slot.Position, pieces[b].slot.Position
		if math.abs(pa.Z - pb.Z) > 0.3 then
			return pa.Z > pb.Z
		end
		return pa.X < pb.X
	end)
	padIndex = 1
	padCase = 1
	playing = true
	local r = room()
	RoundCard.land(centre, if tableMode == "room" then r.name else "Tonight's table", Voice.roundLabel(round, State.get("roundNumbers")), if tableMode == "room" then "Round" else r.name .. " rules")
	lampTo(2.4, 1.2)
	lowPlayed = false
	if message.clock then
		clockLeft = message.clock.left
		clockRunning = message.clock.running
		clockBudget = message.clock.budget
		showRail(true)
		updateRail()
	else
		clockLeft = nil
		clockRunning = false
		clockBudget = nil
		showRail(false)
	end
	server.score = message.score
	local_.score = message.score
	setScore(local_.score, local_.multiplier)
	if State.inputKind() == "gamepad" then
		task.delay(0.6, padHighlight)
	end
	-- A Mythic on the felt: the lamp dims and one light finds the piece.
	for _, p in pieces do
		if p.mythic then
			lampTo(0.4, 1.5)
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Bottom
			spot.Angle = 18
			spot.Range = 14
			spot.Brightness = 4
			spot.Color = Brand.Colours.lightGold
			local holder = Instance.new("Part")
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.Transparency = 1
			holder.Size = Vector3.new(0.2, 0.2, 0.2)
			holder.CFrame = CFrame.new(p.slot.Position + Vector3.new(0, 7, 0))
			holder.Parent = localFolder()
			spot.Parent = holder
			task.delay(6, function()
				holder:Destroy()
				lampTo(2.4, 1.5)
			end)
			break
		end
	end
end

local function onFiled(message: { [string]: any })
	local p = pieces[message.uid]
	server.score = message.score
	server.streak = message.streak
	server.runLength = message.runLength
	server.multiplier = message.multiplier
	server.lastCase = if message.correct then message.case else nil
	if p then
		p.pending = false
		-- A quiet correction if the prediction disagreed.
		if message.correct and not p.filed then
			intoCase(p, message.case)
		elseif not message.correct and p.filed then
			backToFelt(p)
		end
	end
	local_.score = server.score
	local_.streak = server.streak
	local_.runLength = server.runLength
	local_.multiplier = server.multiplier
	local_.lastCase = server.lastCase
	if message.clock then
		clockLeft = message.clock.left
		clockRunning = message.clock.running
	end
	setScore(local_.score, local_.multiplier)
	if State.inputKind() == "gamepad" then
		padHighlight()
	end
end

local function sendNext()
	tableEvent:FireServer({ op = "next" })
end

local function sendBank()
	tableEvent:FireServer({ op = "bank" })
end

function TableClient.leave()
	RoundPanel.close()
	tableEvent:FireServer({ op = "leave" })
end

local function onRoundEnd(message: { [string]: any })
	playing = false
	release()
	setHighlight(nil)
	local_.score = message.score
	server.score = message.score
	setScore(local_.score, local_.multiplier)
	lampTo(1.6, 1.2)
	Sound.play("round", 0.4, 1)
	Sound.briefDip(3)
	RoundCard.land(centre, "Round " .. Voice.roundLabel(message.round, State.get("roundNumbers")), message.grade, string.format("%s points", RoundPanel.number(message.score)))
	if message.last then
		return -- the Nightly card follows
	end
	task.delay(1.1, function()
		if seatedModel == nil then
			return
		end
		local inRoom = tableMode == "room"
		RoundPanel.round(message, {
			primary = Voice.Table.nextRound,
			onPrimary = sendNext,
			secondary = if inRoom then Voice.Table.bank else nil,
			onSecondary = if inRoom then sendBank else nil,
			onLeave = TableClient.leave,
		})
	end)
end

local function onBanked(message: { [string]: any })
	playing = false
	release()
	clearPieces()
	lampTo(1.6, 1.2)
	Sound.play("complete", 0.4, 1)
	local_ = { score = 0, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
	server = table.clone(local_)
	RoundCard.land(centre, "The run", message.grade, string.format("%s points", RoundPanel.number(message.score)))
	task.delay(1.0, function()
		if seatedModel == nil then
			return
		end
		RoundPanel.banked(message, {
			primary = "Another run",
			onPrimary = function()
				tableEvent:FireServer({ op = "again" })
			end,
			onLeave = TableClient.leave,
		})
	end)
end

local function onNightlyCard(message: { [string]: any })
	playing = false
	release()
	clearPieces()
	showRail(false)
	lampTo(1.6, 1.2)
	Sound.play("complete", 0.4, 1)
	local_ = { score = 0, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
	server = table.clone(local_)
	RoundCard.land(centre, "Tonight's table", message.grade, string.format("%s points", RoundPanel.number(message.score)))
	task.delay(1.0, function()
		if seatedModel == nil then
			return
		end
		NightlyCard.show(message, {
			rehearse = function()
				tableEvent:FireServer({ op = "again" })
			end,
			leave = TableClient.leave,
		})
	end)
end

local function bindInput()
	ContextActionService:BindActionAtPriority("MaisonTablePad", function(_, state, input)
		if state ~= Enum.UserInputState.Begin or not playing or Root.isOpen() then
			return Enum.ContextActionResult.Pass
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.DPadLeft or key == Enum.KeyCode.DPadRight then
			local step = if key == Enum.KeyCode.DPadLeft then -1 else 1
			if held then
				padCase = math.clamp(padCase + step, 1, #openCases)
			else
				padIndex += step
				local n = #unfiledOrder()
				if n > 0 then
					padIndex = ((padIndex - 1) % n) + 1
				end
			end
			padHighlight()
			return Enum.ContextActionResult.Sink
		elseif key == Enum.KeyCode.ButtonA then
			if held then
				local caseId = openCases[math.clamp(padCase, 1, #openCases)]
				if caseId then
					file(held :: number, caseId)
				end
			else
				local list = unfiledOrder()
				local uid = list[math.clamp(padIndex, 1, math.max(1, #list))]
				if uid then
					lift(uid, "pad")
					-- The case cursor starts at the left, never on the right case (that would be a hint).
					padCase = 1
					padHighlight()
				end
			end
			return Enum.ContextActionResult.Sink
		elseif key == Enum.KeyCode.ButtonB then
			if held then
				release()
				padHighlight()
				return Enum.ContextActionResult.Sink
			end
			TableClient.leave()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 2000, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB)

	-- Keys 1 to 6 file the held piece into that case (PC).
	ContextActionService:BindAction("MaisonTableKeys", function(_, state, input)
		if state ~= Enum.UserInputState.Begin or not held or not playing then
			return Enum.ContextActionResult.Pass
		end
		local map = {
			[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
		}
		local n = map[input.KeyCode]
		if n and Catalogue.Cases[n] then
			file(held :: number, Catalogue.Cases[n].id)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six)
end

local function unbindInput()
	ContextActionService:UnbindAction("MaisonTablePad")
	ContextActionService:UnbindAction("MaisonTableKeys")
end

local function pointerDown(input: InputObject, processed: boolean)
	if processed or seatedModel == nil or not playing or Root.isOpen() then
		return
	end
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	local uid = pieceAt(pos)
	if uid then
		press = { uid = uid, at = pos, input = input }
		return
	end
	if held then
		local caseId = caseAt(pos)
		if caseId then
			file(held :: number, caseId)
		else
			release()
		end
	end
end

local function pointerMoved(input: InputObject)
	local pr = press
	if pr then
		local t = input.UserInputType
		local same = if t == Enum.UserInputType.Touch then input == pr.input else t == Enum.UserInputType.MouseMovement
		if not same then
			return
		end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if (pos - pr.at).Magnitude > 8 then
			lift(pr.uid, "drag")
			press = nil
		end
		return
	end
	if held and heldMode == "drag" then
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then
			return
		end
		local point = pointOnFelt(Vector2.new(input.Position.X, input.Position.Y), 0.9)
		local p = pieces[held :: number]
		if point and p then
			-- Keep the piece over the table.
			local hw, minZ, maxZ = T.width / 2 - 0.4, T.feltMinZ - 0.6, T.caseRowZ + T.caseDepth / 2
			local lx = math.clamp(point.X - centre.X, -hw, hw)
			local lz = math.clamp(point.Z - centre.Z, minZ, maxZ)
			local at = Vector3.new(centre.X + lx, point.Y, centre.Z + lz)
			p.model:PivotTo(CFrame.new(at) * p.slot.Rotation)
			Guide.move(at)
			Hands.follow(at)
		end
	end
end

local function pointerUp(input: InputObject)
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	local pr = press
	if pr then
		press = nil
		-- A tap. With Tap to sort on, it lifts (or puts back) the piece.
		if State.get("tapToSort") == "On" then
			if held == pr.uid then
				release()
			else
				lift(pr.uid, "tap")
			end
		end
		return
	end
	if held and heldMode == "drag" then
		local caseId = caseAt(pos)
		if caseId then
			file(held :: number, caseId)
		else
			release()
		end
	end
end

local function onSeated(message: { [string]: any })
	local model: Model? = nil
	for _, m in CollectionService:GetTagged("MaisonTable") do
		if m:IsA("Model") and m:GetAttribute("TableId") == message.table then
			model = m
		end
	end
	if not model then
		return
	end
	seatedModel = model
	local c = model:GetAttribute("Centre")
	centre = if typeof(c) == "Vector3" then c else model:GetPivot().Position
	roomId = message.room or "salon"
	State.seated = true
	local_ = { score = 0, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
	server = table.clone(local_)
	Counter.own(model, true)
	Counter.set(model, 0, true)
	Counter.setMultiplier(model, 1)
	local ctl = getControls()
	if ctl then
		ctl:Disable()
	end
	CameraRig.toTable(centre)
	Hud.setSeated(true)
	updateHudLine()
	Hands.attach()
	bindInput()
	Sound.play("chair", 0.3, 1)
	TableClient.Seated:Fire()
	for _, cb in toTableCallbacks do
		task.spawn(cb)
	end
end

local function onLeft(message: { [string]: any })
	showRail(false)
	if Root.isOpen("NightlyCard") then
		Root.close("NightlyCard")
	end
	local model = seatedModel
	seatedModel = nil
	playing = false
	State.seated = false
	clearPieces()
	RoundCard.destroy()
	RoundPanel.close()
	paused = false
	unbindInput()
	Hands.detach()
	if model then
		Counter.own(model, false)
		local light = model:FindFirstChild("Bulb")
		local spot = light and light:FindFirstChild("TableLight")
		if spot and spot:IsA("SpotLight") then
			TweenService:Create(spot, TweenInfo.new(1.2), { Brightness = 1.4 }):Play()
		end
	end
	Hud.setSeated(false)
	local ctl = getControls()
	if ctl then
		ctl:Enable()
	end
	CameraRig.leaveTable()
	local summary = message.summary
	if type(summary) == "table" and (summary.score or 0) > 0 then
		Toast.show("The run is banked", string.format("%s points · %s", RoundPanel.number(summary.score), summary.grade), 4.5)
	end
	TableClient.Left:Fire()
end

function TableClient.onSeated(cb: () -> ())
	table.insert(toTableCallbacks, cb)
end

function TableClient.isSeated(): boolean
	return seatedModel ~= nil
end

function TableClient.start()
	tableEvent.OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" then
			return
		end
		local op = message.op
		if op == "seated" then
			onSeated(message)
		elseif op == "deal" then
			RoundPanel.close()
			renderDeal(message)
		elseif op == "filed" then
			onFiled(message)
		elseif op == "rejected" then
			local p = pieces[message.uid]
			if p then
				p.pending = false
				backToFelt(p)
			end
			local_ = table.clone(server)
			setScore(local_.score, local_.multiplier)
		elseif op == "roundEnd" then
			onRoundEnd(message)
		elseif op == "banked" then
			onBanked(message)
		elseif op == "nightlyCard" then
			onNightlyCard(message)
		elseif op == "clock" then
			if message.clock then
				clockLeft = message.clock.left
				clockRunning = message.clock.running
				clockBudget = message.clock.budget
			end
		elseif op == "left" then
			onLeft(message)
		end
	end)
	-- The clock freezes while a panel is open in the four rooms (never in the Nightly).
	Root.PanelsChanged:Connect(function()
		if seatedModel == nil then
			return
		end
		local open = Root.isOpen() and Root.top() ~= "Round"
		if tableMode == "room" and open ~= paused then
			paused = open
			tableEvent:FireServer({ op = "pause", on = open })
		end
	end)
	UserInputService.InputBegan:Connect(pointerDown)
	UserInputService.InputChanged:Connect(pointerMoved)
	UserInputService.InputEnded:Connect(pointerUp)
	RunService.Heartbeat:Connect(function(dt)
		if clockLeft and clockRunning and playing then
			if not paused then
				clockLeft = math.max(0, (clockLeft :: number) - dt)
			end
			updateHudLine()
			updateRail()
		end
	end)
	-- Settings that change the table apply at once.
	State.SettingChanged:Connect(function(key)
		if key == "pieceNames" then
			for _, p in pieces do
				showName(p, held == p.uid)
			end
		elseif key == "pieceSize" then
			local scale = pieceScale()
			for _, p in pieces do
				if not p.filed then
					p.model:ScaleTo(scale)
				end
			end
		end
	end)
end

return TableClient
