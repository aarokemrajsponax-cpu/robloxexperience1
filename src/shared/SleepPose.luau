--!strict
-- How Steal a Luxe's night staff look (Build 89), shared by the server (which builds what they
-- sleep on, at these heights) and every screen (which poses them). Every pose is a turn of each
-- of the R15 rig's joints, in degrees (x: forward and back, y: twist, z: side to side), and how far
-- the whole body is let down onto what it sits or lies on (a named drop the screen measures from
-- the rig itself: its thighs, its hips, its torso), tipped back (pitch) and rolled.
--
--   asleep     each in their own way: slumped in an armchair, head on the arms at a desk, sprawled
--              on a sofa, tipped back on a stool against the wall, on their back in bed. Breathing.
--   stirring   the same, restless: the head turning, an arm shifting, the sleeper in bed turning.
--   waking     sitting up, a stretch with both arms, then up on their feet (in bed: sitting up).
--   awake      standing (in bed: sitting up), looking round; calling for the guards with one arm
--              raised, ringing.
--   dozing     back down again, slowly.
--
-- Nothing here decides anything: the server says the state and when it began (attributes), and
-- every screen draws the same thing from it.

local SleepPose = {}

-- What each pose sits on: the seat's top, in studs above the floor (the server builds it there).
SleepPose.SEAT = { chair = 1.05, desk = 1.05, stool = 1.7, slump = 0.9 } :: { [string]: number }
SleepPose.BED_TOP = 2.2 -- the mattress's top

SleepPose.JOINTS = { "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftHip", "RightHip", "LeftKnee", "RightKnee" }

export type Pose = { j: { [string]: Vector3 }, drop: string?, pitch: number, roll: number, dropValue: number? }
-- The drops, in studs, measured from the rig (UI/World/LuxeSleepers): one for each seat, the bed
-- lying down and the bed sitting up.
export type Drops = { [string]: number }

local function v(x: number, y: number?, z: number?): Vector3
	return Vector3.new(x, y or 0, z or 0)
end

local function with(base: { [string]: Vector3 }, extra: { [string]: Vector3 }): { [string]: Vector3 }
	local out = table.clone(base)
	for k, val in extra do
		out[k] = val
	end
	return out
end

local SIT = { LeftHip = v(90), RightHip = v(90), LeftKnee = v(-90), RightKnee = v(-90) }
local LEGS_OUT = { LeftHip = v(90), RightHip = v(90), LeftKnee = v(0), RightKnee = v(0) }

local ASLEEP: { [string]: Pose } = {
	-- Slumped back in an armchair, chin on the chest, hands in the lap.
	chair = { drop = "chair", pitch = 0, roll = 0, j = with(SIT, { Waist = v(10), Neck = v(-28, 0, 12), LeftShoulder = v(30, 0, 4), RightShoulder = v(30, 0, -4), LeftElbow = v(60), RightElbow = v(60) }) },
	-- Tipped back on a stool against the wall, head back, arms hanging.
	stool = { drop = "stool", pitch = 0, roll = 0, j = with(SIT, { Waist = v(14), Neck = v(24, 0, -6), LeftShoulder = v(8, 0, -10), RightShoulder = v(8, 0, 10), LeftElbow = v(20), RightElbow = v(20) }) },
	-- Forward onto the desk, arms folded on it, head on its side on them.
	desk = { drop = "desk", pitch = 0, roll = 0, j = with(SIT, { Waist = v(-42), Neck = v(-10, 0, -34), LeftShoulder = v(90, 0, 16), RightShoulder = v(90, 0, -16), LeftElbow = v(0, 0, 85), RightElbow = v(0, 0, -85) }) },
	-- Sprawled on a sofa: sunk back, head lolling, one arm flung out.
	slump = { drop = "slump", pitch = 0, roll = 0, j = { Waist = v(24, 0, 12), Neck = v(14, 0, 26), LeftShoulder = v(10, 0, -42), RightShoulder = v(35, 0, -6), LeftElbow = v(10), RightElbow = v(50), LeftHip = v(70), RightHip = v(70), LeftKnee = v(-45), RightKnee = v(-45) } },
	-- On their back in bed, head turned to one side, arms by their sides.
	bed = { drop = "lie", pitch = 90, roll = 0, j = { Neck = v(0, 25, 0), LeftShoulder = v(0, 0, -12), RightShoulder = v(0, 0, 12), LeftElbow = v(15), RightElbow = v(15) } },
}

