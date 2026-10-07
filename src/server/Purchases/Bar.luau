--!strict
-- The Terrace bar. A guest at the bar orders from the menu (BarMenu): the everyday menu for Gilt,
-- the house specials for Robux. The server checks everything (the item is on the menu, the guest
-- is at the bar, they have the Gilt; a special only ever comes from a receipt) and puts the treat
-- in their right hand, where everyone sees it. A sip or a bite every few seconds (each screen
-- moves the arm: client World/Treats), and when it's finished it's gone.
--
-- A special is first saved as a credit (Perks), in the same write as the receipt, and served at
-- once from it, so a receipt is never lost: if the guest left first, it's served when they're
-- back. The Grand Platter also hands a macaron to each guest near the buyer.
--
-- Gold Key holders have one everyday drink on the house each day (Config.Bar.goldKeyPour).
-- Nothing here changes a score or gives Gilt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BarMenu = require(ReplicatedStorage.Shared.BarMenu)
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)
local Gilt = require(script.Parent.Parent.Gilt)
local Profiles = require(script.Parent.Parent.Profiles)
local RemoteGuard = require(script.Parent.Parent.RemoteGuard)
local Shop = require(script.Parent.Parent.Shop)
local Catalog = require(script.Parent.Catalog)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)

local Bar = {}

-- The specials' product keys, and their credits ("treat:" .. key).
Bar.KEYS = {} :: { string }
for _, item in BarMenu.Items do
	if item.product then
		table.insert(Bar.KEYS, item.product)
	end
end
local IS_SPECIAL: { [string]: boolean } = {}
for _, key in Bar.KEYS do
	IS_SPECIAL[key] = true
end
local function creditOf(key: string): string
	return "treat:" .. key
end

type Holding = { item: BarMenu.Item, model: Model, left: number, next: number, sips: number, last: number }
local holding: { [Player]: Holding } = {}

local function settings(): { [string]: any }
	return Config.data.Bar
end

local function today(): number
	return os.time() // 86400
end

local function barData(data: Profiles.Data): { pourDay: number, served: number }
	local perks = data.perks :: any
	if type(perks.bar) ~= "table" then
		perks.bar = { pourDay = -1, served = 0 }
	end
	return perks.bar
end

-- Whether a Gold Key holder's drink on the house is still to be had today.
local function pourReady(data: Profiles.Data): boolean
	return settings().goldKeyPour == true and data.goldKey and barData(data).pourDay ~= today()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function atBar(player: Player): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - Layout.Terrace.bar).Magnitude <= settings().reach
end

-- Takes the treat out of a guest's hand.
function Bar.putDown(player: Player)
	local h = holding[player]
	holding[player] = nil
	if h and h.model.Parent then
		h.model:Destroy()
	end
end

-- What a guest holds now (its menu id), or nil.
function Bar.holding(player: Player): string?
	local h = holding[player]
	return if h then h.item.id else nil
end

-- Puts a treat in a guest's right hand. False if they've no character to hold it.
function Bar.serve(player: Player, item: BarMenu.Item): boolean
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not character or not hand or not hand:IsA("BasePart") then
		return false
	end
	Bar.putDown(player)
	local model = BarMenu.build(item)
	local handle = model.PrimaryPart :: BasePart
	-- Held just below the hand, a little in front (R15's hand, or R6's whole arm).
	local grip = if hand.Name == "RightHand" then CFrame.new(0, -0.25, -0.35) else CFrame.new(0, -1.15, -0.35)
	-- (Built around the origin: each part moves to the hand, then holds on to the handle.)
	local at = hand.CFrame * grip
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = at * d.CFrame
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = d
			w.Parent = d
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "TreatGrip"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = grip
	weld.Parent = handle
	model:SetAttribute("Sips", 0)
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Servings", item.servings)
	model:SetAttribute("Total", item.servings)
	model:SetAttribute("Kind", item.kind)
	model.Parent = character
	holding[player] = { item = item, model = model, left = item.servings, next = os.clock() + settings().sipSeconds, sips = 0, last = os.clock() }
	return true
end

