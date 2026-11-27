--!strict
-- (Build 107) Codes: type one in and redeem it (server/Codes decides everything: whether it's a
-- code, whether it's open, whether you've used it, and what it pays). A small card of dark glass
-- with the house's gold, opened from the Codes key under the dock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Fortune = require(ReplicatedStorage.Shared.Fortune)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Moment = require(script.Parent.Moment)

local CodesPanel = {}

local NAME = "Codes"
local C = Brand.Colours

function CodesPanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

function CodesPanel.close()
	Root.close(NAME)
end

-- Sends a code to the server; the answer is shown (and celebrated when it pays).
function CodesPanel.redeem(text: string, said: TextLabel?)
	local ok, r = pcall(function()
		return Remotes.func("CodeAsk"):InvokeServer({ code = text })
	end)
	local reply: { [string]: any } = if ok and type(r) == "table" then r else { ok = false, why = "The house couldn't read that just now. Try again in a moment." }
	if reply.ok == true then
		local gilt = tonumber(reply.gilt) or 0
		if said then
			said.Text = string.format("Redeemed: +%s Gilt", Fortune.format(gilt))
			said.TextColor3 = C.brightGold
		end
		pcall(Moment.burst, C.gold, true)
		pcall(Moment.show, { kicker = "Code redeemed", title = tostring(reply.title or "A gift"), line = string.format("+%s Gilt", Fortune.format(gilt)), tone = C.gold, seconds = 4, big = true, value = gilt, sound = "shimmerFall", volume = 0.7 })
		CodesPanel.close()
	else
		local why = tostring(reply.why or "That code didn't work.")
		if said then
			said.Text = why
			said.TextColor3 = Color3.fromRGB(255, 150, 140)
		else
			Toast.show("Codes", why, 3)
		end
	end
	return reply
end

function CodesPanel.open()
	if Root.isOpen(NAME) then
		Root.close(NAME)
		return
	end
	local w = Root.panelWidth(460)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 300))
	Theme.fitHeight(group, content)
	Theme.list(content, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The house's codes", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "Redeem a code", 26, "display", { LayoutOrder = 2 })
	Theme.text(content, "New codes are posted on the game's page and socials. Each one works once, while it's open.", 13, "body", { LayoutOrder = 3, TextWrapped = true, TextColor3 = C.smoke })
	local box = Instance.new("TextBox")
	box.Name = "CodeText"
	box.LayoutOrder = 4
	box.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	box.BackgroundTransparency = 0.15
	box.Size = UDim2.new(1, 0, 0, 48)
	box.FontFace = Brand.Fonts.heavy
	box.TextSize = 20
	box.TextColor3 = C.bone
	box.PlaceholderText = "Type a code"
	box.PlaceholderColor3 = C.dim
	box.ClearTextOnFocus = false
	box.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = C.gold
	stroke.Transparency = 0.4
	stroke.Parent = box
	box.Parent = content
	local said = Theme.text(content, "", 13, "bodyBold", { LayoutOrder = 5, TextWrapped = true })
	local row = Instance.new("Frame")
	row.Name = "Keys"
	row.LayoutOrder = 6
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 46)
	row.Parent = content
	Theme.list(row, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local busy = false
	local function go()
		if busy or box.Text == "" then
			return
		end
		busy = true
		task.spawn(function()
			CodesPanel.redeem(box.Text, said)
			busy = false
		end)
	end
	Theme.key(row, "Redeem", true, go, 160)
	Theme.key(row, "Close", false, CodesPanel.close, 120)
	-- Enter redeems too (a keyboard's way); guarded, so a place without the signal still opens the card.
	pcall(function()
		box.FocusLost:Connect(function(enter: boolean)
			if enter then
				go()
			end
		end)
	end)
	Root.open(NAME, group)
end

return CodesPanel
