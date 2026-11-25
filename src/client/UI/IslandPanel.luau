--!strict
-- The Jet Lounge's card (and the Jet Gallery's desk, and the Pearl Exchange's kiosk): four tabs.
--   The Island      the Island Key: the wealth rank it asks (with the guest's own, ticked or not,
--                   and how far their Fortune has come), both its prices before anyone pays, and
--                   what waits on the island; for a key holder, the jet (Board the jet, in the
--                   Jet Lounge) and today on the island: the pearls, the sunset toast and the
--                   postcards, each with the very Gilt it pays, and Island Standing
--   Liveries        every livery for their jet: its colours, its line, and its price or Wear
--   Island light    the four lights the island can be seen in (each guest's own choice)
--   The Exchange    the island's own pieces for the Suite, for pearls from the lagoon
-- Every figure, price and reward is the server's (AttractionAsk "state": its `rewards` are the
-- sums paid); buying or choosing asks the server, which takes the price or says why not. Robux
-- liveries only open the purchase window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Plan = require(ReplicatedStorage.Shared.Island)
local Craft = require(ReplicatedStorage.Shared.IslandCraft)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local IslandPanel = {}

-- Set by Main: the island's state changed (the HUD and the world redraw).
IslandPanel.changed = function(_state: { [string]: any }) end

