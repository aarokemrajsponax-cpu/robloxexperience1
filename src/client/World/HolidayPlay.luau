--!strict
-- The holiday games on this screen (shared/HolidayGames says what they are; server/Holidays runs
-- them). This follows which game is open and where the guest is, draws each game's place when it
-- arrives on this screen (World/HolidayLane, HolidayField, HolidayPole, HolidayEggs, SleighRide),
-- hears what happens (a door answered, a turkey caught, gifts loaded, an egg found) and shows what
-- the guest won (UI/HolidayPop), keeps the holiday's key at the foot of the dock (Treats, Turkeys,
-- the Sleigh, your Gifts, Eggs, Home), and says on the objective card what to do next. Nothing
-- here decides a reward: the server's messages say what was paid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HolidayKit = require(script.Parent.HolidayKit)
local HolidayLane = require(script.Parent.HolidayLane)
local HolidayField = require(script.Parent.HolidayField)
local HolidayPole = require(script.Parent.HolidayPole)
local HolidayEggs = require(script.Parent.HolidayEggs)
local SleighRide = require(script.Parent.SleighRide)
local HolidayPop = require(script.Parent.Parent.UI.HolidayPop)

local HolidayPlay = {}

local rgb = Color3.fromRGB

-- Set by Main: the dock's holiday key (QuickDock.setHoliday), a quiet notice (Toast), the gift
-- screen (GiftOpening.open), and the objective card's refresh.
HolidayPlay.dockKey = function(_glyph: string?, _label: string?, _count: number?) end
HolidayPlay.say = function(_title: string, _line: string) end
HolidayPlay.openGifts = function(_count: number) end
HolidayPlay.goalChanged = function() end

local TREATS: { [string]: string } = {
	truffle = "🍫",
	apple = "🍎",
	lollipop = "🍭",
	chocolate = "🍫",
	macaron = "🍪",
	caramel = "🍬",
	beans = "🍬",
	floss = "☁️",
}

