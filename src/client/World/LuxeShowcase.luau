--!strict
-- (Build 94) Steal a Luxe's pieces on show, on this screen alone: each turns slowly on its plinth
-- and breathes up and down a little, the finer ones a touch faster, so the halls read as a
-- showroom. Only while the guest is in Steal a Luxe, and only the pieces near them (their halo, the
-- light on the floor and the column of light stay still). Looks only: the server never sees it,
-- and a piece taken or put back is picked up or dropped by itself.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LuxeShowcase = {}

local STILL = { Halo = true, FloorGlow = true, LightColumn = true, Root = true }
local NEAR = 90 -- studs
local SPEED = { Common = 0.35, Uncommon = 0.4, Rare = 0.5, Epic = 0.6, Legendary = 0.75, Mythic = 0.9, Limited = 0.9, Exclusive = 0.9 } :: { [string]: number }

type Shown = { parts: { { part: BasePart, rel: CFrame } }, pivot: CFrame, phase: number, speed: number }
local shown: { [Model]: Shown } = setmetatable({}, { __mode = "k" }) :: any

local function learn(m: Model): Shown?
	local root = m.PrimaryPart or m:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local pivot = root.CFrame
	local parts = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not STILL[d.Name] then
			table.insert(parts, { part = d, rel = pivot:ToObjectSpace(d.CFrame) })
		end
	end
	local rarity = m:GetAttribute("Rarity")
	return { parts = parts, pivot = pivot, phase = math.random() * math.pi * 2, speed = SPEED[if type(rarity) == "string" then rarity else ""] or 0.4 }
end

local function inside(): boolean
	return Players.LocalPlayer:GetAttribute("Attraction") == "luxe"
end

function LuxeShowcase.start()
	local clock = 0
	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		acc += dt
		if acc < 1 / 30 then
			return
		end
		acc = 0
		if not inside() then
			return
		end
		local character = Players.LocalPlayer.Character
		local me = character and character:FindFirstChild("HumanoidRootPart")
		if not me or not me:IsA("BasePart") then
			return
		end
		for _, inst in CollectionService:GetTagged("LuxePiece") do
			if not inst:IsA("Model") or not inst.Parent then
				continue
			end
			local sh = shown[inst]
			if not sh then
				local fresh = learn(inst)
				if not fresh then
					continue
				end
				shown[inst] = fresh
				sh = fresh
			end
			if (sh.pivot.Position - me.Position).Magnitude > NEAR then
				continue
			end
			local turn = CFrame.Angles(0, clock * sh.speed + sh.phase, 0)
			local at = sh.pivot * CFrame.new(0, math.sin(clock * 1.6 + sh.phase) * 0.12, 0) * turn
			for _, p in sh.parts do
				if p.part.Parent then
					p.part.CFrame = at * p.rel
				end
			end
		end
	end)
end

return LuxeShowcase
