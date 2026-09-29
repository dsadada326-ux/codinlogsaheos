-- Fishing Frenzy (client): fishing with your rod + the island's HUD rules.
--   Equip your rod, stand on a bridge, HOLD to charge the power bar and RELEASE to throw. The bobber lands in the pond, a fish
--   bites (bobber dips + "!"), click again to reel it in. Off a bridge: "Stand on a bridge".
--   While on Fishing Frenzy: the Rods/Sell/Upgrades buttons show, the bottom menu bar slides
--   to the bottom-left corner (so the hotbar has room) and "Total Fish Caught" shows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingConfig"))
local FishingFrenzyConfig = require(ReplicatedStorage:WaitForChild("FishingFrenzyConfig"))
local DrillConfig = require(ReplicatedStorage:WaitForChild("DrillConfig")) -- Drilling Mania uses the same corner menu
local LabConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("LabConfig"))
local FishingVisuals = require(ReplicatedStorage:WaitForChild("FishingVisuals"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local castRemote = remotes:WaitForChild("FishingCast")
local reelRemote = remotes:WaitForChild("FishingReel")
local eventRemote = remotes:WaitForChild("FishingEvent")

local assets = ReplicatedStorage:WaitForChild("FishingAssets")
local island = workspace:WaitForChild("Islands"):WaitForChild(FishingConfig.IslandName)

local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local function flat(v)
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 0.001 and v.Unit or Vector3.new(0, 0, -1)
end

local function abbreviate(n)
	return NumberFormat.abbreviate(math.floor(n + 0.5))
end

------------------------------------------------------------------------------------------
-- HUD pieces
------------------------------------------------------------------------------------------
local hud = Instance.new("ScreenGui")
hud.Name = "FishingHUD"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = false
hud.DisplayOrder = 5
hud.Parent = playerGui

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r or 0.2, 0)
	c.Parent = p
end

local function stroke(p, t, c)
	local s = Instance.new("UIStroke")
	s.Thickness = t or 2
	s.Color = c or Color3.fromRGB(10, 15, 25)
	s.Parent = p
	return s
end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do l[k] = v end
	stroke(l, 2)
	l.Parent = parent
	return l
end

-- bucket counter (above the hotbar)
local bucket = Instance.new("Frame")
bucket.Name = "Bucket"
bucket.AnchorPoint = Vector2.new(0.5, 1)
bucket.Position = UDim2.new(0.5, 0, 1, -96)
bucket.Size = UDim2.fromOffset(150, 30)
bucket.BackgroundColor3 = Color3.fromRGB(20, 45, 70)
bucket.BackgroundTransparency = 0.25
bucket.Visible = false
bucket.Parent = hud
corner(bucket, 0.5)
stroke(bucket, 2, Color3.fromRGB(90, 200, 255))
local bucketLabel = text(bucket, { Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Text = "🪣 0 / 20" })

local function paintBucket()
	local carried = player:GetAttribute("FishCarried") or 0
	local cap = FishingConfig.backpackSize(player)
	bucketLabel.Text = "🪣 " .. carried .. " / " .. cap
	bucketLabel.TextColor3 = carried >= cap and Color3.fromRGB(255, 110, 110) or Color3.new(1, 1, 1)
end

-- the catch card
local card = Instance.new("Frame")
card.Name = "CatchCard"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, -160)
card.Size = UDim2.fromOffset(380, 118)
card.BackgroundColor3 = Color3.fromRGB(18, 26, 40)
card.BackgroundTransparency = 0.08
card.Parent = hud
corner(card, 0.14)
local cardStroke = stroke(card, 4, Color3.new(1, 1, 1))
local cardGrad = Instance.new("UIGradient")
cardGrad.Rotation = 90
cardGrad.Parent = card

local viewport = Instance.new("ViewportFrame")
viewport.BackgroundTransparency = 1
viewport.Position = UDim2.fromOffset(8, 6)
viewport.Size = UDim2.fromOffset(120, 106)
viewport.Parent = card
local vpCam = Instance.new("Camera")
vpCam.FieldOfView = 40
vpCam.Parent = viewport
viewport.CurrentCamera = vpCam

