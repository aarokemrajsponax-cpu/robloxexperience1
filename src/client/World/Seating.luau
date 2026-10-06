--!strict
-- Sitting down, on this guest's screen: a seat's prompt ("Sit") walks them up to the nearest free
-- place on that piece, turns them to it and asks the server to sit them there (Seating on the
-- server checks it and makes the seat). Up again with a jump, or the Stand key that shows while
-- seated (or the jump button on a phone). The sorting tables keep their own chairs and prompts.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sound = require(script.Parent.Parent.Sound)
local Root = require(script.Parent.Parent.UI.Root)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)

local Seating = {}

local player = Players.LocalPlayer
local busy = false

local function ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("SitAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

-- The places to sit on a piece (its SitSpot parts), nearest first, leaving out taken ones.
local function freeSpots(model: Instance, from: Vector3): { BasePart }
	local out = {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d.Name == "SitSpot" then
			local who = d:GetAttribute("Taken")
			if who == nil or who == player.UserId then
				table.insert(out, d)
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.Position - from).Magnitude < (b.Position - from).Magnitude
	end)
	return out
end

-- Walks the guest to just in front of a seat (so sitting is a step, never a jump across the
-- room), giving up after a moment if something's in the way.
local function approach(humanoid: Humanoid, root: BasePart, spot: BasePart)
	local front = (spot.CFrame * CFrame.new(0, 0, -1.4)).Position
	local flat = Vector3.new(front.X, root.Position.Y, front.Z)
	if (flat - root.Position).Magnitude < 2.2 then
		return
	end
	humanoid:MoveTo(flat)
	local done = false
	local conn = humanoid.MoveToFinished:Connect(function()
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 1.6 do
		task.wait(0.05)
	end
	conn:Disconnect()
end

local function sit(prompt: ProximityPrompt)
	if busy then
		return
	end
	local anchor = prompt.Parent
	local model = anchor and anchor.Parent
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not model or not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local free = freeSpots(model, root.Position)
	local spot = free[1]
	if not spot then
		Toast.show("Taken", "Every seat there is taken just now.", 3)
		return
	end
	busy = true
	task.spawn(function()
		approach(humanoid, root, spot)
		-- A piece of this guest's own Suite (drawn on their screen) or one of the house's.
		local suiteSpot = model:GetAttribute("Spot")
		local request = if type(suiteSpot) == "string" and not spot:GetAttribute("SeatId")
			then { op = "sit", suite = suiteSpot, index = spot:GetAttribute("SitIndex") }
			else { op = "sit", seat = spot:GetAttribute("SeatId") }
		local r = ask(request)
		if type(r) == "table" and r.ok then
			Sound.play("chair", 0.35)
		elseif type(r) == "table" and type(r.why) == "string" then
			Toast.show("A seat", r.why, 3)
		end
		busy = false
	end)
end

function Seating.stand()
	task.spawn(ask, { op = "stand" })
end

-- Whether this guest sits in one of the house's seats (not a table's chair).
function Seating.seated(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat.Name == "GuestSeat"
end

-- The Stand up key at the foot of the screen, shown while seated in one of the house's seats.
local standKey: TextButton? = nil
local function showStand(on: boolean)
	if on and not standKey then
		local k = Theme.key(Root.hud, "Stand up", false, Seating.stand, 170)
		k.Name = "StandUp"
		k.AnchorPoint = Vector2.new(0.5, 1)
		k.Position = UDim2.new(0.5, 0, 1, -96)
		standKey = k
	elseif not on and standKey then
		standKey:Destroy()
		standKey = nil
	end
end

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Seated:Connect(function(active: boolean, seat: BasePart?)
		showStand(active and seat ~= nil and seat.Name == "GuestSeat")
	end)
	showStand(false)
end

function Seating.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "SeatPrompt" then
			sit(prompt)
		end
	end)
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

return Seating