-- Sitting up and stretching, both arms up (on the way to their feet).
local function stretch(pose: string): Pose
	if pose == "bed" then
		return { drop = "bedSit", pitch = 0, roll = 0, j = with(LEGS_OUT, { Waist = v(-4), Neck = v(16), LeftShoulder = v(165, 0, -10), RightShoulder = v(165, 0, 10), LeftElbow = v(10), RightElbow = v(10) }) }
	end
	return { drop = if pose == "slump" then "slump" else pose, pitch = 0, roll = 0, j = with(SIT, { Waist = v(-4), Neck = v(16), LeftShoulder = v(165, 0, -10), RightShoulder = v(165, 0, 10), LeftElbow = v(10), RightElbow = v(10) }) }
end

-- Up and looking round (in bed: sitting up); calling, one arm raised and ringing.
local function awake(pose: string, t: number, calling: boolean): Pose
	local look = 35 * math.sin(t * 0.8)
	local j: { [string]: Vector3 } = { Neck = v(4, look, 0), Waist = v(0, look * 0.25, 0) }
	if calling then
		j.RightShoulder = v(150, 0, 10 + 10 * math.sin(t * 9))
		j.RightElbow = v(20)
	end
	if pose == "bed" then
		return { drop = "bedSit", pitch = 0, roll = 0, j = with(LEGS_OUT, j) }
	end
	return { drop = nil, pitch = 0, roll = 0, j = j }
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function blend(a: Pose, b: Pose, k: number, drops: Drops): Pose
	local j: { [string]: Vector3 } = {}
	for _, name in SleepPose.JOINTS do
		local x, y = a.j[name], b.j[name]
		if x or y then
			j[name] = (x or Vector3.zero):Lerp(y or Vector3.zero, k)
		end
	end
	-- (Between two drops, a number of studs.)
	local da = SleepPose.dropOf(a, drops)
	local db = SleepPose.dropOf(b, drops)
	return { j = j, drop = nil, pitch = a.pitch + (b.pitch - a.pitch) * k, roll = a.roll + (b.roll - a.roll) * k, dropValue = da + (db - da) * k }
end

-- How far a pose lets the body down, in studs.
function SleepPose.dropOf(p: Pose, drops: Drops): number
	if p.dropValue then
		return p.dropValue
	end
	return if p.drop then drops[p.drop] or 0 else 0
end

-- The pose for a sleeper in `pose`, in `state` for `t` seconds of a state that lasts `lasts`
-- (waking, dozing), stirred `stir` (0 to 1), calling or not, with the rig's own drops.
function SleepPose.pose(pose: string, state: string, t: number, lasts: number, stir: number, calling: boolean, drops: Drops): Pose
	local asleep = ASLEEP[pose] or ASLEEP.chair
	local function sleeping(restless: number): Pose
		local p: Pose = { drop = asleep.drop, pitch = asleep.pitch, roll = asleep.roll, j = table.clone(asleep.j) }
		-- Breathing: the chest rises and falls, the head with it (a slow snore on the stool).
		local breath = math.sin(t * math.pi * 2 / 4.2)
		p.j.Waist = (p.j.Waist or Vector3.zero) + v(1.6 * breath)
		p.j.Neck = (p.j.Neck or Vector3.zero) + v((if pose == "stool" then 3 else 0.8) * breath)
		if restless > 0 then
			p.j.Neck += v(0, 22 * restless * math.sin(t * 1.4), 0)
			p.j.RightShoulder = (p.j.RightShoulder or Vector3.zero) + v(10 * restless * math.sin(t * 0.9))
			if pose == "bed" then
				p.roll = 10 * restless * math.sin(t * 0.7)
			end
		end
		return p
	end
	if state == "asleep" then
		return sleeping(0)
	elseif state == "stirring" then
		return sleeping(math.clamp((stir - 0.3) / 0.7, 0.3, 1))
	elseif state == "waking" then
		local k = if lasts > 0 then t / lasts else 1
		if k < 0.45 then
			return blend(sleeping(0.5), stretch(pose), ease(k / 0.45), drops)
		end
		return blend(stretch(pose), awake(pose, 0, false), ease((k - 0.45) / 0.55), drops)
	elseif state == "dozing" then
		local k = if lasts > 0 then t / lasts else 1
		return blend(awake(pose, 0, false), sleeping(0), ease(k), drops)
	end
	return awake(pose, t, calling)
end

-- A joint's turn as a CFrame (x, then y, then z, in degrees).
function SleepPose.turn(a: Vector3): CFrame
	return CFrame.Angles(math.rad(a.X), math.rad(a.Y), math.rad(a.Z))
end

-- The Root joint's whole move: let down, tipped back and rolled.
function SleepPose.root(p: Pose, drops: Drops): CFrame
	return CFrame.new(0, -SleepPose.dropOf(p, drops), 0) * CFrame.Angles(math.rad(p.pitch), 0, math.rad(p.roll))
end

return SleepPose
