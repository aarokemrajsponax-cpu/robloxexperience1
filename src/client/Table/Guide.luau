--!strict
-- The guide light: a thread of gold light from the piece in your hand to its case. Calm, never
-- flashy. Delayed in Obsidian, absent in Midnight. The settings can make it harder, never easier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Duel = require(ReplicatedStorage.Shared.Duel)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local State = require(script.Parent.Parent.State)

local Guide = {}

local anchor: Part? = nil
local target: Part? = nil
local beam: Beam? = nil
local sparkle: ParticleEmitter? = nil
local serial = 0

local function localFolder(): Instance
	local f = Workspace:FindFirstChild("MaisonLocal")
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = "MaisonLocal"
		nf.Parent = Workspace
		f = nf
	end
	return f :: Instance
end

local function point(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = localFolder()
	local a = Instance.new("Attachment")
	a.Parent = p
	return p
end

local function ensure()
	if anchor and target and beam then
		return
	end
	anchor = point("GuideFrom")
	target = point("GuideTo")
	local b = Instance.new("Beam")
	b.Attachment0 = (anchor :: Part):FindFirstChildOfClass("Attachment")
	b.Attachment1 = (target :: Part):FindFirstChildOfClass("Attachment")
	b.FaceCamera = true
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Segments = 24
	b.CurveSize0 = 1.4
	b.CurveSize1 = -0.6
	b.Enabled = false
	b.Parent = anchor
	beam = b
	local p = Instance.new("ParticleEmitter")
	p.Rate = 0
	p.Lifetime = NumberRange.new(0.5, 0.9)
	p.Speed = NumberRange.new(0.2, 0.6)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	p.LightEmission = 1
	p.Parent = (anchor :: Part):FindFirstChildOfClass("Attachment")
	sparkle = p
end

local function style()
	local b = beam :: Beam
	local colour = Brand.TrailColours[State.get("trailColour")] or Brand.TrailColours.House
	b.Color = ColorSequence.new(colour)
	local trail = State.get("trail")
	local pace = State.get("trailPace")
	local width = if trail == "Ribbon" then 0.16 elseif trail == "Comet" then 0.1 elseif trail == "Runway" then 0.22 else 0.07
	b.Width0 = width
	b.Width1 = if trail == "Comet" then 0.01 else width * 0.5
	b.FaceCamera = trail ~= "Runway"
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	local s = sparkle :: ParticleEmitter
	s.Color = ColorSequence.new(colour)
	local glow = State.get("glow")
	s.Rate = if trail == "Sparkles" and glow ~= "Off" then (if pace == "Lively" then 26 elseif pace == "Calm" then 8 else 16) else 0
end

-- The delay before the guide appears, or nil for no guide at all.
function Guide.delayFor(roomId: string): number?
	local room = if roomId == "library" then Duel.room(1) else Rooms.get(roomId)
	if not room then
		return nil
	end
	local setting = State.get("showTheWay")
	if room.tuning.guide == "none" or setting == "Never" or State.get("trail") == "Case only" then
		return nil
	end
	local roomDelay = if room.tuning.guide == "delayed" then room.tuning.guideDelay else 0
	local settingDelay = if setting == "After a moment" then 1.2 else 0
	return math.max(roomDelay, settingDelay)
end

-- Shows the thread from `from` to `to` after the room's delay. Returns nothing; call hide() to stop.
function Guide.show(roomId: string, from: Vector3, to: Vector3)
	serial += 1
	local mine = serial
	local delay = Guide.delayFor(roomId)
	ensure()
	Guide.move(from)
	;(target :: Part).CFrame = CFrame.new(to)
	if delay == nil then
		return
	end
	task.delay(delay, function()
		if serial ~= mine then
			return
		end
		style()
		;(beam :: Beam).Enabled = true
	end)
end

function Guide.move(from: Vector3)
	if anchor then
		anchor.CFrame = CFrame.new(from)
	end
end

function Guide.hide()
	serial += 1
	if beam then
		beam.Enabled = false
	end
	if sparkle then
		sparkle.Rate = 0
	end
end

return Guide
