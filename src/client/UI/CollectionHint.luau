--!strict
-- The guiding hand at the Collection key (Build 87). The ringed, gloved hand (UI/GuideHand) points
-- at the gold Collection key on the left, with a word on what's in it, for a guest new to the house,
-- once: after the Concierge's tour (it points there on the tour's Collection card too), or a couple
-- of minutes in for a guest who didn't take it. It's noted as done in the guest's record (the
-- server's one-time "guide" notes, hint_collection) only once they open the Collection or press
-- Got it, so a guest who never saw it through is shown it again next evening; after that, never.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Voice = require(ReplicatedStorage.Shared.Voice)
local GuideHand = require(script.Parent.GuideHand)
local QuickDock = require(script.Parent.QuickDock)
local Root = require(script.Parent.Root)

local CollectionHint = {}

local WHAT = "hint_collection"

-- Set by Main: whether the screen is busy (the tour, a table, the welcome).
CollectionHint.isBusy = function(): boolean
	return false
end

local done = false
local asking = false

local function note()
	if done then
		return
	end
	done = true
	task.spawn(function()
		pcall(function()
			Remotes.func("AttractionAsk"):InvokeServer({ op = "guide", what = WHAT })
		end)
	end)
end

-- Whether the hand is at the Collection key now.
function CollectionHint.showing(): boolean
	return GuideHand.active() and GuideHand.target() ~= nil and GuideHand.target() == QuickDock.collectionTarget()
end

-- The hand at the Collection key now (the tour's card asks for it). False if the key isn't there.
function CollectionHint.point(): boolean
	local target = QuickDock.collectionTarget()
	if not target then
		return false
	end
	local V = Voice.GuideHand.collection
	GuideHand.point(target, V.title, V.line, note)
	return true
end

function CollectionHint.clear()
	if CollectionHint.showing() then
		GuideHand.clear()
	end
end

-- The guest opened their Collection (the key, or C): if the hand was pointing there, that's it done.
function CollectionHint.opened()
	if CollectionHint.showing() then
		GuideHand.done()
	end
end

-- Once, for a guest new to the house, if it isn't done yet: the server says (without noting it),
-- then the hand waits for a clear screen (a minute at most).
function CollectionHint.offer()
	if done or asking then
		return
	end
	asking = true
	task.spawn(function()
		local ok, r = pcall(function()
			return Remotes.func("AttractionAsk"):InvokeServer({ op = "guide", what = WHAT, peek = true })
		end)
		if not (ok and type(r) == "table" and r.ok == true and r.first == true) then
			asking = false
			return
		end
		for _ = 1, 120 do
			local busy = false
			pcall(function()
				busy = CollectionHint.isBusy()
			end)
			if not busy and not Root.isOpen() and not GuideHand.active() and QuickDock.collectionTarget() ~= nil then
				CollectionHint.point()
				break
			end
			task.wait(0.5)
		end
		asking = false
	end)
end

return CollectionHint
