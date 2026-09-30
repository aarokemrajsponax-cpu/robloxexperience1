--!strict
-- The Black Card (§12): a monthly Roblox subscription, offered as a card on the Concierge's
-- lectern, never a pop-up. While it's held: the Leather-Bound Ledger (LedgerService reads
-- `data.blackCard.active`), and a black-lacquer nameplate. Each month held: that month's
-- cardholder look, kept for good. Roblox is asked whether the card is held on every visit and
-- whenever Roblox says the subscription changed. With no id in Config.Products.blackCard, the card
-- isn't offered and nothing here runs.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Analytics = require(script.Parent.Analytics)
local Profiles = require(script.Parent.Profiles)

local BlackCard = {}

-- Tells the rest of the house (set by the Shop): the nameplate, the Ledger, the guest's screen.
BlackCard.changed = function(_player: Player, _notice: string?) end

function BlackCard.id(): string
	local id = Config.data.Products.blackCard
	return if type(id) == "string" then id else ""
end

function BlackCard.offered(): boolean
	return BlackCard.id() ~= ""
end

-- Grants this month's cardholder look to a guest who holds the card. Returns the look, if new.
function BlackCard.claimMonth(data: Profiles.Data, time: number?): Wardrobe.Item?
	if not data.blackCard.active then
		return nil
	end
	local month = Wardrobe.cardMonth(time)
	if data.blackCard.months[month] then
		return nil
	end
	data.blackCard.months[month] = true
	local look = Wardrobe.cardholderLook(time)
	if look then
		data.owned[look.id] = true
	end
	return look
end

-- Sets whether the card is held (after asking Roblox), and grants the month's look.
function BlackCard.set(player: Player, data: Profiles.Data, held: boolean)
	local was = data.blackCard.active
	data.blackCard.active = held
	local look = BlackCard.claimMonth(data)
	if held and not was then
		Analytics.custom(player, "Black Card held", nil, nil)
	end
	local notice = if look then "This month's cardholder look is in your Wardrobe: " .. look.name .. "." else nil
	if held ~= was or look then
		BlackCard.changed(player, notice)
	end
end

function BlackCard.check(player: Player)
	local id = BlackCard.id()
	local data = Profiles.get(player)
	if id == "" or not data then
		return
	end
	local ok, status = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, id)
	end)
	-- If Roblox can't be reached, the last answer stands.
	if ok and type(status) == "table" then
		BlackCard.set(player, data, (status :: any).IsSubscribed == true)
	end
end

-- The price as Roblox shows it in the guest's own currency, or nil.
local priceCache: { at: number, text: string? } = { at = -math.huge, text = nil }
function BlackCard.price(): string?
	local id = BlackCard.id()
	if id == "" then
		return nil
	end
	if os.clock() - priceCache.at < 600 then
		return priceCache.text
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetSubscriptionProductInfoAsync(id)
	end)
	priceCache = { at = os.clock(), text = if ok and type(info) == "table" and type((info :: any).DisplayPrice) == "string" then (info :: any).DisplayPrice else nil }
	return priceCache.text
end

function BlackCard.offer(player: Player): boolean
	local id = BlackCard.id()
	if id == "" then
		return false
	end
	local ok = pcall(function()
		MarketplaceService:PromptSubscriptionPurchase(player, id)
	end)
	return ok
end

-- A guest's first minutes in the house are quiet: the card on the lectern stays hidden.
function BlackCard.quiet(player: Player, data: Profiles.Data)
	local seconds = Config.data.BlackCard.quietMinutes * 60
	local since = os.time() - data.firstVisit
	if data.firstVisit > 0 and since < seconds then
		player:SetAttribute("Quiet", true)
		task.delay(seconds - since, function()
			if player.Parent then
				player:SetAttribute("Quiet", nil)
			end
		end)
	end
end

function BlackCard.start()
	Workspace:SetAttribute("BlackCardOffered", BlackCard.offered())
	Profiles.Loaded:Connect(function(player: Player, data: Profiles.Data)
		BlackCard.quiet(player, data)
		task.spawn(BlackCard.check, player)
	end)
	pcall(function()
		(Players :: any).UserSubscriptionStatusChanged:Connect(function(player: Player, subscriptionId: string)
			if subscriptionId == BlackCard.id() then
				BlackCard.check(player)
			end
		end)
	end)
	-- A month can turn during a long visit.
	task.spawn(function()
		while true do
			task.wait(3600)
			for _, player in Players:GetPlayers() do
				local data = Profiles.get(player)
				if data and BlackCard.claimMonth(data) then
					BlackCard.changed(player, "This month's cardholder look is in your Wardrobe.")
				end
			end
		end
	end)
end

return BlackCard
