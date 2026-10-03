--!strict
-- Decrees and rains, on every screen in the house: a gold-edged banner across the top. Its look
-- is the house's own (a buyer can't change the colour, the size or how long it stays): a decree
-- is headed by who proclaimed it, display name and @username, and its words are the ones Roblox's
-- filter returned to the server. One banner at a time; a new one replaces the last.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local DecreeBanner = {}

local current: CanvasGroup? = nil

-- Shows a banner: a small heading in capitals and a line in the display face, for `seconds`
-- (kept between 3 and 15 whatever the message says).
function DecreeBanner.show(heading: string, line: string, seconds: number?)
	if current then
		current:Destroy()
		current = nil
	end
	local w = math.min(620, Root.size().X - 24)
	local group, content = Theme.glass(Root.hud, "Decree", UDim2.fromOffset(w, 0), UDim2.new(0.5, 0, 0, 96), Vector2.new(0.5, 0))
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	local fill = group:FindFirstChild("Fill")
	local stroke = fill and fill:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 2
		stroke.Transparency = 0.05
	end
	Theme.list(content, 6)
	Theme.text(content, heading, 11, "caps", { LayoutOrder = 1 })
	local words = Theme.text(content, line, 24, "display", { LayoutOrder = 2, TextColor3 = Brand.Colours.lightGold })
	words.TextWrapped = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 26
	limit.MinTextSize = 14
	limit.Parent = words
	current = group
	group.GroupTransparency = 1
	Ease.play(group, Ease.scaled(Ease.settle), { GroupTransparency = 0 })
	local hold = math.clamp(tonumber(seconds) or 8, 3, 15)
	task.delay(hold, function()
		if current == group then
			current = nil
			local t = Ease.play(group, Ease.info(0.6, Enum.EasingStyle.Sine), { GroupTransparency = 1 })
			t.Completed:Once(function()
				group:Destroy()
			end)
		end
	end)
end

-- A decree from the server: { name, user, text, seconds }.
function DecreeBanner.decree(m: { [string]: any })
	if type(m.text) ~= "string" or type(m.name) ~= "string" then
		return
	end
	local who = m.name .. (if type(m.user) == "string" and m.user ~= m.name then " (@" .. m.user .. ")" else "")
	DecreeBanner.show("Decree of " .. who, m.text, tonumber(m.seconds))
end

return DecreeBanner
