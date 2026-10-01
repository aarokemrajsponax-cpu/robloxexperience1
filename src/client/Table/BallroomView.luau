--!strict
-- Lights Out on the guest's screen, beyond their own felt: the four brass tabs that choose where
-- parcels go, the line that says how many lamps are lit, parcels flying between tables and
-- burning on your felt, other lamps flickering when a felt is over sixteen, the Key leader's
-- glint, and the last lamp found from the Gallery. Watching from the Gallery drifts the camera
-- between the tables still lit. Local decoration; the server decides all of it.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Layout = require(ReplicatedStorage.Shared.Layout)
local LightsOut = require(ReplicatedStorage.Shared.LightsOut)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Voice = require(ReplicatedStorage.Shared.Voice)

local CameraRig = require(script.Parent.Parent.Camera)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Root = require(script.Parent.Parent.UI.Root)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)
local Hud = require(script.Parent.Parent.UI.Hud)
local Parcels = require(script.Parent.Parcels)
local Flourish = require(script.Parent.Flourish)
local Invite = require(script.Parent.Parent.UI.Invite)

local BallroomView = {}

local T = Layout.Table
local function capacity(): number
	return Config.data.Ballroom.capacity
end
local tableEvent = Remotes.event("Table")
local player = Players.LocalPlayer

type Flying = { built: Parcels.Built, to: number }

local mySeat: number? = nil
local myFrame = CFrame.new()
local tab = "random"
local lit = 0
local keys = 0
local felt = 0
local closing = false
local playing = false
local parcels: { [number]: Flying } = {}
local tabsFrame: Frame? = nil
local tabKeys: { [string]: TextButton } = {}
local statusLabel: TextLabel? = nil
local inRoom = false -- the status line shows only in the Ballroom itself
local watching = false
local zoneKeysShown = false
local flickering: { [Model]: boolean } = {}
local glints: { [Model]: ParticleEmitter } = {}

local folder = Instance.new("Folder")
folder.Name = "Ballroom"

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

local function tableModel(i: number): Model?
	for _, m in CollectionService:GetTagged("BallroomTable") do
		if m:IsA("Model") and m:GetAttribute("Seat") == i then
			return m
		end
	end
	return nil
end

local function frameOf(i: number): CFrame
	local m = tableModel(i)
	local f = m and m:GetAttribute("Frame")
	return if typeof(f) == "CFrame" then f else Layout.ballroomFrame(i)
end

-- Where parcels wait on a felt: the near-left corner, stacked.
local function dock(i: number, n: number): CFrame
	return frameOf(i) * CFrame.new(-T.width / 2 + 0.75, T.topY + 0.32, T.feltMinZ + 0.4 + (n - 1) * 0.85)
end

local function waitingOn(i: number): number
	local n = 0
	for _, p in parcels do
		if p.to == i then
			n += 1
		end
	end
	return n
end

local function lampOf(m: Model): SpotLight?
	local bulb = m:FindFirstChild("Bulb")
	local light = bulb and bulb:FindFirstChild("TableLight")
	return if light and light:IsA("SpotLight") then light else nil
end

---------------------------------------------------------------------------------------------------
-- The status line and the tabs
---------------------------------------------------------------------------------------------------
local function status()
	Sound.setLamps(if lit > 0 then lit else nil)
	local label = statusLabel
	if not label then
		return
	end
	local parts = {}
	if lit > 0 then
		table.insert(parts, string.format("%d lamps lit", lit))
	end
	if mySeat and playing then
		table.insert(parts, string.format("felt %d of %d", felt, capacity()))
		table.insert(parts, if keys == 1 then "1 Key" else string.format("%d Keys", keys))
	end
	if closing then
		table.insert(parts, "Closing Time")
	end
	label.Text = Theme.track(table.concat(parts, "  ·  "))
	label.TextColor3 = if mySeat and playing and felt > capacity() - 3 then Color3.fromRGB(220, 120, 80) else Brand.Colours.lightGold
	label.Visible = #parts > 0 and (inRoom or mySeat ~= nil)
end

local function highlightTabs()
	for id, k in tabKeys do
		k.BackgroundTransparency = if id == tab then 0.05 else 0.35
		k.TextTransparency = if id == tab then 0 else 0.25
	end
