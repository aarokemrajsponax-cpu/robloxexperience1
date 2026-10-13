--!strict
-- The Evening Calendar (shared/Evenings): seven evenings in a row of glass, each with its present
-- drawn and named exactly as it is, the ones opened ticked off, today's lit and waiting to be
-- opened. Come any day for the next one; a missed day loses nothing, and the calendar says so. The
-- server decides every present and whether today's is open (server/Calendar); this only shows it.
--
-- CalendarPanel.open() from the Menu; CalendarPanel.offer() when a guest arrives: it opens by
-- itself only if today's present is waiting and nothing else is on the screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Evenings = require(ReplicatedStorage.Shared.Evenings)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Icons = require(script.Parent.Icons)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Sound = require(script.Parent.Parent.Sound)

local CalendarPanel = {}

local NAME = "Calendar"
local C = Brand.Colours
local rgb = Color3.fromRGB

-- Set by Main: whether the guest is busy (at a table, on the tour) so the calendar waits.
CalendarPanel.isBusy = function(): boolean
	return false
end

type State = { ok: boolean?, why: string?, step: number, weeks: number, total: number, ready: boolean, nextIn: number, opened: number?, gilt: number?, gems: number?, xp: number?, curio: string? }

local function ask(request: { [string]: any }): State?
	local ok, r = pcall(function()
		return Remotes.func("CalendarAsk"):InvokeServer(request)
	end)
	if ok and type(r) == "table" and type(r.step) == "number" then
		return r :: any
	end
	return nil
end

