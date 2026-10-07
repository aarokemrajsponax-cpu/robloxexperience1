--!strict
-- Treats from the Terrace bar, as this screen sees them. The guest holding one eats it themself:
-- each click (or tap, or the Eat key, or F) asks the server for a bite, and the server, which
-- keeps time and counts the servings (Purchases/Bar), says yes by moving the treat's "Sips"
-- counter. Every screen then sees it: the arm lifts the treat to the lips, the head dips, crumbs
-- fall (or bubbles rise from a drink), and the treat itself gets smaller, piece by piece, until the
-- last bite. This is only how it looks; the server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sound = require(script.Parent.Parent.Sound)

local Treats = {}

local LIFT = 0.9 -- seconds for the arm to come up and go down again
local watched: { [Model]: boolean } = {}
local player = Players.LocalPlayer

local function outCubic(t: number): number
	return 1 - (1 - t) ^ 3
end
local function inOutCubic(t: number): number
	return if t < 0.5 then 4 * t ^ 3 else 1 - (-2 * t + 2) ^ 3 / 2
end

-- The shoulder that lifts the treat (R15's RightShoulder, or R6's "Right Shoulder").
local function shoulderOf(character: Model): Motor6D?
	local arm = character:FindFirstChild("RightUpperArm")
	local m = arm and arm:FindFirstChild("RightShoulder")
	if m and m:IsA("Motor6D") then
		return m
	end
	local torso = character:FindFirstChild("Torso")
	local r6 = torso and torso:FindFirstChild("Right Shoulder")
	return if r6 and r6:IsA("Motor6D") then r6 else nil
end

local function neckOf(character: Model): Motor6D?
	local head = character:FindFirstChild("Head")
	local n = head and head:FindFirstChild("Neck")
	if n and n:IsA("Motor6D") then
		return n
	end
	local torso = character:FindFirstChild("Torso")
	local r6 = torso and torso:FindFirstChild("Neck")
	return if r6 and r6:IsA("Motor6D") then r6 else nil
end

local function restOf(m: Motor6D): CFrame
	local rest = m:GetAttribute("RestC0")
	if typeof(rest) ~= "CFrame" then
		rest = m.C0
		m:SetAttribute("RestC0", rest)
	end
	return rest :: CFrame
end

-- Crumbs falling from a bite, or bubbles rising from a sip, at the mouth.
local function mouthfuls(character: Model, drink: boolean, colour: Color3)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, -0.25, -0.55)
	a.Parent = head
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 0
	e.LightEmission = if drink then 0.5 else 0
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(50, 50)
	e.Acceleration = if drink then Vector3.new(0, 3, 0) else Vector3.new(0, -18, 0)
	e.Size = NumberSequence.new(if drink then 0.18 else 0.12, 0)
	e.Color = ColorSequence.new(colour)
	e.Parent = a
	e:Emit(if drink then 8 else 14)
	task.delay(1.2, function()
		a:Destroy()
	end)
end

-- The parts of a treat that get eaten (its sweets, bites, fries, tiers, the drink), top first.
local EDIBLE = { "Bite", "Sweet", "Fry", "Tier", "Top", "Cream", "Dip", "Garnish", "Slice" }
local function edibles(model: Model): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			for _, prefix in EDIBLE do
				if string.sub(d.Name, 1, #prefix) == prefix then
					table.insert(out, d)
					break
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.Position.Y > b.Position.Y
	end)
	return out
end

