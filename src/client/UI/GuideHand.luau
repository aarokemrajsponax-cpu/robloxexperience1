--!strict
-- The house's guiding hand (Build 87): a white-gloved hand with a gold ring on its finger, drawn
-- here from shapes (no image to load), pointing at one thing on the screen, tapping gently, with a
-- soft gold ring breathing round what it points at and a short card beside it saying what it is.
-- One at a time. It never takes a click itself: the thing it points at still works as before.
--
--   GuideHand.point(target, title, line, onDone?)  points at `target` (a GuiObject) until
--   GuideHand.clear(); "Got it" on the card (or pressing the target) ends it and calls onDone.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)

local GuideHand = {}

local GOLD = Color3.fromRGB(255, 204, 90)
local GLOVE = Color3.fromRGB(250, 246, 238)
local GLOVE_EDGE = Color3.fromRGB(196, 186, 170)
local LACQUER = Color3.fromRGB(18, 15, 12)

local holder: Frame? = nil
local raised: { inst: GuiObject, z: number }? = nil
local loop: RBXScriptConnection? = nil
local pressed: RBXScriptConnection? = nil
local doneFn: (() -> ())? = nil
local pointing: GuiObject? = nil

function GuideHand.active(): boolean
	return holder ~= nil
end

-- What it's pointing at (for tests).
function GuideHand.target(): GuiObject?
	return pointing
end

local function roundAt(parent: Instance, name: string, x: number, y: number, w: number, h: number, colour: Color3, radius: number?, z: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.ZIndex = z or 52
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or math.floor(math.min(w, h) / 2))
	c.Parent = f
	f.Parent = parent
	return f
end

