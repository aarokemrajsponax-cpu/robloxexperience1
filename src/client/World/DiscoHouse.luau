--!strict
-- The House Party (an owner's event, often part of Admin Abuse Night): while it's on, every lamp
-- in the house turns disco on this screen, colours chasing round the rooms, and the picture pulses
-- with them. When it ends, every lamp is exactly as it was (each one's colour is kept on it).

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local HouseEvents = require(game:GetService("ReplicatedStorage").Shared.HouseEvents)

local DiscoHouse = {}

local rgb = Color3.fromRGB
local COLOURS = { rgb(255, 60, 140), rgb(80, 140, 255), rgb(90, 255, 170), rgb(255, 214, 80), rgb(190, 90, 255), rgb(255, 120, 40), rgb(60, 230, 255) }
local ATTRIBUTE = HouseEvents.attribute("discoHouse")

local running = false

local function lights(): { Light }
	local out: { Light } = {}
	local maison = Workspace:FindFirstChild("Maison")
	if maison then
		for _, d in maison:GetDescendants() do
			if d:IsA("Light") then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function on(): boolean
	local ends = Workspace:GetAttribute(ATTRIBUTE)
	return type(ends) == "number" and ends > Workspace:GetServerTimeNow()
end

local function party()
	if running then
		return
	end
	running = true
	local list = lights()
	for _, l in list do
		if l:GetAttribute("DiscoWas") == nil then
			l:SetAttribute("DiscoWas", l.Color)
		end
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "HouseParty"
	grade.Parent = Lighting
	task.spawn(function()
		local beat = 0
		while on() do
			beat += 1
			for i, l in list do
				if l.Parent then
					l.Color = COLOURS[(i + beat) % #COLOURS + 1]
				end
			end
			local c = COLOURS[beat % #COLOURS + 1]
			grade.TintColor = Color3.new(1, 1, 1):Lerp(c, 0.12)
			grade.Saturation = 0.15
			task.wait(0.4)
		end
		-- The party's over: every lamp back as it was.
		for _, l in list do
			local was = l:GetAttribute("DiscoWas")
			if typeof(was) == "Color3" then
				l.Color = was
			end
			l:SetAttribute("DiscoWas", nil)
		end
		grade:Destroy()
		running = false
	end)
end

function DiscoHouse.start()
	Workspace:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		if on() then
			party()
		end
	end)
	if on() then
		party()
	end
end

return DiscoHouse
