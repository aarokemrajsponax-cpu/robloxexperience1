--!strict
-- The Concierge's way to a place (Travel event, op "way"): on this guest's screen only, a line of
-- gold arrows along the floor from where they stand to the place (a path round the walls and up
-- the stairs, worked out here; a straight line if no path can be found), a beam of light over the
-- place itself, and a pill at the foot of the screen with where they're going and how far, and a
-- key to stop. Walking, always: nobody is moved. It ends when they arrive, stop it, or after a few
-- minutes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Parent.UI.Root)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)

local Wayfinder = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 204, 90)
local ARRIVE = 12 -- studs: there
local SPACING = 6 -- studs between arrows
local MOST = 40 -- arrows at most
local LIFETIME = 240 -- seconds before it goes by itself

type Way = { name: string, at: Vector3, started: number, folder: Folder, pill: Frame, label: TextLabel, conn: RBXScriptConnection?, repathAt: number }
local current: Way? = nil

local function rootOf(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The points to walk through, from `from` to `to` (a path if one can be found).
function Wayfinder.route(from: Vector3, to: Vector3): { Vector3 }
	local ok, points = pcall(function(): { Vector3 }?
		-- (Asked for here: a screen without the service simply walks the straight line.)
		local path = game:GetService("PathfindingService"):CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		path:ComputeAsync(from, to)
		if path.Status ~= Enum.PathStatus.Success then
			return nil
		end
		local out: { Vector3 } = {}
		for _, w in path:GetWaypoints() do
			table.insert(out, w.Position)
		end
		return out
	end)
	if ok and type(points) == "table" and #points >= 2 then
		return points
	end
	return { from, to }
end

local function clearArrows(folder: Folder)
	for _, child in folder:GetChildren() do
		child:Destroy()
	end
end

-- Lays the arrows along the route, every few studs, each pointing on.
local function lay(way: Way, points: { Vector3 })
	clearArrows(way.folder)
	local laid = 0
	local carry = SPACING / 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local leg = b - a
		local length = leg.Magnitude
		if length < 1e-3 then
			continue
		end
		local d = carry
		while d < length and laid < MOST do
			local p = a + leg.Unit * d
			local flatAhead = Vector3.new(leg.X, 0, leg.Z)
			local ahead = if flatAhead.Magnitude > 1e-3 then flatAhead.Unit else Vector3.new(0, 0, 1)
			local arrow = Instance.new("Part")
			arrow.Name = "WayArrow"
			arrow.Anchored = true
			arrow.CanCollide = false
			arrow.CanQuery = false
			arrow.CanTouch = false
			arrow.CastShadow = false
			arrow.Material = Enum.Material.Neon
			arrow.Color = GOLD
			arrow.Transparency = 0.25
			arrow.Size = Vector3.new(1.6, 0.08, 1.1)
			arrow.CFrame = CFrame.lookAt(p - Vector3.new(0, 2.8, 0), p - Vector3.new(0, 2.8, 0) + ahead)
			arrow.Parent = way.folder
			laid += 1
			d += SPACING
		end
		carry = d - length
	end
	-- The beam over the place.
	local beam = Instance.new("Part")
	beam.Name = "WayBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = GOLD
	beam.Transparency = 0.55
	beam.Size = Vector3.new(0.8, 40, 0.8)
	beam.CFrame = CFrame.new(way.at + Vector3.new(0, 20, 0))
	beam.Parent = way.folder
end

function Wayfinder.stop(arrived: boolean?)
	local way = current
	if not way then
		return
	end
	current = nil
	if way.conn then
		way.conn:Disconnect()
	end
	way.folder:Destroy()
	way.pill:Destroy()
	Root.setBottom("Wayfinder", nil)
	if arrived then
		Toast.show("You've arrived", way.name, 3)
	end
end

function Wayfinder.go(name: string, at: Vector3)
	Wayfinder.stop()
	local root = rootOf()
	if not root then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Wayfinder"
	folder.Parent = Workspace
	-- The pill at the foot of the screen.
	local pill = Instance.new("Frame")
	pill.Name = "WayPill"
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Position = UDim2.new(0.5, 0, 1, -(66 + Root.bottomClear()))
	pill.Size = UDim2.fromOffset(0, 40)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.fromRGB(16, 13, 9)
	pill.BackgroundTransparency = 0.08
	pill.Parent = Root.hud
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 20)
	corner.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = GOLD
	edge.Transparency = 0.3
	edge.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = pill
	Theme.list(pill, 10, true).VerticalAlignment = Enum.VerticalAlignment.Center
	local label = Theme.text(pill, "", 13, "bodyBold", { Name = "Where", LayoutOrder = 1, TextColor3 = GOLD, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), TextWrapped = false })
	local stopKey = Theme.key(pill, "Stop", false, function()
		Wayfinder.stop()
	end, 80)
	stopKey.LayoutOrder = 2
	Root.setBottom("Wayfinder", 66 + 40)
	local way: Way = { name = name, at = at, started = os.clock(), folder = folder, pill = pill, label = label, conn = nil, repathAt = 0 }
	current = way
	lay(way, Wayfinder.route(root.CFrame.Position, at))
	way.repathAt = os.clock() + 4
	local function tick()
		if current ~= way then
			return
		end
		local r = rootOf()
		if not r then
			return
		end
		local here = r.CFrame.Position
		local far = (Vector3.new(at.X, 0, at.Z) - Vector3.new(here.X, 0, here.Z)).Magnitude
		label.Text = string.format("To %s  ·  %d studs", name, math.floor(far + 0.5))
		if far <= ARRIVE and math.abs(at.Y - here.Y) < 10 then
			Wayfinder.stop(true)
			return
		end
		if os.clock() - way.started > LIFETIME then
			Wayfinder.stop()
			return
		end
		-- (Strayed from the arrows: a new route from here, every few seconds.)
		if os.clock() >= way.repathAt then
			way.repathAt = os.clock() + 4
			lay(way, Wayfinder.route(here, at))
		end
	end
	tick()
	local acc = 0
	way.conn = RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			tick()
		end
	end)
end

function Wayfinder.showing(): boolean
	return current ~= nil
end

function Wayfinder.start()
	Remotes.event("Travel").OnClientEvent:Connect(function(m: any)
		if type(m) == "table" and m.op == "way" and type(m.name) == "string" and typeof(m.at) == "Vector3" then
			Wayfinder.go(m.name, m.at)
		end
	end)
	player.CharacterAdded:Connect(function()
		Wayfinder.stop()
	end)
end

return Wayfinder
