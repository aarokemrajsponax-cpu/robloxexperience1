--!strict
-- The catalog at run time: which id each product has in this experience, which product a
-- receipt's ProductId is, and what Roblox says it costs now.
--
-- An id comes from (first that's set): Config.Products[key] (can be changed live), the entry's
-- own Id, or, for developer products, the product found in the experience with the entry's Name.
-- Two products resolving to one id is a setup mistake: that id is treated as unknown (its
-- receipts wait, and the owner is told) rather than guessed.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)

local Catalog = {}

local discovered: { [string]: number } = {} -- key -> developer product id, found by name
local discoveredPrice: { [number]: number } = {}
local disabled: { [string]: string } = {} -- key -> why it's switched off
local prices: { [string]: { price: number?, at: number } } = {}
local reverse: { [number]: string | false } = {} -- developer product id -> key (false: ambiguous)
local conflicts: { [string]: boolean } = {} -- reported already

-- Told about setup problems (the owner sees warnings on their screen).
Catalog.report = function(text: string)
	warn("[Maison] " .. text)
end

function Catalog.entry(key: string): ProductConfig.Entry?
	return ProductConfig.byKey[key]
end

-- The id a key has in this experience, or 0.
function Catalog.idOf(key: string): number
	local e = ProductConfig.byKey[key]
	if not e then
		return 0
	end
	local override = (Config.data.Products :: any)[key]
	if type(override) == "number" and override ~= 0 then
		return override
	end
	if e.Id ~= 0 then
		return e.Id
	end
	if e.ProductType == "DeveloperProduct" then
		return discovered[key] or 0
	end
	return 0
end

local function rebuild()
	reverse = {}
	for _, e in ProductConfig.List do
		if e.ProductType == "DeveloperProduct" then
			local id = Catalog.idOf(e.Key)
			if id ~= 0 then
				local seen = reverse[id]
				if seen == nil then
					reverse[id] = e.Key
				elseif seen ~= false and seen ~= e.Key then
					reverse[id] = false
					local note = string.format("%d:%s:%s", id, tostring(seen), e.Key)
					if not conflicts[note] then
						conflicts[note] = true
						Catalog.report(string.format("Two products share the id %d (%s and %s): neither is sold until that's fixed.", id, tostring(seen), e.Key))
					end
				end
			end
		end
	end
end

-- The catalog key for a receipt's developer product id, or nil (unknown, or ambiguous). The map
-- is rebuilt every time: ids set live (Config.Products) can change at any moment, and a receipt
-- must never be matched against a stale one. (A few dozen entries: cheap.)
function Catalog.keyForProduct(productId: number): string?
	rebuild()
	local key = reverse[productId]
	return if type(key) == "string" then key else nil
end

-- On sale: a valid entry with an id.
function Catalog.enabled(key: string): boolean
	return ProductConfig.byKey[key] ~= nil and disabled[key] == nil and Catalog.idOf(key) ~= 0
end

function Catalog.disabledWhy(key: string): string?
	return disabled[key]
end

-- Roblox's current price for a key (cached), or nil if it isn't on sale.
function Catalog.price(key: string): number?
	local e = ProductConfig.byKey[key]
	local id = Catalog.idOf(key)
	if not e or id == 0 then
		return nil
	end
	local cached = prices[key]
	if cached and os.clock() - cached.at < ProductConfig.Settings.PriceCacheSeconds then
		return cached.price
	end
	if e.ProductType == "DeveloperProduct" and discoveredPrice[id] then
		return discoveredPrice[id]
	end
	local infoType = if e.ProductType == "GamePass" then Enum.InfoType.GamePass else Enum.InfoType.Product
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(id, infoType)
	end)
	if not ok then
		-- (Older engines only have the deprecated name.)
		ok, info = pcall(function()
			return (MarketplaceService :: any):GetProductInfo(id, infoType)
		end)
	end
	local price = if ok and type(info) == "table" and type((info :: any).PriceInRobux) == "number" then (info :: any).PriceInRobux else nil
	prices[key] = { price = price, at = os.clock() }
	return price
end

-- Reads the experience's developer products and matches them to the catalog by Name.
function Catalog.discover()
	local byName: { [string]: string } = {}
	for _, e in ProductConfig.List do
		if e.ProductType == "DeveloperProduct" then
			byName[ProductConfig.normalName(e.Name)] = e.Key
			-- A product renamed in the game (the Gold Leaf salute is Gold Confetti now) is still
			-- found under the name it was made with.
			for _, alias in (e.Aliases or {}) :: { string } do
				local n = ProductConfig.normalName(alias)
				if not byName[n] then
					byName[n] = e.Key
				end
			end
		end
	end
	local ok, pages = pcall(function()
		return MarketplaceService:GetDeveloperProductsAsync()
	end)
	if not ok or not pages then
		return
	end
	local found: { [string]: number } = {}
	for _ = 1, 20 do
		local page = (pages :: any):GetCurrentPage()
		for _, product in page do
			local name = product.Name or product.name
			local id = product.ProductId or product.productId or product.DeveloperProductId
			if type(name) == "string" and type(id) == "number" then
				local key = byName[ProductConfig.normalName(name)]
				if key then
					found[key] = id
					local price = product.PriceInRobux or product.priceInRobux
					if type(price) == "number" then
						discoveredPrice[id] = price
					end
				end
			end
		end
		if (pages :: any).IsFinished then
			break
		end
		local more = pcall(function()
			(pages :: any):AdvanceToNextPageAsync()
		end)
		if not more then
			break
		end
	end
	discovered = found
	rebuild()
end

-- Validates every entry (handlers: the server's grant handlers). Broken entries are switched off
-- and reported. Returns the problems.
function Catalog.validate(handlers: { [string]: boolean }): { [string]: string }
	local problems = ProductConfig.validate(handlers)
	disabled = {}
	for key, why in problems do
		if key ~= "" then
			disabled[key] = why
		end
		Catalog.report(string.format("Product '%s' is switched off: %s.", if key == "" then "?" else key, why))
	end
	return problems
end

-- Every key with its id and state (for the owner's tools and tests).
function Catalog.status(): { { key: string, id: number, enabled: boolean, why: string? } }
	local out = {}
	for _, e in ProductConfig.List do
		table.insert(out, { key = e.Key, id = Catalog.idOf(e.Key), enabled = Catalog.enabled(e.Key), why = disabled[e.Key] })
	end
	return out
end

return Catalog