local NAME = "IslandCard"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local SEA = Color3.fromRGB(110, 220, 236)
local GREEN = Color3.fromRGB(120, 220, 150)

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else nil
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- A row: a swatch at the left, a name and a line, and a key at the right.
local function row(parent: Instance, order: number, swatch: { Color3 }?, name: string, line: string, keyText: string, primary: boolean, enabled: boolean, onPress: () -> ()): Frame
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = 0.965
	-- (Build 91: tall enough for a three-line description at its own size, the words centred.)
	f.Size = UDim2.new(1, 0, 0, 74)
	f.LayoutOrder = order
	f.Parent = parent
	corner(f, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = f
	local left = 0
	if swatch and #swatch > 0 then
		local sw = Instance.new("Frame")
		sw.Name = "Swatch"
		sw.AnchorPoint = Vector2.new(0, 0.5)
		sw.Position = UDim2.new(0, 0, 0.5, 0)
		sw.Size = UDim2.fromOffset(40, 40)
		sw.BackgroundColor3 = swatch[1]
		sw.Parent = f
		corner(sw, 20)
		local ring = Instance.new("UIStroke")
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Thickness = 3
		ring.Color = swatch[2] or swatch[1]
		ring.Parent = sw
		if swatch[3] then
			local band = Instance.new("Frame")
			band.Name = "Band"
			band.AnchorPoint = Vector2.new(0.5, 0.5)
			band.Position = UDim2.fromScale(0.5, 0.5)
			band.Size = UDim2.new(1, -8, 0, 5)
			band.BackgroundColor3 = swatch[3]
			band.BorderSizePixel = 0
			band.Parent = sw
		end
		left = 52
	end
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(left, 0)
	words.Size = UDim2.new(1, -(left + 154), 1, 0)
	words.Parent = f
	Theme.list(words, 1).VerticalAlignment = Enum.VerticalAlignment.Center
	Theme.text(words, name, 14, "bodyBold", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd })
	Theme.text(words, line, 12, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	local key = Theme.key(f, keyText, primary and enabled, function()
		if enabled then
			onPress()
		end
	end, 144)
	key.AnchorPoint = Vector2.new(1, 0.5)
	key.Position = UDim2.new(1, 0, 0.5, 0)
	if not enabled then
		key.Active = false
		key.AutoButtonColor = false
	end
	return f
end

local function price(gilt: number?, gems: number?): string
	if gems and gems > 0 then
		return string.format("%d Gems", gems)
	elseif gilt and gilt > 0 then
		return Rules.format(gilt) .. " Gilt"
	end
	return "Free"
end

-- (Build 103) A slim bar, filled to `fraction`.
local function bar(parent: Instance, order: number, fraction: number, colour: Color3): Frame
	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.BackgroundColor3 = Color3.fromRGB(58, 48, 34)
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, 8)
	track.LayoutOrder = order
	track.Parent = parent
	corner(track, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = colour
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	fill.Parent = track
	corner(fill, 4)
	return track
end

-- A figure from the server's state, or nil.
local function figure(t: any, key: string): number?
	if type(t) ~= "table" then
		return nil
	end
	local v = tonumber(t[key])
	return if v and v >= 0 then v else nil
end

function IslandPanel.open(which: string?)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local size = Root.size()
	local w = Root.panelWidth(580)
	local h = math.min(640, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Jet Lounge", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "Luxury Island", 26, "display", { LayoutOrder = 2 })
	local tabId = if which == "liveries" or which == "light" or which == "exchange" or which == "rides" then which else "island"
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.LayoutOrder = 4
	body.Size = UDim2.new(1, 0, 1, -(18 + 34 + 46 + 52 + 32))
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = C.gold
	body.Parent = content
	Theme.list(body, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local bpad = Instance.new("UIPadding")
	bpad.PaddingRight = UDim.new(0, 8)
	bpad.Parent = body

	local state: { [string]: any }? = nil
	local fill: () -> ()
	local busy = false
	local function act(request: { [string]: any }, done: string?)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			request.op, request.id = "act", "island"
			local r = ask(request)
			busy = false
			if not r then
				Toast.show("Not just now", "The house couldn't be reached. Try again in a moment.", 3)
			elseif r.ok ~= true then
				if r.prompted then
					return -- (the purchase window is open; its price is in it)
				end
				Toast.refused(r)
			else
				Theme.haptic()
				Toast.show(tostring(r.title or done or "Done"), tostring(r.line or ""), 3)
				if type(r.state) == "table" then
					state = r.state
					IslandPanel.changed(r.state)
					if group.Parent then
						fill()
					end
				end
			end
		end)
	end

	-- (Build 103) Boarding the jet from the card, standing in the Jet Lounge: the server takes them
	-- (or says why not), and the flight begins on this screen when it does.
	local function board()
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local r = ask({ op = "go", id = "island" })
			busy = false
			if not r then
				Toast.show("Not just now", "The house couldn't be reached. Try again in a moment.", 3)
			elseif r.ok == true then
				if Root.isOpen(NAME) then
					Root.close(NAME)
				end
			else
				Toast.refused(r)
			end
		end)
	end

	-- A paragraph of the card's body.
	local function para(order: number, text: string, size: number, kind: string, colour: Color3?): TextLabel
		return Theme.text(body, text, size, kind :: any, { LayoutOrder = order, TextColor3 = colour or C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	end

	local function islandTab(s: { [string]: any })
		local rw = if type(s.rewards) == "table" then s.rewards else nil
		local pearlGilt, setGilt = figure(rw, "pearl"), figure(rw, "pearlSet")
		local toastGilt, friendGilt = figure(rw, "toast"), figure(rw, "toastFriend")
		local friendsMost, minutes = figure(rw, "toastFriendsMost"), figure(rw, "toastMinutes")
		local cardsGilt = figure(rw, "postcards")
		if s.key then
			para(1, "The island is yours", 18, "display", SEA)
			if s.here == true then
				para(2, "You're on the island. Your jet waits on the airstrip to fly you home, or press Fly home at the foot of the screen.", 13, "body")
			elseif s.lounge == true then
				para(2, "The private jet is ready, here in the Jet Lounge.", 13, "body")
				local go = Theme.key(body, "Board the jet", true, board, 220)
				go.LayoutOrder = 3
			else
				para(2, "Walk through the jet's arch in the Jet Lounge, on the Terrace, to fly.", 13, "body")
			end
			Theme.hairline(body, UDim.new(0, 120), 4)
			Theme.text(body, "Today on the island", 11, "caps", { LayoutOrder = 5, TextXAlignment = Enum.TextXAlignment.Left })
			-- The day's pearls.
			local taken, of = 0, 0
			for _, t in (if type(s.pearlTaken) == "table" then s.pearlTaken else {}) do
				of += 1
				if t then
					taken += 1
				end
			end
			of = math.max(of, Plan.PEARLS_A_DAY)
			para(6, string.format("🐚  Pearls: %d of %d brought up today", taken, of), 14, "bodyBold", if taken >= of then GOLD else C.bone)
			para(7, (if pearlGilt and setGilt then string.format("+%s Gilt for each, and +%s more for all five in a day. ", Rules.format(pearlGilt), Rules.format(setGilt)) else "") .. "They lie on the lagoon's floor, a new five in new places every day, the same for everyone: swim down beside one to bring it up.", 12, "body")
			-- The sunset toast.
			para(8, if s.toasted then "🌅  The sunset: toasted today" else "🌅  The sunset: still to toast, at the Lookout", 14, "bodyBold", if s.toasted then GOLD else C.bone)
			para(9, "Raise a glass at the Sunset Lookout, on the summit (the summit path, by the gardens, takes you up)" .. (if toastGilt and friendGilt and friendsMost and minutes then string.format(": +%s Gilt once a day, and +%s for each friend who toasts within %d minutes of you, up to %d. They have the same for you.", Rules.format(toastGilt), Rules.format(friendGilt), minutes, friendsMost) else "."), 12, "body")
			-- The postcard spots.
			local count, total = tonumber(s.postcardCount) or 0, tonumber(s.postcardTotal) or #Plan.Postcards
			para(10, string.format("📸  Postcards: %d of %d spots", count, total), 14, "bodyBold", if count >= total then GOLD else C.bone)
			local names = {}
			for _, c in (if type(s.postcardList) == "table" then s.postcardList else {}) do
				if type(c) == "table" then
					table.insert(names, (if c.taken then "✓ " else "○ ") .. tostring(c.name))
				end
			end
			local cardsLine = table.concat(names, "    ")
			if s.postcardsPaid == true then
				cardsLine ..= (if #names > 0 then "  ·  " else "") .. "every spot taken"
			elseif cardsGilt then
				cardsLine ..= (if #names > 0 then "  ·  " else "") .. string.format("all six: +%s Gilt and a badge, once", Rules.format(cardsGilt))
			end
			if cardsLine ~= "" then
				para(11, cardsLine, 12, "body")
			end
			if taken >= of and s.toasted then
				para(12, "That's the day done. Tomorrow brings five new pearls in new places, and a new sunset.", 12, "body", SEA)
			end
			Theme.hairline(body, UDim.new(0, 120), 13)
			-- (Build 90) Island Standing: the rank, and how far to the next.
			local st = if type(s.standing) == "table" then s.standing else nil
			if st then
				local points = tonumber(st.points) or 0
				local nextAt = tonumber(st.nextAt)
				local nextLine = if nextAt then string.format("  ·  %d of %d to %s", points, nextAt, tostring(st.nextName or "")) else "  ·  the highest there is"
				para(14, "Island Standing: " .. tostring(st.name or "Visitor") .. nextLine, 13, "bodyBold", Color3.fromRGB(120, 220, 214))
				local here = Plan.Standing[tonumber(st.rank) or 1]
				local from = if here then here.at else 0
				bar(body, 15, if nextAt and nextAt > from then (points - from) / (nextAt - from) else 1, Color3.fromRGB(120, 220, 214))
				para(16, "A pearl is a point, a sunset toasted three, each postcard spot two, each day you fly in one. Each rank pays Gilt once; Islanders earn the Starlit lights and Patrons the Island Patron livery, never sold.", 12, "body")
			end
			para(17, string.format("Pearls kept for the Exchange: %d  ·  brought up in all: %d  ·  flights: %d", tonumber(s.pearlBalance) or 0, tonumber(s.pearlsAll) or 0, tonumber(s.flights) or 0), 12, "body")
			return
		end
		Theme.text(body, "The Island Key", 18, "display", { LayoutOrder = 1, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left })
		Theme.text(body, "The house's private island, by the jet: the villas and their pools, the lagoon's pearls, the Sunset Lookout. The key is yours for good, and it asks two things.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		local rankOk = (tonumber(s.rank) or 1) >= (tonumber(s.keyRank) or 6)
		local rankDef = Rules.Ranks[tonumber(s.keyRank) or 6] or Rules.Ranks[6]
		local mine = Rules.Ranks[tonumber(s.rank) or 1] or Rules.Ranks[1]
		Theme.text(body, string.format("%s  A wealth rank of %s (a Fortune of %s): you're %s", if rankOk then "✓" else "○", rankDef.name, Rules.format(rankDef.at), if rankOk then "there" else "a " .. mine.name .. " now"), 14, "bodyBold", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = if rankOk then GREEN else C.bone })
		-- (Build 103) How far their Fortune has come toward it.
		local fortune = figure(s, "fortune")
		if not rankOk and fortune and rankDef.at > 0 then
			para(4, string.format("Your Fortune: %s of %s", Rules.format(fortune), Rules.format(rankDef.at)), 12, "body")
			bar(body, 5, fortune / rankDef.at, GOLD)
		end
		Theme.text(body, string.format("○  The key itself: %s Gilt, or %d Gems", Rules.format(tonumber(s.keyGilt) or 0), tonumber(s.keyGems) or 0), 14, "bodyBold", { LayoutOrder = 6, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
		local buys = Instance.new("Frame")
		buys.Name = "Buy"
		buys.BackgroundTransparency = 1
		buys.Size = UDim2.new(1, 0, 0, 46)
		buys.LayoutOrder = 7
		buys.Parent = body
		local line = Theme.list(buys, 10, true)
		line.HorizontalAlignment = Enum.HorizontalAlignment.Left
		line.VerticalAlignment = Enum.VerticalAlignment.Center
		local g = Theme.key(buys, Rules.format(tonumber(s.keyGilt) or 0) .. " Gilt", rankOk, function()
			act({ act = "key", what = "gilt" }, "The Island Key")
		end, 170)
		g.LayoutOrder = 1
		local gm = Theme.key(buys, string.format("%d Gems", tonumber(s.keyGems) or 0), false, function()
			act({ act = "key", what = "gems" }, "The Island Key")
		end, 140)
		gm.LayoutOrder = 2
		Theme.text(body, "Your Fortune grows with every haul, every Basement clear and every Executive beaten: the Fortune plaque under your Gilt shows how far.", 12, "body", { LayoutOrder = 8, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		-- (Build 103) What waits there, with the very Gilt each pays (the server's own figures).
		Theme.hairline(body, UDim.new(0, 120), 9)
		Theme.text(body, "On the island", 11, "caps", { LayoutOrder = 10, TextXAlignment = Enum.TextXAlignment.Left })
		local waits = if pearlGilt and setGilt and toastGilt and friendGilt and cardsGilt
			then string.format("Five pearls a day on the lagoon's floor (+%s Gilt each, +%s more for all five), the sunset toast at the Lookout (+%s Gilt a day, +%s for each friend toasting with you), six postcard spots (+%s Gilt once, for all six), Island Standing, and liveries for your own jet.", Rules.format(pearlGilt), Rules.format(setGilt), Rules.format(toastGilt), Rules.format(friendGilt), Rules.format(cardsGilt))
			else "Five pearls a day on the lagoon's floor, the sunset toast at the Lookout (more with friends), six postcard spots, Island Standing, and liveries for your own jet."
		para(11, waits, 12, "body")
	end

	local function liveriesTab(s: { [string]: any })
		Theme.text(body, "Your jet's livery: every one is a look, nothing more. It's worn on your jet on the airstrip and in the cabin as you fly.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		for i, l in (if type(s.liveries) == "table" then s.liveries else {}) do
			local def = Plan.liveryById[tostring(l.id)]
			if def then
				local worn = s.livery == l.id
				local keyText, primary, enabled
				if worn then
					keyText, primary, enabled = "Worn", false, false
				elseif l.owned then
					keyText, primary, enabled = "Wear", true, true
				elseif type(l.standing) == "string" then
					keyText, primary, enabled = l.standing, false, false
				elseif l.product then
					keyText, primary, enabled = if l.onSale then "Robux" else "Not on sale", false, l.onSale == true
				else
					keyText, primary, enabled = price(l.gilt, l.gems), true, true
				end
				local line = def.line .. (if l.product and not l.owned then "  Robux, for good: the window shows its price." elseif type(l.standing) == "string" and not l.owned then "  Earned with Island Standing: " .. l.standing .. "." else "")
				row(body, 1 + i, { def.body, def.trim, def.stripe }, def.name, line, keyText, primary, enabled, function()
					act({ act = "livery", what = def.id }, def.name)
				end)
			end
		end
	end

	local function lightTab(s: { [string]: any })
		Theme.text(body, "The light you see the island in: only your screen sees it. Change it whenever you like.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		local swatches: { [string]: { Color3 } } = {
			golden = { Color3.fromRGB(255, 176, 96), Color3.fromRGB(255, 214, 150) },
			azure = { Color3.fromRGB(70, 170, 230), Color3.fromRGB(220, 240, 255) },
			dawn = { Color3.fromRGB(240, 160, 180), Color3.fromRGB(255, 220, 200) },
			moonlit = { Color3.fromRGB(40, 50, 100), Color3.fromRGB(190, 200, 255) },
			starlit = { Color3.fromRGB(14, 18, 44), Color3.fromRGB(240, 236, 200) },
		}
		for i, t in (if type(s.themes) == "table" then s.themes else {}) do
			local def = Plan.themeById[tostring(t.id)]
			if def then
				local on = s.theme == t.id
				local earned = type(t.standing) == "string" and not t.owned
				local keyText = if on then "Chosen" elseif t.owned then "Choose" elseif earned then t.standing else price(t.gilt, t.gems)
				local line = def.line .. (if earned then "  Earned with Island Standing: " .. t.standing .. "." else "")
				row(body, 1 + i, swatches[def.id] or swatches.golden, def.name, line, keyText, not on and not earned, not on and not earned, function()
					act({ act = "theme", what = def.id }, def.name)
				end)
			end
		end
	end

	local function exchangeTab(s: { [string]: any })
		Theme.text(body, string.format("You have %d pearl%s. Each day's five lie on the lagoon's floor: swim down beside one to bring it up.", tonumber(s.pearlBalance) or 0, if tonumber(s.pearlBalance) == 1 then "" else "s"), 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		for i, e in (if type(s.exchange) == "table" then s.exchange else {}) do
			local enough = (tonumber(s.pearlBalance) or 0) >= (tonumber(e.pearls) or 0)
			row(body, 1 + i, { Color3.fromRGB(246, 238, 228), Color3.fromRGB(214, 190, 170) }, tostring(e.name), tostring(e.line), if e.owned then "Yours" else string.format("%d pearls", tonumber(e.pearls) or 0), not e.owned and enough, not e.owned, function()
				act({ act = "exchange", what = tostring(e.id) }, tostring(e.name))
			end)
		end
	end

	-- (Build 104) The island's rides: the Day Yacht every guest's; the jet ski and the helicopter
	-- yours for good, for Gilt (the price on the key is the price paid) or for Robux (the window
	-- shows its price). Ridden where they wait on the island, never from here.
	local function ridesTab(s: { [string]: any })
		Theme.text(body, "The island's rides are for the fun of it: nothing a ride does pays. The Day Yacht is every guest's; the jet ski and the helicopter are yours for good once bought.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		local rides = if type(s.rides) == "table" then s.rides else {}
		local where = { jetski = "At the Jet Ski Hire on the South Beach.", yacht = "At the marina pier: Take the helm, or Board.", heli = "On the Grand Villa's helipad." }
		local swatch = { jetski = { Color3.fromRGB(246, 246, 242), Color3.fromRGB(22, 40, 78) }, yacht = { Color3.fromRGB(246, 246, 242), Color3.fromRGB(150, 98, 58) }, heli = { Color3.fromRGB(18, 18, 22), Color3.fromRGB(214, 176, 92) } }
		for i, id in Craft.ORDER do
			local k = Craft.KINDS[id]
			local r = if type(rides[id]) == "table" then rides[id] else {}
			local line = k.line .. "  " .. where[id]
			if r.free or r.owned then
				row(body, 1 + i * 2, swatch[id], k.name, line, if r.free then "Free" else "Yours", false, false, function() end)
			else
				row(body, 1 + i * 2, swatch[id], k.name, line, Rules.format(tonumber(k.gilt) or 0) .. " Gilt", true, true, function()
					act({ act = "buyRide", what = id, how = "gilt" }, k.name)
				end)
				row(body, 2 + i * 2, swatch[id], k.name .. ", for Robux", if r.robux then "The same, yours for good: Roblox's window shows its price." else "Not on sale for Robux yet: it's yours for Gilt.", if r.robux then "Robux" else "Not on sale", false, r.robux == true, function()
					act({ act = "buyRide", what = id, how = "robux" }, k.name)
				end)
			end
		end
	end

	fill = function()
		clear(body)
		local s = state
		if not s then
			Theme.text(body, "One moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
			return
		end
		if tabId == "island" then
			islandTab(s)
		elseif tabId == "liveries" then
			liveriesTab(s)
		elseif tabId == "light" then
			lightTab(s)
		elseif tabId == "rides" then
			ridesTab(s)
		else
			exchangeTab(s)
		end
	end

	local tabs = Theme.tabs(content, { { "island", "The Island" }, { "rides", "Rides" }, { "liveries", "Liveries" }, { "light", "Island light" }, { "exchange", "The Exchange" } }, tabId, function(id: string)
		tabId = id
		fill()
	end, 3)
	tabs.select(tabId)
	local close = Theme.key(content, "Close", true, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 20
	fill()
	Theme.fillRest(body)
	Root.open(NAME, group)
	task.spawn(function()
		local r = ask({ op = "state", id = "island" })
		if not group.Parent then
			return
		end
		if r and r.ok == true then
			state = r
			IslandPanel.changed(r)
			fill()
		else
			clear(body)
			Theme.text(body, "The Jet Lounge couldn't be reached just now. Try again in a moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		end
	end)
end

function IslandPanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

return IslandPanel
