--!strict
-- Circles at the Livre d'Or (§9.7): your Circle and its week (members, points, the five best
-- counted), invitations to guests in the house, and leaving. Without a Circle: ask to join the
-- Circle of someone here, or found one by choosing its words and crest (never typed).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Circle = require(ReplicatedStorage.Shared.Circle)
local Root = require(script.Parent.Root)
local RoundPanel = require(script.Parent.RoundPanel)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Closet = require(script.Parent.Parent.Closet)

local CirclePanel = {}

local NAME = "Circles"
local OFFER = "CircleOffer"

local function crestText(emblem: number, colour: number): (string, Color3)
	return Circle.Emblems[emblem] or "", Circle.Colours[colour] or Brand.Colours.gold
end

-- A row with a label and one key.
local function row(parent: Instance, order: number, text: string, keyText: string?, onPress: (() -> ())?)
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 0, 0, 38)
	r.LayoutOrder = order
	r.Parent = parent
	Theme.text(r, text, 14, "body", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(if keyText then 0.62 else 1, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Brand.Colours.bone,
	})
	if keyText and onPress then
		local k = Theme.key(r, keyText, false, onPress, 150)
		k.AnchorPoint = Vector2.new(1, 0)
		k.Position = UDim2.new(1, 0, 0, 0)
	end
end

