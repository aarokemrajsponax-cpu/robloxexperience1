--!strict
-- The Archivist keeps the Register in the Vault: "Everything you've found is kept here."

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Rig = require(script.Parent.Rig)

local Archivist = {}

Archivist.onSpeak = function(_player: Player) end

function Archivist.spawn(parent: Instance)
	local look = Rig.look("Archivist")
	look.coat = Color3.fromRGB(28, 26, 34)
	local s = Rig.build("Archivist", look, Layout.Vault.archivistHome, parent)
	s.model:SetAttribute("Staff", "Archivist")
	local head = s.model:FindFirstChild("Head")
	local anchor: BasePart = if head and head:IsA("BasePart") then head else s.root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpeakPrompt"
	prompt.ActionText = "Speak"
	prompt.ObjectText = Voice.Archivist.speaker
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player: Player)
		Archivist.onSpeak(player)
	end)
	return s
end

return Archivist
