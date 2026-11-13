--!strict
-- Lights Out's two cards, dressed for the street: graphite glass, a neon edge, the house's gold.
--   * Your lamp goes out: the bulb flickers and dies and a thread of smoke rises, the place you
--     finished stands big ("4th of 20"), then who or what put it out, the Keys you held and how
--     many lamps are still lit; watch from the Gallery, stay for the next evening, or leave.
--   * The evening's result: your place, or the last lamp crowned (its rays turning, the pot
--     counted up, confetti); the evening's top three on a podium, as the server sent them; your
--     Keys, your points this week and the pot.
-- Quick to read and one tap back in: re-entry matters more than anything here. Everything on it is
-- the server's (BallroomService): nothing here decides a place, a point or a coin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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

local rgb = Color3.fromRGB
local NEON = rgb(255, 70, 170)
local ICE = rgb(120, 220, 255)
local GRAPHITE = rgb(16, 15, 20)
local WARM = rgb(255, 214, 140)
local ASH = rgb(70, 70, 78)
local GOLDS = { rgb(255, 244, 210), rgb(240, 204, 120), rgb(198, 148, 64) }
local PODIUM: { [number]: { Color3 } } = {
	[1] = { rgb(255, 236, 170), rgb(222, 172, 76) },
	[2] = { rgb(236, 240, 248), rgb(150, 158, 172) },
	[3] = { rgb(240, 186, 140), rgb(170, 104, 62) },
}

-- The evening's standings (its end, as the server told the whole room), for the podium.
type Standing = { name: string, place: number, keys: number }
local standings: { Standing } = {}

function BallroomPanel.standings(results: unknown)
	standings = {}
	if type(results) ~= "table" then
		return
	end
	for _, r in results :: { any } do
		if type(r) == "table" and type(r.name) == "string" and type(r.place) == "number" then
			table.insert(standings, { name = r.name, place = r.place, keys = if type(r.keys) == "number" then r.keys else 0 })
		end
	end
	table.sort(standings, function(a: Standing, b: Standing): boolean
		return a.place < b.place
	end)
end

local function ordinal(n: number): string
	local lastTwo = n % 100
	local suffix = "th"
	if lastTwo < 11 or lastTwo > 13 then
		local last = n % 10
		suffix = if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th"
	end
	return tostring(n) .. suffix
end

local function small(): boolean
	local s = Root.size()
	return s.Y < 520 or s.X < 760
end

