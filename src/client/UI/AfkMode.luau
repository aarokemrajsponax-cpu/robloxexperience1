--!strict
-- AFK mode on this screen, and the one note about it.
--   * Idle two minutes (no key, no touch, no move: Roblox's Idled), the AFK card shows: the
--     brainrots' jar filling, Gilt an hour, how long you've rested, and that moving brings you
--     back. Every eighteen minutes of it the house rejoins you to this server (server/Afk), so
--     Roblox's idle kick never comes, and the card comes straight back.
--   * Opening Roblox's menu (often on the way out), a note at the top of the screen: you earn Gilt
--     offline with brainrots. At most every fifteen minutes, never more: a reminder, not a nag.
-- Nothing here gives anything: the jar is the server's (server/Brainrots), and what it says is
-- what the server last said.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Voice = require(ReplicatedStorage.Shared.Voice)
local CurioState = require(script.Parent.Parent.CurioState)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local AfkMode = {}

local C = Brand.Colours
local V = Voice.Afk
local player = Players.LocalPlayer

local card: Frame? = nil
local since = 0 -- os.clock() when the guest went idle
local beat: RBXScriptConnection? = nil
local asked = false -- the rejoin has been asked for
local noteAt = -math.huge

local function cfg(): { [string]: any }
	return (Config.data :: any).Afk or {}
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

function AfkMode.active(): boolean
	return card ~= nil
end

-- Leaves AFK mode (they moved, or pressed something).
function AfkMode.leave()
	local c = card
	if not c then
		return
	end
	card = nil
	asked = false
	if beat then
		beat:Disconnect()
		beat = nil
	end
	Ease.play(c, Ease.info(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	for _, d in c:GetDescendants() do
		if d:IsA("TextLabel") then
			Ease.play(d, Ease.info(0.3, Enum.EasingStyle.Quad), { TextTransparency = 1 })
		end
	end
	task.delay(0.32, function()
		c:Destroy()
	end)
end

-- Shows the AFK card; `idleFor` seconds have passed without a touch already.
function AfkMode.enter(idleFor: number)
	if card then
		return
	end
	since = os.clock() - math.max(0, idleFor)
	local shade = Instance.new("Frame")
	shade.Name = "AfkMode"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
	shade.BackgroundTransparency = 0.35
	shade.BorderSizePixel = 0
	shade.ZIndex = 70
	shade.Parent = Root.toasts
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.6) })
	fade.Parent = shade
	local col = Instance.new("Frame")
	col.Name = "Column"
	col.AnchorPoint = Vector2.new(0.5, 0.5)
	col.Position = UDim2.fromScale(0.5, 0.5)
	col.Size = UDim2.fromOffset(math.min(460, Root.size().X - 32), 250)
	col.BackgroundTransparency = 1
	col.ZIndex = 71
	col.Parent = shade
	local list = Theme.list(col, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local function line(name: string, text: string, size: number, kind: any, colour: Color3, order: number): TextLabel
		local l = Theme.text(col, text, size, kind, { Name = name, LayoutOrder = order, TextWrapped = true, TextColor3 = colour })
		l.ZIndex = 72
		return l
	end
	line("Kicker", V.kicker, 12, "caps", Color3.fromRGB(255, 204, 90), 1)
	line("Jar", "", 40, "display", C.bone, 2)
	line("Rate", "", 14, "bodyBold", C.lightGold, 3)
	line("Away", string.format(V.away, math.floor(Brainrots.OFFLINE_SHARE * 100 + 0.5), Brainrots.OFFLINE_HOURS), 13, "body", C.smoke, 4)
	line("Rested", "", 13, "body", C.smoke, 5)
	line("Back", V.back, 13, "bodyBold", C.bone, 6)
	if cfg().rejoin ~= false then
		line("Rejoin", string.format(V.rejoin, tonumber(cfg().rejoinMinutes) or 18), 11, "body", C.smoke, 7)
	end
	card = shade
	asked = false
	beat = RunService.Heartbeat:Connect(function()
		AfkMode.tick()
	end)
	AfkMode.tick()
end

-- Keeps the card up to the moment, and asks to be rejoined when it's time.
function AfkMode.tick()
	local c = card
	if not c then
		return
	end
	local col = c:FindFirstChild("Column")
	if not col then
		return
	end
	local jar, _cap, rate = CurioState.jar()
	local jarLabel = col:FindFirstChild("Jar") :: TextLabel?
	local rateLabel = col:FindFirstChild("Rate") :: TextLabel?
	local rested = col:FindFirstChild("Rested") :: TextLabel?
	if jarLabel then
		jarLabel.Text = if rate > 0 then string.format("%s Gilt", commas(jar)) else V.noSquad
		jarLabel.TextSize = if rate > 0 then 40 else 20
	end
	if rateLabel then
		rateLabel.Text = if rate > 0 then string.format(V.rate, commas(rate)) else V.noSquadLine
	end
	local idle = os.clock() - since
	if rested then
		rested.Text = string.format(V.rested, clock(idle))
	end
	local minutes = tonumber(cfg().rejoinMinutes) or 18
	if cfg().rejoin ~= false and not asked and idle >= minutes * 60 then
		asked = true
		task.spawn(function()
			CurioState.ask({ op = "afkRejoin" })
		end)
	end
end

-- The note at the top while Roblox's menu is open: you earn Gilt offline with brainrots.
function AfkMode.menuNote()
	local gap = (tonumber(cfg().menuNoteMinutes) or 15) * 60
	if os.clock() - noteAt < gap or Root.toasts:FindFirstChild("AfkNote") then
		return
	end
	noteAt = os.clock()
	local _, _, rate = CurioState.jar()
	local bar = Instance.new("Frame")
	bar.Name = "AfkNote"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, -90)
	bar.Size = UDim2.fromOffset(math.min(620, Root.size().X - 24), 70)
	bar.BackgroundColor3 = Color3.fromRGB(16, 12, 10)
	bar.BackgroundTransparency = 0.05
	bar.BorderSizePixel = 0
	bar.ZIndex = 95
	bar.Parent = Root.toasts
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bar
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 204, 90)
	stroke.Thickness = 1.5
	stroke.Parent = bar
	local title = Theme.text(bar, V.note, 20, "display", { Name = "Title", Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 26), TextColor3 = Color3.fromRGB(255, 214, 110) })
	title.ZIndex = 96
	local sub = Theme.text(bar, if rate > 0 then string.format(V.noteLine, commas(Brainrots.offlineRate(rate)), Brainrots.OFFLINE_HOURS) else V.noteNone, 12, "body", { Name = "Line", Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 18), TextColor3 = C.bone, TextWrapped = true })
	sub.ZIndex = 96
	Ease.play(bar, Ease.info(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 12) })
