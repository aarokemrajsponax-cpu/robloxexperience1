--!strict
-- The guiding hand round the screen (Build 90): the ringed, gloved hand (UI/GuideHand) pointing,
-- one at a time, at what a guest new to the house should know is there: their Fortune, the Play
-- key, their level and, the first time their squad is open, a brainrot's Boost. Each is shown
-- when the screen is clear and its target is really there; it's noted in the guest's record (the
-- server's one-time "guide" notes, shared/Directory Hints) only once they press it or Got it, so
-- one they never saw through comes back next evening, and after that never. Replay (the Menu's
-- "Show me round") points at each again without noting anything.
--
--   HandHints.add(hint)        one more, in order (Main adds them, with where each points)
--   HandHints.offer(ids?)      the unseen ones (or just `ids`), one after another
--   HandHints.replay()         all of them again, now

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuideHand = require(script.Parent.GuideHand)
local Root = require(script.Parent.Root)

local HandHints = {}

export type Hint = { id: string, title: string, line: string, target: () -> GuiObject?, ready: (() -> boolean)? }

local hints: { Hint } = {}
local noted: { [string]: boolean } = {}
local running = false
-- (How long between one hint done and the next: none crowds the last.)
HandHints.GAP = 20
HandHints.WAIT = 120 -- seconds a hint waits for a clear screen before it's left for another time

-- Set by Main: whether the screen is busy (the tour, a table, the welcome).
HandHints.isBusy = function(): boolean
	return false
end

function HandHints.add(h: Hint)
	table.insert(hints, h)
end

function HandHints.list(): { Hint }
	return hints
end

local function note(id: string)
	if noted[id] then
		return
	end
	noted[id] = true
	task.spawn(function()
		pcall(function()
			Remotes.func("AttractionAsk"):InvokeServer({ op = "guide", what = id })
		end)
	end)
end

local function first(id: string): boolean
	if noted[id] then
		return false
	end
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer({ op = "guide", what = id, peek = true })
	end)
	if not (ok and type(r) == "table" and r.ok == true) then
		return false
	end
	if r.first ~= true then
		noted[id] = true
		return false
	end
	return true
end

-- Points at one hint when the screen's clear and its target is there. Whether it was shown.
local function show(h: Hint, keep: boolean): boolean
	for _ = 1, HandHints.WAIT * 2 do
		local busy = false
		pcall(function()
			busy = HandHints.isBusy()
		end)
		local target: GuiObject? = nil
		pcall(function()
			target = h.target()
		end)
		local ready = true
		if h.ready then
			pcall(function()
				ready = (h.ready :: () -> boolean)()
			end)
		end
		if not busy and not GuideHand.active() and target ~= nil and target.Parent ~= nil and ready and (h.ready ~= nil or not Root.isOpen()) then
			GuideHand.point(target :: GuiObject, h.title, h.line, if keep then function()
				note(h.id)
			end else nil)
			return true
		end
		task.wait(0.5)
	end
	return false
end

local function run(list: { Hint }, keep: boolean)
	if running then
		return
	end
	running = true
	task.spawn(function()
		for _, h in list do
			if not keep or first(h.id) then
				if show(h, keep) then
					while GuideHand.active() do
						task.wait(0.5)
					end
					task.wait(HandHints.GAP)
				end
			end
		end
		running = false
	end)
end

-- The hints not yet seen through (all, or just those named), one after another.
function HandHints.offer(ids: { string }?)
	local list: { Hint } = {}
	for _, h in hints do
		if not ids or table.find(ids, h.id) then
			table.insert(list, h)
		end
	end
	run(list, true)
end

-- Every hint again, now (nothing noted: the Menu's "Show me round").
function HandHints.replay()
	local list: { Hint } = {}
	for _, h in hints do
		if h.ready == nil then
			table.insert(list, h)
		end
	end
	run(list, false)
end

function HandHints.running(): boolean
	return running
end

return HandHints
