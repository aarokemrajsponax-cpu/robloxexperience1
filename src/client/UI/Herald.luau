--!strict
-- The herald on every screen: a feat told to the house (server/Herald) rises as a slim band of
-- black and gold at the foot of the screen (clear of the keys, the what's-next card and notices at
-- the top, and above whatever stands along the foot), the guest's name and what they did, for a
-- few seconds; a guest's own new wealth rank is told to them with its own notice. Only what the
-- server says is shown. It waits its turn behind a headline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Prestige = require(ReplicatedStorage.Shared.Prestige)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local Herald = {}

-- Set by Main: a sound for a feat, and whether the screen is busy with something bigger (a
-- headline, the title): feats wait.
Herald.sound = function(_own: boolean) end
Herald.busy = function(): boolean
	return false
end

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 204, 90)
local waiting: { { [string]: any } } = {}
local showing = false

local function band(m: { [string]: any })
	local own = m.userId == player.UserId
	local seconds = if type(m.seconds) == "number" then math.clamp(m.seconds, 2, 10) else 5
	local w = math.min(Root.size().X - 24, 540)
	local f = Instance.new("Frame")
	f.Name = "Feat"
	f.AnchorPoint = Vector2.new(0.5, 1)
	f.Position = UDim2.new(0.5, 0, 1, 80)
	f.Size = UDim2.fromOffset(w, 54)
	f.BackgroundColor3 = Color3.fromRGB(14, 11, 8)
	f.BackgroundTransparency = 0.04
	f.Parent = Root.toasts
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = f
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = if typeof(m.colour) == "Color3" then m.colour else GOLD
	edge.Thickness = 1.5
	edge.Transparency = 0.1
	edge.Parent = f
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.Position = UDim2.fromOffset(8, 0)
	glyph.Size = UDim2.fromOffset(46, 54)
	glyph.Text = if type(m.glyph) == "string" then m.glyph else "👑"
	glyph.TextSize = 28
	glyph.FontFace = Brand.Fonts.body
	glyph.Parent = f
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(58, 6)
	title.Size = UDim2.new(1, -70, 0, 16)
	title.FontFace = Brand.Fonts.bodyBold
	title.TextSize = 12
	title.TextColor3 = GOLD
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Text = string.upper(tostring(m.title or "A FEAT")) .. (if type(m.worth) == "number" and m.worth > 0 then "  ·  " .. Rules.format(m.worth) else "")
	title.Parent = f
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(58, 23)
	line.Size = UDim2.new(1, -70, 0, 26)
	line.FontFace = Brand.Fonts.bodyMedium
	line.TextSize = 15
	line.TextColor3 = Color3.new(1, 1, 1)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.TextWrapped = true
	line.Text = (if own then "You" else tostring(m.name or "A guest")) .. " " .. tostring(m.line or "")
	Theme.fit(line, 15, 11)
	line.Parent = f
	pcall(Herald.sound, own)
	local rise = 96 + Root.bottomClear()
	Ease.play(f, Ease.info(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, -rise) })
	task.delay(seconds, function()
		if f.Parent then
			Ease.play(f, Ease.info(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 1, 80) })
			task.delay(0.4, function()
				f:Destroy()
			end)
		end
	end)
	return seconds + 0.5
end

local function drain()
	if showing then
		return
	end
	showing = true
	task.spawn(function()
		while #waiting > 0 do
			local held = 0
			while Herald.busy() and held < 20 do
				held += task.wait(0.5)
			end
			local m = table.remove(waiting, 1)
			if m then
				task.wait(band(m))
			end
		end
		showing = false
	end)
end

function Herald.start()
	Remotes.event("Empire").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "feat" and type(m.line) == "string" then
			table.insert(waiting, m)
			while #waiting > 4 do
				table.remove(waiting, 1)
			end
			drain()
		elseif m.op == "rank" and type(m.name) == "string" then
			Toast.show("You are now: " .. m.name, tostring(m.line or ""), 6)
			pcall(Herald.sound, true)
		elseif m.op == "prestige" and type(m.level) == "number" then
			local l = Prestige.get(m.level)
			if l then
				local gifts = if type(m.rewards) == "table" then m.rewards else l.rewards
				require(script.Parent.Celebrate).prestige(l.level, l.name, l.numeral, l.colour, gifts[#gifts])
			end
		elseif m.op == "flourish" and type(m.userId) == "number" then
			require(script.Parent.Parent.World.Laurels).flourish(m.userId, if type(m.level) == "number" then m.level else nil)
		elseif m.op == "streak" and type(m.count) == "number" then
			-- The day's first visit: how the streak stands, what it's worth, and what tomorrow adds.
			local count = math.floor(m.count)
			local gems = tonumber(m.gems) or 0
			local line
			if count <= 1 then
				line = if m.broke then "A new streak starts today. Come back tomorrow: every day in a row, your Gilt counts for more." else "Come back tomorrow to start a streak: every day in a row, your Gilt counts for more."
			else
				local boost, nextBoost = tonumber(m.boost) or 0, tonumber(m.next) or 0
				line = if nextBoost > boost
					then string.format("Your Gilt counts %d%% more today. Come back tomorrow for %d%%.", boost, nextBoost)
					else string.format("Your Gilt counts %d%% more today, the most there is. Come back tomorrow to keep it.", boost)
			end
			if gems > 0 then
				line = string.format("%d Gems from the house.  %s", gems, line)
			end
			-- (The next Gems, plainly: how many days away.)
			local giftAt, giftGems = tonumber(m.giftAt), tonumber(m.giftGems)
			if giftAt and giftGems and giftAt > count then
				local days = math.floor(giftAt - count)
				line ..= string.format("  %d more day%s for %d Gems.", days, if days == 1 then "" else "s", math.floor(giftGems))
			end
			Toast.show(if count <= 1 then "Welcome back" else string.format("🔥 %d days in a row", count), line, 6)
			if gems > 0 then
				pcall(Herald.sound, true)
			end
		end
	end)
end

-- For tests: how many feats are waiting, and whether one is up.
function Herald.state(): (number, boolean)
	return #waiting, showing
end

return Herald
