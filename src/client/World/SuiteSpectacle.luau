--!strict
-- Suite spectacles: the shows a guest buys for their own Suite; each plays the moment it's bought
-- (one saved from before plays from the bell). The server spends the show and tells this screen to
-- play it (Purchases/Spectacles); this draws it,
-- only here (a Suite is its owner's alone). Also the small screen listing the three, plainly
-- priced, with how many you hold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Parent.UI.Root)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)
local Fireworks = require(script.Parent.Fireworks)
local Midas = require(script.Parent.Midas)
local MemeTakeover = require(script.Parent.MemeTakeover)

local SuiteSpectacle = {}

local NAME = "Spectacles"
local C = Brand.Colours
local ROBUX = utf8.char(0xE002)

local function ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("SpectacleAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

-- Fireworks: the full show over the whole estate (World/Fireworks), seen best from the Suite's
-- terrace, for its owner.
local function fireworks(seconds: number)
	Fireworks.show(seconds, { scale = 1.15, watch = true })
end

-- The Meme Takeover: ninety seconds, six acts (World/MemeTakeover).
local function memes(seconds: number)
	MemeTakeover.play(seconds)
end

-- The Golden Transformation: the Midas touch (World/Midas).
local function golden(seconds: number)
	Midas.play(seconds)
end

function SuiteSpectacle.play(key: string, seconds: number?)
	-- (Bought just now with this screen open: it steps aside for the show.)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local s = seconds or 20
	if key == "spectacleFireworks" then
		fireworks(s)
	elseif key == "spectacleMemes" then
		memes(s)
	elseif key == "spectacleGolden" then
		golden(s)
	end
end

function SuiteSpectacle.open()
	if Root.isOpen(NAME) then
		return
	end
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(math.min(600, Root.size().X - 24), math.min(600, Root.size().Y - 40)))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Spectacles", 24, "display", { LayoutOrder = 1 })
	Theme.text(content, "A show in your own Suite. It starts the moment you buy it (or when you next step in). Only you see it.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke })
	-- The shows, each row as tall as its words (scrolling, on a small screen).
	local list = Instance.new("ScrollingFrame")
	list.Name = "Shows"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, 0, 1, -150)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = C.gold
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.LayoutOrder = 3
	list.Parent = content
	Theme.list(list, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local function fill()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local r = ask({ op = "list" })
		if type(r) ~= "table" or type(r.shows) ~= "table" or not list.Parent then
			return
		end
		for i, sh in r.shows do
			local row = Instance.new("Frame")
			row.Name = "Show_" .. tostring(sh.key)
			row.BackgroundColor3 = Color3.fromRGB(28, 26, 28)
			row.Size = UDim2.new(1, -8, 0, 0)
			row.AutomaticSize = Enum.AutomaticSize.Y
			row.LayoutOrder = i
			row.Parent = list
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = row
			local tall = Instance.new("UISizeConstraint")
			tall.MinSize = Vector2.new(0, 64)
			tall.Parent = row
			-- The name and its line on the left, the key on the right.
			local words = Instance.new("Frame")
			words.Name = "Words"
			words.BackgroundTransparency = 1
			words.Position = UDim2.fromOffset(12, 0)
			words.Size = UDim2.new(1, -206, 0, 0)
			words.AutomaticSize = Enum.AutomaticSize.Y
			words.Parent = row
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 8)
			pad.PaddingBottom = UDim.new(0, 10)
			pad.Parent = words
			Theme.list(words, 4).VerticalAlignment = Enum.VerticalAlignment.Top
			local name = Theme.text(words, tostring(sh.name), 16, "bodyMedium", { TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
			name.TextColor3 = C.bone
			Theme.text(words, tostring(sh.line), 12, "body", { TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, TextColor3 = C.smoke })
			local label = if sh.held > 0 then string.format("Play (%d held)", sh.held) elseif sh.ready then string.format("%s %d", ROBUX, sh.robux) else "Not on sale yet"
			local k = Theme.key(row, label, sh.held > 0 or sh.ready, function()
				task.spawn(function()
					if sh.held > 0 then
						local res = ask({ op = "play", key = sh.key })
						if type(res) == "table" and res.ok then
							Root.close(NAME)
						else
							Toast.show("Spectacles", tostring(if type(res) == "table" and res.why then res.why else "One moment."), 3)
						end
					elseif sh.ready then
						local res = ask({ op = "buy", key = sh.key })
						if type(res) == "table" and not res.ok then
							Toast.show("Spectacles", tostring(res.why or "One moment."), 3)
						end
					end
				end)
			end, 170)
			k.AnchorPoint = Vector2.new(1, 0.5)
			k.Position = UDim2.new(1, -10, 0.5, 0)
			k.Size = UDim2.fromOffset(170, 38)
		end
	end
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 48)
	keys.LayoutOrder = 4
	keys.Parent = content
	Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 200)
	Root.open(NAME, group)
	task.spawn(fill)
end

return SuiteSpectacle
