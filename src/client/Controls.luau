--!strict
-- The guest's own controls (Roblox's PlayerModule): switched off under the Home Screen, at a
-- table and in photo mode, and back on after. Nothing ever waits on them: Roblox's PlayerModule
-- can reach PlayerScripts late (a slow phone, or no character yet under the Home Screen), and a
-- script that waited for it would stop right there (the house's start once did, behind a blank
-- screen). So the wanted state is kept and applied the moment the module is there.

local Players = game:GetService("Players")

local Controls = {}

local player = Players.LocalPlayer
local controls: any = nil
local wanted = true
local looking = false

-- Roblox's control object, if its PlayerModule is already in PlayerScripts (never waits).
function Controls.get(): any
	if controls then
		return controls
	end
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return nil
	end
	local ok, found = pcall(function()
		return ((require :: any)(module) :: any):GetControls()
	end)
	if ok and found then
		controls = found
	end
	return controls
end

local function apply()
	local c = controls
	if not c then
		return
	end
	pcall(function()
		if wanted then
			c:Enable()
		else
			c:Disable()
		end
	end)
end

-- On or off. Applied now if Roblox's controls are there; otherwise as soon as they arrive (looked
-- for in the background: Roblox adds them around the guest's first character, so under the Home
-- Screen they're often not there yet). Still missing half a minute after the character arrived:
-- said once in the Output, and the house carries on.
function Controls.set(on: boolean)
	wanted = on
	if Controls.get() then
		apply()
		return
	end
	if looking then
		return
	end
	looking = true
	task.spawn(function()
		local since: number? = nil
		local told = false
		while not Controls.get() do
			task.wait(0.5)
			if player.Character then
				since = since or os.clock()
			else
				since = nil
			end
			if not told and since and os.clock() - since > 30 then
				told = true
				warn("[Maison] Roblox's PlayerModule isn't in PlayerScripts, so your controls can't be switched off and on. The house carries on without it.")
			end
		end
		looking = false
		apply()
	end)
end

-- Whether the house wants them on (the last Controls.set).
function Controls.wanted(): boolean
	return wanted
end

return Controls
