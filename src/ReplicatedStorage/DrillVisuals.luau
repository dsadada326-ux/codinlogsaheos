-- Drilling Mania visuals shared by the client scripts: drill models in viewports, drills on
-- plots (scaled to fit, heads that spin), stall prompts. Client only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DrillConfig = require(ReplicatedStorage:WaitForChild("DrillConfig"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))

local drillModels = ReplicatedStorage:WaitForChild("Drills")

local V = {}

------------------------------------------------------------------------------------------
-- Can this game load the drill model's meshes? (Meshes uploaded by someone else won't
-- load; then the built-in drill below is used instead.)
------------------------------------------------------------------------------------------
local ContentProvider = game:GetService("ContentProvider")
local meshOk = {} -- [modelName] = true/false once checked

for _, drill in ipairs(DrillConfig.Drills) do
	if meshOk[drill.model] == nil then
		meshOk[drill.model] = "checking"
		task.spawn(function()
			local source = drillModels:FindFirstChild(drill.model)
			local mesh = source and source:FindFirstChildWhichIsA("MeshPart", true)
			if not mesh then
				meshOk[drill.model] = source ~= nil
				return
			end
			local status
			pcall(function()
				ContentProvider:PreloadAsync({ mesh }, function(id, s)
					if id == mesh.MeshId then status = s end
				end)
			end)
			meshOk[drill.model] = status == Enum.AssetFetchStatus.Success
		end)
	end
end

local function usesModel(drill)
	-- the live game can't render meshes this game isn't allowed to use (it only shows the
	-- plain parts), and the check below can't always tell. So the real models are only used
	-- when DrillConfig.UseDrillModels is turned on.
	if not DrillConfig.UseDrillModels then
		return false
	end
	local t = os.clock()
	while meshOk[drill.model] == "checking" and os.clock() - t < 4 do
		task.wait(0.05)
	end
	return meshOk[drill.model] == true
end

------------------------------------------------------------------------------------------
-- the built-in drill: base, two posts, a motor with a spinning gear, 1-4 spinning bits
-- and an oil tank. Coloured with the drill's body/accent; fancier drills glow and sparkle.
------------------------------------------------------------------------------------------
local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = model
	return p
end

-- a vertical cylinder centred at `pos`
local function cyl(parent, pos, diameter, height, color, material)
	return part(parent, {
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = material or Enum.Material.Metal,
	})
end