local rarityLabel = text(card, { Position = UDim2.fromOffset(134, 8), Size = UDim2.new(1, -144, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
local nameLabel = text(card, { Position = UDim2.fromOffset(134, 34), Size = UDim2.new(1, -144, 0, 38), TextXAlignment = Enum.TextXAlignment.Left })
local infoLabel = text(card, { Position = UDim2.fromOffset(134, 76), Size = UDim2.new(1, -144, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, RichText = true, TextColor3 = Color3.fromRGB(215, 235, 255) })

local cardToken = 0
local spinModel

local FishingReveal = require(ReplicatedStorage:WaitForChild("FishingReveal"))
card.Visible = false -- the old box; the big reveal replaced it

local function showCatch(result)
	FishingReveal.show(result, FishingVisuals.rarityColor)
end

RunService.RenderStepped:Connect(function(dt)
	if spinModel and spinModel.Parent then
		spinModel:PivotTo(spinModel:GetPivot() * CFrame.Angles(0, dt * 1.4, 0))
	end
end)

-- big celebration text (tier up / prestige)
local function celebrate(message, color)
	local l = text(hud, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.6, 0.1),
		Text = message, TextColor3 = color,
	})
	local s = Instance.new("UIScale")
	s.Scale = 0
	s.Parent = l
	TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.2, function()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		l:Destroy()
	end)
end

------------------------------------------------------------------------------------------
-- fishing
------------------------------------------------------------------------------------------
local state = "idle" -- idle / casting / waiting / bite / reeling
local session -- the current cast
local arm

local function bridgeList()
	local list = {}
	for _, b in ipairs(island:GetChildren()) do
		if b:GetAttribute("BridgeIndex") then
			table.insert(list, b)
		end
	end
	return list
end

local function onBridge(root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = bridgeList()
	return workspace:Raycast(root.Position, Vector3.new(0, -9, 0), params) ~= nil
end

local function isWaterAt(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = bridgeList()
	table.insert(ignore, player.Character)
	table.insert(ignore, FishingVisuals.folder)
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, FishingVisuals.waterY + 20, z), Vector3.new(0, -40, 0), params)
	return hit and (hit.Instance == FishingVisuals.water or hit.Instance:IsDescendantOf(FishingVisuals.water))
end

local function castTarget(root, scale)
	scale = scale or 1
	local look = flat(root.CFrame.LookVector)
	local toPond = flat(FishingVisuals.water.Position - root.Position)
	for _, dir in ipairs({ look, (look + toPond).Unit, toPond }) do
		for _, dist in ipairs({ FishingConfig.CastDistance * scale, FishingConfig.CastDistance, FishingConfig.CastDistance * 0.7, FishingConfig.CastDistance * 1.3 }) do
			local p = root.Position + dir * dist
			if isWaterAt(p.X, p.Z) then
				return Vector3.new(p.X, FishingVisuals.waterY, p.Z)
			end
		end
	end
	return nil
end

local function rodTool()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("FishingTool") == "Rod" then
		return tool
	end
	return nil
end

local function tipOf(tool)
	local handle = tool and tool:FindFirstChild("Handle")
	return handle and handle:FindFirstChild("Tip")
end

local function endSession()
	if session then
		if session.alert then session.alert:Destroy() end
		if session.exclaim then session.exclaim:Destroy() end
		if session.bobber then session.bobber:destroy() end
	end
	session = nil
	state = "idle"
	if arm then arm:idle() end
end

local function exclamation(bobber)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(2.2, 2.2)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = bobber.model.PrimaryPart
	gui.Parent = bobber.model
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = "!"
	l.TextColor3 = Color3.fromRGB(255, 70, 70)
	l.Parent = gui
	stroke(l, 3, Color3.new(1, 1, 1))
	local s = Instance.new("UIScale")
	s.Scale = 0
	s.Parent = l
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	return gui
end

local function flyFish(fishId, from, character)
	local source = assets.Fish:FindFirstChild(fishId)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not source or not root then return end
	local model = source:Clone()
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false end
	end
	model.Parent = FishingVisuals.folder
	local start = os.clock()
	local T = 0.8
	while true do
		local k = math.clamp((os.clock() - start) / T, 0, 1)
		local to = root.Position + Vector3.new(0, 4.5, 0)
		local p = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 6, 0)
		model:PivotTo(CFrame.new(p) * CFrame.Angles(0, k * 9, math.sin(k * 20) * 0.4))
		if k >= 1 then break end
		RunService.RenderStepped:Wait()
	end
	task.wait(0.35)
	model:Destroy()
end

