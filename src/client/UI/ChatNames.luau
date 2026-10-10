--!strict
-- Names in the chat: the owner speaks as AJKR (in gold, crowned), never their Roblox username; and
-- a guest whose display name reads as AJKR speaks by their @username, so nobody passes for the
-- owner (shared/Names). Everyone else's name is left as Roblox shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Names = require(ReplicatedStorage.Shared.Names)

local ChatNames = {}

-- (A name as plain text inside rich text.)
local function rich(s: string): string
	return (string.gsub(string.gsub(string.gsub(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- (A name found as it is, not as a pattern.)
local function swap(text: string, find: string, put: string): (string, boolean)
	local i, j = string.find(text, find, 1, true)
	if not i or not j then
		return text, false
	end
	return string.sub(text, 1, i - 1) .. put .. string.sub(text, j + 1), true
end

-- Who sent a message (set for tests).
ChatNames.playerFor = function(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

-- The prefix a message should have (nil: as Roblox has it).
function ChatNames.prefix(userId: number, given: string): string?
	local p = ChatNames.playerFor(userId)
	if not p then
		return nil
	end
	local owner = Names.isOwner(p)
	local shown = Names.of(p)
	if not owner and shown == p.DisplayName then
		return nil
	end
	local name = if owner then '<font color="#FFCC6E"><b>👑 ' .. rich(shown) .. "</b></font>" else rich(shown)
	for _, find in { rich(p.DisplayName), p.DisplayName } do
		local out, found = swap(given, find, name)
		if found then
			return out
		end
	end
	return name .. ":"
end

function ChatNames.start()
	pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
			local props = Instance.new("TextChatMessageProperties")
			local source = message.TextSource
			if source then
				local ok, prefix = pcall(ChatNames.prefix, source.UserId, message.PrefixText)
				if ok and prefix then
					props.PrefixText = prefix
				end
			end
			return props
		end
	end)
end

return ChatNames
