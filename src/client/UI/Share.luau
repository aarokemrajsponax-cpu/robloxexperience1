--!strict
-- One quiet Share key at the moments worth sharing (§13): Roblox's own capture sharing, with an
-- invite and launch data attached so a friend lands in the right place. Never automatic. Only for
-- guests whose Roblox policy allows sharing (the server asks Roblox: Policy, "ContentSharingAllowed");
-- for anyone else the Share keys aren't shown at all.

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")

local Toast = require(script.Parent.Toast)

local Share = {}

function Share.allowed(): boolean
	return Players.LocalPlayer:GetAttribute("ContentSharingAllowed") == true
end

function Share.moment(launch: string)
	if not Share.allowed() then
		return
	end
	local ok = pcall(function()
		CaptureService:CaptureScreenshot(function(contentId: any)
			pcall(function()
				CaptureService:PromptShareCapture(Content.fromUri(tostring(contentId)), launch, function() end, function() end)
			end)
		end)
	end)
	if not ok then
		Toast.show("Share", "Sharing isn't available on this device.", 3)
	end
end

return Share
