--!strict
-- The Vault's display and your Suite (the console under the Vault's four domes, the Curios card,
-- the Suite's bell). Five tabs:
--   Featured    the four domes: tap one of your curios to set it under the next dome, tap a dome
--               to empty it (the server keeps only curios you really hold)
--   Collection  how complete your collection is (each family, each rarity, how many to go), and
--               every curio you hold, arranged as you like: its rarity, its words, how it's had,
--               and when you first had it
--   History     the last forty curios you came by, and how
--   Visitors    who may look round your Vault, and a look round anyone else's (as they allow)
--   Your Suite  its look (every theme, its price shown first, or what it comes with), who may
--               visit (friends, invited friends, or nobody), invitations, and a photograph
-- Every figure and every rule is the server's (ShowcaseAsk); nothing here is decided here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Showcase)
local CurioArt = require(script.Parent.CurioArt)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local CurioState = require(script.Parent.Parent.CurioState)

local ShowcasePanel = {}

-- Set by Main: the display changed (World/VaultView sets the domes again).
ShowcasePanel.changed = function(_view: { [string]: any }) end
-- Set by Main: photo mode, the camera already framed.
ShowcasePanel.photo = function() end

local NAME = "Showcase"
local C = Brand.Colours
local rgb = Color3.fromRGB
local GOOD = rgb(132, 228, 170)
local FAMILY = { relic = "Relics", meme = "Brainrots", delicacy = "Delicacies" }
local SOURCE = { tables = "Found at the tables", trade = "A trade", cabinet = "The Cabinet", gift = "A gift" }

local view: { [string]: any } = {}

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("ShowcaseAsk"):InvokeServer(request)
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

