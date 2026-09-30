--!strict
-- Salutes (§12, the house's own addition): a moment bought for the whole house. Everyone in the
-- server sees it and hears who gave it; the giver's name goes on the Tonight board. Purely a
-- spectacle: no Gilt, no score, no advantage to anyone. Prices are Roblox's own, read live; the
-- `robux` here is only the suggested price to set on each developer product.

local Salutes = {}

export type Salute = { id: string, name: string, line: string, seconds: number, announce: string, robux: number, global: boolean }

Salutes.List = {
	{ id = "goldLeaf", name = "A Shower of Gold Leaf", line = "Gold leaf drifts down over every guest in the house.", seconds = 18, announce = "{name} showered the house in gold leaf.", robux = 49, global = false },
	{ id = "encore", name = "An Encore", line = "The Pianist plays an encore, and a spotlight finds you wherever you are.", seconds = 25, announce = "{name} asked the Pianist for an encore.", robux = 79, global = false },
	{ id = "chandelier", name = "The Chandelier Blaze", line = "Every candle in the house flares bright at once.", seconds = 20, announce = "{name} set the chandeliers blazing.", robux = 99, global = false },
	{ id = "fireworks", name = "Fireworks over the House", line = "Gold fireworks over the roofs, seen from every window and the Terrace.", seconds = 25, announce = "{name} lit fireworks over the house.", robux = 149, global = false },
	{ id = "grand", name = "The Grand Salute", line = "All of it at once, and your name announced in every house on Roblox.", seconds = 35, announce = "{name} gave the house the Grand Salute.", robux = 399, global = true },
} :: { Salute }

Salutes.byId = {} :: { [string]: Salute }
for _, s in Salutes.List do
	Salutes.byId[s.id] = s
end

-- The effects a salute plays: the Grand Salute plays all four.
function Salutes.effects(id: string): { string }
	if id == "grand" then
		return { "goldLeaf", "encore", "chandelier", "fireworks" }
	end
	return { id }
end

function Salutes.line(id: string, name: string): string
	local s = Salutes.byId[id]
	return if s then (string.gsub(s.announce, "{name}", name)) else ""
end

return Salutes
