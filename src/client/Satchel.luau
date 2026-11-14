--!strict
-- The Satchel on this guest's screen (server/Satchel decides what's in it):
--   * the Roblox inventory, the hotbar, shown in play and put away on the Home Screen and at the
--     tables (whatever was in hand goes back in it);
--   * what each item does when used: the stun pistol fires in the Executive Suite's fight and
--     says so anywhere else; the decoy is thrown in the Suite's hallway; anything else is flexed;
--   * a flex, this guest's or anyone's near: what they hold, popped up big over their head with
--     its name and rarity, a burst in their Victory Flourish's colour (or its rarity's) and a
--     shimmer. Only the server says a flex happened; this screen never shows one it wasn't sent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local BrainrotList = require(ReplicatedStorage.Shared.Brainrots)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local Satchel = {}

-- Whether the hotbar is put away just now (set by Main: the Home Screen, a table, sorting).
Satchel.hidden = function(): boolean
	return false
end

local COOLDOWN = 3
local rgb = Color3.fromRGB
local NEON = rgb(255, 70, 170)
local GOLD = rgb(232, 196, 108)
local GRAPHITE = rgb(14, 15, 19)

local wired: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastFlex = -math.huge
local shown: boolean? = nil

local function toast(title: string, line: string)
	pcall(function()
		require(script.Parent.UI.Toast).show(title, line, 3)
	end)
end

local function hud(): any
	local ok, m = pcall(function()
		return require(script.Parent.UI.ExecutiveHud)
	end)
	return if ok then m else nil
end

local function inSuite(): boolean
	return Players.LocalPlayer:GetAttribute("Attraction") == "executive"
end

-- What happens when an item is used (a click, a tap, a trigger, with it in hand).
local function used(tool: Tool)
	local kind = tool:GetAttribute("SatchelKind")
	local id = tool:GetAttribute("SatchelId")
	if kind == "gear" and id == "sidearm" then
		local h = hud()
		if h and inSuite() and h.fireFromTool() then
			return
		end
		if inSuite() then
			toast("Hold your fire", "The pistol fires once the guards are onto you, in the Suite's fight.")
		else
			toast("The Stun Pistol", "It fires only in the Executive Suite. Take it up there with an invitation.")
		end
	elseif kind == "gear" and id == "decoy" then
		local h = hud()
		if h and inSuite() then
			h.throwDecoy()
		else
			toast("The Decoy", "Throw it in the Executive Suite's hallway, and every guard watches it for a moment.")
		end
	elseif kind == "flex" then
		local now = os.clock()
		if now - lastFlex < COOLDOWN then
			return
		end
		lastFlex = now
		local key = tool:GetAttribute("SatchelKey")
		if type(key) == "string" then
			pcall(function()
				Remotes.event("Satchel"):FireServer({ op = "flex", key = key })
			end)
		end
	end
end

local function wire(tool: Instance)
	if not tool:IsA("Tool") or wired[tool] or type(tool:GetAttribute("SatchelKey")) ~= "string" then
		return
	end
	wired[tool] = true
	tool.Activated:Connect(function()
		used(tool)
	end)
end
Satchel.used = used

local function tools(): { Tool }
	local out: { Tool } = {}
	local player = Players.LocalPlayer
	local holders: { Instance } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(holders, backpack)
	end
	if player.Character then
		table.insert(holders, player.Character :: Instance)
	end
	for _, holder in holders do
		do
			for _, t in holder:GetChildren() do
				if t:IsA("Tool") and type(t:GetAttribute("SatchelKey")) == "string" then
					table.insert(out, t)
				end
			end
		end
	end
	return out
end
Satchel.tools = tools

-- Shows or puts away the hotbar, and keeps what sits along the foot of the screen above it.
local function apply()
	local want = State.phase == "play" and not Satchel.hidden()
	local n = #tools()
	if want ~= shown then
		shown = want
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, want)
		end)
		if not want then
			-- (Whatever was in hand goes back in the satchel.)
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				for _, t in tools() do
					if t.Parent == character then
						pcall(function()
							humanoid:UnequipTools()
						end)
						break
					end
				end
			end
		end
	end
	pcall(function()
		local Root = require(script.Parent.UI.Root)
		local small = Root.size().Y < 520 or Root.size().X < 760
		Root.setBottom("Satchel", if want and n > 0 then (if small then 60 else 76) / math.max(0.1, Root.scale) else nil)
	end)
end
Satchel.apply = apply

