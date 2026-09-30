--!strict
-- The Ledger, as a book: this Term's page, how far through it you are, what the next page gives
-- on each row, and the Leather-Bound edition.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Closet = require(script.Parent.Parent.Closet)

local LedgerPanel = {}

local NAME = "Ledger"

function LedgerPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(460, size.X - 24)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, math.min(520, size.Y - 40)))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local title = Theme.text(content, "The Ledger", 26, "display", { LayoutOrder = 1 })
	Theme.hairline(content, UDim.new(0, 90), 2)
	local pageText = Theme.text(content, "", 40, "display", { LayoutOrder = 3, TextColor3 = Brand.Colours.lightGold })
	local of = Theme.text(content, "", 12, "caps", { LayoutOrder = 4 })
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(30, 26, 18)
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(0.8, 0, 0, 6)
	bar.LayoutOrder = 5
	bar.Parent = content
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Brand.Colours.gold
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	local nextFree = Theme.text(content, "", 14, "body", { LayoutOrder = 6, TextColor3 = Brand.Colours.bone })
	local nextLeather = Theme.text(content, "", 14, "body", { LayoutOrder = 7, TextColor3 = Brand.Colours.smoke })
	Theme.text(content, "Every page is cosmetic. Pages turn with anything you play: the rooms, the Nightly, the Library and the Ballroom.", 12, "body", { LayoutOrder = 8, TextColor3 = Brand.Colours.dim })
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 20
	keys.Parent = content
	Theme.list(keys, 8)
	local leatherKey = Theme.key(keys, "The Leather-Bound edition", false, function()
		local r = Closet.ask({ op = "ledgerLeather" })
		if type(r) == "table" and not r.ok then
			Toast.show("The Ledger", tostring(r.why), 3)
		end
	end, 300)
	leatherKey.LayoutOrder = 1
	Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 300).LayoutOrder = 2

	local function show(v: { [string]: any })
		title.Text = "The Ledger · " .. tostring(v.term or "")
		pageText.Text = string.format("Page %d", v.page or 0)
		of.Text = Theme.track(string.upper(string.format("of %d", v.pages or 50)))
		fill.Size = UDim2.fromScale(math.clamp(v.progress or 0, 0, 1), 1)
		nextFree.Text = "Page " .. tostring(v.nextPage) .. ": " .. table.concat(v.nextFree or {}, ", ")
		if v.leather then
			nextLeather.Text = "Leather-Bound: " .. table.concat(v.nextLeather or {}, ", ")
			leatherKey.Visible = false
		else
			nextLeather.Text = "The Leather-Bound row adds two pieces a page."
			leatherKey.Visible = true
		end
	end
	local function reload()
		task.spawn(function()
			local v = Closet.ask({ op = "ledger" })
			if type(v) == "table" and v.page ~= nil and content.Parent then
				show(v)
			end
		end)
	end
	local conn = Closet.Changed:Connect(reload)
	Root.open(NAME, group, function()
		conn:Disconnect()
	end)
	reload()
end

return LedgerPanel