------------------------------------------------------------------------------------------
-- bite alert: a big red "!" pops up over your head when something bites
------------------------------------------------------------------------------------------
local function headAlert()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return nil end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BiteAlert"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(90, 120)
	gui.StudsOffset = Vector3.new(0, 1.4, 0)
	gui.SizeOffset = Vector2.new(0, 0.5) -- bottom edge sits just above the head
	gui.MaxDistance = 200
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = playerGui
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.FontFace = FONT
	l.TextScaled = true
	l.Text = "!"
	l.TextColor3 = Color3.fromRGB(255, 70, 80)
	l.Parent = gui
	local st = Instance.new("UIStroke")
	st.Thickness = 5
	st.Color = Color3.fromRGB(255, 255, 255)
	st.Parent = l
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = l
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- wobble while it waits for you
	task.spawn(function()
		local t0 = os.clock()
		while gui.Parent do
			l.Rotation = math.sin((os.clock() - t0) * 18) * 8
			RunService.RenderStepped:Wait()
		end
	end)
	return gui
end

------------------------------------------------------------------------------------------
-- the reel fight: MASH TO REEL! The line starts at 40%, the fish drags it down every second,
-- every click pulls it up. Get it into the green to land the fish; hit 0 and it escapes.
------------------------------------------------------------------------------------------
local fightGui = Instance.new("Frame")
fightGui.Name = "ReelFight"
fightGui.AnchorPoint = Vector2.new(0.5, 1)
fightGui.Position = UDim2.new(0.5, 0, 1, -110)
fightGui.Size = UDim2.new(0.42, 0, 0, 96)
fightGui.BackgroundTransparency = 1
fightGui.Visible = false
fightGui.Parent = hud
local fightLimit = Instance.new("UISizeConstraint")
fightLimit.MaxSize = Vector2.new(720, 96)
fightLimit.MinSize = Vector2.new(300, 80)
fightLimit.Parent = fightGui
local fightScale = Instance.new("UIScale")
fightScale.Parent = fightGui

local fightTitle = text(fightGui, {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, 34),
	Text = "MASH TO REEL!", TextColor3 = Color3.fromRGB(120, 245, 255),
})
fightTitle:FindFirstChildOfClass("UIStroke").Thickness = 3
local fightTitleScale = Instance.new("UIScale")
fightTitleScale.Parent = fightTitle

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 1)
track.Position = UDim2.fromScale(0.5, 1)
track.Size = UDim2.new(1, 0, 0, 52)
track.BackgroundColor3 = Color3.fromRGB(18, 30, 52)
track.Parent = fightGui
corner(track, 0.35)
local trackStroke = stroke(track, 5, Color3.fromRGB(8, 10, 16))
trackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- the danger -> safe colour wash behind the line
local wash = Instance.new("Frame")
wash.BackgroundColor3 = Color3.new(1, 1, 1)
wash.BackgroundTransparency = 0.15
wash.Size = UDim2.fromScale(1, 1)
wash.Parent = track
corner(wash, 0.35)
local washGrad = Instance.new("UIGradient")
washGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 60, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 185, 50)),
	ColorSequenceKeypoint.new(0.87, Color3.fromRGB(60, 150, 230)),
	ColorSequenceKeypoint.new(0.88, Color3.fromRGB(80, 230, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 230, 90)),
})
washGrad.Parent = wash

-- the green goal zone (glows)
local goalZone = Instance.new("Frame")
goalZone.AnchorPoint = Vector2.new(1, 0)
goalZone.Position = UDim2.fromScale(1, 0)
goalZone.Size = UDim2.fromScale(0.12, 1)
goalZone.BackgroundColor3 = Color3.fromRGB(90, 255, 110)
goalZone.BackgroundTransparency = 0.1
goalZone.Parent = track
corner(goalZone, 0.35)
local goalText = text(goalZone, { Size = UDim2.fromScale(1, 0.7), Position = UDim2.fromScale(0, 0.15), Text = "✓", TextColor3 = Color3.new(1, 1, 1) })

-- progress fill (how far you've pulled it)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0.4, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.BackgroundTransparency = 0.6
fill.Parent = track
corner(fill, 0.35)

-- the line (marker)
local lineMarker = Instance.new("Frame")
lineMarker.AnchorPoint = Vector2.new(0.5, 0.5)
lineMarker.Position = UDim2.fromScale(0.4, 0.5)
lineMarker.Size = UDim2.new(0, 10, 1, 18)
lineMarker.BackgroundColor3 = Color3.new(1, 1, 1)
lineMarker.ZIndex = 3
lineMarker.Parent = track
corner(lineMarker, 1)
stroke(lineMarker, 3, Color3.fromRGB(8, 10, 16)).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local fishIcon = text(lineMarker, {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(34, 30), Text = "🐟", ZIndex = 4,
})

local tapHint = text(fightGui, {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 1, 4), Size = UDim2.new(0.5, 0, 0, 20),
	Text = "Click / Tap / Space", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(210, 230, 255),
})

local fight = nil -- the running fight

