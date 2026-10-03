--!strict
-- The offer after a run: once a session, after a couple of banked runs, a small card says what
-- Double Gilt would have paid for the run just played, with a key to buy it. Honest numbers,
-- easy to wave away, never shown again in the same session once dismissed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Closet = require(script.Parent.Parent.Closet)

local OfferCard = {}

local NAME = "OfferCard"
local ROBUX = utf8.char(0xE002)
local runs = 0
local shown = false

function OfferCard.afterRun(gilt: number)
	runs += 1
	if shown or runs < Config.data.Offers.upsellAfterRuns or gilt <= 0 then
		return
	end
	task.spawn(function()
		local view = Closet.ask({ op = "offers" })
		if type(view) ~= "table" or view.doubleGilt or type(view.offers) ~= "table" then
			return
		end
		local offer = nil
		for _, o in view.offers do
			if o.key == "doubleGilt" then
				offer = o
			end
		end
		if not offer or shown then
			return
		end
		shown = true
		task.wait(2.5)
		local size = Root.size()
		local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(math.min(420, size.X - 24), 210), UDim2.new(0.5, 0, 1, -24), Vector2.new(0.5, 1))
		Theme.list(content, 6).VerticalAlignment = Enum.VerticalAlignment.Top
		Theme.text(content, "Double Gilt", 24, "display", { LayoutOrder = 1 })
		local more = math.floor(gilt * (ProductConfig.byKey.doubleGilt.Reward.Multiplier - 1))
		Theme.text(content, string.format("That run paid %d Gilt. With Double Gilt it would have paid %d, and every run from now on pays double, for good.", gilt, gilt + more), 14, "body", { LayoutOrder = 2, TextWrapped = true, TextColor3 = Brand.Colours.bone })
		local keys = Instance.new("Frame")
		keys.BackgroundTransparency = 1
		keys.AutomaticSize = Enum.AutomaticSize.Y
		keys.Size = UDim2.new(1, 0, 0, 0)
		keys.LayoutOrder = 3
		keys.Parent = content
		Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
		Theme.key(keys, if type(offer.price) == "number" then "Get it · " .. ROBUX .. " " .. tostring(offer.price) else "Get it", true, function()
			Root.close(NAME)
			task.spawn(function()
				local r = Closet.ask({ op = "offer", key = "doubleGilt" })
				if type(r) == "table" and r.ok == false then
					Toast.show("Double Gilt", tostring(r.why), 3)
				end
			end)
		end, 190)
		Theme.key(keys, "Not now", false, function()
			Root.close(NAME)
		end, 150)
		Root.open(NAME, group, nil, false)
	end)
end

return OfferCard
