--!strict
-- The Concierge: stands at the lectern, greets guests, shows new guests round the house (the
-- tour), walks guests to a room, and answers when spoken to. Dry, warm, unhurried. Never runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
Concierge.inviteToLibrary = function(_player: Player) end
-- The room of a guest's usual table, or nil (set by Main from Memory).
Concierge.usualRoom = function(_player: Player): string?
	return nil
end
-- Set by the server: may this guest enter a room (the Midnight Room is earned)?
Concierge.canEnter = function(_player: Player, _room: string): boolean
	return true
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

function Concierge.tour(player: Player)
	touring[player] = os.clock()
	tourEvent:FireClient(player, { op = "start" })
end

function Concierge.isTouring(player: Player): boolean
	local since = touring[player]
	return since ~= nil and os.clock() - since < 900
end

local function menu(player: Player)
	local choices = {
		{ id = "room", text = V.choices.takeMe },
		{ id = "tour", text = V.choices.tour },
		{ id = "library", text = V.choices.library },
		{ id = "ballroom", text = V.choices.ballroom },
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
	Dialogue.say(player, V.speaker, V.returning:gsub("{name}", player.DisplayName), choices, function(choice)
		if choice == "usual" and usual then
			Concierge.lead(player, usual)
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
		else
			Dialogue.say(player, V.speaker, V.goodNight, nil, nil, 2)
		end
	end)
end

-- Called once per visit when a guest first steps into the Foyer. Returning guests hear the one
-- thing that matters tonight.
function Concierge.greet(player: Player, firstVisit: boolean, nightlyPending: boolean?, remembered: string?)
	if firstVisit then
		-- A first evening: the tour, straight to a table, or left to look around.
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
	else
		Dialogue.say(player, V.speaker, (V.returning:gsub("{name}", player.DisplayName)), nil, nil, 3.5)
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
			touring[player] = nil
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
		menu(player)
		task.delay(6, function()
			if not s.busy then
				Rig.face(s, s.home.Position + s.home.LookVector * 10)
			end
		end)
	end)
	return s
end

return Concierge
