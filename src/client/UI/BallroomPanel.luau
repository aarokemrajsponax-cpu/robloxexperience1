--!strict
-- Lights Out's two cards: the one that lands when your lamp goes out (watch from the Gallery,
-- stay for the next evening, or leave), and the evening's result (your place, Keys, the week's
-- points, Gilt). Quick to read and one tap back in: re-entry matters more than anything here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local RoundPanel = require(script.Parent.RoundPanel)
local Theme = require(script.Parent.Theme)
local Share = require(script.Parent.Share)

local BallroomPanel = {}

-- Opens the Boutique's Salutes (set by Main).
BallroomPanel.openSalutes = function() end

local NAME = "Ballroom"

export type Actions = { gallery: () -> (), stay: () -> (), leave: () -> () }

local function ordinal(n: number): string
	local lastTwo = n % 100
	local suffix = "th"
	if lastTwo < 11 or lastTwo > 13 then
		local last = n % 10
		suffix = if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th"
	end
	return tostring(n) .. suffix
end

local function row(parent: Instance, left: string, right: string, order: number)
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 0, 0, 24)
	r.LayoutOrder = order
	r.Parent = parent
	Theme.text(r, left, 15, "body", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0.6, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Brand.Colours.smoke,
	})
	Theme.text(r, right, 15, "bodyMedium", {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromScale(0.6, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Brand.Colours.bone,
	})
end

local function card(caps: string, heading: string, sub: string?, rows: { { string } }, note: string?, actions: Actions, primary: "stay" | "gallery")
	BallroomPanel.close()
	local size = Root.size()
	local w = math.min(420, size.X - 24)
	local h = 300 + #rows * 26 + (if sub then 24 else 0) + (if note then 24 else 0)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h), UDim2.new(0.5, 0, 0.5, 20))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, caps, 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, heading, 24, "display", { LayoutOrder = 2, TextColor3 = Brand.Colours.lightGold })
	if sub then
		Theme.text(content, sub, 14, "body", { LayoutOrder = 3, TextColor3 = Brand.Colours.smoke })
	end
	Theme.hairline(content, UDim.new(0, 120), 4)
	for i, r in rows do
		row(content, r[1], r[2], 4 + i)
	end
	if note then
		Theme.text(content, note, 12, "body", { LayoutOrder = 30, TextColor3 = Brand.Colours.dim })
	end
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 50
	keys.Parent = content
	Theme.list(keys, 8)
	local order: { string } = if primary == "stay" then { "stay", "gallery" } else { "gallery", "stay" }
	for i, id in order do
		local text = if id == "stay" then Voice.Ballroom.nextEvening else Voice.Ballroom.gallery
		local fn: () -> () = if id == "stay" then actions.stay else actions.gallery
		Theme.key(keys, text, i == 1, function()
			BallroomPanel.close()
			fn()
		end, 260).LayoutOrder = i
	end
	if heading == Voice.Ballroom.lastLamp then
		if Share.allowed() then
			Theme.key(keys, "Share", false, function()
				Share.moment("ballroom")
			end, 260).LayoutOrder = 3
		end
		-- The moment to celebrate with the whole house (a Salute: spectacle only).
		Theme.key(keys, "Salute the house", false, function()
			BallroomPanel.close()
			BallroomPanel.openSalutes()
		end, 260).LayoutOrder = 3
	end
	Theme.key(keys, "Leave", false, function()
		BallroomPanel.close()
		actions.leave()
	end, 260).LayoutOrder = 4
	Root.open(NAME, group, nil, false)
	pcall(function()
		game:GetService("GuiService").SelectedObject = keys:FindFirstChildWhichIsA("TextButton")
	end)
end

-- Your lamp is out: the place, and who put it out.
function BallroomPanel.out(message: { [string]: any }, actions: Actions)
	local place = ordinal(message.place or 20)
	local of = tostring(message.of or 20)
	local sub = if type(message.by) == "string"
		then Voice.fill(Voice.Ballroom.outBy, { place = place, of = of, name = message.by })
		else Voice.fill(Voice.Ballroom.outPlace, { place = place, of = of })
	local rows: { { string } } = {}
	if (message.keys or 0) > 0 then
		table.insert(rows, { "Keys you held", tostring(message.keys) })
	end
	card(Voice.Ballroom.title, Voice.Ballroom.outTitle, sub, rows, nil, actions, "gallery")
end

-- The evening's result.
function BallroomPanel.result(message: { [string]: any }, actions: Actions)
	local place = message.place or 20
	local heading = if message.won then Voice.Ballroom.lastLamp else Voice.fill(Voice.Ballroom.place, { place = ordinal(place), of = tostring(message.of or 20) })
	local rows: { { string } } = {
		{ Voice.Ballroom.keys, tostring(message.keys or 0) },
	}
	if message.counted then
		table.insert(rows, { Voice.Ballroom.points, "+" .. RoundPanel.number(message.points or 0) })
	end
	if (message.gilt or 0) > 0 then
		table.insert(rows, { Voice.Ballroom.gilt, "+" .. RoundPanel.number(message.gilt) })
	end
	card(Voice.Ballroom.title, heading, nil, rows, if message.counted then nil elseif game:GetService("Workspace"):GetAttribute("PrivateEvening") == true then Voice.Private.line else Voice.Ballroom.notCountedNote, actions, "stay")
end

function BallroomPanel.close()
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
end

return BallroomPanel
