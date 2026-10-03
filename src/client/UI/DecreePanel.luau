--!strict
-- Emperor's Decree, written: a line of your own (or one of the house's), checked by the server
-- and Roblox's filter first, shown back exactly as the house would proclaim it, and only then
-- the purchase. The price is Roblox's, as the server read it. Everyone sees your display name
-- and @username with the words; nobody can choose how it looks or how long it stays.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Perks = require(script.Parent.Parent.Perks)

local DecreePanel = {}

local NAME = "Decree"
local ROBUX = utf8.char(0xE002)

local function number(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function proclaimText(info: { [string]: any }): string
	local held = tonumber(info.held) or 0
	if held > 0 then
		return string.format("Proclaim (%d held)", held)
	elseif type(info.price) == "number" then
		return string.format("Proclaim  %s %s", ROBUX, number(info.price))
	end
	return "Proclaim"
end

function DecreePanel.open()
	local info = Perks.ask({ op = "decree" })
	if type(info) ~= "table" or info.ok == false then
		Toast.show("Emperor's Decree", "The house couldn't open the decree just now.", 3)
		return
	end
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local maxLength = tonumber(info.maxLength) or 80
	local size = Root.size()
	local w = math.min(460, size.X - 24)
	-- As tall as the screen allows; the body scrolls on a short (phone) screen.
	local h = math.min(600, size.Y - 24)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h), UDim2.new(0.5, 0, 0.5, 0))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "For the whole house", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "Emperor's Decree", 24, "display", { LayoutOrder = 2 })
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.LayoutOrder = 3
	body.Size = UDim2.new(1, 0, 1, -(16 + 34 + 44 + 3 * 8))
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = Brand.Colours.gold
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.Parent = content
	Theme.list(body, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	-- (A little room on every side, so the edges of the box and the keys aren't clipped.)
	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingLeft = UDim.new(0, 2)
	bodyPad.PaddingRight = UDim.new(0, 8)
	bodyPad.PaddingTop = UDim.new(0, 2)
	bodyPad.PaddingBottom = UDim.new(0, 2)
	bodyPad.Parent = body
	Theme.text(body, string.format("Your words, in gold, on every screen in the house for %d seconds, with your name. Roblox's filter reads them first.", tonumber(info.seconds) or 8), 13, "body", {
		LayoutOrder = 3,
		TextWrapped = true,
		TextColor3 = Brand.Colours.smoke,
	})

	local box = Instance.new("TextBox")
	box.Name = "DecreeText"
	box.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	box.BackgroundTransparency = 0.2
	box.Size = UDim2.new(1, 0, 0, 44)
	box.LayoutOrder = 4
	box.FontFace = Brand.Fonts.body
	box.TextSize = 16
	box.TextColor3 = Brand.Colours.bone
	box.PlaceholderText = string.format("Write your decree (up to %d letters)", maxLength)
	box.PlaceholderColor3 = Brand.Colours.dim
	box.ClearTextOnFocus = false
	box.MultiLine = false
	box.TextWrapped = true
	box.Text = if type(info.written) == "string" then info.written else ""
	local boxStroke = Instance.new("UIStroke")
	boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	boxStroke.Color = Brand.Colours.gold
	boxStroke.Transparency = 0.55
	boxStroke.Parent = box
	local boxPad = Instance.new("UIPadding")
	boxPad.PaddingLeft = UDim.new(0, 10)
	boxPad.PaddingRight = UDim.new(0, 10)
	boxPad.Parent = box
	box.Parent = body
	local counter = Theme.text(body, "", 11, "body", { LayoutOrder = 5, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Brand.Colours.dim })
	local function count()
		local n = utf8.len(box.Text) or #box.Text
		if n > maxLength then
			-- Kept to the limit as it's typed (the server checks again anyway).
			local cut = utf8.offset(box.Text, maxLength + 1)
			if cut then
				box.Text = string.sub(box.Text, 1, cut - 1)
			end
			n = maxLength
		end
		counter.Text = string.format("%d / %d", n, maxLength)
	end
	box:GetPropertyChangedSignal("Text"):Connect(count)
	count()

	local preview = Theme.text(body, "", 15, "display", { LayoutOrder = 7, TextWrapped = true, TextColor3 = Brand.Colours.lightGold })
	local status = Theme.text(body, "", 12, "body", { LayoutOrder = 8, TextWrapped = true, TextColor3 = Brand.Colours.smoke })
	-- (Empty lines take no room.)
	local function shown()
		preview.Visible = preview.Text ~= ""
		status.Visible = status.Text ~= ""
	end
	if (tonumber(info.cooldown) or 0) > 0 then
		status.Text = string.format("Your next decree may be proclaimed in %d seconds.", info.cooldown)
	elseif (tonumber(info.queue) or 0) >= (tonumber(info.queueMax) or 3) then
		status.Text = "The house is hearing other decrees. Try again in a minute."
	end
	shown()

	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 9
	keys.Parent = body
	Theme.list(keys, 8)
	local proclaim: TextButton
	local ready = false
	local function composed(result: any)
		if type(result) ~= "table" or result.ok ~= true then
			ready = false
			preview.Text = ""
			status.Text = if type(result) == "table" and type(result.why) == "string" then result.why else "The house couldn't read that just now."
			if type(result) == "table" and result.presetsOnly then
				box.Visible = false
				counter.Visible = false
			end
			proclaim.Visible = false
			shown()
			return
		end
		ready = true
		preview.Text = "“" .. tostring(result.text) .. "”"
		status.Text = "This is exactly how the house will show it."
		info.held = result.held
		info.price = result.price
		proclaim.Text = string.upper(proclaimText(info))
		proclaim.Visible = true
		shown()
	end
	Theme.key(keys, "Check my words", false, function()
		composed(Perks.ask({ op = "decreeCompose", text = box.Text }))
	end, 300).LayoutOrder = 1
	proclaim = Theme.key(keys, proclaimText(info), true, function()
		if not ready then
			return
		end
		local r = Perks.ask({ op = "decreeProclaim" })
		if type(r) == "table" and r.ok then
			Root.close(NAME)
			if not r.prompted then
				Toast.show("Emperor's Decree", "Proclaimed.", 3)
			end
		else
			status.Text = if type(r) == "table" and type(r.why) == "string" then r.why else "The house couldn't do that just now."
			shown()
		end
	end, 300)
	proclaim.LayoutOrder = 2
	proclaim.Visible = false

	-- The house's own lines (for anyone, and the only choice for accounts that can't chat), as
	-- they'll read: in sentence case, not the keys' capitals.
	Theme.text(body, "Or one of the house's", 11, "caps", { LayoutOrder = 10 })
	local presets = Instance.new("Frame")
	presets.BackgroundTransparency = 1
	presets.AutomaticSize = Enum.AutomaticSize.Y
	presets.Size = UDim2.new(1, 0, 0, 0)
	presets.LayoutOrder = 11
	presets.Parent = body
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -4, 0, 44)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = presets
	for i, line in (if type(info.presets) == "table" then info.presets else {}) :: { any } do
		local k = Theme.key(presets, tostring(line), false, function()
			box.Text = ""
			composed(Perks.ask({ op = "decreeCompose", preset = i }))
		end, 200)
		k.Text = tostring(line)
		k.TextWrapped = true
		k.LayoutOrder = i
	end
	Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 300).LayoutOrder = 20
	Root.open(NAME, group)
end

return DecreePanel
