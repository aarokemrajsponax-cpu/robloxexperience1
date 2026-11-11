--!strict
-- The first time a guest goes into one of the house's games, or walks into the Vault, a short card
-- of how it works: three lines (shared/Directory). Once, ever: the server keeps the note
-- (Attractions' "entered" says whether it's the first time; AttractionAsk "guide" for the Vault),
-- so it never comes back on another visit or another device.
--
-- It stands at the top of the screen under the keys and any attraction's strip, clear of the
-- thumbstick, the jump button and the middle of the screen; only its own Got it key takes a touch,
-- and it goes by itself after a while, when the guest leaves, or when a panel opens over it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Directory = require(ReplicatedStorage.Shared.Directory)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local FirstVisit = {}

local NAME = "FirstVisit"
local C = Brand.Colours
local STAY = 22 -- seconds it stays, unless put away sooner
local NEXT_CARD = 300 -- the what-to-do-next card's width, at the top right (UI/Objective)

local current: Frame? = nil
local token = 0

function FirstVisit.hide()
	local card = current
	if not card then
		return
	end
	current = nil
	card:Destroy()
end

function FirstVisit.showing(): boolean
	return current ~= nil
end

-- A card: its glyph and name, "First time here", three short lines in its colour, and Got it.
function FirstVisit.show(name: string, glyph: string, accent: Color3, lines: { string }, seconds: number?)
	FirstVisit.hide()
	token += 1
	local mine = token
	-- (Between the keys down the left and the what-to-do-next card at the top right, where there's
	-- room: never over either.)
	local size = Root.size()
	local left = math.max(12, Root.left + 12)
	local right = size.X - 12 - NEXT_CARD - 12
	local w, cx = math.min(500, size.X - 24), size.X / 2
	if right - left >= 340 then
		w = math.min(500, right - left)
		cx = left + (right - left) / 2
	end
	local top = math.max(66, Root.topClear()) + 8
	local group, content = Theme.glass(Root.hud, NAME, UDim2.fromOffset(w, 200), UDim2.fromOffset(cx, top), Vector2.new(0.5, 0))
	group.ZIndex = 20
	current = group
	local list = Theme.list(content, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.text(content, "First time here  ·  how it works", 11, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.3) })
	local title = Theme.text(content, string.format("%s  %s", glyph, name), 20, "display", {
		Name = "Title",
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, -110, 0, 26),
		TextWrapped = false,
	})
	Theme.fit(title, 20, 14)
	for n, line in lines do
		local row = Instance.new("Frame")
		row.Name = "Line" .. n
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.LayoutOrder = 2 + n
		row.Parent = content
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = accent
		dot.Position = UDim2.fromOffset(2, 7)
		dot.Size = UDim2.fromOffset(6, 6)
		dot.Rotation = 45
		dot.Parent = row
		Theme.text(row, line, 14, "body", {
			Name = "Words",
			Position = UDim2.fromOffset(18, 0),
			Size = UDim2.new(1, -18, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.bone,
		})
	end
	local got = Theme.key(group, "Got it", true, function()
		FirstVisit.hide()
	end, 96)
	got.Name = "GotIt"
	got.AnchorPoint = Vector2.new(1, 0)
	got.Position = UDim2.new(1, -18, 0, 16)
	got.Size = UDim2.fromOffset(96, 36)
	got.ZIndex = 30
	Theme.fitHeight(group, content)
	group.Position = UDim2.fromOffset(cx, top + 10)
	Ease.play(group, Ease.settle, { Position = UDim2.fromOffset(cx, top) })
	task.delay(seconds or STAY, function()
		if token == mine then
			FirstVisit.hide()
		end
	end)
	-- (A panel opened over it puts it away: the panel is what the guest chose to look at.)
	task.spawn(function()
		while token == mine and current == group do
			if Root.isOpen() then
				FirstVisit.hide()
				return
			end
			task.wait(0.5)
		end
	end)
end

-- The first time inside an attraction (the server says so on "entered").
function FirstVisit.attraction(id: string)
	local e = Directory.byAttraction[id]
	if e then
		FirstVisit.show(e.name, e.glyph, e.accent, e.intro)
	end
end

-- The first time somewhere that isn't an attraction (the Vault): the server says whether it is.
function FirstVisit.room(what: string)
	local spec = Directory.Rooms[what]
	if not spec then
		return
	end
	task.spawn(function()
		local ok, r = pcall(function()
			return Remotes.func("AttractionAsk"):InvokeServer({ op = "guide", what = what })
		end)
		if ok and type(r) == "table" and r.ok == true and r.first == true then
			FirstVisit.show(spec.name, spec.glyph, C.gold, spec.lines)
		end
	end)
end

-- Whether the Grand Auction's "how bidding works" is still to be shown (asks the server, which
-- notes it as shown).
function FirstVisit.firstAt(what: string): boolean
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer({ op = "guide", what = what })
	end)
	return ok and type(r) == "table" and r.ok == true and r.first == true
end

return FirstVisit
