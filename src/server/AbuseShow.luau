--!strict
-- Admin Abuse as a show, on the server:
--   the owner     AJKR's own avatar, built here (only a server can) and kept in ReplicatedStorage
--                 for the few nights made for it (AJKR's giant over the house, AJKR's army). It's
--                 never a stored picture: it's built again from AJKR's look as it is now: from what
--                 they're wearing in this server if they're here, else from their Roblox avatar
--                 (fetched again at the start of every night, and every few minutes), so a change of
--                 outfit shows up by itself.
--   the realms    each night has its realm (shared/AbuseNights); Mega Abuse moves from the night's
--                 realm to the next, and the next, each for a while, at the same moments in every
--                 server. The server only says which (Workspace's AbuseRealm, AbuseRealmAt); every
--                 screen draws it.
--   the gifts     every so often, a gift from the owner on every guest's screen, theirs to open
--                 while it lasts. Opening it is checked here (their own gift, still open, Admin Abuse
--                 still on) and pays Gilt; the third opened in one night gives the Admin's Crown
--                 (once ever), or more Gilt to a guest who has it. Nothing random, nothing paid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AbuseNights = require(ReplicatedStorage.Shared.AbuseNights)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Curios = require(script.Parent.Curios)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local AbuseShow = {}

AbuseShow.AVATAR = "MaisonOwnerAvatar"
AbuseShow.CROWN = "adminCrown"

local function cfg(): { [string]: any }
	return (Config.data.Admin :: any).show
end

-- Admin Abuse's night: when it began (Workspace's AbuseSince), while it's on.
local function night(): number?
	local ends = Workspace:GetAttribute("AbuseUntil")
	local since = Workspace:GetAttribute("AbuseSince")
	if type(ends) == "number" and ends > os.time() and type(since) == "number" then
		return since
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- The owner's avatar
---------------------------------------------------------------------------------------------------
-- Where the avatar is kept for every screen to copy. (Set for tests.)
AbuseShow.home = function(): Instance
	return ReplicatedStorage
end

-- AJKR's look as it is now: what they're wearing here if they're in this server, else their
-- Roblox avatar. (Set for tests.)
AbuseShow.describeOwner = function(userId: number): HumanoidDescription
	local here = Players:GetPlayerByUserId(userId)
	local character = here and here.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local ok, worn = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		if ok and worn then
			return worn
		end
	end
	return Players:GetHumanoidDescriptionFromUserId(userId)
end

-- (Set for tests: the avatar built from a look.)
AbuseShow.makeAvatar = function(userId: number): Model?
	return Players:CreateHumanoidModelFromDescription(AbuseShow.describeOwner(userId), Enum.HumanoidRigType.R15)
end

local building = false
local builtAt = -math.huge
-- Builds AJKR's avatar for every screen from their look now. `fresh`: again even if one is there
-- (replacing it once the new one is ready; not more than once a minute). False if Roblox couldn't
-- give it just now (tried again later).
function AbuseShow.buildAvatar(fresh: boolean?): boolean
	local home = AbuseShow.home()
	local old = home:FindFirstChild(AbuseShow.AVATAR)
	if old and not (fresh and os.clock() - builtAt >= 60) then
		return true
	end
	if building then
		return false
	end
	building = true
	local ok, model = pcall(AbuseShow.makeAvatar, Config.data.Admin.ownerUserId)
	building = false
	if not ok or typeof(model) ~= "Instance" or not (model :: Instance):IsA("Model") then
		return old ~= nil
	end
	builtAt = os.clock()
	local m = model :: Model
	-- Only its look: no scripts, no sounds; nothing to bump into.
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Anchored = false
		end
	end
	local root = m:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
		m.PrimaryPart = root
	end
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		if not humanoid:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = humanoid
		end
	end
	m.Name = AbuseShow.AVATAR
	m:SetAttribute("UserId", Config.data.Admin.ownerUserId)
	m:SetAttribute("BuiltAt", os.time())
	-- (The new one in, then the old one out: a screen copying it always finds one.)
	m.Parent = home
	if old and old ~= m then
		old:Destroy()
	end
	return true
end

---------------------------------------------------------------------------------------------------
-- The realms
---------------------------------------------------------------------------------------------------
local function setRealm(id: string?)
	Workspace:SetAttribute("AbuseRealm", id)
	Workspace:SetAttribute("AbuseRealmAt", if id then os.time() else nil)
end
AbuseShow.setRealm = setRealm

---------------------------------------------------------------------------------------------------
-- The gifts
---------------------------------------------------------------------------------------------------
type Gift = { id: number, expires: number, gilt: number, crown: boolean, night: number }
local open: { [Player]: Gift } = {}
local opened: { [Player]: { night: number, count: number } } = {}
local nextId = 0

local function hasCrown(player: Player): boolean
	local data = Profiles.get(player)
	return data ~= nil and Curios.count(data, AbuseShow.CROWN) > 0
end

local function countFor(player: Player, n: number): number
	local o = opened[player]
	return if o and o.night == n then o.count else 0
end