-- Hands each guest near `from` (not holding anything) a macaron from their platter.
local function share(from: Player)
	local root = rootOf(from)
	if not root then
		return
	end
	local handed = 0
	for _, other in Players:GetPlayers() do
		if handed >= settings().shareMax then
			break
		end
		local r = rootOf(other)
		if other ~= from and r and not holding[other] and (r.Position - root.Position).Magnitude <= settings().shareRadius then
			if Bar.serve(other, BarMenu.Shared) then
				handed += 1
				Perks.tell(other, { op = "notice", title = "The Terrace", line = string.format("%s handed you a macaron from their Grand Platter.", from.DisplayName) })
			end
		end
	end
	if handed > 0 then
		Perks.tell(from, { op = "notice", title = "The Grand Platter", line = string.format("You handed a macaron to %d guest%s.", handed, if handed == 1 then "" else "s") })
	end
end

-- Serves a special from its credit, if there is one. True if one was served.
local function serveSpecial(player: Player, data: Profiles.Data, key: string): boolean
	local item = BarMenu.byProduct[key]
	if not item or Perks.credits(data, creditOf(key)) <= 0 or not player.Character then
		return false
	end
	if not Perks.use(player, data, creditOf(key), key) then
		return false
	end
	local served, ok = pcall(Bar.serve, player, item)
	if not served or not ok then
		-- No hand to hold it right now (or it couldn't be made): the credit goes back, to be served when they can.
		Perks.add(data, creditOf(key), 1)
		return false
	end
	barData(data).served += 1
	if item.share then
		share(player)
	end
	Perks.tell(player, { op = "notice", title = "The Terrace", line = item.name .. ", for you. Enjoy it." })
	return true
end

local function grant(ctx: Grants.Context)
	local key = ctx.key
	Perks.add(ctx.data, creditOf(key), 1)
	ctx:after(function()
		-- Served straight away, in place of anything they hold.
		if serveSpecial(ctx.player, ctx.data, key) then
			Perks.push(ctx.player)
		end
	end)
end

-- The menu for a guest's screen: every item, its price (Roblox's live price for the specials),
-- and whether it can be had now.
function Bar.menu(player: Player): { [string]: any }
	local data = Profiles.get(player)
	local items = {}
	for _, item in BarMenu.Items do
		local entry: { [string]: any } = { id = item.id, name = item.name, kind = item.kind, line = item.line, servings = item.servings, glow = item.glow == true, share = item.share == true }
		if item.gilt then
			entry.gilt = item.gilt
		elseif item.product then
			entry.key = item.product
			entry.robux = Catalog.price(item.product) or item.robux
			entry.ready = Catalog.enabled(item.product)
			entry.waiting = if data then Perks.credits(data, creditOf(item.product)) else 0
		end
		table.insert(items, entry)
	end
	return {
		ok = true,
		items = items,
		gilt = if data then data.gilt else 0,
		holding = Bar.holding(player),
		pour = data ~= nil and pourReady(data),
		goldKey = data ~= nil and data.goldKey,
	}
end

