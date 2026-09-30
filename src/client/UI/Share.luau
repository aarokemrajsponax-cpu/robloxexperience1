--!strict
-- One quiet Share key at the moments worth sharing (§13): Roblox's own capture sharing, with an
-- invite and launch data attached so a friend lands in the right place. Never automatic.

local CaptureService = game:GetService("CaptureService")

local Toast = require(script.Parent.Toast)

local Share = {}

function Share.moment(launch: string)
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