local function edge(f: Frame, colour: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = colour
	s.Thickness = thickness or 1
	s.Parent = f
end

-- The hand, pointing left, in a 76 by 46 box: the index finger out with a gold ring and its
-- stone, the other fingers curled under, the thumb along the top, a lacquered cuff trimmed in gold.
-- (Build 104) `mirrored`: pointing right, for a key on the right of the screen (the same hand,
-- every piece laid from the other side).
local function drawHand(parent: Instance, mirrored: boolean?): Frame
	local hand = Instance.new("Frame")
	hand.Name = "Hand"
	hand.BackgroundTransparency = 1
	hand.Size = UDim2.fromOffset(76, 46)
	hand.ZIndex = 52
	hand.Parent = parent
	local function round(p: Instance, name: string, x: number, y: number, w: number, h: number, colour: Color3, radius: number?, z: number?): Frame
		return roundAt(p, name, if mirrored then 76 - x - w else x, y, w, h, colour, radius, z)
	end
	local finger = round(hand, "Finger", 0, 12, 40, 11, GLOVE, nil, 53)
	edge(finger, GLOVE_EDGE)
	for i, y in { 22, 28, 34 } do
		local curl = round(hand, "Curl" .. i, 24 - i, y, 22, 8, GLOVE, nil, 52)
		edge(curl, GLOVE_EDGE)
	end
	local palm = round(hand, "Palm", 30, 9, 30, 32, GLOVE, 10, 52)
	edge(palm, GLOVE_EDGE)
	local thumb = round(hand, "Thumb", 33, 3, 20, 9, GLOVE, nil, 53)
	edge(thumb, GLOVE_EDGE)
	-- (The ring: a gold band round the finger near the hand, a white stone on it.)
	local band = round(hand, "Ring", 30, 10, 5, 15, GOLD, 2, 54)
	edge(band, Color3.fromRGB(170, 120, 30))
	local stone = round(hand, "Stone", 29, 6, 7, 7, Color3.fromRGB(236, 248, 255), 1, 55)
	stone.Rotation = 45
	edge(stone, GOLD)
	local cuff = round(hand, "Cuff", 58, 6, 18, 38, LACQUER, 5, 53)
	edge(cuff, GOLD, 1.5)
	return hand
end

function GuideHand.clear()
	if loop then
		loop:Disconnect()
		loop = nil
	end
	if pressed then
		pressed:Disconnect()
		pressed = nil
	end
	if holder then
		holder:Destroy()
		holder = nil
	end
	local r = raised
	if r and r.inst.Parent then
		r.inst.ZIndex = r.z
	end
	raised = nil
	pointing = nil
	doneFn = nil
end

-- Ends it as done (the guest pressed what it pointed at, or Got it).
function GuideHand.done()
	local fn = doneFn
	GuideHand.clear()
	if fn then
		pcall(fn)
	end
end

function GuideHand.point(target: GuiObject, title: string, line: string, onDone: (() -> ())?)
	GuideHand.clear()
	doneFn = onDone
	pointing = target
	-- (Laid on the target itself, or on what holds it when it clips what's on it, so it stays with
	-- it wherever it's placed and goes when it goes; that holder is raised over its neighbours
	-- meanwhile, so the card beside it is never under the next key.)
	-- (Build 104: what holds a clipping target may be the screen itself, as for the HOUSE TOUR key:
	-- the hand was laid inside the key then, and clipped away by it; it never showed.)
	local host: Instance = target
	local parent = target.Parent
	if target.ClipsDescendants and parent and (parent:IsA("GuiObject") or parent:IsA("LayerCollector")) then
		host = parent
	end
	if host:IsA("GuiObject") then
		local g = host :: GuiObject
		raised = { inst = g, z = g.ZIndex }
		g.ZIndex = math.max(g.ZIndex, 20)
	else
		raised = nil
	end
	local layer = Instance.new("Frame")
	layer.Name = "MaisonGuideHand"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 50
	layer.Parent = host
	holder = layer
	-- (Build 104) Laid on what holds the target, the layer takes the target's own place and size
	-- (each frame: it may glide), so the ring, the hand and the card stand round the target and
	-- not round the whole screen. Until now the HOUSE TOUR key's hand was drawn off the screen.
	local function follow()
		if host ~= target then
			layer.AnchorPoint = target.AnchorPoint
			layer.Position = target.Position
			layer.Size = target.Size
		end
	end
	follow()
	-- (Build 104) A target on the right of the screen: the hand points at it from its left, the
	-- card on that side too (and above the hand, not below it, near the foot of the screen).
	-- (Read from where the target is placed, its anchoring to the screen's right or foot; and
	-- where it's drawn, when that can be read.)
	local mirrored = target.Position.X.Scale >= 0.5
	local low = target.Position.Y.Scale >= 0.75
	pcall(function()
		local camera = workspace.CurrentCamera
		local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local size = target.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			local mid = target.AbsolutePosition + size / 2
			mirrored = mid.X > vp.X / 2
			low = mid.Y > vp.Y * 0.6
		end
	end)
	-- The ring round the target, breathing.
	local halo = Instance.new("Frame")
	halo.Name = "Halo"
	halo.BackgroundTransparency = 1
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.ZIndex = 51
	halo.Parent = layer
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 16)
	hc.Parent = halo
	local hs = Instance.new("UIStroke")
	hs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hs.Color = GOLD
	hs.Thickness = 3
	hs.Parent = halo
	local hand = drawHand(layer, mirrored)
	-- The card beside it: what it is, in a sentence, and Got it.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = LACQUER
	card.BackgroundTransparency = 0.04
	card.Size = UDim2.fromOffset(260, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.ZIndex = 52
	card.Parent = layer
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 12)
	cc.Parent = card
	local cs = Instance.new("UIStroke")
	cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cs.Color = GOLD
	cs.Transparency = 0.2
	cs.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.FontFace = Brand.Fonts.display
	t.TextSize = 15
	t.TextColor3 = GOLD
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Text = string.upper(title)
	t.LayoutOrder = 1
	t.ZIndex = 53
	t.Parent = card
	local l = Instance.new("TextLabel")
	l.Name = "Line"
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.FontFace = Brand.Fonts.body
	l.TextSize = 14
	l.TextColor3 = Color3.fromRGB(236, 228, 214)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = line
	l.LayoutOrder = 2
	l.ZIndex = 53
	l.Parent = card
	local ok = Instance.new("TextButton")
	ok.Name = "GotIt"
	ok.AutoButtonColor = true
	ok.BackgroundColor3 = GOLD
	ok.Size = UDim2.fromOffset(84, 28)
	ok.FontFace = Brand.Fonts.bodyBold
	ok.TextSize = 13
	ok.TextColor3 = Color3.fromRGB(28, 20, 8)
	ok.Text = "Got it"
	ok.LayoutOrder = 3
	ok.ZIndex = 54
	ok.Parent = card
	local oc = Instance.new("UICorner")
	oc.CornerRadius = UDim.new(1, 0)
	oc.Parent = ok
	ok.Activated:Connect(GuideHand.done)
	if target:IsA("GuiButton") then
		pressed = (target :: GuiButton).Activated:Connect(GuideHand.done)
	end
	local t0 = os.clock()
	local function place()
		if not target.Parent then
			GuideHand.clear()
			return
		end
		local k = os.clock() - t0
		local breathe = 0.5 + 0.5 * math.sin(k * 4)
		halo.Position = UDim2.fromScale(0.5, 0.5)
		halo.Size = UDim2.new(1, 10 + breathe * 6, 1, 10 + breathe * 6)
		hs.Transparency = 0.1 + 0.45 * breathe
		-- (The tap: toward the target and back.)
		local tap = math.max(0, math.sin(k * 5)) * 7
		follow()
		if mirrored then
			hand.Position = UDim2.new(0, -90 + tap, 0.5, -23)
			card.AnchorPoint = Vector2.new(1, if low then 1 else 0)
			card.Position = UDim2.new(0, -98, 0.5, if low then 23 else 16)
		else
			hand.Position = UDim2.new(1, 14 - tap, 0.5, -23)
			-- (The card a little lower than the hand, clear of the keys along the dock's top edge.)
			card.AnchorPoint = Vector2.new(0, if low then 1 else 0)
			card.Position = UDim2.new(1, 92, 0.5, if low then 23 else 16)
		end
	end
	place()
	loop = RunService.Heartbeat:Connect(place)
end

return GuideHand
