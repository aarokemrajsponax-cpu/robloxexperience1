--!strict
-- Maison Noir: client boot. Intro → title over the street → Play → the walk in → the table.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local State = require(script.Parent.State)
local Root = require(script.Parent.UI.Root)
local Theme = require(script.Parent.UI.Theme)
local Sound = require(script.Parent.Sound)
local CameraRig = require(script.Parent.Camera)
local Intro = require(script.Parent.UI.Intro)
local Title = require(script.Parent.UI.Title)
local Dialogue = require(script.Parent.UI.Dialogue)
local Prompts = require(script.Parent.UI.Prompts)
local Hud = require(script.Parent.UI.Hud)
local Toast = require(script.Parent.UI.Toast)
local SettingsPanel = require(script.Parent.UI.SettingsPanel)
local BoardPanel = require(script.Parent.UI.BoardPanel)
local HowToPlay = require(script.Parent.UI.HowToPlay)
local Counter = require(script.Parent.Table.Counter)
local TableClient = require(script.Parent.Table.TableClient)
local Ambient = require(script.Parent.World.Ambient)

local player = Players.LocalPlayer

-- Roblox's own chat stays. The house has no tools and no health bar.
for _, kind in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(kind, false)
	end)
end

State.watch("movement", function(value)
	Ease.motionScale = if value == "Still" then 0 elseif value == "Calm" then 0.6 else 1
end)
Theme.onClick(Sound.ui)
Root.onDip(Sound.dip)

Dialogue.start()
Prompts.start()
Counter.start()
TableClient.start()
Ambient.start()

-- Controls stay off until Play.
local controls: any = nil
local function getControls(): any
	if controls then
		return controls
	end
	local ok, module = pcall(function()
		return require((player:WaitForChild("PlayerScripts") :: any):WaitForChild("PlayerModule") :: ModuleScript) :: any
	end)
	if ok and module then
		controls = module:GetControls()
	end
	return controls
end
local function setControls(on: boolean)
	local c = getControls()
	if c then
		if on then
			c:Enable()
		else
			c:Disable()
		end
	end
end
setControls(false)

-- Walk by default; hold Shift (or click the left stick) to run.
local running = false
local function applySpeed()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if running then Config.data.Movement.runSpeed else Config.data.Movement.walkSpeed
	end
end
ContextActionService:BindAction("MaisonRun", function(_, state, input)
	if input.KeyCode == Enum.KeyCode.ButtonL3 then
		if state == Enum.UserInputState.Begin then
			running = not running
		end
	else
		running = state == Enum.UserInputState.Begin
	end
	applySpeed()
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

local function quickSit()
	if TableClient.isSeated() then
		return
	end
	task.spawn(function()
		local ok, seated = pcall(function()
			return Remotes.func("QuickSit"):InvokeServer()
		end)
		if not ok or not seated then
			Toast.show("The Salon", "Every table is taken. One will be free shortly.", 4)
		end
	end)
end

local hudStarted = false
local function startHud()
	if hudStarted then
		return
	end
	hudStarted = true
	Hud.start(SettingsPanel.open, TableClient.leave)
end

local function waitForCharacter(): Model
	local character = player.Character
	while not character or not character:FindFirstChild("HumanoidRootPart") do
		task.wait(0.1)
		character = player.Character
	end
	return character :: Model
end

local playing = false
local function onPlay()
	if playing then
		return
	end
	playing = true
	Title.hide()
	State.funnel(2)
	waitForCharacter()
	State.setPhase("handoff")
	CameraRig.handoff(1.6)
	setControls(true)
	applySpeed()
	State.setPhase("play")
	State.funnel(3)
	startHud()
	if State.isFirstVisit() and not TableClient.isSeated() then
		Hud.showStraight(quickSit)
	end
end

HowToPlay.onFinish = function()
	if TableClient.isSeated() then
		return
	end
	if not playing then
		task.spawn(onPlay)
		task.wait(1.8)
	end
	quickSit()
end

TableClient.Seated.Event:Connect(function()
	Hud.hideStraight()
end)

Remotes.event("Guest").OnClientEvent:Connect(function(message: any)
	if type(message) == "table" and message.op == "howto" then
		HowToPlay.open()
	end
end)

-- Respawns never replay the intro; they hand straight back to the follow camera.
player.CharacterAdded:Connect(function()
	if playing then
		task.wait(0.2)
		if not TableClient.isSeated() then
			CameraRig.follow()
			setControls(true)
			applySpeed()
		end
	end
end)

-- The title keeps its composed shot even if Roblox resets the camera when the avatar appears.
local function guardTitleCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if (State.phase == "intro" or State.phase == "title") and camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
	end)
end

-- Boot
State.setPhase("intro")
CameraRig.titleDrift()
guardTitleCamera()
Intro.play(function()
	State.funnel(1)
end)
State.waitForWelcome(12)
if not playing then
	State.setPhase("title")
	Title.show({ play = onPlay, how = HowToPlay.open, board = BoardPanel.open })
end
