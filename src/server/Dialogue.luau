--!strict
-- Sends staff lines to one guest and routes their replies. Lines appear in the client's glass
-- dialogue panel, never the default Roblox bubble.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Dialogue = {}

export type Choice = { id: string, text: string }
type Pending = { token: string, choices: { [string]: boolean }, handler: (choiceId: string) -> () }

local pending: { [Player]: Pending } = {}
local dialogueEvent = Remotes.event("Dialogue")
local choiceEvent = Remotes.event("DialogueChoice")

export type Extra = { title: string?, step: string?, point: Vector3?, pointName: string? }

-- Shows a line. With choices, `handler` runs with the chosen id (once). `extra` adds a heading,
-- a step ("3 of 12") and a place to point at (a gold pin and a line of light), for the tour.
function Dialogue.say(player: Player, speaker: string, line: string, choices: { Choice }?, handler: ((choiceId: string) -> ())?, hold: number?, extra: Extra?)
	local token = HttpService:GenerateGUID(false)
	if choices and handler then
		local allowed = {}
		for _, c in choices do
			allowed[c.id] = true
		end
		pending[player] = { token = token, choices = allowed, handler = handler }
	end
	dialogueEvent:FireClient(player, {
		token = token,
		speaker = speaker,
		line = line,
		choices = choices,
		hold = hold,
		title = extra and extra.title,
		step = extra and extra.step,
		point = extra and extra.point,
		pointName = extra and extra.pointName,
	})
end

function Dialogue.close(player: Player)
	pending[player] = nil
	dialogueEvent:FireClient(player, { close = true })
end

function Dialogue.start()
	RemoteGuard.event(choiceEvent, "dialogueChoice", function(player: Player, token: unknown, choiceId: unknown)
		if type(token) ~= "string" or type(choiceId) ~= "string" then
			return
		end
		local p = pending[player]
		if not p or p.token ~= token or not p.choices[choiceId] then
			return
		end
		pending[player] = nil
		task.spawn(p.handler, choiceId)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return Dialogue