function V.build(drill)
	local body, accent = drill.body or Color3.fromRGB(140, 140, 150), drill.accent or Color3.fromRGB(220, 220, 230)
	local dark = body:Lerp(Color3.new(0, 0, 0), 0.45)
	local steel = Color3.fromRGB(165, 170, 180)
	local model = Instance.new("Model")
	model.Name = drill.id

	-- base + trim
	local base = part(model, { Name = "Base", Size = Vector3.new(5.2, 0.6, 5.2), CFrame = CFrame.new(0, 0.3, 0), Color = dark, Material = Enum.Material.DiamondPlate })
	model.PrimaryPart = base
	local trimMat = drill.glow and Enum.Material.Neon or Enum.Material.Metal
	for _, s in ipairs({ { 0, 2.55, 5.2, 0.12 }, { 0, -2.55, 5.2, 0.12 }, { 2.55, 0, 0.12, 5.2 }, { -2.55, 0, 0.12, 5.2 } }) do
		part(model, { Name = "Trim", Size = Vector3.new(s[3], 0.14, s[4]), CFrame = CFrame.new(s[1], 0.62, s[2]), Color = accent, Material = trimMat })
	end

	-- frame
	for _, x in ipairs({ -2.1, 2.1 }) do
		part(model, { Name = "Post", Size = Vector3.new(0.55, 6, 0.55), CFrame = CFrame.new(x, 3.6, 0), Color = body, Material = Enum.Material.Metal })
		part(model, { Name = "Foot", Size = Vector3.new(1, 0.4, 1), CFrame = CFrame.new(x, 0.8, 0), Color = dark, Material = Enum.Material.Metal })
	end
	part(model, { Name = "Beam", Size = Vector3.new(4.9, 0.7, 1), CFrame = CFrame.new(0, 6.95, 0), Color = body, Material = Enum.Material.Metal })

	-- motor + stripe
	local motor = part(model, { Name = "Motor", Size = Vector3.new(2.3, 1.5, 2.1), CFrame = CFrame.new(0, 8.05, 0), Color = body, Material = Enum.Material.Metal })
	part(model, { Name = "Stripe", Size = Vector3.new(2.36, 0.28, 2.16), CFrame = CFrame.new(0, 8.15, 0), Color = accent, Material = trimMat })

	-- spinning gear on top
	local gear = Instance.new("Model")
	gear.Name = "HorizontalRotationLeft"
	gear.Parent = model
	gear.WorldPivot = CFrame.new(0, 8.98, 0)
	cyl(gear, Vector3.new(0, 8.98, 0), 1.7, 0.36, accent)
	for i = 0, 5 do
		local a = i * math.pi / 3
		part(gear, {
			Name = "Tooth", Size = Vector3.new(0.4, 0.34, 0.4), Color = accent:Lerp(Color3.new(1, 1, 1), 0.2), Material = Enum.Material.Metal,
			CFrame = CFrame.new(0, 8.98, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0.95, 0, 0),
		})
	end

	-- the bits
	local bits = drill.bits or 1
	local spots = ({
		{ Vector3.new(0, 0, 0) },
		{ Vector3.new(-0.95, 0, 0), Vector3.new(0.95, 0, 0) },
		{ Vector3.new(-1.25, 0, 0), Vector3.new(0, 0, 0), Vector3.new(1.25, 0, 0) },
		{ Vector3.new(-0.8, 0, -0.8), Vector3.new(0.8, 0, -0.8), Vector3.new(-0.8, 0, 0.8), Vector3.new(0.8, 0, 0.8) },
	})[math.clamp(bits, 1, 4)]
	local k = bits == 1 and 1 or (bits == 2 and 0.78 or 0.62)
	for i, spot in ipairs(spots) do
		local head = Instance.new("Model")
		head.Name = bits == 1 and "Drill" or ("Drill" .. i)
		head.Parent = model
		head.WorldPivot = CFrame.new(spot + Vector3.new(0, 3.7, 0))
		cyl(head, spot + Vector3.new(0, 5.1, 0), 0.42 * k + 0.1, 3.1, steel)
		local widths = { 1.6, 1.3, 1.0, 0.7, 0.4 }
		for j, wd in ipairs(widths) do
			local y = 3.55 - (j - 1) * 0.54 - 0.27
			cyl(head, spot + Vector3.new(0, y, 0), wd * k, 0.54, j % 2 == 1 and steel or accent, j % 2 == 1 and Enum.Material.Metal or trimMat)
		end
		-- two flutes so you can see it spin
		for _, side in ipairs({ 1, -1 }) do
			part(head, {
				Name = "Flute", Size = Vector3.new(0.14, 2.6, 0.42 * k), Color = accent, Material = trimMat,
				CFrame = CFrame.new(spot + Vector3.new(side * 0.5 * k, 2.25, 0)) * CFrame.Angles(0, 0, math.rad(side * 14)),
			})
		end
	end

	-- oil tank + pipe
	local tankColor = Color3.fromRGB(70, 45, 105)
	cyl(model, Vector3.new(0, 1.85, -1.95), 1.35, 2.5, tankColor)
	cyl(model, Vector3.new(0, 3.15, -1.95), 1.45, 0.14, accent, trimMat)
	part(model, { Name = "Pipe", Size = Vector3.new(0.28, 0.28, 1.6), CFrame = CFrame.new(0, 2.9, -1.1), Color = steel, Material = Enum.Material.Metal })

	if drill.glow then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 9
		light.Brightness = 1.3
		light.Parent = motor
	end
	if drill.sparkle then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, 0.4, 0)
		att.Parent = base
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(drill.sparkle)
		pe.Size = NumberSequence.new(0.35, 0)
		pe.Lifetime = NumberRange.new(0.8, 1.4)
		pe.Rate = 6
		pe.Speed = NumberRange.new(1.5, 3)
		pe.SpreadAngle = Vector2.new(60, 60)
		pe.LightEmission = 1
		pe.Parent = att
	end
	if drill.smoke then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0.6, 0.8, 0)
		att.Parent = motor
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220))
		pe.Size = NumberSequence.new(0.4, 1.4)
		pe.Transparency = NumberSequence.new(0.4, 1)
		pe.Lifetime = NumberRange.new(1, 1.6)
		pe.Rate = 4
		pe.Speed = NumberRange.new(2, 3)
		pe.Parent = att
	end

	model.WorldPivot = CFrame.new(0, 0, 0)
	-- bigger drills are a little bigger
	local s = 1 + ((drill.index or 1) - 1) * 0.02
	if s ~= 1 then
		pcall(model.ScaleTo, model, s)
	end
	return model
end

-- a fresh copy of a drill's model with no scripts/sounds, every part anchored + non-colliding
function V.clone(drill)
	local source = drillModels:FindFirstChild(drill.model)
	if not source or not usesModel(drill) then
		return V.build(drill)
	end
	local model = source:Clone()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	return model
end