local function corner(f: GuiObject, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = f
end

local function block(parent: Instance, order: number, height: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = rgb(255, 255, 255)
	f.BackgroundTransparency = 0.95
	f.Size = UDim2.new(1, 0, 0, height)
	f.LayoutOrder = order
	f.Parent = parent
	corner(f, 10)
	return f
end

-- A bar of how far: `held` of `total`, with its words over it.
local function bar(parent: Instance, order: number, label: string, held: number, total: number, colour: Color3)
	local f = block(parent, order, 46)
	local full = held >= total and total > 0
	local togo = total - held
	local words = if full then "Complete" elseif togo <= 2 then string.format("So close: %d to go", togo) else string.format("%d of %d", held, total)
	Theme.text(f, label, 13, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.fromOffset(12, 5), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if full then colour else C.bone })
	local right = Theme.text(f, words, 12, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.4, -24, 0, 18), Position = UDim2.new(0.6, 12, 0, 5), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if full or togo <= 2 then colour else C.smoke })
	right.Name = "Words"
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = rgb(0, 0, 0)
	track.BackgroundTransparency = 0.55
	track.Position = UDim2.fromOffset(12, 28)
	track.Size = UDim2.new(1, -24, 0, 8)
	track.Parent = f
	corner(track, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = colour
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(if total > 0 then math.clamp(held / total, 0, 1) else 0, 0, 1, 0)
	fill.Parent = track
	corner(fill, 4)
end

local function choiceRow(parent: Instance, order: number, choices: { Rules.Choice }, current: string, onPick: (id: string) -> ())
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.LayoutOrder = order
	row.Parent = parent
	Theme.list(row, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
	for i, c in choices do
		local on = c.id == current
		local k = Theme.key(row, c.name, on, function()
			if not on then
				onPick(c.id)
			end
		end, 150)
		k.Size = UDim2.fromOffset(150, 36)
		k.LayoutOrder = i
	end
end

---------------------------------------------------------------------------------------------------
-- The tabs
---------------------------------------------------------------------------------------------------
local refill: (() -> ())? = nil

local function apply(r: { [string]: any }?)
	if not r then
		Toast.show("Not just now", "The house couldn't be reached. Try again in a moment.", 3)
		return
	end
	if r.ok ~= true then
		Toast.show("Not just now", tostring(r.why or "Not just now."), 3)
		return
	end
	view = r
	ShowcasePanel.changed(r)
	if refill then
		(refill :: () -> ())()
	end
end

local function featured(body: GuiObject)
	local current: { string } = if type(view.featured) == "table" then table.clone(view.featured) else {}
	Theme.text(body, "Four domes in the Vault, by the Archivist's desk: everyone who looks round your Vault sees what's under them. Tap one of your curios to set it under the next dome; tap a dome to empty it.", 12, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	local domes = Instance.new("Frame")
	domes.Name = "Domes"
	domes.BackgroundTransparency = 1
	domes.Size = UDim2.new(1, 0, 0, 118)
	domes.LayoutOrder = 2
	domes.Parent = body
	Theme.list(domes, 12, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	for i = 1, Rules.FEATURED do
		local id = current[i]
		local b = Instance.new("TextButton")
		b.Name = "Dome" .. i
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = rgb(16, 30, 24)
		b.BackgroundTransparency = 0.1
		b.Size = UDim2.fromOffset(96, 112)
		b.LayoutOrder = i
		b.Parent = domes
		corner(b, 48)
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = if id then (Curios.RarityColour[(Curios.byId[id] :: any).rarity] or GOOD) else GOOD
		edge.Transparency = if id then 0.05 else 0.6
		edge.Thickness = 1.5
		edge.Parent = b
		if id and Curios.byId[id] then
			local m = CurioArt.medallion(b, id, 60)
			m.AnchorPoint = Vector2.new(0.5, 0)
			m.Position = UDim2.new(0.5, 0, 0, 12)
			Theme.text(b, (Curios.byId[id] :: any).name, 11, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -10, 0, 28), Position = UDim2.fromOffset(5, 76), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true })
		else
			Theme.text(b, "Empty dome", 11, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -10, 0, 30), Position = UDim2.fromOffset(5, 42), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.dim })
		end
		b.Activated:Connect(function()
			if id then
				local list = table.clone(current)
				table.remove(list, i)
				task.spawn(function()
					apply(ask({ op = "feature", items = list }))
				end)
			end
		end)
	end
	Theme.text(body, "Your curios", 12, "caps", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left })
	local shelf = Instance.new("Frame")
	shelf.Name = "Shelf"
	shelf.BackgroundTransparency = 1
	shelf.Size = UDim2.new(1, 0, 0, 0)
	shelf.AutomaticSize = Enum.AutomaticSize.Y
	shelf.LayoutOrder = 4
	shelf.Parent = body
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(78, 98)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = shelf
	local ids = {}
	for id, n in CurioState.items do
		if n > 0 and Curios.byId[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids, Curios.compare)
	for i, id in ids do
		local chosen = table.find(current, id) ~= nil
		local b = Instance.new("TextButton")
		b.Name = "Curio_" .. id
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.LayoutOrder = i
		b.Parent = shelf
		local m = CurioArt.medallion(b, id, 56)
		m.AnchorPoint = Vector2.new(0.5, 0)
		m.Position = UDim2.fromScale(0.5, 0)
		Theme.text(b, (if chosen then "✓ " else "") .. (Curios.byId[id] :: any).name, 11, "body", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 58), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, TextColor3 = if chosen then GOOD else C.bone })
		b.Activated:Connect(function()
			if chosen then
				return
			end
			if #current >= Rules.FEATURED then
				Toast.show("The Vault's display", "All four domes are full: tap a dome to empty it first.", 3)
				return
			end
			local list = table.clone(current)
			table.insert(list, id)
			task.spawn(function()
				apply(ask({ op = "feature", items = list }))
			end)
		end)
	end
	if #ids == 0 then
		Theme.text(body, "Your curios will be here: they turn up at the tables, in the attractions and in the house's events.", 13, "body", { LayoutOrder = 5, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	end
end

local function collection(body: GuiObject)
	local comp = if type(view.completion) == "table" then view.completion else {}
	local held, total = tonumber(comp.held) or 0, tonumber(comp.total) or 0
	Theme.text(body, string.format("%d of the house's %d curios: %d%% of the collection", held, total, if total > 0 then math.floor(held / total * 100) else 0), 15, "bodyBold", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOOD })
	local order = 2
	for _, f in (if type(comp.families) == "table" then comp.families else {}) do
		bar(body, order, FAMILY[f.id] or tostring(f.id), tonumber(f.held) or 0, tonumber(f.total) or 0, GOOD)
		order += 1
	end
	Theme.text(body, "By rarity", 12, "caps", { LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left })
	order += 1
	for _, r in (if type(comp.rarities) == "table" then comp.rarities else {}) do
		bar(body, order, tostring(r.id), tonumber(r.held) or 0, tonumber(r.total) or 0, Curios.RarityColour[tostring(r.id)] or GOOD)
		order += 1
	end
	Theme.text(body, "Arranged", 12, "caps", { LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left })
	order += 1
	choiceRow(body, order, Rules.Arrangements, tostring(view.arrange or "rarity"), function(id: string)
		task.spawn(function()
			apply(ask({ op = "arrange", what = id }))
		end)
	end)
	order += 1
	-- Every curio held, as arranged: its rarity, its words, how it's had, when first had.
	local ids = {}
	for id, n in CurioState.items do
		if n > 0 and Curios.byId[id] then
			table.insert(ids, id)
		end
	end
	local arrange = tostring(view.arrange or "rarity")
	local first: { [string]: number } = if type(view.first) == "table" then view.first else {}
	table.sort(ids, function(a: string, b: string): boolean
		local ca, cb = Curios.byId[a] :: any, Curios.byId[b] :: any
		if arrange == "family" and ca.family ~= cb.family then
			return ca.family < cb.family
		elseif arrange == "newest" then
			local fa, fb = first[a] or 0, first[b] or 0
			if fa ~= fb then
				return fa > fb
			end
		elseif arrange == "starred" then
			local sa, sb = CurioState.favs[a] == true, CurioState.favs[b] == true
			if sa ~= sb then
				return sa
			end
		end
		return Curios.compare(a, b)
	end)
	for _, id in ids do
		local c = Curios.byId[id] :: any
		local f = block(body, order, 74)
		order += 1
		local m = CurioArt.medallion(f, id, 52)
		m.Position = UDim2.fromOffset(10, 11)
		local colour = Curios.RarityColour[c.rarity] or C.bone
		Theme.text(f, string.format("%s  ·  %s%s", c.name, string.upper(c.rarity), if (CurioState.items[id] or 0) > 1 then string.format("  ·  ×%d", CurioState.items[id]) else ""), 13, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -84, 0, 18), Position = UDim2.fromOffset(72, 7), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = colour, TextTruncate = Enum.TextTruncate.AtEnd })
		Theme.text(f, tostring(c.line), 12, "body", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -84, 0, 18), Position = UDim2.fromOffset(72, 27), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.bone, TextTruncate = Enum.TextTruncate.AtEnd })
		local had = first[id]
		Theme.text(f, string.format("%s%s", tostring(c.how or ""), if had then "  ·  first had " .. os.date("%d %b %Y", had) else ""), 11, "body", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -84, 0, 16), Position = UDim2.fromOffset(72, 48), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke, TextTruncate = Enum.TextTruncate.AtEnd })
	end
