--!strict
-- The Tailor stands behind the Boutique's long counter. Speak to them (or ring the bell) and the
-- Boutique opens: today's six, the week's two, the season, the Gold Key and the Ledger.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Rig = require(script.Parent.Rig)

local Tailor = {}

-- What speaking to the Tailor does (set by Main: a line, then the Boutique opens).
Tailor.onSpeak = function(_player: Player) end

function Tailor.spawn(parent: Instance)
	local look = Rig.look("Tailor")
	look.coat = Color3.fromRGB(34, 26, 30)
	local s = Rig.build("Tailor", look, Layout.Boutique.tailorHome, parent)
	s.model:SetAttribute("Staff", "Tailor")
	local head = s.model:FindFirstChild("Head")
	local anchor: BasePart = if head and head:IsA("BasePart") then head else s.root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpeakPrompt"
	prompt.ActionText = "Speak"
	prompt.ObjectText = Voice.Tailor.speaker
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player: Player)
		Tailor.onSpeak(player)
	end)
	return s
end

return Tailor