local open: string? = nil -- the game open now
local area: string? = nil -- where the guest is (a game's place, or nil: the Maison)
local pending = 0 -- gifts from the North Pole waiting to be opened
local caught = 0 -- turkeys caught this visit to the field
local loadedTrip = 0
local clock = 0
local root: Folder? = nil
local attached: { [string]: Instance? } = {}
local keySpec = ""

local function ask(request: { [string]: any }): any
	local ok, r = pcall(function()
		return Remotes.func("HolidayAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else { ok = false, why = "The house couldn't do that just now." }
end

local function myRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

---------------------------------------------------------------------------------------------------
-- Going there and coming home: a fade to black and back
---------------------------------------------------------------------------------------------------
local fader: Frame? = nil
local function fade(to: number, seconds: number)
	local f = fader
	if not f or not f.Parent then
		local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
		if not pg then
			return
		end
		local g = Instance.new("ScreenGui")
		g.Name = "HolidayTravel"
		g.IgnoreGuiInset = true
		g.ResetOnSpawn = false
		g.DisplayOrder = 90
		g.Parent = pg
		local nf = Instance.new("Frame")
		nf.Size = UDim2.fromScale(1, 1)
		nf.BackgroundColor3 = rgb(4, 4, 8)
		nf.BackgroundTransparency = 1
		nf.BorderSizePixel = 0
		nf.Parent = g
		fader = nf
		f = nf
	end
	local t = TweenService:Create(f :: Frame, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 - to })
	t:Play()
end

local function travel(request: { [string]: any })
	fade(1, 0.3)
	task.wait(0.32)
	local r = ask(request)
	task.wait(if r.ok then 0.35 else 0)
	fade(0, 0.5)
	if not r.ok and r.why then
		HolidayPlay.say("Not just now", tostring(r.why))
	end
end

---------------------------------------------------------------------------------------------------
-- The key in the dock
---------------------------------------------------------------------------------------------------
local function setKey(glyph: string?, label: string?, count: number?)
	local spec = tostring(glyph) .. "|" .. tostring(label) .. "|" .. tostring(count)
	if spec == keySpec then
		return
	end
	keySpec = spec
	HolidayPlay.dockKey(glyph, label, count)
end

local function updateKey()
	if area ~= nil and area ~= "pole" then
		setKey("🏠", "Home")
		return
	end
	if area == "pole" then
		setKey(nil, nil)
		return
	end
	if pending > 0 and (open == nil or open == "christmas") then
		setKey("🎁", "Gifts", pending)
		return
	end
	if open == "halloween" then
		setKey("🎃", "Treats")
	elseif open == "thanksgiving" then
		setKey("🦃", "Turkeys")
	elseif open == "christmas" then
		setKey("🛷", "Sleigh")
	elseif open == "easter" then
		setKey("🥚", "Eggs", HolidayEggs.left())
	else
		setKey(nil, nil)
	end
end

-- The holiday key was pressed.
function HolidayPlay.press()
	if area ~= nil and area ~= "pole" then
		task.spawn(travel, { op = "home" })
		return
	end
	if pending > 0 and (open == nil or open == "christmas") and area == nil then
		HolidayPlay.openGifts(pending)
		return
	end
	if open == "halloween" or open == "thanksgiving" then
		task.spawn(travel, { op = "go" })
	elseif open == "christmas" then
		task.spawn(function()
			local r = ask({ op = "board" })
			if not r.ok and r.why then
				HolidayPlay.say("Santa's Sleigh", tostring(r.why))
			end
		end)
	elseif open == "easter" then
		HolidayPlay.say("The Great Egg Hunt", string.format("%d eggs are hidden round the house: on shelves, in corners, under things. One is golden.", HolidayEggs.left()))
	end
end

-- (For Gifts' Ride again.)
function HolidayPlay.ride()
	task.spawn(function()
		local r = ask({ op = "board" })
		if not r.ok and r.why then
			HolidayPlay.say("Santa's Sleigh", tostring(r.why))
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- What to do next (the objective card)
---------------------------------------------------------------------------------------------------
export type Goal = { key: string, title: string, line: string, how: string? }

function HolidayPlay.goal(): Goal?
	if area == "lane" then
		local n = 0
		for _ in HolidayLane.visited() do
			n += 1
		end
		return { key = "lane:" .. n, title = "Hallows Lane", line = string.format("Doors knocked at: %d of 9", n), how = "Walk up to a door and knock. Every host has a treat once a round; all nine fills your bag." }
	elseif area == "field" then
		return { key = "field:" .. caught, title = "The Harvest Field", line = if caught > 0 then string.format("Turkeys caught: %d", caught) else "The turkeys are loose", how = "Run at a turkey to catch it. They dodge. The golden one is fastest." }
	elseif area == "pole" then
		local held = HolidayPole.carrying()
		return { key = "pole:" .. held .. ":" .. loadedTrip, title = "The North Pole", line = string.format("In your arms: %d · Loaded: %d", held, loadedTrip), how = "Walk into gifts to pick them up; carry them to the back of the sleigh to load them before it leaves." }
	end
	if pending > 0 then
		return { key = "gifts:" .. pending, title = "Your gifts", line = if pending == 1 then "A gift to open" else string.format("%d gifts to open", pending), how = "The Gifts key in the dock opens them." }
	end
	if open then
		local g = HolidayGames.byId[open]
		if g then
			return { key = "open:" .. open, title = g.name, line = g.line, how = if g.area then "The " .. g.key .. " key in the dock takes you there." else nil }
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- The places arriving on this screen
---------------------------------------------------------------------------------------------------
local function find(name: string): Instance?
	local r = root
	return if r then r:FindFirstChild(name) else nil
end

local function reattach()
	local lane = find("HallowsLane")
	if lane ~= attached.lane then
		attached.lane = lane
		HolidayLane.attach(if lane and lane:IsA("Model") then lane else nil)
	end
	local field = find("HarvestField")
	if field ~= attached.field then
		attached.field = field
		HolidayField.attach(if field and field:IsA("Model") then field else nil)
	end
	local pole = find("NorthPole")
	local sleigh = find("SantasSleigh")
	if pole ~= attached.pole or sleigh ~= attached.sleigh then
		attached.pole = pole
		attached.sleigh = sleigh
		HolidayPole.attach(if pole and pole:IsA("Model") then pole else nil, if sleigh and sleigh:IsA("Model") then sleigh else nil)
		SleighRide.update(if sleigh and sleigh:IsA("Model") then sleigh else nil)
	end
	local eggs = find("Eggs")
	if eggs ~= attached.eggs then
		attached.eggs = eggs
		HolidayEggs.attach(eggs)
	end
end

local function watchRoot(folder: Folder)
	root = folder
	folder.ChildAdded:Connect(function()
		task.defer(reattach)
	end)
	folder.ChildRemoved:Connect(function()
		task.defer(reattach)
	end)
	reattach()
end

---------------------------------------------------------------------------------------------------
-- What the server says
---------------------------------------------------------------------------------------------------
local function onMessage(m: any)
	if type(m) ~= "table" then
		return
	end
	local op = m.op
	if op == "door" and type(m.i) == "number" and type(m.by) == "number" then
		HolidayLane.door(m.i, m.by, m.empty == true, if type(m.treat) == "string" then m.treat else nil)
	elseif op == "treat" then
		HolidayLane.mine(if type(m.visited) == "table" then m.visited else nil, if type(m.host) == "string" then m.host else nil, if type(m.line) == "string" then m.line else nil)
		if m.empty ~= true then
			task.delay(1.9, function()
				HolidayPop.show({
					glyph = TREATS[tostring(m.treat)] or "🍬",
					title = tostring(m.host or "A treat"),
					line = if type(m.treatName) == "string" then string.upper(string.sub(m.treatName, 1, 1)) .. string.sub(m.treatName, 2) else nil,
					gilt = m.gilt,
					gems = m.gems,
					colour = rgb(255, 150, 60),
				})
				if m.full == true then
					task.delay(0.6, function()
						HolidayPop.show({ glyph = "🎃", title = "A full bag!", line = "Every door on Hallows Lane, and the Candy Pail to keep.", gilt = m.bonusGilt, gems = m.bonusGems, colour = rgb(176, 108, 255), big = true })
					end)
				end
			end)
		end
		HolidayPlay.goalChanged()
	elseif op == "caught" and type(m.id) == "number" then
		HolidayField.caught(m.id, m.golden == true, if typeof(m.at) == "Vector3" then m.at else nil)
	elseif op == "turkey" then
		caught += 1
		HolidayPop.show({ glyph = "🦃", title = if m.golden == true then "The golden turkey!" else "Caught one!", line = if m.golden == true then "The fastest bird alive, and you caught it." else "Gobble gobble. Off it goes, back to the barn.", gilt = m.gilt, gems = m.gems, colour = if m.golden == true then rgb(255, 214, 110) else rgb(236, 170, 80), big = m.golden == true })
		HolidayPlay.goalChanged()
	elseif op == "goldenTurkey" then
		if open == "thanksgiving" then
			HolidayPlay.say("The Harvest Field", "A golden turkey has walked out of the barn!")
		end
	elseif op == "picked" and type(m.id) == "number" and type(m.by) == "number" then
		HolidayPole.picked(m.id, m.by)
	elseif op == "loaded" and type(m.by) == "number" and type(m.n) == "number" then
		HolidayPole.loaded(m.by, m.n)
	elseif op == "gifts" then
		if type(m.gifts) == "number" then
			pending = m.gifts
		end
		if type(m.loaded) == "number" then
			local n = m.loaded - loadedTrip
			loadedTrip = m.loaded
			if n > 0 then
				HolidayPop.show({ glyph = "🎁", title = "Loaded on the sleigh", line = if n == 1 then "A gift, safe in Santa's sack." else string.format("%d gifts, safe in Santa's sack.", n), colour = rgb(230, 70, 70), extra = string.format("%d loaded this trip. Open them at home.", loadedTrip) })
			end
		end
		HolidayPlay.goalChanged()
	elseif op == "full" and type(m.why) == "string" then
		HolidayPlay.say("Santa's Sleigh", m.why)
	elseif op == "dropped" and type(m.n) == "number" then
		HolidayPlay.say("Left in the snow", if m.n == 1 then "One gift was still in your arms when the sleigh left." else string.format("%d gifts were still in your arms when the sleigh left.", m.n))
	elseif op == "arrived" then
		if m.place == "pole" then
			loadedTrip = 0
		elseif m.place == "home" then
			loadedTrip = 0
			if type(m.gifts) == "number" then
				pending = m.gifts
				if pending > 0 then
					task.delay(2.2, function()
						HolidayPlay.openGifts(pending)
					end)
				end
			end
		end
		HolidayPlay.goalChanged()
	elseif op == "say" and type(m.text) == "string" then
		HolidayPlay.say("Santa's Sleigh", m.text)
	elseif op == "egg" then
		HolidayEggs.found(if typeof(m.at) == "Vector3" then m.at else nil, m.golden == true)
		HolidayPlay.goalChanged()
	elseif op == "eggFound" then
		HolidayPop.show({ glyph = "🥚", title = if m.golden == true then "The golden egg!" else "A painted egg", line = if m.golden == true then "Hidden best of all. Found by you." else if type(m.left) == "number" then string.format("%d still hidden round the house.", m.left) else nil, gilt = m.gilt, gems = m.gems, colour = if m.golden == true then rgb(255, 214, 110) else rgb(250, 180, 220), big = m.golden == true })
	elseif op == "eggsDone" then
		if open == "easter" then
			HolidayPlay.say("The Great Egg Hunt", "Every egg has been found! More are being hidden...")
		end
	elseif op == "eggsHidden" then
		if open == "easter" then
			HolidayPlay.say("The Great Egg Hunt", "Fresh eggs are hidden all over the house.")
		end
	elseif op == "opened" or op == "closed" then
		task.defer(reattach)
	end
end

---------------------------------------------------------------------------------------------------
-- The beat
---------------------------------------------------------------------------------------------------
local lastArea: string? = nil
local lastHere: string? = nil
local slow = 0

local function step(dt: number)
	clock += dt
	local t = clock
	HolidayKit.step(dt, t)
	SleighRide.step(dt, t)
	if attached.lane then
		HolidayLane.step(dt, t)
	end
	if attached.field then
		HolidayField.step(dt, t)
	end
	if attached.pole or attached.sleigh then
		HolidayPole.step(dt, t)
	end
	slow += dt
	if slow < 0.25 then
		return
	end
	slow = 0
	-- Where the guest is, and where the camera is (each place is dressed while it's seen).
	local r = myRoot()
	local was = area
	area = if r then HolidayGames.areaAt(r.CFrame.Position) else nil
	local cam = Workspace.CurrentCamera
	local here = if cam then HolidayGames.areaAt(cam.CFrame.Position) else area
	if here ~= lastHere then
		HolidayLane.here(here == "lane" and attached.lane ~= nil)
		HolidayField.here(here == "field" and attached.field ~= nil)
		HolidayPole.here(here == "pole" and attached.pole ~= nil)
		lastHere = here
	end
	if area ~= lastArea then
		lastArea = area
		if area == "field" and was ~= "field" then
			caught = 0
		end
		HolidayPlay.goalChanged()
	end
	updateKey()
end

local function refresh()
	local id = Workspace:GetAttribute(HolidayGames.ATTRIBUTE)
	open = if type(id) == "string" then id else nil
	updateKey()
	HolidayPlay.goalChanged()
end

function HolidayPlay.start()
	Remotes.event("Holiday").OnClientEvent:Connect(function(m: any)
		local ok, err = pcall(function()
			onMessage(m)
		end)
		if not ok then
			warn("[Maison] A holiday message went astray: " .. tostring(err))
		end
	end)
	Workspace:GetAttributeChangedSignal(HolidayGames.ATTRIBUTE):Connect(refresh)
	for _, key in { "SleighState", "SleighT0", "SleighFlight" } do
		Workspace:GetAttributeChangedSignal(key):Connect(function()
			local s = attached.sleigh
			SleighRide.update(if s and s:IsA("Model") then s else nil)
		end)
	end
	local folder = Workspace:FindFirstChild("HolidayGames")
	if folder and folder:IsA("Folder") then
		watchRoot(folder)
	end
	Workspace.ChildAdded:Connect(function(c: Instance)
		if c:IsA("Folder") and c.Name == "HolidayGames" then
			watchRoot(c)
		end
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		local ok, err = pcall(function()
			step(dt)
		end)
		if not ok then
			warn("[Maison] The holiday games' drawing stumbled: " .. tostring(err))
		end
	end)
	refresh()
	-- Gifts waiting from an earlier visit.
	task.spawn(function()
		local s = ask({ op = "state" })
		if s.ok and type(s.gifts) == "number" then
			pending = s.gifts
			updateKey()
			HolidayPlay.goalChanged()
		end
	end)
end

-- The guest's gifts waiting changed (the gift screen opened some).
function HolidayPlay.setPending(n: number)
	pending = math.max(0, n)
	updateKey()
	HolidayPlay.goalChanged()
end

-- For tests.
function HolidayPlay.area(): string?
	return area
end
function HolidayPlay.pending(): number
	return pending
end

return HolidayPlay
