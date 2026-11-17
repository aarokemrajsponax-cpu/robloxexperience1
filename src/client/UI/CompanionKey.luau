--!strict
-- (Build 94) Inside Steal a Luxe, the Maison Basement and the Executive Suite the brainrot walking
-- beside a guest, and their companion, step aside so everyone can see the way. This small key, on
-- the right of the screen while there, calls them back in for the visit (or sends them away
-- again); the server sets it, so every screen agrees. Leaving the attraction, they're back
-- beside the guest by themselves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local CurioState = require(script.Parent.Parent.CurioState)

local CompanionKey = {}

local player = Players.LocalPlayer
local key: TextButton? = nil
local busy = false

local function has(): boolean
	local b = player:GetAttribute("Brainrot")
	local c = player:GetAttribute("Companion")
	return (type(b) == "string" and b ~= "") or (type(c) == "string" and c ~= "")
end

local function inside(): string?
	local a = player:GetAttribute(AttractionList.ATTRIBUTE)
	return if type(a) == "string" and AttractionList.HIDES_COMPANIONS[a] then a else nil
end

local function refresh()
	local a = inside()
	if not a or not has() then
		if key then
			key:Destroy()
			key = nil
		end
		return
	end
	local shown = player:GetAttribute(AttractionList.COMPANIONS_IN) == a
	local text = if shown then "Send my brainrot away" else "Call my brainrot in"
	if key and key.Name == "CompanionKey_" .. tostring(shown) then
		return
	end
	if key then
		key:Destroy()
	end
	local k = Theme.key(Root.hud, text, false, function()
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local r = CurioState.ask({ op = "summon", on = not shown })
			busy = false
			if type(r) == "table" and r.ok ~= true and type(r.why) == "string" then
				Toast.show("Your brainrot", r.why, 3)
			end
		end)
	end, 200)
	k.Name = "CompanionKey_" .. tostring(shown)
	k.AnchorPoint = Vector2.new(1, 1)
	-- (Above the jump button on a touch screen; above the corner's cards otherwise.)
	k.Position = UDim2.new(1, -16, 1, if UserInputService.TouchEnabled then -230 else -150)
	k.Size = UDim2.fromOffset(200, 40)
	key = k
end

function CompanionKey.start()
	for _, name in { AttractionList.ATTRIBUTE, AttractionList.COMPANIONS_IN, "Brainrot", "Companion" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return CompanionKey
