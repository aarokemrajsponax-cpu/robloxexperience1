--!strict
-- (Build 105) The Mischief key on the Steal a Luxe and Basement screens: shown only while another
-- guest is in reach (for a Midway Steal, a guest carrying pieces), naming who and how many plays are
-- held, or the Robux price when none is (one press then opens Roblox's purchase window, nothing
-- more). The server decides everything: who's in reach, the cooldown, the safe window, the charge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Perks = require(script.Parent.Parent.Perks)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local MischiefKey = {}

export type Spec = { kind: string, id: string, act: string, reach: number, label: string, carrying: boolean }

MischiefKey.SPECS = {
	midway = { kind = "midway", id = "luxe", act = "midway", reach = 14, label = "Midway Steal", carrying = true },
	push = { kind = "push", id = "basement", act = "push", reach = 12, label = "Push", carrying = false },
} :: { [string]: Spec }

local player = Players.LocalPlayer

-- The nearest other guest in reach (and in the same attraction), or nil.
function MischiefKey.target(spec: Spec): Player?
	local me = player.Character
	local root = me and me:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local here = player:GetAttribute("Attraction")
	local best: Player?, bestD = nil, spec.reach
	for _, other in Players:GetPlayers() do
		if other == player or other:GetAttribute("Attraction") ~= here then
			continue
		end
		if spec.carrying and (tonumber(other:GetAttribute("LuxeBag")) or 0) <= 0 then
			continue
		end
		local c = other.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			local d = (r.Position - root.Position).Magnitude
			if d <= bestD then
				best, bestD = other, d
			end
		end
	end
	return best
end

-- The key's words: who, and the plays held (or the price).
function MischiefKey.text(spec: Spec, target: Player?): string
	local held = Perks.held("mischief_" .. spec.kind)
	local who = if target then target.DisplayName else ""
	if held > 0 then
		return string.format("%s %s (%d)", spec.label, who, held)
	end
	return string.format("%s %s · 19 R$", spec.label, who)
end

-- Adds the key to `parent` (hidden until someone's in reach); returns a stop function.
function MischiefKey.mount(parent: Instance, kind: string): () -> ()
	local spec = MischiefKey.SPECS[kind]
	local current: Player? = nil
	local busy = false
	local key = Theme.key(parent, spec.label, true, function()
		local target = current
		if busy or not target then
			return
		end
		busy = true
		task.spawn(function()
			local ok, r = pcall(function()
				return Remotes.func("AttractionAsk"):InvokeServer({ op = "act", id = spec.id, act = spec.act, n = target.UserId })
			end)
			busy = false
			if ok and type(r) == "table" and r.ok ~= true and r.prompted ~= true then
				Toast.refused(r, "Not just now.")
			end
		end)
	end, 200, "ruby")
	key.Name = "MischiefKey"
	key.Visible = false
	local alive = true
	task.spawn(function()
		while alive and key.Parent do
			current = MischiefKey.target(spec)
			key.Visible = current ~= nil
			if current then
				key.Text = MischiefKey.text(spec, current)
			end
			task.wait(0.25)
		end
	end)
	return function()
		alive = false
	end
end

-- A shove from the server: the guest's own character is pushed (their client owns its physics).
function MischiefKey.pushed(m: { [string]: any })
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local x, y, z = tonumber(m.x), tonumber(m.y), tonumber(m.z)
	if root and root:IsA("BasePart") and x and y and z then
		local v = Vector3.new(x, y, z)
		if v.Magnitude <= 120 then
			root.AssemblyLinearVelocity = v
		end
	end
	Toast.show("Pushed", tostring(m.by or "Someone") .. " shoved you.", 2)
end

return MischiefKey
