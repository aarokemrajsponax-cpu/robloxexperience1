--!strict
-- The Quartermaster's board (at his desk in the Executive's Anteroom): your invitations to the
-- Executive Suite and every way to earn one (or one for Gilt), the sidearm (free: every guest takes
-- one up), and the gear for the next run, each with what it does and its price in Gilt. Every
-- figure and price is the server's (AttractionAsk "state"); the server takes the price or says why.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local ExecutivePanel = {}

local NAME = "Quartermaster"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)

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

local function line(parent: Instance, order: number, title: string, words: string, keyText: string, primary: boolean, onPress: (() -> ())?): Frame
	local f = Instance.new("Frame")
	f.Name = "Line"
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 50)
	f.LayoutOrder = order
	f.Parent = parent
	local w = Instance.new("Frame")
	w.BackgroundTransparency = 1
	w.Size = UDim2.new(1, -150, 1, 0)
	w.Parent = f
	Theme.list(w, 1).VerticalAlignment = Enum.VerticalAlignment.Center
	Theme.text(w, title, 14, "bodyBold", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None })
	Theme.text(w, words, 12, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
	local key = Theme.key(f, keyText, primary, function()
		if onPress then
			onPress()
		end
	end, 140)
	key.AnchorPoint = Vector2.new(1, 0.5)
	key.Position = UDim2.new(1, 0, 0.5, 0)
	if not onPress then
		key.Active = false
		key.AutoButtonColor = false
	end
	return f
end

function ExecutivePanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local w = Root.panelWidth(540)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 640))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Executive Suite", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "The Quartermaster", 26, "display", { LayoutOrder = 2 })
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.Size = UDim2.new(1, 0, 0, 0)
	rows.LayoutOrder = 3
	rows.Parent = content
	Theme.list(rows, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(rows, "One moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })

	local fill: (s: { [string]: any }) -> ()
	local busy = false
	local function act(request: { [string]: any })
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local r = ask(request)
			busy = false
			if not r then
				Toast.show("Not just now", "The house couldn't be reached. Try again in a moment.", 3)
			elseif r.ok ~= true then
				Toast.show("Not yet", tostring(r.why or "Not just now."), 3)
			elseif type(r.state) == "table" and group.Parent then
				Theme.haptic()
				fill(r.state)
			end
		end)
	end
	fill = function(s: { [string]: any })
		clear(rows)
		local invites, most = tonumber(s.invites) or 0, tonumber(s.most) or 5
		Theme.text(rows, string.format("Invitations: %d of %d", invites, most), 16, "bodyBold", { LayoutOrder = 1, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left })
		Theme.text(rows, string.format("One is spent going up. Earn them: clear the Maison Basement, or bank a haul of %s or more in Steal a Luxe.", Rules.format(tonumber(s.inviteHaul) or 8000)), 12, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextXAlignment = Enum.TextXAlignment.Left })
		local price = tonumber(s.invitePrice) or 25000
		line(rows, 3, "An invitation", "For Gilt, if you'd rather not wait.", if invites >= most then "You hold the most" else Rules.format(price) .. " Gilt", invites < most, if invites < most then function()
			act({ op = "act", id = "executive", act = "invite" })
		end else nil)
		Theme.hairline(rows, UDim.new(0, 120), 4)
		local gear = if type(s.gear) == "table" then s.gear else {}
		for i, g in gear do
			if g.free then
				line(rows, 10 + i, tostring(g.glyph or "") .. "  " .. tostring(g.name), tostring(g.line), if g.packed then "Taken" else "Take it (free)", not g.packed, if g.packed then nil else function()
					act({ op = "act", id = "executive", act = "sidearm" })
				end)
			else
				line(rows, 10 + i, tostring(g.glyph or "") .. "  " .. tostring(g.name), tostring(g.line), if g.packed then "Packed" else Rules.format(tonumber(g.price) or 0) .. " Gilt", false, if g.packed then nil else function()
					act({ op = "act", id = "executive", act = "gear", what = g.id })
				end)
			end
		end
		Theme.text(rows, "Gear is packed for your next run and works only in the Suite.", 12, "body", { LayoutOrder = 30, TextColor3 = C.smoke })
	end
	local close = Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 20
	Root.open(NAME, group)
	task.spawn(function()
		local r = ask({ op = "state", id = "executive" })
		if not group.Parent then
			return
		end
		if r and r.ok == true then
			fill(r)
		else
			clear(rows)
			Theme.text(rows, "The Quartermaster's board couldn't be read just now. Try again in a moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
		end
	end)
end

function ExecutivePanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

return ExecutivePanel