-- A gift on this guest's screen (the one before it, unopened, goes).
function AbuseShow.offer(player: Player): Gift?
	local n = night()
	if not n then
		return nil
	end
	nextId += 1
	local count = countFor(player, n)
	local crown = count + 1 == cfg().crownAfter
	local gift: Gift = { id = nextId, expires = os.time() + cfg().giftWindow, gilt = cfg().giftGilt, crown = crown, night = n }
	open[player] = gift
	Remotes.event("Salute"):FireClient(player, {
		op = "abuseGift",
		id = gift.id,
		gilt = gift.gilt,
		crown = crown and not hasCrown(player),
		bonus = if crown and hasCrown(player) then cfg().crownBonus else nil,
		number = count + 1,
		seconds = cfg().giftWindow,
	})
	return gift
end

-- Opening a gift: theirs, still open, Admin Abuse still on.
function AbuseShow.open(player: Player, request: unknown): { [string]: any }
	local r = RemoteGuard.message(request, 2, 0)
	local id = if r then RemoteGuard.number(r.id, 1, 1e9, true) else nil
	if not r or r.op ~= "open" or not id then
		RemoteGuard.reject(player, "abuseGift", "malformed")
		return { ok = false }
	end
	local gift = open[player]
	if not gift or gift.id ~= id then
		return { ok = false, why = "That gift has gone." }
	end
	if os.time() > gift.expires or night() ~= gift.night then
		open[player] = nil
		return { ok = false, why = "That gift has gone." }
	end
	open[player] = nil
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "One moment." }
	end
	local paid = Gilt.pay(player, data, gift.gilt, "Admin Abuse gift")
	local count = countFor(player, gift.night) + 1
	opened[player] = { night = gift.night, count = count }
	local crown = false
	local bonus = 0
	if count == cfg().crownAfter then
		if hasCrown(player) then
			bonus = Gilt.pay(player, data, cfg().crownBonus, "Admin Abuse gift")
		else
			crown = Curios.forEvent(player, AbuseShow.CROWN, AbuseShow.CROWN)
		end
	end
	return { ok = true, gilt = paid + bonus, crown = crown, count = count }
end

---------------------------------------------------------------------------------------------------
-- The night
---------------------------------------------------------------------------------------------------
local runToken = 0

-- Admin Abuse (or Mega Abuse) has begun: the night's realm (Mega Abuse: its realms in turn, at
-- the same moments in every server, counted from `since`), and AJKR's gifts, while it's on.
function AbuseShow.began(mega: boolean, plan: AbuseNights.Plan?, since: number?)
	runToken += 1
	local my = runToken
	local c = cfg()
	local start = since or os.time()
	local realms: { string } = if plan then plan.realms elseif mega then c.realms else { c.abuseRealm }
	local realmSeconds: number = math.max(10, if plan then plan.realmSeconds else c.realmSeconds)
	local giftEvery: number = math.max(10, if plan then plan.giftEvery elseif mega then c.giftEvery.mega else c.giftEvery.abuse)
	local function realmAt(now: number): string?
		if #realms == 0 then
			return nil
		end
		local k = math.floor(math.max(0, now - start) / realmSeconds)
		return realms[k % #realms + 1]
	end
	local current = realmAt(os.time())
	setRealm(current)
	-- AJKR's own look, as it is now, for the nights that show it.
	if plan and (plan.giant or table.find(plan.night.pool, "ownerArmy")) then
		task.spawn(AbuseShow.buildAvatar, true)
	end
	task.spawn(function()
		local nextGift = start + math.floor(giftEvery * 0.4)
		while nextGift < os.time() do
			nextGift += giftEvery
		end
		while runToken == my and night() do
			local now = os.time()
			local want = realmAt(now)
			if want ~= current then
				current = want
				setRealm(want)
			end
			if now >= nextGift then
				nextGift = now + giftEvery
				for _, p in Players:GetPlayers() do
					AbuseShow.offer(p)
				end
			end
			task.wait(1)
		end
		if runToken == my then
			setRealm(nil)
			table.clear(open)
		end
	end)
end

-- Stopped (Stop everything): the realm goes at once.
function AbuseShow.stopped()
	runToken += 1
	setRealm(nil)
	table.clear(open)
end

function AbuseShow.start()
	RemoteGuard.invoke(Remotes.func("AbuseGiftAsk"), "abuseGift", AbuseShow.open)
	Players.PlayerRemoving:Connect(function(player)
		open[player] = nil
		opened[player] = nil
	end)
	-- AJKR's avatar: now, and again every few minutes (their look as it is then), so it's never
	-- out of date; and as soon as AJKR's own character appears here (what they're wearing now).
	task.spawn(function()
		local first = true
		while true do
			pcall(AbuseShow.buildAvatar, not first)
			first = false
			task.wait(math.max(60, cfg().avatarRefreshSeconds or 300))
		end
	end)
	local function watch(p: Player)
		if p.UserId == Config.data.Admin.ownerUserId then
			pcall(function()
				p.CharacterAppearanceLoaded:Connect(function()
					task.delay(1, AbuseShow.buildAvatar, true)
				end)
			end)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

return AbuseShow
