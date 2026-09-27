-- Shows a player's avatar in the Profile UI's "character" frame.
-- The whole body turns left/right to follow the cursor, the head looks at it,
-- and it stands on a glowing platform over an animated backdrop.
-- Click the character to make it spin and wave.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local profileGui = player:WaitForChild("PlayerGui"):WaitForChild("Profile")
local profileFrame = profileGui:WaitForChild("Frame")
local holder = profileFrame:WaitForChild("Frame"):WaitForChild("character")

-- Look
local ACCENT = Color3.fromRGB(170, 90, 255) -- platform ring, glow and backdrop tint
local ACCENT_2 = Color3.fromRGB(60, 200, 255)

-- Turning toward the cursor (degrees)
local MAX_BODY_YAW = 55
local MAX_HEAD_YAW = 30 -- on top of the body turn
local MAX_HEAD_PITCH = 18
local FOLLOW_SPEED = 8

-- Camera
local CAMERA_DISTANCE = 12
local CAMERA_HEIGHT = 0.6

local IDLE_R15 = "rbxassetid://507766666"
local IDLE_R6 = "rbxassetid://180435571"
local WAVE_R15 = "rbxassetid://507770239"
local WAVE_R6 = "rbxassetid://128777973"

--------------------------------------------------------------------------------
-- Backdrop (plain UI behind the 3D view)
--------------------------------------------------------------------------------

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 12)
	c.Parent = parent
end

local backdrop = Instance.new("Frame")
backdrop.Name = "AvatarBackdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(1, 1, 1)
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 1
backdrop.ClipsDescendants = true
backdrop.Parent = holder
corner(backdrop)

local backdropGradient = Instance.new("UIGradient")
backdropGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 10, 24)),
	ColorSequenceKeypoint.new(0.5, ACCENT:Lerp(Color3.new(0, 0, 0), 0.55)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 10, 24)),
})
backdropGradient.Rotation = 90
backdropGradient.Parent = backdrop

-- Soft glow behind the character
local glow = Instance.new("Frame")
glow.Name = "Glow"
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.fromScale(0.5, 0.55)
glow.Size = UDim2.fromScale(0.9, 0.9)
glow.SizeConstraint = Enum.SizeConstraint.RelativeYY
glow.BackgroundColor3 = ACCENT
glow.BorderSizePixel = 0
glow.ZIndex = 1
glow.Parent = backdrop
corner(glow, UDim.new(1, 0))

local glowGradient = Instance.new("UIGradient")
glowGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.55),
	NumberSequenceKeypoint.new(1, 1),
})
glowGradient.Parent = glow

-- Two slow light beams sweeping behind the character
local beams = {}
for i = 1, 2 do
	local beam = Instance.new("Frame")
	beam.Name = "Beam" .. i
	beam.AnchorPoint = Vector2.new(0.5, 0.5)
	beam.Position = UDim2.fromScale(0.5, 0.55)
	beam.Size = UDim2.new(0.18, 0, 2.2, 0)
	beam.BackgroundColor3 = i == 1 and ACCENT or ACCENT_2
	beam.BorderSizePixel = 0
	beam.ZIndex = 1
	beam.Parent = backdrop

	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Rotation = 0
	g.Parent = beam
	beams[i] = beam
end

-- Glowing border
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Color = Color3.new(1, 1, 1)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = backdrop

local strokeGradient = Instance.new("UIGradient")
strokeGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, ACCENT),
	ColorSequenceKeypoint.new(0.5, ACCENT_2),
	ColorSequenceKeypoint.new(1, ACCENT),
})
strokeGradient.Parent = stroke

--------------------------------------------------------------------------------
-- 3D view
--------------------------------------------------------------------------------

local viewport = Instance.new("ViewportFrame")
viewport.Name = "AvatarViewport"
viewport.Size = UDim2.fromScale(1, 1)
viewport.BackgroundTransparency = 1
viewport.ZIndex = 2
viewport.Ambient = Color3.fromRGB(150, 140, 180)
viewport.LightColor = Color3.fromRGB(255, 245, 255)
viewport.LightDirection = Vector3.new(-0.6, -1, -0.8)
viewport.Parent = holder

