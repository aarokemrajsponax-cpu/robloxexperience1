--!strict
-- The house's events, on every guest's screen: a slim strip under the top of the screen naming
-- what's on and how long it has left (Golden Hour · Gilt counts double · 12:41). Announcements
-- from the owner land as a line; a summons from another house offers a key to join it. Gold coins
-- and golden keys turn slowly so they catch the eye.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AbuseNights = require(ReplicatedStorage.Shared.AbuseNights)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local EventBanner = {}

-- The strip: slim capsules of black glass at the top of the screen, below the Gilt bar and clear
-- of the keys either side, with a turning gold edge and a soft glow. The headline is set in the
-- display face in gold metal, with a live light beside it; the lines under it in the clean sans.
local STRIP_W = 500
local TOP = 62
local GAP = 6
local HEIGHT = { head = 42, line = 30, soon = 32 }
type Kind = "head" | "line" | "soon"

local TweenService = game:GetService("TweenService")

local strip = Instance.new("Frame")
strip.Name = "HouseEvents"
strip.BackgroundTransparency = 1
strip.AnchorPoint = Vector2.new(0.5, 0)
strip.Position = UDim2.new(0.5, 0, 0, TOP)
strip.Size = UDim2.fromOffset(STRIP_W, 0)
strip.AutomaticSize = Enum.AutomaticSize.Y
strip.Parent = Root.hud
Theme.list(strip, GAP).HorizontalAlignment = Enum.HorizontalAlignment.Center

local rows: { [string]: TextLabel } = {}
local holders: { [string]: Frame } = {}
local kinds: { [string]: Kind } = {}

local function still(): boolean
	return State.get("movement") == "Still"
end

-- The largest the words in a capsule may be (in screen pixels): readable on a phone, never loud
-- on a big screen. (They shrink to fit a long name rather than run off the edge.)
local function fitSize(kind: Kind): number
	local base = if kind == "head" then 17 elseif kind == "soon" then 15 else 14
	return math.floor(math.clamp(base * Root.scale, 13, base + 6) + 0.5)
end

-- (How far down the strip reaches, and how wide it is, for what comes in below it: the notices,
-- the card of what to do next.)
local function reportTop()
	local bottom = 0
	for key in rows do
		bottom += HEIGHT[kinds[key] or "line"] + GAP
	end
	Root.setTop("events", if bottom > 0 and strip.Visible then TOP + bottom else nil, STRIP_W / 2)
end
strip:GetPropertyChangedSignal("Visible"):Connect(reportTop)

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

-- The live light beside the headline: a red point that breathes, with a ring that widens from it.
local function liveLight(parent: Frame)
	local dot = Instance.new("Frame")
	dot.Name = "Live"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(0, 24, 0.5, 0)
	dot.Size = UDim2.fromOffset(9, 9)
	dot.BackgroundColor3 = Color3.fromRGB(255, 84, 84)
	dot.BorderSizePixel = 0
	dot.ZIndex = 3
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = dot
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 3
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local rs = Instance.new("UIStroke")
	rs.Color = Color3.fromRGB(255, 120, 110)
	rs.Thickness = 1.5
	rs.Transparency = 0.2
	rs.Parent = ring
	ring.Parent = dot
	dot.Parent = parent
	if not still() then
		TweenService:Create(dot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.45 }):Play()
		TweenService:Create(ring, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Size = UDim2.fromScale(3.2, 3.2) }):Play()
		TweenService:Create(rs, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Transparency = 1 }):Play()
	end
end

-- One capsule of the strip (made once, then only its words change). Returns its words.
local function pill(key: string, order: number, kind: Kind): TextLabel
	local existing = rows[key]
	if existing then
		return existing
	end
	local height = HEIGHT[kind]
	local holder = Instance.new("Frame")
	holder.Name = key
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Size = UDim2.new(if kind == "head" then 1 else 0.9, 0, 0, height)
	holder.Parent = strip
	if kind ~= "line" then
		Theme.glow(holder, Brand.Colours.glow, height // 2, if kind == "head" then 0.75 else 0.45)
	end
	-- The glass: near-black, a breath of warmth at the top, a fine gold edge turning round it.
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BackgroundTransparency = if kind == "line" then 0.1 else 0.03
	fill.ZIndex = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, height // 2)
	corner.Parent = fill
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = if kind == "line"
		then ColorSequence.new(Color3.fromRGB(24, 24, 29), Color3.fromRGB(9, 9, 12))
		else ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 37, 24)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 13, 15)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 7, 9)),
		})
	sheen.Parent = fill
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = if kind == "head" then 1.6 else 1.1
	stroke.Transparency = if kind == "line" then 0.3 else 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Theme.edge(stroke, if kind == "line" then 1.2 else 0.6)
	stroke.Parent = fill
	fill.Parent = holder
	-- A line of light along the top edge of the glass.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BorderSizePixel = 0
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Position = UDim2.new(0.5, 0, 0, 1)
	shine.Size = UDim2.new(1, -height, 0, 1)
	shine.BackgroundColor3 = Brand.Colours.brightGold
	shine.ZIndex = 2
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, if kind == "line" then 0.75 else 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Parent = shine
	shine.Parent = holder
	-- The words.
	local label = Instance.new("TextLabel")
	label.Name = "Words"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, if kind == "head" then 10 else 0, 0.5, 0)
	label.Size = UDim2.new(1, if kind == "head" then -84 else -40, 1, -10)
	label.FontFace = if kind == "head" then Brand.Fonts.display elseif kind == "soon" then Brand.Fonts.bodyBold else Brand.Fonts.body
	label.TextColor3 = if kind == "head" then Color3.new(1, 1, 1) elseif kind == "soon" then Brand.Colours.brightGold else Color3.fromRGB(226, 229, 235)
	label.TextScaled = true
	label.TextWrapped = false
	label.Text = ""
	label.ZIndex = 3
	local fit = Instance.new("UITextSizeConstraint")
	fit.Name = "Fit"
	fit.MinTextSize = 9
	fit.MaxTextSize = fitSize(kind)
	fit.Parent = label
	if kind == "head" then
		Theme.metal(label, true)
		liveLight(holder)
	end
	label.Parent = holder
	rows[key] = label
	holders[key] = holder
	kinds[key] = kind
	return label
