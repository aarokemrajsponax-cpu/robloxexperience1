--!strict
-- A safety net, separate from the house's own server script (Main). Main spawns every guest once
-- the house is built; if it ever stops before that (an error, a script stopped by Roblox), nobody
-- would spawn and the screen would show only sky. This waits, and if a guest still has no
-- character after a while, it says so in Output and spawns them anyway.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WAIT = 20 -- seconds: far longer than the house takes to build (about a second) and place a guest

local function watch(player: Player)
	task.delay(WAIT, function()
		if player.Parent and player.Character == nil then
			local stage = Workspace:GetAttribute("MaisonBoot")
			warn(string.format(
				"[Maison] %s had no character after %d seconds; spawning them now. The server's start was at: %s.",
				player.Name,
				WAIT,
				if stage == "open" then "done (the character itself was slow to load)" else tostring(stage or "not started")
			))
			if Workspace:GetAttribute("MaisonReady") ~= true then
				warn("[Maison] The house wasn't built yet. Check Output for \"[Maison] Building ... failed\" or a script timeout.")
			end
			local ok = pcall(function()
				(player :: any):LoadCharacterAsync()
			end)
			if not ok then
				pcall(function()
					(player :: any):LoadCharacter()
				end)
			end
		end
	end)
end

Players.PlayerAdded:Connect(watch)
for _, p in Players:GetPlayers() do
	watch(p)
end
