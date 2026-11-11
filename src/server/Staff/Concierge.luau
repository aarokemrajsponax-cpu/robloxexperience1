--!strict
-- The Concierge: stands at the lectern, greets guests, shows new guests round the house (the
-- tour: every destination, and how the house's money works), walks guests to a room or shows them
-- the way anywhere (gold arrows on the floor; taken there at once only if they ask), says what to do
-- next from what they've done, and answers questions from how the house really works. Dry, warm,
-- unhurried. Never runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Names = require(ReplicatedStorage.Shared.Names)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Dialogue = require(script.Parent.Parent.Dialogue)
local Private = require(script.Parent.Parent.Private)
local RemoteGuard = require(script.Parent.Parent.RemoteGuard)
local Rig = require(script.Parent.Rig)

local Concierge = {}

local V = Voice.Concierge
local staff: Rig.Staff? = nil
local leading: Player? = nil

-- Set by the table service so the Concierge knows when a guest has sat down.
Concierge.isSeated = function(_player: Player): boolean
	return false
end
-- Set by the client bridge: opens How to play on the guest's screen.
Concierge.openHowTo = function(_player: Player) end
-- Set by Main: the Maison Directory on the guest's screen (every game in the house, on a card).
Concierge.openDirectory = function(_player: Player) end
Concierge.inviteToLibrary = function(_player: Player) end
-- The room of a guest's usual table, or nil (set by Main from Memory).
Concierge.usualRoom = function(_player: Player): string?
	return nil
end
-- Set by the server: may this guest enter a room (the Midnight Room is earned)?
Concierge.canEnter = function(_player: Player, _room: string): boolean
	return true
end
-- Set by Main: a guest's saved record (for what to do next), the house's places, going straight
-- to one, and whether they've been shown this build's news (and noting it).
Concierge.dataOf = function(_player: Player): any?
	return nil
end
Concierge.placeAt = function(_id: string): (string?, Vector3?)
	return nil, nil
end
Concierge.travel = function(_player: Player, _id: string): (boolean, string?)
	return false, "Not just now."
end
Concierge.newsSeen = function(_player: Player): boolean
	return true
end
Concierge.markNews = function(_player: Player) end
-- The holiday on now, by the house's calendar (set by Main: shared/LiveCalendar): its name and line.
Concierge.season = function(): (string?, string?)
	return nil, nil
end
-- The house's settings the answers quote (set by Main: Config.data).
Concierge.settings = function(): { [string]: any }
	return {}
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Walks ahead of the guest to a room, pausing if they fall behind.
function Concierge.lead(player: Player, roomId: string)
	local s = staff
	if not s then
		return
	end
	local doorSpec = Layout.RoomDoors[roomId]
	local roomSpec = Layout.Rooms[roomId]
	if not doorSpec or not roomSpec then
		return
	end
	if not Concierge.canEnter(player, roomId) then
		Dialogue.say(player, V.speaker, V.midnightLocked, nil, nil, 3.5)
		return
	end
	if s.busy then
		Dialogue.say(player, V.speaker, V.lost)
		return
	end
	s.busy = true
	leading = player
	Dialogue.say(player, V.speaker, V.thisWay, nil, nil, 2.5)
	local waypoint = doorSpec.centre + doorSpec.facing * 4 -- just inside the Foyer
	local arrival = roomSpec.arrival

	local function stop(): boolean
		return player.Parent ~= Players or Concierge.isSeated(player) or characterRoot(player) == nil
	end
	local function behind(): boolean
		local root = characterRoot(player)
		if not root then
			return false
		end
		local far = (root.Position - s.root.Position).Magnitude > 14
		if far then
			Rig.face(s, root.Position)
		end
		return far
	end

	task.spawn(function()
		local reached = true
		for _, point in doorSpec.approach do
			if reached then
				reached = Rig.walkTo(s, point, behind, stop)
			end
		end
		if reached then
			reached = Rig.walkTo(s, waypoint, behind, stop)
		end
		if reached then
			reached = Rig.walkTo(s, arrival, behind, stop)
		end
		if reached and not stop() then
			local root = characterRoot(player)
			if root then
				Rig.face(s, root.Position)
			end
			Dialogue.say(player, V.speaker, V.arrivedIn[roomId] or V.arrived, nil, nil, 3)
			task.wait(2.5)
		end
		leading = nil
		Rig.walkTo(s, waypoint)
		for i = #doorSpec.approach, 1, -1 do
			Rig.walkTo(s, doorSpec.approach[i])
		end
		Rig.goHome(s)
		s.busy = false
	end)
end

-- A Private Evening's host arranges the Ballroom: the pace, then the empty chairs.
local function setEvening(player: Player)
	local P = Voice.Private
	local current = Private.get()
	local paces = {}
	for _, id in { "gentle", "house", "brisk" } do
		table.insert(paces, { id = id, text = (if current.pace == id then "· " else "") .. (P.paces :: any)[id] })
	end
	Dialogue.say(player, V.speaker, P.setEvening .. "  " .. P.pace .. ":", paces, function(pace)
		Private.set(player, "pace", pace)
		local chairs = {}
		for _, id in { "fill", "none" } do
			table.insert(chairs, { id = id, text = (if Private.get().standIns == id then "· " else "") .. (P.standInChoices :: any)[id] })
		end
		Dialogue.say(player, V.speaker, P.standIns .. ":", chairs, function(standIns)
			Private.set(player, "standIns", standIns)
			Dialogue.say(player, V.speaker, P.done, nil, nil, 2)
		end)
	end)
end

-- The tour: the Concierge walks the guest round the whole house. It runs on the guest's own
-- screen (client World/Tour, a guide only they see), so any number of guests can take it at once
-- and the Concierge stays at the lectern for everyone else. The server only starts it and knows
-- who's on it (nobody on the tour is offered the walk to the Salon).
local tourEvent = Remotes.event("Tour")
local touring: { [Player]: number } = {}

-- Set by Main: whether a guest is still new to the house (no tour yet, fewer than two rounds),
-- and to note that they've had the tour.
Concierge.needsTour = function(_player: Player): boolean
	return false
end
Concierge.toured = function(_player: Player) end

function Concierge.tour(player: Player)
	Concierge.markNews(player)
	touring[player] = os.clock()
	tourEvent:FireClient(player, { op = "start" })
end

function Concierge.isTouring(player: Player): boolean
	local since = touring[player]
	return since ~= nil and os.clock() - since < 900
end

-- The places a guest may ask for (rooms first: the Concierge can walk them there himself).
type Place = { id: string, text: string, room: boolean? }
local PLACES: { Place } = {
	{ id = "velvet", text = "Steal a Luxe  ·  the Luxe Lounge", room = true },
	{ id = "obsidian", text = "The Maison Basement  ·  the Basement Stair", room = true },
	{ id = "midnight", text = "The Executive Suite  ·  the Anteroom", room = true },
	{ id = "salon", text = "The Salon", room = true },
	{ id = "vault", text = "The Vault" },
	{ id = "boutique", text = "The Boutique" },
	{ id = "library", text = "The Library" },
	{ id = "ballroom", text = "The Ballroom  ·  the Grand Ballroom" },
	{ id = "terrace", text = "The Terrace  ·  the Jet Lounge" },
	{ id = "suite", text = "Your Suite" },
	{ id = "grandPrix", text = "The Grand Prix" },
}
Concierge.PLACES = PLACES

local wayEvent = Remotes.event("Travel")

-- Shows a guest the way to a place: walking, with gold arrows on their own floor.
function Concierge.showWay(player: Player, id: string): boolean
	local name, at = Concierge.placeAt(id)
	if not name or not at then
		return false
	end
	wayEvent:FireClient(player, { op = "way", place = id, name = name, at = at })
	return true
end

-- Where to go next, from what the guest has done (their record, as the server keeps it).
function Concierge.recommend(player: Player): (string, string?)
	local R = V.recommend
	local data = Concierge.dataOf(player)
	if not data then
		return R.luxe, "velvet"
	end
	local pages = if type(data.attractions) == "table" then data.attractions else {}
	local luxe = if type(pages.luxe) == "table" then pages.luxe else {}
	local basement = if type(pages.basement) == "table" then pages.basement else {}
	local executive = if type(pages.executive) == "table" then pages.executive else {}
	local settings = Concierge.settings()
	local luxeCfg = (settings.Attractions or {}).luxe or {}
	if (tonumber(executive.invites) or 0) > 0 then
		return R.executive, "midnight"
	end
	if (tonumber(luxe.hauls) or 0) == 0 then
		return R.luxe, "velvet"
	end
	local bagLevel = tonumber(luxe.bag) or 1
	local nextBag = luxeCfg.bagPrice and luxeCfg.bagPrice[bagLevel + 1]
	if nextBag and (tonumber(data.gilt) or 0) >= nextBag then
		return R.upgrade, "velvet"
	end
	if (tonumber(basement.clears) or 0) == 0 then
		return R.basement, "obsidian"
	end
	-- (Never been in the Grand Ballroom: the house's fun, with friends.)
	if type(pages.gala) ~= "table" then
		return R.gala, "ballroom"
	end
	-- (A Tycoon without the Island Key: the jet waits.)
	local island = if type(pages.island) == "table" then pages.island else {}
	local reached = if type(data.empire) == "table" then tonumber(data.empire.rank) or 1 else 1
	if island.key ~= true and reached >= (tonumber(((settings.Attractions or {}).island or {}).keyRank) or 6) then
		return R.island, "terrace"
	end
	local ex = (settings.Attractions or {}).executive or {}
	local function commas(n: number): string
		local text = tostring(math.floor(n))
		local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return if out:sub(1, 1) == "," then out:sub(2) else out
	end
	local line = R.quartermaster
		:gsub("{inviteHaul}", commas(tonumber(ex.inviteHaul) or 8000))
		:gsub("{invitePrice}", commas(tonumber(ex.invitePrice) or 25000))
	return line, "midnight"
end

-- An answer, with the house's own numbers in it.
function Concierge.answer(id: string): string?
	local settings = Concierge.settings()
	local a = settings.Attractions or {}
	local luxe, basement, executive, island = a.luxe or {}, a.basement or {}, a.executive or {}, a.island or {}
	local function commas(n: number): string
		local text = tostring(math.floor(n))
		local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return if out:sub(1, 1) == "," then out:sub(2) else out
	end
	for _, q in V.questions do
		if q.id == id then
			return (
				q.a
					:gsub("{inviteHaul}", commas(tonumber(executive.inviteHaul) or 8000))
					:gsub("{invitePrice}", commas(tonumber(executive.invitePrice) or 25000))
					:gsub("{stride}", tostring(math.floor((tonumber(luxe.stridePerLevel) or 0.035) * 1000 + 0.5) / 10))
					:gsub("{skipGems}", tostring(tonumber(basement.skipGems) or 25))
					:gsub("{skipStep}", tostring(tonumber(basement.skipGemsStep) or 15))
					:gsub("{islandGilt}", commas(tonumber(island.keyGilt) or 25000))
					:gsub("{islandGems}", tostring(tonumber(island.keyGems) or 250))
					:gsub("{galaGilt}", commas(tonumber((a.gala or {}).dailyGilt) or 2500))
			)
		end
	end
	return nil
end

-- Somewhere to go: walked by the Concierge (a room, when he's free), shown the way with arrows, or
-- taken there at once.
local function findPlace(player: Player, id: string)
	local name = nil
	local isRoom = false
	for _, p in PLACES do
		if p.id == id then
			name = p.text
			isRoom = p.room == true
		end
	end
	if not name then
		return
	end
	Dialogue.say(player, V.speaker, (V.find.how:gsub("{place}", name)), {
		{ id = "walk", text = V.choices.walk },
		{ id = "now", text = V.choices.now },
	}, function(how)
		if player.Parent ~= Players then
			return
		end
		if how == "now" then
			local ok, why = Concierge.travel(player, id)
			if not ok then
				Dialogue.say(player, V.speaker, why or "Not just now.", nil, nil, 2.5)
			else
				Dialogue.close(player)
			end
			return
		end
		local s = staff
		if isRoom and s and not s.busy then
			Concierge.lead(player, id)
		elseif Concierge.showWay(player, id) then
			Dialogue.say(player, V.speaker, V.find.showing, nil, nil, 3)
		end
	end)
end
Concierge.findPlace = findPlace

local function menu(player: Player)
	local choices = {
		{ id = "next", text = V.choices.next },
		{ id = "games", text = V.choices.games },
		{ id = "find", text = V.choices.find },
		{ id = "ask", text = V.choices.ask },
		{ id = "tour", text = V.choices.tour },
		{ id = "how", text = V.choices.how },
		{ id = "bye", text = V.choices.bye },
	}
	if Private.isHost(player) then
		table.insert(choices, 4, { id = "evening", text = V.choices.setEvening })
	end
	-- A regular is offered their usual table.
	local usual = Concierge.usualRoom(player)
	if usual then
		table.insert(choices, 1, { id = "usual", text = V.memory.usual })
	end
	Dialogue.say(player, V.speaker, V.returning:gsub("{name}", Names.of(player)), choices, function(choice)
		if choice == "usual" and usual then
			Concierge.lead(player, usual)
		elseif choice == "next" then
			local line, place = Concierge.recommend(player)
			Dialogue.say(player, V.speaker, line, if place then {
				{ id = "go", text = V.choices.walk },
				{ id = "now", text = V.choices.now },
				{ id = "fine", text = V.choices.thanks },
			} else nil, if place then function(next: string)
				if next == "go" then
					local s = staff
					if s and not s.busy then
						Concierge.lead(player, place)
					else
						Concierge.showWay(player, place)
						Dialogue.say(player, V.speaker, V.find.showing, nil, nil, 3)
					end
				elseif next == "now" then
					local ok, why = Concierge.travel(player, place)
					if not ok then
						Dialogue.say(player, V.speaker, why or "Not just now.", nil, nil, 2.5)
					else
						Dialogue.close(player)
					end
				end
			end else nil, if place then nil else 4)
		elseif choice == "find" then
			local list = {}
			for _, p in PLACES do
				table.insert(list, { id = p.id, text = p.text })
			end
			Dialogue.say(player, V.speaker, V.find.which, list, function(id: string)
				findPlace(player, id)
			end)
		elseif choice == "ask" then
			local list = {}
			for _, q in V.questions do
				table.insert(list, { id = q.id, text = q.q })
			end
			Dialogue.say(player, V.speaker, V.whichQuestion, list, function(id: string)
				local a = Concierge.answer(id)
				if a then
					Dialogue.say(player, V.speaker, a, {
						{ id = "more", text = V.choices.ask },
						{ id = "fine", text = V.choices.thanks },
					}, function(next: string)
						if next == "more" then
							menu(player)
						end
					end)
				end
			end)
		elseif choice == "tour" then
			Concierge.tour(player)
		elseif choice == "evening" then
			setEvening(player)
		elseif choice == "room" then
			local rooms = {
				{ id = "salon", text = "The Salon" },
				{ id = "velvet", text = "The Velvet Room" },
				{ id = "obsidian", text = "The Obsidian Room" },
			}
			if Concierge.canEnter(player, "midnight") then
				table.insert(rooms, { id = "midnight", text = "The Midnight Room" })
			end
			Dialogue.say(player, V.speaker, V.whichRoom, rooms, function(roomId)
				Concierge.lead(player, roomId)
			end)
		elseif choice == "library" then
			Dialogue.say(player, V.speaker, V.libraryWay, {
				{ id = "invite", text = V.choices.inviteFriend },
				{ id = "fine", text = V.choices.thanks },
			}, function(next)
				if next == "invite" then
					Dialogue.close(player)
					Concierge.inviteToLibrary(player)
				end
			end)
		elseif choice == "ballroom" then
			Dialogue.say(player, V.speaker, V.ballroomWay, nil, nil, 3.5)
		elseif choice == "how" then
			Dialogue.close(player)
			Concierge.openHowTo(player)
		elseif choice == "games" then
			Dialogue.close(player)
			Concierge.openDirectory(player)
		else
			Dialogue.say(player, V.speaker, V.goodNight, nil, nil, 2)
		end
	end)
end

-- The tour, offered first: the tour, straight to a table, or left to look around.
local function offerTour(player: Player)
	Dialogue.say(player, V.speaker, V.tourOffer, {
		{ id = "tour", text = V.tourYes },
		{ id = "table", text = V.tourSkip },
		{ id = "later", text = V.tourLater },
	}, function(choice)
		if player.Parent ~= Players or Concierge.isSeated(player) then
			return
		end
		if choice == "tour" then
			Concierge.tour(player)
		elseif choice == "table" then
			Concierge.lead(player, "salon")
		else
			Dialogue.say(player, V.speaker, V.tourLaterLine, nil, nil, 3)
		end
	end)
end

-- Called once per visit when a guest first steps into the Foyer. A guest still new to the house
-- (a first evening, or no tour yet and fewer than two rounds) is offered the tour; returning
-- guests hear the one thing that matters tonight.
function Concierge.greet(player: Player, firstVisit: boolean, nightlyPending: boolean?, remembered: string?)
	local ok, new = pcall(Concierge.needsTour, player)
	if firstVisit or (ok and new == true) then
		-- (A new guest's tour shows them everything new too.)
		Concierge.markNews(player)
		offerTour(player)
	elseif not Concierge.newsSeen(player) then
		-- A guest from before the house changed: shown what's new, once, if they'd like.
		Concierge.markNews(player)
		Dialogue.say(player, V.speaker, (V.returning:gsub("{name}", Names.of(player))) .. "  " .. V.newsOffer, {
			{ id = "tour", text = V.newsYes },
			{ id = "later", text = V.newsLater },
		}, function(choice: string)
			if player.Parent ~= Players or Concierge.isSeated(player) then
				return
			end
			if choice == "tour" then
				Concierge.tour(player)
			else
				Dialogue.say(player, V.speaker, V.newsLaterLine, nil, nil, 3)
			end
		end)
	else
		Dialogue.say(player, V.speaker, (V.returning:gsub("{name}", Names.of(player))), nil, nil, 3.5)
		-- One thing the house remembers (last time, a milestone, being missed).
		local extra = 0
		if remembered then
			extra = 3.8
			task.delay(3.8, function()
				if player.Parent == Players and not Concierge.isSeated(player) then
					Dialogue.say(player, V.speaker, remembered, nil, nil, 4)
				end
			end)
		end
		-- The holiday that's on, if one is.
		local holiday, holidayLine = Concierge.season()
		if holiday then
			extra += 3.8
			task.delay(extra, function()
				if player.Parent == Players and not Concierge.isSeated(player) then
					Dialogue.say(player, V.speaker, string.format("%s at the Maison. %s", holiday, holidayLine or ""), nil, nil, 4)
				end
			end)
		end
		if nightlyPending then
			task.delay(3.8 + extra, function()
				if player.Parent == Players and not Concierge.isSeated(player) then
					Dialogue.say(player, V.speaker, V.tonightLaid, nil, nil, 3.5)
				end
			end)
		end
	end
end

-- A new guest standing lost in the Foyer: the Concierge drifts over and offers the walk.
function Concierge.offerHelp(player: Player)
	local s = staff
	local root = characterRoot(player)
	if not s or s.busy or not root then
		return
	end
	s.busy = true
	task.spawn(function()
		local toward = root.Position - s.root.Position
		local flat = Vector3.new(toward.X, 0, toward.Z)
		if flat.Magnitude > 6 then
			local goal = s.root.Position + flat.Unit * (flat.Magnitude - 4)
			Rig.walkTo(s, Vector3.new(goal.X, s.home.Position.Y, goal.Z), nil, function()
				return player.Parent ~= Players or Concierge.isSeated(player)
			end)
		end
		Rig.face(s, root.Position)
		s.busy = false
		Dialogue.say(player, V.speaker, V.lost, {
			{ id = "yes", text = V.choices.takeMe },
			{ id = "no", text = V.choices.fine },
		}, function(choice)
			if choice == "yes" then
				Concierge.lead(player, "salon")
			else
				Dialogue.say(player, V.speaker, V.goodNight, nil, nil, 1.5)
				if staff and not staff.busy then
					Rig.goHome(staff)
				end
			end
		end)
		task.delay(12, function()
			if staff and not staff.busy and leading == nil then
				Rig.goHome(staff)
			end
		end)
	end)
end

Concierge.menu = function(player: Player)
	menu(player)
end

function Concierge.line(player: Player, line: string, hold: number?)
	Dialogue.say(player, V.speaker, line, nil, nil, hold)
end

function Concierge.isLeading(player: Player): boolean
	return leading == player
end

function Concierge.spawn(parent: Instance)
	RemoteGuard.event(tourEvent, "tour", function(player: Player, message: unknown)
		if type(message) ~= "table" then
			return
		end
		local op = (message :: any).op
		if op == "start" then
			touring[player] = os.clock()
		elseif op == "end" then
			-- (A tour that ran its course, or most of it: they've been shown the house.)
			local since = touring[player]
			touring[player] = nil
			if since and os.clock() - since > 10 then
				pcall(Concierge.toured, player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		touring[player] = nil
	end)
	local s = Rig.build("Concierge", Rig.look("Concierge"), Layout.Foyer.conciergeHome, parent)
	staff = s
	s.model:SetAttribute("Staff", "Concierge")
	local head = s.model:FindFirstChild("Head")
	local anchor: BasePart = if head and head:IsA("BasePart") then head else s.root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpeakPrompt"
	prompt.ActionText = "Speak"
	prompt.ObjectText = "The Concierge"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player: Player)
		if s.busy and leading ~= player then
			Dialogue.say(player, V.speaker, V.waiting, nil, nil, 2.5)
			return
		end
		Rig.face(s, (characterRoot(player) or s.root).Position)
		-- (A guest still new to the house is offered the tour first, not the whole menu.)
		local ok, new = pcall(Concierge.needsTour, player)
		if ok and new == true then
			offerTour(player)
		else
			menu(player)
		end
		task.delay(6, function()
			if not s.busy then
				Rig.face(s, s.home.Position + s.home.LookVector * 10)
			end
		end)
	end)
	return s
end

return Concierge
