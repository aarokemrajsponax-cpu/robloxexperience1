--!strict
-- The Pianist sits at the Foyer's grand piano and plays its music (§5). Never speaks. The music
-- itself comes from the piano on each guest's screen (Sound); here the Pianist is seated at the
-- keys, and plays the Pianist animation once one is published (Config.Assets.Animations.pianist).
-- Until then each guest's screen sways them gently at the keys (StaffLife).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Rig = require(script.Parent.Rig)

local Pianist = {}

local function bend(model: Model, part: string, joint: string, angle: number)
	local p = model:FindFirstChild(part)
	local m = p and p:FindFirstChild(joint)
	if m and m:IsA("Motor6D") then
		m.C0 = m.C0 * CFrame.Angles(math.rad(angle), 0, 0)
	end
end

function Pianist.spawn(parent: Instance)
	local look = Rig.look("Pianist")
	look.coat = Color3.fromRGB(12, 12, 15)
	local home = Layout.Foyer.pianist
	local s = Rig.build("Pianist", look, home, parent)
	s.model:SetAttribute("Staff", "Pianist")
	if s.idle then
		s.idle:Stop(0)
	end
	-- Seated: thighs forward along the bench, shins down, hands out toward the keys.
	for _, side in { "Left", "Right" } do
		bend(s.model, side .. "UpperLeg", side .. "Hip", 90)
		bend(s.model, side .. "LowerLeg", side .. "Knee", -90)
		bend(s.model, side .. "UpperArm", side .. "Shoulder", 55)
		bend(s.model, side .. "LowerArm", side .. "Elbow", 25)
	end
	s.humanoid.AutoRotate = false
	s.root.Anchored = true
	s.root.CFrame = home + Vector3.new(0, Layout.Foyer.pianoBenchTop + 0.45 + s.root.Size.Y / 2, 0)
	s.busy = true

	local id = Config.data.Assets.Animations.pianist
	if id ~= "" then
		local animator = s.humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = true
				track:Play(0.5)
				s.model:SetAttribute("Playing", true)
			end
		end
	end
	return s
end

return Pianist
