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
local HolidayMeter = require(script.Parent.Parent.UI.HolidayMeter)

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
local rehere = false -- a place arrived or went: each module's dressing is decided afresh
-- The Harvest Field's count (the server's): free catches left of how many, bought catches held,
-- the Hunter Pass. The North Pole's: how many you can carry, and load in a trip.
local field = { free = 5, of = 5, held = 0, unlimited = false, more = 10 }
local pole = { carry = 5, tripMost = 15 }
local prices: { [string]: number? } = {}

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
-- The count at the foot of the screen, and the offers
---------------------------------------------------------------------------------------------------
local TURKEY = rgb(240, 160, 60)
local GIFT = rgb(230, 70, 70)

local function updateMeter()
	if area == "field" then
		local sections: { HolidayMeter.Section } = {}
		if field.unlimited then
			table.insert(sections, { label = "Turkey Hunter Pass", value = "UNLIMITED", colour = TURKEY })
		elseif field.free > 0 or field.held == 0 then
			table.insert(sections, { label = "Free catches", value = string.format("%d / %d", field.free, field.of), pips = field.of, lit = field.free, colour = TURKEY })
		end
		if not field.unlimited and field.held > 0 then
			table.insert(sections, { label = "Bought catches", value = tostring(field.held), colour = rgb(255, 214, 110) })
		end
		table.insert(sections, { label = "Caught", value = tostring(caught), colour = TURKEY })
		HolidayMeter.show("🦃", TURKEY, sections)
	elseif area == "pole" then
		local carried = Players.LocalPlayer:GetAttribute("GiftsCarried")
		local held = if type(carried) == "number" then carried else 0
		HolidayMeter.show("🎁", GIFT, {
			{ label = "In your arms", value = string.format("%d / %d", held, pole.carry), pips = pole.carry, lit = held, colour = GIFT },
			{ label = "On the sleigh", value = string.format("%d / %d", loadedTrip, pole.tripMost), bar = loadedTrip / math.max(1, pole.tripMost), colour = rgb(255, 214, 110) },
		})
	else
		HolidayMeter.hide()
	end
end

local function turkeyOffer()
	HolidayMeter.offer(
		string.format("Your %d free catches are used", field.of),
		"Keep the chase going right now. Every turkey pays its Gilt as usual; the golden one too.",
		{
			{ label = string.format("+%d turkeys", field.more), price = prices.turkeyMore, press = function()
				HolidayMeter.buy(1)
			end },
			{ label = "Unlimited all holiday", price = prices.turkeyHunter, best = true, press = function()
				HolidayMeter.buy(2)
			end },
		},
		"Or come back in a quarter of an hour: your next visit has free catches again."
	)
end

local function sleighOffer()
	HolidayMeter.offer(
		"Your free sleigh ride is used",
		"Fly to the North Pole again and bring home up to 15 more gifts.",
		{
			{ label = "One more ride", price = prices.sleighRide, press = function()
				HolidayMeter.buy(3)
			end },
			{ label = "Every ride this Christmas", price = prices.sleighSeason, best = true, press = function()
				HolidayMeter.buy(4)
			end },
		},
		"One ride a Christmas is always free."
	)
end

