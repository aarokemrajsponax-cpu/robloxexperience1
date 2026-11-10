--!strict
-- The Maison Basement's best times (at the lectern in the Basement Stair): all time, this week,
-- and among your friends, fastest first, with your own best. Every time is the server's
-- (AttractionAsk "boards"); a run with a skipped stage is never on them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Plan = require(ReplicatedStorage.Shared.Basement)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local BasementPanel = {}

local NAME = "BasementBoard"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local player = Players.LocalPlayer

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function row(parent: Instance, order: number, left: string, right: string, mine: boolean)
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 24)
	f.LayoutOrder = order
	f.Parent = parent
	local colour = if mine then GOLD else C.bone
	local l = Theme.text(f, left, 14, if mine then "bodyBold" else "body", { Name = "Left", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -110, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = colour })
	l.Position = UDim2.fromOffset(0, 0)
	local r = Theme.text(f, right, 14, "bodyBold", { Name = "Right", TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 106, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextColor3 = if mine then GOLD else C.lightGold })
	r.AnchorPoint = Vector2.new(1, 0)
	r.Position = UDim2.new(1, 0, 0, 0)
end

function BasementPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local w = Root.panelWidth(480)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 560))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Maison Basement", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "Best Times", 26, "display", { LayoutOrder = 2 })
	local mine = Theme.text(content, "", 13, "bodyBold", { LayoutOrder = 3, TextColor3 = GOLD })
	local which = "all"
	local rows = Instance.new("Frame")
	rows.Name = "Board"
	rows.BackgroundTransparency = 1
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.Size = UDim2.new(1, 0, 0, 0)
	rows.LayoutOrder = 6
	rows.Parent = content
	Theme.list(rows, 0).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "From the foot of the stair to the Treasury. A run with a skipped stage isn't on the boards.", 12, "body", { LayoutOrder = 7, TextColor3 = C.smoke })
	local function load()
		clear(rows)
		Theme.text(rows, "One moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
		local asked = which
		task.spawn(function()
			local ok, r = pcall(function()
				return Remotes.func("AttractionAsk"):InvokeServer({ op = "act", id = "basement", act = "boards", what = asked })
			end)
			if not group.Parent or asked ~= which then
				return
			end
			clear(rows)
			if not ok or type(r) ~= "table" or r.ok ~= true then
				Theme.text(rows, "The boards couldn't be read just now. Try again in a moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
				return
			end
			local best = tonumber(if which == "week" then r.weekBest else r.best)
			mine.Text = if best then (if which == "week" then "Your best this week: " else "Your best: ") .. Plan.clock(best) else "No time of yours yet: run it to the Treasury."
			local entries = if type(r.entries) == "table" then r.entries else {}
			if #entries == 0 then
				Theme.text(rows, if which == "friends" then "None of your friends has a time yet." else "Nobody has a time here yet.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
				return
			end
			for i, e in entries do
				if i > 15 then
					break
				end
				row(rows, i, string.format("%d.  %s", i, tostring(e.name)), Plan.clock(tonumber(e.score) or 0), e.userId == player.UserId)
			end
		end)
	end
	local tabs = Theme.tabs(content, { { "all", "All time" }, { "week", "This week" }, { "friends", "Friends" } }, which, function(id: string)
		which = id
		load()
	end, 5)
	tabs.select(which)
	load()
	local close = Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 20
	Root.open(NAME, group)
end

function BasementPanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

return BasementPanel
