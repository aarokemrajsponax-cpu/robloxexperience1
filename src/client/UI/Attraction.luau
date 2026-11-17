--!strict
-- The attractions on a guest's screen (shared/Attractions): each one's own screen is shown while,
-- and only while, the server says they're in it (the "Attraction" attribute), and goes the moment
-- they're out. What the server tells them about it (the Attraction event) comes here first: going
-- in and out, the house's notices, the board at the Luxe Lounge's lectern, and Stride while they
-- walk a treadmill in the Lounge (Speed: a card at the foot of the screen). Luxury Island's jet
-- flies them in and home (World/IslandView), and the Jet Lounge's card opens from its arch. The
-- Grand Ballroom's screen, cards and hall (UI/GalaHud, UI/GalaPanel, World/GalaView) too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local BasementHud = require(script.Parent.BasementHud)
local BasementPanel = require(script.Parent.BasementPanel)
local ExecutiveHud = require(script.Parent.ExecutiveHud)
local ExecutivePanel = require(script.Parent.ExecutivePanel)
local FirstVisit = require(script.Parent.FirstVisit)
local GalaHud = require(script.Parent.GalaHud)
local GalaPanel = require(script.Parent.GalaPanel)
local GalaView = require(script.Parent.Parent.World.GalaView)
-- (Build 81) The Flex Studio: its card, and the reel shot on this screen.
local FlexPanel = require(script.Parent.FlexPanel)
FlexPanel.shoot = require(script.Parent.Parent.World.FlexReel).play
local IslandHud = require(script.Parent.IslandHud)
local IslandPanel = require(script.Parent.IslandPanel)
local IslandView = require(script.Parent.Parent.World.IslandView)
local LuxeHud = require(script.Parent.LuxeHud)
local LuxePanel = require(script.Parent.LuxePanel)
local LoadIn = require(script.Parent.LoadIn)
local Root = require(script.Parent.Root)
local Toast = require(script.Parent.Toast)

local Attraction = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 204, 90)

local chip: Frame? = nil
local chipUntil = 0

-- (Build 87) Speed, on a treadmill in the Luxe Lounge: a card at the foot of the screen, over the
-- keys, big enough to read while walking: SPEED and the level, a gold bar filling to the next
-- level with the points, and GOLDEN ×2 on the golden treadmill. (It was a small chip called Stride.)
local function strideChip(m: { [string]: any })
	local c = chip
	if not c then
		local card = Instance.new("Frame")
		card.Name = "SpeedCard"
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.BackgroundColor3 = Color3.fromRGB(14, 11, 8)
		card.BackgroundTransparency = 0.04
		card.Parent = Root.hud
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16)
		corner.Parent = card
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = GOLD
		edge.Thickness = 2
		edge.Transparency = 0.15
		edge.Parent = card
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 140, 130))
		shade.Parent = card
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(18, 10)
		title.Size = UDim2.new(1, -36, 0, 28)
		title.FontFace = Brand.Fonts.display
		title.TextSize = 24
		title.TextColor3 = Color3.fromRGB(255, 244, 222)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.Parent = card
		local badge = Instance.new("TextLabel")
		badge.Name = "Golden"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -14, 0, 12)
		badge.Size = UDim2.fromOffset(96, 24)
		badge.BackgroundColor3 = GOLD
		badge.FontFace = Brand.Fonts.bodyBold
		badge.TextSize = 13
		badge.TextColor3 = Color3.fromRGB(28, 20, 8)
		badge.Text = "GOLDEN  ×2"
		badge.Parent = card
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = badge
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Position = UDim2.new(0, 18, 0, 46)
		track.Size = UDim2.new(1, -136, 0, 10)
		track.BackgroundColor3 = Color3.fromRGB(58, 48, 34)
		track.Parent = card
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(1, 0)
		tc.Parent = track
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = GOLD
		fill.Parent = track
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = fill
		local count = Instance.new("TextLabel")
		count.Name = "Count"
		count.AnchorPoint = Vector2.new(1, 0)
		count.BackgroundTransparency = 1
		count.Position = UDim2.new(1, -16, 0, 40)
		count.Size = UDim2.fromOffset(108, 22)
		count.FontFace = Brand.Fonts.figures
		count.TextSize = 16
		count.TextColor3 = GOLD
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.Parent = card
		chip = card
		c = card
	end
	local card = c :: Frame
	local vp = Root.size()
	card.Size = UDim2.fromOffset(math.min(380, vp.X - 32), 72)
	card.Position = UDim2.new(0.5, 0, 1, -(76 + Root.bottomClear()))
	local nextAt = tonumber(m.next)
	local points = tonumber(m.points) or 0
	local title = card:FindFirstChild("Title") :: TextLabel
	local count = card:FindFirstChild("Count") :: TextLabel
	local badge = card:FindFirstChild("Golden") :: TextLabel
	local track = card:FindFirstChild("Track") :: Frame
	local fill = track:FindFirstChild("Fill") :: Frame
	title.Text = string.format("SPEED  ·  LEVEL %d", tonumber(m.level) or 1)
	title.Size = UDim2.new(1, if m.golden then -140 else -36, 0, 28)
	badge.Visible = m.golden == true
	count.Text = if nextAt then string.format("%d / %d", points, nextAt) else "THE TOP"
	fill.Size = UDim2.fromScale(if nextAt and nextAt > 0 then math.clamp(points / nextAt, 0, 1) else 1, 1)
	card.Visible = true
	chipUntil = os.clock() + 2.5
	task.delay(2.6, function()
		if chip and os.clock() >= chipUntil then
			chip.Visible = false
		end
	end)