end

local function choose(id: string)
	if id == tab then
		return
	end
	tab = id
	highlightTabs()
	tableEvent:FireServer({ op = "tab", tab = id })
end

local function buildUi()
	if not statusLabel then
		statusLabel = Theme.text(Root.hud, "", 13, "caps", {
			Name = "BallroomStatus",
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 52),
			Size = UDim2.fromOffset(520, 22),
			TextColor3 = Brand.Colours.lightGold,
			Visible = false,
		})
	end
	if tabsFrame then
		return
	end
	local f = Instance.new("Frame")
	f.Name = "BallroomTabs"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0, 0.5)
	f.Position = UDim2.new(0, 12, 0.5, 0)
	f.Size = UDim2.fromOffset(150, 250)
	f.Visible = false
	f.Parent = Root.hud
	Theme.list(f, 6)
	Theme.text(f, "Parcels go to", 11, "caps", { LayoutOrder = 0, TextColor3 = Brand.Colours.smoke })
	for i, id in LightsOut.Tabs do
		local k = Theme.key(f, LightsOut.TabNames[id], false, function()
			choose(id)
		end, 150)
		k.LayoutOrder = i
		tabKeys[id] = k
	end
	tabsFrame = f
	highlightTabs()
end

local function showTabs(on: boolean)
	buildUi()
	if tabsFrame then
		tabsFrame.Visible = on
	end
	if on then
		-- Tab (keyboard) and the shoulder buttons (gamepad) cycle the tabs.
		ContextActionService:BindAction("MaisonBallroomTabs", function(_, state, input)
			if state ~= Enum.UserInputState.Begin or Root.isOpen() then
				return Enum.ContextActionResult.Pass
			end
			local i = table.find(LightsOut.Tabs, tab) or 1
			local step = if input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1
			choose(LightsOut.Tabs[((i - 1 + step) % #LightsOut.Tabs) + 1])
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Tab, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
	else
		ContextActionService:UnbindAction("MaisonBallroomTabs")
	end
end

---------------------------------------------------------------------------------------------------
-- Parcels between tables
---------------------------------------------------------------------------------------------------
local function fly(model: Model, from: CFrame, to: CFrame, seconds: number)
	model:PivotTo(from)
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(a)
		if model.Parent then
			local p = from.Position:Lerp(to.Position, a) + Vector3.new(0, math.sin(a * math.pi) * 6, 0)
			model:PivotTo(CFrame.new(p) * to.Rotation)
		end
	end)
	local t = TweenService:Create(value, Ease.scaled(TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)), { Value = 1 })
	t.Completed:Once(function()
		value:Destroy()
		if model.Parent then
			model:PivotTo(to)
		end
	end)
	t:Play()
end

local function restack()
	local ids = {}
	for id, p in parcels do
		if p.to == mySeat then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for i, id in ids do
		parcels[id].built.model:PivotTo(dock(mySeat :: number, i))
	end
end

local function onParcel(message: { [string]: any })
	local from, to = message.from :: number, message.to :: number
	if from ~= mySeat and to ~= mySeat then
		return -- other tables' parcels aren't drawn (the room would be a blizzard of boxes)
	end
	local built = Parcels.build(message.count)
	built.model.Parent = localFolder()
	parcels[message.id] = { built = built, to = to }
	local start = frameOf(from) * CFrame.new(0, T.topY + 1.2, T.caseRowZ)
	local goal = dock(to, waitingOn(to))
	local travel = math.min(0.8, (message.fuse :: number) * 0.3)
	fly(built.model, start, goal, travel)
	task.delay(travel, function()
		if built.model.Parent then
			Parcels.burn(built, (message.fuse :: number) - travel)
		end
	end)
	if to == mySeat then
		Sound.play("low", 0.35, 0.8)
		Toast.show(Voice.Library.parcelIn, string.format("%d from Table %d", message.count, from), 1.6)
	else
		Sound.play("round", 0.25, 1.4)
	end
end

local function drop(id: number): Vector3?
	local p = parcels[id]
	if not p then
		return nil
	end
	parcels[id] = nil
	local at = p.built.model:GetPivot().Position
	Parcels.burst(p.built.model)
	restack()
	return at
end

---------------------------------------------------------------------------------------------------
-- The room: flickering lamps, the Key leader's glint
---------------------------------------------------------------------------------------------------
local flickerClock = 0
local function roomStep(dt: number)
	flickerClock += dt
	if flickerClock < 0.09 then
		return
	end
	flickerClock = 0
	for _, m in CollectionService:GetTagged("BallroomTable") do
		if m:IsA("Model") then
			local light = lampOf(m)
			local on = m:GetAttribute("Flicker") == true
			if light then
				if on then
					flickering[m] = true
					light.Brightness = if math.random() < 0.45 then 0.25 else 1.2 + math.random() * 1.4
				elseif flickering[m] then
					flickering[m] = nil
					light.Brightness = if m:GetAttribute("Out") then 0 else 2.4
				end
			end
			local leader = m:GetAttribute("KeyLeader") == true
			if leader and not glints[m] then
				local bulb = m:FindFirstChild("Bulb")
				if bulb and bulb:IsA("BasePart") then
					local e = Instance.new("ParticleEmitter")
					e.Name = "KeyGlint"
					e.Rate = if State.get("glow") == "Off" then 0 else 4
					e.Lifetime = NumberRange.new(0.5, 0.9)
					e.Speed = NumberRange.new(0.2, 0.6)
					e.SpreadAngle = Vector2.new(180, 180)
					e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0) })
					e.Color = ColorSequence.new(Brand.Colours.lightGold)
					e.LightEmission = 1
					e.Parent = bulb
					glints[m] = e
				end
			elseif not leader and glints[m] then
				glints[m]:Destroy()
				glints[m] = nil
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Watching from the Gallery
---------------------------------------------------------------------------------------------------
local function litTables(): { Model }
	local out = {}
	for _, m in CollectionService:GetTagged("BallroomTable") do
		if m:IsA("Model") and not m:GetAttribute("Out") and (m:GetAttribute("Score") or 0) > 0 then
			table.insert(out, m)
		end
	end
	return out
