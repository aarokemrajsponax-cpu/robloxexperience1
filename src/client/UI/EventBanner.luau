--!strict
-- The house's events, on every guest's screen: a slim strip under the top of the screen naming
-- what's on and how long it has left (Golden Hour · Gilt counts double · 12:41). Announcements
-- from the owner land as a line; a summons from another house offers a key to join it. Gold coins
-- and golden keys turn slowly so they catch the eye.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local EventBanner = {}

local strip = Instance.new("Frame")
strip.Name = "HouseEvents"
strip.BackgroundTransparency = 1
strip.AnchorPoint = Vector2.new(0.5, 0)
strip.Position = UDim2.new(0.5, 0, 0, 52)
strip.Size = UDim2.fromOffset(520, 0)
strip.AutomaticSize = Enum.AutomaticSize.Y
strip.Parent = Root.hud
Theme.list(strip, 4).HorizontalAlignment = Enum.HorizontalAlignment.Center

local rows: { [string]: TextLabel } = {}

-- At a table the strip steps aside (it would lie across the top of the cloth) and what's on goes
-- to the sorting screen's header line instead, through this (set by Main).
EventBanner.onSeatedLine = function(_line: string?) end
local seated = false

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- The server's clock (the event ends are in its time); close enough from the client's own.
local function now(): number
	return Workspace:GetServerTimeNow()
end

-- One line of the strip (made once, then only its words change).
local function line(key: string, order: number, size: number, weight: string, background: Color3, thick: number?): TextLabel
	local existing = rows[key]
	if existing then
		return existing
	end
	local l = Theme.text(strip, "", size, weight :: any, {
		LayoutOrder = order,
		BackgroundTransparency = 0.2,
		BackgroundColor3 = background,
		TextColor3 = Brand.Colours.lightGold,
	})
	l.Name = key
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = l
	local stroke = Instance.new("UIStroke")
	stroke.Color = Brand.Colours.gold
	stroke.Thickness = thick or 1
	stroke.Transparency = 0.3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = l
	rows[key] = l
	return l
end

local function drop(key: string)
	local l = rows[key]
	if l then
		l:Destroy()
		rows[key] = nil
	end
end