-- Orders an everyday item for Gilt (or the Gold Key's drink on the house).
function Bar.order(player: Player, data: Profiles.Data, id: string, pour: boolean): { [string]: any }
	local item = BarMenu.byId[id]
	if not item or not item.gilt then
		return { ok = false, why = "That isn't on the menu." }
	end
	if not atBar(player) then
		return { ok = false, why = "Order at the bar on the Terrace." }
	end
	if pour then
		if item.kind ~= "drink" or not pourReady(data) then
			return { ok = false, why = "Your drink on the house is for tomorrow now." }
		end
		if not Bar.serve(player, item) then
			return { ok = false, why = "Not just now." }
		end
		barData(data).pourDay = today()
		barData(data).served += 1
		return { ok = true, free = true }
	end
	local price = item.gilt :: number
	if data.gilt < price then
		return { ok = false, why = string.format("Not enough Gilt yet: %s more.", Gilt.format(price - data.gilt)) }
	end
	if not Bar.serve(player, item) then
		return { ok = false, why = "Not just now." }
	end
	data.gilt -= price
	barData(data).served += 1
	Analytics.sink(player, "Gilt", price, data.gilt, "bar_" .. item.id)
	return { ok = true, gilt = data.gilt }
end

local ORDER_KEYS = { op = true, id = true, pour = true, key = true }

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 4, 0)
	if not r then
		RemoteGuard.reject(player, "barAsk", "malformed")
		return { ok = false, why = "That isn't something the bar does." }
	end
	for k in r do
		if not ORDER_KEYS[k] then
			RemoteGuard.reject(player, "barAsk", "malformed")
			return { ok = false, why = "That isn't something the bar does." }
		end
	end
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	if r.op == "menu" then
		return Bar.menu(player)
	elseif r.op == "order" then
		local id = RemoteGuard.string(r.id, 40)
		if not id then
			return { ok = false, why = "That isn't on the menu." }
		end
		local result = Bar.order(player, data, id, r.pour == true)
		if result.ok then
			Shop.push(player) -- the purse on their screen
		end
		return result
	elseif r.op == "special" then
		local key = RemoteGuard.oneOf(r.key, IS_SPECIAL)
		if not key then
			return { ok = false, why = "That isn't on the menu." }
		end
		-- One already paid for and waiting: served now, nothing to buy.
		if Perks.credits(data, creditOf(key)) > 0 then
			return { ok = serveSpecial(player, data, key) }
		end
		if not atBar(player) then
			return { ok = false, why = "Order at the bar on the Terrace." }
		end
		local ok, why = Store.prompt(player, key, "bar")
		return { ok = ok, why = why, prompted = ok }
	elseif r.op == "putDown" then
		Bar.putDown(player)
		return { ok = true }
	elseif r.op == "bite" then
		local ok, left = Bar.bite(player)
		return { ok = ok, left = left }
	end
	return { ok = false, why = "That isn't something the bar does." }
end

-- One bite (or sip): a serving gone, and every screen sees the arm come up (the "Sips" counter).
local function bite(player: Player, h: Holding)
	local now = os.clock()
	h.left -= 1
	h.last = now
	h.next = now + settings().sipSeconds
	h.sips += 1
	h.model:SetAttribute("Sips", h.sips)
	h.model:SetAttribute("Servings", h.left)
	if h.left <= 0 then
		holding[player] = nil
		local model = h.model
		task.delay(1.4, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end
end

-- A guest eats (or drinks) when they click: the server only checks they hold something and
-- aren't faster than a person can chew (Config.Bar.biteGap).
function Bar.bite(player: Player): (boolean, number?)
	local h = holding[player]
	if not h or not h.model.Parent then
		return false, nil
	end
	if os.clock() - h.last < settings().biteGap then
		return false, h.left
	end
	bite(player, h)
	return true, h.left
end

local function tick()
	local now = os.clock()
	local auto = settings().sipSeconds
	for player, h in holding do
		if not h.model.Parent or not player.Parent then
			holding[player] = nil
		elseif auto > 0 and now >= h.next then
			bite(player, h)
		elseif now - h.last > settings().idleSeconds then
			-- Set down after a long while untouched.
			Bar.putDown(player)
		end
	end
end

function Bar.start()
	Grants.register("barTreat", grant)
	for _, key in Bar.KEYS do
		-- On arriving (or a new character): one waiting is served, if their hands are free.
		Perks.autoUse[creditOf(key)] = function(player: Player, data: Profiles.Data): boolean
			return holding[player] == nil and serveSpecial(player, data, key)
		end
		Store.eligibility[key] = function(_player: Player, data: Profiles.Data): (boolean, string?)
			local entry = ProductConfig.byKey[key]
			if Perks.credits(data, creditOf(key)) >= (entry.Rules.MaxHeld or 5) then
				return false, "You've a few of those waiting already: ask the bar for one."
			end
			return true, nil
		end
	end
	RemoteGuard.invoke(Remotes.func("BarAsk"), "barAsk", onAsk)
	Players.PlayerRemoving:Connect(function(player: Player)
		holding[player] = nil
	end)
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			holding[player] = nil
		end)
		-- A special paid for while their character was away is served when it's back.
		player.CharacterAdded:Connect(function()
			task.delay(2, function()
				for _, key in Bar.KEYS do
					Perks.tryAuto(player, creditOf(key))
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.Heartbeat:Connect(tick)
end

return Bar
