--!strict
-- The screen layers, their scale on small phones, and the panel stack. Panels layer:
-- closing one returns you exactly where you were. While a panel is open the world behind
-- it falls softly out of focus and the music dips.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ease = require(ReplicatedStorage.Shared.Ease)

local Root = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local function screen(name: string, order: number, insets: Enum.ScreenInsets): ScreenGui
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order
	gui.IgnoreGuiInset = insets == Enum.ScreenInsets.None
	gui.ScreenInsets = insets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end

Root.intro = screen("MaisonIntro", 100, Enum.ScreenInsets.None)
Root.panels = screen("MaisonPanels", 50, Enum.ScreenInsets.CoreUISafeInsets)
Root.dialogue = screen("MaisonDialogue", 40, Enum.ScreenInsets.CoreUISafeInsets)
Root.hud = screen("MaisonHud", 20, Enum.ScreenInsets.CoreUISafeInsets)
Root.prompts = screen("MaisonPrompts", 15, Enum.ScreenInsets.CoreUISafeInsets)

-- One UIScale per layer so everything fits the smallest phone.
local scales: { UIScale } = {}
for _, gui in { Root.intro, Root.panels, Root.dialogue, Root.hud } do
	local s = Instance.new("UIScale")
	s.Parent = gui
	table.insert(scales, s)
end

function Root.viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

Root.scale = 1
-- Called after the scale changes (Theme sets small text larger when everything is scaled down).
Root.rescaled = {} :: { (scale: number) -> () }
local function rescale()
	local v = Root.viewport()
	local short = math.min(v.X, v.Y)
	local before = Root.scale
	Root.scale = math.clamp(short / 640, 0.62, 1.25)
	for _, s in scales do
		s.Scale = Root.scale
	end
	if Root.scale ~= before then
		for _, fn in Root.rescaled do
			fn(Root.scale)
		end
	end
end
rescale()
local function watchCamera()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
end
watchCamera()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera()
	rescale()
end)

-- Usable size of a layer in unscaled pixels.
-- Usable size of a layer in unscaled pixels: below Roblox's top bar, which panels sit under.
function Root.size(): Vector2
	local v = Root.viewport()
	local ok, top = pcall(function()
		return GuiService:GetGuiInset()
	end)
	local inset = if ok and typeof(top) == "Vector2" then top.Y else 0
	return Vector2.new(v.X, math.max(200, v.Y - inset)) / Root.scale
end

-- Soft focus behind panels (local only).
local focus = Instance.new("DepthOfFieldEffect")
focus.Name = "MaisonFocus"
focus.Enabled = false
focus.FarIntensity = 0
focus.NearIntensity = 0
focus.FocusDistance = 0.05
focus.InFocusRadius = 0
focus.Parent = Lighting

local blurGoal = { FarIntensity = 0.55, NearIntensity = 0.4, FocusDistance = 0.05, InFocusRadius = 0 }
local clearGoal = { FarIntensity = 0, NearIntensity = 0 }

-- A resting focus under no panel: at the table, the felt sharp and the room behind it soft.
export type Focus = { FocusDistance: number, InFocusRadius: number, FarIntensity: number }
local baseFocus: Focus? = nil

export type Panel = {
	name: string,
	group: CanvasGroup,
	onClose: (() -> ())?,
	blur: boolean,
}

local stack: { Panel } = {}
Root.sticky = { Round = true } :: { [string]: boolean }
local dip: ((boolean) -> ())? = nil

function Root.onDip(fn: (boolean) -> ())
	dip = fn
end

