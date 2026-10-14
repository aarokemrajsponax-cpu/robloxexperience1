--!strict
-- The house's icons, drawn: clean lines on a 24-unit grid, scaled to any size, in any colour,
-- flat and solid like a printed mark (Build 65: no neon halo; the "Halo" layer is still made, clear,
-- so anything that tints an icon finds it where it always was). Drawn
-- from frames rather than taken from the emoji font, so they look the same on every screen, sit
-- crisp at any size, and match the house's own glass and gold instead of a phone's cartoon set.
--
-- Icons.draw(parent, name, colour, px) puts one in a px-square frame named "Icon" and returns it
-- (nil for a name it doesn't know: then the caller keeps its glyph). Icons.has(name) asks first.

local Icons = {}

type Painter = {
	line: (x1: number, y1: number, x2: number, y2: number, w: number?) -> (),
	ring: (cx: number, cy: number, r: number, w: number?) -> (),
	box: (x: number, y: number, w: number, h: number, radius: number?, stroke: number?) -> (),
	dot: (cx: number, cy: number, r: number) -> (),
}

local SHAPES: { [string]: (p: Painter) -> () } = {}

-- A cabinet of curios: four little cases, two by two.
SHAPES.collection = function(p)
	p.box(3.5, 3.5, 7.5, 7.5, 2)
	p.box(13, 3.5, 7.5, 7.5, 2)
	p.box(3.5, 13, 7.5, 7.5, 2)
	p.box(13, 13, 7.5, 7.5, 2)
	p.dot(16.75, 16.75, 1.6)
end

-- Two arrows passing each other.
SHAPES.trade = function(p)
	p.line(4, 8, 19.5, 8)
	p.line(15.5, 4, 19.5, 8)
	p.line(15.5, 12, 19.5, 8)
	p.line(4.5, 16, 20, 16)
	p.line(8.5, 12, 4.5, 16)
	p.line(8.5, 20, 4.5, 16)
end

-- A coat hanger.
SHAPES.wardrobe = function(p)
	p.ring(12, 5, 2.2, 1.6)
	p.line(12, 7.2, 12, 9.2)
	p.line(12, 9.2, 2.8, 17.5)
	p.line(12, 9.2, 21.2, 17.5)
	p.line(2.8, 17.5, 21.2, 17.5)
end

-- A cut stone: its table, its crown and the point beneath.
SHAPES.gems = function(p)
	p.line(7, 4.5, 17, 4.5)
	p.line(7, 4.5, 3, 9.5)
	p.line(17, 4.5, 21, 9.5)
	p.line(3, 9.5, 21, 9.5)
	p.line(3, 9.5, 12, 20.5)
	p.line(21, 9.5, 12, 20.5)
	p.line(9.5, 9.5, 12, 20.5, 1.1)
	p.line(14.5, 9.5, 12, 20.5, 1.1)
end

-- A door, just open, its handle lit.
SHAPES.suites = function(p)
	p.box(6, 2.5, 12, 19, 1.5)
	p.line(3, 21.5, 21, 21.5)
	p.dot(15, 12.5, 1.5)
end

-- An envelope.
SHAPES.invite = function(p)
	p.box(2.5, 5.5, 19, 13, 2)
	p.line(3, 6.5, 12, 13.5)
	p.line(21, 6.5, 12, 13.5)
end

-- A burst of fireworks.
SHAPES.watch = function(p)
	for i = 0, 7 do
		local a = i * math.pi / 4
		local r1, r2 = (if i % 2 == 0 then 3.5 else 4.5), (if i % 2 == 0 then 10 else 7.5)
		p.line(12 + math.cos(a) * r1, 12 + math.sin(a) * r1, 12 + math.cos(a) * r2, 12 + math.sin(a) * r2)
	end
	p.dot(12, 12, 1.6)
end

-- A house.
SHAPES.home = function(p)
	p.line(2.5, 12, 12, 3.5)
	p.line(12, 3.5, 21.5, 12)
	p.box(5.5, 11, 13, 10.5, 1)
	p.box(10, 15, 4, 6.5, 0.8)
end

-- A coin: its rim and its raised ring.
SHAPES.gilt = function(p)
	p.ring(12, 12, 9)
	p.ring(12, 12, 5.5, 1.2)
end

-- A medal on its ribbon.
SHAPES.badge = function(p)
	p.line(8, 2.5, 10.5, 9)
	p.line(16, 2.5, 13.5, 9)
	p.ring(12, 15, 6)
	p.dot(12, 15, 2)
end

-- A crown.
SHAPES.crown = function(p)
	p.line(3.5, 19, 20.5, 19)
	p.line(3.5, 19, 3, 7.5)
	p.line(20.5, 19, 21, 7.5)
	p.line(3, 7.5, 8.5, 12.5)
	p.line(8.5, 12.5, 12, 5)
	p.line(12, 5, 15.5, 12.5)
	p.line(15.5, 12.5, 21, 7.5)
end

-- A calendar page, a day ringed.
SHAPES.daily = function(p)
	p.box(3, 4.5, 18, 16.5, 2)
	p.line(3.5, 9.5, 20.5, 9.5)
	p.line(8, 2.5, 8, 6.5)
	p.line(16, 2.5, 16, 6.5)
	p.ring(12, 15, 2.6, 1.4)
end

-- A spark of light.
SHAPES.spark = function(p)
	p.line(12, 2.5, 12, 21.5)
	p.line(2.5, 12, 21.5, 12)
	p.line(6.5, 6.5, 17.5, 17.5, 1.1)
	p.line(17.5, 6.5, 6.5, 17.5, 1.1)
	p.dot(12, 12, 2)
end

-- A lightning bolt.
SHAPES.bolt = function(p)
	p.line(14, 2.5, 6.5, 13)
	p.line(6.5, 13, 12.5, 13)
	p.line(12.5, 13, 9.5, 21.5)
	p.line(9.5, 21.5, 17.5, 10.5)
	p.line(17.5, 10.5, 11.5, 10.5)
	p.line(11.5, 10.5, 14, 2.5)
end

-- A shopping bag, its handles up.
SHAPES.bag = function(p)
	p.box(4, 8, 16, 13.5, 2)
	p.ring(12, 8, 4, 1.5)
	p.line(6, 8, 18, 8)
end

-- An open book.
SHAPES.book = function(p)
	p.line(12, 6, 12, 20)
	p.line(12, 6, 4, 4)
	p.line(4, 4, 4, 18)
	p.line(4, 18, 12, 20)
	p.line(12, 6, 20, 4)
	p.line(20, 4, 20, 18)
	p.line(20, 18, 12, 20)
end

-- A pen's nib, writing.
SHAPES.pen = function(p)
	p.line(18.5, 3.5, 7, 15)
	p.line(20.5, 5.5, 9, 17)
	p.line(18.5, 3.5, 20.5, 5.5)
	p.line(7, 15, 5, 19.5)
	p.line(9, 17, 5, 19.5)
	p.line(3, 21.5, 13, 21.5, 1.2)
end

-- A circle of friends: dots in a ring round one more.
SHAPES.circle = function(p)
	for i = 0, 5 do
		local a = i * math.pi / 3 - math.pi / 2
		p.dot(12 + math.cos(a) * 7.5, 12 + math.sin(a) * 7.5, 1.7)
	end
	p.ring(12, 12, 3, 1.4)
end

-- A question, answered: a ring with the mark of information.
SHAPES.help = function(p)
	p.ring(12, 12, 9)
	p.line(12, 11, 12, 16.5)
	p.dot(12, 7.5, 1.3)
end

-- A gear: a ring with its teeth.
SHAPES.gear = function(p)
	p.ring(12, 12, 6)
	p.ring(12, 12, 2.2, 1.3)
	for i = 0, 7 do
		local a = i * math.pi / 4
		p.line(12 + math.cos(a) * 7.2, 12 + math.sin(a) * 7.2, 12 + math.cos(a) * 9.8, 12 + math.sin(a) * 9.8, 2.2)
	end
end

-- A curve through a bend, drawn as a few short lines (a quadratic Bézier from (x1, y1) to (x2, y2)
-- pulled towards (cx, cy)).
local function curve(p: Painter, x1: number, y1: number, cx: number, cy: number, x2: number, y2: number, w: number?)
	local steps = 6
	local px, py = x1, y1
	for i = 1, steps do
		local t = i / steps
		local a, b, c = (1 - t) * (1 - t), 2 * (1 - t) * t, t * t
		local x, y = a * x1 + b * cx + c * x2, a * y1 + b * cy + c * y2
		p.line(px, py, x, y, w)
		px, py = x, y
	end
end

-- A present: its box and lid, the ribbon down it, a bow of two loops on top.
SHAPES.gift = function(p)
	p.box(4.5, 11, 15, 10.5, 1.5)
	p.box(3, 7.5, 18, 3.5, 1)
	p.line(12, 7.5, 12, 21.5)
	p.line(12, 7.5, 7.5, 3.8)
	p.line(7.5, 3.8, 6.8, 6.6)
	p.line(6.8, 6.6, 12, 7.5)
	p.line(12, 7.5, 16.5, 3.8)
	p.line(16.5, 3.8, 17.2, 6.6)
	p.line(17.2, 6.6, 12, 7.5)
end

-- A world with a ring round it.
SHAPES.planet = function(p)
	p.ring(12, 12, 5.8)
	local rx, ry, tilt = 10.5, 3.4, math.rad(-18)
	local function at(a: number): (number, number)
		local x, y = math.cos(a) * rx, math.sin(a) * ry
		return 12 + x * math.cos(tilt) - y * math.sin(tilt), 12 + x * math.sin(tilt) + y * math.cos(tilt)
	end
	-- (The near half of the ring, in front of the world; the far half hides behind it.)
	local steps = 10
	for i = 0, steps - 1 do
		local a1, a2 = i / steps * math.pi, (i + 1) / steps * math.pi
		local x1, y1 = at(a1)
		local x2, y2 = at(a2)
		p.line(x1, y1, x2, y2, 1.4)
	end
	local fx, fy = at(-0.08)
	local gx, gy = at(-0.62)
	p.line(fx, fy, gx, gy, 1.4)
	local hx, hy = at(math.pi + 0.08)
	local jx, jy = at(math.pi + 0.62)
	p.line(hx, hy, jx, jy, 1.4)
end

-- An eye, open: its lids and its pupil.
SHAPES.eye = function(p)
	curve(p, 2.5, 12, 12, 3, 21.5, 12)
	curve(p, 2.5, 12, 12, 21, 21.5, 12)
	p.ring(12, 12, 3.4, 1.5)
	p.dot(12, 12, 1.3)
end

function Icons.has(name: string?): boolean
	return name ~= nil and SHAPES[name] ~= nil
end

-- Draws icon `name` in a px-square frame named "Icon" under `parent`; nil if it isn't one.
function Icons.draw(parent: Instance, name: string, colour: Color3, px: number, weight: number?): Frame?
	local shape = SHAPES[name]
	if not shape then
		return nil
	end
	local k = px / 24
	-- (A touch bolder since the halo went: the line alone carries the mark, on a phone too.)
	local thick = (weight or 2.1) * k
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(px, px)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder:SetAttribute("Icon", name)
	local core = colour:Lerp(Color3.new(1, 1, 1), 0.12)
	local z = 1
	-- One stroke of light: a soft wide halo of the colour under a bright core.
	local function bar(cx: number, cy: number, len: number, w: number, angle: number)
		for layer = 1, 2 do
			local f = Instance.new("Frame")
			f.Name = if layer == 1 then "Halo" else "Line"
			f.BorderSizePixel = 0
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromOffset(cx * k, cy * k)
			local width = if layer == 1 then w * 2.6 else w
			f.Size = UDim2.fromOffset(len * k + width, width)
			f.Rotation = angle
			f.BackgroundColor3 = if layer == 1 then colour else core
			f.BackgroundTransparency = if layer == 1 then 1 else 0
			f.ZIndex = z + layer
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = f
			f.Parent = holder
		end
	end
	local function outline(x: number, y: number, w: number, h: number, radius: number, stroke: number, round: boolean)
		for layer = 1, 2 do
			local f = Instance.new("Frame")
			f.Name = if layer == 1 then "Halo" else "Line"
			f.BackgroundTransparency = 1
			f.Position = UDim2.fromOffset(x * k, y * k)
			f.Size = UDim2.fromOffset(w * k, h * k)
			f.ZIndex = z + layer
			local c = Instance.new("UICorner")
			c.CornerRadius = if round then UDim.new(1, 0) else UDim.new(0, radius * k)
			c.Parent = f
			local s = Instance.new("UIStroke")
			s.Color = if layer == 1 then colour else core
			s.Thickness = if layer == 1 then stroke * 2.6 else stroke
			s.Transparency = if layer == 1 then 1 else 0
			s.Parent = f
			f.Parent = holder
		end
	end
	-- (A stroke's width in the UI's units: the icon's own weight, or a finer one where a shape asks;
	-- never under two pixels on the screen, however small the UI is drawn, so a phone shows every
	-- line as clearly as a monitor does.)
	local okRoot, R = pcall(function()
		return require(script.Parent.Root)
	end)
	local uiScale = if okRoot and type(R) == "table" and type((R :: any).scale) == "number" then (R :: any).scale else 1
	local least = 2 / math.max(0.5, uiScale)
	local function strokePx(w: number?): number
		return math.max(least, (w or 1.7) / (weight or 1.7) * thick)
	end
	local painter: Painter = {
		line = function(x1: number, y1: number, x2: number, y2: number, w: number?)
			local dx, dy = x2 - x1, y2 - y1
			local len = math.sqrt(dx * dx + dy * dy)
			bar((x1 + x2) / 2, (y1 + y2) / 2, len, strokePx(w), math.deg(math.atan2(dy, dx)))
		end,
		ring = function(cx: number, cy: number, r: number, w: number?)
			outline(cx - r, cy - r, r * 2, r * 2, 0, strokePx(w), true)
		end,
		box = function(x: number, y: number, w: number, h: number, radius: number?, stroke: number?)
			outline(x, y, w, h, radius or 2, strokePx(stroke), false)
		end,
		dot = function(cx: number, cy: number, r: number)
			for layer = 1, 2 do
				local f = Instance.new("Frame")
				f.Name = if layer == 1 then "Halo" else "Line"
				f.BorderSizePixel = 0
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.Position = UDim2.fromOffset(cx * k, cy * k)
				local d = (if layer == 1 then r * 2.6 else r) * 2 * k
				f.Size = UDim2.fromOffset(d, d)
				f.BackgroundColor3 = if layer == 1 then colour else core
				f.BackgroundTransparency = if layer == 1 then 1 else 0
				f.ZIndex = z + layer
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(1, 0)
				c.Parent = f
				f.Parent = holder
			end
		end,
	}
	shape(painter)
	holder.Parent = parent
	return holder
end

-- Sets every line of a drawn icon to a new colour (hover, a state change).
function Icons.tint(icon: Instance, colour: Color3)
	local core = colour:Lerp(Color3.new(1, 1, 1), 0.12)
	for _, f in icon:GetChildren() do
		if f:IsA("Frame") then
			local s = f:FindFirstChildOfClass("UIStroke")
			local c = if f.Name == "Halo" then colour else core
			if s then
				s.Color = c
			else
				f.BackgroundColor3 = c
			end
		end
	end
end

return Icons
