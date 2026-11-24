--!strict
-- (Build 102) The elevator to the private floors, on this screen (server/Wings decides every
-- journey). Its panel: your Suite, your Vault, a friend's Suite when they allow it, the house; each
-- with how long it takes. The ride: the car's doors slide shut, a brass indicator counts the floors
-- with an arrow, light slips past the doors' seam, a chime on leaving and arriving, and the doors
-- part onto where you've arrived. It lasts exactly as long as the server's journey (5.5 seconds to
-- your own floors, 6.5 to a friend's), and you can't walk away mid-ride.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Controls = require(script.Parent.Parent.Controls)
local Sound = require(script.Parent.Parent.Sound)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local Elevator = {}

local NAME = "Elevator"
local C = Brand.Colours
local GOLD = Color3.fromRGB(232, 196, 108)

local function sound(name: string, volume: number?)
	pcall(Sound.play, name, volume or 0.6)
end

---------------------------------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------------------------------

local function ride(to: string, userId: number?)
	Root.close(NAME)
	task.spawn(function()
		local ok, r = pcall(function()
			return Remotes.func("ElevatorAsk"):InvokeServer({ op = "ride", to = to, userId = userId })
		end)
		if ok and type(r) == "table" and r.ok ~= true then
			Toast.show("The elevator", tostring(r.why or "Not just now."), 3)
		end
	end)
end

local function seconds(floors: { [string]: any }, key: string): string
	local s = type(floors.seconds) == "table" and tonumber(floors.seconds[key]) or nil
	return if s then string.format("%.1f s", s) else ""
end

-- Opens the panel with the floors the server says this guest may choose.
function Elevator.open(floors: { [string]: any }?)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local f = floors
	if not f then
		local ok, r = pcall(function()
			return Remotes.func("ElevatorAsk"):InvokeServer({ op = "floors" })
		end)
		if not ok or type(r) ~= "table" or type(r.floors) ~= "table" then
			Toast.show("The elevator", "Not just now.", 3)
			return
		end
		f = r.floors
	end
	local fl = f :: { [string]: any }
	local here = tostring(fl.here or "house")
	local w = Root.panelWidth(400)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 300))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The elevator", 11, "caps", { LayoutOrder = 1, TextColor3 = GOLD })
	Theme.text(content, "Your private floors", 22, "display", { LayoutOrder = 2 })
	Theme.text(content, "Your Suite and your Vault are yours alone: nobody else can walk in. Friends come up only when you let them.", 13, "body", { LayoutOrder = 3, TextColor3 = C.smoke })
	local order = 10
	local function choice(label: string, primary: boolean, fn: () -> ())
		order += 1
		local k = Theme.key(content, label, primary, fn, w - 48)
		k.Name = "Floor" .. order
		k.LayoutOrder = order
	end
	if here ~= "suite" then
		choice("Your Suite  ·  " .. seconds(fl, "suite"), true, function()
			ride("suite", nil)
		end)
	end
	if here ~= "vault" then
		choice("Your Vault  ·  " .. seconds(fl, "vault"), here == "suite", function()
			ride("vault", nil)
		end)
	end
	local closed = 0
	if type(fl.friends) == "table" then
		for _, friend in fl.friends do
			if type(friend) == "table" and friend.open == true then
				local id = tonumber(friend.userId)
				choice(tostring(friend.name) .. "'s Suite  ·  " .. seconds(fl, "friend"), false, function()
					ride("friend", id)
				end)
			elseif type(friend) == "table" then
				closed += 1
			end
		end
	end
	if closed > 0 then
		order += 1
		Theme.text(content, if closed == 1 then "One friend here has their Suite closed to visitors." else closed .. " friends here have their Suites closed to visitors.", 12, "body", { LayoutOrder = order, TextColor3 = C.smoke })
	end
	if here ~= "house" then
		choice("Back to the house  ·  " .. seconds(fl, "house"), false, function()
			ride("house", nil)
		end)
	end
	order += 1
	local close = Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 160)
	close.LayoutOrder = 200
	Root.open(NAME, group)
	sound("hover", 0.4)
end

function Elevator.isOpen(): boolean
	return Root.isOpen(NAME)
end

---------------------------------------------------------------------------------------------------
-- The ride
---------------------------------------------------------------------------------------------------

local current: { [string]: any }? = nil

