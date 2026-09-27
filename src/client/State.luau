--!strict
-- The client's picture of the guest: settings, what the server told us on arrival, the season.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)

local State = {}

State.settings = Settings.defaults()
State.guest = nil :: { [string]: any }?
State.seated = false
State.phase = "intro" :: string

local settingChanged = Instance.new("BindableEvent")
State.SettingChanged = settingChanged.Event -- (key, value)
local welcomed = Instance.new("BindableEvent")
State.Welcomed = welcomed.Event
local phaseChanged = Instance.new("BindableEvent")
State.PhaseChanged = phaseChanged.Event

local guestEvent = Remotes.event("Guest")

local function applyOverrides(overrides: any)
	if type(overrides) == "table" then
		Config.applyOverrides(overrides)
	end
end

guestEvent.OnClientEvent:Connect(function(message: any)
	if type(message) ~= "table" then
		return
	end
	if message.op == "welcome" then
		State.guest = message
		State.settings = Settings.sanitize(message.settings)
		applyOverrides(message.overrides)
		welcomed:Fire(message)
		for key, value in State.settings do
			settingChanged:Fire(key, value)
		end
	elseif message.op == "config" then
		applyOverrides(message.overrides)
	end
end)

function State.waitForWelcome(timeout: number): { [string]: any }?
	local limit = os.clock() + timeout
	while State.guest == nil and os.clock() < limit do
		task.wait(0.05)
	end
	return State.guest
end

function State.get(key: string): any
	return State.settings[key]
end

function State.set(key: string, value: any)
	if not Settings.validate(key, value) or State.settings[key] == value then
		return
	end
	State.settings[key] = value
	Remotes.event("Setting"):FireServer(key, value)
	settingChanged:Fire(key, value)
end

-- Calls `fn(value)` now and whenever the setting changes.
function State.watch(key: string, fn: (value: any) -> ())
	fn(State.settings[key])
	State.SettingChanged:Connect(function(k, v)
		if k == key then
			fn(v)
		end
	end)
end

function State.setPhase(phase: string)
	State.phase = phase
	phaseChanged:Fire(phase)
end

function State.isFirstVisit(): boolean
	return State.guest ~= nil and State.guest.firstVisit == true
end

function State.season(): (string, string, string)
	return tostring(Workspace:GetAttribute("Season") or ""), tostring(Workspace:GetAttribute("SeasonName") or ""), tostring(Workspace:GetAttribute("SeasonLine") or "")
end

function State.inputKind(): "touch" | "gamepad" | "mouse"
	local ok, preferred = pcall(function()
		return UserInputService.PreferredInput
	end)
	if ok then
		if preferred == Enum.PreferredInput.Touch then
			return "touch"
		elseif preferred == Enum.PreferredInput.Gamepad then
			return "gamepad"
		end
		return "mouse"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	end
	return "mouse"
end

function State.funnel(step: number)
	Remotes.event("Funnel"):FireServer(step)
end

return State
