--!strict
-- The attractions on a guest's screen (shared/Attractions): each one's own screen is shown while,
-- and only while, the server says they're in it (the "Attraction" attribute), and goes the moment
-- they're out. What the server tells them about it (the Attraction event) comes here first: going
-- in and out, the house's notices, the board at the Luxe Lounge's lectern, and Stride while they
-- walk a treadmill in the Lounge (a small count at the foot of the screen). Luxury Island's jet
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
local IslandHud = require(script.Parent.IslandHud)
local IslandPanel = require(script.Parent.IslandPanel)
local IslandView = require(script.Parent.Parent.World.IslandView)
local LuxeHud = require(script.Parent.LuxeHud)
local LuxePanel = require(script.Parent.LuxePanel)
local Root = require(script.Parent.Root)
local Toast = require(script.Parent.Toast)

local Attraction = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 204, 90)

local chip: TextLabel? = nil
local chipUntil = 0

local function strideChip(m: { [string]: any })
	local c = chip
	if not c then
		local l = Instance.new("TextLabel")
		l.Name = "StrideChip"
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Size = UDim2.fromOffset(0, 30)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.BackgroundColor3 = Color3.fromRGB(16, 13, 9)
		l.BackgroundTransparency = 0.08
		l.FontFace = Brand.Fonts.bodyBold
		l.TextSize = 13
		l.TextColor3 = GOLD
		l.Parent = Root.hud
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 15)
		corner.Parent = l
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = l
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = GOLD
		edge.Transparency = 0.3
		edge.Parent = l
		chip = l
		c = l
	end
	local label = c :: TextLabel
	label.Position = UDim2.new(0.5, 0, 1, -(70 + Root.bottomClear()))
	local nextAt = tonumber(m.next)
	label.Text = string.format("%sSTRIDE  ·  LEVEL %d  ·  %s", if m.golden then "GOLDEN  ·  " else "", tonumber(m.level) or 1, if nextAt then string.format("%d / %d", tonumber(m.points) or 0, nextAt) else "THE TOP")
	label.Visible = true
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
				if first then
					FirstVisit.attraction(def.id)
				else
					Toast.show(def.name, def.line, 6)
				end
			end
		elseif op == "left" then
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
				GalaPanel.open(if type(m.which) == "string" then m.which else nil)
			end
		elseif op == "gala" then
			GalaView.on(m)
			if GalaHud.mounted() then
				GalaHud.on(m)
			end
		elseif op == "stride" then
			strideChip(m)
		elseif op == "invited" then
			local held = tonumber(m.invites) or 1
			Toast.show("An invitation earned", string.format("To the Executive Suite (you hold %d). Its lift is in the Executive's Anteroom, off the Foyer.", held), 5)
		elseif op == "strideUp" then
			Toast.show(string.format("Stride level %d", tonumber(m.level) or 1), string.format("%d%% faster in Steal a Luxe", tonumber(m.faster) or 0), 3)
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
