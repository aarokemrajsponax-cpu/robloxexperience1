--!nocheck
-- Writes a built world as JSON for the 3D viewer (viewer.js): every visible part, every lit
-- lamp, every SurfaceGui (in the UI snapshots' format, for textures.py) and the Lighting.
-- Used by tests/smoke.luau (EXPORT=<file>) and tools/view/showroom.luau.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum

return function(workspace, lighting, path)
	local function rgb(c)
		return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
	end
	local function v3(v)
		return { v.X, v.Y, v.Z }
	end
	local function udim2(u)
		return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
	end
	local function colour(c)
		return { c.R, c.G, c.B }
	end
	local function dump(inst)
		local n = { class = inst.ClassName, name = inst.Name, kids = {} }
		if inst:IsA("GuiObject") then
			n.pos = udim2(inst.Position)
			n.size = udim2(inst.Size)
			n.anchor = { inst.AnchorPoint.X, inst.AnchorPoint.Y }
			n.rot = inst.Rotation
			n.bg = colour(inst.BackgroundColor3)
			n.bgT = inst.BackgroundTransparency
			n.visible = inst.Visible
			n.z = inst.ZIndex
			n.order = inst.LayoutOrder
			n.clip = inst.ClipsDescendants
			n.auto = inst.AutomaticSize.Name
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				n.text = inst.Text
				n.textSize = inst.TextSize
				n.textColor = colour(inst.TextColor3)
				n.textT = inst.TextTransparency
				n.xAlign = inst.TextXAlignment.Name
				n.yAlign = inst.TextYAlignment.Name
				n.wrap = inst.TextWrapped
				n.scaled = inst.TextScaled
				local ff = inst.FontFace
				n.weight = ff.Weight.Name
				n.style = ff.Style.Name
				n.family = ff.Family
			end
		elseif inst:IsA("UICorner") then
			n.radius = { inst.CornerRadius.Scale, inst.CornerRadius.Offset }
		elseif inst:IsA("UIGradient") then
			local cs, ts = {}, {}
			for _, k in inst.Color.Keypoints do
				table.insert(cs, { k.Time, k.Value.R, k.Value.G, k.Value.B })
			end
			for _, k in inst.Transparency.Keypoints do
				table.insert(ts, { k.Time, k.Value })
			end
			n.colors, n.trans, n.rot, n.offset, n.enabled = cs, ts, inst.Rotation, { inst.Offset.X, inst.Offset.Y }, inst.Enabled
		elseif inst:IsA("UIStroke") then
			n.color, n.thickness, n.trans, n.enabled = colour(inst.Color), inst.Thickness, inst.Transparency, inst.Enabled
		elseif inst:IsA("UIScale") then
			n.scale = inst.Scale
		elseif inst:IsA("UIListLayout") then
			n.dir = inst.FillDirection.Name
			n.padding = { inst.Padding.Scale, inst.Padding.Offset }
			n.hAlign = inst.HorizontalAlignment.Name
			n.vAlign = inst.VerticalAlignment.Name
		elseif inst:IsA("UIPadding") then
			n.pad = { inst.PaddingTop.Offset, inst.PaddingBottom.Offset, inst.PaddingLeft.Offset, inst.PaddingRight.Offset }
			n.padS = { inst.PaddingTop.Scale, inst.PaddingBottom.Scale, inst.PaddingLeft.Scale, inst.PaddingRight.Scale }
		elseif inst:IsA("UITextSizeConstraint") then
			n.maxText, n.minText = inst.MaxTextSize, inst.MinTextSize
		elseif inst:IsA("UIGridLayout") then
			n.cell, n.cellPad, n.hAlign = udim2(inst.CellSize), udim2(inst.CellPadding), inst.HorizontalAlignment.Name
		elseif inst:IsA("UISizeConstraint") then
			n.max = { inst.MaxSize.X, inst.MaxSize.Y }
		end
		for _, c in inst:GetChildren() do
			table.insert(n.kids, dump(c))
		end
		return n
	end
	local out = { parts = {}, lights = {}, guis = {}, lighting = {} }
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Transparency < 0.99 then
				local shape = if d:IsA("WedgePart") then "Wedge" elseif d:IsA("CornerWedgePart") then "CornerWedge" elseif d:IsA("Part") then d.Shape.Name else "Block"
				table.insert(out.parts, { d.Name, shape, v3(d.Size), { d.CFrame:GetComponents() }, rgb(d.Color), d.Material.Name, d.Transparency, d.Reflectance, d.CastShadow })
			end
		elseif d:IsA("Light") then
			local p = d.Parent
			if d.Enabled and p and p:IsA("BasePart") then
				local entry = { kind = d.ClassName, cf = { p.CFrame:GetComponents() }, size = v3(p.Size), color = rgb(d.Color), brightness = d.Brightness, range = d.Range, shadows = d.Shadows }
				if d:IsA("SpotLight") or d:IsA("SurfaceLight") then
					entry.face = d.Face.Name
					entry.angle = d.Angle
				end
				table.insert(out.lights, entry)
			end
		elseif d:IsA("SurfaceGui") then
			local p = d.Adornee or d.Parent
			if d.Enabled and p and p:IsA("BasePart") then
				local face = d.Face.Name
				local s = p.Size
				local w = if face == "Left" or face == "Right" then s.Z else s.X
				local h = if face == "Top" or face == "Bottom" then s.Z else s.Y
				local px = if d.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud then { w * d.PixelsPerStud, h * d.PixelsPerStud } else { d.CanvasSize.X, d.CanvasSize.Y }
				local kids = {}
				for _, c in d:GetChildren() do
					table.insert(kids, dump(c))
				end
				table.insert(out.guis, { part = { p.CFrame:GetComponents() }, size = v3(p.Size), face = face, canvas = px, lit = d.LightInfluence, brightness = d.Brightness, kids = kids, name = p:GetFullName() })
			end
		end
	end
	out.lighting = {
		clock = lighting.ClockTime,
		brightness = lighting.Brightness,
		ambient = rgb(lighting.Ambient),
		outdoor = rgb(lighting.OutdoorAmbient),
		exposure = lighting.ExposureCompensation,
	}
	fs.writeFile(path, serde.encode("json", out))
	print(("exported %d parts, %d lights, %d surface guis to %s"):format(#out.parts, #out.lights, #out.guis, path))
end
