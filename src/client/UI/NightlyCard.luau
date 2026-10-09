--!strict
-- The Nightly card (§6, §9.1): composed to be screenshotted at phone size. Date, room, score,
-- grade, five round hallmarks, your place among your connections, the percentile. Display
-- names only, nothing personal. Share sends it through Roblox's own capture sharing with an
-- invite attached; Invite asks a friend to try the same deal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Hallmark = require(script.Parent.Hallmark)
local Root = require(script.Parent.Root)
local RoundPanel = require(script.Parent.RoundPanel)
local Share = require(script.Parent.Share)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local NightlyCard = {}

local NAME = "NightlyCard"
local LAUNCH = "nightly"

local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }

local function dateText(key: string): string
	local y, m, d = string.match(key, "^(%d+)-(%d+)-(%d+)$")
	if not y then
		return key
	end
	return string.format("%d %s %s", tonumber(d) or 0, MONTHS[tonumber(m) or 1] or "", y)
end

local function ordinal(n: number): string
	local suffix = "th"
	local lastTwo = n % 100
	if lastTwo < 11 or lastTwo > 13 then
		local last = n % 10
		suffix = if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th"
	end
	return tostring(n) .. suffix
end

local function share()
	Share.moment(LAUNCH)
end

local function invite()
	local ok = pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.LaunchData = LAUNCH
		options.PromptMessage = "Tonight's table is laid. Same pieces, same order."
		SocialService:PromptGameInvite(Players.LocalPlayer, options)
	end)
	if not ok then
		Toast.show("Invite", "Invites aren't available here.", 3)
	end
end

export type Actions = { rehearse: () -> (), leave: () -> () }

function NightlyCard.show(card: { [string]: any }, actions: Actions)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local size = Root.size()
	local w = math.min(460, size.X - 24)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 540))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local room = Rooms.get(card.room)

	Theme.text(content, Brand.Name, 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, if card.scored then "Tonight's Table" else "Tonight's Table · Rehearsal", 22, "display", { LayoutOrder = 2 })
	Theme.text(content, dateText(card.key) .. "  ·  " .. (if room then room.name else "") .. " rules", 13, "body", { LayoutOrder = 3, TextColor3 = Brand.Colours.smoke })
	Theme.hairline(content, UDim.new(0, 120), 4)
	Theme.text(content, RoundPanel.number(card.score), 40, "display", { LayoutOrder = 5, TextColor3 = Brand.Colours.bone })
	Hallmark.big(content, card.grade, 6)

	local marks = Instance.new("Frame")
	marks.BackgroundTransparency = 1
	marks.Size = UDim2.new(1, 0, 0, 54)
	marks.LayoutOrder = 7
	marks.Parent = content
	Theme.list(marks, 4, true)
	for i, grade in card.rounds do
		Hallmark.small(marks, Voice.roman(i), grade, i)
	end

	local standing: { string } = {}
	if card.connections then
		table.insert(standing, string.format("%s of %d among your connections", ordinal(card.connections.place), card.connections.of))
	end
	if card.percentile then
		table.insert(standing, if card.percentile <= 50 then string.format("Top %d%% tonight", card.percentile) else string.format("%s of %d tonight", ordinal(card.rank or 0), card.total or 0))
	end
	if not card.scored then
		table.insert(standing, "Rehearsals don't count toward the board.")
	elseif type(card.reason) == "string" and card.reason ~= "" and card.reason ~= "left" then
		table.insert(standing, card.reason)
	end
	for i, text in standing do
		Theme.text(content, text, 14, "body", { LayoutOrder = 7 + i, TextColor3 = Brand.Colours.lightGold })
	end
	if (card.gilt or 0) > 0 then
		Theme.text(content, "+" .. RoundPanel.number(card.gilt) .. " Gilt", 12, "bodyMedium", { LayoutOrder = 12, TextColor3 = Brand.Colours.smoke })
	end

	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 20
	keys.Parent = content
	Theme.list(keys, 8)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 44)
	row.LayoutOrder = 1
	row.Parent = keys
	Theme.list(row, 8, true)
	if Share.allowed() then
		Theme.key(row, "Share", true, share, 150).LayoutOrder = 1
	end
	Theme.key(row, "Invite", false, invite, 150).LayoutOrder = 2
	Theme.key(keys, "Rehearse it", false, function()
		Root.close(NAME)
		actions.rehearse()
	end, 308).LayoutOrder = 2
	Theme.key(keys, "Leave", false, function()
		Root.close(NAME)
		actions.leave()
	end, 308).LayoutOrder = 3
	Root.sticky[NAME] = true
	Root.open(NAME, group, nil, false)
end

return NightlyCard
