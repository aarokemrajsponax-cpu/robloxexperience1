--!strict
-- Salutes (§12, the house's own addition): a moment bought for the whole house. Everyone in the
-- server sees it and hears who gave it; the giver's name goes on the Tonight board. Purely a
-- spectacle: no Gilt, no score, no advantage to anyone. Prices are Roblox's own, read live; the
-- `robux` here is only the suggested price to set on each developer product.

local Salutes = {}

export type Salute = { id: string, name: string, product: string, aliases: { string }?, line: string, seconds: number, announce: string, robux: number, global: boolean, scale: number? }

-- `product`: the developer product's name in the Creator Dashboard is "Salute: " .. product.
-- `aliases`: older names a product may still have there (each found as well).
-- `scale`: how big its fireworks are (World/Fireworks).
Salutes.List = {
	{ id = "goldLeaf", name = "A Shower of Gold Confetti", product = "Gold Confetti", aliases = { "Gold Leaf" }, line = "Gold confetti bursts over every guest in the house and flutters down, glinting as it turns.", seconds = 18, announce = "{name} showered the house in gold confetti.", robux = 75, global = false },
	{ id = "encore", name = "An Encore", product = "Encore", line = "The Pianist plays an encore, a followspot finds you wherever you are, rose petals fall round you and the house applauds.", seconds = 25, announce = "{name} asked the Pianist for an encore.", robux = 125, global = false },
	{ id = "chandelier", name = "The Chandelier Blaze", product = "Chandelier", line = "Every lamp in the house flares in a wave out from you, each chandelier throwing off glints of crystal.", seconds = 20, announce = "{name} set the chandeliers blazing.", robux = 175, global = false },
	{ id = "fireworks", name = "Fireworks over the House", product = "Fireworks", line = "A pyromusical over the whole estate: Japanese chrysanthemums to taiko drums, then a golden finale to Handel, seen from every window.", seconds = 45, announce = "{name} lit fireworks over the house.", robux = 299, global = false, scale = 1 },
	{ id = "grand", name = "The Grand Salute", product = "Grand Salute", line = "All of it at once (gold confetti, the encore, the chandeliers, a bigger show) and your name announced in every house on Roblox.", seconds = 60, announce = "{name} gave the house the Grand Salute.", robux = 599, global = true, scale = 1.3 },
	{ id = "finale", name = "The Midnight Finale", product = "Midnight Finale", line = "Ten golden numbers and a bell for each on every screen, midnight chimes, then the biggest show the house can fire: ninety seconds in three acts, Niagara Falls down the front of the house, gold confetti and blazing chandeliers, your name in every house.", seconds = 100, announce = "{name} lit the Midnight Finale.", robux = 999, global = true, scale = 1.6 },
} :: { Salute }

Salutes.byId = {} :: { [string]: Salute }
for _, s in Salutes.List do
	Salutes.byId[s.id] = s
end

-- The effects a salute plays: the Grand Salute plays all four; the Finale counts down first.
function Salutes.effects(id: string): { string }
	if id == "grand" then
		return { "goldLeaf", "encore", "chandelier", "fireworks" }
	elseif id == "finale" then
		return { "countdown", "goldLeaf", "chandelier", "fireworks" }
	end
	return { id }
end

-- Seconds of countdown before a salute's show (the Finale's ten).
Salutes.COUNTDOWN = 10

function Salutes.line(id: string, name: string): string
	local s = Salutes.byId[id]
	return if s then (string.gsub(s.announce, "{name}", name)) else ""
end

return Salutes