-- A chooser: ‹ value › cycling through a list.
local function chooser(parent: Instance, order: number, label: string, values: { string }, start: number, onChange: (number) -> ())
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 0, 0, 40)
	r.LayoutOrder = order
	r.Parent = parent
	Theme.text(r, label, 13, "caps", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.3, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local index = start
	local value = Theme.text(r, values[index], 16, "display", {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.new(0.3, 44, 0, 0),
		Size = UDim2.new(0.7, -88, 1, 0),
		TextColor3 = Brand.Colours.lightGold,
	})
	local function step(d: number)
		index = (index - 1 + d) % #values + 1
		value.Text = values[index]
		onChange(index)
	end
	local prev = Theme.key(r, "‹", false, function()
		step(-1)
	end, 40)
	prev.Position = UDim2.new(0.3, 0, 0, 0)
	local nextKey = Theme.key(r, "›", false, function()
		step(1)
	end, 40)
	nextKey.AnchorPoint = Vector2.new(1, 0)
	nextKey.Position = UDim2.new(1, 0, 0, 0)
end

function CirclePanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(520, size.X - 24)
	local h = math.min(600, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local title = Theme.text(content, "Circles", 26, "display", { LayoutOrder = 1 })
	Theme.hairline(content, UDim.new(0, 90), 2)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 3
	scroll.Size = UDim2.new(1, 0, 1, -(26 + 12 + 44 + 30))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Brand.Colours.gold
	scroll.Parent = content
	Theme.list(scroll, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll
	Theme.text(scroll, "One moment...", 14, "body", { LayoutOrder = 1, TextColor3 = Brand.Colours.dim })

	local fill: (v: { [string]: any }) -> ()
	local function reload()
		task.spawn(function()
			local v = Closet.ask({ op = "circle" })
			if type(v) == "table" and content.Parent then
				fill(v)
			end
		end)
	end
	local function after(r: any, done: string?)
		if type(r) == "table" and r.ok then
			if done then
				Toast.show("Circles", done, 3)
			end
			reload()
		elseif type(r) == "table" then
			Toast.show("Circles", tostring(r.why), 3)
		end
	end

	fill = function(v: { [string]: any })
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local order = 0
		local function add(): number
			order += 1
			return order
		end
		if not v.enabled then
			Theme.text(scroll, "Circles open soon.", 15, "body", { LayoutOrder = add(), TextColor3 = Brand.Colours.dim })
			return
		end
		local c = v.circle
		if c then
			local glyph, colour = crestText(c.emblem, c.colour)
			title.Text = c.name
			Theme.text(scroll, glyph, 40, "display", { LayoutOrder = add(), TextColor3 = colour })
			Theme.text(scroll, string.format("This week: %s points  ·  the five best count", RoundPanel.number(c.score or 0)), 13, "caps", { LayoutOrder = add() })
			for _, m in c.members do
				row(scroll, add(), string.format("%s%s  —  %s", m.name, if m.host then " (host)" else "", RoundPanel.number(m.points or 0)))
			end
			if #c.members < (v.max or 20) and #(v.guests or {}) > 0 then
				Theme.text(scroll, "Invite a guest in the house", 11, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
				for _, g in v.guests do
					row(scroll, add(), g.name, "Invite", function()
						after(Closet.ask({ op = "circleInvite", userId = g.userId }), "Invitation sent to " .. g.name .. ".")
					end)
				end
			end
			row(scroll, add(), "Points come from the Nightly, ranked wins in the Library and counted Ballroom evenings.", nil, nil)
			row(scroll, add(), "", "Leave the Circle", function()
				after(Closet.ask({ op = "circleLeave" }), "You've left the Circle.")
			end)
			return
		end
		title.Text = "Circles"
		Theme.text(scroll, "Clubs of up to twenty. A Circle's week is its five best members' points; the top Circles hang on the Tonight board.", 14, "body", { LayoutOrder = add(), TextColor3 = Brand.Colours.smoke, TextWrapped = true })
		if #(v.guests or {}) > 0 then
			Theme.text(scroll, "Ask to join", 11, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
			for _, g in v.guests do
				row(scroll, add(), string.format("%s  ·  %s", g.circle or "", g.name), "Ask", function()
					after(Closet.ask({ op = "circleRequest", userId = g.userId }), "Your request has gone to the host.")
				end)
			end
		end
		Theme.text(scroll, string.format("Found a Circle  ·  %s Gilt", RoundPanel.number(v.foundGilt or 0)), 11, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
		local choice = { adjective = 1, noun = 1, emblem = 1, colour = 1 }
		local preview = Theme.text(scroll, "", 22, "display", { LayoutOrder = add(), TextColor3 = Brand.Colours.lightGold })
		local function show()
			local glyph, colour = crestText(choice.emblem, choice.colour)
			preview.Text = glyph .. "  " .. Circle.name(choice :: any)
			preview.TextColor3 = colour
		end
		chooser(scroll, add(), "Word", v.adjectives, 1, function(i)
			choice.adjective = i
			show()
		end)
		chooser(scroll, add(), "Name", v.nouns, 1, function(i)
			choice.noun = i
			show()
		end)
		local emblems = {}
		for i, e in v.emblems do
			table.insert(emblems, e .. "  " .. (v.emblemNames[i] or ""))
		end
		chooser(scroll, add(), "Emblem", emblems, 1, function(i)
			choice.emblem = i
			show()
		end)
		chooser(scroll, add(), "Colour", v.colourNames, 1, function(i)
			choice.colour = i
			show()
		end)
		show()
		row(scroll, add(), string.format("You have %s Gilt.", RoundPanel.number(v.gilt or 0)), "Found it", function()
			after(Closet.ask({ op = "circleFound", choice = choice }), "Your Circle is founded.")
		end)
	end

	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 20
	keys.Parent = content
	Theme.list(keys, 8)
	local close = Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 300)
	Root.open(NAME, group)
	pcall(function()
		game:GetService("GuiService").SelectedObject = close
	end)
	reload()
end

-- An invitation to a Circle (or, for its host, someone asking to join): yes or no.
function CirclePanel.offer(m: { [string]: any })
	if Root.isOpen(OFFER) then
		Root.close(OFFER)
	end
	local size = Root.size()
	local w = math.min(400, size.X - 24)
	local group, content = Theme.glass(Root.panels, OFFER, UDim2.fromOffset(w, 230))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local glyph, colour = crestText(tonumber(m.emblem) or 1, tonumber(m.colour) or 1)
	Theme.text(content, glyph .. "  " .. tostring(m.name), 22, "display", { LayoutOrder = 1, TextColor3 = colour })
	local line = if m.kind == "request" then tostring(m.fromName) .. " asks to join your Circle." else tostring(m.fromName) .. " invites you to their Circle."
	Theme.text(content, line, 15, "body", { LayoutOrder = 2, TextColor3 = Brand.Colours.bone })
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 3
	keys.Parent = content
	Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function answer(yes: boolean)
		Root.close(OFFER)
		local r = Closet.ask({ op = "circleAnswer", kind = m.kind, circle = m.circle, from = m.from, yes = yes })
		if type(r) == "table" and r.ok and yes and m.kind == "invite" then
			Toast.show("Circles", "Welcome to " .. tostring(r.name or m.name) .. ".", 3)
		elseif type(r) == "table" and not r.ok then
			Toast.show("Circles", tostring(r.why), 3)
		end
	end
	local yes = Theme.key(keys, if m.kind == "request" then "Welcome them" else "Join", true, function()
		answer(true)
	end, 160)
	Theme.key(keys, "Not now", false, function()
		answer(false)
	end, 160)
	Root.open(OFFER, group, nil, false)
	pcall(function()
		game:GetService("GuiService").SelectedObject = yes
	end)
end

return CirclePanel
