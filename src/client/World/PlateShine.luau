--!strict
-- (Build 96) Showpiece nameplates and Gem Shop titles, alive on this screen: the band of light
-- sweeps across a showpiece frame every few seconds, its frame's colours run round it, and a
-- worn title's sheen drifts across its words. Only what the server built is moved (the
-- "Nameplate" over each guest's head, marked Shine / TitleShine); nothing here decides who wears
-- what.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlateShine = {}

PlateShine.PERIOD = 3.2 -- seconds for one sweep (and a rest) across the plate
local FAR = 90
local STEP = 1 / 30

function PlateShine.animate(gui: Instance, t: number)
	if gui:GetAttribute("Shine") then
		local band = gui:FindFirstChild("SheenBand", true)
		local sheen = band and band:FindFirstChild("Sheen")
		if sheen and sheen:IsA("UIGradient") then
			local phase = (t % PlateShine.PERIOD) / PlateShine.PERIOD
			sheen.Offset = Vector2.new(-1.2 + phase * 2.4, 0)
		end
		local sweep = gui:FindFirstChild("Sweep", true)
		if sweep and sweep:IsA("UIGradient") then
			sweep.Rotation = (t * 90) % 360
		end
	end
	if gui:GetAttribute("TitleShine") then
		local title = gui:FindFirstChild("Title", true)
		local g = title and title:FindFirstChildOfClass("UIGradient")
		if g then
			g.Offset = Vector2.new(math.sin(t * 1.8) * 0.6, 0)
		end
	end
end

function PlateShine.start()
	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		acc += dt
		if acc < STEP then
			return
		end
		acc = 0
		local t = os.clock()
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else nil
		for _, p in Players:GetPlayers() do
			local c = p.Character
			local head = c and c:FindFirstChild("Head")
			local gui = head and head:FindFirstChild("Nameplate")
			if gui and head:IsA("BasePart") and (gui:GetAttribute("Shine") or gui:GetAttribute("TitleShine")) then
				if not eye or (head.Position - eye).Magnitude <= FAR then
					PlateShine.animate(gui, t)
				end
			end
		end
	end)
end

return PlateShine
