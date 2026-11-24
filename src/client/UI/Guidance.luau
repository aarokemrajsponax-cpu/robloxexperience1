--!strict
-- (Build 102) The house's quiet guide: one next step at a time, pointed at with the gold hand
-- (UI/GuideHand) and a sentence, for a guest still finding their way: where the first Gilt is,
-- your private Suite, the Boutique, your collection. Each is shown once, ever (remembered with the
-- guest's settings, so never again on another visit), goes at "Got it", at a press of what it
-- points at, or by itself after a few seconds, and never while anything else is going on (a panel,
-- the tour, an attraction, the elevator, a loading screen). Several minutes between two. A guest
-- who's long past all this (a higher level) never sees them.

local Players = game:GetService("Players")

local State = require(script.Parent.Parent.State)
local GuideHand = require(script.Parent.GuideHand)
local Root = require(script.Parent.Root)

local Guidance = {}

export type Step = { id: string, title: string, line: string, gilt: number? }

Guidance.STEPS = {
	{ id = "play", title = "Your first Gilt", line = "Press Play and pick Steal a Luxe: lift treasure, bank it at the getaway car, and see its exact Gilt first." },
	{ id = "suites", title = "Your private Suite", line = "Only you can go in. The elevator takes you up; friends come only when you let them." },
	{ id = "shop", title = "Spend your Gilt", line = "The Boutique: brainrots, boosters and nameplates, every price shown before you buy.", gilt = 300 },
	{ id = "collection", title = "Your collection", line = "Every brainrot and curio you own, your Gems and your trades." },
} :: { Step }

-- Set by Main: where each step points (nil while it isn't on screen), and whether anything else
-- has the guest's attention now.
Guidance.targets = {} :: { [string]: () -> GuiObject? }
Guidance.busy = function(): boolean
	return false
end

local FIRST = 40 -- seconds into play before the first (after the House Tour hand has had its turn)
local GAP = 240 -- seconds at least between two
local SHOW = 14 -- seconds one stays if nothing is pressed
local MAX_LEVEL = 8 -- past this level, no pointers

local player = Players.LocalPlayer
local playingSince: number? = nil
local lastAt = -math.huge
local showing: string? = nil

local function step(): number
	local v = tonumber(State.get("guideStep")) or 0
	return math.clamp(math.floor(v), 0, #Guidance.STEPS)
end

local function advance(id: string)
	local i = step()
	local s = Guidance.STEPS[i + 1]
	if s and s.id == id then
		State.set("guideStep", i + 1)
	end
	if showing == id then
		showing = nil
	end
end

-- Whether this guest is new enough to be guided.
function Guidance.wanted(): boolean
	local level = tonumber(player:GetAttribute("Level")) or 1
	return level <= MAX_LEVEL and step() < #Guidance.STEPS
end

-- Shows the next step if now is a good moment. Returns its id if it did.
function Guidance.check(now: number?): string?
	local t = now or os.clock()
	if State.phase ~= "play" then
		playingSince = nil
		return nil
	end
	playingSince = playingSince or t
	if showing or not Guidance.wanted() then
		return nil
	end
	if t - (playingSince :: number) < FIRST or t - lastAt < GAP then
		return nil
	end
	if GuideHand.active() or Root.isOpen() or Guidance.busy() or type(player:GetAttribute("Attraction")) == "string" then
		return nil
	end
	local s = Guidance.STEPS[step() + 1]
	if not s then
		return nil
	end
	if s.gilt then
		local gilt = tonumber(player:GetAttribute("Gilt")) or (State.guest and tonumber((State.guest :: any).gilt)) or 0
		if gilt < s.gilt then
			return nil
		end
	end
	local find = Guidance.targets[s.id]
	local target = find and find()
	if not target then
		return nil
	end
	showing = s.id
	lastAt = t
	local id = s.id
	GuideHand.point(target, s.title, s.line, function()
		advance(id)
	end)
	task.delay(SHOW, function()
		if showing == id and GuideHand.target() == target then
			GuideHand.clear()
			advance(id)
		end
	end)
	return id
end

-- (Build 102) After an Admin Abuse night, once ever, for a newcomer who may have come only for it:
-- the rest of the house is here every night, and Play is where to pick from it.
Guidance.EVENT = { title = "The house is open every night", line = "Steal a Luxe, the Basement and the Executive Suite are open all the time. Press Play to pick one." }

function Guidance.afterEvent()
	if (tonumber(State.get("guideEvent")) or 0) >= 1 then
		return
	end
	local level = tonumber(player:GetAttribute("Level")) or 1
	if level > MAX_LEVEL then
		return
	end
	task.spawn(function()
		for _ = 1, 30 do
			local find = Guidance.targets.play
			local target = find and find()
			if target and State.phase == "play" and not GuideHand.active() and not Root.isOpen() and not Guidance.busy() and type(player:GetAttribute("Attraction")) ~= "string" then
				State.set("guideEvent", 1)
				lastAt = os.clock()
				GuideHand.point(target, Guidance.EVENT.title, Guidance.EVENT.line)
				task.delay(SHOW, function()
					if GuideHand.target() == target then
						GuideHand.clear()
					end
				end)
				return
			end
			task.wait(2)
		end
	end)
end

-- For tests: as if play had just begun.
function Guidance.reset()
	playingSince = nil
	lastAt = -math.huge
	showing = nil
end

function Guidance.start()
	task.spawn(function()
		while true do
			task.wait(3)
			pcall(Guidance.check)
		end
	end)
end

return Guidance
