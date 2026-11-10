--!strict
-- Start here: for a guest still new to the house, once, just after the welcome. The whole game in
-- three plain steps (meet the Concierge, sit at a table, sort the treasures), and two keys: Show
-- me the way (the gold arrow leads to the Concierge, who shows them round) and Straight to a
-- table. It waits if anything else is on the screen, and never opens at a table. (On a phone on its
-- side the steps stand side by side on a wider card: it fits, keys and all, without scrolling.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local StartHere = {}

local NAME = "StartHere"
local C = Brand.Colours

-- Set by Main: whether the guest is busy (at a table, on the tour), and what the two keys do.
StartHere.isBusy = function(): boolean
	return false
end
StartHere.showWay = function() end
StartHere.toTable = function() end

local shown = false

-- A screen shorter than this (in the UI's own units: a phone on its side) has the three steps side
-- by side on a wider card, so the card fits without scrolling and its keys are never out of sight.
local SHORT = 560

-- One step: its number in a gold ring, its title, its line.
local function step(parent: Instance, n: number, title: string, line: string): Frame
	local row = Instance.new("Frame")
	row.Name = "Step" .. n
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Size = UDim2.new(1, 0, 0, 0)
	row.LayoutOrder = 2 + n
	row.Parent = parent
	local ring = Instance.new("TextLabel")
	ring.Name = "Number"
	ring.Size = UDim2.fromOffset(30, 30)
	ring.BackgroundColor3 = Color3.fromRGB(28, 24, 18)
	ring.FontFace = Brand.Fonts.figures
	ring.TextSize = 16
	ring.TextColor3 = C.lightGold
	ring.Text = tostring(n)
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local rs = Instance.new("UIStroke")
	rs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rs.Color = C.gold
	rs.Transparency = 0.2
	rs.Thickness = 1.25
	rs.Parent = ring
	ring.Parent = row
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(44, 0)
	words.AutomaticSize = Enum.AutomaticSize.Y
	words.Size = UDim2.new(1, -44, 0, 0)
	words.Parent = row
	local list = Theme.list(words, 2)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.text(words, title, 16, "bodyBold", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.bone })
	Theme.text(words, line, 14, "body", {
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.smoke,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	return row
end

function StartHere.open()
	if Root.isOpen(NAME) then
		return
	end
	local S = Voice.StartHere
	local short = Root.size().Y < SHORT
	local w = Root.panelWidth(if short then 880 else 520)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 420))
	local list = Theme.list(content, if short then 10 else 12)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, S.title, 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, S.heading, 24, "display", { LayoutOrder = 2 })
	local inner = w - 48
	-- (Side by side when the screen is short and the card wide enough for three columns.)
	local across = short and inner >= 600
	local steps: Instance = content
	if across then
		local row = Instance.new("Frame")
		row.Name = "Steps"
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.LayoutOrder = 3
		row.Parent = content
		Theme.list(row, 16, true).VerticalAlignment = Enum.VerticalAlignment.Top
		steps = row
	end
	for n, s in S.steps do
		local row = step(steps, n, s.title, if across then s.short or s.line else s.line)
		if across then
			row.Size = UDim2.new(0, math.floor((inner - 32) / 3), 0, 0)
		end
	end
	Theme.text(content, S.after, 14, "body", { LayoutOrder = 10, TextColor3 = C.lightGold, TextWrapped = true })
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 11
	keys.Parent = content
	local kl = Theme.list(keys, 10, true)
	kl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(keys, S.go, true, function()
		Root.close(NAME)
		StartHere.showWay()
	end, math.min(220, math.floor(inner / 2) - 5)).LayoutOrder = 1
	Theme.key(keys, S.table, false, function()
		Root.close(NAME)
		StartHere.toTable()
	end, math.min(220, math.floor(inner / 2) - 5)).LayoutOrder = 2
	Theme.fitHeight(group, content)
	Root.open(NAME, group)
end

-- On arrival: once a session, only if nothing else is on the screen (it waits a little for that).
function StartHere.offer()
	if shown then
		return
	end
	task.spawn(function()
		for _ = 1, 60 do
			if not Root.isOpen() and not StartHere.isBusy() then
				shown = true
				StartHere.open()
				return
			end
			task.wait(0.5)
		end
	end)
end

function StartHere.isOpen(): boolean
	return Root.isOpen(NAME)
end

return StartHere
