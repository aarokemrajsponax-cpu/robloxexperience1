--!strict
-- How to play: five short steps with the real 3D pieces turning slowly in gold light.
-- Back / Next; the last step seats you at a table. Closing it returns you exactly where you were.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local PieceIcon = require(script.Parent.PieceIcon)
local State = require(script.Parent.Parent.State)

local HowToPlay = {}

local NAME = "HowToPlay"

local STEPS = {
	{ title = Voice.HowToPlay[1], line = "Drag a piece, or tap it.", piece = "dressWatch" },
	{ title = Voice.HowToPlay[2], line = "Every piece has a case. Drop it in.", piece = "diamondRing" },
	{ title = Voice.HowToPlay[3], line = "A thread of gold runs to the right case.", piece = "goldBar" },
	{ title = Voice.HowToPlay[4], line = "A streak raises the multiplier. Three into one case pays more.", piece = "rubyGem" },
	{ title = Voice.HowToPlay[5], line = "The Salon keeps no clock. Take your time.", piece = "objetEgg" },
}

-- The Club Floor's own three steps, the first time a guest climbs the stair (§15).
local CLUB_STEPS = {
	{ title = "Same pieces, both of you", line = "In the Library two guests sort the identical deal. First to clear the felt takes the hand.", piece = "pocketWatch" },
	{ title = "Three in a row sends a parcel", line = "Three into one case sends a sealed parcel of lookalikes across. Your own parcels cancel theirs.", piece = "goldCoins" },
	{ title = "Keep your lamp lit", line = "In the Ballroom a felt holds sixteen. Go over for three seconds and your lamp goes out. The last lamp wins.", piece = "blackDiamond" },
}

-- Set by Main: what the last step's key does (seat the guest, or return them to the table).
HowToPlay.onFinish = function() end

-- The piece, drawn as it is on the sorting screen, in a pool of gold light, floating gently.
local function viewport(parent: Instance, pieceId: string): (Frame, () -> ())
	local holder = Instance.new("Frame")
	holder.Name = "Piece"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 170)
	holder.LayoutOrder = 2
	holder:SetAttribute("Piece", pieceId)
	holder.Parent = parent
	for k, size in { 1.0, 0.78, 0.58 } do
		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromOffset(170 * size, 170 * size)
		glow.BorderSizePixel = 0
		glow.BackgroundColor3 = Color3.fromRGB(226, 176, 86)
		glow.BackgroundTransparency = 0.95 - k * 0.012
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = glow
		glow.Parent = holder
	end
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromOffset(130, 130)
	art.Parent = holder
	PieceIcon.piece(art, pieceId, 130)
	local t = 0
	local conn = RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		art.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 1.4) * 4)
		art.Rotation = math.sin(t * 0.9) * 3
	end)
	return holder, function()
		conn:Disconnect()
	end
end

function HowToPlay.open(club: boolean?)
	if Root.isOpen(NAME) then
		return
	end
	local STEPS = if club then CLUB_STEPS else STEPS
	local size = Root.size()
	local w = math.min(480, size.X - 24)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 470))
	Theme.fitHeight(group, content)
	Theme.list(content, 10).VerticalAlignment = Enum.VerticalAlignment.Top

	local stepLabel = Theme.text(content, "", 11, "caps", { LayoutOrder = 1 })
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 170)
	holder.LayoutOrder = 2
	holder.Parent = content
	local title = Theme.text(content, "", 26, "display", { LayoutOrder = 3 })
	Theme.hairline(content, UDim.new(0, 70), 4)
	local line = Theme.text(content, "", 16, "body", { LayoutOrder = 5, TextColor3 = Brand.Colours.smoke })

	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 44)
	keys.LayoutOrder = 6
	keys.Parent = content
	Theme.list(keys, 10, true)

	local index = 1
	local stopSpin: (() -> ())? = nil
	local back: TextButton
	local nextKey: TextButton

	local function render()
		local step = STEPS[index]
		stepLabel.Text = string.upper(Voice.roman(index) .. "  of  " .. Voice.roman(#STEPS))
		title.Text = step.title
		line.Text = step.line
		if stopSpin then
			stopSpin()
		end
		for _, c in holder:GetChildren() do
			c:Destroy()
		end
		local vp, stop = viewport(holder, step.piece)
		vp.Size = UDim2.fromScale(1, 1)
		stopSpin = stop
		back.Visible = index > 1
		local last = index == #STEPS
		local text = if last then (if club then "Understood" elseif State.seated then "Back to the table" else "Take me to a table") else "Next"
		nextKey.Text = string.upper(text)
	end

	back = Theme.key(keys, "Back", false, function()
		index = math.max(1, index - 1)
		render()
	end, 150)
	nextKey = Theme.key(keys, "Next", true, function()
		if index < #STEPS then
			index += 1
			render()
		else
			Root.close(NAME)
			if not club then
				HowToPlay.onFinish()
			end
		end
	end, 220)
	local close = Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 150)
	close.LayoutOrder = 7
	render()
	Root.open(NAME, group, function()
		if stopSpin then
			stopSpin()
		end
	end)
end

return HowToPlay