local function updateFocus()
	local anyBlur = false
	for _, p in stack do
		if p.blur then
			anyBlur = true
		end
	end
	local base = baseFocus
	if anyBlur then
		focus.Enabled = true
		Ease.play(focus, Ease.panel, blurGoal)
	elseif base then
		focus.Enabled = true
		Ease.play(focus, Ease.settle, { FocusDistance = base.FocusDistance, InFocusRadius = base.InFocusRadius, FarIntensity = base.FarIntensity, NearIntensity = 0 })
	else
		local t = Ease.play(focus, Ease.panel, clearGoal)
		t.Completed:Once(function()
			if #stack == 0 and baseFocus == nil then
				focus.Enabled = false
			end
		end)
	end
	if dip then
		dip(anyBlur)
	end
	-- The world's prompts step back while a panel is open.
	Root.prompts.Enabled = #stack == 0
end

function Root.setFocus(goal: Focus?)
	baseFocus = goal
	updateFocus()
end

local panelChanged = Instance.new("BindableEvent")
Root.PanelsChanged = panelChanged.Event

-- Each panel eases in from a touch smaller and lower, and eases away the same way.
local function openScale(group: CanvasGroup): UIScale
	local existing = group:FindFirstChild("OpenScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local s = Instance.new("UIScale")
	s.Name = "OpenScale"
	s.Parent = group
	return s
end

local function show(group: CanvasGroup)
	group.Visible = true
	group.GroupTransparency = 1
	local startPos = group.Position
	group.Position = startPos + UDim2.fromOffset(0, 10)
	local s = openScale(group)
	s.Scale = 0.965
	Ease.play(group, Ease.scaled(Ease.panel), { GroupTransparency = 0, Position = startPos })
	Ease.play(s, Ease.scaled(Ease.info(0.42, Enum.EasingStyle.Quint)), { Scale = 1 })
end

local function hide(group: CanvasGroup, destroy: boolean)
	local startPos = group.Position
	Ease.play(openScale(group), Ease.scaled(Ease.quick), { Scale = 0.98 })
	local t = Ease.play(group, Ease.scaled(Ease.quick), { GroupTransparency = 1, Position = startPos + UDim2.fromOffset(0, 6) })
	t.Completed:Once(function()
		group.Position = startPos
		if destroy then
			group:Destroy()
		else
			group.Visible = false
		end
	end)
end

-- Opens a panel on top of whatever is showing. The one beneath fades back while this is up.
function Root.open(name: string, group: CanvasGroup, onClose: (() -> ())?, blur: boolean?)
	for i = #stack, 1, -1 do
		if stack[i].name == name then
			table.remove(stack, i)
		end
	end
	local below = stack[#stack]
	if below then
		Ease.play(below.group, Ease.quick, { GroupTransparency = 1 })
		below.group.Interactable = false
	end
	local panel: Panel = { name = name, group = group, onClose = onClose, blur = blur ~= false }
	table.insert(stack, panel)
	group.Interactable = true
	show(group)
	updateFocus()
	panelChanged:Fire()
end

function Root.close(name: string?)
	local index = #stack
	if name then
		index = 0
		for i, p in stack do
			if p.name == name then
				index = i
			end
		end
	end
	if index == 0 then
		return
	end
	local panel = table.remove(stack, index) :: Panel
	hide(panel.group, true)
	local top = stack[#stack]
	if top then
		top.group.Interactable = true
		Ease.play(top.group, Ease.panel, { GroupTransparency = 0 })
	end
	updateFocus()
	panelChanged:Fire()
	if panel.onClose then
		panel.onClose()
	end
end

function Root.isOpen(name: string?): boolean
	if name == nil then
		return #stack > 0
	end
	for _, p in stack do
		if p.name == name then
			return true
		end
	end
	return false
end

function Root.top(): string?
	local p = stack[#stack]
	return if p then p.name else nil
end

-- Esc (or B on a gamepad) closes the top panel.
ContextActionService:BindActionAtPriority("MaisonClosePanel", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local top = stack[#stack]
	-- Decision panels (the round summary) stay until a choice is made.
	if top and not Root.sticky[top.name] then
		Root.close()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, 3000, Enum.KeyCode.ButtonB)

return Root