-- the drill in a ViewportFrame, framed to fit. Returns vpf, model, center
function V.viewport(parent, drill, props, yaw)
	local vpf = Kit.new("ViewportFrame", {
		BackgroundTransparency = 1, Ambient = Color3.fromRGB(170, 170, 175), LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
	})
	for k, v in pairs(props or {}) do vpf[k] = v end
	vpf.Parent = parent
	local model = V.clone(drill)
	if not model then return vpf end
	local world = Kit.new("WorldModel", {}, vpf)
	model.Parent = world
	model:PivotTo(CFrame.Angles(0, math.rad(yaw or 25), 0) * model:GetPivot())
	local cf, size = model:GetBoundingBox()
	local cam = Kit.new("Camera", { FieldOfView = 32 }, vpf)
	vpf.CurrentCamera = cam
	local radius = math.max(size.X, size.Y, size.Z) * 0.55
	local dist = radius / math.tan(math.rad(16)) * 1.02
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.12, dist), cf.Position)
	return vpf, model, cf.Position
end

-- places a drill model on a plot: scaled so it fits `footprint` studs, sitting on `floorCF`
function V.placeOnPlot(drill, floorCF, footprint)
	local model = V.clone(drill)
	if not model then return nil end
	local _, size = model:GetBoundingBox()
	local fit = math.min(1, footprint / math.max(size.X, size.Z), 14 / size.Y)
	if fit < 1 then
		pcall(model.ScaleTo, model, model:GetScale() * fit)
	end
	-- stand it on the floor, centred
	local cf, sz = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local rel = cf:ToObjectSpace(pivot) -- pivot relative to box centre
	local target = floorCF * CFrame.new(0, sz.Y / 2, 0) * rel
	model:PivotTo(target)
	return model
end

------------------------------------------------------------------------------------------
-- spinning heads: children named Drill / Drill1.. bob + spin, *Rotation* models turn,
-- Lasers pulse. Returns a stepper(t) you call every frame.
------------------------------------------------------------------------------------------
function V.animator(model)
	local parts = {}
	local base = model:GetPivot()
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			local n = child.Name
			local kind
			if n:match("^Drill%d*$") then kind = "drill"
			elseif n:find("HorizontalRotationLeft") then kind = "left"
			elseif n:find("HorizontalRotationRight") then kind = "right"
			elseif n:find("VerticleRotationUp") or n:find("VerticalRotationUp") then kind = "up"
			elseif n:find("VerticleRotationDown") or n:find("VerticalRotationDown") then kind = "down"
			elseif n == "Lasers" then kind = "lasers"
			end
			if kind then
				local pivot = child:IsA("Model") and child:GetPivot() or child.CFrame
				-- spin around the head's centre, on the drill's own up axis
				local centerPos = child:IsA("Model") and child:GetBoundingBox().Position or child.Position
				local c = CFrame.new(centerPos) * base.Rotation
				table.insert(parts, {
					obj = child, kind = kind,
					centerRel = base:ToObjectSpace(c), -- spin around the head's centre
					pivotFromCenter = c:ToObjectSpace(pivot),
					phase = math.random() * 6,
				})
			end
		end
	end
	local function set(p, cf)
		if p.obj:IsA("Model") then p.obj:PivotTo(cf) else p.obj.CFrame = cf end
	end
	return function(t)
		if not model.Parent then return end
		local root = model:GetPivot()
		for _, p in ipairs(parts) do
			local center = root * p.centerRel
			local rot
			if p.kind == "drill" then
				center = center * CFrame.new(0, math.sin(t * 6 + p.phase) * 0.12, 0)
				rot = CFrame.Angles(0, t * 9, 0)
			elseif p.kind == "left" then rot = CFrame.Angles(0, t * 2.5, 0)
			elseif p.kind == "right" then rot = CFrame.Angles(0, -t * 2.5, 0)
			elseif p.kind == "up" then rot = CFrame.Angles(t * 2, 0, 0)
			elseif p.kind == "down" then rot = CFrame.Angles(-t * 2, 0, 0)
			else -- lasers: slow turn
				rot = CFrame.Angles(0, t * 1.5, 0)
			end
			set(p, center * rot * p.pivotFromCenter)
		end
	end
end

-- an invisible part in the middle of a stall (a Folder of parts) with a Custom prompt on it
function V.stallPrompt(folder, name, actionText, objectText)
	local sum, n, minY = Vector3.zero, 0, math.huge
	for _, p in ipairs(folder:GetDescendants()) do
		if p:IsA("BasePart") then
			sum += p.Position
			n += 1
			minY = math.min(minY, p.Position.Y - p.Size.Y / 2)
		end
	end
	if n == 0 then return nil end
	local center = sum / n
	local anchor = Instance.new("Part")
	anchor.Name = name .. "PromptAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = Vector3.new(center.X, minY + 4, center.Z)
	anchor.Parent = workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = anchor
	return prompt, anchor
end

function V.rarityColor(rarity)
	return DrillConfig.Rarities[rarity] or Color3.new(1, 1, 1)
end

return V
