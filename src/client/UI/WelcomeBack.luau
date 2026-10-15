--!strict
-- Welcome back: a returning guest's one card, a few seconds after they arrive. What's waiting for
-- them, each with its key (tonight's present: Open; what their brainrots earned while they were
-- away: Collect, there and then), and what's new in the house since they were last here (once a
-- build: the server says when). One tidy card instead of a present, a toast and a notice each
-- arriving on their own. Nothing to say, no card. It waits while anything else has the screen,
-- and never opens at a table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Build = require(ReplicatedStorage.Shared.Build)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Names = require(ReplicatedStorage.Shared.Names)
local Voice = require(ReplicatedStorage.Shared.Voice)
local CurioState = require(script.Parent.Parent.CurioState)
local Sound = require(script.Parent.Parent.Sound)
local Icons = require(script.Parent.Icons)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local WelcomeBack = {}

local NAME = "WelcomeBack"
local C = Brand.Colours
local V = Voice.WelcomeBack

-- Set by Main: whether something else has the guest (a table, the tour, the welcome), and what
-- the present's key opens, and the calendar's state now.
WelcomeBack.isBusy = function(): boolean
	return false
end
WelcomeBack.openCalendar = function() end
WelcomeBack.calendar = function(): { [string]: any }?
	return nil
end

local awayGilt = 0
local shown = false

-- What the brainrots earned while the guest was away (the server says so as they arrive).
function WelcomeBack.noteAway(gilt: number)
	awayGilt = math.max(awayGilt, math.floor(gilt))
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function ordinal(n: number): string
	local last = n % 10
	local teen = n % 100 >= 11 and n % 100 <= 13
	return tostring(n) .. (if teen then "th" elseif last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th")
end

-- One thing waiting: its mark in a gold ring, its words (wrapping, the row as tall as they need),
-- and its key at the right. `compact` (a short screen): the title alone.
local function row(parent: Instance, order: number, icon: string, title: string, line: string?, key: string, onPress: (TextButton) -> ()): TextButton
	local r = Instance.new("Frame")
	r.Name = "Row" .. order
	r.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	r.BackgroundTransparency = 0.95
	r.Size = UDim2.new(1, 0, 0, if line then 64 else 52)
	r.AutomaticSize = Enum.AutomaticSize.Y
	r.LayoutOrder = order
	r.Parent = parent
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 10)
	rc.Parent = r
	local ring = Instance.new("Frame")
	ring.Name = "Mark"
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.new(0, 12, 0.5, 0)
	ring.Size = UDim2.fromOffset(38, 38)
	ring.BackgroundColor3 = Color3.fromRGB(28, 24, 18)
	ring.Parent = r
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = ring
	local ringStroke = Instance.new("UIStroke")
	ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ringStroke.Color = C.gold
	ringStroke.Transparency = 0.25
	ringStroke.Thickness = 1.25
	ringStroke.Parent = ring
	local mark = Icons.draw(ring, icon, C.lightGold, 22)
	if mark then
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)
	end
	local keyWidth = 116
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.new(0, 62, 0, 0)
	words.Size = UDim2.new(1, -(62 + keyWidth + 22), 0, 0)
	words.AutomaticSize = Enum.AutomaticSize.Y
	words.Parent = r
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = words
	local list = Theme.list(words, 2)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	local wrap = { TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y }
	local t = Theme.text(words, title, 16, "bodyBold", { Name = "Title", LayoutOrder = 1, TextColor3 = C.bone, Size = UDim2.new(1, 0, 0, 0) })
	for k, v in wrap do
		(t :: any)[k] = v
	end
	if line then
		local l = Theme.text(words, line, 13, "body", { Name = "Line", LayoutOrder = 2, TextColor3 = C.smoke, Size = UDim2.new(1, 0, 0, 0) })
		for k, v in wrap do
			(l :: any)[k] = v
		end
	end
	local button: TextButton
	button = Theme.key(r, key, true, function()
		onPress(button)
	end, keyWidth)
	button.Name = "Key"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12, 0.5, 0)
	return button
end