local function corner(parent: Instance, r: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = parent
end

local function label(parent: Instance, name: string, text: string, font: Font, colour: Color3, y: number, h: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, h)
	l.Position = UDim2.fromScale(0, y)
	l.Text = text
	l.FontFace = font
	l.TextScaled = true
	l.TextColor3 = colour
	l.TextStrokeTransparency = 0.55
	l.Parent = parent
	return l
end

-- A flex over a guest's head (`m` from the server: who, what, its rarity, their flourish).
function Satchel.show(m: { [string]: any })
	local who = if type(m.userId) == "number" then Players:GetPlayerByUserId(m.userId) else nil
	local character = who and who.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local id = if type(m.id) == "string" then m.id else ""
	local curio = CurioList.byId[id]
	local rarity = if type(m.rarity) == "string" then m.rarity else (if curio then curio.rarity else "")
	local colour = (CurioList.RarityColour :: any)[rarity] or GOLD
	local mut = if type(m.mut) == "string" then (BrainrotList.Mutations :: any)[m.mut] else nil
	local ring = if mut and typeof(mut.colour) == "Color3" then mut.colour else colour
	local style = if type(m.flourish) == "string" then Wardrobe.get(m.flourish) else nil
	local burst = if style and typeof(style.style.colour) == "Color3" then style.style.colour else ring
	local name = if type(m.name) == "string" then m.name else (if curio then curio.name else "")
	local glyph = if type(m.glyph) == "string" then m.glyph else (if curio then curio.glyph else "✨")
	local mine = who == Players.LocalPlayer

	local gui = Instance.new("BillboardGui")
	gui.Name = "Flex"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(6.4, 4.6)
	gui.StudsOffset = Vector3.new(0, 3.9, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.AlwaysOnTop = mine
	gui.ResetOnSpawn = false

	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.33)
	disc.Size = UDim2.fromScale(0, 0)
	disc.SizeConstraint = Enum.SizeConstraint.RelativeYY
	disc.BackgroundColor3 = GRAPHITE
	disc.BorderSizePixel = 0
	disc.Parent = gui
	corner(disc, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = ring
	stroke.Parent = disc
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new(rgb(30, 30, 38), GRAPHITE)
	glow.Rotation = 90
	glow.Parent = disc
	local g = label(disc, "Glyph", glyph, Brand.Fonts.display, rgb(255, 255, 255), 0.14, 0.72)
	g.Size = UDim2.fromScale(0.72, 0.72)
	g.Position = UDim2.fromScale(0.14, 0.14)
	g.TextStrokeTransparency = 1

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.fromScale(0.5, 0.66)
	plate.Size = UDim2.fromScale(0.96, 0.32)
	plate.BackgroundColor3 = GRAPHITE
	plate.BackgroundTransparency = 0.12
	plate.BorderSizePixel = 0
	plate.Parent = gui
	corner(plate, UDim.new(0.22, 0))
	local edge = Instance.new("UIStroke")
	edge.Thickness = 2
	edge.Color = NEON
	edge.Transparency = 0.2
	edge.Parent = plate
	local tag = label(plate, "Tag", if mine then "YOU FLEXED" else "FLEX", Brand.Fonts.heavy, NEON, 0.04, 0.3)
	tag.TextStrokeTransparency = 1
	label(plate, "Name", name, Brand.Fonts.display, rgb(255, 255, 255), 0.32, 0.38)
	local line = string.upper(if mut then string.format("%s · %s", mut.name, rarity) else rarity)
	local r = label(plate, "Rarity", line, Brand.Fonts.figures, ring, 0.7, 0.26)
	r.TextStrokeTransparency = 1

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	gui.Parent = playerGui or Workspace

	-- The pop: in big, a little past, then settled; the plate slides up into place.
	TweenService:Create(disc, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.62, 0.62) }):Play()
	plate.Position = UDim2.fromScale(0.5, 0.8)
	TweenService:Create(plate, TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.66) }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), { Thickness = 7 }):Play()

	-- The burst: sparks in their flourish's colour (or the rarity's), unless glow is off.
	local spark: Part? = nil
	if State.get("glow") ~= "Off" then
		local p = Instance.new("Part")
		p.Name = "FlexBurst"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.CFrame = CFrame.new(head.Position + Vector3.new(0, 3.2, 0))
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(burst, rgb(255, 255, 255))
		e.LightEmission = 0.8
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0, 1)
		e.Speed = NumberRange.new(9, 16)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Drag = 3
		e.Acceleration = Vector3.new(0, -6, 0)
		e.Rate = 0
		e.Parent = p
		p.Parent = Workspace
		pcall(function()
			e:Emit(if mine then 36 else 24)
		end)
		spark = p
	end
	pcall(function()
		Sound.play(if mine then "reward" else "shimmer", if mine then 0.7 else 0.45)
	end)

	task.delay(2.4, function()
		for _, o in gui:GetDescendants() do
			if o:IsA("TextLabel") then
				TweenService:Create(o, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif o:IsA("Frame") then
				TweenService:Create(o, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			elseif o:IsA("UIStroke") then
				TweenService:Create(o, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(3, function()
		gui:Destroy()
		if spark then
			spark:Destroy()
		end
	end)
end

function Satchel.start()
	local player = Players.LocalPlayer
	local function watch(holder: Instance)
		for _, t in holder:GetChildren() do
			wire(t)
		end
		holder.ChildAdded:Connect(function(t: Instance)
			wire(t)
			task.defer(apply)
		end)
		holder.ChildRemoved:Connect(function()
			task.defer(apply)
		end)
	end
	local function backpack(b: Instance)
		if b:IsA("Backpack") then
			watch(b)
			task.defer(apply)
		end
	end
	for _, b in player:GetChildren() do
		backpack(b)
	end
	player.ChildAdded:Connect(backpack)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(function(c: Model)
		watch(c)
		task.defer(apply)
	end)
	State.PhaseChanged:Connect(function()
		apply()
	end)
	Remotes.event("Satchel").OnClientEvent:Connect(function(m: unknown)
		if type(m) == "table" and (m :: any).op == "flex" then
			Satchel.show(m :: any)
		end
	end)
	-- (What hides it, the Home Screen, a table, sorting, is looked at a few times a second.)
	task.spawn(function()
		while true do
			task.wait(0.25)
			pcall(apply)
		end
	end)
	apply()
end

return Satchel
