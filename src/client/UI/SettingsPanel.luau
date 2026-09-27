--!strict
-- Settings (Appendix F), saved to the guest's profile so they follow them between devices.
-- Each change applies at once and only to what it affects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local SettingsPanel = {}

local NAME = "Settings"

local function valueText(def: Settings.Definition, value: any): string
	if def.range then
		return tostring(value)
	end
	return tostring(value)
end

local function row(parent: Instance, def: Settings.Definition, order: number)
	local frame = Instance.new("Frame")
	frame.Name = def.key
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 40)
	frame.LayoutOrder = order
	frame.Parent = parent
	local label = Theme.text(frame, def.label, 15, "body", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0.52, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if def.wired then Brand.Colours.bone else Brand.Colours.dim,
	})
	label.TextWrapped = true
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, 0, 0.5, 0)
	holder.Size = UDim2.new(0.46, 0, 0, 34)
	holder.Parent = frame

	if not def.wired then
		Theme.text(holder, if def.group == "The Club" then "Opens with the Club Floor" else "Arrives with the next rooms", 12, "body", {
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Brand.Colours.dim,
		})
		return
	end

	if def.options then
		local options = def.options
		local key: TextButton
		key = Theme.key(holder, valueText(def, State.get(def.key)), false, function()
			local now = State.get(def.key)
			local index = table.find(options, now) or 1
			local nextValue = options[(index % #options) + 1]
			State.set(def.key, nextValue)
		end, 10)
		key.Size = UDim2.fromScale(1, 1)
		key.Text = valueText(def, State.get(def.key))
		State.SettingChanged:Connect(function(k, v)
			if k == def.key and key.Parent then
				key.Text = valueText(def, v)
			end
		end)
	elseif def.range then
		local range = def.range
		local list = Theme.list(holder, 6, true)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Right
		local minus = Theme.key(holder, "–", false, function()
			State.set(def.key, math.clamp((State.get(def.key) :: number) - 5, range[1], range[2]))
		end, 38)
		minus.Size = UDim2.fromOffset(38, 34)
		minus.LayoutOrder = 1
		local value = Theme.text(holder, tostring(State.get(def.key)), 15, "bodyMedium", {
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromOffset(44, 34),
			LayoutOrder = 2,
			TextColor3 = Brand.Colours.lightGold,
		})
		local plus = Theme.key(holder, "+", false, function()
			State.set(def.key, math.clamp((State.get(def.key) :: number) + 5, range[1], range[2]))
		end, 38)
		plus.Size = UDim2.fromOffset(38, 34)
		plus.LayoutOrder = 3
		State.SettingChanged:Connect(function(k, v)
			if k == def.key and value.Parent then
				value.Text = tostring(v)
			end
		end)
	end
end

function SettingsPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(560, size.X - 24)
	local h = math.min(620, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Settings", 26, "display", { LayoutOrder = 1 })
	Theme.hairline(content, UDim.new(0, 90), 2)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 3
	scroll.Size = UDim2.new(1, 0, 1, -(26 + 12 + 44 + 40))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Brand.Colours.gold
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = content
	local inner = Theme.list(scroll, 4)
	inner.VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = scroll

	local order = 0
	for _, groupName in Settings.Groups do
		order += 1
		local heading = Theme.text(scroll, groupName, 11, "caps", { LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left })
		heading.Size = UDim2.new(1, 0, 0, 26)
		for _, def in Settings.Definitions do
			if def.group == groupName then
				order += 1
				row(scroll, def, order)
			end
		end
	end

	local close = Theme.key(content, "Close", true, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 4
	Root.open(NAME, group)
end

return SettingsPanel
