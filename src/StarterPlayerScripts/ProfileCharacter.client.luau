-- Shows a player's avatar in the Profile UI's "character" frame.
-- The avatar plays its idle animation and turns its head/torso toward the mouse.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local profileGui = player:WaitForChild("PlayerGui"):WaitForChild("Profile")
local holder = profileGui:WaitForChild("Frame"):WaitForChild("Frame"):WaitForChild("character")

local IDLE_R15 = "rbxassetid://507766666"
local IDLE_R6 = "rbxassetid://180435571"

-- How far the character can turn toward the mouse (degrees)
local MAX_HEAD_YAW = 40
local MAX_HEAD_PITCH = 20
local WAIST_SHARE = 0.4 -- R15 only: how much of the turn the waist takes
local FOLLOW_SPEED = 10

local viewport = Instance.new("ViewportFrame")
viewport.Name = "AvatarViewport"
viewport.Size = UDim2.fromScale(1, 1)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(200, 200, 200)
viewport.LightColor = Color3.fromRGB(255, 255, 255)
viewport.LightDirection = Vector3.new(-1, -1, -1)
viewport.Parent = holder

-- A WorldModel is needed for animations to play inside a ViewportFrame
local world = Instance.new("WorldModel")
world.Parent = viewport

local camera = Instance.new("Camera")
camera.FieldOfView = 30
camera.Parent = viewport
viewport.CurrentCamera = camera

local current -- { model, neck, neckC0, waist, waistC0, isR6 }
local yaw, pitch = 0, 0

local function getIdleAnimationId(model, isR6)
	local animate = model:FindFirstChild("Animate")
	local idle = animate and animate:FindFirstChild("idle")
	local anim = idle and idle:FindFirstChildWhichIsA("Animation")
	if anim and anim.AnimationId ~= "" then
		return anim.AnimationId
	end
	return isR6 and IDLE_R6 or IDLE_R15
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
		end
	end
	return model
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
	model:PivotTo(CFrame.new(0, 0, 0))
	model.Parent = world

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
	local anim = Instance.new("Animation")
	anim.AnimationId = getIdleAnimationId(model, isR6)
	local track = animator:LoadAnimation(anim)
	track.Looped = true
	track:Play()

	-- Frame the upper body, camera in front of the character
	local focus = root.Position + Vector3.new(0, 1.2, 0)
	camera.CFrame = CFrame.lookAt(focus + root.CFrame.LookVector * 11, focus)

	current = {
		model = model,
		neck = neck,
		neckC0 = neck and neck.C0,
		waist = waist,
		waistC0 = waist and waist.C0,
		isR6 = isR6,
	}
	yaw, pitch = 0, 0
end

RunService.RenderStepped:Connect(function(dt)
	if not current or not holder.Visible or not profileGui.Enabled then return end

	-- Mouse position relative to the frame's center, -1..1
	local mouse = UserInputService:GetMouseLocation()
	local inset = game:GetService("GuiService"):GetGuiInset()
	local center = holder.AbsolutePosition + holder.AbsoluteSize / 2 + inset
	local rel = (mouse - center) / (holder.AbsoluteSize / 2)
	local x = math.clamp(rel.X, -1.5, 1.5) / 1.5
	local y = math.clamp(rel.Y, -1.5, 1.5) / 1.5

	-- The character faces the camera, so mouse-right is the character's left
	local targetYaw = math.rad(x * MAX_HEAD_YAW)
	local targetPitch = math.rad(-y * MAX_HEAD_PITCH)
	local a = 1 - math.exp(-FOLLOW_SPEED * dt)
	yaw += (targetYaw - yaw) * a
	pitch += (targetPitch - pitch) * a

	if current.isR6 then
		if current.neck then
			current.neck.C0 = current.neckC0 * CFrame.Angles(-pitch, 0, yaw)
		end
	else
		local headShare = current.waist and (1 - WAIST_SHARE) or 1
		if current.neck then
			current.neck.C0 = current.neckC0 * CFrame.Angles(pitch * headShare, yaw * headShare, 0)
		end
		if current.waist then
			current.waist.C0 = current.waistC0 * CFrame.Angles(pitch * WAIST_SHARE, yaw * WAIST_SHARE, 0)
		end
	end
end)

-- Show yourself by default. Other scripts can show a searched player with:
--   profileGui:SetAttribute("ShowUserId", userId)
profileGui:GetAttributeChangedSignal("ShowUserId"):Connect(function()
	local id = profileGui:GetAttribute("ShowUserId")
	if typeof(id) == "number" then
		showUser(id)
	end
end)

showUser(player.UserId)
