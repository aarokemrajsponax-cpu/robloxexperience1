--!strict
-- A victory flourish (a Library win, the last lamp): a burst over the guest's own table in the
-- style they wear from the Boutique (gold leaf, candle snuff, champagne), or the house's own
-- quiet gold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local State = require(script.Parent.Parent.State)
local Closet = require(script.Parent.Parent.Closet)

local Flourish = {}

function Flourish.play(at: Vector3)
	if State.get("glow") == "Off" then
		return
	end
	local style = Closet.style("flourish")
	local colour = if style and typeof(style.colour) == "Color3" then style.colour else Brand.Colours.lightGold
	local kind = if style then style.kind else "house"
	local holder = Instance.new("Part")
	holder.Name = "Flourish"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(at)
	holder.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	local a = Instance.new("Attachment")
	a.Parent = holder
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Color = ColorSequence.new(colour)
	e.LightEmission = if kind == "snuff" then 0.2 else 0.9
	e.Lifetime = NumberRange.new(if kind == "leaf" then 2.4 else 1.2, if kind == "leaf" then 3.4 else 1.8)
	e.Speed = NumberRange.new(if kind == "spray" then 9 else 3, if kind == "spray" then 14 else 6)
	e.SpreadAngle = Vector2.new(if kind == "spray" then 25 else 70, if kind == "spray" then 25 else 70)
	e.Acceleration = Vector3.new(0, if kind == "leaf" then -1.5 elseif kind == "snuff" then 1.5 else -8, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, if kind == "snuff" then 0.5 else 0.18), NumberSequenceKeypoint.new(1, if kind == "snuff" then 1.2 else 0.05) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = a
	e:Emit(if State.get("glow") == "Subtle" then 18 else 40)
	task.delay(4, function()
		holder:Destroy()
	end)
end

return Flourish