end

local function history(body: GuiObject)
	local list = if type(view.history) == "table" then view.history else {}
	if #list == 0 then
		Theme.text(body, "Nothing yet: every curio you come by from now on is written here, with when and how.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		return
	end
	for i, h in list do
		local c = Curios.byId[tostring(h.id)] :: any
		if c then
			local f = block(body, i, 52)
			local m = CurioArt.medallion(f, tostring(h.id), 38)
			m.Position = UDim2.fromOffset(8, 7)
			Theme.text(f, string.format("%s%s", c.name, if (tonumber(h.n) or 1) > 1 then string.format(" ×%d", tonumber(h.n) or 1) else ""), 13, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -200, 0, 18), Position = UDim2.fromOffset(56, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Curios.RarityColour[c.rarity] or C.bone, TextTruncate = Enum.TextTruncate.AtEnd })
			Theme.text(f, SOURCE[tostring(h.source)] or (if tostring(h.source) ~= "" then tostring(h.source) else "Found"), 11, "body", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -200, 0, 16), Position = UDim2.fromOffset(56, 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke, TextTruncate = Enum.TextTruncate.AtEnd })
			local when = Theme.text(f, if tonumber(h.at) then os.date("%d %b, %H:%M", tonumber(h.at)) else "", 11, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(130, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.smoke })
			when.AnchorPoint = Vector2.new(1, 0.5)
			when.Position = UDim2.new(1, -12, 0.5, 0)
		end
	end
end

