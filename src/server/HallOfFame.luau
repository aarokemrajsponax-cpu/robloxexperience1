--!strict
-- The Hall of Fame: the Grand Ballroom's six boards of the house's best, all-time, from every
-- server: the Wealthiest (the Fortune board's own), Gilt in hand, Gems, brainrots held, Wardrobe
-- pieces owned and curios held. Each figure is the server's own count from a guest's saved record;
-- a guest is offered to the boards when they arrive, every few minutes while they're here and as
-- they leave, and only when a figure has changed. A guest whose Fortune is private (Settings: Show
-- my Fortune, Off) is never on them, and is taken off once if they were. The boards are read every
-- two minutes and drawn on the hall's north wall.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local Names = require(ReplicatedStorage.Shared.Names)
local Plan = require(ReplicatedStorage.Shared.Gala)
local Fortune = require(script.Parent.Fortune)
local Gate = require(script.Parent.Gate)
local Profiles = require(script.Parent.Profiles)

local HallOfFame = {}

export type Entry = { userId: number, name: string, score: number }

local SIZE = 10
local OWN: { [string]: boolean } = { gilt = true, gems = true, brainrots = true, cosmetics = true, items = true }
local cache: { [string]: { Entry } } = {}
local sent: { [Player]: { [string]: number } } = {}
local names: { [number]: string } = {}

local function cfg(): { [string]: any }
	return ((Config.data :: any).Attractions or {}).gala or {}
end

local function store(id: string): any
	return DataStoreService:GetOrderedDataStore(tostring(cfg().hallStore or "MaisonHall_v1") .. "_" .. id)
end

local function shown(data: Profiles.Data): boolean
	return (data.settings :: any).showFortune ~= "Off"
end

-- A guest's figures for the boards, from their saved record.
function HallOfFame.figures(data: Profiles.Data): { [string]: number }
	local d = data :: any
	local brainrots, items = 0, 0
	local held = if type(d.curios) == "table" and type(d.curios.items) == "table" then d.curios.items else {}
	for id, n in held do
		local c = CurioList.byId[id]
		if c and type(n) == "number" and n > 0 then
			if c.family == "meme" then
				brainrots += n
			else
				items += n
			end
		end
	end
	local cosmetics = 0
	for _, v in (if type(d.owned) == "table" then d.owned else {}) do
		if v == true then
			cosmetics += 1
		end
	end
	local gemOwned = if type(d.gemShop) == "table" and type(d.gemShop.owned) == "table" then d.gemShop.owned else {}
	for _, v in gemOwned do
		if v == true then
			cosmetics += 1
		end
	end
	return {
		gilt = math.max(0, math.floor(if type(d.gilt) == "number" then d.gilt else 0)),
		gems = math.max(0, math.floor(if type(d.gems) == "number" then d.gems else 0)),
		brainrots = brainrots,
		cosmetics = cosmetics,
		items = items,
	}
end

-- Offers a guest's figures to the boards (only what has changed since the last time).
function HallOfFame.submit(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local last = sent[player]
	if not last then
		last = {}
		sent[player] = last
	end
	local key = tostring(player.UserId)
	if not shown(data) then
		for id in OWN do
			if last[id] ~= 0 then
				last[id] = 0
				Gate.write("hall:" .. id, function()
					store(id):RemoveAsync(key)
				end)
			end
		end
		return
	end
	for id, value in HallOfFame.figures(data) do
		if OWN[id] and value > 0 and last[id] ~= value then
			last[id] = value
			Gate.write("hall:" .. id, function()
				store(id):SetAsync(key, value)
			end)
		end
	end
end

local function nameOf(userId: number): string
	local known = names[userId]
	if known then
		return known
	end
	local player = Players:GetPlayerByUserId(userId)
	local name = if player then Names.of(player) else nil
	if not name then
		local ok, found = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok and type(found) == "string" then found else "A guest"
	end
	names[userId] = name :: string
	return name :: string
end

-- Reads every board (a store that doesn't answer keeps what was read last).
function HallOfFame.refresh()
	for id in OWN do
		local ok, page = Gate.read("hall:" .. id, function()
			return store(id):GetSortedAsync(false, SIZE):GetCurrentPage()
		end)
		if ok and type(page) == "table" then
			local out: { Entry } = {}
			for _, item in page :: { any } do
				local userId = tonumber(item.key)
				if userId and type(item.value) == "number" and item.value > 0 then
					table.insert(out, { userId = userId, name = nameOf(userId), score = item.value })
				end
			end
			cache[id] = out
		end
	end
	cache.fortune = Fortune.top()
end

function HallOfFame.board(id: string): { Entry }
	return cache[id] or {}
end

---------------------------------------------------------------------------------------------------
-- The boards in the hall
---------------------------------------------------------------------------------------------------
type Face = { title: TextLabel, rows: { { rank: TextLabel, name: TextLabel, score: TextLabel } }, empty: TextLabel }
local drawn: { [BasePart]: Face } = {}

local function text(parent: Instance, name: string, t: string, font: Font, colour: Color3, size: UDim2, pos: UDim2, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.FontFace = font
	l.Text = t
	l.TextColor3 = colour
	l.TextScaled = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function face(part: BasePart): Face?
	local known = drawn[part]
	if known then
		return known
	end
	local id = tostring(part:GetAttribute("Board") or "")
	local def = nil
	for _, b in Plan.Boards do
		if b.id == id then
			def = b
		end
	end
	if not def then
		return nil
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.MaxDistance = 220
	gui.Parent = part
	local c = Brand.Colours
	text(gui, "Glyph", def.glyph, Brand.Fonts.body, def.colour, UDim2.new(1, 0, 0.07, 0), UDim2.new(0, 0, 0.035, 0))
	local title = text(gui, "Title", string.upper(def.name), Brand.Fonts.display, def.colour, UDim2.new(0.9, 0, 0.065, 0), UDim2.new(0.05, 0, 0.115, 0))
	text(gui, "Line", string.upper(def.line), Brand.Fonts.bodyBold, c.smoke, UDim2.new(0.9, 0, 0.032, 0), UDim2.new(0.05, 0, 0.19, 0))
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = def.colour
	rule.BackgroundTransparency = 0.4
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(0.5, 0, 0, 2)
	rule.Position = UDim2.new(0.25, 0, 0.24, 0)
	rule.Parent = gui
	local rows = {}
	for i = 1, SIZE do
		local y = 0.27 + (i - 1) * 0.069
		local top3 = i <= 3
		local colour = if i == 1 then def.colour else c.bone
		local rank = text(gui, "Rank" .. i, tostring(i), Brand.Fonts.display, if top3 then def.colour else c.smoke, UDim2.new(0.12, 0, 0.05, 0), UDim2.new(0.04, 0, y, 0))
		local name = text(gui, "Name" .. i, "", if top3 then Brand.Fonts.bodyBold else Brand.Fonts.body, colour, UDim2.new(0.52, 0, 0.045, 0), UDim2.new(0.17, 0, y + 0.003, 0), Enum.TextXAlignment.Left)
		local score = text(gui, "Score" .. i, "", Brand.Fonts.bodyBold, colour, UDim2.new(0.28, 0, 0.045, 0), UDim2.new(0.68, 0, y + 0.003, 0), Enum.TextXAlignment.Right)
		table.insert(rows, { rank = rank, name = name, score = score })
	end
	local empty = text(gui, "Empty", "The first names are still to be written.", Brand.Fonts.body, c.smoke, UDim2.new(0.8, 0, 0.05, 0), UDim2.new(0.1, 0, 0.5, 0))
	local made: Face = { title = title, rows = rows, empty = empty }
	drawn[part] = made
	return made
end

function HallOfFame.draw()
	for _, part in CollectionService:GetTagged("HallBoard") do
		if part:IsA("BasePart") then
			local f = face(part)
			if f then
				local list = HallOfFame.board(tostring(part:GetAttribute("Board")))
				for i, row in f.rows do
					local e = list[i]
					row.name.Text = if e then e.name else ""
					row.score.Text = if e then Plan.commas(e.score) else ""
					row.rank.Visible = e ~= nil
				end
				f.empty.Visible = #list == 0
			end
		end
	end
end

function HallOfFame.start()
	Profiles.Loaded:Connect(function(player: Player)
		task.delay(5, function()
			if player.Parent then
				pcall(HallOfFame.submit, player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pcall(HallOfFame.submit, player)
		sent[player] = nil
	end)
	task.spawn(function()
		local sinceSubmit = 0
		while true do
			pcall(HallOfFame.refresh)
			pcall(HallOfFame.draw)
			task.wait(math.max(30, tonumber(cfg().hallSeconds) or 120))
			sinceSubmit += 1
			if sinceSubmit >= 2 then
				sinceSubmit = 0
				for _, player in Players:GetPlayers() do
					pcall(HallOfFame.submit, player)
				end
			end
		end
	end)
end

return HallOfFame
