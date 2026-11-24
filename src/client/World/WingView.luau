--!strict
-- (Build 102) Only the private wings that matter are drawn on this screen: this guest's own (always,
-- so the floor is there the instant the elevator opens on it), the friend's they're riding up to
-- or visiting, and the one they stand in. Every other guest's wing is put away on this screen, so
-- nobody's rooms or lights are ever seen from anyone else's windows (and phones draw far less).
-- The wings themselves, and who may be in which, are the server's (server/Wings).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Wing = require(ReplicatedStorage.Shared.Wing)

local WingView = {}

local player = Players.LocalPlayer
local away: { [Model]: number } = {}
local holder: Folder? = nil

-- The wings this screen keeps drawn now.
function WingView.wanted(): { [number]: boolean }
	local keep: { [number]: boolean } = {}
	local mine = player:GetAttribute("Wing")
	if type(mine) == "number" then
		keep[mine] = true
	end
	local visit = player:GetAttribute("WingVisit")
	if type(visit) == "number" then
		keep[visit] = true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local k = Wing.slotAt(root.Position)
		if k then
			keep[k] = true
		end
	end
	return keep
end

function WingView.refresh()
	local wings = Workspace:FindFirstChild("PrivateWings")
	if not wings then
		return
	end
	holder = wings :: Folder
	local keep = WingView.wanted()
	for _, m in wings:GetChildren() do
		local k = m:GetAttribute("Wing")
		if m:IsA("Model") and type(k) == "number" and not keep[k] then
			away[m] = k
			m.Destroying:Once(function()
				away[m] = nil
			end)
			m.Parent = nil
		end
	end
	for m, k in away do
		if keep[k] then
			away[m] = nil
			m.Parent = holder
		end
	end
	-- (Build 104) A wing's open grounds (the country beyond its garden walls) are drawn only while
	-- standing in that wing: from the house below, nothing hangs in the sky.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local here = if root and root:IsA("BasePart") then Wing.slotAt(root.Position) else nil
	for _, m in wings:GetChildren() do
		local k = m:GetAttribute("Wing")
		local garden = m:FindFirstChild("Garden")
		local grounds = garden and garden:FindFirstChild("Grounds")
		if grounds and grounds:IsA("BasePart") then
			local want = if k == here then 0 else 1
			if grounds.Transparency ~= want then
				grounds.Transparency = want
			end
		end
	end
end

function WingView.start()
	task.spawn(function()
		while true do
			pcall(WingView.refresh)
			task.wait(0.4)
		end
	end)
end

return WingView
