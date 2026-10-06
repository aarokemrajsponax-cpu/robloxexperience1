--!strict
-- Fading a whole panel in and out without a CanvasGroup. A CanvasGroup draws its contents into a
-- texture first, which softens text (worse on big panels, a scaled screen, or a phone): every
-- panel in the house is a plain Frame instead, so its type is drawn crisp, straight to the
-- screen. A fade here eases every part of the panel together: each piece's own transparency
-- (its background, text, image, outline) is kept, and moved toward fully clear by `alpha`.
-- Anything added to a panel while it's faded comes in at the same fade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ease = require(ReplicatedStorage.Shared.Ease)

local Fade = {}

type Base = { [string]: number }
type State = { alpha: number, bases: { [Instance]: Base }, value: NumberValue, conn: RBXScriptConnection? }

local states: { [Instance]: State } = setmetatable({}, { __mode = "k" }) :: any

local function propsOf(d: Instance): { string }
	if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
		return { "BackgroundTransparency", "TextTransparency" }
	elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
		return { "BackgroundTransparency", "ImageTransparency" }
	elseif d:IsA("ViewportFrame") then
		return { "BackgroundTransparency", "ImageTransparency" }
	elseif d:IsA("ScrollingFrame") then
		return { "BackgroundTransparency", "ScrollBarImageTransparency" }
	elseif d:IsA("GuiObject") then
		return { "BackgroundTransparency" }
	elseif d:IsA("UIStroke") then
		return { "Transparency" }
	end
	return {}
end

local function capture(st: State, d: Instance)
	local props = propsOf(d)
	if #props == 0 then
		return
	end
	local base: Base = {}
	for _, p in props do
		local ok, v = pcall(function()
			return (d :: any)[p]
		end)
		if ok and type(v) == "number" then
			base[p] = v
		end
	end
	st.bases[d] = base
end

local function apply(root: Instance, st: State)
	local a = st.alpha
	for d, base in st.bases do
		if d.Parent == nil and d ~= root then
			st.bases[d] = nil
			continue
		end
		for p, b in base do
			pcall(function()
				(d :: any)[p] = b + (1 - b) * a
			end)
		end
	end
end

local function stateOf(root: Instance): State
	local st = states[root]
	if st then
		return st
	end
	local value = Instance.new("NumberValue")
	value.Name = "Fade"
	value.Value = 0
	local s: State = { alpha = 0, bases = {}, value = value, conn = nil }
	states[root] = s
	value.Changed:Connect(function(v: number)
		s.alpha = v
		apply(root, s)
	end)
	-- Pieces added while the panel is faded come in faded too.
	s.conn = root.DescendantAdded:Connect(function(d: Instance)
		if s.alpha > 0 then
			capture(s, d)
			local base: Base = s.bases[d] or {}
			for p, b in base do
				pcall(function()
					(d :: any)[p] = b + (1 - b) * s.alpha
				end)
			end
		end
	end)
	return s
end

-- Takes the panel's current look as the look it fades from (only when it's showing in full).
local function captureAll(root: Instance, st: State)
	if st.alpha > 0 then
		return
	end
	st.bases = {}
	capture(st, root)
	for _, d in root:GetDescendants() do
		capture(st, d)
	end
end

-- How faded a panel is now (0: in full, 1: gone).
function Fade.alpha(root: Instance): number
	local st = states[root]
	return if st then st.alpha else 0
end

-- Sets a panel's fade at once.
function Fade.set(root: Instance, alpha: number)
	local st = stateOf(root)
	captureAll(root, st)
	st.value.Value = alpha
	st.alpha = alpha
	apply(root, st)
end

-- Eases a panel's fade to `alpha`, and any other properties of the panel itself (its Position)
-- with the same timing. Returns the tween of the fade (its Completed says when it's done).
function Fade.to(root: Instance, info: TweenInfo, alpha: number, also: { [string]: any }?): Tween
	local st = stateOf(root)
	captureAll(root, st)
	local t = Ease.play(st.value, info, { Value = alpha })
	t.Completed:Once(function()
		-- (Lands exactly, even if a frame was skipped.)
		st.alpha = alpha
		apply(root, st)
	end)
	if also then
		Ease.play(root, info, also)
	end
	return t
end

return Fade
