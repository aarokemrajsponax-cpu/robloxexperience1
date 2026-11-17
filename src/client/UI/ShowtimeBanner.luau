--!strict
-- (Build 93) Showtime's call (shared/Showtime, server/Showtime): when Showtime opens, a card at the
-- top of every screen names the game it's called, where it's played, what a round of it pays, and
-- how long is left (by the server's clock, so it's the same on every screen), with a key that takes
-- the guest straight there. Shown once each Showtime; "Not now" or a minute puts it away. A guest
-- who's already at the game is told so instead of being sent anywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Plan = require(ReplicatedStorage.Shared.Showtime)
local HudCard = require(script.Parent.HudCard)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local ShowtimeBanner = {}

local C = Brand.Colours
local NAME = "ShowtimeBanner"
local WIDTH = 440
local SHOW_FOR = 60 -- seconds before it puts itself away
-- The keys along the top (Play, Shop, How to play...) reach this far down (UI units: placed at 10,
-- 44 tall): the card comes in below them, never over them.
local KEYS_BOTTOM = 10 + 44

-- Set by Main: takes the guest to the Grand Ballroom (and in); whether they're inside it now.
ShowtimeBanner.take = function() end
ShowtimeBanner.inBallroom = function(): boolean
	return false
end

local shownSlot: number? = nil
local card: Frame? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function gilt(): number
	local c = (Config.data :: any).Showtime
	return if type(c) == "table" then math.floor(tonumber(c.gilt) or 0) else 0
end

function ShowtimeBanner.hide()
	local f = card
	card = nil
	if f then
		f:Destroy()
	end
end

-- Shows the call for Showtime `slot` (once each).
function ShowtimeBanner.show(slot: number)
	if shownSlot == slot then
		return
	end
	shownSlot = slot
	ShowtimeBanner.hide()
	local g = Plan.gameOf(slot)
	local f = Instance.new("Frame")
	f.Name = NAME
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.new(0.5, 0, 0, math.max(Root.topClear(), KEYS_BOTTOM) + 12)
	f.Size = UDim2.fromOffset(math.min(WIDTH, Root.size().X - 24), 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Parent = Root.toasts
	HudCard.style(f, C.gold)
	-- (Its words on a sheet of their own, so the card's accent bar stays down its left edge.)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Size = UDim2.new(1, 0, 0, 0)
	body.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = body
	local list = Theme.list(body, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	local clock = Theme.text(body, "Showtime", 13, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.lightGold })
	Theme.text(body, g.glyph .. "  " .. g.name, 22, "display", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left })
	local inside = ShowtimeBanner.inBallroom()
	local pays = gilt()
	local line = string.format("In the Grand Ballroom, at %s. %s", g.where, g.line)
	if pays > 0 then
		line ..= string.format(" Play a round while it's on: +%d Gilt, once.", pays)
	end
	Theme.text(body, line, 13, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.smoke, TextWrapped = true })
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.LayoutOrder = 4
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.Parent = body
	Theme.list(keys, 8, true)
	if inside then
		Theme.text(keys, "You're in the Grand Ballroom: head for " .. g.where .. ".", 13, "bodyMedium", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.bone, Size = UDim2.new(1, -150, 0, 0) })
	else
		Theme.key(keys, "Take me there", true, function()
			ShowtimeBanner.hide()
			ShowtimeBanner.take()
		end, 190).LayoutOrder = 1
	end
	Theme.key(keys, "Not now", false, function()
		ShowtimeBanner.hide()
	end, 130).LayoutOrder = 2
	card = f
	local opened = os.clock()
	task.spawn(function()
		while card == f and f.Parent do
			local left = Plan.closesAt(slot) - now()
			if left <= 0 or os.clock() - opened > SHOW_FOR then
				if card == f then
					ShowtimeBanner.hide()
				end
				return
			end
			clock.Text = "SHOWTIME  ·  CLOSES IN " .. Plan.clock(left)
			task.wait(1)
		end
	end)
end

local function check()
	if Workspace:GetAttribute("ShowtimeOpen") == true then
		local slot = Workspace:GetAttribute("ShowtimeSlot")
		if type(slot) == "number" then
			ShowtimeBanner.show(slot)
		end
	elseif card then
		ShowtimeBanner.hide()
	end
end

function ShowtimeBanner.start()
	Workspace:GetAttributeChangedSignal("ShowtimeOpen"):Connect(check)
	Workspace:GetAttributeChangedSignal("ShowtimeSlot"):Connect(check)
	check()
end

return ShowtimeBanner