-- A WorldModel is needed for animations to play inside a ViewportFrame
local world = Instance.new("WorldModel")
world.Parent = viewport

local camera = Instance.new("Camera")
camera.FieldOfView = 30
camera.Parent = viewport
viewport.CurrentCamera = camera

-- Platform the character stands on
local function disc(name, radius, height, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, radius * 2, radius * 2)
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Parent = world
	return p
end

local ring = disc("Ring", 2.35, 0.25, ACCENT, Enum.Material.Neon)
local ringInner = disc("RingInner", 2.1, 0.3, Color3.fromRGB(20, 18, 32), Enum.Material.SmoothPlastic)
local ringOuter = disc("RingOuter", 3.1, 0.05, ACCENT_2, Enum.Material.Neon, 0.6)

--------------------------------------------------------------------------------
-- Avatar
--------------------------------------------------------------------------------

local current -- { model, root, neck, neckC0, waist, waistC0, isR6, animator }
local bodyYaw, headYaw, headPitch = 0, 0, 0
local spin = Instance.new("NumberValue") -- extra yaw for the intro / click spin (radians)
local zoom = Instance.new("NumberValue")
zoom.Value = CAMERA_DISTANCE
local baseCFrame = CFrame.new()
local feetY = 0

local function getAnimationId(model, name, fallbackR15, fallbackR6, isR6)
	local animate = model:FindFirstChild("Animate")
	local folder = animate and animate:FindFirstChild(name)
	local anim = folder and folder:FindFirstChildWhichIsA("Animation")
	if anim and anim.AnimationId ~= "" then
		return anim.AnimationId
	end
	return isR6 and fallbackR6 or fallbackR15
end

local function loadAvatar(userId)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if not ok or not model then
		-- Fall back to copying the local player's character
		local char = player.Character
		if not char then return nil end
		char.Archivable = true
		model = char:Clone()
	end

	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
		end
	end
	return model
end

local function playAnimation(id, looped, priority)
	if not current then return end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return current.animator:LoadAnimation(anim)
	end)
	if not ok then return end
	track.Looped = looped
	track.Priority = priority or Enum.AnimationPriority.Idle
	track:Play(0.2)
	return track
end

local function showUser(userId)
	if current then
		current.model:Destroy()
		current = nil
	end

	local model = loadAvatar(userId)
	if not model then return end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		return
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	model.Parent = world

	-- Stand the character on the platform, facing the camera (-Z)
	baseCFrame = CFrame.new()
	model:PivotTo(baseCFrame)
	local _, size = model:GetBoundingBox()
	feetY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		feetY = root.Position.Y - 3
	end

	local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
	local neck, waist
	if isR6 then
		local torso = model:FindFirstChild("Torso")
		neck = torso and torso:FindFirstChild("Neck")
	else
		local head = model:FindFirstChild("Head")
		local upper = model:FindFirstChild("UpperTorso")
		neck = head and head:FindFirstChild("Neck")
		waist = upper and upper:FindFirstChild("Waist")
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	current = {
		model = model,
		root = root,
		neck = neck,
		neckC0 = neck and neck.C0,
		waist = waist,
		waistC0 = waist and waist.C0,
		isR6 = isR6,
		animator = animator,
		height = size.Y,
	}

	playAnimation(getAnimationId(model, "idle", IDLE_R15, IDLE_R6, isR6), true)

	-- Intro: spin in from behind and zoom in
	spin.Value = math.pi * 2
	zoom.Value = CAMERA_DISTANCE * 1.6
	TweenService:Create(spin, TweenInfo.new(1.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 }):Play()
	TweenService:Create(zoom, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = CAMERA_DISTANCE }):Play()
end

-- Click the character: spin once and wave
local busy = false
viewport.InputBegan:Connect(function(input)
	if busy or not current then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	busy = true
	spin.Value = -math.pi * 2
	local t = TweenService:Create(spin, TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 })
	t:Play()
	playAnimation(getAnimationId(current.model, "wave", WAVE_R15, WAVE_R6, current.isR6), false, Enum.AnimationPriority.Action)
	t.Completed:Wait()
	busy = false
