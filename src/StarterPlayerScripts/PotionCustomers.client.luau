-- Laboratory potion stand customers (just for looks, only on your screen).
-- Your Roblox friends (their real avatars + names) walk up the path, queue at the
-- Potion Stand, "buy" a potion, and walk off. If you don't have many friends, a few
-- famous Roblox accounts fill in.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local SETTINGS = {
	MaxCustomers = 4, -- walking around at once
	SpawnEvery = { 3, 6 }, -- seconds between new customers (random in this range)
	BuySeconds = 2.2, -- how long a customer stands at the counter
	QueueGap = 3.6, -- studs between people in the line
	WalkSpeed = 13,
	ActiveRange = 230, -- only runs while you're this close to the stand
	FallbackIds = { 156, 261, 1, 2032622, 16, 18, 1052, 3 }, -- used when you don't have enough friends
}

local POTIONS = {
	{ name = "Speed Potion", color = Color3.fromRGB(80, 200, 255) },
	{ name = "Luck Potion", color = Color3.fromRGB(90, 255, 120) },
	{ name = "Strength Potion", color = Color3.fromRGB(255, 90, 90) },
	{ name = "Mystery Potion", color = Color3.fromRGB(190, 110, 255) },
	{ name = "Golden Potion", color = Color3.fromRGB(255, 210, 60) },
}
local ASK = { "One potion please!", "What's good today?", "I need a boost!", "Heard these are fire", "Gimme the purple one", "Take my money!" }
local THANKS = { "Thanks!", "Let's gooo!", "W stand", "See ya!", "Worth it!", "Coming back tmrw" }

local FONT = Font.fromEnum(Enum.Font.FredokaOne)

------------------------------------------------------------------------------------------
-- the stand + the path
------------------------------------------------------------------------------------------
local labFolder = workspace:WaitForChild("Labratory")
local stand = labFolder:WaitForChild("PotionStand")
local anchor = stand:WaitForChild("PromptAnchor")

-- the long path the stand sits on (the biggest "Ground" part in the Labratory)
local function findPath()
	local best
	for _, p in ipairs(labFolder:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Ground" then
			if not best or p.Size.X * p.Size.Z > best.Size.X * best.Size.Z then best = p end
		end
	end
	return best
end

local pathPart
for _ = 1, 40 do
	pathPart = findPath()
	if pathPart then break end
	task.wait(0.5)
end
if not pathPart then return end

local standCF = stand:GetBoundingBox()
local front = Vector3.new(anchor.Position.X - standCF.X, 0, anchor.Position.Z - standCF.Z).Unit
local groundY = pathPart.Position.Y + pathPart.Size.Y / 2

-- the counter spot, and the far end of the path the customers come from
local counterSpot = Vector3.new(anchor.Position.X, groundY, anchor.Position.Z) + front * 2.2
local pathLong = pathPart.CFrame:VectorToWorldSpace(pathPart.Size.X > pathPart.Size.Z and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1))
pathLong = Vector3.new(pathLong.X, 0, pathLong.Z).Unit
if pathLong:Dot(front) < 0 then pathLong = -pathLong end
local halfLen = math.max(pathPart.Size.X, pathPart.Size.Z) / 2
-- how far along the path the stand is from the path's middle
local along = (counterSpot - Vector3.new(pathPart.Position.X, groundY, pathPart.Position.Z)):Dot(pathLong)
local farEnd = counterSpot + pathLong * (halfLen - along - 6)

local function queueSpot(i)
	return counterSpot + front * ((i - 1) * SETTINGS.QueueGap)
end

------------------------------------------------------------------------------------------
-- who can show up: your friends (+ fallbacks)
------------------------------------------------------------------------------------------
local people = {} -- { userId, name }
task.spawn(function()
	local ok, pages = pcall(function() return Players:GetFriendsAsync(player.UserId) end)
	if ok and pages then
		while true do
			for _, f in ipairs(pages:GetCurrentPage()) do
				table.insert(people, { id = f.Id, name = f.DisplayName or f.Username })
			end
			if pages.IsFinished or #people >= 200 then break end
			local okNext = pcall(function() pages:AdvanceToNextPageAsync() end)
			if not okNext then break end
		end
	end
	if #people < 5 then
		for _, id in ipairs(SETTINGS.FallbackIds) do
			local okName, name = pcall(function() return Players:GetNameFromUserIdAsync(id) end)
			table.insert(people, { id = id, name = okName and name or "Customer" })
		end
	end
end)

-- avatars are cached so each friend only loads once
local avatarCache = {}
local function avatarFor(person)
	if avatarCache[person.id] == nil then
		local ok, model = pcall(function() return Players:CreateHumanoidModelFromUserId(person.id) end)
		avatarCache[person.id] = ok and model or false
	end
	local m = avatarCache[person.id]
	return m and m:Clone() or nil