-- The treat as much eaten as its servings say: pieces gone top first, a drink going down.
local function shrink(model: Model)
	local total = model:GetAttribute("Total")
	local left = model:GetAttribute("Servings")
	if type(total) ~= "number" or type(left) ~= "number" or total <= 0 then
		return
	end
	local eaten = 1 - math.clamp(left / total, 0, 1)
	local pieces = edibles(model)
	local gone = math.floor(#pieces * eaten + 0.001)
	-- (Changed on this screen only: every screen does the same from the same counter.)
	for i, p in pieces do
		if i <= gone then
			p.Transparency = 1
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Drink" then
			local base = d:GetAttribute("BaseTransparency")
			if type(base) ~= "number" then
				base = d.Transparency
				d:SetAttribute("BaseTransparency", base)
			end
			d.Transparency = (base :: number) + (0.95 - (base :: number)) * math.clamp(eaten, 0, 1)
		end
	end
end

local function lift(model: Model)
	local character = model.Parent
	if not character or not character:IsA("Model") then
		return
	end
	local drink = model:GetAttribute("Kind") == "drink"
	local shoulder = shoulderOf(character)
	local neck = neckOf(character)
	local armRest = if shoulder then restOf(shoulder) else nil
	local neckRest = if neck then restOf(neck) else nil
	-- R15 turns about the shoulder's own frame; R6's shoulder frame is turned, so its axis differs.
	local up = if shoulder and armRest then (if shoulder.Name == "RightShoulder" then armRest * CFrame.Angles(math.rad(110), 0, math.rad(-20)) else armRest * CFrame.Angles(0, 0, math.rad(100))) else nil
	local dip = if neckRest then neckRest * CFrame.Angles(math.rad(if drink then 14 else -12), 0, 0) else nil
	local t0 = os.clock()
	local chewed = false
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) / LIFT
		if t >= 1 or not character.Parent then
			if shoulder and armRest then
				shoulder.C0 = armRest
			end
			if neck and neckRest then
				neck.C0 = neckRest
			end
			if conn then
				conn:Disconnect()
			end
			return
		end
		-- Up, a moment at the lips (the head meeting it, a chew), and down.
		local k = if t < 0.3 then outCubic(t / 0.3) elseif t < 0.6 then 1 else 1 - inOutCubic((t - 0.6) / 0.4)
		if shoulder and armRest and up then
			shoulder.C0 = armRest:Lerp(up, k)
		end
		if neck and neckRest and dip then
			local chew = if t >= 0.3 and t < 0.6 and not drink then math.sin((t - 0.3) * 60) * 0.25 else 0
			neck.C0 = neckRest:Lerp(dip, k * (0.8 + chew))
		end
		if t >= 0.32 and not chewed then
			chewed = true
			local colour = Color3.fromRGB(214, 170, 110)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and (d.Name == "Drink" or string.sub(d.Name, 1, 4) == "Bite" or string.sub(d.Name, 1, 5) == "Sweet" or d.Name == "Fry") then
					colour = d.Color
					break
				end
			end
			mouthfuls(character, drink, colour)
			if character == player.Character then
				pcall(Sound.play, if drink then "drinkSip" else "eatBite", 0.7)
			end
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Eating: the guest's own treat
---------------------------------------------------------------------------------------------------
local gui: ScreenGui? = nil
local eatKey: TextButton? = nil
local mine: Model? = nil
local lastAsk = 0

local function myTreat(): Model?
	local m = mine
	if m and m.Parent and m.Parent == player.Character then
		return m
	end
	return nil
end

local function label(model: Model): string
	local left = model:GetAttribute("Servings")
	local drink = model:GetAttribute("Kind") == "drink"
	local verb = if drink then "Take a sip" else "Take a bite"
	return if type(left) == "number" then string.format("%s · %d left", verb, left) else verb
end

local function refresh()
	local m = myTreat()
	local k = eatKey
	if gui then
		(gui :: ScreenGui).Enabled = m ~= nil
	end
	if m and k then
		k.Text = label(m)
	end
end

-- Ask the server for a bite (it says yes no faster than a person can chew).
function Treats.bite(): boolean
	local m = myTreat()
	if not m then
		return false
	end
	local now = os.clock()
	if now - lastAsk < Config.data.Bar.biteGap then
		return false
	end
	lastAsk = now
	task.spawn(function()
		pcall(function()
			Remotes.func("BarAsk"):InvokeServer({ op = "bite" })
		end)
	end)
	return true
end