local function visitors(body: GuiObject)
	Theme.text(body, "Who may look round your Vault", 12, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
	local current = tostring(view.vault or "everyone")
	choiceRow(body, 2, Rules.VaultPrivacy, current, function(id: string)
		task.spawn(function()
			apply(ask({ op = "privacy", what = "vault", value = id }))
		end)
	end)
	local line = Rules.vaultPrivacyById[current]
	Theme.text(body, if line then line.line else "", 12, "body", { LayoutOrder = 3, TextColor3 = C.smoke, TextXAlignment = Enum.TextXAlignment.Left })
	Theme.hairline(body, UDim.new(0, 120), 4)
	Theme.text(body, "Look round a guest's Vault", 12, "caps", { LayoutOrder = 5, TextXAlignment = Enum.TextXAlignment.Left })
	local list = Instance.new("Frame")
	list.Name = "Guests"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.LayoutOrder = 6
	list.Parent = body
	Theme.list(list, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	task.spawn(function()
		local r = ask({ op = "guests" })
		if not list.Parent then
			return
		end
		local guests = if r and type(r.guests) == "table" then r.guests else {}
		for i, g in guests do
			local f = block(list, i, 52)
			Theme.text(f, tostring(g.name), 14, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
			Theme.text(f, if g.open then "Their Vault is open to you" else "Their Vault is private", 11, "body", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -170, 0, 16), Position = UDim2.fromOffset(12, 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
			if g.open then
				local k = Theme.key(f, "Look round", false, function()
					task.spawn(function()
						local card = ask({ op = "visit", userId = tonumber(g.userId) })
						if card and card.ok == true then
							ShowcasePanel.card(card)
						elseif card then
							Toast.show("Their Vault", tostring(card.why or "Not just now."), 3)
						end
					end)
				end, 140)
				k.AnchorPoint = Vector2.new(1, 0.5)
				k.Position = UDim2.new(1, -8, 0.5, 0)
				k.Size = UDim2.fromOffset(140, 36)
			end
		end
		if #guests == 0 then
			Theme.text(list, "Nobody else is in the house just now.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
		end
	end)
end

local function suite(body: GuiObject)
	Theme.text(body, "The Suite's look", 12, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
	local themes = if type(view.themes) == "table" then view.themes else {}
	local order = 2
	for _, tv in themes do
		local t = Rules.themeById[tostring(tv.id)]
		if t then
			local chosenNow = view.theme == t.id
			local f = block(body, order, 60)
			order += 1
			for k, colour in { t.walls, t.trim, t.floor } do
				local sw = Instance.new("Frame")
				sw.Name = "Swatch"
				sw.BackgroundColor3 = colour
				sw.Size = UDim2.fromOffset(14, 40)
				sw.Position = UDim2.fromOffset(10 + (k - 1) * 16, 10)
				sw.Parent = f
				corner(sw, 4)
			end
			Theme.text(f, t.name, 14, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -240, 0, 20), Position = UDim2.fromOffset(66, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if chosenNow then GOOD else C.bone })
			Theme.text(f, t.line, 11, "body", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -240, 0, 16), Position = UDim2.fromOffset(66, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke, TextTruncate = Enum.TextTruncate.AtEnd })
			local keyText = if chosenNow then "Chosen" elseif tv.open then "Choose" else tostring(tv.price)
			local buyable = not tv.open and (t.gilt ~= nil or t.gems ~= nil)
			local k = Theme.key(f, keyText, tv.open == true and not chosenNow, function()
				if chosenNow then
					return
				end
				if not tv.open and not buyable then
					Toast.show(t.name, tostring(tv.price) .. ".", 3)
					return
				end
				task.spawn(function()
					apply(ask({ op = if buyable then "buyTheme" else "theme", what = t.id }))
				end)
			end, 160)
			k.AnchorPoint = Vector2.new(1, 0.5)
			k.Position = UDim2.new(1, -8, 0.5, 0)
			k.Size = UDim2.fromOffset(160, 38)
		end
	end
	Theme.text(body, "Who may visit your Suite", 12, "caps", { LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left })
	order += 1
	local current = tostring(view.suite or "friends")
	choiceRow(body, order, Rules.SuitePrivacy, current, function(id: string)
		task.spawn(function()
			apply(ask({ op = "privacy", what = "suite", value = id }))
		end)
	end)
	order += 1
	if current == "invited" then
		local friends = if type(view.friends) == "table" then view.friends else {}
		for _, fr in friends do
			local f = block(body, order, 48)
			order += 1
			Theme.text(f, tostring(fr.name), 14, "bodyBold", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -180, 0, 20), Position = UDim2.fromOffset(12, 13), TextXAlignment = Enum.TextXAlignment.Left })
			local k = Theme.key(f, if fr.invited then "Invited" else "Invite", not fr.invited, function()
				task.spawn(function()
					apply(ask({ op = if fr.invited then "uninvite" else "invite", userId = tonumber(fr.userId) }))
				end)
			end, 140)
			k.AnchorPoint = Vector2.new(1, 0.5)
			k.Position = UDim2.new(1, -8, 0.5, 0)
			k.Size = UDim2.fromOffset(140, 36)
		end
		if #friends == 0 then
			Theme.text(body, "None of your friends is in the house just now.", 12, "body", { LayoutOrder = order, TextColor3 = C.smoke })
			order += 1
		end
	end
	Theme.hairline(body, UDim.new(0, 120), order)
	order += 1
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 44)
	row.LayoutOrder = order
	row.Parent = body
	Theme.list(row, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.key(row, "Photograph your Suite", false, function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local S = Layout.Suite :: any
		local from = if typeof(S.arrival) == "Vector3" then S.arrival + Vector3.new(0, 6, 0) else nil
		local at = if typeof(S.centre) == "Vector3" then S.centre else nil
		Root.close(NAME)
		if from and at then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(from, at + Vector3.new(0, 2, 0))
		end
		ShowcasePanel.photo()
	end, 230)
end

---------------------------------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------------------------------
local TABS = { { "featured", "Featured" }, { "collection", "Collection" }, { "history", "History" }, { "visitors", "Visitors" }, { "suite", "Your Suite" } }

function ShowcasePanel.open(tab: string?)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local current = tab or "featured"
	local size = Root.size()
	local w = Root.panelWidth(640)
	local h = math.min(660, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Vault & your Suite", 11, "caps", { LayoutOrder = 1 })
	local title = Theme.text(content, "", 26, "display", { LayoutOrder = 2 })
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.LayoutOrder = 4
	body.Size = UDim2.new(1, 0, 0, 300)
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = GOOD
	body.Parent = content
	Theme.list(body, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = body
	local titles = { featured = "The Vault's Display", collection = "Your Collection", history = "Acquisitions", visitors = "Visitors", suite = "Your Suite" }
	local function fill()
		clear(body)
		title.Text = titles[current] or "The Vault"
		if not view.ok then
			Theme.text(body, "One moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
			return
		end
		if current == "collection" then
			collection(body)
		elseif current == "history" then
			history(body)
		elseif current == "visitors" then
			visitors(body)
		elseif current == "suite" then
			suite(body)
		else
			featured(body)
		end
	end
	refill = fill
	local tabs = Theme.tabs(content, TABS, current, function(id: string)
		current = id
		fill()
	end, 3)
	tabs.select(current)
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 44)
	keys.LayoutOrder = 20
	keys.Parent = content
	Theme.list(keys, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(keys, "Close", false, function()
		Root.close(NAME)
	end, 140)
	fill()
	Theme.fillRest(body)
	Root.open(NAME, group, function()
		refill = nil
	end)
	task.spawn(function()
		local r = ask({ op = "state" })
		if r and r.ok == true then
			view = r
			ShowcasePanel.changed(r)
			if refill then
				(refill :: () -> ())()
			end
		end
	end)
end

function ShowcasePanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

-- Another guest's Vault, as they allow it: their four domes and how complete their collection is.
function ShowcasePanel.card(card: { [string]: any })
	local CARD = "ShowcaseVisit"
	if Root.isOpen(CARD) then
		Root.close(CARD)
	end
	local group, content = Theme.glass(Root.panels, CARD, UDim2.fromOffset(math.min(520, Root.size().X - 24), 400), nil, nil, "emerald")
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "A look round", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, tostring(card.name) .. "'s Vault", 24, "display", { LayoutOrder = 2 })
	local comp = if type(card.completion) == "table" then card.completion else {}
	Theme.text(content, string.format("%d of the house's %d curios", tonumber(comp.held) or 0, tonumber(comp.total) or 0), 14, "bodyBold", { LayoutOrder = 3, TextColor3 = GOOD })
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 100)
	row.LayoutOrder = 4
	row.Parent = content
	Theme.list(row, 12, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local shown = if type(card.featured) == "table" and #card.featured > 0 then card.featured else (if type(card.rarest) == "table" then card.rarest else {})
	for i, id in shown do
		if i <= 4 and Curios.byId[tostring(id)] then
			local cell = Instance.new("Frame")
			cell.BackgroundTransparency = 1
			cell.Size = UDim2.fromOffset(90, 100)
			cell.LayoutOrder = i
			cell.Parent = row
			local m = CurioArt.medallion(cell, tostring(id), 58)
			m.AnchorPoint = Vector2.new(0.5, 0)
			m.Position = UDim2.fromScale(0.5, 0)
			Theme.text(cell, (Curios.byId[tostring(id)] :: any).name, 11, "body", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 62), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true })
		end
	end
	Theme.text(content, if type(card.featured) == "table" and #card.featured > 0 then "Under their four domes." else "Their rarest, as they haven't chosen any to feature yet.", 12, "body", { LayoutOrder = 5, TextColor3 = C.smoke })
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 44)
	keys.LayoutOrder = 6
	keys.Parent = content
	Theme.list(keys, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(keys, "Close", false, function()
		Root.close(CARD)
	end, 140)
	Root.open(CARD, group)
	local _ = Players
end

return ShowcasePanel
