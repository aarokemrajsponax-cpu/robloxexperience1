--!strict
-- The Maison Basement's own screen, shown only while a guest is in it: the stage and its part, the
-- run's clock (from leaving the start, by the server's clock, as the server times it), the best
-- time, the falls, and two keys: Leave, and Skip (one stage on: for a skip held, for Gems at the
-- house's price, or for Robux when it's on sale; a skipped run isn't timed for the boards and the
-- stage skipped pays nothing, and the screen says so before anything is spent).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Plan = require(ReplicatedStorage.Shared.Basement)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local BasementHud = {}

local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local CARD_W = 340
local CARD_H = 92
local SKIP = "BasementSkip"

local card: Frame? = nil
local keys: Frame? = nil
local parts: { [string]: any } = {}
local view: { [string]: any } = {}
local beat: RBXScriptConnection? = nil
local topConn: RBXScriptConnection? = nil

local function serverNow(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end
BasementHud.now = serverNow

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else nil
end

local function label(parent: Instance, name: string, text: string, size: number, font: Font, colour: Color3, y: number, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.Position = UDim2.fromOffset(0, y)
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = text
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function place()
	local c = card
	if not c then
		return
	end
	local y = math.max(Root.topClear("Basement") + 6, 126)
	c.Position = UDim2.new(0.5, 0, 0, y)
	Root.setTop("Basement", y + CARD_H + 4, CARD_W / 2)
	local k = keys
	if k then
		k.Position = UDim2.new(0.5, 0, 1, -(14 + Root.bottomClear()))
	end
end

local function clockText(): string
	local started = tonumber(view.started)
	if not started then
		return "0:00.00"
	end
	return Plan.clock(BasementHud.now() - started)
end

local function draw()
	if not card then
		return
	end
	local stage = tonumber(view.stage) or 1
	parts.zone.Text = string.upper(tostring(view.zone or Plan.Zones[Plan.zoneOf(stage)].name))
	parts.stage.Text = string.format("Stage %d of %d  ·  %s", stage, Plan.STAGES, tostring(view.stageName or Plan.StageNames[stage]))
	parts.best.Text = if tonumber(view.best) then "BEST " .. Plan.clock(view.best) else "NO BEST YET"
	parts.falls.Text = string.format("FALLS %d", tonumber(view.falls) or 0) .. (if view.assisted then "  ·  SKIPPED: NOT TIMED" else "")
	parts.clock.Text = clockText()
	local skipKey = parts.skipKey :: TextButton?
	if skipKey then
		local heldNow = tonumber(view.skips) or 0
		skipKey.Text = if heldNow > 0 then string.format("Skip (%d held)", heldNow) else "Skip a stage"
	end
end

local function closeSkip()
	if Root.isOpen(SKIP) then
		Root.close(SKIP)
	end
end

-- The choice before a skip: what it does and what it costs, before anything is spent.
function BasementHud.offerSkip()
	if Root.isOpen(SKIP) then
		return
	end
	local w = Root.panelWidth(420)
	local group, content = Theme.glass(Root.panels, SKIP, UDim2.fromOffset(w, 300))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Maison Basement", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "Skip a stage", 24, "display", { LayoutOrder = 2 })
	Theme.text(content, "On to the next checkpoint. A skipped run isn't timed for the boards, and the stage you skip pays nothing. The Treasury itself can't be skipped to.", 13, "body", { LayoutOrder = 3, TextColor3 = C.smoke })
	-- This stage's price, plainly, before anything is spent: it rises with every stage.
	local stage = tonumber(view.stage) or 1
	local gems = tonumber(view.skipGems) or Plan.skipGems(stage)
	local need = tonumber(view.skipNeed) or Plan.skipsNeeded(stage)
	local heldNow = tonumber(view.skips) or 0
	local price = string.format("Stage %d: %d Gems", stage, gems)
	if view.skipOnSale or heldNow > 0 then
		price ..= string.format(", or %d skip%s (you hold %d)", need, if need == 1 then "" else "s", heldNow)
	end
	price ..= ". The deeper the stage, the more a skip costs."
	if view.skipOnSale and heldNow < need and need > 1 then
		price ..= string.format(" Each purchase is one skip: %d more for this stage.", need - heldNow)
	end
	Theme.text(content, price, 13, "bodyBold", { LayoutOrder = 4, TextColor3 = C.lightGold })
	local row = Instance.new("Frame")
	row.Name = "Choices"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 46)
	row.LayoutOrder = 5
	row.Parent = content
	Theme.list(row, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function go(request: { [string]: any })
		closeSkip()
		task.spawn(function()
			local r = ask(request)
			if r and r.ok ~= true and type(r.why) == "string" then
				Toast.show("Not yet", r.why, 3)
			end
		end)
	end
	local enough = heldNow >= need
	if enough then
		Theme.key(row, if need == 1 then "Use 1 skip" else string.format("Use %d skips", need), true, function()
			go({ op = "act", id = "basement", act = "skip" })
		end, 150)
	end
	Theme.key(row, string.format("%d Gems", gems), not enough, function()
		go({ op = "act", id = "basement", act = "skip", what = "gems" })
	end, 130)
	if not enough and view.skipOnSale then
		Theme.key(row, "Buy a skip", false, function()
			go({ op = "act", id = "basement", act = "skip" })
		end, 130)
	end
	local cancel = Theme.key(content, "Cancel", false, closeSkip, 160)
	cancel.LayoutOrder = 10
	Root.open(SKIP, group)
end

function BasementHud.mounted(): boolean
	return card ~= nil
end

function BasementHud.mount()
	if card then
		return
	end
	local c = Instance.new("Frame")
	c.Name = "BasementCard"
	c.AnchorPoint = Vector2.new(0.5, 0)
	c.Size = UDim2.fromOffset(CARD_W, CARD_H)
	c.BackgroundColor3 = Color3.fromRGB(14, 12, 16)
	c.BackgroundTransparency = 0.08
	c.Parent = Root.hud
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = c
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = GOLD
	edge.Thickness = 1.25
	edge.Transparency = 0.3
	edge.Parent = c
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 8)
	pad.Parent = c
	label(c, "Title", "THE MAISON BASEMENT", 11, Brand.Fonts.bodyBold, GOLD, 0)
	parts.zone = label(c, "Zone", "THE WINE CELLAR", 11, Brand.Fonts.bodyBold, C.bone, 0, Enum.TextXAlignment.Right)
	parts.stage = label(c, "Stage", "", 14, Brand.Fonts.bodyBold, C.bone, 20)
	parts.clock = label(c, "Clock", "0:00.00", 22, Brand.Fonts.figures, Color3.new(1, 1, 1), 42)
	parts.best = label(c, "Best", "", 11, Brand.Fonts.bodyBold, GOLD, 46, Enum.TextXAlignment.Right)
	parts.falls = label(c, "Falls", "", 10, Brand.Fonts.bodyBold, C.smoke, 62, Enum.TextXAlignment.Right)
	card = c

	local k = Instance.new("Frame")
	k.Name = "BasementKeys"
	k.AnchorPoint = Vector2.new(0.5, 1)
	k.BackgroundTransparency = 1
	k.Size = UDim2.fromOffset(320, 44)
	k.Parent = Root.hud
	Theme.list(k, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(k, "Leave", false, function()
		task.spawn(function()
			local r = ask({ op = "home" })
			if r and r.ok ~= true and type(r.why) == "string" then
				Toast.show("Not just now", r.why, 3)
			end
		end)
	end, 130)
	parts.skipKey = Theme.key(k, "Skip a stage", true, function()
		BasementHud.offerSkip()
	end, 160)
	keys = k
	place()
	draw()
	topConn = Root.TopChanged:Connect(place)
	beat = RunService.Heartbeat:Connect(function()
		local clock = parts.clock :: TextLabel?
		if clock then
			clock.Text = clockText()
		end
	end)
end

function BasementHud.unmount()
	if beat then
		beat:Disconnect()
		beat = nil
	end
	if topConn then
		topConn:Disconnect()
		topConn = nil
	end
	if card then
		card:Destroy()
		card = nil
	end
	if keys then
		keys:Destroy()
		keys = nil
	end
	closeSkip()
	parts = {}
	view = {}
	Root.setTop("Basement", nil)
end

local FELL = {
	fall = "You fell.",
	steam = "The steam caught you.",
	laser = "A laser caught you.",
	valve = "The valve's bar swept you off.",
}

function BasementHud.on(m: { [string]: any })
	local op = m.op
	if op == "basement" then
		view = m
		draw()
	elseif op == "checkpoint" then
		local n = tonumber(m.n) or 0
		local purse = tonumber(m.purse) or 0
		if purse > 0 then
			Toast.show(tostring(m.zone) .. ", done", string.format("%s to your Estate  ·  checkpoint %d", Rules.format(purse), n), 4)
		elseif n < Plan.STAGES then
			Toast.show(string.format("Checkpoint %d", n), if m.skipped then "Skipped to: this stage pays nothing." elseif (tonumber(m.gilt) or 0) > 0 then string.format("+%s Gilt", Rules.format(m.gilt)) else "Reached.", 2)
		end
	elseif op == "fell" then
		Toast.show(string.format("Back to checkpoint %d", tonumber(m.checkpoint) or 0), FELL[tostring(m.why)] or "Back you go.", 2)
	elseif op == "treasury" then
		local title = "The Treasury"
		local line: string
		if m.timed and tonumber(m.seconds) then
			title = "The Treasury  ·  " .. Plan.clock(m.seconds)
			line = if m.record then "A new best time." elseif m.weekRecord then "Your best this week." else "Best: " .. Plan.clock(tonumber(m.best) or m.seconds)
		else
			line = "A skipped run isn't timed for the boards."
		end
		if (tonumber(m.gems) or 0) > 0 then
			line ..= string.format("  ·  %d Gems from the chest", m.gems)
		end
		if m.brainrot then
			line ..= "  ·  Topo Tesoriere for your collection"
		end
		Toast.show(title, line, 6)
	end
end

return BasementHud
