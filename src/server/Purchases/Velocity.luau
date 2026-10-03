--!strict
-- VIP Velocity Elite: walk and run 1.5× faster for good, with a gold trail at your heels
-- (ProductConfig velocityElite, a game pass; velocityEliteProduct, the same as a one-time
-- developer product for experiences without the pass).
--
-- Ownership is Roblox's word: the pass is checked with UserOwnsGamePassAsync whenever the guest
-- arrives (a pass Roblox stops reporting, after a refund, is taken away and logged), and granted
-- the moment Roblox reports the purchase. The entitlement is one flag in the profile, so it can't
-- be granted twice; a second one-time purchase becomes Boutique credit.
--
-- The speed goes through Shared/Speed with every other speed effect (the server only sets the
-- "SpeedPerk" attribute; the guest's screen applies the one combined speed), and both the speed
-- and the trail can be switched off in Settings, independently.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)
local Catalog = require(script.Parent.Catalog)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)
local Telemetry = require(script.Parent.Telemetry)

local Velocity = {}

local PASS = "velocityElite"
local PRODUCT = "velocityEliteProduct"
local AURA = "VelocityAura"

local function multiplier(): number
	return ProductConfig.byKey[PASS].Reward.SpeedMultiplier
end

function Velocity.owns(data: Profiles.Data): boolean
	return data.perks.velocity == true
end

-- The gold trail at a guest's heels: two attachments at the feet and a short, thin trail, with a
-- few sparks. Visible, never in the way.
local function addAura(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or character:FindFirstChild(AURA) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = AURA
	local a0 = Instance.new("Attachment")
	a0.Name = "AuraLow"
	a0.Position = Vector3.new(0, -2.4, 0.3)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "AuraHigh"
	a1.Position = Vector3.new(0, -1.6, 0.3)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "GoldTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.MinLength = 0.2
	trail.FaceCamera = true
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(Color3.fromRGB(246, 222, 160), Color3.fromRGB(198, 160, 82))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Parent = folder
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Rate = 4
	sparks.Lifetime = NumberRange.new(0.4, 0.7)
	sparks.Speed = NumberRange.new(0.2, 0.6)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	sparks.Color = ColorSequence.new(Color3.fromRGB(246, 222, 160))
	sparks.LightEmission = 1
	sparks.Parent = a0
	folder.Parent = character
	-- The attachments live on the root (a trail needs them there); the folder marks the aura so it
	-- can be found and removed together.
	a0:SetAttribute("VelocityAura", true)
	a1:SetAttribute("VelocityAura", true)
end

local function removeAura(character: Model)
	local folder = character:FindFirstChild(AURA)
	if folder then
		folder:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, name in { "AuraLow", "AuraHigh" } do
			local a = root:FindFirstChild(name)
			if a then
				a:Destroy()
			end
		end
	end
end

-- Applies the perk as the guest's settings say: the speed attribute and the trail.
function Velocity.apply(player: Player)
	local data = Profiles.get(player)
	local owns = data ~= nil and Velocity.owns(data)
	local settings: { [string]: any } = if data then data.settings else {}
	local speedOn = owns and settings.velocitySpeed ~= "Off"
	local auraOn = owns and settings.velocityAura ~= "Off"
	player:SetAttribute("SpeedPerk", if speedOn then multiplier() else nil)
	player:SetAttribute("VelocityElite", if owns then true else nil)
	local character = player.Character
	if character then
		if auraOn then
			addAura(character)
		else
			removeAura(character)
		end
	end
	Perks.push(player)
end

-- Asks Roblox whether the guest owns the pass (three tries). nil if Roblox couldn't say.
local function ownsPass(player: Player): boolean?
	local id = Catalog.idOf(PASS)
	if id == 0 then
		return nil
	end
	for attempt = 1, 3 do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		if ok then
			return owns == true
		end
		task.wait(attempt)
	end
	return nil
end

-- On arrival: confirm ownership with Roblox (the profile's flag stands if Roblox can't answer).
function Velocity.check(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local owns = ownsPass(player)
	if owns == true and not data.perks.velocityPass then
		data.perks.velocity = true
		data.perks.velocityPass = true
	elseif owns == false and data.perks.velocityPass then
		-- Roblox no longer reports the pass (refunded): the perk goes with it.
		data.perks.velocityPass = false
		data.perks.velocity = (data.purchases[PRODUCT] or 0) > 0
		Telemetry.log(player, Telemetry.Events.Revoked, PASS, "not_owned")
	end
	Velocity.apply(player)
end

local function grant(ctx: Grants.Context)
	local data = ctx.data
	if Velocity.owns(data) then
		-- Already theirs (bought twice): the second becomes Boutique credit, never lost.
		local creditKey = ctx.product.Rules.DuplicateCredit or "tier499"
		data.credits[creditKey] = (data.credits[creditKey] or 0) + 1
		local player = ctx.player
		ctx:after(function()
			Perks.tell(player, { op = "notice", title = "VIP Velocity Elite", line = "It was already yours, so this one is kept as Boutique credit." })
		end)
		return
	end
	data.perks.velocity = true
	local player = ctx.player
	ctx:after(function()
		Velocity.apply(player)
		Perks.tell(player, { op = "notice", title = "VIP Velocity Elite", line = "Yours for good: 1.5× speed and a gold trail. Both can be switched off in Settings." })
	end)
end

function Velocity.start()
	Grants.register("velocity", grant)
	local function notOwned(_player: Player, data: Profiles.Data): (boolean, string?)
		if Velocity.owns(data) then
			return false, "VIP Velocity Elite is already yours."
		end
		return true, nil
	end
	Store.eligibility[PASS] = notOwned
	Store.eligibility[PRODUCT] = notOwned
	Perks.contributors.velocity = function(_player: Player, data: Profiles.Data): any
		return {
			owned = Velocity.owns(data),
			speed = data.settings.velocitySpeed ~= "Off",
			aura = data.settings.velocityAura ~= "Off",
			multiplier = multiplier(),
		}
	end
	-- A pass bought in this server: the "purchase finished" event only says a window closed, so
	-- ownership is confirmed with Roblox (UserOwnsGamePassAsync, retried while Roblox catches up)
	-- before it's granted. If Roblox can't confirm it yet, the next arrival will.
	pcall(function()
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
			if not purchased or passId ~= Catalog.idOf(PASS) then
				return
			end
			task.spawn(function()
				for attempt = 1, ProductConfig.Settings.PassConfirmTries do
					local data = Profiles.get(player)
					if not data or player.Parent ~= Players or data.perks.velocityPass then
						return
					end
					if ownsPass(player) == true then
						data.perks.velocity = true
						data.perks.velocityPass = true
						Telemetry.log(player, Telemetry.Events.Granted, PASS, "pass", Catalog.price(PASS), Telemetry.segment(data.purchases))
						Velocity.apply(player)
						Perks.tell(player, { op = "notice", title = "VIP Velocity Elite", line = "Yours for good: 1.5× speed and a gold trail. Both can be switched off in Settings." })
						return
					end
					task.wait(attempt * 2)
				end
			end)
		end)
	end)
	Profiles.Loaded:Connect(function(player: Player)
		task.spawn(Velocity.check, player)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(Velocity.apply, player)
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
end

return Velocity
