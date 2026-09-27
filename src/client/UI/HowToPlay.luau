--!strict
-- How to play: five short steps with the real 3D pieces turning slowly in gold light.
-- Back / Next; the last step seats you at a table. Closing it returns you exactly where you were.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local PieceModels = require(ReplicatedStorage.Shared.PieceModels)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
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

-- Set by Main: what the last step's key does (seat the guest, or return them to the table).
HowToPlay.onFinish = function() end

local function viewport(parent: Instance, pieceId: string): (ViewportFrame, () -> ())
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Piece"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.new(1, 0, 0, 170)
	vp.LayoutOrder = 2
	vp.Ambient = Color3.fromRGB(70, 60, 50)
	vp.LightColor = Color3.fromRGB(255, 226, 170)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vp
	vp.CurrentCamera = camera
	local model: Model? = nil
	local angle = 0
	local function setPiece(id: string)
		if model then
			model:Destroy()
		end
		local m = PieceModels.build(id, Color3.fromRGB(16, 17, 20))
		m.Parent = world
		model = m
		local _, size = m:GetBoundingBox()
		local radius = math.max(size.X, size.Y, size.Z)
		camera.CFrame = CFrame.lookAt(Vector3.new(0, radius * 1.3, -radius * 3.2), Vector3.new(0, size.Y * 0.35, 0))
	end
	setPiece(pieceId)
	local conn = RunService.RenderStepped:Connect(function(dt: number)
		if model and model.PrimaryPart then
			angle += dt * 0.5
			model:PivotTo(CFrame.Angles(0, angle, 0))
		end
	end)
	vp:SetAttribute("Piece", pieceId)
	return vp, function()
		conn:Disconnect()
	end
end

function HowToPlay.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(480, size.X - 24)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 470))
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
		stepLabel.Text = Theme.track(string.upper(Voice.roman(index) .. "  of  " .. Voice.roman(#STEPS)))
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
		local text = if last then (if State.seated then "Back to the table" else "Take me to a table") else "Next"
		nextKey.Text = Theme.track(string.upper(text))
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
			HowToPlay.onFinish()
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
