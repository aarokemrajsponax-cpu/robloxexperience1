--!strict
-- The Vault's door and the lift (built by World/Passages). The door swings open whenever a guest
-- is near the doorway, either side, and shuts once nobody is: the Vault keeps to itself. The
-- lift: a guest presses the bell-push, the doors part, their screen dims for the ride (the
-- client's LiftView) and they step out of the doors on the other floor. Everything here is the
-- server's: where a guest may ride from (they must be standing at the push) and where they arrive.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local VaultAccess = {}

-- Whether a guest is busy at a table (set by Main): nobody rides the lift from a seat.
VaultAccess.isSeated = function(_player: Player): boolean
	return false
end

local D = Layout.VaultDoor
local LIFT = Layout.Lift

---------------------------------------------------------------------------------------------------
-- The door
---------------------------------------------------------------------------------------------------
local doorOpen = false
local swing: NumberValue? = nil

local function placeDoor(angle: number)
	for _, p in CollectionService:GetTagged("VaultDoorPart") do
		local from = p:GetAttribute("FromHinge")
		if p:IsA("BasePart") and typeof(from) == "CFrame" then
			-- Turning about the hinge's line: into the Vault (+Z) as it opens.
			p.CFrame = CFrame.new(D.hinge) * CFrame.Angles(0, -angle, 0) * from
		end
	end
end

local function sound(name: string)
	for _, p in CollectionService:GetTagged("VaultDoorPart") do
		local s = p:FindFirstChild(name)
		if s and s:IsA("Sound") then
			s:Play()
			if name == "Open" then
				task.delay(D.seconds + 0.2, function()
					s:Stop()
				end)
			end
			return
		end
	end
end

function VaultAccess.setDoor(open: boolean)
	if open == doorOpen then
		return
	end
	doorOpen = open
	local v = swing
	if not v then
		return
	end
	sound(if open then "Open" else "Shut")
	TweenService:Create(v, TweenInfo.new(D.seconds, Enum.EasingStyle.Quad, if open then Enum.EasingDirection.Out else Enum.EasingDirection.InOut), { Value = if open then math.rad(95) else 0 }):Play()
end

function VaultAccess.doorIsOpen(): boolean
	return doorOpen
end

-- Whether anyone stands within reach of the doorway (on the Foyer side or the Vault's).
local function someoneNear(): boolean
	local doorway = Layout.Vault.door
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local d = root.Position - doorway
			if Vector3.new(d.X, 0, d.Z).Magnitude <= D.reach and math.abs(d.Y) < 8 then
				return true
			end
		end
	end
	-- The staff come and go too (the Archivist keeps the Vault).
	return false
end

---------------------------------------------------------------------------------------------------
-- The lift
---------------------------------------------------------------------------------------------------
local riding: { [Player]: boolean } = {}

local function leaves(id: string): { BasePart }
	local out = {}
	for _, p in CollectionService:GetTagged("LiftLeaf") do
		if p:IsA("BasePart") and p:GetAttribute("Landing") == id then
			table.insert(out, p)
		end
	end
	return out
end

local function pushOf(id: string): BasePart?
	for _, p in CollectionService:GetTagged("LiftCall") do
		if p:IsA("BasePart") and p:GetAttribute("From") == id then
			return p
		end
	end
	return nil
end

local function play(id: string, name: string)
	local push = pushOf(id)
	local s = push and push:FindFirstChild(name)
	if s and s:IsA("Sound") then
		s:Play()
	end
end

-- Opens (or closes) one landing's doors.
function VaultAccess.liftDoors(id: string, open: boolean)
	play(id, "Doors")
	for _, p in leaves(id) do
		local closed = p:GetAttribute("Closed")
		local slide = p:GetAttribute("Slide")
		if typeof(closed) == "CFrame" and typeof(slide) == "Vector3" then
			local goal = if open then closed + slide else closed
			TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal }):Play()
		end
	end
end

-- Where a guest steps out on a floor: just outside its doors, facing away from them.
function VaultAccess.arrival(id: string): CFrame
	local at = (LIFT :: any)[id]
	local base: Vector3 = at.centre
	local out: Vector3 = at.out
	local spot = base + out * 3 + Vector3.new(0, 3, 0)
	return CFrame.lookAt(spot, spot + out)
end

-- A guest rides from `from` to the other floor. Returns whether they went.
function VaultAccess.ride(player: Player, from: string): boolean
	local to = if from == "suite" then "vault" elseif from == "vault" then "suite" else nil
	if not to or riding[player] or VaultAccess.isSeated(player) then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return false
	end
	-- They must be at this landing (the prompt's reach, and a little more).
	local base: Vector3 = (LIFT :: any)[from].centre
	if (root.Position - base).Magnitude > 14 then
		return false
	end
	riding[player] = true
	task.spawn(function()
		play(from, "Bell")
		VaultAccess.liftDoors(from, true)
		Remotes.event("Guest"):FireClient(player, { op = "lift", to = to, seconds = LIFT.ride, name = (LIFT :: any)[to].name })
		task.wait(0.9)
		-- Behind the dimmed screen: down (or up) to the other floor.
		local c = player.Character
		if c and c.Parent and player.Parent == Players then
			c:PivotTo(VaultAccess.arrival(to))
		end
		task.wait(0.35)
		VaultAccess.liftDoors(from, false)
		task.wait(math.max(0, LIFT.ride - 1.6))
		play(to, "Bell")
		VaultAccess.liftDoors(to, true)
		task.wait(2.2)
		VaultAccess.liftDoors(to, false)
		riding[player] = nil
	end)
	return true
end

function VaultAccess.start()
	-- The door.
	local v = Instance.new("NumberValue")
	v.Name = "VaultDoorSwing"
	v.Value = 0
	v.Changed:Connect(function(angle: number)
		placeDoor(angle)
	end)
	swing = v
	task.spawn(function()
		local lastNear = 0
		while true do
			if someoneNear() then
				lastNear = os.clock()
				VaultAccess.setDoor(true)
			elseif doorOpen and os.clock() - lastNear > 1.5 then
				VaultAccess.setDoor(false)
			end
			task.wait(0.2)
		end
	end)
	-- The lift.
	local function wire(push: Instance)
		local prompt = push:FindFirstChildWhichIsA("ProximityPrompt")
		local from = push:GetAttribute("From")
		if prompt and type(from) == "string" then
			prompt.Triggered:Connect(function(player: Player)
				VaultAccess.ride(player, from)
			end)
		end
	end
	for _, push in CollectionService:GetTagged("LiftCall") do
		wire(push)
	end
	CollectionService:GetInstanceAddedSignal("LiftCall"):Connect(wire)
	Players.PlayerRemoving:Connect(function(player: Player)
		riding[player] = nil
	end)
end

return VaultAccess
