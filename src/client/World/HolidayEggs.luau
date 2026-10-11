--!strict
-- The Great Egg Hunt on this screen (the server hides the eggs, a small invisible part each, and
-- decides who found one). Each egg is drawn here: painted in pastels, banded and dotted, resting
-- where it was hidden, with a glint every few seconds for a sharp eye; the golden one shines. Found:
-- a burst of pastel confetti where it stood.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local HolidayKit = require(script.Parent.HolidayKit)

local HolidayEggs = {}

local rgb = Color3.fromRGB

-- (By each egg's Id: the part the server removes is known by its Id.)
local eggs: { [number]: Model } = {}
local connections: { RBXScriptConnection } = {}
local folder: Folder? = nil
local left = 0

local function idOf(part: BasePart): number?
	local id = part:GetAttribute("Id")
	return if type(id) == "number" then id else nil
end

local function add(part: BasePart)
	local id = idOf(part)
	if not id or eggs[id] then
		return
	end
	local scheme = part:GetAttribute("Scheme")
	local golden = part:GetAttribute("Golden") == true
	local height = part:GetAttribute("Height")
	local h = if type(height) == "number" then height else 1.6
	local colours = HolidayProps.EGGS[if type(scheme) == "number" then math.clamp(scheme, 1, #HolidayProps.EGGS) else 1]
	local floor = part.CFrame * CFrame.new(0, -h / 2, 0)
	local m = HolidayProps.egg(HolidayKit.folder("HolidayEggs"), floor, h, colours, golden)
	if not golden then
		HolidayKit.glint(m.PrimaryPart :: BasePart, colours[2], 0.35)
	end
	eggs[id] = m
	left += 1
end

local function remove(id: number)
	local m = eggs[id]
	if m then
		eggs[id] = nil
		m:Destroy()
		left = math.max(0, left - 1)
	end
end

-- The eggs' folder arrived (or went).
function HolidayEggs.attach(f: Instance?)
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
	for id in eggs do
		remove(id)
	end
	left = 0
	folder = if f and f:IsA("Folder") then f else nil
	local ff = folder
	if not ff then
		return
	end
	for _, p in ff:GetChildren() do
		if p:IsA("BasePart") then
			add(p)
		end
	end
	table.insert(connections, ff.ChildAdded:Connect(function(p)
		if p:IsA("BasePart") then
			add(p)
		end
	end))
	table.insert(connections, ff.ChildRemoved:Connect(function(p)
		local id = if p:IsA("BasePart") then idOf(p) else nil
		if id then
			remove(id)
		end
	end))
end

-- An egg found (by anyone): confetti where it stood.
function HolidayEggs.found(at: Vector3?, golden: boolean)
	if not at then
		return
	end
	local colours = if golden then { rgb(255, 214, 110), rgb(255, 246, 210) } else { rgb(250, 182, 206), rgb(170, 214, 250), rgb(196, 234, 180), rgb(255, 245, 170) }
	HolidayKit.burst(at, colours, if golden then 40 else 22, 0.5, true)
	if golden then
		HolidayKit.words(at + Vector3.new(0, 3, 0), "THE GOLDEN EGG!", rgb(255, 214, 110), 12)
	end
end

-- How many eggs are left to find.
function HolidayEggs.left(): number
	return left
end

return HolidayEggs