local function stopFight()
	fight = nil
	fightGui.Visible = false
end

local function mash()
	if not fight then return end
	fight.progress = math.min(1, fight.progress + fight.click)
	fight.lastClick = os.clock()
	fightTitleScale.Scale = 1.15
	TweenService:Create(fightTitleScale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if arm then arm:reel() end
end

-- success / failure visuals shared by the fight and the early/late cases
local function landFish(s, result)
	local tool = rodTool()
	local tip = tipOf(tool)
	local bobberPos = s.bobber.model:GetPivot().Position
	FishingVisuals.splash(bobberPos, 1.3)
	task.spawn(flyFish, result.fish, bobberPos, player.Character)
	s.bobber:reelTo(function()
		return tip and tip.WorldPosition or bobberPos
	end, 0.45)
	showCatch(result)
	paintBucket()
	if result.carried and result.capacity and result.carried >= result.capacity then
		task.delay(1.2, function() MessageToPlayer.show("BucketFull") end)
	end
end

local function loseFish(s, message)
	if message then MessageToPlayer.show(message) end
	local tool = rodTool()
	local tip = tipOf(tool)
	local bobberPos = s.bobber.model:GetPivot().Position
	s.bobber:reelTo(function()
		return tip and tip.WorldPosition or bobberPos
	end, 0.4)
end

-- clicked before a bite, or never clicked: the fish is gone
local function reel(early)
	if not session then return end
	local s = session
	state = "reeling"
	if s.exclaim then s.exclaim:Destroy() s.exclaim = nil end
	if s.alert then s.alert:Destroy() s.alert = nil end
	pcall(function() reelRemote:InvokeServer(s.id, "escape") end)
	loseFish(s, early and "TooEarly" or "GotAway")
	if session == s then endSession() end
end

-- clicked while it bites: hook it and start the fight
local function hookFish()
	if not session then return end
	local s = session
	state = "fighting"
	if s.exclaim then s.exclaim:Destroy() s.exclaim = nil end
	if s.alert then s.alert:Destroy() s.alert = nil end

	local ok, result = pcall(function()
		return reelRemote:InvokeServer(s.id, "hook")
	end)
	if not (ok and type(result) == "table" and result.ok) then
		local reason = ok and type(result) == "table" and result.reason
		loseFish(s, reason == "early" and "TooEarly" or reason == "full" and "BucketFull" or "GotAway")
		if session == s then endSession() end
		return
	end

	local cfg = result.fight
	fight = { progress = cfg.start, click = cfg.click, drain = cfg.drain, goal = cfg.goal, started = os.clock(), lastClick = os.clock() }
	local myFight = fight
	fightTitle.Text = "MASH TO REEL!"
	fightTitle.TextColor3 = Color3.fromRGB(120, 245, 255)
	goalZone.Size = UDim2.fromScale(1 - cfg.goal, 1)
	fishIcon.TextColor3 = FishingVisuals.rarityColor(result.rarity)
	fightGui.Visible = true
	fightScale.Scale = 0.6
	TweenService:Create(fightScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if arm then arm:reel() end

	-- the bobber gets dragged about while you fight it
	local tool = rodTool()
	local tip = tipOf(tool)
	local startPos = s.bobber.model:GetPivot().Position
	local won
	while fight == myFight and session == s do
		local dt = RunService.RenderStepped:Wait()
		local t = os.clock() - fight.started
		-- the fish pulls harder in bursts
		local surge = 1 + 0.6 * math.max(0, math.sin(t * 2.3)) ^ 3
		fight.progress -= fight.drain * surge * dt
		local p = math.clamp(fight.progress, 0, 1)
		fill.Size = UDim2.fromScale(p, 1)
		lineMarker.Position = UDim2.new(p, 0, 0.5, math.sin(t * 40) * (surge > 1.3 and 3 or 1))
		trackStroke.Color = p < 0.2 and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(8, 10, 16)
		-- bobber creeps towards you as you win
		if s.bobber and s.bobber.model.Parent and tip then
			local towards = startPos:Lerp(Vector3.new(tip.WorldPosition.X, FishingVisuals.waterY, tip.WorldPosition.Z), p * 0.55)
			s.bobber.pos = towards + Vector3.new(math.sin(t * 13) * 0.25, 0, math.cos(t * 11) * 0.25)
			s.bobber.dipAmount = -0.25 - 0.2 * math.max(0, math.sin(t * 9))
		end
		if fight.progress >= fight.goal then
			won = true
			break
		elseif fight.progress <= 0 then
			won = false
			break
		elseif os.clock() - fight.lastClick > 6 then
			won = false -- stopped reeling
			break
		end
	end
	if fight ~= myFight then return end -- cancelled (walked off, unequipped...)

	if won then
		fightTitle.Text = "GOT IT!"
		fightTitle.TextColor3 = Color3.fromRGB(120, 255, 120)
		-- the server needs a moment to have passed: wait out the fastest-possible time if needed
		local okLand, landed = pcall(function()
			return reelRemote:InvokeServer(s.id, "land")
		end)
		task.delay(0.35, function() if fight == nil then fightGui.Visible = false end end)
		stopFight()
		fightGui.Visible = true
		task.delay(0.35, function() if not fight then fightGui.Visible = false end end)
		if okLand and type(landed) == "table" and landed.ok then
			landFish(s, landed)
		else
			local reason = okLand and type(landed) == "table" and landed.reason
			loseFish(s, reason == "full" and "BucketFull" or "GotAway")
		end
	else
		fightTitle.Text = "IT GOT AWAY..."
		fightTitle.TextColor3 = Color3.fromRGB(255, 110, 110)
		task.delay(0.6, function() if not fight then fightGui.Visible = false end end)
		fight = nil
		pcall(function() reelRemote:InvokeServer(s.id, "escape") end)
		loseFish(s, "GotAway")
	end
	if session == s then endSession() end
end

-- mashing: any click / tap / space while fighting
UserInputService.InputBegan:Connect(function(input, processed)
	if not fight then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonA then
		mash()
	end
end)

------------------------------------------------------------------------------------------
-- cast power bar (right side): hold to charge - the marker runs x1.0 (bottom) -> x1.5 (top)
-- and back down; release to throw. The multiplier boosts that cast's luck + fish weight.
------------------------------------------------------------------------------------------
local POWER_MIN, POWER_MAX = 1, 1.5
local POWER_CYCLE = 1.1 -- seconds from bottom to top

local powerGui = Instance.new("Frame")
powerGui.Name = "CastPower"
powerGui.AnchorPoint = Vector2.new(1, 0.5)
powerGui.Position = UDim2.new(1, -18, 0.5, 0)
powerGui.Size = UDim2.new(0, 170, 0.56, 0)
powerGui.BackgroundTransparency = 1
powerGui.Visible = false
powerGui.Parent = hud
local powerSizeLimit = Instance.new("UISizeConstraint")
powerSizeLimit.MaxSize = Vector2.new(170, 440)
powerSizeLimit.MinSize = Vector2.new(120, 220)
powerSizeLimit.Parent = powerGui
local powerScale = Instance.new("UIScale")
powerScale.Parent = powerGui

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(1, 0)
bar.Position = UDim2.new(1, 0, 0, 0)
bar.Size = UDim2.new(0, 56, 1, -34)
bar.BackgroundColor3 = Color3.new(1, 1, 1)
bar.Parent = powerGui
corner(bar, 0.22)
local barStroke = stroke(bar, 4, Color3.fromRGB(12, 16, 24))
barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local barGrad = Instance.new("UIGradient")
barGrad.Rotation = 90 -- top -> bottom
barGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 215, 80)),
	ColorSequenceKeypoint.new(0.3, Color3.fromRGB(160, 215, 70)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 190, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 55, 50)),
})
barGrad.Parent = bar
local shine = Instance.new("Frame")
shine.BackgroundColor3 = Color3.new(1, 1, 1)
shine.BackgroundTransparency = 0.75
shine.Position = UDim2.new(0, 7, 0, 10)
shine.Size = UDim2.new(0, 8, 1, -20)
shine.Parent = bar
corner(shine, 1)

