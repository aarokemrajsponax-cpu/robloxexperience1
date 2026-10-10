--!strict
-- Your Suite, drawn on your own screen (§3): the piece in each spot from your Suite (or the
-- house's own where it has one), built with the Furniture library; the Gold Key rooms opened for
-- holders; and nobody else in the rooms: other guests in the Suite are hidden here, so it's
-- always yours alone. A friend on Roblox may take you into theirs (the Suites key; the server
-- checks the friendship): then their Suite is drawn here as they've furnished it, and the guests
-- in that same Suite see each other; everyone in any other Suite stays unseen.
--
-- The pieces live: the fish swim, the pool shimmers, the fire pit flickers. Things to use carry a
-- prompt (Furniture's "UsePrompt", its attribute "Use" naming what it does); using one plays here,
-- on this screen only: the television and the cinema screen show something, the shower runs,
-- the sauna steams, the hot tub bubbles, the arcade plays, the punchbag swings, the massage chair
-- hums, and your own piano opens its keys for you, free.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Furniture = require(ReplicatedStorage.Shared.Furniture)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Suite = require(ReplicatedStorage.Shared.Suite)
local Closet = require(script.Parent.Parent.Closet)
local Sound = require(script.Parent.Parent.Sound)
local Toast = require(script.Parent.Parent.UI.Toast)

local SuiteView = {}

local player = Players.LocalPlayer
local S = Layout.Suite

-- Opens this guest's own piano (set by Main: PianoPanel.private).
SuiteView.playPiano = function(_piano: Model) end

local folder: Folder? = nil
local inside = false

-- The friend's Suite this guest is visiting (sent by the server), or nil: their own.
type Visit = { userId: number, name: string, suite: { [string]: string }, goldKey: boolean }
local visiting: Visit? = nil

function SuiteView.visiting(): Visit?
	return visiting
end

local function placed(): { [string]: string }
	local v = visiting
	return if v then v.suite else Closet.suite
end

local function hasGoldKey(): boolean
	local v = visiting
	return if v then v.goldKey else Closet.goldKey
end
local hidden: { [Player]: boolean? } = {}

-- What stands in each spot now, so a change rebuilds only what changed.
type Drawn = { key: string, model: Model }
local drawn: { [string]: Drawn } = {}

-- The parts that move, gathered once each time the Suite is drawn.
type Fish = { part: BasePart, home: CFrame, n: number }
local fishes: { Fish } = {}
local waters: { BasePart } = {}
local flames: { BasePart } = {}

local function gather()
	table.clear(fishes)
	table.clear(waters)
	table.clear(flames)
	for _, d in drawn do
		for _, p in d.model:GetDescendants() do
			if p:IsA("BasePart") then
				local fish = p:GetAttribute("Fish")
				if type(fish) == "number" then
					table.insert(fishes, { part = p, home = p.CFrame, n = fish })
				elseif p:GetAttribute("Water") then
					table.insert(waters, p)
				elseif p:GetAttribute("Flame") then
					table.insert(flames, p)
				end
			end
		end
	end
end

-- What a piece is: its kind and its look, as one string.
local function keyOf(kind: string, style: { [string]: any }): string
	local parts = { kind }
	local keys = {}
	for k in style do
		table.insert(keys, tostring(k))
	end
	table.sort(keys)
	for _, k in keys do
		local v = style[k]
		table.insert(parts, k .. "=" .. (if typeof(v) == "Color3" then (v :: Color3):ToHex() else tostring(v)))
	end
	return table.concat(parts, ";")
end

-- What stands in each spot for this guest: { [spot] = style }, nil where the spot is bare.
function SuiteView.pieces(placed: { [string]: string }, goldKey: boolean): { [string]: { [string]: any } }
	return Suite.pieces(placed, goldKey)
end

local function draw()
	local f = folder
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = "Suite"
		nf.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
		folder = nf
		f = nf
	end
	local want = Suite.pieces(placed(), hasGoldKey())
	-- Take away what's no longer wanted, or no longer the same.
	for spotId, d in drawn do
		local style = want[spotId]
		local kind = style and Suite.kindOf(spotId, style)
		if not style or not kind or keyOf(kind, style) ~= d.key then
			d.model:Destroy()
			drawn[spotId] = nil
		end
	end
	-- And build what's missing, a few a frame so walking in never stutters.
	local built = 0
	for spotId, style in want do
		if drawn[spotId] then
			continue
		end
		local kind = Suite.kindOf(spotId, style)
		local cf = S.spots[spotId]
		if not kind or not cf then
			continue
		end
		local ok, model = pcall(function()
			local m = Furniture.build(kind, nil, cf, style, true, Layout.SUITE_FURNITURE)
			return m
		end)
		if ok and model then
			model.Name = spotId
			model:SetAttribute("Spot", spotId)
			model.Parent = f
			drawn[spotId] = { key = keyOf(kind, style), model = model }
			built += 1
			if built % 4 == 0 and RunService:IsRunning() then
				task.wait()
				if not inside then
					return
				end
			end
		end
	end
	gather()
end

local function clear()
	local f = folder
	if f then
		f:Destroy()
		folder = nil
	end
	drawn = {}
	table.clear(fishes)
	table.clear(waters)
	table.clear(flames)
end

---------------------------------------------------------------------------------------------------
-- Using things
---------------------------------------------------------------------------------------------------

local busy: { [Instance]: boolean } = {}

-- A screen's picture: a SurfaceGui with a slow gradient and a title, lit.
local function showOn(screen: BasePart, title: string, colours: { Color3 }, seconds: number)
	if busy[screen] then
		return
	end
	busy[screen] = true
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Picture"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = screen
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(colours[1], colours[2] or colours[1])
	grad.Rotation = 20
	grad.Parent = back
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.8, 0.3)
	label.Position = UDim2.fromScale(0.1, 0.35)
	label.TextScaled = true
	label.Text = title
	label.TextColor3 = Color3.fromRGB(255, 244, 220)
	label.FontFace = Font.new("rbxassetid://12187374765")
	label.Parent = back
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Brightness = 1.2
	glow.Range = 14
	glow.Angle = 100
	glow.Color = colours[1]
	glow.Parent = screen
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < seconds and gui.Parent do
			local t = os.clock() - t0
			grad.Rotation = 20 + math.sin(t * 0.4) * 40
			grad.Offset = Vector2.new(math.sin(t * 0.3) * 0.3, 0)
			label.TextTransparency = math.clamp(math.abs(math.sin(t * 0.25)) * 1.4 - 0.4, 0, 1)
			local c = colours[(math.floor(t / 4) % #colours) + 1]
			glow.Color = c
			task.wait(1 / 20)
		end
		gui:Destroy()
		glow:Destroy()
		busy[screen] = nil
	end)
end

local function screenOf(model: Instance): BasePart?
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Screen") then
			return d
		end
	end
	return nil
end

local function emitter(parent: BasePart, name: string, props: { [string]: any }): ParticleEmitter
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ParticleEmitter") then
		return existing
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function seated(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Sit
end

local USES: { [string]: (model: Model, prompt: ProximityPrompt) -> () } = {
	tv = function(model)
		local screen = screenOf(model)
		if screen then
			showOn(screen, "Maison Television", { Color3.fromRGB(40, 60, 140), Color3.fromRGB(140, 40, 90), Color3.fromRGB(30, 110, 120) }, 40)
		end
	end,
	film = function(model)
		local screen = screenOf(model)
		if screen then
			Toast.show("The screening room", "Tonight's film: lights down, curtains back.", 4)
			showOn(screen, "Maison Noir presents", { Color3.fromRGB(255, 210, 150), Color3.fromRGB(120, 60, 30), Color3.fromRGB(40, 50, 90) }, 45)
		end
	end,
	arcade = function(model)
		local screen = screenOf(model)
		if screen then
			showOn(screen, "PLAYER ONE", { Color3.fromRGB(255, 60, 160), Color3.fromRGB(60, 200, 255), Color3.fromRGB(255, 220, 60) }, 20)
			for i = 0, 5 do
				task.delay(i * 0.18, function()
					Sound.play("tick", 0.4, 1 + i * 0.12)
				end)
			end
		end
	end,
	shower = function(model)
		local head: BasePart? = nil
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("ShowerHead") then
				head = d
			end
		end
		if not head then
			return
		end
		local e = emitter(head, "Rain", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(210, 230, 255)),
			LightEmission = 0.3,
			Size = NumberSequence.new(0.08),
			Transparency = NumberSequence.new(0.35),
			Lifetime = NumberRange.new(0.9, 1.1),
			Speed = NumberRange.new(9, 11),
			SpreadAngle = Vector2.new(12, 12),
			EmissionDirection = Enum.NormalId.Bottom,
			Acceleration = Vector3.new(0, -20, 0),
		})
		e.Rate = if e.Rate > 0 then 0 else 160
		Sound.play("drop", 0.3, 0.7)
	end,
	sauna = function(model)
		local stones: BasePart? = nil
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Embers" then
				stones = d
			end
		end
		if stones then
			local e = emitter(stones, "Steam", {
				Texture = "rbxasset://textures/particles/smoke_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(240, 240, 240)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(2, 3.5),
				Speed = NumberRange.new(1, 2),
				SpreadAngle = Vector2.new(40, 40),
				EmissionDirection = Enum.NormalId.Top,
			})
			e:Emit(30)
			Sound.play("drop", 0.4, 0.55)
		end
	end,
	bubbles = function(model)
		local water: BasePart? = nil
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Bubbles") then
				water = d
			end
		end
		if water then
			local e = emitter(water, "Bubbles", {
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(230, 250, 255)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.05) }),
				Transparency = NumberSequence.new(0.3),
				Lifetime = NumberRange.new(0.4, 0.8),
				Speed = NumberRange.new(1.5, 3),
				SpreadAngle = Vector2.new(70, 70),
				EmissionDirection = Enum.NormalId.Top,
			})
			e.Rate = if e.Rate > 0 then 0 else 90
		end
	end,
	punch = function(model)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Swings") then
				if busy[d] then
					return
				end
				busy[d] = true
				local rest = d.CFrame
				local pivot = rest * CFrame.new(0, 2.1 + 1.4, 0) -- the chain's end above it
				task.spawn(function()
					for i = 0, 40 do
						local swing = math.sin(i / 40 * math.pi * 3) * math.rad(14) * (1 - i / 40)
						d.CFrame = pivot * CFrame.Angles(swing, 0, 0) * pivot:Inverse() * rest
						task.wait(1 / 30)
					end
					d.CFrame = rest
					busy[d] = nil
				end)
				Sound.play("drop", 0.6, 0.6)
				return
			end
		end
	end,
	massage = function()
		if not seated() then
			Toast.show("The massage chair", "Sit in it first, then press start.", 3)
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or busy[humanoid] then
			return
		end
		busy[humanoid] = true
		Toast.show("The massage chair", "Relax. Eight seconds of bliss.", 3)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 8 and humanoid.Sit do
				local t = os.clock() - t0
				humanoid.CameraOffset = Vector3.new(math.sin(t * 31) * 0.03, math.sin(t * 23) * 0.04, 0)
				task.wait()
			end
			humanoid.CameraOffset = Vector3.zero
			busy[humanoid] = nil
		end)
	end,
	piano = function(model)
		SuiteView.playPiano(model)
	end,
}

