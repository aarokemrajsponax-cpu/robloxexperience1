--!strict
-- One family of easing for the whole house. Nothing pops, bounces or spins.

local TweenService = game:GetService("TweenService")

local Ease = {}

Ease.quick = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Ease.panel = TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Ease.settle = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Ease.glide = TweenInfo.new(1.4, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
Ease.slow = TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
Ease.linear = TweenInfo.new(1, Enum.EasingStyle.Linear)

function Ease.info(seconds: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): TweenInfo
	return TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
end

function Ease.play(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

-- Movement setting: Full = 1, Calm = 0.6, Still = 0 (durations collapse to almost nothing).
Ease.motionScale = 1

function Ease.scaled(info: TweenInfo): TweenInfo
	local scale = math.max(Ease.motionScale, 0.02)
	return TweenInfo.new(info.Time * scale, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime * scale)
end

return Ease
