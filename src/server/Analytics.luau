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

function Analytics.custom(player: Player, name: string, value: number?, fields: { [string]: any }?)
	if not enabled() then
		return
	end
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value, fields)
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

function Analytics.start()
	Players.PlayerRemoving:Connect(function(player)
		logged[player] = nil
		stamps[player] = nil
	end)
end

return Analytics