end

local function follow()
	local id = player:GetAttribute(AttractionList.ATTRIBUTE)
	if id == "luxe" then
		LuxeHud.mount()
	else
		LuxeHud.unmount()
	end
	if id == "basement" then
		BasementHud.mount()
	else
		BasementHud.unmount()
	end
	if id == "executive" then
		ExecutiveHud.mount()
	else
		ExecutiveHud.unmount()
	end
	if id == "island" then
		IslandHud.mount()
		local st = IslandView.state()
		if st then
			IslandHud.update(st)
		end
	else
		IslandHud.unmount()
	end
	-- The Grand Ballroom: its screen, and the hall's light, music and dance floor on this one.
	if id == "gala" then
		GalaHud.mount()
		GalaView.enter()
	else
		GalaHud.unmount()
		GalaView.leave()
		GalaPanel.closePoses()
		if GalaPanel.isOpen() then
			Root.close("GalaCard")
		end
	end
end

function Attraction.start()
	LuxeHud.openBoard = LuxePanel.open
	-- Luxury Island: its board, photo mode at the postcards, and one state for the HUD and the world.
	IslandHud.openBoard = IslandPanel.open
	IslandHud.photo = function()
		require(script.Parent.PhotoMode).enter()
	end
	IslandView.notice = Toast.show
	local hudWas = true
	IslandView.cinematic = function(on: boolean)
		if on then
			hudWas = Root.hud.Enabled
			Root.close()
			Root.hud.Enabled = false
		else
			Root.hud.Enabled = hudWas
		end
	end
	IslandView.changed = IslandHud.update
	IslandPanel.changed = function(st: { [string]: any })
		IslandView.update(st)
		IslandHud.update(st)
	end
	-- The Grand Ballroom: one state for its screen and the hall; its cards; poses in photo mode.
	GalaView.changed = GalaHud.update
	GalaHud.openPanel = GalaPanel.open
	GalaPanel.move = GalaView.move
	GalaPanel.stop = GalaView.stopMove
	GalaPanel.state = GalaView.state
	GalaPanel.changed = GalaView.update
	GalaPanel.invite = function(userId: number, name: string)
		require(script.Parent.TradePanel).invite(userId, name)
	end
	GalaView.photo = function()
		local PhotoMode = require(script.Parent.PhotoMode)
		PhotoMode.enter()
		if not PhotoMode.isActive() then
			-- (Photo mode couldn't open: the camera framed on the set comes straight back.)
			pcall(function()
				(require(script.Parent.Parent.Camera) :: any).follow()
			end)
		end
		if PhotoMode.isActive() then
			GalaPanel.poses()
			task.spawn(function()
				while PhotoMode.isActive() do
					task.wait(0.3)
				end
				GalaPanel.closePoses()
			end)
		end
	end
	GalaView.start()
	Remotes.event("Attraction").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		local op = m.op
		if op == "entered" then
			follow()
			local def = AttractionList.byId[tostring(m.id)]
			-- (The very first time: how it works, on a card of its own; after that, a line.)
			local first = m.first == true
			if m.id == "island" then
				-- (The jet: a few seconds in its cabin while the island is made ready.)
				IslandView.flight(true)
				task.delay(6.4, function()
					if def and player:GetAttribute(AttractionList.ATTRIBUTE) == "island" then
						if first then
							FirstVisit.attraction("island")
						else
							Toast.show(def.name, "Five pearls on the lagoon's floor today, the sunset toast at the Lookout, and your jet on the airstrip to fly home.", 6)
						end
					end
				end)
			elseif def then
				local function greet()
					if first then
						FirstVisit.attraction(def.id)
					else
						Toast.show(def.name, def.line, 6)
					end
				end
				-- (Build 82) Held still a few seconds while the place is made ready: the card says
				-- so, and the greeting follows once they can move.
				if tonumber(m.hold) then
					LoadIn.start(def.id, tonumber(m.hold) :: number, function()
						-- (Still there once they can move.)
						if player:GetAttribute(AttractionList.ATTRIBUTE) == def.id then
							greet()
						end
					end)
				else
					greet()
				end
			end
		elseif op == "unheld" then
			LoadIn.finish()
		elseif op == "left" then
			LoadIn.finish(true)
			FirstVisit.hide()
			follow()
			if m.id == "island" and m.why == "home" then
				IslandView.flight(false)
			end
		elseif op == "lostOnLeaving" then
			Toast.show("Left behind", string.format("What you hadn't banked (%s) stays in the residence.", Rules.format(tonumber(m.lost) or 0)), 4)
		elseif op == "notice" then
			Toast.show(tostring(m.title or ""), tostring(m.line or ""), 3)
		elseif op == "panel" then
			if m.id == "luxe" then
				LuxePanel.open()
			elseif m.id == "basement" then
				BasementPanel.open()
			elseif m.id == "executive" then
				ExecutivePanel.open()
			elseif m.id == "auction" then
				require(script.Parent.AuctionPanel).open()
			elseif m.id == "island" then
				IslandPanel.open(if type(m.which) == "string" then m.which else nil)
			elseif m.id == "gala" then
				if m.which == "flex" or m.which == "feed" then
					FlexPanel.open(m.which)
				else
					GalaPanel.open(if type(m.which) == "string" then m.which else nil)
				end
			end
		elseif op == "gala" then
			if m.kind == "flex" then
				FlexPanel.on(m)
			end
			GalaView.on(m)
			if GalaHud.mounted() then
				GalaHud.on(m)
			end
		elseif op == "stride" then
			strideChip(m)
		elseif op == "invited" then
			local held = tonumber(m.invites) or 1
			Toast.show("An invitation earned", string.format("To the Executive Suite (you hold %d). Its lift is in the Executive's Anteroom, off the Foyer.", held), 5)
		elseif op == "islandStanding" then
			-- (Build 90) A new Island Standing rank: what it paid, and what came with it.
			local gilt = tonumber(m.gilt) or 0
			Toast.show("Island Standing: " .. tostring(m.name or ""), tostring(m.line or "") .. (if gilt > 0 then string.format("  ·  +%s Gilt", Rules.format(gilt)) else ""), 5)
		elseif op == "strideUp" then
			Toast.show(string.format("Speed level %d", tonumber(m.level) or 1), string.format("%d%% faster in Steal a Luxe", tonumber(m.faster) or 0), 3)
		elseif LuxeHud.mounted() then
			LuxeHud.on(m)
		elseif BasementHud.mounted() then
			BasementHud.on(m)
		elseif ExecutiveHud.mounted() then
			ExecutiveHud.on(m)
		elseif IslandHud.mounted() then
			IslandHud.on(m)
		end
	end)
	player:GetAttributeChangedSignal(AttractionList.ATTRIBUTE):Connect(follow)
	follow()
end

return Attraction