local marker = Instance.new("Frame")
marker.Name = "Marker"
marker.AnchorPoint = Vector2.new(1, 0.5)
marker.Position = UDim2.new(1, 6, 1, 0)
marker.Size = UDim2.new(0, 68, 0, 6)
marker.BackgroundColor3 = Color3.new(1, 1, 1)
marker.ZIndex = 3
marker.Parent = bar
corner(marker, 1)
stroke(marker, 2, Color3.fromRGB(12, 16, 24)).ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local powerLabel = text(bar, {
	Name = "Mult", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -12, 1, 0), Size = UDim2.fromOffset(110, 34),
	Text = "🍀x1.00", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 240, 150), ZIndex = 3,
})
powerLabel:FindFirstChildOfClass("UIStroke").Thickness = 3

local hint = text(powerGui, {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 16, 1, 0), Size = UDim2.new(0, 150, 0, 26),
	Text = "Release to Throw!", TextXAlignment = Enum.TextXAlignment.Right,
})

local charging = nil -- { start }

local function powerAt(t)
	-- 0 -> 1 -> 0 ... (ping-pong), eased so it lingers a hair at the ends
	local phase = (t / POWER_CYCLE) % 2
	local k = phase <= 1 and phase or 2 - phase
	return k
end

local function multFor(k)
	return POWER_MIN + (POWER_MAX - POWER_MIN) * k
