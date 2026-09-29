local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local SettingsConfig = require(RS:WaitForChild("SettingsConfig"))
local IslandTwoConfig = require(RS:WaitForChild("IslandTwoConfig"))

local function settingOn(key)
	local value = player:GetAttribute(SettingsConfig.attributeOf(key))

	if value == nil then
		return SettingsConfig.Settings[key].Default
	end

	return value
end

-- The Blue Button on Island 2 moves and presses exactly like the Red Button
-- (a copy of ButtonVFXManager): faces you, bobs, hops on hover, squashes on press.
-- It only presses when its cooldown is ready.
local buttonModel = workspace
	:WaitForChild("Islands")
	:WaitForChild("Island2")
	:WaitForChild("BlueButton")
	:WaitForChild("Button")

local button = buttonModel:WaitForChild("Button")
local base = buttonModel:WaitForChild("Base")
local clickPart = buttonModel:WaitForChild("ClickPart")
local clickDetector = clickPart:WaitForChild("ClickDetector")

local counter = buttonModel:WaitForChild("Counter")
local counterGui = counter:WaitForChild("SurfaceGui")

local counterScale = counterGui
	:WaitForChild("Frame")
	:WaitForChild("UIScale")

local circlePop = buttonModel
	:WaitForChild("Emitattachment")
	:WaitForChild("CirclePop")

local stars = buttonModel
	:WaitForChild("Emitattachment2")
	:WaitForChild("stars")

local lines = buttonModel
	:WaitForChild("Emitattachment2")
	:WaitForChild("lines")

local modelStartPivot = buttonModel:GetPivot()
local modelToButton = modelStartPivot:ToObjectSpace(button.CFrame)

local buttonStartSize = button.Size
local baseStartSize = base.Size
local counterStartScale = counterScale.Scale
local modelPosition = modelStartPivot.Position

-- The button's front is the direction the counter text faces.
local counterNormal = counter.CFrame:VectorToWorldSpace(
	Vector3.FromNormalId(counterGui.Face)
)

local frontDirection = Vector3.new(
	counterNormal.X,
	0,
	counterNormal.Z
).Unit

local referenceCFrame = CFrame.lookAt(
	modelPosition,
	modelPosition + frontDirection
)

local rotationOffset =
	referenceCFrame:ToObjectSpace(modelStartPivot)

local hoverSound = Instance.new("Sound")
hoverSound.SoundId = "rbxassetid://117503154823137"
hoverSound.Volume = 0.7
hoverSound.Parent = buttonModel

local pressPosition = 0
local pressVelocity = 0
local counterPosition = 0
local counterVelocity = 0
local idleParticleTimer = 0

local FACING_SPEED = 12 -- how fast the button turns to face its target
local facingPivot = modelStartPivot

local hoverJump = Instance.new("NumberValue")
hoverJump.Value = 0

local hoverTween
local hoverId = 0

local function updateSpring(position, velocity, deltaTime)
	local frequency = math.pi * 2 * 2
	local damping = 0.3
	local dampedFrequency =
		frequency * math.sqrt(1 - damping ^ 2)

	local decay =
		math.exp(-damping * frequency * deltaTime)

	local newPosition =
		decay
		* (
			position * math.cos(dampedFrequency * deltaTime)
			+ (
				velocity + damping * frequency * position
			)
			/ dampedFrequency
			* math.sin(dampedFrequency * deltaTime)
		)

	local newVelocity =
		decay
		* (
			velocity * math.cos(dampedFrequency * deltaTime)
			- (
				position * frequency + velocity * damping
			)
			* math.sin(dampedFrequency * deltaTime)
		)

	return newPosition, newVelocity
end

local function getRoot()
	local character = player.Character

	if character then
		return character:FindFirstChild("HumanoidRootPart")
	end
end

-- what the counter should face: the camera while it is scripted
-- (camera view mode), otherwise the player
local function getFacingTarget()
	local camera = workspace.CurrentCamera

	if camera and camera.CameraType == Enum.CameraType.Scriptable then
		return camera.CFrame.Position
	end

	local root = getRoot()

	if root then
		return root.Position
	end

	return nil
end

local function getFacingPivot(deltaTime)
	local focus = getFacingTarget()
	local desired = modelStartPivot

	if focus then
		local flatOffset = Vector3.new(
			focus.X - modelPosition.X,
			0,
			focus.Z - modelPosition.Z
		)

		-- ignore a target straight above/below the button
		if flatOffset.Magnitude > 0.1 then
			desired = CFrame.lookAt(
				modelPosition,
				modelPosition + flatOffset
			) * rotationOffset
		else
			desired = facingPivot
		end
	end

	facingPivot = facingPivot:Lerp(
		desired,
		1 - math.exp(-FACING_SPEED * deltaTime)
	)

	return facingPivot
