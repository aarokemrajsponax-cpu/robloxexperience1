--!strict
-- Megalodon Rain on this guest's screen: the banner naming who made it rain, gold falling all
-- around them for as long as the server says it rains (with the house's gold leaf and every lamp
-- flaring), and a quiet line when their own share of Gilt lands. Effects only: the Gilt is the
-- server's, given once per rain, whatever this screen does.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DecreeBanner = require(script.Parent.Parent.UI.DecreeBanner)
local Toast = require(script.Parent.Parent.UI.Toast)
local Sound = require(script.Parent.Parent.Sound)
local SaluteView = require(script.Parent.SaluteView)

local RainView = {}

local player = Players.LocalPlayer
local GOLD = { Color3.fromRGB(255, 226, 140), Color3.fromRGB(246, 200, 92), Color3.fromRGB(214, 160, 60) }

local function folder(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

-- Heavy, bright drops falling around the guest wherever they walk.
local function shower(seconds: number)
	local cloud = Instance.new("Part")
	cloud.Name = "MegalodonRain"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.CastShadow = false
	cloud.Transparency = 1
	cloud.Size = Vector3.new(50, 1, 50)
	cloud.Parent = folder()
	local e = Instance.new("ParticleEmitter")
	e.Name = "Coins"
	e.Rate = 120
	e.Lifetime = NumberRange.new(1.6, 2.4)
	e.Speed = NumberRange.new(14, 20)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(6, 6)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.Size = NumberSequence.new(0.32)
	e.LightEmission = 0.8
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD[1]),
		ColorSequenceKeypoint.new(0.5, GOLD[2]),
		ColorSequenceKeypoint.new(1, GOLD[3]),
	})
	e.Parent = cloud
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < seconds and cloud.Parent do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				cloud.Position = root.Position + Vector3.new(0, 30, 0)
			end
			task.wait(0.1)
		end
		e.Enabled = false
		task.delay(3, function()
			cloud:Destroy()
		end)
	end)
end

-- A rain started in the house: { by, seconds, line, share }.
function RainView.rain(m: { [string]: any })
	local seconds = math.clamp(tonumber(m.seconds) or 20, 5, 60)
	local line = if type(m.line) == "string" then m.line else (tostring(m.by) .. " triggered MEGALODON RAIN!")
	DecreeBanner.show("Megalodon Rainmaker", line, 7)
	Sound.play("complete", 0.5)
	pcall(shower, seconds)
	pcall(SaluteView.effects.goldLeaf, { seconds = seconds })
	pcall(SaluteView.effects.chandelier, { seconds = seconds })
end

-- This guest's own share of a rain landed.
function RainView.share(m: { [string]: any })
	local gilt = tonumber(m.gilt) or 0
	if gilt > 0 then
		Toast.show("Megalodon Rain", string.format("+%d Gilt from %s's rain.", gilt, tostring(m.by)), 4)
	end
end

return RainView
