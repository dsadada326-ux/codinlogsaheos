-- Join intro for brand-new players, right after the loading screen:
--   you fall out of the sky for ~5 seconds onto the loading-screen island (Workspace.LoadingScene),
--   filmed by a camera down on the ground looking up at you. Just before you hit the ground your eyes shut; while it's dark you're
--   moved to your real spawn (and we wait for it to load), then your eyes blink open there.
-- Doing the fall over the loading island means none of the real map has to load for it.
--
-- SettingsService (server) puts you on your spot and sets _IntroLanding; this plays the drop.
-- Only brand-new players get it (saved IntroPlayed flag). To preview it in Studio, select
-- Workspace and tick the PreviewJoinIntro attribute, then press Play.
-- When it's done this sets IntroFinished on the player (on this client), so a tutorial can start:
--   player:GetAttributeChangedSignal("IntroFinished"):Connect(startTutorial)
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local DROP_HEIGHT = 300      -- studs above the loading island
local FALL_TIME = 5          -- seconds from the top to the ground
local BLACKOUT_BEFORE = 0.5  -- the eyes shut this long before you'd hit the ground
local LAND_OFFSET = 11       -- land this far from the island's button, toward the camera side
local CAM_DISTANCE = 22      -- the camera sits on the ground this far from where you land...
local CAM_HEIGHT = 1.5       -- ...this high up, looking up at you as you fall
local SPAWN_WAIT = 6         -- max seconds (in the dark) to wait for the real spawn to load
local SETTLE_TIME = 1        -- then this long for the map's scripts to hide locked areas before waking up

local played = false

------------------------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------------------------
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- the first solid, visible thing straight below a point (skips invisible helper parts)
local function groundBelow(pos, ignore, depth)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(ignore)
	params.FilterDescendantsInstances = list

	for _ = 1, 10 do
		local hit = workspace:Raycast(pos, Vector3.new(0, -(depth or 200), 0), params)

		if not hit then
			return nil
		end

		if hit.Instance.Transparency < 1 then
			return hit.Position
		end

		table.insert(list, hit.Instance)
		params.FilterDescendantsInstances = list
	end

	return nil
end

-- lock movement: through the PlayerModule if the game has one, otherwise by zeroing
-- walk speed and jump (put back exactly as they were afterwards)
local function lockMovement(humanoid)
	local module = player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
	local controls

	if module then
		pcall(function()
			controls = require(module):GetControls()
			controls:Disable()
		end)
	end

	local speed, jumpPower, jumpHeight = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	return function()
		if controls then
			pcall(function()
				controls:Enable()
			end)
		end

		if humanoid.WalkSpeed == 0 then humanoid.WalkSpeed = speed end
		if humanoid.JumpPower == 0 then humanoid.JumpPower = jumpPower end
		if humanoid.JumpHeight == 0 then humanoid.JumpHeight = jumpHeight end
	end
end

-- hide the HUD for the cinematic; returns a function that brings it back
local function hideHud(except)
	local hidden = {}

	for _, gui in ipairs(player:WaitForChild("PlayerGui"):GetChildren()) do
		if gui:IsA("ScreenGui") and gui ~= except and gui.Name ~= "LoadingScreen" and gui.Enabled then
			gui.Enabled = false
			table.insert(hidden, gui)
		end
	end

	return function()
		for _, gui in ipairs(hidden) do
			if gui.Parent then
				gui.Enabled = true
			end
		end
	end
end

