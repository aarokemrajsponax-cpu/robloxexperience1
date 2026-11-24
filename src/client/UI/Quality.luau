--!strict
-- (Build 102) How much this screen draws: the house's glow, its particles and its loading scenes,
-- scaled to the device. A phone, or a guest who has set Roblox's graphics low, gets a softer bloom
-- and half the sparkle in every particle effect, so the game stays smooth; a strong computer gets
-- the whole show. Only how things look on this screen changes, never what happens.

local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Quality = {}

-- "full" or "lite".
function Quality.level(): string
	local low = false
	pcall(function()
		local q = UserSettings().GameSettings.SavedQualityLevel
		-- (Automatic reads as 0: decided by the device below.)
		if q.Value > 0 and q.Value <= 4 then
			low = true
		end
	end)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		low = true
	end
	return if low then "lite" else "full"
end

local function easeEmitter(e: Instance)
	if e:IsA("ParticleEmitter") and e:GetAttribute("QualityEased") == nil then
		e:SetAttribute("QualityEased", true)
		e.Rate = e.Rate * 0.5
	end
end

function Quality.apply()
	if Quality.level() ~= "lite" then
		return
	end
	local bloom = Lighting:FindFirstChild("MaisonBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Size = 20
		bloom.Intensity = 0.4
	end
	for _, d in Workspace:GetDescendants() do
		easeEmitter(d)
	end
	Workspace.DescendantAdded:Connect(easeEmitter)
end

function Quality.start()
	task.delay(2, function()
		pcall(Quality.apply)
	end)
end

return Quality
