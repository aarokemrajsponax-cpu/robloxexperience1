--!strict
-- Treats from the Terrace bar, as this screen sees them: whoever holds one lifts it for a sip or a
-- bite each time the server counts one (the treat's "Sips" attribute), by turning their shoulder
-- on this screen only; and the last one sinks away. The server decides everything (Purchases/Bar);
-- this is only how it looks.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Sound = require(script.Parent.Parent.Sound)

local Treats = {}

local LIFT = 1.1 -- seconds for the arm to come up and go down again
local watched: { [Model]: boolean } = {}

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

local function lift(model: Model)
	local character = model.Parent
	if not character or not character:IsA("Model") then
		return
	end
	local shoulder = shoulderOf(character)
	if not shoulder then
		return
	end
	local rest = shoulder:GetAttribute("RestC0")
	if typeof(rest) ~= "CFrame" then
		rest = shoulder.C0
		shoulder:SetAttribute("RestC0", rest)
	end
	local base = rest :: CFrame
	-- R15 turns about the shoulder's own frame; R6's shoulder frame is turned, so its axis differs.
	local up = if shoulder.Name == "RightShoulder" then base * CFrame.Angles(math.rad(105), 0, math.rad(-18)) else base * CFrame.Angles(0, 0, math.rad(95))
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) / LIFT
		if t >= 1 or not shoulder.Parent then
			shoulder.C0 = base
			if conn then
				conn:Disconnect()
			end
			return
		end
		-- Up, a moment at the lips, and down.
		local k = if t < 0.35 then outCubic(t / 0.35) elseif t < 0.6 then 1 else 1 - inOutCubic((t - 0.6) / 0.4)
		shoulder.C0 = base:Lerp(up, k)
	end)
	if character == Players.LocalPlayer.Character then
		Sound.play("pickup", 0.18)
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") or model.Name ~= "Treat" or watched[model] then
		return
	end
	watched[model] = true
	model:GetAttributeChangedSignal("Sips"):Connect(function()
		lift(model)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			watched[model] = nil
			-- Put the arm back where it was.
			local character = model.Parent
			if character and character:IsA("Model") then
				local shoulder = shoulderOf(character)
				local rest = shoulder and shoulder:GetAttribute("RestC0")
				if shoulder and typeof(rest) == "CFrame" then
					shoulder.C0 = rest
				end
			end
		end
	end)
	if model:GetAttribute("Owner") == Players.LocalPlayer.UserId then
		Sound.play(if model.PrimaryPart and model.PrimaryPart:FindFirstChild("Glow") then "shimmer" else "pickup", 0.4)
	end
end

function Treats.start()
	Workspace.DescendantAdded:Connect(watch)
	for _, d in Workspace:GetDescendants() do
		watch(d)
	end
end

return Treats