local function buildKeys()
	if gui then
		return
	end
	local parent = player:FindFirstChild("PlayerGui")
	if not parent then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "MaisonEat"
	g.IgnoreGuiInset = false
	g.ResetOnSpawn = false
	g.DisplayOrder = 12
	g.Enabled = false
	local k = Instance.new("TextButton")
	k.Name = "Eat"
	k.AnchorPoint = Vector2.new(0.5, 1)
	k.Position = UDim2.new(0.5, 0, 1, -96)
	k.Size = UDim2.fromOffset(250, 48)
	k.BackgroundColor3 = Color3.fromRGB(176, 140, 72)
	k.TextColor3 = Color3.fromRGB(20, 16, 10)
	k.FontFace = Brand.Fonts.bodyBold
	k.TextSize = 18
	k.Text = "Take a bite"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = k
	k.Activated:Connect(function()
		Treats.bite()
	end)
	k.Parent = g
	local down = Instance.new("TextButton")
	down.Name = "PutDown"
	down.AnchorPoint = Vector2.new(0.5, 1)
	down.Position = UDim2.new(0.5, 0, 1, -62)
	down.Size = UDim2.fromOffset(120, 26)
	down.BackgroundTransparency = 1
	down.TextColor3 = Color3.fromRGB(230, 214, 180)
	down.FontFace = Brand.Fonts.body
	down.TextSize = 14
	down.Text = "Set it down"
	down.Activated:Connect(function()
		task.spawn(function()
			pcall(function()
				Remotes.func("BarAsk"):InvokeServer({ op = "putDown" })
			end)
		end)
	end)
	down.Parent = g
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -146)
	hint.Size = UDim2.fromOffset(320, 20)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.fromRGB(230, 214, 180)
	hint.TextStrokeTransparency = 0.6
	hint.FontFace = Brand.Fonts.body
	hint.TextSize = 14
	hint.Text = if UserInputService.TouchEnabled then "Tap to eat" else "Click (or press F) to eat"
	hint.Parent = g
	g.Parent = parent
	gui = g
	eatKey = k
end

-- What a click on the world lands on: eating shouldn't steal a click meant for a seat or a door.
local function clickIsFree(): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return true
	end
	local at = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(at.X, at.Y)
	local params = RaycastParams.new()
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 40, params)
	if not hit then
		return true
	end
	local inst = hit.Instance
	if inst:IsA("Seat") or inst:IsA("VehicleSeat") or inst:FindFirstChildWhichIsA("ClickDetector") or inst:FindFirstChildWhichIsA("ProximityPrompt") then
		return false
	end
	return true
end

local function watch(model: Instance)
	if not model:IsA("Model") or model.Name ~= "Treat" or watched[model] then
		return
	end
	watched[model] = true
	-- (How many servings it started with, to know how much is eaten.)
	if model:GetAttribute("Total") == nil then
		local s = model:GetAttribute("Servings")
		if type(s) == "number" then
			model:SetAttribute("Total", s)
		end
	end
	model:GetAttributeChangedSignal("Sips"):Connect(function()
		lift(model)
	end)
	model:GetAttributeChangedSignal("Servings"):Connect(function()
		shrink(model)
		refresh()
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			watched[model] = nil
			if mine == model then
				mine = nil
				refresh()
			end
			-- Put the arm and head back where they were.
			local character = model.Parent
			if character and character:IsA("Model") then
				for _, m in { shoulderOf(character), neckOf(character) } do
					local rest = m and m:GetAttribute("RestC0")
					if m and typeof(rest) == "CFrame" then
						m.C0 = rest
					end
				end
			end
		end
	end)
	shrink(model)
	if model:GetAttribute("Owner") == player.UserId then
		mine = model
		buildKeys()
		refresh()
		Sound.play(if model.PrimaryPart and model.PrimaryPart:FindFirstChild("Glow") then "shimmer" else "pickup", 0.4)
	end
end

function Treats.start()
	Workspace.DescendantAdded:Connect(watch)
	for _, d in Workspace:GetDescendants() do
		watch(d)
	end
	-- A click on the world, a tap, F, or the gamepad's right trigger: a bite.
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not myTreat() then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
			Treats.bite()
		elseif (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and clickIsFree() then
			Treats.bite()
		end
	end)
end

return Treats
