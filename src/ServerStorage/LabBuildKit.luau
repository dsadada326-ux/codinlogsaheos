-- helpers for building the Laboratory pieces (Studio only)
local K = {}
K.FY = 2.55 -- lab floor height
K.col = {
	WHITE = Color3.fromRGB(240, 243, 248), LIGHT = Color3.fromRGB(205, 212, 225), GREY = Color3.fromRGB(150, 156, 170),
	DARK = Color3.fromRGB(55, 60, 75), DARKER = Color3.fromRGB(35, 38, 48), TEAL = Color3.fromRGB(40, 200, 190),
	GREEN = Color3.fromRGB(90, 235, 110), BLUE = Color3.fromRGB(80, 180, 255), PURPLE = Color3.fromRGB(170, 95, 255),
	YELLOW = Color3.fromRGB(255, 205, 40), RED = Color3.fromRGB(235, 70, 70), WOOD = Color3.fromRGB(160, 110, 65),
	WOODDARK = Color3.fromRGB(120, 80, 45), GLASS = Color3.fromRGB(190, 230, 255),
}
function K.model(name, parent) local m = Instance.new("Model") m.Name = name m.Parent = parent return m end
function K.part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
local function cfOf(pos) return typeof(pos) == "CFrame" and pos or CFrame.new(pos) end
function K.box(parent, name, size, pos, color, mat, extra)
	local t = { Name = name, Size = size, CFrame = cfOf(pos), Color = color, Material = mat or Enum.Material.SmoothPlastic }
	for k, v in pairs(extra or {}) do t[k] = v end
	return K.part(parent, t)
end
function K.cyl(parent, name, pos, dia, h, color, mat, extra)
	local t = { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, dia, dia), CFrame = cfOf(pos) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = mat or Enum.Material.SmoothPlastic }
	for k, v in pairs(extra or {}) do t[k] = v end
	return K.part(parent, t)
end
function K.tube(parent, name, a, b, dia, color, mat, extra)
	local len = (b - a).Magnitude
	local t = { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, dia, dia), CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), Color = color, Material = mat or Enum.Material.SmoothPlastic }
	for k, v in pairs(extra or {}) do t[k] = v end
	return K.part(parent, t)
end
function K.ball(parent, name, pos, dia, color, mat, extra)
	local t = { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.new(dia, dia, dia), CFrame = cfOf(pos), Color = color, Material = mat or Enum.Material.SmoothPlastic }
	for k, v in pairs(extra or {}) do t[k] = v end
	return K.part(parent, t)
end
function K.light(part, color, range, b)
	local l = Instance.new("PointLight") l.Color = color l.Range = range or 12 l.Brightness = b or 1.2 l.Parent = part return l
end
function K.fx(part, color, rate, smoke, dir)
	local a = Instance.new("Attachment") a.Parent = part
	local pe = Instance.new("ParticleEmitter")
	if smoke then
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Size = NumberSequence.new(0.8, 2.6) pe.Transparency = NumberSequence.new(0.5, 1) pe.LightEmission = 0.2
	else
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Size = NumberSequence.new(0.35, 0.05) pe.Transparency = NumberSequence.new(0.1, 1) pe.LightEmission = 1
	end
	pe.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35))
	pe.Lifetime = NumberRange.new(1, 1.6) pe.Rate = rate or 5 pe.Speed = NumberRange.new(1.5, 3)
	pe.SpreadAngle = Vector2.new(20, 20) pe.EmissionDirection = dir or Enum.NormalId.Top
	pe.Parent = a
	return pe
end
function K.sign(part, face, text, c1, c2, ppu)
	local sg = Instance.new("SurfaceGui") sg.Face = face sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud sg.PixelsPerStud = ppu or 40 sg.LightInfluence = 0 sg.Parent = part
	local t = Instance.new("TextLabel") t.BackgroundTransparency = 1 t.Size = UDim2.fromScale(1, 1) t.Font = Enum.Font.FredokaOne t.TextScaled = true t.Text = text t.TextColor3 = Color3.new(1, 1, 1) t.Parent = sg
	local st = Instance.new("UIStroke") st.Thickness = 4 st.Color = Color3.fromRGB(10, 14, 24) st.Parent = t
	local gr = Instance.new("UIGradient") gr.Rotation = 90 gr.Color = ColorSequence.new(c1 or Color3.new(1,1,1), c2 or Color3.new(1,1,1)) gr.Parent = t
	local pad = Instance.new("UIPadding") pad.PaddingTop = UDim.new(0.1, 0) pad.PaddingBottom = UDim.new(0.1, 0) pad.PaddingLeft = UDim.new(0.05, 0) pad.PaddingRight = UDim.new(0.05, 0) pad.Parent = t
	return t
end
-- small flask: glass bulb, glowing liquid, neck, cork
function K.flask(parent, pos, color, s)
	s = s or 1
	K.ball(parent, "FlaskGlass", pos + Vector3.new(0, 0.6 * s, 0), 1.2 * s, K.col.GLASS, Enum.Material.Glass, { Transparency = 0.45 })
	K.ball(parent, "FlaskLiquid", pos + Vector3.new(0, 0.52 * s, 0), 0.95 * s, color, Enum.Material.Neon, { Transparency = 0.1 })
	K.cyl(parent, "FlaskNeck", pos + Vector3.new(0, 1.35 * s, 0), 0.45 * s, 0.6 * s, K.col.GLASS, Enum.Material.Glass, { Transparency = 0.35 })
	K.cyl(parent, "Cork", pos + Vector3.new(0, 1.7 * s, 0), 0.5 * s, 0.25 * s, Color3.fromRGB(150, 100, 55), Enum.Material.Wood)
end
-- a screen board (posts + frame + a flat "Screen" part the SurfaceGui goes on), facing `dir`
function K.board(parent, center, width, height, dir, frameColor)
	local cf = CFrame.lookAt(center, center + dir)
	for _, s in ipairs({ -1, 1 }) do
		K.box(parent, "Post", Vector3.new(0.8, center.Y - K.FY + height / 2, 0.8), (cf * CFrame.new(s * (width / 2 + 0.2), -(center.Y - K.FY + height / 2) / 2 + height / 2, 0.3)), K.col.DARK)
	end
	K.box(parent, "Frame", Vector3.new(width + 1.2, height + 1.2, 0.6), cf * CFrame.new(0, 0, 0.35), frameColor or K.col.DARK)
	local screen = K.box(parent, "Screen", Vector3.new(width, height, 0.2), cf * CFrame.new(0, 0, 0.0), K.col.DARKER)
	return screen
end
return K