end

-- A composed look at one table from above and behind it, as a streamer would want it.
local function shotOf(m: Model): CFrame
	local f = m:GetAttribute("Frame")
	local frame = if typeof(f) == "CFrame" then f else m:GetPivot()
	local focus = frame:PointToWorldSpace(Vector3.new(0, T.topY, 0))
	local eye = frame:PointToWorldSpace(Vector3.new(4, T.topY + 9, -10))
	return CFrame.lookAt(eye, focus)
end

local function stopWatching()
	if not watching then
		return
	end
	watching = false
	CameraRig.stopWatching()
end

local function watch()
	if watching then
		stopWatching()
		return
	end
	watching = true
	CameraRig.watch(function(): CFrame?
		local list = litTables()
		if #list == 0 then
			return Layout.Ballroom.galleryView
		end
		return shotOf(list[math.random(1, #list)])
	end, 6)
end

local function zoneKeys()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local inBallroom = root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "ballroom"
	if inBallroom ~= inRoom then
		inRoom = inBallroom
		status()
	end
	local want = inBallroom and mySeat == nil and not State.seated
	if want then
		Hud.setExtraKeys({
			{
				text = "Next evening",
				onPress = function()
					tableEvent:FireServer({ op = "nextEvening" })
					stopWatching()
				end,
			},
			{ text = if watching then "Stop watching" else "Watch", onPress = watch },
			{ text = "Invite", onPress = Invite.ballroom },
		})
		zoneKeysShown = true
	elseif zoneKeysShown then
		Hud.setExtraKeys({})
		zoneKeysShown = false
		stopWatching()
	end
end

---------------------------------------------------------------------------------------------------
-- The evening's moments
---------------------------------------------------------------------------------------------------
local function lastLamp(message: { [string]: any })
	local winner = message.winner
	local m = if type(winner) == "number" then tableModel(winner) else nil
	if not m then
		return
	end
	-- The camera finds the last lamp from the Gallery rail.
	local f = m:GetAttribute("Frame")
	local frame = if typeof(f) == "CFrame" then f else m:GetPivot()
	local target = frame:PointToWorldSpace(Vector3.new(0, T.topY, 0))
	local B = Layout.Ballroom
	local eye = Vector3.new(B.galleryView.Position.X, B.galleryView.Position.Y, B.galleryView.Position.Z)
	CameraRig.moment(CFrame.lookAt(eye, target), 4.5)
	if winner == mySeat then
		Sound.play("complete", 0.5, 1)
		Sound.shimmer()
		task.delay(1.4, Flourish.play, target + Vector3.new(0, 1, 0))
	else
		Sound.play("round", 0.3, 0.8)
	end
end

-- Handles one Lights Out message. Returns where a parcel burst, for pieces spilling onto the
-- guest's own felt.
function BallroomView.handle(message: { [string]: any }): Vector3?
	local op = message.op
	buildUi()
	if op == "gathering" then
		Toast.show(Voice.Ballroom.title, Voice.fill(Voice.Ballroom.gathering, { seconds = tostring(math.ceil(message.startsIn or 0)) }), 3.5)
		lit = 0
		closing = false
	elseif op == "eveningStart" then
		tab = if type(message.tab) == "string" then message.tab else "random"
		keys = 0
		lit = Config.data.Ballroom.tables
		closing = false
		playing = true
		highlightTabs()
		showTabs(true)
		Toast.show(Voice.Ballroom.title, if message.counted then Voice.Ballroom.counted elseif Workspace:GetAttribute("PrivateEvening") == true then Voice.Private.line else Voice.Ballroom.notCounted, 4)
	elseif op == "eveningBegins" then
		lit = message.alive or lit
	elseif op == "tab" then
		tab = message.tab
		highlightTabs()
	elseif op == "parcel" then
		onParcel(message)
	elseif op == "parcelShrink" then
		local p = parcels[message.id]
		if p then
			Parcels.setCount(p.built, message.count)
		end
	elseif op == "parcelCancel" then
		if drop(message.id) then
			Sound.play("chime", 0.3, 1.5)
		end
	elseif op == "parcelOpen" then
		Sound.play("drop", 0.3, 0.8)
		return drop(message.id)
	elseif op == "parcelLanded" then
		if message.seat ~= mySeat then
			drop(message.id)
		end
	elseif op == "lampOut" then
		lit = message.alive or lit
		if message.by == mySeat and mySeat ~= nil then
			keys = message.keys or keys
			Sound.shimmer()
			Toast.show(Voice.Ballroom.key, Voice.fill(Voice.Ballroom.tookKey, { table = tostring(message.seat) }), 2.5)
		end
	elseif op == "out" then
		playing = false
		showTabs(false)
	elseif op == "closingTime" then
		closing = true
		Toast.show(Voice.Ballroom.closingTime, Voice.Ballroom.closingLine, 3.5)
		Sound.play("low", 0.4, 0.7)
	elseif op == "cases" then
		Toast.show(Voice.Ballroom.title, Voice.Ballroom.sixthCase, 2.5)
	elseif op == "eveningEnd" then
		playing = false
		lit = 1
		showTabs(false)
		for id in parcels do
			drop(id)
		end
		lastLamp(message)
	elseif op == "queued" then
		Toast.show(Voice.Ballroom.title, Voice.Ballroom.queued, 3.5)
	end
	status()
	return nil
end

function BallroomView.seated(_model: Model, frame: CFrame, seat: number?)
	mySeat = seat
	myFrame = frame
	felt = 0
	keys = 0
	playing = false
	stopWatching()
	if zoneKeysShown then
		Hud.setExtraKeys({})
		zoneKeysShown = false
	end
	localFolder()
	buildUi()
	status()
end

function BallroomView.setFelt(count: number, keyCount: number?)
	felt = count
	if keyCount then
		keys = keyCount
	end
	status()
end

function BallroomView.mySeat(): number?
	return mySeat
end

function BallroomView.frame(): CFrame
	return myFrame
end

function BallroomView.clear()
	for id in parcels do
		drop(id)
	end
	mySeat = nil
	playing = false
	showTabs(false)
	status()
	Sound.setLamps(nil)
end

function BallroomView.start()
	RunService.Heartbeat:Connect(roomStep)
	task.spawn(function()
		while true do
			zoneKeys()
			task.wait(0.5)
		end
	end)
end

return BallroomView