end

------------------------------------------------------------------------------------------
-- little visuals
------------------------------------------------------------------------------------------
local function nameTag(model, text)
	local head = model:FindFirstChild("Head")
	if not head then return end
	local g = Instance.new("BillboardGui")
	g.Name = "CustomerName"
	g.Size = UDim2.fromOffset(160, 26)
	g.StudsOffset = Vector3.new(0, 2.3, 0)
	g.MaxDistance = 80
	g.LightInfluence = 0
	g.Adornee = head
	g.Parent = head
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = FONT
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = g
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Parent = t
end

local function bubble(model, text, color)
	local head = model:FindFirstChild("Head")
	if not head then return end
	local old = head:FindFirstChild("Speech")
	if old then old:Destroy() end
	local g = Instance.new("BillboardGui")
	g.Name = "Speech"
	g.Size = UDim2.fromOffset(190, 44)
	g.StudsOffset = Vector3.new(0, 4.2, 0)
	g.MaxDistance = 70
	g.LightInfluence = 0
	g.Adornee = head
	g.Parent = head
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = g
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.4, 0)
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Color3.fromRGB(20, 20, 30)
	st.Parent = f
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.92, 0.8)
	t.Position = UDim2.fromScale(0.04, 0.1)
	t.FontFace = FONT
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or Color3.fromRGB(30, 30, 40)
	t.Parent = f
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = f
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.8, function()
		if g.Parent then
			TweenService:Create(sc, TweenInfo.new(0.2), { Scale = 0 }):Play()
			task.wait(0.2)
			g:Destroy()
		end
	end)
end