local function frame(parent: Instance, name: string, size: UDim2, colour: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour or GRAPHITE
	f.BackgroundTransparency = if colour then (transparency or 0) else 1
	f.Parent = parent
	return f
end

local function round(f: GuiObject, r: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0.5, 0)
	c.Parent = f
end

local function stroke(f: GuiObject, colour: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	return s
end

local function gradient(f: GuiObject, colours: { Color3 }, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = Theme.sequence(colours)
	g.Rotation = rotation or 90
	g.Parent = f
	return g
end

local function tween(o: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, repeats: number?, reverses: boolean?)
	local t = TweenService:Create(o, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, repeats or 0, reverses or false), goal)
	t:Play()
	return t
end

-- The lamp: a bulb under a graphite shade with a neon rim. "out": it flickers and dies, and a thread
-- of smoke rises from it. "won": lit gold, with rays turning behind it. "place": steady and warm.
local function lamp(parent: Instance, kind: "out" | "won" | "place", px: number, order: number)
	local holder = frame(parent, "Lamp", UDim2.new(1, 0, 0, px + 10))
	holder.LayoutOrder = order
	local stage = frame(holder, "Stage", UDim2.fromOffset(px, px))
	stage.AnchorPoint = Vector2.new(0.5, 0)
	stage.Position = UDim2.new(0.5, 0, 0, 4)
	if kind == "won" then
		local rays = frame(stage, "Rays", UDim2.fromScale(1.7, 1.7))
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Position = UDim2.fromScale(0.5, 0.58)
		for i = 0, 7 do
			local ray = frame(rays, "Ray", UDim2.new(0.07, 0, 1, 0), GOLDS[2], 0.55)
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Rotation = i * 22.5
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
			g.Rotation = 90
			g.Parent = ray
		end
		tween(rays, 9, { Rotation = 360 }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	end
	local glow = frame(stage, "Glow", UDim2.fromScale(1.05, 1.05), if kind == "out" then WARM else (if kind == "won" then GOLDS[1] else WARM), 0.72)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.6)
	round(glow)
	local bulb = frame(stage, "Bulb", UDim2.fromScale(0.5, 0.5), if kind == "won" then GOLDS[2] else WARM, 0)
	bulb.AnchorPoint = Vector2.new(0.5, 0.5)
	bulb.Position = UDim2.fromScale(0.5, 0.6)
	round(bulb)
	gradient(bulb, if kind == "won" then GOLDS else { rgb(255, 246, 220), WARM }, 90)
	local shade = frame(stage, "Shade", UDim2.fromScale(0.78, 0.26), GRAPHITE, 0)
	shade.AnchorPoint = Vector2.new(0.5, 0)
	shade.Position = UDim2.fromScale(0.5, 0.06)
	round(shade, UDim.new(0.4, 0))
	stroke(shade, if kind == "won" then GOLDS[2] else NEON, 2)
	if kind == "won" then
		tween(glow, 0.9, { BackgroundTransparency = 0.45, Size = UDim2.fromScale(1.25, 1.25) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	elseif kind == "out" then
		-- Flicker, flicker, gone: then the bulb is ash and smoke rises from it.
		task.spawn(function()
			for _, step in { { 0.75, 0.07 }, { 0.1, 0.09 }, { 0.85, 0.06 }, { 0.25, 0.12 }, { 0.92, 0.08 }, { 0.5, 0.1 } } do
				if not holder.Parent then
					return
				end
				bulb.BackgroundTransparency = step[1]
				glow.BackgroundTransparency = 0.72 + step[1] * 0.28
				task.wait(step[2])
			end
			bulb.BackgroundTransparency = 0
			bulb.BackgroundColor3 = ASH
			local g = bulb:FindFirstChildOfClass("UIGradient")
			if g then
				g.Color = Theme.sequence({ rgb(96, 96, 104), ASH })
			end
			glow.BackgroundTransparency = 1
			local rim = shade:FindFirstChildOfClass("UIStroke")
			if rim then
				tween(rim, 0.6, { Transparency = 0.6 })
			end
			while holder.Parent do
				local puff = frame(stage, "Smoke", UDim2.fromScale(0.16, 0.16), rgb(190, 190, 200), 0.45)
				puff.AnchorPoint = Vector2.new(0.5, 0.5)
				puff.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.12, 0.42)
				round(puff)
				tween(puff, 1.6, { Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.5, -0.35), Size = UDim2.fromScale(0.42, 0.42), BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
				task.delay(1.7, function()
					puff:Destroy()
				end)
				task.wait(0.55)
			end
		end)
	end
end

-- Small boxes of what the evening came to: a caps name over its figure.
type Chip = { label: string, value: string, colour: Color3? }
local function chip(label: string, value: string, colour: Color3?): Chip
	return { label = label, value = value, colour = colour }
end

local function chips(parent: Instance, list: { Chip }, order: number)
	if #list == 0 then
		return
	end
	-- (Each box as wide as its own words, measured: the same on every screen.)
	local row = frame(parent, "Chips", UDim2.new(1, 0, 0, 48))
	row.LayoutOrder = order
	local l = Theme.list(row, 8, true)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	for i, c in list do
		local wide = math.max(Theme.measureAs(c.label, 10, "caps").X, Theme.measureAs(c.value, 18, "display").X)
		local box = frame(row, "Chip", UDim2.fromOffset(math.ceil(wide) + 30, 46), GRAPHITE, 0.08)
		box.LayoutOrder = i
		round(box, UDim.new(0, 10))
		stroke(box, c.colour or NEON, 1.5, 0.35)
		Theme.text(box, c.label, 10, "caps", {
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 14),
			TextColor3 = Brand.Colours.smoke,
			TextWrapped = false,
		})
		Theme.text(box, c.value, 18, "display", {
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 22),
			TextColor3 = c.colour or Brand.Colours.bone,
			TextWrapped = false,
		})
	end
end

-- The evening's top three on a podium (second, first, third), the guest's own name in neon.
local function podium(parent: Instance, order: number)
	if #standings < 2 then
		return
	end
	local me = Players.LocalPlayer
	local tight = small()
	local width = if tight then 92 else 112
	local heights = { [1] = if tight then 52 else 66, [2] = if tight then 38 else 48, [3] = if tight then 28 else 36 }
	local row = frame(parent, "Podium", UDim2.new(1, 0, 0, heights[1] + 52))
	row.LayoutOrder = order
	local l = Theme.list(row, 10, true)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Bottom
	for slot, place in { 2, 1, 3 } do
		local s = standings[place]
		if s then
			local col = frame(row, "Place" .. place, UDim2.fromOffset(width, heights[place] + 52))
			col.LayoutOrder = slot
			local you = s.name == me.DisplayName or s.name == me.Name
			Theme.text(col, s.name, 13, "bodyBold", {
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.new(1, 0, 0, 18),
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = if you then NEON else Brand.Colours.bone,
			})
			Theme.text(col, if you then "YOU · " .. s.keys .. " KEYS" else s.keys .. (if s.keys == 1 then " KEY" else " KEYS"), 10, "caps", {
				AutomaticSize = Enum.AutomaticSize.None,
				Position = UDim2.fromOffset(0, 19),
				Size = UDim2.new(1, 0, 0, 14),
				TextWrapped = false,
				TextColor3 = if you then NEON else Brand.Colours.dim,
			})
			local block = frame(col, "Block", UDim2.new(1, 0, 0, 0), PODIUM[place][1], 0)
			block.AnchorPoint = Vector2.new(0, 1)
			block.Position = UDim2.fromScale(0, 1)
			round(block, UDim.new(0, 6))
			gradient(block, PODIUM[place], 90)
			if you then
				stroke(block, NEON, 2)
			end
			Theme.text(block, tostring(place), 20, "display", {
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.fromScale(1, 1),
				TextColor3 = rgb(28, 20, 8),
			})
			-- (Up from the floor, second and third a beat behind the winner.)
			task.delay(if place == 1 then 0.15 else 0.35 + place * 0.08, function()
				if block.Parent then
					tween(block, 0.45, { Size = UDim2.new(1, 0, 0, heights[place]) }, Enum.EasingStyle.Back)
				end
			end)
		end
	end
end

-- The pot, counted up to what was paid (the figure itself is the server's).
local function countUp(label: TextLabel, to: number, suffix: string)
	label.Text = "+" .. RoundPanel.number(to) .. suffix
	task.spawn(function()
		local start = os.clock()
		local seconds = 1.1
		while label.Parent do
			local t = math.min(1, (os.clock() - start) / seconds)
			local eased = 1 - (1 - t) ^ 3
			label.Text = "+" .. RoundPanel.number(math.floor(to * eased + 0.5)) .. suffix
			if t >= 1 then
				break
			end
			task.wait(0.03)
		end
		label.Text = "+" .. RoundPanel.number(to) .. suffix
	end)
end

-- Confetti over the card: gold, neon and ice, falling and turning, gone in a few seconds.
local function confetti(group: Frame)
	local colours = { GOLDS[2], NEON, ICE, GOLDS[1] }
	for i = 1, 30 do
		local bit = frame(group, "Confetti", UDim2.fromOffset(math.random(5, 8), math.random(9, 14)), colours[(i % #colours) + 1], 0)
		bit.ZIndex = 20
		bit.Position = UDim2.new(math.random(), 0, 0, -math.random(10, 60))
		bit.Rotation = math.random(0, 180)
		local fall = math.random(220, 420)
		tween(bit, 1.6 + math.random() * 1.2, { Position = bit.Position + UDim2.fromOffset(math.random(-40, 40), fall), Rotation = bit.Rotation + math.random(180, 540), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(3.2, function()
			bit:Destroy()
		end)
	end
end

type Card = {
	kind: "out" | "won" | "place",
	caps: string,
	heading: string,
	big: string?,
	sub: string?,
	chips: { Chip },
	note: string?,
	gilt: number?,
	primary: "stay" | "gallery",
}

local function card(c: Card, actions: Actions)
	BallroomPanel.close()
	local tight = small()
	local w = Root.panelWidth(if tight then 400 else 460)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 420), UDim2.new(0.5, 0, 0.5, -14))
	Theme.fitHeight(group, content)
	Theme.list(content, if tight then 6 else 8).VerticalAlignment = Enum.VerticalAlignment.Top

	-- The street edge: a neon line across the top of the glass, pink into ice.
	local edge = frame(content, "NeonEdge", UDim2.new(1, 0, 0, 3), NEON, 0)
	edge.LayoutOrder = 0
	round(edge, UDim.new(1, 0))
	gradient(edge, if c.kind == "won" then { GOLDS[3], GOLDS[1], GOLDS[3] } else { NEON, ICE }, 0)

	lamp(content, c.kind, if tight then 48 elseif c.kind == "out" then 70 else 58, 1)
	local capsColour = if c.kind == "out" then NEON elseif c.kind == "won" then GOLDS[2] else ICE
	Theme.text(content, c.caps, 11, "caps", { LayoutOrder = 2, TextColor3 = capsColour })
	local heading = Theme.text(content, c.heading, if tight then 21 else 25, "display", { LayoutOrder = 3, TextColor3 = rgb(255, 255, 255) })
	gradient(heading, if c.kind == "won" then GOLDS else { rgb(255, 255, 255), Brand.Colours.lightGold }, 90)
	if c.big then
		local big = Theme.text(content, c.big, if tight then 34 else 44, "display", { LayoutOrder = 4, TextColor3 = rgb(255, 255, 255) })
		gradient(big, GOLDS, 90)
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = big
		tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if c.gilt and c.gilt > 0 then
		local pot = Theme.text(content, "", if tight then 28 else 34, "display", { LayoutOrder = 5, TextColor3 = rgb(255, 255, 255) })
		gradient(pot, GOLDS, 90)
		countUp(pot, c.gilt, " Gilt")
	end
	if c.sub then
		Theme.text(content, c.sub, 14, "body", { LayoutOrder = 6, TextColor3 = Brand.Colours.smoke })
	end
	chips(content, c.chips, 7)
	if c.kind ~= "out" then
		podium(content, 8)
	end
	if c.note then
		Theme.text(content, c.note, 12, "body", { LayoutOrder = 30, TextColor3 = Brand.Colours.dim })
	end

	-- The keys: the one that matters most, wide, then the rest two to a row (so even the last
	-- lamp's card, with Share and Salute, stays inside a small screen).
	local keys = frame(content, "Keys", UDim2.new(1, 0, 0, 0))
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.LayoutOrder = 50
	Theme.list(keys, 8).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local order: { string } = if c.primary == "stay" then { "stay", "gallery" } else { "gallery", "stay" }
	local function go(id: string): () -> ()
		local fn: () -> () = if id == "stay" then actions.stay else actions.gallery
		return function()
			BallroomPanel.close()
			fn()
		end
	end
	local function label(id: string): string
		return if id == "stay" then Voice.Ballroom.nextEvening else Voice.Ballroom.gallery
	end
	Theme.key(keys, label(order[1]), true, go(order[1]), math.min(320, w - 48)).LayoutOrder = 1
	local more = frame(keys, "More", UDim2.new(1, 0, 0, 0))
	more.AutomaticSize = Enum.AutomaticSize.Y
	more.LayoutOrder = 2
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.CellSize = UDim2.new(0.5, -4, 0, 44)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = more
	local half = math.floor((w - 56) / 2)
	Theme.key(more, label(order[2]), false, go(order[2]), half).LayoutOrder = 1
	if c.kind == "won" then
		if Share.allowed() then
			Theme.key(more, "Share", false, function()
				Share.moment("ballroom")
			end, half).LayoutOrder = 2
		end
		-- The moment to celebrate with the whole house (a Salute: spectacle only).
		Theme.key(more, "Salute the house", false, function()
			BallroomPanel.close()
			BallroomPanel.openSalutes()
		end, half).LayoutOrder = 3
	end
	Theme.key(more, "Leave", false, function()
		BallroomPanel.close()
		actions.leave()
	end, half).LayoutOrder = 4

	-- In: up from a little smaller, with a bounce; the winner's confetti a moment after.
	local pop = Instance.new("UIScale")
	pop.Scale = 0.9
	pop.Parent = group
	tween(pop, 0.38, { Scale = 1 }, Enum.EasingStyle.Back)
	if c.kind == "won" then
		task.delay(0.25, function()
			if group.Parent then
				confetti(group)
			end
		end)
	end
	Root.open(NAME, group, nil, false)
	pcall(function()
		Theme.select(keys:FindFirstChildWhichIsA("TextButton"))
	end)
end

-- Your lamp is out: the place, and who or what put it out.
function BallroomPanel.out(message: { [string]: any }, actions: Actions)
	local place = if type(message.place) == "number" then message.place else 20
	local of = if type(message.of) == "number" then message.of else 20
	local why = if type(message.by) == "string"
		then Voice.fill(Voice.Ballroom.outByName, { name = message.by })
		elseif message.reason == "over" then Voice.Ballroom.outOver
		else nil
	local list: { Chip } = {}
	if (message.keys or 0) > 0 then
		table.insert(list, chip("Keys you held", tostring(message.keys), Brand.Colours.lightGold))
	end
	if place > 1 then
		table.insert(list, chip("Still lit", tostring(place - 1), ICE))
	end
	card({
		kind = "out",
		caps = Voice.Ballroom.title,
		heading = Voice.Ballroom.outTitle,
		big = Voice.fill(Voice.Ballroom.outPlace, { place = ordinal(place), of = tostring(of) }),
		sub = why,
		chips = list,
		primary = "gallery",
	}, actions)
end

-- The evening's result.
function BallroomPanel.result(message: { [string]: any }, actions: Actions)
	local place = if type(message.place) == "number" then message.place else 20
	local won = message.won == true
	local list: { Chip } = { chip(Voice.Ballroom.keys, tostring(message.keys or 0), Brand.Colours.lightGold) }
	if message.counted then
		table.insert(list, chip(Voice.Ballroom.points, "+" .. RoundPanel.number(message.points or 0), ICE))
	end
	-- One winner takes the whole pot: yours (counted up above), or what it was.
	if not won and type(message.pot) == "number" then
		table.insert(list, chip(Voice.Ballroom.pot, RoundPanel.number(message.pot) .. " Gilt", GOLDS[2]))
	end
	local note = if message.counted then nil elseif Workspace:GetAttribute("PrivateEvening") == true then Voice.Private.line else Voice.Ballroom.notCountedNote
	card({
		kind = if won then "won" else "place",
		caps = if won then Voice.Ballroom.lastLampCaps else Voice.Ballroom.title,
		heading = if won then Voice.Ballroom.lastLamp else Voice.Ballroom.resultTitle,
		big = if won then nil else Voice.fill(Voice.Ballroom.place, { place = ordinal(place), of = tostring(message.of or 20) }),
		gilt = if won then message.gilt else nil,
		sub = if won then nil else Voice.Ballroom.onlyLast,
		chips = list,
		note = note,
		primary = "stay",
	}, actions)
end

function BallroomPanel.close()
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
end

return BallroomPanel
