--!strict
-- Your Suite (the bell by the door, in the gallery). A tab for each room; in each, every spot
-- with a picture of what stands there now (turn it to see), the pieces you own to choose from,
-- and every piece you could put there with its price, plain: Gilt (earned at the tables), Robux
-- (and the same piece for Gilt), or what it comes with (the Gold Key, a House Standing). Buying
-- one puts it straight in its spot. Nothing is random: what you see is what you get.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Furniture = require(ReplicatedStorage.Shared.Furniture)
local Suite = require(ReplicatedStorage.Shared.Suite)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local BoutiquePanel = require(script.Parent.BoutiquePanel)
local RoundPanel = require(script.Parent.RoundPanel)
local Closet = require(script.Parent.Parent.Closet)

local SuitePanel = {}

local NAME = "Suite"
local C = Brand.Colours
local ROBUX = utf8.char(0xE002)

-- What each Gold Key room holds, for the card that says it's locked.
local LOCKED = {
	dressing = "A tall glass and a chaise, for trying on your looks.",
	study = "A partners' desk and a globe.",
}

local room = "main"

local function card(parent: Instance, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Spot"
	f.BackgroundColor3 = Color3.fromRGB(22, 20, 22)
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = UDim2.new(1, 0, 0, 0)
	f.LayoutOrder = order
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.gold
	stroke.Transparency = 0.8
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = f
	local list = Theme.list(f, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	return f
end

---------------------------------------------------------------------------------------------------
-- The picture of a piece: a small turntable in a ViewportFrame
---------------------------------------------------------------------------------------------------
type Preview = { frame: ViewportFrame, model: Model?, camera: Camera?, spin: number }
local previews: { Preview } = {}

local function show(p: Preview, kind: string?, style: { [string]: any }?)
	if p.model then
		p.model:Destroy()
		p.model = nil
	end
	local empty = p.frame:FindFirstChild("Empty")
	if not kind or not style then
		if empty and empty:IsA("TextLabel") then
			empty.Visible = true
		end
		return
	end
	if empty and empty:IsA("TextLabel") then
		empty.Visible = false
	end
	local ok, model = pcall(function()
		local m = Furniture.build(kind, nil, CFrame.new(), style, false)
		return m
	end)
	if not ok or not model then
		return
	end
	-- Prompts and seats aren't part of the picture.
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	model.Parent = p.frame
	p.model = model
	local camera = p.camera
	if not camera then
		local c = Instance.new("Camera")
		c.FieldOfView = 34
		c.Parent = p.frame
		p.frame.CurrentCamera = c
		p.camera = c
		camera = c
	end
	local ok2, cf, size = pcall(function()
		return model:GetBoundingBox()
	end)
	local centre = if ok2 then (cf :: CFrame).Position else Vector3.new(0, 2, 0)
	local extent = if ok2 then math.max((size :: Vector3).X, (size :: Vector3).Y, (size :: Vector3).Z) else 6
	local dist = extent * 1.7 + 2
	(camera :: Camera).CFrame = CFrame.lookAt(centre + Vector3.new(-dist * 0.55, dist * 0.42, -dist * 0.8), centre)
end

local function newPreview(parent: Instance, order: number): Preview
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Picture"
	vp.Size = UDim2.new(1, 0, 0, 150)
	vp.BackgroundColor3 = Color3.fromRGB(34, 30, 32)
	vp.BackgroundTransparency = 0
	vp.Ambient = Color3.fromRGB(150, 140, 130)
	vp.LightColor = Color3.fromRGB(255, 236, 210)
	vp.LightDirection = Vector3.new(-0.4, -1, 0.6)
	vp.LayoutOrder = order
	vp.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = vp
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(70, 62, 60), Color3.fromRGB(20, 18, 20))
	grad.Parent = vp
	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.BackgroundTransparency = 1
	empty.Size = UDim2.fromScale(1, 1)
	empty.Text = "Nothing here yet"
	empty.FontFace = Brand.Fonts.body
	empty.TextSize = 14
	empty.TextColor3 = C.dim
	empty.Visible = false
	empty.Parent = vp
	local p: Preview = { frame = vp, model = nil, camera = nil, spin = 0 }
	table.insert(previews, p)
	return p
end

-- A key with a price on it (or what the piece comes with).
local function priceKey(parent: Instance, order: number, text: string, primary: boolean, enabled: boolean, onPress: () -> ()): TextButton
	local k = Theme.key(parent, text, primary, function()
		if enabled then
			onPress()
		end
	end, 160)
	k.Size = UDim2.fromOffset(160, 36)
	k.LayoutOrder = order
	if not enabled then
		k.BackgroundTransparency = 0.6
		k.TextTransparency = 0.35
	end
	return k
end

function SuitePanel.open(start: string?)
	if Root.isOpen(NAME) then
		return
	end
	room = start or room
	local size = Root.size()
	local w = math.min(640, size.X - 24)
	local h = math.min(680, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Your Suite", 26, "display", { LayoutOrder = 1 })
	local summary = Theme.text(content, "Every room is yours alone. Only you see it this way, and nothing here changes a score.", 13, "body", {
		LayoutOrder = 2,
		TextColor3 = C.smoke,
		TextWrapped = true,
	})

	local specs: { { string } } = {}
	for _, id in Suite.Rooms do
		table.insert(specs, { id, Suite.RoomNames[id] })
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Rooms"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 4
	scroll.Size = UDim2.new(1, 0, 1, -(26 + 40 + 46 + 44 + 8))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = C.gold
	scroll.Parent = content
	Theme.list(scroll, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll
	Theme.text(scroll, "One moment...", 14, "body", { LayoutOrder = 1, TextColor3 = C.dim })

	local view: { [string]: any }? = nil
	local fill: () -> ()

	local function reload()
		task.spawn(function()
			local v = Closet.ask({ op = "suite" })
			if type(v) == "table" and type(v.spots) == "table" and content.Parent then
				view = v
				fill()
			end
		end)
	end

	local function goldKey()
		Root.close(NAME)
		BoutiquePanel.open("goldKey")
	end

	local function place(spotId: string, id: string)
		task.spawn(function()
			local r = Closet.ask({ op = "place", spot = spotId, id = id })
			if type(r) == "table" and not r.ok then
				Toast.show("Your Suite", tostring(r.why), 3)
			end
			reload()
		end)
	end

	local function buyGilt(spotId: string, o: { [string]: any })
		task.spawn(function()
			local r = Closet.ask({ op = "buyGilt", item = o.id })
			if type(r) == "table" and r.ok then
				Closet.ask({ op = "place", spot = spotId, id = o.id })
				Toast.show("Your Suite", tostring(o.name) .. " is in your Suite.", 3)
				reload()
			else
				Toast.show("Your Suite", tostring(if type(r) == "table" and r.why then r.why else "One moment."), 3)
			end
		end)
	end

	local function buyRobux(o: { [string]: any })
		task.spawn(function()
			local r = Closet.ask({ op = "buy", item = o.id })
			if type(r) == "table" and not r.ok then
				Toast.show("Your Suite", tostring(r.why or "One moment."), 3)
			end
			-- Once it's bought, the house puts it in its spot and this page catches up.
		end)
	end

	local bar = Theme.tabs(content, specs, room, function(id: string)
		room = id
		fill()
	end, 3)

	fill = function()
		local v = view
		if not v then
			return
		end
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, p in previews do
			if p.model then
				p.model:Destroy()
			end
		end
		table.clear(previews)
		scroll.CanvasPosition = Vector2.zero
		bar.select(room)
		local gilt = if type(v.gilt) == "number" then v.gilt else Closet.gilt
		local mine, open = 0, 0
		for _, spot in v.spots do
			if spot.open then
				open += 1
				if spot.placed ~= "" then
					mine += 1
				end
			end
		end
		summary.Text = string.format("Your pieces in %d of %d places  ·  %s Gilt to spend  ·  only you see your Suite", mine, open, RoundPanel.number(gilt))
		local order = 0
		local function add(): number
			order += 1
			return order
		end
		local spotsHere = {}
		for _, spot in v.spots do
			if spot.room == room then
				table.insert(spotsHere, spot)
			end
		end
		if #spotsHere > 0 and not spotsHere[1].open then
			-- A room that comes with the Gold Key: what's in it, and the key to see it.
			local locked = card(scroll, add())
			Theme.text(locked, "Comes with the Gold Key", 16, "bodyMedium", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.lightGold })
			Theme.text(locked, (LOCKED :: any)[room] or "", 14, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = C.smoke })
			Theme.key(locked, "See the Gold Key", true, goldKey, 220).LayoutOrder = 3
			return
		end
		for _, spot in spotsHere do
			local box = card(scroll, add())
			Theme.text(box, spot.name, 13, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
			local preview = newPreview(box, 2)
			local placedItem = if spot.placed ~= "" then Wardrobe.get(spot.placed) else nil
			local nowStyle = if placedItem then placedItem.style else spot.house
			local nowName = if placedItem then placedItem.name elseif spot.house then "The house's own" else "Nothing yet"
			show(preview, Suite.kindOf(spot.id, nowStyle), nowStyle)
			local current = Theme.text(box, nowName, 17, "bodyMedium", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.bone })
			-- Pieces of yours that could stand here: tap one to put it there.
			local owned = {}
			local forSale = {}
			for _, o in spot.options do
				if o.owned then
					table.insert(owned, o)
				else
					table.insert(forSale, o)
				end
			end
			if #owned > 0 then
				local row = Instance.new("Frame")
				row.Name = "Yours"
				row.BackgroundTransparency = 1
				row.AutomaticSize = Enum.AutomaticSize.Y
				row.Size = UDim2.new(1, 0, 0, 0)
				row.LayoutOrder = 4
				row.Parent = box
				local grid = Instance.new("UIGridLayout")
				grid.CellSize = UDim2.fromOffset(186, 36)
				grid.CellPadding = UDim2.fromOffset(8, 8)
				grid.SortOrder = Enum.SortOrder.LayoutOrder
				grid.Parent = row
				local choices = { { id = "", name = if spot.house then "The house's own" else "Leave it empty" } }
				for _, o in owned do
					table.insert(choices, { id = o.id, name = o.name })
				end
				for i, choice in choices do
					local here = choice.id == spot.placed
					local k = Theme.key(row, choice.name, here, function()
						if not here then
							place(spot.id, choice.id)
						end
					end, 186)
					k.LayoutOrder = i
					k.MouseEnter:Connect(function()
						local item = if choice.id ~= "" then Wardrobe.get(choice.id) else nil
						local style = if item then item.style else spot.house
						show(preview, Suite.kindOf(spot.id, style), style)
					end)
				end
			end
			-- Every piece that could stand here, with its price, plain.
			for i, o in forSale do
				local row = Instance.new("Frame")
				row.Name = "Offer"
				row.BackgroundColor3 = Color3.fromRGB(30, 27, 28)
				row.BackgroundTransparency = 0.2
				row.AutomaticSize = Enum.AutomaticSize.Y
				row.Size = UDim2.new(1, 0, 0, 0)
				row.LayoutOrder = 10 + i
				row.Parent = box
				local rc = Instance.new("UICorner")
				rc.CornerRadius = UDim.new(0, 4)
				rc.Parent = row
				local rp = Instance.new("UIPadding")
				rp.PaddingTop = UDim.new(0, 8)
				rp.PaddingBottom = UDim.new(0, 8)
				rp.PaddingLeft = UDim.new(0, 10)
				rp.PaddingRight = UDim.new(0, 10)
				rp.Parent = row
				local text = Instance.new("Frame")
				text.BackgroundTransparency = 1
				text.AutomaticSize = Enum.AutomaticSize.Y
				text.Size = UDim2.new(1, -172, 0, 0)
				text.Parent = row
				local tl = Theme.list(text, 2)
				tl.HorizontalAlignment = Enum.HorizontalAlignment.Left
				Theme.text(text, tostring(o.name), 15, "bodyMedium", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.bone })
				Theme.text(text, tostring(o.line or ""), 13, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke })
				local keys = Instance.new("Frame")
				keys.BackgroundTransparency = 1
				keys.AnchorPoint = Vector2.new(1, 0)
				keys.Position = UDim2.fromScale(1, 0)
				keys.AutomaticSize = Enum.AutomaticSize.Y
				keys.Size = UDim2.new(0, 160, 0, 0)
				keys.Parent = row
				Theme.list(keys, 6)
				-- The price, and how it's had.
				if (o.source == "gilt" or o.source == "standing") and type(o.gilt) == "number" then
					local can = gilt >= o.gilt and (o.standing == nil or o.standingOk ~= false)
					priceKey(keys, 1, RoundPanel.number(o.gilt) .. " Gilt", can, can, function()
						buyGilt(spot.id, o)
					end)
					if o.standing then
						Theme.text(keys, "For " .. tostring(o.standing) .. "s", 12, "body", { LayoutOrder = 2, TextColor3 = C.dim })
					end
				elseif type(o.robux) == "number" then
					if o.robuxOnSale then
						priceKey(keys, 1, string.format("%s %d", ROBUX, o.robux), true, true, function()
							buyRobux(o)
						end)
					end
					if type(o.giltAlt) == "number" then
						priceKey(keys, 2, RoundPanel.number(o.giltAlt) .. " Gilt", false, gilt >= o.giltAlt, function()
							buyGilt(spot.id, o)
						end)
					end
				elseif o.source == "goldKey" then
					priceKey(keys, 1, "With the Gold Key", false, true, goldKey)
				elseif o.source == "introduction" then
					Theme.text(keys, "With the Introduction", 13, "body", { LayoutOrder = 1, TextColor3 = C.dim })
				end
				-- Hover a piece to see it in the picture.
				row.MouseEnter:Connect(function()
					local item = Wardrobe.get(o.id)
					if item then
						show(preview, Suite.kindOf(spot.id, item.style), item.style)
						current.Text = tostring(o.name) .. "  (preview)"
					end
				end)
				row.MouseLeave:Connect(function()
					show(preview, Suite.kindOf(spot.id, nowStyle), nowStyle)
					current.Text = nowName
				end)
			end
		end
	end

	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 20
	keys.Parent = content
	local keyList = Theme.list(keys, 8, true)
	keyList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local close = Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 2
	-- The shows for your Suite (fireworks, memes, gold), each plainly priced.
	Theme.key(keys, "Spectacles", false, function()
		Root.close(NAME)
		require(script.Parent.Parent.World.SuiteSpectacle).open()
	end, 170).LayoutOrder = 1
	-- The pictures turn slowly.
	local spin = RunService.RenderStepped:Connect(function(dt: number)
		for _, p in previews do
			local m = p.model
			if m and m.Parent then
				p.spin += dt * 0.35
				pcall(function()
					m:PivotTo(CFrame.Angles(0, math.sin(p.spin) * 0.6, 0))
				end)
			end
		end
	end)
	Root.open(NAME, group, function()
		spin:Disconnect()
		for _, p in previews do
			if p.model then
				p.model:Destroy()
			end
		end
		table.clear(previews)
	end)
	pcall(function()
		game:GetService("GuiService").SelectedObject = close
	end)
	-- A piece bought for Robux arrives a moment later: show it when it does.
	local changed: RBXScriptConnection? = nil
	changed = Closet.Changed:Connect(function()
		if not content.Parent then
			if changed then
				changed:Disconnect()
			end
			return
		end
		reload()
	end)
	reload()
end

return SuitePanel
