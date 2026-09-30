--!strict
-- Salutes: moments bought for the whole house (Salutes.luau). One plays at a time; the rest wait
-- their turn (a few at most). Everyone in the house sees it and who gave it; the giver's name goes
-- on the Tonight board (the Grand Salute's in every house), and their nameplate carries a gold
-- star for half an hour.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Salutes = require(ReplicatedStorage.Shared.Salutes)
local Analytics = require(script.Parent.Analytics)

local SaluteService = {}

type Queued = { id: string, name: string, userId: number }
local queue: { Queued } = {}
local playing = false

-- The board's feed (set by Main): this house only, or every house.
SaluteService.note = function(_text: string, _everywhere: boolean) end
-- The giver's nameplate (set by Main).
SaluteService.benefactor = function(_player: Player) end

function SaluteService.waiting(): number
	return #queue + (if playing then 1 else 0)
end

function SaluteService.full(): boolean
	return #queue >= Config.data.Products.saluteQueue
end

local function run()
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local q = table.remove(queue, 1) :: Queued
			local s = Salutes.byId[q.id]
			if s then
				Remotes.event("Salute"):FireAllClients({ op = "salute", id = q.id, by = q.name, userId = q.userId, seconds = s.seconds, effects = Salutes.effects(q.id), line = Salutes.line(q.id, q.name) })
				SaluteService.note(Salutes.line(q.id, q.name), s.global)
				task.wait(s.seconds + 2)
			end
		end
		playing = false
	end)
end

-- A salute bought (from a receipt) or given by the house (the owner's events).
function SaluteService.play(player: Player?, id: string, byName: string?)
	if not Salutes.byId[id] then
		return
	end
	local name = byName or (if player then player.DisplayName else "The house")
	table.insert(queue, { id = id, name = name, userId = if player then player.UserId else 0 })
	if player then
		Analytics.custom(player, "Salute given", nil, { salute = id })
		player:SetAttribute("BenefactorUntil", os.time() + Config.data.Products.benefactorMinutes * 60)
		SaluteService.benefactor(player)
		local minutes = Config.data.Products.benefactorMinutes
		task.delay(minutes * 60 + 1, function()
			if player.Parent == Players then
				SaluteService.benefactor(player)
			end
		end)
	end
	run()
end

return SaluteService
