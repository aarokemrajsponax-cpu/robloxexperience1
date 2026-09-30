--!strict
-- The Livre d'Or: the last signatures (a name and a chosen line, and when), and, once a night,
-- your own: choose a line and sign.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Closet = require(script.Parent.Parent.Closet)

local GuestBookPanel = {}

local NAME = "GuestBook"

local function ago(seconds: number): string
	if seconds < 3600 then
		return "just now"
	elseif seconds < 86400 then
		local h = math.floor(seconds / 3600)
		return if h == 1 then "an hour ago" else string.format("%d hours ago", h)
	end
	local d = math.floor(seconds / 86400)
	return if d == 1 then "yesterday" else string.format("%d days ago", d)
end

function GuestBookPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(520, size.X - 24)
	local h = math.min(600, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Livre d'Or", 26, "display", { LayoutOrder = 1 })
	Theme.hairline(content, UDim.new(0, 90), 2)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 3
	scroll.Size = UDim2.new(1, 0, 1, -(26 + 12 + 44 + 30))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Brand.Colours.gold
	scroll.Parent = content
	Theme.list(scroll, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll
	Theme.text(scroll, "One moment...", 14, "body", { LayoutOrder = 1, TextColor3 = Brand.Colours.dim })

	local function fill(v: { [string]: any })
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local order = 0
		local function add(): number
			order += 1
			return order
		end
		if not v.signedToday then
			Theme.text(scroll, "Sign it tonight", 11, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
			for i, line in v.lines do
				local k = Theme.key(scroll, line, false, function()
					task.spawn(function()
						local r = Closet.ask({ op = "sign", line = i })
						if type(r) == "table" and r.entries then
							Toast.show("The Livre d'Or", "Signed. The next guest will read it.", 3)
							fill(r)
						elseif type(r) == "table" then
							Toast.show("The Livre d'Or", tostring(r.why), 3)
						end
					end)
				end, 440)
				k.LayoutOrder = add()
			end
		else
			Theme.text(scroll, "You've signed tonight.", 13, "body", { LayoutOrder = add(), TextColor3 = Brand.Colours.smoke })
		end
		Theme.text(scroll, "Signed lately", 11, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
		if #v.entries == 0 then
			Theme.text(scroll, "The first page is still blank.", 14, "body", { LayoutOrder = add(), TextColor3 = Brand.Colours.dim })
		end
		for _, e in v.entries do
			Theme.text(scroll, string.format("%s  —  \"%s\"  ·  %s", tostring(e.name), tostring(e.text), ago((v.now or 0) - (e.at or 0))), 14, "body", {
				LayoutOrder = add(),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				TextColor3 = Brand.Colours.bone,
			})
		end
	end

	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 20
	keys.Parent = content
	Theme.list(keys, 8)
	local close = Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 300)
	Root.open(NAME, group)
	pcall(function()
		game:GetService("GuiService").SelectedObject = close
	end)
	task.spawn(function()
		local v = Closet.ask({ op = "guestBook" })
		if type(v) == "table" and v.lines and content.Parent then
			fill(v)
		end
	end)
end

return GuestBookPanel