-- hide some parts on this screen only; returns a function that shows them again
local function hideParts(root)
	local hidden = {}

	if root then
		for _, d in ipairs(root:GetDescendants()) do
			if (d:IsA("BasePart") or d:IsA("Decal")) and d.LocalTransparencyModifier < 1 then
				table.insert(hidden, { inst = d, was = d.LocalTransparencyModifier })
				d.LocalTransparencyModifier = 1
			end
		end
	end

	return function()
		for _, h in ipairs(hidden) do
			if h.inst.Parent then
				h.inst.LocalTransparencyModifier = h.was
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- the eyelids (a black top and bottom lid with soft inner edges) + blur
------------------------------------------------------------------------------------------
local function makeEyes()
	local gui = Instance.new("ScreenGui")
	gui.Name = "JoinIntroEyes"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.Parent = player:WaitForChild("PlayerGui")

	local function lid(isTop)
		local frame = Instance.new("Frame")
		frame.Name = isTop and "TopLid" or "BottomLid"
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0, isTop and 0 or 1)
		frame.Position = UDim2.fromScale(0, isTop and 0 or 1)
		frame.Size = UDim2.fromScale(1, 0.5)
		frame.Parent = gui

		local edge = Instance.new("Frame")
		edge.Name = "Edge"
		edge.BackgroundColor3 = Color3.new(0, 0, 0)
		edge.BorderSizePixel = 0
		edge.AnchorPoint = Vector2.new(0, isTop and 0 or 1)
		edge.Position = UDim2.fromScale(0, isTop and 1 or 0)
		edge.Size = UDim2.new(1, 0, 0, 70)
		edge.Parent = frame

		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = isTop and NumberSequence.new(0, 1) or NumberSequence.new(1, 0)
		fade.Parent = edge

		return frame
	end

	local top = lid(true)
	local bottom = lid(false)

	local blur = Instance.new("BlurEffect")
	blur.Name = "JoinIntroBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local eyes = { gui = gui }

	-- open = 0 (shut) .. 1 (wide open)
	function eyes.set(open, time, style)
		local h = 0.5 * (1 - open)
		local info = TweenInfo.new(time or 0, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local off = open >= 1 and 70 or 0 -- slide fully open lids (and their soft edges) off-screen

		TweenService:Create(top, info, { Size = UDim2.fromScale(1, h), Position = UDim2.new(0, 0, 0, -off) }):Play()
		TweenService:Create(bottom, info, { Size = UDim2.fromScale(1, h), Position = UDim2.new(0, 0, 1, off) }):Play()

		if time and time > 0 then
			task.wait(time)
		end
	end

	function eyes.blur(size, time)
		TweenService:Create(blur, TweenInfo.new(time or 0, Enum.EasingStyle.Quad), { Size = size }):Play()
	end

	function eyes.destroy()
		gui:Destroy()
		blur:Destroy()
	end

	return eyes
end

------------------------------------------------------------------------------------------
-- the intro
------------------------------------------------------------------------------------------
local function play(landing)
	-- let the loading screen finish first (it stays black until our eyes take over)
	local waited = 0

	while player:GetAttribute("LoadingDone") ~= true and waited < 40 do
		waited += task.wait(0.1)
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5)
	local humanoid = character:WaitForChild("Humanoid", 5)

	if not (root and humanoid) then
		return
	end

	local eyes = makeEyes() -- starts shut
	eyes.set(0)
	local showHud = hideHud(eyes.gui)
	local unlock = lockMovement(humanoid)
	local oldFov = camera.FieldOfView
	local cleanup = {}

	local ok, err = pcall(function()
		local rotation = root.CFrame.Rotation
		local standOffset = humanoid.RigType == Enum.HumanoidRigType.R15
			and (humanoid.HipHeight + root.Size.Y / 2)
			or 3

		-- the loading island (always loaded for everyone)
		local scene = workspace:WaitForChild("LoadingScene", 10)
		local cap = scene and scene:FindFirstChild("RedButton") and scene.RedButton:FindFirstChild("Button")
			and scene.RedButton.Button:FindFirstChild("Button")
		local camPart = scene and scene:FindFirstChild("Island") and scene.Island:FindFirstChild("CameraPosition")

		-- no loading island? just drop onto the real spot instead
		local center = cap and cap.Position or landing
		local towardCam = camPart and flat(camPart.Position - center) or Vector3.new(-1, 0, 0)
		towardCam = towardCam.Magnitude > 0.01 and towardCam.Unit or Vector3.new(-1, 0, 0)
		local fallSpot = cap and (center + towardCam * LAND_OFFSET) or landing

		local ignore = { character }
		local groundPos = groundBelow(Vector3.new(fallSpot.X, fallSpot.Y + 80, fallSpot.Z), ignore, 200)
			or (fallSpot - Vector3.new(0, 3, 0))
		local fallStand = Vector3.new(fallSpot.X, groundPos.Y + standOffset, fallSpot.Z)
		local topPos = fallStand + Vector3.new(0, DROP_HEIGHT, 0)

		-- the cursors shouldn't be around for this
		if cap then
			local cursors = cap.Parent:FindFirstChild("ClickCursors")
			table.insert(cleanup, hideParts(cursors))
		end

		-- start loading the real spawn in the background while we fall
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(landing, SPAWN_WAIT)
			end)
		end)

		-- face the button while falling
		if cap then
			rotation = CFrame.lookAt(fallStand, Vector3.new(center.X, fallStand.Y, center.Z)).Rotation
		end

		root.Anchored = true
		root.CFrame = CFrame.new(topPos) * rotation

		-- the camera: down on the ground, a bit away from where you'll land, looking up at you.
		-- It sits out past the landing spot (away from the button) and a little to the side,
		-- pulled in if something's in the way.
		local side = Vector3.new(-towardCam.Z, 0, towardCam.X)
		local camDir = (towardCam + side * 0.45).Unit
		local camFrom = Vector3.new(fallSpot.X, groundPos.Y + CAM_HEIGHT, fallSpot.Z)
		local camParams = RaycastParams.new()
		camParams.FilterType = Enum.RaycastFilterType.Exclude
		camParams.FilterDescendantsInstances = { character }
		local blocked = workspace:Raycast(camFrom, camDir * CAM_DISTANCE, camParams)
		local camPos = camFrom + camDir * (blocked and math.max(blocked.Distance - 1.5, 6) or CAM_DISTANCE)

		local function follow(target)
			camera.CFrame = CFrame.lookAt(camPos, target)
		end

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 30 -- zoomed in on the tiny figure way up high...
		follow(topPos)

		-- trail
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 1.2, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -1.2, 0)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.6
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 220, 255))
		trail.Transparency = NumberSequence.new(0.15, 1)
		trail.WidthScale = NumberSequence.new(1.4, 0)
		trail.Parent = root
		table.insert(cleanup, function()
			trail:Destroy()
			a0:Destroy()
			a1:Destroy()
		end)

		-- open on the sky
		eyes.set(1, 0.6)

		-- the fall (we move you along the curve ourselves, so nothing can tunnel through)
		root.Anchored = false
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

		local t = 0
		local drop = topPos.Y - fallStand.Y
		local shut = false

		while t < FALL_TIME do
			local dt = RunService.Heartbeat:Wait()
			t += dt

			local a = math.clamp(t / FALL_TIME, 0, 1)
			local eased = 0.3 * a + 0.7 * a * a -- already moving at the start, speeding up
			local y = topPos.Y - drop * eased

			root.CFrame = CFrame.new(fallStand.X, y, fallStand.Z) * rotation
			root.AssemblyLinearVelocity = Vector3.new(0, -drop * (0.3 + 1.4 * a) / FALL_TIME, 0)

			camera.FieldOfView = 30 + 45 * a -- ...widening as you get close
			follow(root.Position)

			-- eyes shut just before you hit the ground
			if not shut and t >= FALL_TIME - BLACKOUT_BEFORE then
				shut = true
				task.spawn(eyes.set, 0, BLACKOUT_BEFORE * 0.8)
			end
		end

		-- in the dark: thud, then move to the real spawn and wait for it to load
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxasset://sounds/action_jump_land.mp3"
		sound.Volume = 1.5
		sound.PlaybackSpeed = 0.5
		sound.Parent = root
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 3)

		for _, fn in ipairs(cleanup) do
			fn()
		end

		table.clear(cleanup)

		root.Anchored = true
		root.CFrame = CFrame.new(landing) * root.CFrame.Rotation
		root.AssemblyLinearVelocity = Vector3.zero

		pcall(function()
			player:RequestStreamAroundAsync(landing, SPAWN_WAIT)
		end)

		-- stand on whatever is under the spawn, once it has loaded
		local spawnGround
		local start = os.clock()

		repeat
			spawnGround = groundBelow(landing + Vector3.new(0, 4, 0), { character }, 40)

			if not spawnGround then
				task.wait(0.1)
			end
		until spawnGround or os.clock() - start > SPAWN_WAIT

		local standPos = spawnGround and (spawnGround + Vector3.new(0, standOffset, 0)) or landing
		local look = flat(rotation.LookVector)
		look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
		root.CFrame = CFrame.lookAt(standPos, standPos + look)
		root.Anchored = false
		humanoid:ChangeState(Enum.HumanoidStateType.Landed)

		-- the area has just streamed in: let the scripts that hide locked areas catch up
		task.wait(SETTLE_TIME)

		-- behind you, ready for when the eyes open
		camera.FieldOfView = oldFov
		local head = character:FindFirstChild("Head") or root
		camera.CFrame = CFrame.lookAt(root.Position - look * 12 + Vector3.new(0, 5, 0), head.Position)
		camera.CameraType = Enum.CameraType.Custom

		-- blink awake
		eyes.blur(24)
		task.wait(0.6)
		eyes.set(0.18, 0.35)          -- a crack of light
		eyes.set(0, 0.14)             -- ...shut
		task.wait(0.2)
		eyes.blur(14, 0.3)
		eyes.set(0.5, 0.3)            -- a bit more
		eyes.set(0.05, 0.12)          -- ...blink
		eyes.blur(0, 0.9)
		eyes.set(1, 0.7, Enum.EasingStyle.Sine) -- wide awake
	end)

	if not ok then
		warn("[JoinIntro] " .. tostring(err))
	end

	-- always give everything back, even if something above failed
	for _, fn in ipairs(cleanup) do
		fn()
	end

	root.Anchored = false
	camera.FieldOfView = oldFov
	camera.CameraType = Enum.CameraType.Custom
	eyes.destroy()
	showHud()
	unlock()
	player:SetAttribute("IntroFinished", true)
end

local function tryPlay()
	local landing = player:GetAttribute("_IntroLanding")

	if played or typeof(landing) ~= "Vector3" then
		return
	end

	played = true
	task.spawn(play, landing)
end

player:GetAttributeChangedSignal("_IntroLanding"):Connect(tryPlay)
tryPlay()