end

RunService.RenderStepped:Connect(function()
	if not charging then return end
	local k = powerAt(os.clock() - charging.start)
	charging.k = k
	marker.Position = UDim2.new(1, 6, 1 - k, 0)
	powerLabel.Position = UDim2.new(0, -12, 1 - k, 0)
	powerLabel.Text = string.format("🍀x%.2f", multFor(k))
	powerLabel.TextColor3 = k >= 0.9 and Color3.fromRGB(140, 255, 120) or Color3.fromRGB(255, 240, 150)
	if arm then arm:setPower(k) end
end)

local function showPowerBar(on)
	if on then
		powerGui.Visible = true
		powerScale.Scale = 0.6
		TweenService:Create(powerScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		powerGui.Visible = false
	end
end

local function flashPower(k)
	local mult = multFor(k)
	local perfect = k >= 0.9
	local l = text(hud, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(360, 54),
		Text = perfect and "PERFECT CAST! 🍀x" .. string.format("%.2f", mult) or string.format("🍀x%.2f", mult),
		TextColor3 = perfect and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 235, 140),
	})
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = l
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = perfect and 1.1 or 0.8 }):Play()
	task.delay(0.9, function()
		TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 1 }):Play() end
		task.wait(0.35)
		l:Destroy()
	end)
end

-- can we start a cast from here? (shows the right message if not)
local function canCast()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local tool = rodTool()
	if not root or not tool then return false end
	if not onBridge(root) then
		MessageToPlayer.show("NotOnBridge")
		return false
	end
	if (player:GetAttribute("FishCarried") or 0) >= FishingConfig.backpackSize(player) then
		MessageToPlayer.show("BucketFull")
		return false
	end
	if not castTarget(root) then
		MessageToPlayer.show("CastWater")
		return false
	end
	return true
end

local function startCharge()
	if not canCast() then return end
	state = "charging"
	charging = { start = os.clock(), k = 0 }
	if arm then arm:charge() end
	showPowerBar(true)
end

local function cancelCharge()
	charging = nil
	showPowerBar(false)
	if state == "charging" then
		state = "idle"
		if arm then arm:idle() end
	end
end

local function cast(k)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local tool = rodTool()
	if not root or not tool then cancelCharge() return end

	-- a stronger cast lands farther out
	local target = castTarget(root, 0.75 + 0.5 * k)
	if not target or not onBridge(root) then
		cancelCharge()
		MessageToPlayer.show(target and "NotOnBridge" or "CastWater")
		return
	end

	state = "casting"
	flashPower(k)

	-- ask the server while the arm whips forward
	local sent = os.clock()
	local result, done = nil, false
	task.spawn(function()
		local ok, r = pcall(function()
			return castRemote:InvokeServer(target, k)
		end)
		result = ok and r or nil
		done = true
	end)
	if arm then arm:release() end
	while not done do task.wait() end

	if not (type(result) == "table" and result.ok) then
		state = "idle"
		if arm then arm:idle() end
		local reason = type(result) == "table" and result.reason
		if reason == "bridge" then MessageToPlayer.show("NotOnBridge")
		elseif reason == "water" then MessageToPlayer.show("CastWater")
		elseif reason == "full" then MessageToPlayer.show("BucketFull") end
		return
	end

	local s = { id = result.id, biteAt = sent + result.biteIn }
	session = s

	local tip = tipOf(tool)
	local bobber = FishingVisuals.bobber()
	s.bobber = bobber
	if tip then bobber:attachLine(tip) end
	bobber:fly(tip and tip.WorldPosition or root.Position, target, 0.45 + 0.15 * k)
	if session ~= s then return end
	FishingVisuals.splash(target, 0.6)
	bobber:float(target)
	if arm then arm:waiting() end
	state = "waiting"

	-- wait for the bite
	task.delay(math.max(0, s.biteAt - os.clock()), function()
		if session ~= s or state ~= "waiting" then return end
		state = "bite"
		s.alert = headAlert() -- the "!" pops up over YOUR head
		bobber:dip()
		FishingVisuals.splash(target, 0.8)
		if arm then arm:bite() end
		-- too slow: it swims off
		task.delay(FishingConfig.ReelWindow, function()
			if session == s and state == "bite" then
				reel(false)
			end
		end)
	end)