-- "5h 12m", "38m", "under a minute".
local function until_(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h, m = s // 3600, (s % 3600) // 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm", m)
	end
	return "under a minute"
end

-- The drawn icon and the short words for a present (its biggest part first).
local function face(p: Evenings.Present, seventh: boolean): (string, string, string?)
	if seventh then
		-- (The best of them: its whole present is said in full under the row.)
		return "crown", "THE BEST", if p.curio then "+ A CURIO" else "+ " .. tostring(p.gems) .. " GEMS"
	elseif p.gems > 0 then
		return "gems", tostring(p.gems) .. " GEMS", nil
	elseif p.gilt > 0 then
		return "gilt", tostring(p.gilt), if p.xp > 0 then "+" .. tostring(p.xp) .. " XP" else "GILT"
	end
	return "spark", tostring(p.xp) .. " XP", nil
end

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

-- One evening's tile: "state" is "opened", "today" or "later".
local function tile(parent: Instance, step: number, p: Evenings.Present, state: string, w: number): Frame
	local seventh = step == 7
	local f = Instance.new("Frame")
	f.Name = "Evening" .. step
	f.Size = UDim2.fromOffset(w, 112)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = if state == "later" then 0.08 else 0
	f.BorderSizePixel = 0
	f.LayoutOrder = step
	f:SetAttribute("State", state)
	corner(f, 12)
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = if state == "today"
		then ColorSequence.new(rgb(58, 46, 22), rgb(16, 14, 12))
		elseif seventh then ColorSequence.new(rgb(40, 32, 56), rgb(12, 11, 18))
		else ColorSequence.new(rgb(28, 28, 34), rgb(11, 11, 14))
	fill.Parent = f
	local edge = Instance.new("UIStroke")
	edge.Color = if state == "today" then C.brightGold elseif seventh then rgb(170, 150, 255) else rgb(120, 112, 100)
	edge.Thickness = if state == "today" then 2 else 1
	edge.Transparency = if state == "later" then 0.55 else 0.15
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = f
	local day = Theme.text(f, if state == "today" then "Tonight" else "Evening " .. step, 11, "caps", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = if state == "today" then C.brightGold elseif state == "opened" then rgb(150, 146, 138) else rgb(196, 190, 180),
	})
	day.Name = "Day"
	local icon, big, small = face(p, seventh)
	local holder = Instance.new("Frame")
	holder.Name = "IconBox"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 28)
	holder.Size = UDim2.fromOffset(34, 34)
	holder.Parent = f
	Icons.draw(holder, icon, if state == "opened" then rgb(140, 136, 128) elseif seventh then rgb(190, 170, 255) else C.brightGold, 30)
	local amount = Theme.text(f, big, 14, "body", {
		Position = UDim2.fromOffset(2, 66),
		Size = UDim2.new(1, -4, 0, 18),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = if state == "opened" then rgb(150, 146, 138) else Color3.new(1, 1, 1),
		FontFace = Brand.Fonts.bodyBold,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	amount.Name = "Amount"
	if small then
		local more = Theme.text(f, small, 11, "body", {
			Position = UDim2.fromOffset(2, 86),
			Size = UDim2.new(1, -4, 0, 16),
			AutomaticSize = Enum.AutomaticSize.None,
			TextColor3 = rgb(176, 170, 160),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		more.Name = "More"
	end
	if state == "opened" then
		-- (Opened: ticked off in gold.)
		local tick = Theme.text(f, "✓", 18, "body", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, -2),
			Size = UDim2.fromOffset(20, 20),
			AutomaticSize = Enum.AutomaticSize.None,
			TextColor3 = C.gold,
			FontFace = Brand.Fonts.bodyBold,
		})
		tick.Name = "Tick"
	elseif state == "today" then
		-- (Tonight's breathes, gently, until it's opened.)
		TweenService:Create(edge, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.6 }):Play()
	end
	f.Parent = parent
	return f
end

local function draw(s: State)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local w = Root.panelWidth(660)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 470))
	local list = Theme.list(content, 10)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Evening Calendar", 11, "caps", { LayoutOrder = 1 })
	local headline = if s.ready then (if s.step == 6 then "The seventh evening: the best of them" else "Tonight's present is waiting") else "Tonight's present is open"
	Theme.text(content, headline, 24, "display", { LayoutOrder = 2 })
	local total = Evenings.weekTotal(s.weeks)
	Theme.text(content, string.format("A present every day you come: open the next one, any day. Miss a day and nothing is lost. This week: %s Gilt, %d Gems and %d XP in all.", tostring(total.gilt), total.gems, total.xp), 14, "body", {
		LayoutOrder = 3,
		TextColor3 = rgb(206, 200, 190),
	})
	-- The seven evenings: one row where they fit, else four over three.
	local inner = w - 48
	local perRow = if inner >= 7 * 74 + 6 * 8 then 7 else 4
	local tileW = math.floor((inner - (perRow - 1) * 8) / perRow)
	local row = Instance.new("Frame")
	row.Name = "Evenings"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, if perRow == 7 then 112 else 112 * 2 + 8)
	row.LayoutOrder = 4
	row.Parent = content
	row:SetAttribute("Row", true)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(tileW, 112)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = row
	for step = 1, 7 do
		local state = if step <= s.step then "opened" elseif step == s.step + 1 and s.ready then "today" else "later"
		tile(row, step, Evenings.present(step, s.weeks), state, tileW)
	end
	-- The seventh's present, said in full.
	local best = Evenings.present(7, s.weeks)
	Theme.text(content, "The seventh evening: " .. Evenings.words(best) .. (if best.curio then " (The Seventh Evening, a key to the house)" else "") .. ".", 13, "body", {
		LayoutOrder = 5,
		TextColor3 = rgb(196, 184, 255),
	}).Name = "Seventh"
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 7
	keys.Parent = content
	local kl = Theme.list(keys, 10, true)
	kl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	if s.ready then
		local present = Evenings.present(s.step + 1, s.weeks)
		local busy = false
		Theme.key(keys, "Open tonight's present", true, function()
			if busy then
				return
			end
			busy = true
			local r = ask({ op = "open" })
			if not r or r.ok ~= true then
				busy = false
				Toast.show("The Evening Calendar", if r and r.why then r.why else "One moment: try again.", 3)
				if r then
					draw(r)
				end
				return
			end
			Sound.shimmer()
			pcall(Sound.play, "coinDrop", 0.8)
			Toast.show("The Evening Calendar", "Evening " .. tostring(r.opened) .. ": " .. Evenings.words(present) .. ".", 4)
			draw(r)
		end, math.min(300, inner)).LayoutOrder = 1
	else
		Theme.text(content, "The next evening's present is ready in " .. until_(s.nextIn) .. " (midnight, UTC).", 14, "body", {
			LayoutOrder = 6,
			TextColor3 = C.lightGold,
		})
	end
	Theme.key(keys, if s.ready then "Later" else "Close", false, function()
		Root.close(NAME)
	end, 160).LayoutOrder = 2
	Theme.fitHeight(group, content)
	Root.open(NAME, group)
end

function CalendarPanel.open()
	if Root.isOpen(NAME) then
		Root.close(NAME)
		return
	end
	local s = ask({ op = "state" })
	if not s then
		Toast.show("The Evening Calendar", "One moment: try again.", 3)
		return
	end
	draw(s)
end

-- On arrival: open by itself only if tonight's present is waiting and nothing else is up.
function CalendarPanel.offer()
	if Root.isOpen() or CalendarPanel.isBusy() then
		return
	end
	local s = ask({ op = "state" })
	if s and s.ready and not Root.isOpen() and not CalendarPanel.isBusy() then
		draw(s)
	end
end

return CalendarPanel