local function onTriggered(prompt: ProximityPrompt)
	local use = prompt:GetAttribute("Use")
	local f = folder
	if type(use) ~= "string" or not f or not prompt:IsDescendantOf(f) then
		return
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	while model and model.Parent ~= f do
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	local fn = USES[use]
	if fn and model then
		fn(model, prompt)
	end
end

---------------------------------------------------------------------------------------------------
-- The pieces live: fish, water, fire
---------------------------------------------------------------------------------------------------
local function animate()
	local t = os.clock()
	for _, f in fishes do
		if f.part.Parent then
			local phase = t * (0.35 + f.n * 0.05) + f.n
			local turned = math.cos(phase) < 0
			f.part.CFrame = f.home * CFrame.new(math.sin(phase) * 3.2, math.sin(phase * 1.7) * 0.3, 0) * CFrame.Angles(0, if turned then math.pi else 0, 0)
		end
	end
	for _, w in waters do
		w.Transparency = 0.35 + math.sin(t * 1.3) * 0.04
	end
	for _, flame in flames do
		flame.Size = Vector3.new(1.4, 1.1 + math.sin(t * 9) * 0.15 + math.sin(t * 13) * 0.08, 1.4)
		local light = flame:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 1.5 + math.sin(t * 11) * 0.15
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The doors, and privacy
---------------------------------------------------------------------------------------------------

