--!strict
-- The staff notice you (§5): when you come near, the Concierge, the Tailor and the Archivist turn
-- their head toward you, never more than a natural glance, and back again when you go. Drawn on
-- each guest's own screen, so everyone is looked at.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StaffLife = {}

local player = Players.LocalPlayer
local NEAR = 14
local MAX_YAW = math.rad(55)
local MAX_PITCH = math.rad(20)

type Watcher = { neck: Motor6D, base: CFrame, head: BasePart, yaw: number, pitch: number }
local watchers: { [Model]: Watcher } = {}

local function find()
	local maison = Workspace:FindFirstChild("Maison")
	local staffFolder = maison and maison:FindFirstChild("Staff")
	if not staffFolder then
		return
	end
	for _, model in staffFolder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("Staff") and not watchers[model] and not model:GetAttribute("StandIn") then
			local head = model:FindFirstChild("Head")
			local neck = head and head:FindFirstChild("Neck")
			if head and head:IsA("BasePart") and neck and neck:IsA("Motor6D") then
				watchers[model] = { neck = neck, base = neck.C0, head = head, yaw = 0, pitch = 0 }
			end
		end
	end
end

local function step(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 1.5, 0) else nil
	for model, w in watchers do
		if not model.Parent then
			watchers[model] = nil
			continue
		end
		local wantYaw, wantPitch = 0, 0
		if target and (target - w.head.Position).Magnitude < NEAR then
			local body = (w.neck.Part0 :: BasePart).CFrame
			local rel = body:PointToObjectSpace(target)
			wantYaw = math.clamp(math.atan2(-rel.X, -rel.Z), -MAX_YAW, MAX_YAW)
			wantPitch = math.clamp(math.atan2(rel.Y - 1.5, math.sqrt(rel.X * rel.X + rel.Z * rel.Z)), -MAX_PITCH, MAX_PITCH)
		end
		local k = math.min(1, dt * 4)
		w.yaw += (wantYaw - w.yaw) * k
		w.pitch += (wantPitch - w.pitch) * k
		w.neck.C0 = w.base * CFrame.Angles(w.pitch, w.yaw, 0)
	end
end

function StaffLife.start()
	task.spawn(function()
		for _ = 1, 30 do
			find()
			task.wait(2)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return StaffLife
