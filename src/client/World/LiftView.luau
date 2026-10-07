--!strict
-- The lift ride on this screen (VaultAccess on the server moves the guest): the screen dims to
-- black as the doors close behind them, a line says where they're going, a soft hum while the car
-- travels, and it brightens again as the doors open on the other floor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LiftView = {}

local player = Players.LocalPlayer

function LiftView.ride(to: string, seconds: number)
	local gui = Instance.new("ScreenGui")
	gui.Name = "LiftRide"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	local cover = Instance.new("Frame")
	cover.BackgroundColor3 = Color3.fromRGB(6, 6, 8)
	cover.BackgroundTransparency = 1
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.Parent = gui
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(0.8, 0, 0, 40)
	line.FontFace = Brand.Fonts.display
	line.TextSize = 30
	line.TextColor3 = Color3.fromRGB(240, 214, 150)
	line.TextTransparency = 1
	line.Text = "The lift · to " .. to
	line.Parent = cover
	gui.Parent = player:WaitForChild("PlayerGui")
	local dim = math.max(0.4, math.min(0.7, seconds * 0.3))
	TweenService:Create(cover, TweenInfo.new(dim, Enum.EasingStyle.Quad), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(line, TweenInfo.new(dim), { TextTransparency = 0 }):Play()
	task.delay(seconds, function()
		TweenService:Create(cover, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(line, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.delay(0.8, function()
			gui:Destroy()
		end)
	end)
end

function LiftView.start()
	Remotes.event("Guest").OnClientEvent:Connect(function(m: any)
		if type(m) == "table" and m.op == "lift" then
			LiftView.ride(tostring(m.name or "the next floor"), math.clamp(tonumber(m.seconds) or 2, 1, 5))
		end
	end)
end

return LiftView