-- The Gold Key rooms: open on a holder's screen, shut on everyone else's.
local function doors()
	for _, door in CollectionService:GetTagged("SuiteAlcove") do
		if door:IsA("BasePart") then
			local open = hasGoldKey()
			door.CanCollide = not open
			door.LocalTransparencyModifier = if open then 1 else 0
			for _, d in door:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = door.LocalTransparencyModifier
				end
			end
		end
	end
end


-- Other guests in the Suite aren't drawn here: each guest's Suite is their own. Nothing of theirs
-- shows (their name, a glow or a light they wear, a trail) or sounds (their footsteps), and what
-- they put on while there is hidden too; once they leave, each thing is back just as it was.
local SWITCHED = { "BillboardGui", "SurfaceGui", "ParticleEmitter", "Trail", "Beam", "Light", "Fire", "Smoke", "Sparkles", "Highlight" }

local function switched(d: Instance): boolean
	for _, class in SWITCHED do
		if d:IsA(class) then
			return true
		end
	end
	return false
end

local function hideOne(d: Instance, hide: boolean)
	if d:IsA("BasePart") then
		d.LocalTransparencyModifier = if hide then 1 else 0
	elseif d:IsA("Decal") then
		d.LocalTransparencyModifier = if hide then 1 else 0
	elseif d:IsA("Sound") then
		local kept = d:GetAttribute("SuiteVolume")
		if hide then
			if kept == nil then
				d:SetAttribute("SuiteVolume", d.Volume)
			end
			d.Volume = 0
		elseif type(kept) == "number" then
			d.Volume = kept
			d:SetAttribute("SuiteVolume", nil)
		end
	elseif switched(d) then
		local any = d :: any
		local kept = d:GetAttribute("SuiteWasOn")
		if hide then
			if kept == nil then
				d:SetAttribute("SuiteWasOn", any.Enabled == true)
			end
			any.Enabled = false
		elseif type(kept) == "boolean" then
			any.Enabled = kept
			d:SetAttribute("SuiteWasOn", nil)
		end
	end
