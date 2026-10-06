--!strict
-- Suite spectacles: the shows a guest buys for their own Suite, and plays from the bell. The
-- server spends the show and tells this screen to play it (Purchases/Spectacles); this draws it,
-- only here (a Suite is its owner's alone). Also the small screen listing the three, plainly
-- priced, with how many you hold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Parent.UI.Root)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)
local Sound = require(script.Parent.Parent.Sound)

local SuiteSpectacle = {}

local NAME = "Spectacles"
local C = Brand.Colours
local ROBUX = utf8.char(0xE002)
local GOLD = Color3.fromRGB(255, 210, 120)

local function ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("SpectacleAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

local function folder(): Instance
	local f = Instance.new("Folder")
	f.Name = "SuiteSpectacle"
	f.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	return f
end

local function part(parent: Instance, size: Vector3, at: Vector3, colour: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.Neon
	p.Color = colour
	p.CFrame = CFrame.new(at)
	p.Parent = parent
	return p
end

local function centreOf(box: { minX: number, maxX: number, minZ: number, maxZ: number }): Vector3
	return Vector3.new((box.minX + box.maxX) / 2, Layout.Suite.floorY, (box.minZ + box.maxZ) / 2)
end

-- Fireworks over the Suite's terrace: shells rise and burst into rings of sparks.
local function fireworks(seconds: number)
	local f = folder()
	local base = centreOf(Layout.Suite.terrace)
	local colours = { Color3.fromRGB(255, 90, 120), GOLD, Color3.fromRGB(120, 200, 255), Color3.fromRGB(170, 255, 150), Color3.fromRGB(220, 140, 255) }
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < seconds and f.Parent do
			local c = colours[math.random(1, #colours)]
			local from = base + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
			local top = from + Vector3.new(0, math.random(26, 38), 0)
			local shell = part(f, Vector3.new(0.6, 0.6, 0.6), from, c, Enum.PartType.Ball)
			local rise = 0.9
			local s0 = os.clock()
			while os.clock() - s0 < rise do
				shell.CFrame = CFrame.new(from:Lerp(top, (os.clock() - s0) / rise))
				task.wait()
			end
			shell:Destroy()
			pcall(Sound.play, "shimmer", 0.35)
			local sparks = {}
			for i = 1, 22 do
				local a = i / 22 * math.pi * 2
				local dir = Vector3.new(math.cos(a), math.sin(a * 3) * 0.4, math.sin(a)).Unit
				table.insert(sparks, { p = part(f, Vector3.new(0.4, 0.4, 0.4), top, c, Enum.PartType.Ball), d = dir })
			end
			local b0 = os.clock()
			task.spawn(function()
				while os.clock() - b0 < 1.4 do
					local k = (os.clock() - b0) / 1.4
					for _, sp in sparks do
						sp.p.CFrame = CFrame.new(top + sp.d * 12 * math.sqrt(k) - Vector3.new(0, 4 * k * k, 0))
						sp.p.Transparency = k
					end
					task.wait()
				end
				for _, sp in sparks do
					sp.p:Destroy()
				end
			end)
			task.wait(0.5 + math.random() * 0.6)
		end
		task.wait(1.6)
		f:Destroy()
	end)
end

-- The meme curios burst out and bounce around the drawing room.
local function memes(seconds: number)
	local f = folder()
	local base = centreOf(Layout.Suite.main) + Vector3.new(0, 4, 0)
	local list = {}
	for _, c in Curios.List do
		if c.family == "meme" then
			table.insert(list, c)
		end
	end
	local bodies = {}
	for i = 1, 24 do
		local c = list[(i - 1) % #list + 1]
		local p = part(f, Vector3.new(1, 1, 1), base, Color3.new(1, 1, 1))
		p.Transparency = 1
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(3, 3)
		bb.LightInfluence = 0
		bb.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = c.glyph
		t.TextScaled = true
		t.Parent = bb
		local a = i / 24 * math.pi * 2
		table.insert(bodies, { p = p, v = Vector3.new(math.cos(a) * 10, 14 + (i % 5) * 2, math.sin(a) * 10), at = base })
	end
	pcall(Sound.play, "combo", 0.6)
	local box = Layout.Suite.main
	local floorY = Layout.Suite.floorY + 1.5
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		if os.clock() - t0 > seconds or not f.Parent then
			if conn then
				conn:Disconnect()
			end
			f:Destroy()
			return
		end
		for _, b in bodies do
			b.v -= Vector3.new(0, 30 * dt, 0)
			local n = b.at + b.v * dt
			if n.Y < floorY then
				n = Vector3.new(n.X, floorY, n.Z)
				b.v = Vector3.new(b.v.X, math.abs(b.v.Y) * 0.85 + 4, b.v.Z)
			end
			if n.X < box.minX + 1 or n.X > box.maxX - 1 then
				b.v = Vector3.new(-b.v.X, b.v.Y, b.v.Z)
			end
			if n.Z < box.minZ + 1 or n.Z > box.maxZ - 1 then
				b.v = Vector3.new(b.v.X, b.v.Y, -b.v.Z)
			end
			b.at = n
			b.p.CFrame = CFrame.new(n)
		end
	end)
end

-- The Suite turns gold: every light in the drawn Suite warms to gold, and gold leaf falls.
local function golden(seconds: number)
	local f = folder()
	local suite = (Workspace:FindFirstChild("MaisonLocal") or Workspace):FindFirstChild("Suite")
	local saved: { [Light]: Color3 } = {}
	if suite then
		for _, d in suite:GetDescendants() do
			if d:IsA("Light") then
				saved[d] = d.Color
				d.Color = GOLD
			end
		end
	end
	local emitterPart = part(f, Vector3.new(26, 1, 20), centreOf(Layout.Suite.main) + Vector3.new(0, 11, 0), GOLD)
	emitterPart.Transparency = 1
	local leaf = Instance.new("ParticleEmitter")
	leaf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	leaf.Color = ColorSequence.new(GOLD)
	leaf.LightEmission = 0.8
	leaf.Rate = 60
	leaf.Lifetime = NumberRange.new(4, 6)
	leaf.Speed = NumberRange.new(1, 2)
	leaf.Acceleration = Vector3.new(0, -2, 0)
	leaf.EmissionDirection = Enum.NormalId.Bottom
	leaf.Size = NumberSequence.new(0.35, 0.2)
	leaf.Rotation = NumberRange.new(0, 360)
	leaf.RotSpeed = NumberRange.new(-90, 90)
	leaf.Parent = emitterPart
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Brightness = 2
	glow.Range = 30
	glow.Parent = emitterPart
	pcall(Sound.chime, 8)
	task.delay(seconds, function()
		leaf.Enabled = false
		for l, c in saved do
			if l.Parent then
				l.Color = c
			end
		end
		task.wait(6)
		f:Destroy()
	end)
end

function SuiteSpectacle.play(key: string, seconds: number?)
	local s = seconds or 20
	if key == "spectacleFireworks" then
		fireworks(s)
	elseif key == "spectacleMemes" then
		memes(s)
	elseif key == "spectacleGolden" then
		golden(s)
	end
end

function SuiteSpectacle.open()
	if Root.isOpen(NAME) then
		return
	end
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(math.min(560, Root.size().X - 24), math.min(440, Root.size().Y - 40)))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Spectacles", 24, "display", { LayoutOrder = 1 })
	Theme.text(content, "A show in your own Suite, played when you choose. Each purchase is one show. Only you see it.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke })
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.Size = UDim2.new(1, 0, 0, 0)
	list.LayoutOrder = 3
	list.Parent = content
	Theme.list(list, 8)
	local function fill()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local r = ask({ op = "list" })
		if type(r) ~= "table" or type(r.shows) ~= "table" or not list.Parent then
			return
		end
		for i, sh in r.shows do
			local row = Instance.new("Frame")
			row.BackgroundColor3 = Color3.fromRGB(28, 26, 28)
			row.Size = UDim2.new(1, 0, 0, 64)
			row.LayoutOrder = i
			row.Parent = list
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = row
			local name = Theme.text(row, tostring(sh.name), 16, "bodyMedium", { TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -200, 0, 20), AutomaticSize = Enum.AutomaticSize.None })
			name.TextColor3 = C.bone
			Theme.text(row, tostring(sh.line), 12, "body", { TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -200, 0, 32), AutomaticSize = Enum.AutomaticSize.None, TextColor3 = C.smoke })
			local label = if sh.held > 0 then string.format("Play (%d held)", sh.held) elseif sh.ready then string.format("%s %d", ROBUX, sh.robux) else "Not on sale yet"
			local k = Theme.key(row, label, sh.held > 0 or sh.ready, function()
				task.spawn(function()
					if sh.held > 0 then
						local res = ask({ op = "play", key = sh.key })
						if type(res) == "table" and res.ok then
							Root.close(NAME)
						else
							Toast.show("Spectacles", tostring(if type(res) == "table" and res.why then res.why else "One moment."), 3)
						end
					elseif sh.ready then
						local res = ask({ op = "buy", key = sh.key })
						if type(res) == "table" and not res.ok then
							Toast.show("Spectacles", tostring(res.why or "One moment."), 3)
						end
					end
				end)
			end, 170)
			k.AnchorPoint = Vector2.new(1, 0.5)
			k.Position = UDim2.new(1, -10, 0.5, 0)
			k.Size = UDim2.fromOffset(170, 38)
		end
	end
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 48)
	keys.LayoutOrder = 4
	keys.Parent = content
	Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 200)
	Root.open(NAME, group)
	task.spawn(fill)
end

return SuiteSpectacle
