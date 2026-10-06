--!strict
-- The Terrace Bar's menu (the prompt on the bar). Drinks, snacks and the house specials, each
-- with exactly what it is and its price, plain: Gilt for the everyday menu, Robux for the
-- specials (the same kind of treat made grand). Nothing is random and nothing has alcohol in it.
-- The server checks every order (Purchases/Bar); this screen only asks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local RoundPanel = require(script.Parent.RoundPanel)

local BarPanel = {}

local NAME = "Bar"
local C = Brand.Colours
local ROBUX = utf8.char(0xE002)

local function ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("BarAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

local function row(parent: Instance, order: number): (Frame, Frame, Frame)
	local f = Instance.new("Frame")
	f.Name = "Item"
	f.BackgroundColor3 = Color3.fromRGB(26, 23, 24)
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = UDim2.new(1, 0, 0, 0)
	f.LayoutOrder = order
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = f
	local text = Instance.new("Frame")
	text.Name = "Words"
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.Size = UDim2.new(1, -176, 0, 0)
	text.Parent = f
	Theme.list(text, 3).HorizontalAlignment = Enum.HorizontalAlignment.Left
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.AnchorPoint = Vector2.new(1, 0)
	keys.Position = UDim2.fromScale(1, 0)
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(0, 164, 0, 0)
	keys.Parent = f
	Theme.list(keys, 6)
	return f, text, keys
end

local function heading(parent: Instance, order: number, title: string, line: string)
	Theme.text(parent, title, 13, "caps", { LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left })
	Theme.text(parent, line, 13, "body", { LayoutOrder = order + 1, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = C.smoke })
end

function BarPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(600, size.X - 24)
	local h = math.min(660, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Terrace Bar", 26, "display", { LayoutOrder = 1 })
	local summary = Theme.text(content, "One moment...", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true })

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Menu"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 3
	scroll.Size = UDim2.new(1, 0, 1, -(34 + 22 + 52 + 24))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = C.gold
	scroll.Parent = content
	Theme.list(scroll, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll

	local fill: (menu: { [string]: any }) -> ()
	local function reload()
		task.spawn(function()
			local m = ask({ op = "menu" })
			if type(m) == "table" and type(m.items) == "table" and content.Parent then
				fill(m)
			end
		end)
	end

	local function order(item: { [string]: any }, pour: boolean)
		task.spawn(function()
			local r = ask({ op = "order", id = item.id, pour = pour })
			if type(r) == "table" and r.ok then
				Toast.show("The Terrace Bar", tostring(item.name) .. (if r.free then ", on the house." else ". Enjoy it."), 3)
				Root.close(NAME)
			else
				Toast.show("The Terrace Bar", tostring(if type(r) == "table" and r.why then r.why else "One moment."), 3)
				reload()
			end
		end)
	end

	local function special(item: { [string]: any })
		task.spawn(function()
			local r = ask({ op = "special", key = item.key })
			if type(r) == "table" and r.ok and not r.prompted then
				Root.close(NAME) -- one already paid for, served now
			elseif type(r) == "table" and not r.ok then
				Toast.show("The Terrace Bar", tostring(r.why or "One moment."), 3)
			end
			-- Bought: the house serves it the moment Roblox confirms the purchase.
		end)
	end

	fill = function(m: { [string]: any })
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local gilt = if type(m.gilt) == "number" then m.gilt else 0
		local line = string.format("%s Gilt to spend  ·  no alcohol, nothing random, nothing that changes a score", RoundPanel.number(gilt))
		if m.pour then
			line = "Your Gold Key: one drink on the house today  ·  " .. line
		end
		summary.Text = line
		local n = 0
		local function add(): number
			n += 1
			return n * 10
		end
		local sections = {
			{ title = "Drinks", line = "Poured while you wait; you sip it wherever you go.", test = function(i: any)
				return i.kind == "drink" and i.gilt ~= nil
			end },
			{ title = "Snacks", line = "Made at the bar, a bite every few seconds.", test = function(i: any)
				return i.kind == "snack" and i.gilt ~= nil
			end },
			{ title = "The house specials", line = "Bought with Robux at the price shown. You get exactly what it says: a treat to hold and enjoy. Cosmetic only.", test = function(i: any)
				return i.robux ~= nil
			end },
		}
		for _, sec in sections do
			heading(scroll, add(), sec.title, sec.line)
			n += 1
			for _, item in m.items do
				if not sec.test(item) then
					continue
				end
				local _, words, keys = row(scroll, add())
				Theme.text(words, tostring(item.name), 16, "bodyMedium", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.bone })
				Theme.text(words, tostring(item.line), 13, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = C.smoke })
				local holds = string.format("%d %s", item.servings, if item.kind == "drink" then "sips" else "bites")
				Theme.text(words, holds, 12, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.dim })
				if type(item.gilt) == "number" then
					if m.pour and item.kind == "drink" then
						local k = Theme.key(keys, "On the house", true, function()
							order(item, true)
						end, 164)
						k.Size = UDim2.fromOffset(164, 36)
						k.LayoutOrder = 1
					end
					local can = gilt >= item.gilt
					local k = Theme.key(keys, RoundPanel.number(item.gilt) .. " Gilt", can and not m.pour, function()
						if can then
							order(item, false)
						end
					end, 164)
					k.Size = UDim2.fromOffset(164, 36)
					k.LayoutOrder = 2
					if not can then
						k.BackgroundTransparency = 0.6
						k.TextTransparency = 0.35
					end
				elseif type(item.robux) == "number" then
					if type(item.waiting) == "number" and item.waiting > 0 then
						local k = Theme.key(keys, string.format("Yours: serve it (%d)", item.waiting), true, function()
							special(item)
						end, 164)
						k.Size = UDim2.fromOffset(164, 36)
						k.LayoutOrder = 1
					elseif item.ready then
						local k = Theme.key(keys, string.format("%s %d", ROBUX, item.robux), true, function()
							special(item)
						end, 164)
						k.Size = UDim2.fromOffset(164, 36)
						k.LayoutOrder = 1
					else
						Theme.text(keys, string.format("%s %d · not on sale yet", ROBUX, item.robux), 13, "body", { LayoutOrder = 1, TextColor3 = C.dim, TextWrapped = true })
					end
				end
			end
		end
		if type(m.holding) == "string" then
			local k = Theme.key(scroll, "Put down what you're holding", false, function()
				task.spawn(ask, { op = "putDown" })
				Root.close(NAME)
			end, 280)
			k.LayoutOrder = add()
		end
	end

	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 20
	keys.Parent = content
	Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local close = Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 1
	Root.open(NAME, group)
	pcall(function()
		game:GetService("GuiService").SelectedObject = close
	end)
	reload()
end

function BarPanel.start()
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "BarPrompt" then
			BarPanel.open()
		end
	end)
end

return BarPanel
