--!strict
-- At the table your avatar's arm reaches for the piece you pick up and toward the case you file
-- it in, and the head turns to look at what you're holding. Subtle, never cartoonish.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Hands = {}

local player = Players.LocalPlayer
local arm: IKControl? = nil
local look: IKControl? = nil
local targetPart: Part? = nil

local function part(): Part
	if targetPart and targetPart.Parent then
		return targetPart
	end
	local p = Instance.new("Part")
	p.Name = "ReachTarget"
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	local folder = Workspace:FindFirstChild("MaisonLocal") or Workspace
	p.Parent = folder
	targetPart = p
	return p
end

function Hands.attach()
	Hands.detach()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local hand = character:FindFirstChild("RightHand")
	local upper = character:FindFirstChild("RightUpperArm")
	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("UpperTorso")
	if not (hand and upper and head and torso) then
		return
	end
	local ok = pcall(function()
		local t = part()
		local a = Instance.new("IKControl")
		a.Name = "MaisonReach"
		a.Type = Enum.IKControlType.Position
		a.EndEffector = hand
		a.ChainRoot = upper
		a.Target = t
		a.Weight = 0
		a.SmoothTime = 0.08
		a.Priority = 1
		a.Parent = humanoid
		arm = a
		local l = Instance.new("IKControl")
		l.Name = "MaisonLook"
		l.Type = Enum.IKControlType.LookAt
		l.EndEffector = head
		l.ChainRoot = head
		l.Target = t
		l.Weight = 0
		l.SmoothTime = 0.15
		l.Parent = humanoid
		look = l
	end)
	if not ok then
		Hands.detach()
	end
end

function Hands.reach(position: Vector3?)
	local a, l = arm, look
	if not a or not l then
		return
	end
	if position then
		part().CFrame = CFrame.new(position)
		TweenService:Create(a, TweenInfo.new(0.25), { Weight = 0.55 }):Play()
		TweenService:Create(l, TweenInfo.new(0.35), { Weight = 0.5 }):Play()
	else
		TweenService:Create(a, TweenInfo.new(0.35), { Weight = 0 }):Play()
		TweenService:Create(l, TweenInfo.new(0.45), { Weight = 0 }):Play()
	end
end

function Hands.follow(position: Vector3)
	if arm then
		part().CFrame = CFrame.new(position)
	end
end

function Hands.detach()
	if arm then
		arm:Destroy()
		arm = nil
	end
	if look then
		look:Destroy()
		look = nil
	end
end

return Hands
