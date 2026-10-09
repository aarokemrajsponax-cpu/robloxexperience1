--!strict
-- The close of a Tête-à-Tête: who takes the table, hands won, the rating and Mark (after the
-- placement evenings), the Gilt, and Another or Leave. Ranked, friendly and Stand-in evenings
-- say plainly which they were.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local RoundPanel = require(script.Parent.RoundPanel)
local Theme = require(script.Parent.Theme)
local Share = require(script.Parent.Share)

local DuelPanel = {}

local NAME = "Duel"

export type Actions = { side: string, again: () -> (), leave: () -> () }

local function row(parent: Instance, left: string, right: string, order: number)
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 0, 0, 24)
	r.LayoutOrder = order
	r.Parent = parent
	Theme.text(r, left, 15, "body", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0.55, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Brand.Colours.smoke,
	})
	Theme.text(r, right, 15, "bodyMedium", {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromScale(0.55, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Brand.Colours.bone,
	})
end

function DuelPanel.show(message: { [string]: any }, actions: Actions)
	DuelPanel.close()
	local side = actions.side
	local rivalSide = if side == "a" then "b" else "a"
	local wins = message.wins or {}
	local rival = if type(message.rival) == "string" then message.rival else "Your rival"
	local heading = if message.won
		then (if message.reason == "forfeit" then Voice.fill(Voice.Library.forfeit, { name = rival }) else Voice.Library.won)
		else Voice.fill(Voice.Library.lost, { name = rival })
	local kind = if message.standIn then Voice.Library.standIn elseif message.ranked then Voice.Library.ranked else Voice.Library.friendly

	local rows: { { string } } = {
		{ Voice.Library.hands, string.format("%d – %d", wins[side] or 0, wins[rivalSide] or 0) },
	}
	if type(message.before) == "number" and type(message.after) == "number" then
		local delta = math.floor(message.after + 0.5) - math.floor(message.before + 0.5)
		table.insert(rows, { Voice.Library.rating, string.format("%d  (%s%d)", math.floor(message.after + 0.5), if delta >= 0 then "+" else "−", math.abs(delta)) })
	end
	if type(message.markAfter) == "string" then
		local changed = message.markBefore ~= message.markAfter
		table.insert(rows, { if changed then "A new Mark" else "Your Mark", message.markAfter })
	end
	if (message.gilt or 0) > 0 then
		table.insert(rows, { Voice.Library.gilt, "+" .. RoundPanel.number(message.gilt) })
	end

	local size = Root.size()
	local w = math.min(420, size.X - 24)
	local h = 300 + #rows * 26 + (if (message.placementLeft or 0) > 0 then 24 else 0)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h), UDim2.new(0.5, 0, 0.5, 20))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, Voice.Library.title .. "  ·  " .. kind, 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, heading, 24, "display", { LayoutOrder = 2, TextColor3 = if message.won then Brand.Colours.lightGold else Brand.Colours.bone })
	Theme.hairline(content, UDim.new(0, 120), 3)
	for i, r in rows do
		row(content, r[1], r[2], 3 + i)
	end
	if (message.placementLeft or 0) > 0 then
		Theme.text(content, Voice.fill(Voice.Library.placement, { n = tostring(message.placementLeft) }), 13, "body", { LayoutOrder = 20, TextColor3 = Brand.Colours.smoke })
	end
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 50
	keys.Parent = content
	Theme.list(keys, 8)
	Theme.key(keys, Voice.Library.another, true, function()
		Root.close(NAME)
		actions.again()
	end, 260).LayoutOrder = 1
	if Share.allowed() and (message.won or (type(message.markAfter) == "string" and message.markAfter ~= message.markBefore)) then
		Theme.key(keys, "Share", false, function()
			Share.moment("library")
		end, 260).LayoutOrder = 2
	end
	Theme.key(keys, "Leave", false, function()
		Root.close(NAME)
		actions.leave()
	end, 260).LayoutOrder = 3
	Root.open(NAME, group, nil, false)
	pcall(function()
		game:GetService("GuiService").SelectedObject = keys:FindFirstChildWhichIsA("TextButton")
	end)
end

function DuelPanel.close()
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
end

return DuelPanel