local function takePrices(p: any)
	if type(p) == "table" then
		for k, v in p do
			if type(k) == "string" and type(v) == "number" then
				prices[k] = v
			end
		end
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
		if not r.ok and r.offer == "sleigh" then
			takePrices(r.prices)
			sleighOffer()
		elseif not r.ok and r.why then
			HolidayPlay.say("Santa's Sleigh", tostring(r.why))
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- What to do next (the objective card)
---------------------------------------------------------------------------------------------------
-- `rank` says where it stands among the card's other goals: "here" (in a game's own place: first
-- of all), "gifts" (gifts waiting to be opened: after a first visit's seat), "open" (a game is
-- open: after tonight's table).
export type Goal = { key: string, title: string, line: string, how: string?, rank: string }

local function sleighLine(): (string, string, string)
	local s = Workspace:GetAttribute("SleighState")
	if s == "boarding" then
		return "boarding", "The sleigh is boarding now, out front!", "The Sleigh key in the dock, or walk up to the sleigh at the kerb."
	elseif s == "toPole" or s == "pole" or s == "toHome" then
		return "away", "The sleigh is away at the North Pole. It'll be back.", "Board it when it lands at the kerb out front."
	end
	return "home", "Santa's sleigh is waiting at the kerb out front.", "The Sleigh key in the dock, or walk up to the sleigh."
end

function HolidayPlay.goal(): Goal?
	if area == "lane" then
		local n = 0
		for _ in HolidayLane.visited() do
			n += 1
		end
		return { key = "lane:" .. n, title = "Hallows Lane", line = string.format("Doors knocked at: %d of 9", n), how = "Walk up to a door and knock. Every host has a treat each round; all nine fills your bag.", rank = "here" }
	elseif area == "field" then
		return { key = "field:" .. caught, title = "The Harvest Field", line = if caught > 0 then string.format("Turkeys caught: %d", caught) else "The turkeys are loose!", how = "Run into a turkey, or press E when it's close. They tire after a sprint; the golden one is fastest (hold Shift to run).", rank = "here" }
	elseif area == "pole" then
		local carried = Players.LocalPlayer:GetAttribute("GiftsCarried")
		local held = if type(carried) == "number" then carried else 0
		return { key = "pole:" .. held .. ":" .. loadedTrip, title = "The North Pole", line = string.format("In your arms: %d / %d · On the sleigh: %d / %d", held, pole.carry, loadedTrip, pole.tripMost), how = string.format("Pick up gifts (%d at a time), then carry them to the gold ring behind the sleigh. It takes %d of yours a trip.", pole.carry, pole.tripMost), rank = "here" }
	end
	if pending > 0 then
		return { key = "gifts:" .. pending, title = "Your gifts", line = if pending == 1 then "A gift from the North Pole to open" else string.format("%d gifts from the North Pole to open", pending), how = "The Gifts key in the dock opens them.", rank = "gifts" }
	end
	local g = if open then HolidayGames.byId[open] else nil
	if not g then
		return nil
	end
	if g.id == "christmas" then
		local state, line, how = sleighLine()
		return { key = "open:christmas:" .. state, title = g.name, line = line, how = how, rank = "open" }
	elseif g.id == "easter" then
		local left = HolidayEggs.left()
		return { key = "open:easter:" .. left, title = g.name, line = if left == 1 then "One painted egg still hidden round the house." elseif left > 0 then string.format("%d painted eggs hidden round the house.", left) else "Fresh eggs are being hidden round the house.", how = "Look on shelves, in corners and under things in every room. One is golden.", rank = "open" }
	elseif g.id == "stPatrick" then
		return { key = "open:stPatrick", title = g.name, line = g.line, how = "Play any table: the luck is in every round.", rank = "open" }
	end
	return { key = "open:" .. g.id, title = g.name, line = g.line, how = "The " .. g.key .. " key in the dock takes you there.", rank = "open" }
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
	rehere = true
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
	elseif op == "turkeyMeter" or op == "turkeyOut" then
		field.free = if type(m.free) == "number" then m.free else field.free
		field.of = if type(m.of) == "number" then m.of else field.of
		field.held = if type(m.held) == "number" then m.held else field.held
		field.unlimited = m.unlimited == true
		field.more = if type(m.more) == "number" then m.more else field.more
		if type(m.caught) == "number" then
			caught = m.caught
		end
		takePrices(m.prices)
		updateMeter()
		if op == "turkeyOut" then
			turkeyOffer()
		end
	elseif op == "rides" then
		takePrices(m.prices)
		if m.offer == "sleigh" or (m.pass ~= true and m.free == 0 and m.held == 0 and m.ok == false) then
			sleighOffer()
		end
	elseif op == "bought" then
		HolidayMeter.closeOffer()
		local what = if m.key == "turkeyHunter" then "The Turkey Hunter Pass is yours: catch as many as you like." elseif m.key == "turkeyMore" then "More turkeys to catch. Go get them!" elseif m.key == "sleighSeason" then "Santa's Season Pass is yours: every ride is free this Christmas." else "Another ride on Santa's sleigh. All aboard!"
		HolidayPlay.say("Thank you", what)
	elseif op == "turkey" then
		-- Counted at once; the meter that follows from the server says the true number.
		caught += 1
		HolidayPop.show({ glyph = "🦃", title = if m.golden == true then "The golden turkey!" else "Caught one!", line = if m.golden == true then "The fastest bird alive, and you caught it." else "Gobble gobble. Off it goes, back to the barn.", gilt = m.gilt, gems = m.gems, colour = if m.golden == true then rgb(255, 214, 110) else rgb(236, 170, 80), big = m.golden == true })
		updateMeter()
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
		pole.carry = if type(m.carry) == "number" then m.carry else pole.carry
		pole.tripMost = if type(m.tripMost) == "number" then m.tripMost else pole.tripMost
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
			pole.carry = if type(m.carry) == "number" then m.carry else pole.carry
			pole.tripMost = if type(m.tripMost) == "number" then m.tripMost else pole.tripMost
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
	if here ~= lastHere or rehere then
		HolidayLane.here(here == "lane" and attached.lane ~= nil)
		HolidayField.here(here == "field" and attached.field ~= nil)
		HolidayPole.here(here == "pole" and attached.pole ~= nil)
		lastHere = here
		rehere = false
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
	Players.LocalPlayer:GetAttributeChangedSignal("GiftsCarried"):Connect(function()
		updateMeter()
		HolidayPlay.goalChanged()
	end)
	HolidayMeter.buy = function(n: number)
		task.spawn(function()
			local r = ask({ op = "buy", n = n })
			if not r.ok and r.why then
				HolidayPlay.say("Not just now", tostring(r.why))
			end
		end)
	end
	for _, key in { "SleighState", "SleighT0", "SleighFlight" } do
		Workspace:GetAttributeChangedSignal(key):Connect(function()
			local s = attached.sleigh
			SleighRide.update(if s and s:IsA("Model") then s else nil)
			if key == "SleighState" then
				HolidayPlay.goalChanged()
			end
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
		takePrices(s.prices)
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
