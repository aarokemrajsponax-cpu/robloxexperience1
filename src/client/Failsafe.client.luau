--!strict
-- A safety net, separate from the house's own client (Main). If Main hasn't started within a few
-- seconds (an error in Studio, a service Roblox refused), the guest still plays like any Roblox
-- game: their own character, Roblox's own camera and controls, and Roblox's own prompts so every
-- Sit and Speak still works. When Main starts normally, this does nothing.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local WAIT = 12

local started = os.clock()
while os.clock() - started < WAIT do
	if player:GetAttribute("MaisonClient") == "ready" then
		return
	end
	task.wait(0.25)
end
if player:GetAttribute("MaisonClient") == "ready" then
	return
end

warn("[Maison] The house's client didn't start; playing with Roblox's own camera, controls and prompts.")

local function camera()
	local cam = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		if humanoid then
			cam.CameraSubject = humanoid
		end
	end
end

local function controls()
	pcall(function()
		local playerScripts = player:WaitForChild("PlayerScripts", 5)
		local module = playerScripts and playerScripts:WaitForChild("PlayerModule", 5)
		if module and module:IsA("ModuleScript") then
			local m = require(module) :: any
			m:GetControls():Enable()
		end
	end)
end

local function plain(p: Instance)
	if p:IsA("ProximityPrompt") then
		p.Style = Enum.ProximityPromptStyle.Default
	end
end

camera()
controls()
for _, d in Workspace:GetDescendants() do
	plain(d)
end
Workspace.DescendantAdded:Connect(plain)
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	camera()
	controls()
end)
