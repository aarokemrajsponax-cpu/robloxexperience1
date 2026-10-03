--!strict
-- For the owner: anything that goes wrong on this screen (a script error, or a "[Maison] ..."
-- warning) shows in a small panel in the bottom-right corner, so a screenshot is enough to say
-- exactly what broke. Shown in Studio, and in live games only to the owner and their helpers.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Brand = require(game:GetService("ReplicatedStorage").Shared.Brand)
local Root = require(script.Parent.Root)

local ErrorNotice = {}

local panel: Frame? = nil
local lines: { string } = {}

local function allowed(): boolean
	return RunService:IsStudio() or Players.LocalPlayer:GetAttribute("MaisonAdmin") == true
end

local function draw()
	local f = panel
	if not f then
		local nf = Instance.new("Frame")
		nf.Name = "Errors"
		nf.AnchorPoint = Vector2.new(1, 1)
		nf.Position = UDim2.new(1, -10, 1, -10)
		nf.Size = UDim2.fromOffset(460, 0)
		nf.AutomaticSize = Enum.AutomaticSize.Y
		nf.BackgroundColor3 = Color3.fromRGB(40, 12, 12)
		nf.BackgroundTransparency = 0.08
		nf.BorderSizePixel = 0
		nf.ZIndex = 50
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent = nf
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 4)
		list.Parent = nf
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.LayoutOrder = 0
		close.Size = UDim2.new(1, 0, 0, 18)
		close.BackgroundTransparency = 1
		close.FontFace = Brand.Fonts.bodyBold
		close.TextSize = 13
		close.TextXAlignment = Enum.TextXAlignment.Left
		close.TextColor3 = Color3.fromRGB(255, 190, 170)
		close.Text = "For the owner only · click to hide"
		close.ZIndex = 51
		close.Activated:Connect(function()
			nf.Visible = false
			lines = {}
		end)
		close.Parent = nf
		nf.Parent = Root.hud
		panel = nf
		f = nf
	end
	local frame = f :: Frame
	for _, c in frame:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	for i, line in lines do
		local l = Instance.new("TextLabel")
		l.LayoutOrder = i
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.BackgroundTransparency = 1
		l.FontFace = Brand.Fonts.body
		l.TextSize = 12
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.fromRGB(245, 230, 225)
		l.Text = line
		l.ZIndex = 51
		l.Parent = frame
	end
	frame.Visible = true
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

function ErrorNotice.add(message: string)
	if not allowed() then
		return
	end
	if isStudioSaveNoise(message) then
		if studioHintShown then
			return
		end
		studioHintShown = true
		message = STUDIO_SAVE
	elseif isServiceHiccup(message) then
		if hiccupShown then
			return
		end
		hiccupShown = true
		message = SERVICE_HICCUP
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
