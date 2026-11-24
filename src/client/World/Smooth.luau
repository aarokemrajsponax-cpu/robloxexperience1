--!strict
-- (Build 102) No hard cuts. Whenever this guest is moved a long way at once (a Take me there, a
-- respawn, the house putting them somewhere), the screen is already dark on that very frame and
-- the new place fades up softly, instead of the camera snapping across the house. Nothing waits
-- on it: it's only how the move looks. (The elevator and the loading screens have their own.)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Smooth = {}

-- Set by Main: whether a screen of its own already covers the move (the elevator, a loading
-- screen, the Home Screen).
Smooth.covered = function(): boolean
	return false
end

local JUMP = 45 -- studs in one step that count as being moved, not walking
local player = Players.LocalPlayer
local veil: Frame? = nil
local last: Vector3? = nil
local playing: Tween? = nil

local function cover(): Frame?
	local v = veil
	if v and v.Parent then
		return v
	end
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then
		return nil
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "MaisonSmooth"
	screen.IgnoreGuiInset = true
	screen.ScreenInsets = Enum.ScreenInsets.None
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 93
	screen.Parent = gui
	local f = Instance.new("Frame")
	f.Name = "Veil"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(6, 5, 8)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = screen
	veil = f
	return f
end

-- Dark at once, then the new place fades up.
function Smooth.fade(seconds: number?)
	local f = cover()
	if not f then
		return
	end
	if playing then
		playing:Cancel()
	end
	f.BackgroundTransparency = 0
	local t = TweenService:Create(f, TweenInfo.new(seconds or 0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	playing = t
	t:Play()
end

-- One step: was the guest just moved a long way?
function Smooth.step(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		last = nil
		return false
	end
	local p = root.Position
	local was = last
	last = p
	if was and (p - was).Magnitude > JUMP then
		local ok, busy = pcall(Smooth.covered)
		if not (ok and busy) then
			Smooth.fade()
			return true
		end
	end
	return false
end

function Smooth.start()
	RunService.Heartbeat:Connect(function()
		Smooth.step()
	end)
	player.CharacterAdded:Connect(function()
		last = nil
	end)
end

return Smooth
