--!strict
-- How much the house's shows may draw on this screen, so they are as grand as the screen can take
-- and never more: the guest's graphics level (Roblox's own setting), their own Glow and sparks
-- setting, and how smoothly this screen is really running. Every spectacle asks it how many sparks,
-- flakes, lights and pieces to make: the full show on a strong machine, a lighter one on a phone,
-- on a low graphics level, or whenever the frame rate starts to fall. It measures the frame rate as
-- the guest plays: down quickly when frames drop, back up slowly as they recover.

local RunService = game:GetService("RunService")

local Quality = {}

local LIGHTEST = 0.35
local measured = 1
local pinned: number? = nil
local started = false

-- Roblox's graphics level (1 to 10; Automatic counts as a good machine, and the frame rate keeps
-- it honest).
local function saved(): number
	local ok, level = pcall(function(): any
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	if ok and type(level) == "number" and level > 0 then
		return math.clamp(0.4 + level * 0.06, 0.5, 1)
	end
	return 0.9
end

-- The guest's own Glow and sparks setting (Settings).
local function chosen(): number
	local ok, glow = pcall(function(): any
		return require(script.Parent.State).get("glow")
	end)
	if ok and glow == "Subtle" then
		return 0.7
	elseif ok and glow == "Off" then
		return 0.45
	end
	return 1
end

-- From the lightest (0.35) to everything (1).
function Quality.level(): number
	return math.clamp(math.min(saved(), pinned or measured) * chosen(), LIGHTEST, 1)
end

-- `n` of something, as many as this screen should draw (never fewer than `least`, or 1).
function Quality.count(n: number, least: number?): number
	return math.max(least or 1, math.floor(n * Quality.level() + 0.5))
end

-- Whether this screen can afford the extras (garlands wound up the Foyer's columns, mist...).
function Quality.rich(): boolean
	return Quality.level() >= 0.6
end

-- (For tests: the share the frame rate allows, as measured; and holding it at `v` whatever the
-- frames say, or letting go with nil.)
function Quality.measured(): number
	return measured
end
function Quality.pin(v: number?)
	pinned = if v then math.clamp(v, LIGHTEST, 1) else nil
end

function Quality.start()
	if started then
		return
	end
	started = true
	local frames, elapsed = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		frames += 1
		elapsed += dt
		if elapsed < 3 then
			return
		end
		local fps = frames / elapsed
		frames, elapsed = 0, 0
		local target = if fps >= 52 then 1 elseif fps >= 42 then 0.85 elseif fps >= 32 then 0.65 else 0.45
		measured = if target < measured then target else math.min(target, measured + 0.05)
	end)
end

return Quality