end

-- press: start charging (or reel if a line is out)
local function onActivated()
	if state == "idle" then
		startCharge()
	elseif state == "waiting" then
		reel(true) -- clicked before a bite
	elseif state == "bite" then
		hookFish()
	end
end

-- let go: throw
local function onDeactivated()
	if state == "charging" and charging then
		local k = charging.k or 0
		charging = nil
		showPowerBar(false)
		cast(k)
	end
end

-- hook every rod tool that shows up
local hooked = {}
local function hookTool(tool)
	if hooked[tool] or not tool:IsA("Tool") or tool:GetAttribute("FishingTool") ~= "Rod" then return end
	hooked[tool] = true
	tool.Activated:Connect(onActivated)
	tool.Deactivated:Connect(onDeactivated)
	tool.Unequipped:Connect(function()
		cancelCharge()
		if session then endSession() end
	end)
	tool.AncestryChanged:Connect(function(_, parent)
		if not parent then hooked[tool] = nil end
	end)
end

local function watchContainer(container)
	for _, t in ipairs(container:GetChildren()) do hookTool(t) end
	container.ChildAdded:Connect(function(t) task.defer(hookTool, t) end)
end

local function onCharacter(character)
	endSession()
	if arm then arm:destroy() arm = nil end
	task.spawn(function()
		arm = FishingVisuals.arm(character, function() return rodTool() ~= nil end, function()
			local tool = rodTool()
			local handle = tool and tool:FindFirstChild("Handle")
			return handle and FishingVisuals.leftGrip(handle, tool.Grip.Position) or nil
		end)
	end)
	watchContainer(character)
end

watchContainer(player:WaitForChild("Backpack"))
player.ChildAdded:Connect(function(c)
	if c:IsA("Backpack") then watchContainer(c) end
end)
if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)

-- walking off the bridge (or dying) mid-cast cancels it
task.spawn(function()
	while true do
		task.wait(0.3)
		if session and (state == "waiting" or state == "bite" or state == "fighting") then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root or not onBridge(root) or not rodTool() then
				endSession()
			end
		end
	end
end)

------------------------------------------------------------------------------------------
-- events from the server (shells, tier ups, robux sell)
------------------------------------------------------------------------------------------
eventRemote.OnClientEvent:Connect(function(kind, ...)
	if kind == "shell" then
		local pos, amount, size = ...
		FishingVisuals.popup(pos + Vector3.new(0, 2, 0), "+" .. abbreviate(amount), size == "Golden" and Color3.fromRGB(255, 215, 60) or Color3.fromRGB(255, 205, 220), FishingVisuals.Icons.Shells, size == "Golden" or size == "Large")
	elseif kind == "tier" then
		local tier = ...
		celebrate("FISH TIER " .. tier .. "!", Color3.fromRGB(255, 220, 70))
	elseif kind == "prestige" then
		local p = ...
		celebrate("FISHING PRESTIGE " .. p .. "!", Color3.fromRGB(120, 230, 255))
	elseif kind == "sold" then
		local total = ...
		celebrate("SOLD 2x! +" .. abbreviate(total) .. " Fish Meal", Color3.fromRGB(120, 255, 140))
	end
end)

-- shells on the sand bob and spin a little (only on your screen)
local shellFolder = island:WaitForChild("SpawnedShells", 30)
local shellBase = {}
RunService.RenderStepped:Connect(function()
	if not shellFolder then return end
	local t = os.clock()
	for _, shell in ipairs(shellFolder:GetChildren()) do
		local base = shellBase[shell]
		if not base then
			base = shell:GetPivot()
			shellBase[shell] = base
			shell.Destroying:Connect(function() shellBase[shell] = nil end)
		end
		shell:PivotTo(base * CFrame.new(0, 0.25 + math.sin(t * 2 + base.X) * 0.15, 0) * CFrame.Angles(0, t * 0.8, 0))
	end
end)

------------------------------------------------------------------------------------------
-- island HUD: top buttons, bottom bar position, Total Fish Caught
------------------------------------------------------------------------------------------
local fishingGui = playerGui:WaitForChild("Fishing")
local topRow = fishingGui:WaitForChild("Top")
local bottomBar = playerGui:WaitForChild("Buttons"):WaitForChild("Container")
local currencies = playerGui:WaitForChild("Currencies"):WaitForChild("MainCurrenciesFrame")
local totalLabel = currencies:FindFirstChild("TotalFishCaught")

local barInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local barLayout = bottomBar:FindFirstChildOfClass("UIListLayout")
local barHome = {
	Position = bottomBar.Position, Size = bottomBar.Size, AnchorPoint = bottomBar.AnchorPoint,
}
local layoutHome = barLayout and {
	FillDirection = barLayout.FillDirection, Padding = barLayout.Padding,
	HorizontalAlignment = barLayout.HorizontalAlignment, VerticalAlignment = barLayout.VerticalAlignment,
}
local buttonHome = {}
for _, b in ipairs(bottomBar:GetChildren()) do
	if b:IsA("GuiObject") then buttonHome[b] = b.Size end
end

-- on the island the menu buttons stack top-to-bottom in the bottom-left corner,
-- so the middle of the bottom is free for the fishing hotbar
local gridLayout
local function stackBar()
	-- on the island: a 2x2 grid in the bottom-left corner
	local size
	for btn in pairs(buttonHome) do
		if btn.Visible and btn.AbsoluteSize.X > 0 then size = btn.AbsoluteSize break end
	end
	size = (size or Vector2.new(140, 62)) * 0.9
	local gapX, gapY = 14, 28 -- extra room above: the icons poke out of the top of each button
	if barLayout then barLayout.Parent = nil end
	if not gridLayout then
		gridLayout = Instance.new("UIGridLayout")
		gridLayout.Name = "IslandGrid"
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.FillDirection = Enum.FillDirection.Horizontal
		gridLayout.FillDirectionMaxCells = 2
		gridLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end
	gridLayout.CellSize = UDim2.fromOffset(size.X, size.Y)
	gridLayout.CellPadding = UDim2.fromOffset(gapX, gapY)
	gridLayout.Parent = bottomBar
	bottomBar.AnchorPoint = Vector2.new(0, 1)
	bottomBar.Size = UDim2.fromOffset(size.X * 2 + gapX, size.Y * 2 + gapY)
	bottomBar.Position = UDim2.new(0, -size.X * 2 - 40, 1, -18)
	TweenService:Create(bottomBar, barInfo, { Position = UDim2.new(0, 18, 1, -18) }):Play()
end

local function unstackBar()
	if gridLayout then gridLayout.Parent = nil end
	if barLayout then barLayout.Parent = bottomBar end
	for btn, sz in pairs(buttonHome) do
		if btn.Parent then btn.Size = sz end
	end
	if barLayout and layoutHome then
		for k, v in pairs(layoutHome) do barLayout[k] = v end
	end
	for k, v in pairs(barHome) do bottomBar[k] = v end
end

local function paintTotal()
	if totalLabel then
		totalLabel.Text = "Total Fish Caught: " .. abbreviate(player:GetAttribute("FishCaught") or 0)
	end
end

local wasOn, wasStacked = nil, nil
-- on = on Fishing Frenzy; stacked = the menu moves to the corner (Fishing Frenzy or Drilling Mania)
local function applyIsland(on, stacked)
	if on == wasOn and stacked == wasStacked then return end
	wasOn = on
	topRow.Visible = on
	bucket.Visible = false -- the Inventory shows how many fish you carry
	if totalLabel then totalLabel.Visible = on end
	if stacked == wasStacked then return end
	wasStacked = stacked
	on = stacked

	if on then
		stackBar()
	else
		unstackBar()
	end

	-- the owner-only panel button would sit on top of the stacked menu: nudge it right
	local ownerPanel = playerGui:FindFirstChild("OwnerPanel")
	local toggle = ownerPanel and ownerPanel:FindFirstChild("Toggle")
	if toggle then
		if not toggle:GetAttribute("HomeX") then
			toggle:SetAttribute("HomeX", toggle.Position.X.Offset)
		end
		local home = toggle:GetAttribute("HomeX")
		toggle.Position = UDim2.new(toggle.Position.X.Scale, on and home + 150 or home, toggle.Position.Y.Scale, toggle.Position.Y.Offset)
	end
end

player:GetAttributeChangedSignal("FishCaught"):Connect(paintTotal)
player:GetAttributeChangedSignal("FishCarried"):Connect(paintBucket)
for _, u in ipairs({ "ShellUp_Backpack" }) do
	player:GetAttributeChangedSignal(u):Connect(paintBucket)
end
paintTotal()
paintBucket()

task.spawn(function()
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local fishing = root ~= nil and FishingFrenzyConfig.isInside(root.Position)
		local drilling = root ~= nil and (DrillConfig.isInside(root.Position) or LabConfig.isInside(root.Position))
		applyIsland(fishing, fishing or drilling)
		task.wait(0.25)
	end
end)
