--!strict
-- The Vault's and the Suite's displays: what a guest shows of what they own, and to whom.
--   The Vault       eight featured curios under glass domes in the Vault (any eight you hold); your
--                   collection's completion (by family and by rarity), every curio's description,
--                   how it's had and when you first had it; the last forty you came by; how your
--                   collection is arranged; and who may look at your Vault (everyone, friends, or
--                   only you)
--   The Suite       its look (a theme for its walls, trim and floors: the house's own free, others
--                   for a price shown first, or with the Island Key or a Prestige laurel), who may
--                   visit (friends, only friends you invite, or nobody), and the photograph
-- Pure rules, shared by the server (which decides everything) and the screens.

local Showcase = {}

local rgb = Color3.fromRGB

Showcase.FEATURED = 8 -- curios under the Vault's domes (Build 82: two rows of four, from one)
Showcase.HISTORY = 40 -- acquisitions kept

export type Choice = { id: string, name: string, line: string }

Showcase.Arrangements = {
	{ id = "rarity", name = "By rarity", line = "The rarest first." },
	{ id = "family", name = "By family", line = "Each family together." },
	{ id = "newest", name = "Newest first", line = "What you came by last, first." },
	{ id = "starred", name = "Starred first", line = "The curios you've starred, first." },
} :: { Choice }

Showcase.VaultPrivacy = {
	{ id = "everyone", name = "Everyone", line = "Any guest in the house may look round your Vault." },
	{ id = "friends", name = "Friends", line = "Only your friends on Roblox." },
	{ id = "me", name = "Only me", line = "Nobody but you." },
} :: { Choice }

Showcase.SuitePrivacy = {
	{ id = "friends", name = "Friends", line = "Any friend on Roblox may walk into your Suite." },
	{ id = "invited", name = "Invited friends", line = "Only friends you invite, this visit." },
	{ id = "nobody", name = "Nobody", line = "Your Suite is yours alone." },
} :: { Choice }

local function index(list: { Choice }): { [string]: Choice }
	local out = {}
	for _, c in list do
		out[c.id] = c
	end
	return out
end
Showcase.arrangementById = index(Showcase.Arrangements)
Showcase.vaultPrivacyById = index(Showcase.VaultPrivacy)
Showcase.suitePrivacyById = index(Showcase.SuitePrivacy)

-- The Suite's themes: walls, trim and floors. `gilt`/`gems`: a price (permanent, shown first);
-- `islandKey`: comes with the Island Key; `prestige`: with that Maison Prestige laurel.
export type Theme = {
	id: string,
	name: string,
	line: string,
	walls: Color3,
	trim: Color3,
	floor: Color3,
	gilt: number?,
	gems: number?,
	islandKey: boolean?,
	prestige: number?,
}
Showcase.Themes = {
	{ id = "noir", name = "Maison Noir", line = "Black lacquer and antique gold: the house's own.", walls = rgb(22, 22, 26), trim = rgb(160, 122, 58), floor = rgb(18, 18, 21) },
	{ id = "ivory", name = "Ivory Salon", line = "Cream walls, pale gold, bright mornings.", walls = rgb(226, 216, 196), trim = rgb(196, 160, 90), floor = rgb(196, 182, 156), gilt = 15000 },
	{ id = "emerald", name = "Emerald Study", line = "Deep green, brass, the smell of old books.", walls = rgb(20, 48, 36), trim = rgb(176, 136, 64), floor = rgb(42, 28, 20), gilt = 20000 },
	{ id = "rose", name = "Rosé", line = "Dusky pink and rose gold.", walls = rgb(122, 72, 78), trim = rgb(222, 172, 150), floor = rgb(62, 36, 40), gems = 120 },
	{ id = "midnight", name = "Midnight Blue", line = "Ink-blue walls under silver.", walls = rgb(16, 22, 46), trim = rgb(190, 196, 210), floor = rgb(12, 14, 26), gems = 150 },
	{ id = "island", name = "Island White", line = "Sun-bleached white and sea glass, from Luxury Island.", walls = rgb(236, 236, 230), trim = rgb(90, 190, 200), floor = rgb(214, 200, 176), islandKey = true },
	{ id = "laurel", name = "The Laurel Rooms", line = "Gilded panels, for the house's Prestige.", walls = rgb(52, 40, 24), trim = rgb(240, 200, 110), floor = rgb(30, 22, 14), prestige = 4 },
} :: { Theme }
Showcase.themeById = {} :: { [string]: Theme }
for _, t in Showcase.Themes do
	Showcase.themeById[t.id] = t
end

-- What a theme costs or needs, in a few words.
function Showcase.themePrice(t: Theme): string
	if t.gilt then
		return Showcase.commas(t.gilt) .. " Gilt"
	elseif t.gems then
		return Showcase.commas(t.gems) .. " Gems"
	elseif t.islandKey then
		return "With the Island Key"
	elseif t.prestige then
		return "With Maison Prestige " .. t.prestige
	end
	return "The house's own"
end

function Showcase.commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

return Showcase
