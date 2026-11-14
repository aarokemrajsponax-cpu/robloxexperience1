--!strict
-- The Luxe Lucky Box showroom on this screen (server World/LuckyShowroom builds it): the three
-- boxes turn slowly and float on their pedestals, and the showroom's prompt is shown only when
-- Roblox's policy for this guest allows paid random items (the server's "PaidRandomAllowed"
-- attribute: until it says so, there's no prompt). The prompt opens the boxes' panel.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LuckyBoxPanel = require(script.Parent.Parent.UI.LuckyBoxPanel)

local LuckyShowroom = {}

local player = Players.LocalPlayer
local bases: { [Model]: CFrame } = {}
local NEAR = 140 -- studs: further than this, the boxes rest

local function allowed(): boolean
	return player:GetAttribute("PaidRandomAllowed") == true
end

local function promptsIn(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "LuckyBoxPrompt" then
			d.Enabled = allowed()
		end
	end
end

local function refreshPrompts()
	for _, root in CollectionService:GetTagged("LuckyShowroom") do
		promptsIn(root)
	end
end

-- Where a box rests, kept the first time it's seen (it turns and floats about that).
local function baseOf(m: Model): CFrame?
	local b = bases[m]
	if b then
		return b
	end
	local ok, cf = pcall(function()
		return m:GetPivot()
	end)
	if ok then
		bases[m] = cf
		return cf
	end
	return nil
end

function LuckyShowroom.step(t: number)
	local cam = Workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else nil
	for i, m in CollectionService:GetTagged("LuckyBoxSpin") do
		if m:IsA("Model") and m.Parent then
			local base = baseOf(m)
			if base and (not eye or (base.Position - eye).Magnitude < NEAR) then
				local phase = i * 2.1
				m:PivotTo(base * CFrame.new(0, math.sin(t * 1.6 + phase) * 0.2, 0) * CFrame.Angles(0, t * 0.7 + phase, 0))
			end
		end
	end
end

function LuckyShowroom.start()
	refreshPrompts()
	CollectionService:GetInstanceAddedSignal("LuckyShowroom"):Connect(function(root: Instance)
		promptsIn(root)
		root.DescendantAdded:Connect(function(d: Instance)
			if d:IsA("ProximityPrompt") and d.Name == "LuckyBoxPrompt" then
				d.Enabled = allowed()
			end
		end)
	end)
	CollectionService:GetInstanceRemovedSignal("LuckyBoxSpin"):Connect(function(m: Instance)
		bases[m :: any] = nil
	end)
	player:GetAttributeChangedSignal("PaidRandomAllowed"):Connect(refreshPrompts)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "LuckyBoxPrompt" and allowed() then
			LuckyBoxPanel.open()
		end
	end)
	RunService.RenderStepped:Connect(function()
		LuckyShowroom.step(os.clock())
	end)
end

return LuckyShowroom
