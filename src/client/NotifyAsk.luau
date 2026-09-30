--!strict
-- Asks for Roblox's experience-notification opt-in, once, a few seconds after a guest's first
-- Nightly card (a moment of delight, never on first join). Roblox shows its own prompt only to
-- guests it may ask (13+, not asked recently).

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")

local Closet = require(script.Parent.Closet)

local NotifyAsk = {}

NotifyAsk.delay = 8 -- seconds after the Nightly card

function NotifyAsk.ask()
	local ok, can = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	if not ok or not can then
		return
	end
	local conn: RBXScriptConnection? = nil
	conn = ExperienceNotificationService.OptInPromptClosed:Connect(function()
		if conn then
			conn:Disconnect()
		end
		-- Roblox doesn't say which way it went; ask again whether we may.
		local okAfter, stillCan = pcall(function()
			return ExperienceNotificationService:CanPromptOptInAsync()
		end)
		Closet.ask({ op = "notify", answer = if okAfter and not stillCan then "granted" else "declined" })
	end)
	pcall(function()
		ExperienceNotificationService:PromptOptIn()
	end)
end

function NotifyAsk.start()
	Closet.Message:Connect(function(op: string)
		if op == "askNotify" then
			task.delay(NotifyAsk.delay, NotifyAsk.ask)
		end
	end)
end

return NotifyAsk