local function frame(parent: Instance, name: string, colour: Color3, pos: UDim2, size: UDim2, z: number, t: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = t or 0
	f.Position = pos
	f.Size = size
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function gradient(f: GuiObject, a: Color3, b: Color3, rotation: number)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation
	g.Parent = f
end

-- One of the car's doors: brushed brass, a darker seam, fine lines down it.
local function door(parent: Instance, left: boolean): Frame
	local d = frame(parent, if left then "DoorL" else "DoorR", Color3.new(1, 1, 1), UDim2.fromScale(if left then -0.5 else 1, 0), UDim2.fromScale(0.5, 1), 20)
	gradient(d, Color3.fromRGB(196, 158, 86), Color3.fromRGB(120, 88, 40), if left then 0 else 180)
	for i = 1, 9 do
		local line = frame(d, "Line", Color3.fromRGB(255, 236, 190), UDim2.fromScale(i / 10, 0), UDim2.new(0, 1, 1, 0), 21, 0.82)
		line.Size = UDim2.new(0, 1, 1, 0)
	end
	local edge = frame(d, "Edge", Color3.fromRGB(60, 42, 16), UDim2.new(if left then 1 else 0, if left then -3 else 0, 0, 0), UDim2.new(0, 3, 1, 0), 22)
	edge.Size = UDim2.new(0, 3, 1, 0)
	return d
end

function Elevator.ride(m: { [string]: any })
	Elevator.finish(true)
	Root.close(NAME)
	local seconds = math.clamp(tonumber(m.seconds) or 5.5, 1, 10)
	-- (Notices wait for the doors to open.)
	Toast.hold(true)
	local was = Controls.wanted()
	Controls.set(false)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MaisonElevator"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 94
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Root.hud.Parent
	-- The car: dark lacquered walls with gold pinstripes, a warm light along the ceiling.
	local car = frame(gui, "Car", Color3.new(1, 1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10)
	car.Active = true
	gradient(car, Color3.fromRGB(34, 24, 18), Color3.fromRGB(10, 8, 8), 90)
	car.BackgroundTransparency = 1
	for i = 1, 11 do
		frame(car, "Stripe", GOLD, UDim2.fromScale(i / 12, 0), UDim2.new(0, 1, 1, 0), 11, 0.86)
	end
	local glow = frame(car, "CeilingLight", Color3.fromRGB(255, 214, 150), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.16), 12, 0.2)
	local gg = Instance.new("UIGradient")
	gg.Rotation = 90
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	gg.Parent = glow
	local rail = frame(car, "Rail", GOLD, UDim2.fromScale(0, 0.72), UDim2.new(1, 0, 0, 4), 13, 0.15)
	rail.Size = UDim2.new(1, 0, 0, 4)
	-- The doors (closing at once), and the light slipping past their seam as the car moves.
	local doors = frame(car, "Doors", Color3.new(0, 0, 0), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.62, 0.92), 19, 1)
	doors.AnchorPoint = Vector2.new(0.5, 0.5)
	doors.ClipsDescendants = true
	local frameRing = Instance.new("UIStroke")
	frameRing.Color = GOLD
	frameRing.Thickness = 3
	frameRing.Parent = doors
	local leftDoor = door(doors, true)
	local rightDoor = door(doors, false)
	local seam = frame(doors, "Seam", Color3.fromRGB(255, 230, 170), UDim2.fromScale(0.5, 0), UDim2.new(0, 2, 1, 0), 23, 1)
	seam.AnchorPoint = Vector2.new(0.5, 0)
	-- The indicator over the doors: an arrow and the floor, in brass on black glass.
	local panel = frame(car, "Indicator", Color3.fromRGB(8, 6, 6), UDim2.fromScale(0.5, 0.06), UDim2.fromOffset(240, 66), 30, 0.05)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 12)
	pc.Parent = panel
	local ps = Instance.new("UIStroke")
	ps.Color = GOLD
	ps.Thickness = 1.5
	ps.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Scale = math.max(0.75, Root.scale)
	scale.Parent = panel
	local function text(name: string, words: string, size: number, font: Font, colour: Color3, pos: UDim2, sz: UDim2, z: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Text = words
		l.TextSize = size
		l.FontFace = font
		l.TextColor3 = colour
		l.Position = pos
		l.Size = sz
		l.ZIndex = z
		l.Parent = panel
		return l
	end
	local up = m.to ~= "house"
	local arrow = text("Arrow", if up then "▲" else "▼", 22, Brand.Fonts.heavy, GOLD, UDim2.fromOffset(14, 0), UDim2.new(0, 30, 1, 0), 31)
	local floorLabel = text("Floor", "L", 30, Brand.Fonts.display, Color3.fromRGB(255, 236, 196), UDim2.fromOffset(50, 4), UDim2.new(0, 80, 0, 36), 31)
	text("Where", string.upper(tostring(m.name or "")), 11, Brand.Fonts.heavy, Color3.fromRGB(210, 190, 150), UDim2.fromOffset(50, 40), UDim2.new(1, -60, 0, 16), 31).TextXAlignment = Enum.TextXAlignment.Left
	floorLabel.TextXAlignment = Enum.TextXAlignment.Left
	-- How far along, exactly: a fine gold line under the indicator.
	local track = frame(panel, "Track", Color3.new(1, 1, 1), UDim2.new(0, 14, 1, -6), UDim2.new(1, -28, 0, 2), 31, 0.85)
	local fill = frame(track, "Fill", GOLD, UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), 32)

	TweenService:Create(car, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 0 }):Play()
	local shut = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(leftDoor, shut, { Position = UDim2.fromScale(0, 0) }):Play()
	TweenService:Create(rightDoor, shut, { Position = UDim2.fromScale(0.5, 0) }):Play()
	sound("chime", 0.5)
	task.delay(0.15, sound, "slide", 0.4)

	-- Floors counted on the way: the house (L), then up to the private floors (or the reverse).
	local target = tostring(m.floor or "PH")
	local stops = if up then { "L", "2", "5", "9", "14", "20", "27", "36", target } else { "PH", "27", "14", "5", "L" }
	local started = os.clock()
	local state: { [string]: any } = { gui = gui, controls = was, left = leftDoor, right = rightDoor, car = car }
	current = state
	state.beat = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - started) / seconds, 0, 1)
		fill.Size = UDim2.fromScale(t, 1)
		-- (The car eases away and eases in: the floors pass fastest in the middle.)
		local eased = t * t * (3 - 2 * t)
		floorLabel.Text = stops[math.clamp(1 + math.floor(eased * (#stops - 1) + 0.5), 1, #stops)]
		seam.BackgroundTransparency = 0.35 + 0.5 * (0.5 + 0.5 * math.sin(os.clock() * 9))
		arrow.TextTransparency = 0.1 + 0.4 * (0.5 + 0.5 * math.sin(os.clock() * 4))
		glow.BackgroundTransparency = 0.15 + 0.1 * math.sin(os.clock() * 2)
	end)
	-- (Never stuck: if the server's word that we've arrived doesn't come, it opens anyway.)
	task.delay(seconds + 3, function()
		if current == state then
			Elevator.finish(false)
		end
	end)
end

-- Arrived: the doors part onto the new floor and the car fades away. `quiet`: just put it away.
function Elevator.finish(quiet: boolean?)
	local state = current
	if not state then
		return
	end
	current = nil
	if state.beat then
		state.beat:Disconnect()
	end
	Controls.set(state.controls ~= false)
	task.delay(if quiet then 0 else 0.9, Toast.hold, false)
	local gui = state.gui :: ScreenGui
	if quiet then
		gui:Destroy()
		return
	end
	sound("chime", 0.6)
	local open = TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	TweenService:Create(state.left, open, { Position = UDim2.fromScale(-0.5, 0) }):Play()
	TweenService:Create(state.right, open, { Position = UDim2.fromScale(1, 0) }):Play()
	task.delay(0.35, function()
		for _, d in gui:GetDescendants() do
			if d:IsA("Frame") then
				TweenService:Create(d, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(0.95, function()
		gui:Destroy()
	end)
end

function Elevator.riding(): boolean
	return current ~= nil
end

function Elevator.start()
	Remotes.event("Guest").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "elevatorMenu" and type(m.floors) == "table" then
			Elevator.open(m.floors)
		elseif m.op == "elevator" then
			Elevator.ride(m)
		elseif m.op == "elevatorArrived" then
			Elevator.finish(false)
		end
	end)
end

return Elevator
