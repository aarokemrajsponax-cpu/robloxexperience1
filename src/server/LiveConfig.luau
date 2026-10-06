--!strict
-- Overlays Roblox Configs (Creator Dashboard → Configs) onto the code defaults in Shared/Config.
-- A Config key is the setting's path with dots written as underscores, for example
--   Rooms_salon_firstDeal = 9
-- Changes published on the dashboard reach running servers without republishing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LiveConfig = {}

LiveConfig.overrides = {} :: { [string]: any }
LiveConfig.available = false

local changed = Instance.new("BindableEvent")
LiveConfig.Changed = changed.Event

local function keyFor(path: string): string
	return (string.gsub(path, "%.", "_"))
end

local function read(snapshot: ConfigSnapshot): { [string]: any }
	local found = {}
	for _, path in Config.paths() do
		local ok, value = pcall(function()
			return snapshot:GetValue(keyFor(path))
		end)
		if ok and value ~= nil then
			found[path] = value
		end
	end
	return found
end

local function apply(found: { [string]: any })
	local applied = {}
	for path, value in found do
		if Config.set(path, value) then
			applied[path] = value
		else
			warn(`[Maison] Config {keyFor(path)} ignored: expected a {typeof(Config.get(path))}`)
		end
	end
	LiveConfig.overrides = applied
	changed:Fire(applied)
	Remotes.event("Guest"):FireAllClients({ op = "config", overrides = applied })
end

-- Starts loading (and keeps listening for published changes). Returns a function that waits for
-- the load, at most `timeout` seconds after it was started (the house builds meanwhile).
function LiveConfig.begin(): (timeout: number) -> ()
	local done = false
	local started = os.clock()
	task.spawn(function()
		local ok, snapshot = pcall(function()
			return (game:GetService("ConfigService") :: ConfigService):GetConfigAsync()
		end)
		if not ok or not snapshot then
			done = true
			return
		end
		LiveConfig.available = true
		apply(read(snapshot))
		done = true
		snapshot.UpdateAvailable:Connect(function()
			pcall(function()
				snapshot:Refresh()
			end)
			apply(read(snapshot))
		end)
	end)
	return function(timeout: number)
		local limit = started + timeout
		while not done and os.clock() < limit do
			task.wait(0.1)
		end
	end
end

-- Loads once (waiting at most `timeout` seconds) and keeps listening for published changes.
function LiveConfig.start(timeout: number)
	LiveConfig.begin()(timeout)
end

return LiveConfig