end

local function setHidden(other: Player, hide: boolean)
	local character = other.Character
	if character then
		for _, d in character:GetDescendants() do
			hideOne(d, hide)
		end
	end
	hidden[other] = if hide then true else nil
end

-- Whose Suite a guest is in: the friend they're visiting, or their own.
local function suiteOf(p: Player): number
	local host = p:GetAttribute("SuiteHost")
	return if type(host) == "number" then host else p.UserId
end

-- Whether another guest is in a Suite that isn't the one this guest is in. (Seen only when in the
-- very same Suite: a friend visiting, or the friend you visit.)
local function elsewhere(other: Player, mine: number): boolean
	local character = other.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "suite" and suiteOf(other) ~= mine
end

local function privacy()
	local mine = suiteOf(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			if elsewhere(other, mine) then
				-- (Again each time: what they've put on since, or a new character, is hidden too.)
				setHidden(other, true)
			elseif hidden[other] then
				setHidden(other, false)
			end
		end
	end
end

-- Every frame: a guest stepping into another Suite is hidden the moment they do (the pass above,
-- four times a second, catches what they put on and brings back whoever leaves).
local function privacyNow()
	local mine = suiteOf(player)
	for _, other in Players:GetPlayers() do
		if other ~= player and not hidden[other] and elsewhere(other, mine) then
			setHidden(other, true)
		end
	end
end

local welcomed = false

function SuiteView.start()
	doors()
	Closet.Changed:Connect(function()
		doors()
		if inside then
			task.spawn(draw)
		end
	end)
	-- Into a friend's Suite (or home again): their pieces, their Gold Key rooms.
	Closet.Message:Connect(function(op: string, m: any)
		if op ~= "suiteHost" then
			return
		end
		local was = visiting
		if type(m.host) == "number" and m.host ~= player.UserId then
			visiting = {
				userId = m.host,
				name = tostring(m.name or "A friend"),
				suite = if type(m.suite) == "table" then m.suite else {},
				goldKey = m.goldKey == true,
			}
		else
			visiting = nil
		end
		doors()
		if inside then
			task.spawn(draw)
		end
		local v = visiting
		if v and (not was or was.userId ~= v.userId) then
			Toast.show(v.name .. "'s Suite", "As " .. v.name .. " has furnished it. Only friends may visit each other's Suites.", 5)
		elseif not v and was and inside then
			Toast.show("Your Suite", "Back in your own Suite.", 3)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(onTriggered)
	Players.PlayerRemoving:Connect(function(other: Player)
		hidden[other] = nil
	end)
	RunService.Heartbeat:Connect(function()
		if inside then
			animate()
		end
		privacyNow()
	end)
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local now = root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "suite"
			if now and not inside then
				inside = true
				task.spawn(draw)
				-- The first time in, say how to furnish it.
				if not welcomed and not visiting then
					welcomed = true
					Toast.show("Your Suite", "It's yours alone. Ring the bell by the door to furnish every room.", 6)
				end
			elseif not now and inside then
				inside = false
				clear()
			end
			privacy()
			task.wait(0.25)
		end
	end)
end

return SuiteView