-- The card. `news`: the server says this guest hasn't seen this build's news yet.
function WelcomeBack.open(name: string, nights: number, news: boolean, present: boolean, jar: number): boolean
	local hasNews = news and Voice.WhatsNew.build == Build.number and #Voice.WhatsNew.lines > 0
	if not (present or jar > 0 or hasNews) then
		return false
	end
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local w = Root.panelWidth(500)
	-- (On a short screen, a phone on its side: the card keeps to the essentials.)
	local compact = Root.viewport().Y < 600
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 420))
	local list = Theme.list(content, 10)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, V.title, 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, string.format(V.heading, name), 24, "display", { LayoutOrder = 2, TextWrapped = true })
	if nights > 1 and not compact then
		Theme.text(content, string.format(V.night, ordinal(nights)), 14, "body", { Name = "Night", LayoutOrder = 3, TextColor3 = C.lightGold })
	end
	if present then
		row(content, 10, "daily", V.present.title, if compact then nil else V.present.line, V.present.key, function()
			Root.close(NAME)
			WelcomeBack.openCalendar()
		end)
	end
	if jar > 0 then
		row(content, 11, "gilt", string.format(V.jar.title, commas(jar)), if compact then nil else V.jar.line, V.jar.key, function(button: TextButton)
			if button:GetAttribute("Done") then
				return
			end
			button:SetAttribute("Done", true)
			local r = CurioState.ask({ op = "collect" })
			if type(r) == "table" and r.ok and type(r.gilt) == "number" then
				button.Text = Caps(V.jar.done)
				awayGilt = 0
				pcall(Sound.play, "coinDrop", 0.6)
				Toast.show("Your brainrots", "+" .. commas(r.gilt) .. " Gilt", 3)
			else
				button:SetAttribute("Done", nil)
				Toast.show("Your brainrots", if type(r) == "table" and type(r.why) == "string" then r.why else "One moment: try again.", 3)
			end
		end)
	end
	if hasNews then
		local box = Instance.new("Frame")
		box.Name = "News"
		box.BackgroundTransparency = 1
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.Size = UDim2.new(1, 0, 0, 0)
		box.LayoutOrder = 20
		box.Parent = content
		local bl = Theme.list(box, 6)
		bl.HorizontalAlignment = Enum.HorizontalAlignment.Left
		Theme.text(box, V.news, 11, "caps", { LayoutOrder = 1, TextColor3 = C.lightGold })
		for i, line in Voice.WhatsNew.lines do
			if compact and i > 2 then
				break
			end
			local item = Instance.new("Frame")
			item.Name = "Item" .. i
			item.BackgroundTransparency = 1
			item.AutomaticSize = Enum.AutomaticSize.Y
			item.Size = UDim2.new(1, 0, 0, 0)
			item.LayoutOrder = 1 + i
			item.Parent = box
			local dot = Instance.new("Frame")
			dot.Name = "Dot"
			dot.Position = UDim2.fromOffset(4, 8)
			dot.Size = UDim2.fromOffset(5, 5)
			dot.BorderSizePixel = 0
			dot.BackgroundColor3 = C.gold
			dot.Parent = item
			local dc = Instance.new("UICorner")
			dc.CornerRadius = UDim.new(1, 0)
			dc.Parent = dot
			Theme.text(item, line, 14, "body", {
				Name = "Line",
				Position = UDim2.fromOffset(18, 0),
				Size = UDim2.new(1, -18, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.bone,
			})
		end
	end
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 30
	keys.Parent = content
	local kl = Theme.list(keys, 10, true)
	kl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(keys, V.go, false, function()
		Root.close(NAME)
	end, 180)
	Theme.fitHeight(group, content)
	Root.open(NAME, group)
	return true
end

-- On arrival (a returning guest): once the screen is free, the card if there's anything to say.
-- Returns at once; `fallback` runs if no card was shown (nothing to say, or never a free moment).
function WelcomeBack.offer(news: boolean, nights: number, fallback: (() -> ())?)
	if shown then
		return
	end
	shown = true
	task.spawn(function()
		for _ = 1, 120 do
			if not Root.isOpen() and not WelcomeBack.isBusy() then
				local cal = WelcomeBack.calendar()
				local present = type(cal) == "table" and cal.ready == true
				local jar = awayGilt
				local ok, held = pcall(CurioState.jar)
				if ok and type(held) == "number" then
					jar = math.max(jar, math.floor(held))
				end
				local name = Names.of(Players.LocalPlayer)
				if not WelcomeBack.open(name, nights, news, present, jar) and fallback then
					fallback()
				end
				return
			end
			task.wait(0.5)
		end
		if fallback then
			fallback()
		end
	end)
end

function WelcomeBack.isOpen(): boolean
	return Root.isOpen(NAME)
end

return WelcomeBack