end

-- New words in a capsule come in softly.
local function say(label: TextLabel, text: string)
	if label.Text == text then
		return
	end
	label.Text = text
	if not still() then
		label.TextTransparency = 1
		TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	end
end

local function drop(key: string)
	local h = holders[key]
	if h then
		h:Destroy()
	end
	rows[key] = nil
	holders[key] = nil
	kinds[key] = nil
end

-- (On a bigger or smaller screen, the words keep to a readable size.)
table.insert(Root.rescaled, function()
	for key, l in rows do
		local fit = l:FindFirstChild("Fit")
		if fit and fit:IsA("UITextSizeConstraint") then
			fit.MaxTextSize = fitSize(kinds[key] or "line")
		end
	end
end)

local function refresh()
	-- (At a table the strip stays out of the way whatever told it so, or didn't.)
	local atTable = seated or State.seated == true
	if strip.Visible == atTable then
		strip.Visible = not atTable
	end
	-- Admin and Mega Abuse never show a clock to the house: how long they last is AJKR's business.
	-- (Events on their own say how long they have left.)
	local abuse = Workspace:GetAttribute("AbuseUntil")
	local abusing = type(abuse) == "number" and abuse > now()
	local short = {}
	local on: { { e: HouseEvents.Event, ends: number, i: number } } = {}
	for i, e in HouseEvents.List do
		local ends = Workspace:GetAttribute(HouseEvents.attribute(e.id))
		if type(ends) == "number" and ends > now() then
			table.insert(on, { e = e, ends = ends, i = i })
			table.insert(short, if abusing then e.name else e.name .. " " .. clock(ends - now()))
		end
	end
	-- Many at once (Admin Abuse Night): one headline and one line turning through them, never a
	-- wall of strips down the screen.
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
		local head = pill("__head", 1, "head")
		-- (Tonight's night by name, "ADMIN ABUSE · THE MIDAS HEIST", on one line: the line under it
		-- turns through the events.)
		local nightId = Workspace:GetAttribute("AbuseNight")
		local night = if type(nightId) == "string" then AbuseNights.byId[nightId] else nil
		local mega = Workspace:GetAttribute("AbuseMega") == true
		say(head, if abusing and night
			then string.format("%s  ·  %s", if mega then "MEGA ABUSE" else "ADMIN ABUSE", string.upper(night.name))
			elseif abusing then string.format("%s  ·  %d EVENTS ON", if mega then "MEGA ABUSE" else "ADMIN ABUSE NIGHT", #on)
			else string.format("%d EVENTS ON  ·  %s", #on, clock(longest)))
		local a = on[math.floor(now() / 3) % #on + 1]
		say(pill("__cycle", 2, "line"), if abusing
			then string.format("%s  ·  %s", Caps(a.e.name), a.e.line)
			else string.format("%s  ·  %s  ·  %s", Caps(a.e.name), a.e.line, clock(a.ends - now())))
	else
		drop("__head")
		drop("__cycle")
		for _, a in on do
			pill(a.e.id, 2 + a.i, "line").Text = string.format("%s  ·  %s  ·  %s", Caps(a.e.name), a.e.line, clock(a.ends - now()))
		end
	end
	-- A scheduled event coming up: every screen counts down to it for the hour before.
	local at = Workspace:GetAttribute("NextEventAt")
	local name = Workspace:GetAttribute("NextEventName")
	if type(at) == "number" and type(name) == "string" and at > now() then
		pill("__next", 0, "soon").Text = string.format("%s STARTS IN %s  ·  stay in the house", Caps(name), clock(at - now()))
	elseif rows.__next then
		drop("__next")
	end
	if seated then
		EventBanner.onSeatedLine(if #short > 0 then table.concat(short, "  ·  ") else nil)
	end
	reportTop()
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
			-- (A message's arrival: the same quick two-note ping as a headline's.)
			local Sound = require(script.Parent.Parent.Sound)
			pcall(Sound.play, "notify", 0.9, 1.25)
			task.delay(0.11, function()
				pcall(Sound.play, "notify", 0.9, 1.68)
			end)
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
			-- (A running turkey is moved by the server, not bobbed here.)
			if p:IsA("BasePart") and p:GetAttribute("Moves") ~= true then
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