end)

--------------------------------------------------------------------------------
-- Every frame
--------------------------------------------------------------------------------

local clock = 0
RunService.RenderStepped:Connect(function(dt)
	if not profileGui.Enabled or not profileFrame.Visible then return end
	clock += dt

	-- Backdrop motion
	beams[1].Rotation = 20 + math.sin(clock * 0.6) * 25
	beams[2].Rotation = -20 + math.sin(clock * 0.5 + 1.5) * 25
	strokeGradient.Rotation = (clock * 60) % 360
	local pulse = 0.5 + 0.5 * math.sin(clock * 2)
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.45 + pulse * 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	ring.Transparency = pulse * 0.25
	ringOuter.Transparency = 0.45 + pulse * 0.35

	if not current then return end

	-- Cursor position relative to the frame's center, -1..1
	local mouse = UserInputService:GetMouseLocation()
	local center = holder.AbsolutePosition + holder.AbsoluteSize / 2 + GuiService:GetGuiInset()
	local rel = (mouse - center) / (holder.AbsoluteSize * 1.5)
	local x = math.clamp(rel.X, -1, 1)
	local y = math.clamp(rel.Y, -1, 1)

	-- The character faces the camera, so the cursor on screen-right is the character's left
	local a = 1 - math.exp(-FOLLOW_SPEED * dt)
	bodyYaw += (math.rad(x * MAX_BODY_YAW) - bodyYaw) * a
	headYaw += (math.rad(x * MAX_HEAD_YAW) - headYaw) * a
	headPitch += (math.rad(-y * MAX_HEAD_PITCH) - headPitch) * a

	-- Turn the whole body
	current.model:PivotTo(baseCFrame * CFrame.Angles(0, bodyYaw + spin.Value, 0))

	-- Head (and waist on R15) look further toward the cursor
	if current.isR6 then
		if current.neck then
			current.neck.C0 = current.neckC0 * CFrame.Angles(-headPitch, 0, headYaw)
		end
	else
		if current.neck then
			current.neck.C0 = current.neckC0 * CFrame.Angles(headPitch * 0.7, headYaw * 0.7, 0)
		end
		if current.waist then
			current.waist.C0 = current.waistC0 * CFrame.Angles(headPitch * 0.3, headYaw * 0.3, 0)
		end
	end

	-- Platform under the feet, rotated flat
	local flat = CFrame.Angles(0, 0, math.rad(90))
	ringInner.CFrame = CFrame.new(0, feetY - 0.12, 0) * flat
	ring.CFrame = CFrame.new(0, feetY - 0.2, 0) * flat
	ringOuter.CFrame = CFrame.new(0, feetY - 0.3, 0) * flat

	-- Camera: slightly above, looking down at the body, with a gentle sway
	local focusY = feetY + current.height * 0.5
	local sway = Vector3.new(math.sin(clock * 0.4) * 0.3, math.sin(clock * 0.7) * 0.1, 0)
	local camPos = Vector3.new(0, focusY + CAMERA_HEIGHT, -zoom.Value) + sway
	camera.CFrame = CFrame.lookAt(camPos, Vector3.new(0, focusY - 0.2, 0))
end)

-- Show yourself by default. Other scripts can show a searched player with:
--   profileGui:SetAttribute("ShowUserId", userId)
profileGui:GetAttributeChangedSignal("ShowUserId"):Connect(function()
	local id = profileGui:GetAttribute("ShowUserId")
	if typeof(id) == "number" then
		showUser(id)
	end
end)

-- Replay the intro whenever the profile is opened
local function replayIntro()
	if profileGui.Enabled and profileFrame.Visible and current then
		spin.Value = math.pi * 2
		TweenService:Create(spin, TweenInfo.new(1.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 }):Play()
	end
end
profileFrame:GetPropertyChangedSignal("Visible"):Connect(replayIntro)
profileGui:GetPropertyChangedSignal("Enabled"):Connect(replayIntro)

showUser(player.UserId)