end

local function playHoverJump()
	hoverId += 1
	local currentId = hoverId

	if settingOn("SFX") then
		hoverSound:Stop()
		hoverSound.TimePosition = 0
		hoverSound:Play()
	end

	if settingOn("VFX") then
		stars:Emit(4)
		lines:Emit(3)
	end

	if hoverTween then
		hoverTween:Cancel()
	end

	hoverJump.Value = 0

	hoverTween = TweenService:Create(
		hoverJump,
		TweenInfo.new(
			0.16,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{
			Value = 0.22
		}
	)

	hoverTween:Play()

	hoverTween.Completed:Connect(function(state)
		if state ~= Enum.PlaybackState.Completed
			or currentId ~= hoverId then
			return
		end

		hoverTween = TweenService:Create(
			hoverJump,
			TweenInfo.new(
				0.28,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				Value = 0
			}
		)

		hoverTween:Play()
	end)
end

RunService.RenderStepped:Connect(function(deltaTime)
	pressPosition, pressVelocity =
		updateSpring(
			pressPosition,
			pressVelocity,
			deltaTime
		)

	counterPosition, counterVelocity =
		updateSpring(
			counterPosition,
			counterVelocity,
			deltaTime
		)

	local bounce =
		math.abs(math.sin(os.clock() * 3.5))

	local idleHeight =
		0.03 + bounce * 0.12

	local idleScale =
		1.015 + bounce * 0.025

	idleParticleTimer += deltaTime

	if idleParticleTimer >= 1.5 then
		idleParticleTimer = 0

		if settingOn("VFX") then
			if math.random(1, 2) == 1 then
				stars:Emit(1)
			else
				lines:Emit(1)
			end
		end
	end

	local displayPivot =
		CFrame.new(
			0,
			idleHeight + hoverJump.Value,
			0
		)
		* getFacingPivot(deltaTime)

	buttonModel:PivotTo(displayPivot)

	local heightScale =
		math.max(1 - pressPosition * 0.02, 0.2)
		* idleScale

	local widthScale =
		math.max(1 + pressPosition * 0.015, 0.2)
		* idleScale

	local newHeight =
		buttonStartSize.Y * heightScale

	base.Size = Vector3.new(
		baseStartSize.X * widthScale,
		baseStartSize.Y,
		baseStartSize.Z * widthScale
	)

	button.Size = Vector3.new(
		buttonStartSize.X * widthScale,
		newHeight,
		buttonStartSize.Z * widthScale
	)

	button.CFrame =
		displayPivot
		* modelToButton
		* CFrame.new(
			0,
			(newHeight - buttonStartSize.Y) / 2
			- pressPosition * 0.9,
			0
		)

	counterScale.Scale =
		counterStartScale
		* (1 + counterPosition / 5.3 * 0.3)
		* idleScale
end)

local function emitButtonParticles()
	if not settingOn("VFX") then
		return
	end

	stars:Emit(math.random(5, 15))
	lines:Emit(math.random(5, 15))
	circlePop:Emit(1)
end

local MAX_SPRING_VELOCITY = 140 -- one press adds 100; never let spam stack past this

local function playPressVFX()
	pressVelocity = math.min(pressVelocity + 100, MAX_SPRING_VELOCITY)
	counterVelocity = math.min(counterVelocity + 100, MAX_SPRING_VELOCITY)

	emitButtonParticles()
end

local localReadyAt = 0
local lastLocalPress = 0

clickDetector.MouseHoverEnter:Connect(function()
	playHoverJump()
end)

clickDetector.MouseClick:Connect(function()
	-- only a click that counts presses the button: cooldown ready AND the tree is standing
	local now = workspace:GetServerTimeNow()

	if (player:GetAttribute("BlueReadyAt") or 0) > now or (player:GetAttribute("TreeRespawnAt") or 0) > now then
		return
	end

	-- the server's cooldown takes a moment to come back; don't press again until it would be ready
	if now < localReadyAt then
		return
	end
	localReadyAt = now + math.max(IslandTwoConfig.cooldown(player) * 0.9, 0.1)

	lastLocalPress = os.clock()
	playPressVFX()
end)

-- every hit the server confirms presses the button, even if the click above guessed "not ready yet"
RS:WaitForChild("Remotes"):WaitForChild("WoodChop").OnClientEvent:Connect(function()
	if os.clock() - lastLocalPress > 0.25 then
		playPressVFX()
	end
	lastLocalPress = 0
end)