end

local function noteAway()
	local bar = Root.toasts:FindFirstChild("AfkNote") :: Frame?
	if not bar then
		return
	end
	task.delay(6, function()
		if bar.Parent then
			Ease.play(bar, Ease.info(0.4, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, 0, 0, -90) })
			task.delay(0.45, function()
				bar:Destroy()
			end)
		end
	end)
end

function AfkMode.start()
	player.Idled:Connect(function(seconds: number)
		if seconds >= (tonumber(cfg().after) or 120) then
			AfkMode.enter(seconds)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if card and input.UserInputType ~= Enum.UserInputType.MouseMovement then
			AfkMode.leave()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if not card then
			return
		end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local ok, moving = pcall(function()
			return hum ~= nil and hum.MoveDirection.Magnitude > 0.1
		end)
		if ok and moving then
			AfkMode.leave()
		end
	end)
	GuiService.MenuOpened:Connect(AfkMode.menuNote)
	GuiService.MenuClosed:Connect(noteAway)
	-- Rejoined from AFK mode: straight back to the card.
	local ok, data = pcall(function()
		return TeleportService:GetLocalPlayerTeleportData()
	end)
	if ok and type(data) == "table" and (data :: any).afk == true then
		task.delay(4, function()
			AfkMode.enter(0)
		end)
	end
end

return AfkMode
