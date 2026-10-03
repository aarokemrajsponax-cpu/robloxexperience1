--!strict
-- Roblox analytics: the first-evening onboarding funnel, economy events and custom events
-- (Appendix J). Every call is guarded so analytics can never break play.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Analytics = {}

-- The first evening (Appendix J). Order matters: Roblox reads these as funnel steps.
Analytics.FirstEvening = {
	"Intro shown", -- 1  client
	"Play pressed", -- 2  client
	"Control given", -- 3  client
	"Foyer entered", -- 4
	"Seated", -- 5
	"First piece lifted", -- 6
	"First piece filed", -- 7
	"Round I complete", -- 8
	"Round III complete", -- 9
	"Run banked", -- 10
}
Analytics.ClientSteps = { [1] = true, [2] = true, [3] = true }

local logged: { [Player]: { [number]: boolean } } = {}
local stamps: { [Player]: { [string]: number } } = {}

local function enabled(): boolean
	return Config.data.Analytics.enabled
end

function Analytics.step(player: Player, step: number)
	local done = logged[player]
	if not done then
		done = {}
		logged[player] = done
	end
	if done[step] then
		return
	end
	done[step] = true
	local name = Analytics.FirstEvening[step]
	if not name then
		return
	end
	local s = stamps[player] or {}
	stamps[player] = s
	s[name] = os.clock()
	if not enabled() then
		return
	end
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Analytics.stamp(player: Player, name: string): number?
	local s = stamps[player]
	return if s then s[name] else nil
end

-- Roblox only reads three breakdown fields per custom event, keyed by
-- Enum.AnalyticsCustomFieldKeys.CustomField01..03 (any other key is silently dropped). Fields come
-- either in order ({ "product", "reason", "segment" }) or by name (sorted, sent as "name=value").
local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }
local function fieldKey(i: number): string
	local ok, name = pcall(function()
		return ((Enum :: any).AnalyticsCustomFieldKeys :: any)[FIELD_KEYS[i]].Name
	end)
	return if ok and type(name) == "string" then name else FIELD_KEYS[i]
end

function Analytics.fields(fields: { [any]: any }?): { [string]: string }?
	if fields == nil then
		return nil
	end
	local values: { string } = {}
	if fields[1] ~= nil then
		for i = 1, 3 do
			local v = fields[i]
			if v ~= nil and v ~= "" then
				values[i] = tostring(v)
			end
		end
	else
		local names = {}
		for k in fields do
			table.insert(names, tostring(k))
		end
		table.sort(names)
		for i = 1, math.min(3, #names) do
			values[i] = names[i] .. "=" .. tostring(fields[names[i]])
		end
	end
	local out: { [string]: string } = {}
	for i, v in values do
		out[fieldKey(i)] = string.sub(v, 1, 50)
	end
	return out
end

function Analytics.custom(player: Player, name: string, value: number?, fields: { [any]: any }?)
	if not enabled() then
		return
	end
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value, Analytics.fields(fields))
	end)
end

function Analytics.source(player: Player, currency: string, amount: number, balance: number, sku: string)
	if not enabled() or amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, currency, amount, balance, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, sku)
	end)
end

function Analytics.sink(player: Player, currency: string, amount: number, balance: number, sku: string)
	if not enabled() or amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, currency, amount, balance, Enum.AnalyticsEconomyTransactionType.Shop.Name, sku)
	end)
end

function Analytics.start()
	Players.PlayerRemoving:Connect(function(player)
		logged[player] = nil
		stamps[player] = nil
	end)
end

return Analytics