local function refresh()
	local short = {}
	local on: { { e: HouseEvents.Event, ends: number, i: number } } = {}
	for i, e in HouseEvents.List do
		local ends = Workspace:GetAttribute(HouseEvents.attribute(e.id))
		if type(ends) == "number" and ends > now() then
			table.insert(on, { e = e, ends = ends, i = i })
			table.insert(short, e.name .. " " .. clock(ends - now()))
		end
	end
	-- Many at once (Admin Abuse Night): one headline and one line turning through them, never a
	-- wall of strips down the screen.
	local abuse = Workspace:GetAttribute("AbuseUntil")
	local abusing = type(abuse) == "number" and abuse > now()
	local compact = abusing or #on >= 3
	for _, e in HouseEvents.List do
		local still = false
		for _, a in on do
			if a.e.id == e.id then
				still = true
			end
		end
		if compact or not still then
			drop(e.id)
		end
	end
	if compact and #on > 0 then
		local longest = 0
		for _, a in on do
			longest = math.max(longest, a.ends - now())
		end
		local head = line("__head", 1, 17, "bodyBold", Color3.fromRGB(46, 30, 6), 2)
		head.Text = if abusing
			then string.format("ADMIN ABUSE NIGHT  ·  %d EVENTS ON  ·  %s", #on, clock((abuse :: number) - now()))
			else string.format("%d EVENTS ON  ·  %s", #on, clock(longest))
		-- (The headline glows in time.)
		head.TextColor3 = Brand.Colours.lightGold:Lerp(Color3.new(1, 1, 1), (math.sin(now() * 3) + 1) / 2 * 0.35)
		local a = on[math.floor(now() / 3) % #on + 1]
		line("__cycle", 2, 14, "bodyMedium", Color3.fromRGB(12, 10, 6)).Text = string.format("%s  ·  %s  ·  %s", Caps(a.e.name), a.e.line, clock(a.ends - now()))
	else
		drop("__head")
		drop("__cycle")
		for _, a in on do
			line(a.e.id, 2 + a.i, 14, "bodyMedium", Color3.fromRGB(12, 10, 6)).Text = string.format("%s  ·  %s  ·  %s", Caps(a.e.name), a.e.line, clock(a.ends - now()))
		end
	end
	-- A scheduled event coming up: every screen counts down to it for the hour before.
	local at = Workspace:GetAttribute("NextEventAt")
	local name = Workspace:GetAttribute("NextEventName")
	local soon = rows.__next
	if type(at) == "number" and type(name) == "string" and at > now() then
		if not soon then
			local l = Theme.text(strip, "", 15, "bodyBold", {
				LayoutOrder = 0,
				BackgroundTransparency = 0.15,
				BackgroundColor3 = Color3.fromRGB(40, 28, 8),
				TextColor3 = Brand.Colours.lightGold,
			})
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 14)
			pad.PaddingRight = UDim.new(0, 14)
			pad.PaddingTop = UDim.new(0, 6)
			pad.PaddingBottom = UDim.new(0, 6)
			pad.Parent = l
			local stroke = Instance.new("UIStroke")
			stroke.Color = Brand.Colours.gold
			stroke.Thickness = 1.5
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = l
			rows.__next = l
			soon = l
		end
		(soon :: TextLabel).Text = string.format("%s STARTS IN %s  ·  stay in the house", Caps(name), clock(at - now()))
	elseif soon then
		soon:Destroy()
		rows["__next"] = nil
	end
	if seated then
		EventBanner.onSeatedLine(if #short > 0 then table.concat(short, "  ·  ") else nil)
	end
end

function EventBanner.setSeated(on: boolean)
	seated = on
	strip.Visible = not on
	if not on then
		EventBanner.onSeatedLine(nil)
	end
	refresh()
end

-- A summons from the owner's house in another server: a card with a key to go there.
local function summons(m: { [string]: any })
	local NAME = "Summons"
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local size = Root.size()
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(math.min(420, size.X - 24), 220), UDim2.new(0.5, 0, 0, 150), Vector2.new(0.5, 0))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "An invitation", 22, "display", { LayoutOrder = 1 })
	local text = if type(m.text) == "string" and m.text ~= "" then m.text else "Something is happening in another house tonight."
	Theme.text(content, tostring(m.by) .. " invites you: " .. text, 14, "body", { LayoutOrder = 2, TextWrapped = true, TextColor3 = Brand.Colours.bone })
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 3
	keys.Parent = content
	Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local go = Theme.key(keys, "Go there", true, function()
		Root.close(NAME)
		Toast.show("An invitation", "On your way...", 3)
		Remotes.event("Salute"):FireServer({ op = "join", jobId = m.jobId })
	end, 170)
	Theme.key(keys, "Not now", false, function()
		Root.close(NAME)
	end, 170)
	Root.open(NAME, group, nil, false)
	pcall(function()
		game:GetService("GuiService").SelectedObject = go
	end)
end

function EventBanner.start()
	for _, e in HouseEvents.List do
		Workspace:GetAttributeChangedSignal(HouseEvents.attribute(e.id)):Connect(refresh)
	end
	Workspace:GetAttributeChangedSignal("AbuseUntil"):Connect(refresh)
	Remotes.event("Salute").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "announce" and type(m.text) == "string" then
			Toast.show("From " .. tostring(m.by), m.text, 7)
		elseif m.op == "summon" then
			summons(m)
		end
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(1)
		end
	end)
	-- Coins and keys turn and bob.
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local maison = Workspace:FindFirstChild("Maison")
		local folder = maison and maison:FindFirstChild("HouseEvents")
		if not folder then
			return
		end
		for _, p in folder:GetChildren() do
			if p:IsA("BasePart") then
				local base = p:GetAttribute("Base")
				if typeof(base) ~= "CFrame" then
					base = p.CFrame
					p:SetAttribute("Base", base)
				end
				p.CFrame = (base :: CFrame) * CFrame.new(0, math.sin(t * 2 + (base :: CFrame).Position.X) * 0.25, 0) * CFrame.Angles(t * 1.6, 0, 0)
			end
		end
	end)
end

return EventBanner
