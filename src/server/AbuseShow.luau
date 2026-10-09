--!strict
-- Admin Abuse as a show, on the server:
--   the owner     the owner's own avatar, built here once (only a server can) and kept in
--                 ReplicatedStorage, so every screen can draw it: in the hologram that casts each
--                 surprise, and as the giant over the house. It's built from the owner's UserId, so
--                 it's there whether or not the owner is in this server.
--   the realms    Mega Abuse moves the house from realm to realm (the cosmos, a sugar rush, Midas
--                 gold, neon, the abyss, frost), each for a while; Admin Abuse keeps to one (gilded).
--                 The server only says which (Workspace's AbuseRealm, AbuseRealmAt); every screen
--                 draws it.
--   the gifts     every so often, a gift from the owner on every guest's screen, theirs to open
--                 while it lasts. Opening it is checked here (their own gift, still open, Admin Abuse
--                 still on) and pays Gilt; the third opened in one night gives the Admin's Crown
--                 (once ever), or more Gilt to a guest who has it. Nothing random, nothing paid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

-- (Set for tests: what Roblox's Players gives for a UserId.)
AbuseShow.makeAvatar = function(userId: number): Model?
	local description = Players:GetHumanoidDescriptionFromUserId(userId)
	return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
end

local building = false
-- Builds the owner's avatar for every screen, if it isn't there yet. False if Roblox couldn't
-- give it just now (tried again later).
function AbuseShow.buildAvatar(): boolean
	local home = AbuseShow.home()
	if home:FindFirstChild(AbuseShow.AVATAR) then
		return true
	end
	if building then
		return false
	end
	building = true
	local ok, model = pcall(AbuseShow.makeAvatar, Config.data.Admin.ownerUserId)
	building = false
	if not ok or typeof(model) ~= "Instance" or not (model :: Instance):IsA("Model") then
		return false
	end
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
	m.Parent = home
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

-- Admin Abuse (or Mega Abuse) has begun: the realms in turn, and the gifts, while it's on.
function AbuseShow.began(mega: boolean)
	runToken += 1
	local my = runToken
	local c = cfg()
	local realms: { string } = c.realms
	if mega and #realms > 0 then
		setRealm(realms[1])
	else
		setRealm(c.abuseRealm)
	end
	task.spawn(function()
		local i = 1
		local nextRealm = os.time() + c.realmSeconds
		local nextGift = os.time() + math.floor((if mega then c.giftEvery.mega else c.giftEvery.abuse) * 0.4)
		while runToken == my and night() do
			local now = os.time()
			if mega and #realms > 1 and now >= nextRealm then
				i = i % #realms + 1
				setRealm(realms[i])
				nextRealm = now + c.realmSeconds
			end
			if now >= nextGift then
				nextGift = now + (if mega then c.giftEvery.mega else c.giftEvery.abuse)
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
	-- The owner's avatar: now, and again later if Roblox couldn't give it.
	task.spawn(function()
		for _ = 1, 20 do
			if AbuseShow.buildAvatar() then
				return
			end
			task.wait(60)
		end
	end)
end

return AbuseShow
