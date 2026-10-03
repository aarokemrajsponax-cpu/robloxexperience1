--!strict
-- Chronos Defiance, when the clock runs out in a timed room: a small card over the table with
-- the real time left to decide (the server's window, counted down here), what a revive gives,
-- and what it costs or that one is already held. Two clear keys: revive, or bank the run. While
-- Roblox's own purchase window is open the countdown waits, and says so; after a purchase it
-- says it's waiting for Roblox to confirm. Nothing here is invented: every number comes from
-- the server's message.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Sound = require(script.Parent.Parent.Sound)

local RevivePanel = {}

local NAME = "Revive"
local ROBUX = utf8.char(0xE002)

export type Actions = { onRevive: () -> (), onBank: () -> () }

local deadline = 0 -- os.clock() when the server's window closes
local waiting = false -- Roblox's purchase window is open, or its receipt is on its way
local countdown: TextLabel? = nil
local status: TextLabel? = nil
local reviveKey: TextButton? = nil
local beat: RBXScriptConnection? = nil
local lastWhole = -1

local function number(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function reviveText(m: { [string]: any }): string
	local held = tonumber(m.held) or 0
	if held > 0 then
		return string.format("Use a revive (%d held)", held)
	elseif type(m.price) == "number" then
		return string.format("Revive  %s %s", ROBUX, number(m.price))
	end
	return "Revive"
end

local function statusText(m: { [string]: any }): string
	if m.waitingReceipt then
		return "Waiting for Roblox to confirm your purchase. Your run revives the moment it does."
	elseif m.prompting then
		return "Roblox's purchase window is open. The clock waits."
	elseif type(m.why) == "string" then
		return m.why
	end
	local left = tonumber(m.usesLeft) or 0
	return string.format("%d revive%s left this run.", left, if left == 1 then "" else "s")
end

-- Applies a message from the server to the card (the window's time, the keys, the line).
function RevivePanel.update(m: { [string]: any })
	deadline = os.clock() + math.max(0, tonumber(m.left) or 0)
	waiting = m.prompting == true or m.waitingReceipt == true
	if status then
		status.Text = statusText(m)
	end
	if reviveKey then
		reviveKey.Text = string.upper(reviveText(m))
		reviveKey.Visible = not waiting and ((tonumber(m.held) or 0) > 0 or m.onSale == true)
	end
end

function RevivePanel.open(m: { [string]: any }, actions: Actions)
	RevivePanel.close()
	local size = Root.size()
	local w = math.min(400, size.X - 24)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 0), UDim2.new(0.5, 0, 0.5, 10))
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The clock ran out", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "Chronos Defiance", 24, "display", { LayoutOrder = 2 })
	countdown = Theme.text(content, "", 40, "display", { LayoutOrder = 3, TextColor3 = Brand.Colours.lightGold })
	Theme.text(content, string.format("+%d seconds, and your run goes on.", tonumber(m.add) or 0), 15, "body", {
		LayoutOrder = 4,
		TextWrapped = true,
		TextColor3 = Brand.Colours.bone,
	})
	if m.boardsCount == false then
		Theme.text(content, string.format("The boards keep your score from before the revive (%s). Gilt counts the whole run.", number(tonumber(m.boardScore) or 0)), 12, "body", {
			LayoutOrder = 5,
			TextWrapped = true,
			TextColor3 = Brand.Colours.smoke,
		})
	end
	status = Theme.text(content, "", 12, "body", { LayoutOrder = 6, TextWrapped = true, TextColor3 = Brand.Colours.smoke })
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 10
	keys.Parent = content
	Theme.list(keys, 8)
	local revive = Theme.key(keys, reviveText(m), true, function()
		actions.onRevive()
	end, 280)
	revive.LayoutOrder = 1
	reviveKey = revive
	Theme.key(keys, "Bank the run", false, function()
		RevivePanel.close()
		actions.onBank()
	end, 280).LayoutOrder = 2
	RevivePanel.update(m)
	Root.open(NAME, group, nil, false)
	Sound.play("low", 0.3)
	pcall(function()
		game:GetService("GuiService").SelectedObject = revive
	end)
	lastWhole = -1
	beat = RunService.Heartbeat:Connect(function()
		local label = countdown
		if not label or not label.Parent then
			return
		end
		if waiting then
			label.Text = "· · ·"
			return
		end
		local left = math.max(0, deadline - os.clock())
		local whole = math.ceil(left)
		label.Text = string.format("0:%02d", whole)
		if whole ~= lastWhole and whole <= 3 and whole > 0 then
			Sound.play("tick", 0.2)
		end
		lastWhole = whole
	end)
end

function RevivePanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

function RevivePanel.close()
	if beat then
		beat:Disconnect()
		beat = nil
	end
	countdown = nil
	status = nil
	reviveKey = nil
	waiting = false
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
end

return RevivePanel
