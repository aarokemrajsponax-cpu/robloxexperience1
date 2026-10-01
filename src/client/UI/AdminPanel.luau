--!strict
-- House controls: the owner's panel (only the owner sees the "House" key, and the server checks
-- every request again). Four pages: Events (Golden Hour, Lucky Hour, giants, gold coins, a
-- treasure hunt...), Spectacle (any Salute for free, another season for a while), Guests (crown,
-- spotlight, bring, gift, remove) and Announce (a line to this house or every house, and a
-- summons for guests in every house to join this one).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local AdminPanel = {}

local NAME = "HouseControls"
local page = "events"
local minutes = 15
local everywhere = false

local function ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("AdminAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

-- One line of the panel: words on the left, keys on the right; `stacked` puts the keys on a
-- line of their own beneath the words (for rows with several choices).
local function row(parent: Instance, order: number, label: string, detail: string?, stacked: boolean?): Frame
	local r = Instance.new("Frame")
	r.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	r.BackgroundTransparency = 0.35
	r.Size = UDim2.new(1, 0, 0, if stacked then 96 else 64)
	r.LayoutOrder = order
	r.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = r
	local texts = Instance.new("Frame")
	texts.BackgroundTransparency = 1
	texts.Position = UDim2.fromOffset(12, 6)
	texts.Size = if stacked then UDim2.new(1, -24, 0, 44) else UDim2.new(0.55, -12, 1, -12)
	texts.Parent = r
	Theme.list(texts, 2).HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.text(texts, label, 16, "display", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
	if detail then
		Theme.text(texts, detail, 11, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Brand.Colours.smoke, TextWrapped = true })
	end
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	if stacked then
		keys.AnchorPoint = Vector2.new(0, 1)
		keys.Position = UDim2.new(0, 12, 1, -8)
		keys.Size = UDim2.new(1, -24, 0, 34)
	else
		keys.AnchorPoint = Vector2.new(1, 0.5)
		keys.Position = UDim2.new(1, -8, 0.5, 0)
		keys.Size = UDim2.new(0.45, 0, 1, -12)
	end
	keys.Parent = r
	Theme.list(keys, 6, true).HorizontalAlignment = if stacked then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right
	return keys
end

local function small(parent: Instance, text: string, primary: boolean, onPress: () -> ()): TextButton
	local k = Theme.key(parent, text, primary, onPress, 90)
	k.Size = UDim2.fromOffset(90, 32)
	return k
end

function AdminPanel.open()
	if Root.isOpen(NAME) then
		Root.close(NAME)
		return
	end
	local size = Root.size()
	local w = math.min(640, size.X - 24)
	local h = math.min(640, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "House controls", 26, "display", { LayoutOrder = 1 })
	Theme.text(content, "For the owner. Events change Gilt, pages and luck, never a score.", 12, "body", { LayoutOrder = 2, TextColor3 = Brand.Colours.dim })
	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(1, 0, 0, 40)
	tabs.LayoutOrder = 3
	tabs.Parent = content
	Theme.list(tabs, 6, true)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 4
	scroll.Size = UDim2.new(1, 0, 1, -(26 + 18 + 40 + 44 + 50))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Brand.Colours.gold
	scroll.Parent = content
	Theme.list(scroll, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll

	local view: { [string]: any }? = nil
	local render: () -> ()
	local function reload(result: any?)
		task.spawn(function()
			local v = if type(result) == "table" and result.guests then result else ask({ op = "state" })
			if type(v) == "table" and v.ok and content.Parent then
				view = v
				render()
			elseif type(v) == "table" and v.why then
				Toast.show("House controls", tostring(v.why), 3)
			end
		end)
	end
	local function send(request: { [string]: any }, done: string?)
		task.spawn(function()
			local r = ask(request)
			if type(r) == "table" and r.ok == false then
				Toast.show("House controls", tostring(r.why), 3)
			elseif done then
				Toast.show("House controls", done, 2.5)
			end
			reload(r)
		end)
	end

	render = function()
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local v = view
		if not v then
			return
		end
		local order = 0
		local function add(): number
			order += 1
			return order
		end
		-- How long, and where: shared by events, seasons and announcements.
		local opts = row(scroll, add(), "For " .. tostring(minutes) .. " minutes" .. (if everywhere then ", in every house" else ", in this house"), "Events and seasons last this long.", true)
		for _, m in v.minutes do
			small(opts, tostring(m) .. " min", m == minutes, function()
				minutes = m
				render()
			end)
		end
		small(opts, if everywhere then "Every house" else "This house", everywhere, function()
			everywhere = not everywhere
			render()
		end)
		if page == "events" then
			for _, e in v.events do
				local left = if type(e.endsAt) == "number" then e.endsAt - Workspace:GetServerTimeNow() else 0
				local keys = row(scroll, add(), e.name .. (if left > 0 then string.format("  ·  %d:%02d left", left // 60, left % 60) else ""), e.line)
				if left > 0 then
					small(keys, "Stop", false, function()
						send({ op = "stop", id = e.id }, e.name .. " stopped.")
					end)
				end
				small(keys, "Start", true, function()
					send({ op = "event", id = e.id, minutes = minutes, everywhere = everywhere }, e.name .. " has begun.")
				end)
			end
		elseif page == "spectacle" then
			Theme.text(scroll, "Salutes, free from the house", 11, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
			for _, sa in v.salutes do
				local keys = row(scroll, add(), sa.name, nil)
				small(keys, "Play", true, function()
					send({ op = "salute", id = sa.id })
				end)
			end
			Theme.text(scroll, "Dress the house in another season (seasonal pieces come too)", 11, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
			for _, se in v.seasons do
				local keys = row(scroll, add(), se.name, nil)
				small(keys, "Now", false, function()
					send({ op = "season", id = se.id, minutes = minutes }, "The house is dressed for " .. se.name .. ".")
				end)
			end
		elseif page == "guests" then
			local all = row(scroll, add(), "Every guest", "A gift of Gilt to everyone in this house.")
			for _, amount in v.giftGilt do
				small(all, tostring(amount), false, function()
					send({ op = "giftAll", amount = amount }, string.format("Every guest received %d Gilt.", amount))
				end)
			end
			for _, g in v.guests do
				local keys = row(scroll, add(), g.name .. (if g.crowned then "  ♛" else ""), nil)
				small(keys, "Crown", true, function()
					send({ op = "crown", userId = g.userId })
				end)
				small(keys, "Spotlight", false, function()
					send({ op = "spotlight", userId = g.userId })
				end)
				small(keys, "Bring", false, function()
					send({ op = "bring", userId = g.userId })
				end)
				local gifts = row(scroll, add(), "   " .. g.name .. ": a gift, or remove", nil)
				for _, amount in v.giftGilt do
					small(gifts, tostring(amount), false, function()
						send({ op = "gift", userId = g.userId, amount = amount }, string.format("%s received %d Gilt.", g.name, amount))
					end)
				end
				small(gifts, "Remove", false, function()
					send({ op = "kick", userId = g.userId }, g.name .. " has been shown out.")
				end)
			end
		elseif page == "announce" then
			for i, line in v.announcements do
				local keys = row(scroll, add(), line, nil)
				small(keys, "Say it", true, function()
					send({ op = "announce", preset = i, everywhere = everywhere }, "Announced.")
				end)
			end
			local box = Instance.new("TextBox")
			box.Name = "OwnerLine"
			box.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
			box.BackgroundTransparency = 0.2
			box.Size = UDim2.new(1, 0, 0, 40)
			box.LayoutOrder = add()
			box.FontFace = Brand.Fonts.body
			box.TextSize = 15
			box.TextColor3 = Brand.Colours.bone
			box.PlaceholderText = "Your own line (140 letters; Roblox filters it first)"
			box.PlaceholderColor3 = Brand.Colours.dim
			box.ClearTextOnFocus = false
			box.Text = ""
			box.Parent = scroll
			local keys = row(scroll, add(), "Your own line", nil)
			small(keys, "Say it", true, function()
				send({ op = "announce", text = string.sub(box.Text, 1, 140), everywhere = everywhere }, "Announced.")
			end)
			local summon = row(scroll, add(), "Summon every house", "Guests in every other house are invited to join you here.")
			small(summon, "Summon", true, function()
				send({ op = "summon", text = string.sub(box.Text, 1, 140) }, "Every house has been invited.")
			end)
		end
	end

	for i, spec in { { "events", "Events" }, { "spectacle", "Spectacle" }, { "guests", "Guests" }, { "announce", "Announce" } } do
		local k = Theme.key(tabs, spec[2], page == spec[1], function()
			page = spec[1]
			render()
		end, 130)
		k.LayoutOrder = i
	end
	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, 0, 0, 44)
	footer.LayoutOrder = 5
	footer.Parent = content
	Theme.list(footer, 8, true)
	Theme.key(footer, "Close", true, function()
		Root.close(NAME)
	end, 180)
	Root.open(NAME, group)
	reload()
end

return AdminPanel
