--!strict
-- For the owner: anything that goes wrong on this screen (a script error, or a "[Maison] ..."
-- warning) shows in a small panel in the bottom-right corner, so a screenshot is enough to say
-- exactly what broke. Shown in Studio, and in live games only to the owner.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Brand = require(game:GetService("ReplicatedStorage").Shared.Brand)
local Root = require(script.Parent.Root)

local ErrorNotice = {}

-- Real faults (a script error, a "[Maison]" warning) stay in the panel until hidden. Roblox's own
-- services having a moment (saving in Studio, the live leaderboards) are not faults: those come
-- as a calm house note, once each, that leaves by itself.
local panel: Frame? = nil
local lines: { string } = {}
local NOTE_SECONDS = 14

local CORAL = Color3.fromRGB(255, 138, 120)
local GOLD = Color3.fromRGB(255, 214, 140)
local INK = Color3.fromRGB(236, 238, 242)
local SMOKE = Color3.fromRGB(194, 199, 207)

local function allowed(): boolean
	return RunService:IsStudio() or Players.LocalPlayer:GetAttribute("MaisonAdmin") == true
end

-- A card in the bottom-right corner: black glass, a fine edge, room to read.
local function card(name: string, edge: Color3, width: number): (Frame, Frame)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(1, 1)
	f.Position = UDim2.new(1, -12, 1, -12)
	f.Size = UDim2.fromOffset(width, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundColor3 = Color3.fromRGB(10, 11, 14)
	f.BackgroundTransparency = 0.06
	f.BorderSizePixel = 0
	f.ZIndex = 50
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = edge
	stroke.Transparency = 0.35
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = f
	-- The lines, one under another, in a body of their own (so a click area over the whole card
	-- isn't taken for a line).
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.ZIndex = 51
	body.Parent = f
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = body
	return f, body
end

local function label(parent: Instance, text: string, order: number, font: Font, size: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = colour
	l.Text = text
	l.ZIndex = 51
	l.Parent = parent
	return l
end

local function draw()
	local f = panel
	if not f then
		local nf, nbody = card("Errors", CORAL, 460)
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.LayoutOrder = 0
		close.Size = UDim2.new(1, 0, 0, 18)
		close.BackgroundTransparency = 1
		close.FontFace = Brand.Fonts.bodyBold
		close.TextSize = 12
		close.TextXAlignment = Enum.TextXAlignment.Left
		close.TextColor3 = CORAL
		close.Text = "FOR THE OWNER ONLY  ·  CLICK TO HIDE"
		close.ZIndex = 51
		close.Activated:Connect(function()
			nf.Visible = false
			lines = {}
		end)
		close.Parent = nbody
		nf.Parent = Root.hud
		panel = nf
		f = nf
	end
	local frame = f :: Frame
	local body = frame:FindFirstChild("Body") or frame
	for _, c in body:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	for i, line in lines do
		label(body, "●  " .. line, i, Brand.Fonts.body, 14, INK)
	end
	frame.Visible = true
end

-- A calm house note (not an error): gold edge, plain words, gone by itself after a while.
local function note(text: string)
	local f, body = card("HouseNote", GOLD, 400)
	-- Above the panel of faults, if that's up too.
	local p = panel
	if p and p.Visible then
		local ok, height = pcall(function(): number
			return p.AbsoluteSize.Y / math.max(0.1, Root.scale)
		end)
		f.Position = UDim2.new(1, -12, 1, -12 - (if ok and height > 0 then height else 120) - 8)
	end
	label(body, "HOUSE NOTE  ·  FOR THE OWNER", 0, Brand.Fonts.bodyBold, 12, GOLD)
	label(body, text, 1, Brand.Fonts.body, 14, SMOKE)
	local hide = Instance.new("TextButton")
	hide.Name = "Hide"
	hide.BackgroundTransparency = 1
	hide.Size = UDim2.fromScale(1, 1)
	hide.Text = ""
	hide.ZIndex = 52
	hide.Activated:Connect(function()
		f:Destroy()
	end)
	hide.Parent = f
	-- Over any earlier note: the newest is the one to read.
	local existing = Root.hud:FindFirstChild("HouseNote")
	if existing then
		existing:Destroy()
	end
	f.Parent = Root.hud
	task.delay(NOTE_SECONDS, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end

-- Studio blocks saving until "Studio Access to API Services" is on: that isn't a fault in the
-- game, so instead of a stream of red lines it gets one plain line saying how to turn it on.
local STUDIO_SAVE = "Studio isn't allowed to save yet (normal; the live game saves). To save in Studio too: Home tab → Game Settings → Security → turn on Enable Studio Access to API Services → Save."
local studioHintShown = false

local function isStudioSaveNoise(message: string): boolean
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "Studio access to APIs is not allowed", 1, true) ~= nil
		or string.find(message, "API access is not enabled", 1, true) ~= nil
		or (string.find(message, "DataStore", 1, true) ~= nil and string.find(message, "Studio", 1, true) ~= nil)
end

-- Roblox's own saving service failing for a moment (a 502 "internal server error", "API
-- Services rejected request"): not a fault in the game, and everything is retried, so it's one
-- plain line once, not a stream of red ones.
local SERVICE_HICCUP = "Roblox's saving service had a hiccup (it happens, most often in Studio). Nothing is lost: progress and purchases are kept and saved again automatically."
local hiccupShown = false

local function isServiceHiccup(message: string): boolean
	return string.find(message, "InternalServerError", 1, true) ~= nil
		or string.find(message, "internal server error", 1, true) ~= nil
		or string.find(message, "API Services rejected request", 1, true) ~= nil
		or string.find(message, "502", 1, true) ~= nil and string.find(message, "DataStore", 1, true) ~= nil
		or string.find(message, "Purchase ledger", 1, true) ~= nil
		or string.find(message, "Ledger write failed", 1, true) ~= nil
		or string.find(message, "Request was throttled", 1, true) ~= nil
end

-- Roblox's MemoryStore (the live leaderboards, the weekend's standings) not answering: "Unknown
-- Error", mostly in Studio. Roblox prints each one in red even though the house catches it, rests
-- that store a while and shows this server's own scores meanwhile (server/Gate): one plain line,
-- once.
local BOARDS_HICCUP = "Roblox's live leaderboards didn't answer for a moment (common in Studio). Nothing is lost: the boards show this server's scores meanwhile and ask again later."
local boardsShown = false

local function isMemoryStoreNoise(message: string): boolean
	return string.find(message, "MemoryStoreService", 1, true) ~= nil or string.find(message, "MemoryStore", 1, true) ~= nil and string.find(message, "Error", 1, true) ~= nil
end

function ErrorNotice.add(message: string)
	if not allowed() then
		return
	end
	if isMemoryStoreNoise(message) then
		if not boardsShown then
			boardsShown = true
			pcall(note, BOARDS_HICCUP)
		end
		return
	elseif isStudioSaveNoise(message) then
		if not studioHintShown then
			studioHintShown = true
			pcall(note, STUDIO_SAVE)
		end
		return
	elseif isServiceHiccup(message) then
		if not hiccupShown then
			hiccupShown = true
			pcall(note, SERVICE_HICCUP)
		end
		return
	end
	local first = string.sub((string.split(message, "\n"))[1] or message, 1, 220)
	if lines[#lines] == first then
		return
	end
	table.insert(lines, first)
	while #lines > 4 do
		table.remove(lines, 1)
	end
	pcall(draw)
end

function ErrorNotice.start()
	task.spawn(function()
		local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
		Remotes.event("Errors").OnClientEvent:Connect(function(message: any)
			ErrorNotice.add(tostring(message))
		end)
	end)
	LogService.MessageOut:Connect(function(message: string, kind: Enum.MessageType)
		if kind == Enum.MessageType.MessageError or (kind == Enum.MessageType.MessageWarning and string.find(message, "[Maison]", 1, true)) then
			ErrorNotice.add(message)
		end
	end)
end

return ErrorNotice