-- a potion that hops from the counter into the customer's hands, and a "SOLD!" pop
local function sellEffect(model, potion)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(0.9, 0.9, 0.9)
	p.Material = Enum.Material.Neon
	p.Color = potion.color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(anchor.Position + Vector3.new(0, 1.5, 0))
	p.Parent = workspace
	local neck = Instance.new("Part")
	neck.Size = Vector3.new(0.35, 0.45, 0.35)
	neck.Material = Enum.Material.Glass
	neck.Color = Color3.fromRGB(220, 240, 255)
	neck.Anchored = true
	neck.CanCollide = false
	neck.CanQuery = false
	neck.Parent = p
	local light = Instance.new("PointLight")
	light.Color = potion.color
	light.Range = 6
	light.Parent = p
	local target = root.Position + Vector3.new(0, 0.2, 0) - front * 0.8
	local start = p.Position
	local v = Instance.new("NumberValue")
	v:GetPropertyChangedSignal("Value"):Connect(function()
		local k = v.Value
		local pos = start:Lerp(target, k) + Vector3.new(0, math.sin(k * math.pi) * 2.5, 0)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(0, k * 8, 0)
		neck.CFrame = p.CFrame * CFrame.new(0, 0.6, 0)
	end)
	TweenService:Create(v, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Value = 1 }):Play()
	task.delay(0.6, function()
		-- the potion sticks to the customer's right hand
		local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
		v:Destroy()
		if hand and model.Parent then
			p.Anchored = false
			neck.Anchored = false
			p.Massless = true
			neck.Massless = true
			p.CFrame = hand.CFrame * CFrame.new(0, -0.9, -0.2)
			neck.CFrame = p.CFrame * CFrame.new(0, 0.6, 0)
			local w1 = Instance.new("WeldConstraint") w1.Part0 = hand w1.Part1 = p w1.Parent = p
			local w2 = Instance.new("WeldConstraint") w2.Part0 = p w2.Part1 = neck w2.Parent = p
			p.Parent = model
		else
			p:Destroy()
		end
	end)
	-- "SOLD!" above the counter
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(200, 40)
	g.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	g.LightInfluence = 0
	g.AlwaysOnTop = true
	g.MaxDistance = 90
	g.Adornee = anchor
	g.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = FONT
	t.TextScaled = true
	t.Text = "SOLD! " .. potion.name
	t.TextColor3 = potion.color
	t.Parent = g
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Parent = t
	TweenService:Create(g, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(0, 8, 0) }):Play()
	task.delay(0.7, function()
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
	task.delay(1.2, function() g:Destroy() end)
end

------------------------------------------------------------------------------------------
-- customers
------------------------------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "PotionCustomers"
folder.Parent = workspace

local queue = {} -- customers waiting / at the counter, in order
local alive = 0

local ANIMS = {
	[Enum.HumanoidRigType.R15] = { walk = "rbxassetid://507777826", idle = "rbxassetid://507766666", wave = "rbxassetid://507770239" },
	[Enum.HumanoidRigType.R6] = { walk = "rbxassetid://180426354", idle = "rbxassetid://180435571", wave = "rbxassetid://128777973" },
}

local function walkTo(c, pos)
	local hum = c.humanoid
	if not (hum and hum.Parent) then return false end
	c.walking = true
	local done = false
	local conn = hum.MoveToFinished:Connect(function() done = true end)
	local t0 = os.clock()
	while not done and hum.Parent and os.clock() - t0 < 25 do
		hum:MoveTo(pos) -- re-issue (MoveTo gives up after 8 seconds)
		local t1 = os.clock()
		while not done and os.clock() - t1 < 6 and hum.Parent do
			local root = c.root
			if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < 1.2 then
				done = true
			end
			task.wait(0.1)
		end
	end
	conn:Disconnect()
	c.walking = false
	return hum.Parent ~= nil
end

local function faceStand(c)
	if c.root then
		local pos = c.root.Position
		c.root.CFrame = CFrame.lookAt(pos, pos - Vector3.new(front.X, 0, front.Z))
	end
end

local function positionOf(c)
	for i, q in ipairs(queue) do
		if q == c then return i end
	end
end

local function despawn(c)
	alive -= 1
	local model = c.model
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end
	task.delay(0.55, function() model:Destroy() end)
end

local function spawnCustomer()
	if #people == 0 then return end
	local person = people[math.random(1, #people)]
	local model = avatarFor(person)
	if not model then return end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (hum and root) then model:Destroy() return end

	model.Name = "Customer_" .. person.name
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = SETTINGS.WalkSpeed + math.random(-2, 2)
	hum.BreakJointsOnDeath = false
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local side = Vector3.new(-pathLong.Z, 0, pathLong.X) * math.random(-40, 40) / 10
	local start = farEnd + side
	model:PivotTo(CFrame.lookAt(start + Vector3.new(0, hum.HipHeight + root.Size.Y / 2 + 0.3, 0), counterSpot + Vector3.new(0, 3, 0)))
	model.Parent = folder
	nameTag(model, person.name)

	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local ids = ANIMS[hum.RigType] or ANIMS[Enum.HumanoidRigType.R15]
	local function load(id)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(a) end)
		return ok and track or nil
	end
	local walk, idle, wave = load(ids.walk), load(ids.idle), load(ids.wave)
	if idle then idle.Looped = true idle:Play() end
	hum.Running:Connect(function(speed)
		if not walk then return end
		if speed > 0.5 then
			if not walk.IsPlaying then walk:Play(0.15) end
			walk:AdjustSpeed(speed / 14)
		elseif walk.IsPlaying then
			walk:Stop(0.2)
		end
	end)

	local c = { model = model, humanoid = hum, root = root, person = person }
	alive += 1
	table.insert(queue, c)

	task.spawn(function()
		-- walk up and take a place in line, stepping forward as the line moves
		local myPlace = positionOf(c)
		walkTo(c, queueSpot(myPlace))
		while model.Parent do
			local place = positionOf(c)
			if place == 1 then break end
			if place ~= myPlace then
				myPlace = place
				walkTo(c, queueSpot(place))
			end
			faceStand(c)
			task.wait(0.3)
		end
		if not model.Parent then return end
		-- at the counter
		walkTo(c, queueSpot(1))
		faceStand(c)
		local potion = POTIONS[math.random(1, #POTIONS)]
		bubble(model, ASK[math.random(1, #ASK)])
		task.wait(SETTINGS.BuySeconds * 0.5)
		sellEffect(model, potion)
		task.wait(SETTINGS.BuySeconds * 0.5)
		if wave then wave:Play() end
		bubble(model, THANKS[math.random(1, #THANKS)], Color3.fromRGB(30, 140, 60))
		-- leave the line and walk off down the path
		local i = positionOf(c)
		if i then table.remove(queue, i) end
		local away = Vector3.new(-pathLong.Z, 0, pathLong.X) * (math.random() < 0.5 and -6 or 6)
		walkTo(c, counterSpot + front * 3 + away)
		walkTo(c, farEnd + away * 1.2)
		despawn(c)
	end)
end

-- keep customers coming while you're nearby
task.spawn(function()
	while true do
		local wait = math.random(SETTINGS.SpawnEvery[1] * 10, SETTINGS.SpawnEvery[2] * 10) / 10
		task.wait(wait)
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if myRoot and (myRoot.Position - counterSpot).Magnitude < SETTINGS.ActiveRange and alive < SETTINGS.MaxCustomers then
			task.spawn(spawnCustomer)
		end
	end
end)
