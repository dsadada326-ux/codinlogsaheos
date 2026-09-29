-- Fishing visuals shared by the player's fishing (FishingClient) and the auto-fisher NPCs
-- (AutoFisherClient). Client only.
--   FishingVisuals.arm(character)  -> an arm animator: :cast() :wait() :bite() :reel() :idle()
--       (moves the right shoulder/elbow Motor6Ds, so no animation assets are needed)
--   FishingVisuals.bobber() / :fly(from, to, time) / :float() / :dip() / :reelTo(pos)
--   FishingVisuals.line(fromAttachment, bobber)   the fishing line (a Beam)
--   FishingVisuals.splash(position, size)  FishingVisuals.popup(position, text, color)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingConfig"))
local assets = ReplicatedStorage:WaitForChild("FishingAssets")

local FishingVisuals = {}

local fxFolder = workspace:FindFirstChild("FishingFX") or Instance.new("Folder")
fxFolder.Name = "FishingFX"
fxFolder.Parent = workspace
FishingVisuals.folder = fxFolder

local island = workspace:WaitForChild("Islands"):WaitForChild(FishingConfig.IslandName)
local waterPart = island:WaitForChild("Map"):WaitForChild("WaterArea")
FishingVisuals.waterY = waterPart.Position.Y + waterPart.Size.Y / 2 + 0.05
FishingVisuals.water = waterPart

------------------------------------------------------------------------------------------
-- arm animation (procedural), Fisch-style overhead cast.
-- Drives the waist, right shoulder, elbow and wrist by overriding the joints' Transform
-- right after the Animator runs (PreSimulation), so it fully replaces the tool-hold pose
-- instead of fighting it. Only active while `isActive()` says so (holding the rod).
--   charge  : rod swings ALL the way back behind you and trembles while you hold
--   release : whips forward over your head with a wrist flick, body leans in
-- Angles (radians, from the arm hanging down): sp = shoulder pitch (+ raises forward/up/back),
-- sr = shoulder roll, e = elbow bend, w = wrist (+ tips the rod back), tp = torso pitch
-- (+ leans back), ty = torso twist.
------------------------------------------------------------------------------------------
local ArmAnim = {}
ArmAnim.__index = ArmAnim

local KEYS = { "sp", "sy", "sr", "e", "w", "tp", "ty" }
local ARM_FORWARD = math.rad(90) -- the normal "holding a tool" arm

local POSES = {
	-- both hands on the rod, held in front at belly height, body turned a little sideways
	idle =    { sp = -0.95, sy = 0.9,  sr = 0,    e = 1.3,  w = -0.3,  tp = 0,     ty = -0.55 },
	-- hold: rod ALL the way back behind you, over the shoulder, leaning back
	charge =  { sp = 1.45,  sy = 1.0,  sr = 0,    e = 1.2,  w = 0.0,   tp = 0.2,   ty = -0.4 },
	-- release: whipped forward and down past the front, leaning into it
	whip =    { sp = -0.45, sy = 0.8,  sr = 0,    e = 0.35, w = -0.9,  tp = -0.22, ty = -0.5 },
	waiting = { sp = -0.95, sy = 0.9,  sr = 0,    e = 1.35, w = -0.3,  tp = -0.03, ty = -0.55 },
	bite =    { sp = -1.05, sy = 0.9,  sr = 0,    e = 1.2,  w = -0.65, tp = -0.08, ty = -0.55 },
	reel =    { sp = -0.6,  sy = 0.9,  sr = 0,    e = 1.6,  w = 0.15,  tp = 0.1,   ty = -0.5 },
}

local function easeOut(k) return 1 - (1 - k) ^ 3 end
local function easeIn(k) return k ^ 2.4 end
local function easeInOut(k) return k < 0.5 and 4 * k ^ 3 or 1 - (-2 * k + 2) ^ 3 / 2 end

-- getLeftGrip(): an Attachment on the rod where the LEFT hand should hold it (two-handed grip)
function FishingVisuals.arm(character, isActive, getLeftGrip)
	local upper = character:WaitForChild("RightUpperArm", 5)
	local lower = character:WaitForChild("RightLowerArm", 5)
	local hand = character:WaitForChild("RightHand", 5)
	local torso = character:WaitForChild("UpperTorso", 5)
	local shoulderJoint = upper and upper:WaitForChild("RightShoulder", 5)
	local elbowJoint = lower and lower:WaitForChild("RightElbow", 5)
	if not shoulderJoint or not elbowJoint then
		return nil
	end
	local wristJoint = hand and hand:FindFirstChild("RightWrist")
	local waistJoint = torso and torso:FindFirstChild("Waist")

	if type(isActive) ~= "function" then
		isActive = function() return true end
	end

	local self = setmetatable({
		joints = { shoulder = shoulderJoint, elbow = elbowJoint, wrist = wristJoint, waist = waistJoint },
		isActive = isActive,
		current = table.clone(POSES.idle),
		tween = nil,
		mode = "idle",
		power = 0,
		t = 0,
	}, ArmAnim)

	-- left hand on the rod: our own 2-bone IK drives the left shoulder + elbow each frame
	local lUpper = character:FindFirstChild("LeftUpperArm")
	local lLower = character:FindFirstChild("LeftLowerArm")
	local lHand = character:FindFirstChild("LeftHand")
	local lShoulder = lUpper and lUpper:FindFirstChild("LeftShoulder")
	local lElbow = lLower and lLower:FindFirstChild("LeftElbow")
	if getLeftGrip and torso and lShoulder and lElbow then
		local function parts(joint)
			if joint:IsA("Motor6D") then
				return joint.C0, joint.C1
			end
			return joint.Attachment0 and joint.Attachment0.CFrame, joint.Attachment1 and joint.Attachment1.CFrame
		end
		local sC0, sC1 = parts(lShoulder)
		local eC0, eC1 = parts(lElbow)
		local wrist = lHand and lHand:FindFirstChild("LeftWrist")
		local wC0, wC1
		if wrist then wC0, wC1 = parts(wrist) end
		local gripAtt = lHand and lHand:FindFirstChild("LeftGripAttachment")
		if sC0 and sC1 and eC0 and eC1 then
			local l1 = (eC0.Position - sC1.Position).Magnitude
			local l2 = wC0 and (wC0.Position - eC1.Position).Magnitude or 1
			if wC1 and gripAtt then
				l2 += (gripAtt.Position - wC1.Position).Magnitude * 0.8
			end
			self.leftArm = {
				shoulder = lShoulder, elbow = lElbow, sC0 = sC0, sC1 = sC1, eC0 = eC0, eC1 = eC1,
				l1 = l1, l2 = l2, torso = torso,
			}
			self.getLeftGrip = getLeftGrip
		end
	end

	self.conn = RunService.PreSimulation:Connect(function(dt)
		self:_step(dt)
	end)
	return self
end

local function setTransform(joint, cf)
	if joint and joint.Parent then
		joint.Transform = cf
	end
end

function ArmAnim:_step(dt)
	if not self.joints.shoulder.Parent then
		self:destroy()
		return
	end
	self.t += dt

	local tw = self.tween
	if tw then
		local k = math.clamp((os.clock() - tw.start) / tw.duration, 0, 1)
		local a = tw.ease(k)
		for _, key in ipairs(KEYS) do
			self.current[key] = tw.from[key] + (tw.to[key] - tw.from[key]) * a
		end
		if k >= 1 then
			self.tween = nil
		end
	end

	local active = self.isActive()
	if not active then
		return -- not holding the rod: let the normal animations play
	end

	local c = self.current
	local sp, sr, e, w, tp, ty = c.sp, c.sr, c.e, c.w, c.tp, c.ty
	if not self.tween then
		if self.mode == "charge" then
			-- straining: shakes harder the more power you build
			local shake = 0.015 + self.power * 0.045
			sp += math.sin(self.t * 43) * shake
			w += math.sin(self.t * 37 + 1) * shake
		elseif self.mode == "waiting" then
			sp += math.sin(self.t * 2) * 0.03
			w += math.sin(self.t * 2 + 1) * 0.05
		elseif self.mode == "bite" then
			local tug = math.sin(self.t * 30) * 0.09 + math.sin(self.t * 11) * 0.07
			sp += tug
			w += tug * 1.5
		elseif self.mode == "reel" then
			e += math.sin(self.t * 22) * 0.3
			sp += math.sin(self.t * 11) * 0.05
			w += math.sin(self.t * 9) * 0.08
		end
	end

	local j = self.joints
	setTransform(j.shoulder, CFrame.Angles(0, c.sy, 0) * CFrame.Angles(ARM_FORWARD + sp, 0, sr))
	setTransform(j.elbow, CFrame.Angles(e, 0, 0))
	setTransform(j.wrist, CFrame.Angles(w, 0, 0))
	if math.abs(tp) + math.abs(ty) > 0.002 then
		setTransform(j.waist, CFrame.Angles(tp, ty, 0))
	end

	-- second hand on the rod, just below the right hand (wherever it reaches best)
	local grip = self.leftArm and self.getLeftGrip()
	if grip and grip.Parent then
		local base = grip.WorldPosition
		local down = -grip.Parent.CFrame.UpVector
		local S = (self.leftArm.torso.CFrame * self.leftArm.sC0).Position
		local t = math.clamp((S - base):Dot(down), 0.35, 1.0)
		self:_leftHand(base + down * t)
	end
end

-- 2-bone IK: put the left hand on `target` (world position), elbow pointing down/out
function ArmAnim:_leftHand(target)
	local L = self.leftArm
	local torsoCF = L.torso.CFrame
	local shoulderFrame = torsoCF * L.sC0
	local S = shoulderFrame.Position
	local toTarget = target - S
	local dist = math.clamp(toTarget.Magnitude, 0.2, L.l1 + L.l2 - 0.02)
	local n = toTarget.Magnitude > 0.001 and toTarget.Unit or -torsoCF.UpVector

	local pole = torsoCF:VectorToWorldSpace(Vector3.new(-0.7, -1, 0.3))
	local p = pole - n * pole:Dot(n)
	p = p.Magnitude > 0.001 and p.Unit or -torsoCF.UpVector

	local cosA = math.clamp((L.l1 * L.l1 + dist * dist - L.l2 * L.l2) / (2 * L.l1 * dist), -1, 1)
	local a = math.acos(cosA)
	local E = S + (n * math.cos(a) + p * math.sin(a)) * L.l1
	local T = S + n * dist

	local down1 = (E - S).Unit
	local down2 = (T - E).Unit
	local x = down1:Cross(down2)
	x = x.Magnitude < 0.001 and torsoCF.RightVector or x.Unit

	local upperJoint = CFrame.fromMatrix(S, x, -down1) * L.sC1.Rotation
	local upperCF = upperJoint * L.sC1:Inverse()
	setTransform(L.shoulder, (shoulderFrame:Inverse() * upperJoint).Rotation)

	local elbowParent = upperCF * L.eC0
	local lowerJoint = CFrame.fromMatrix(E, x, -down2) * L.eC1.Rotation
	setTransform(L.elbow, (elbowParent:Inverse() * lowerJoint).Rotation)
end

-- blend to a pose over `duration` seconds
function ArmAnim:to(name, duration, ease)
	self.mode = name
	self.tween = {
		from = table.clone(self.current),
		to = POSES[name] or POSES.idle,
		start = os.clock(),
		duration = math.max(duration or 0.2, 0.01),
		ease = ease or easeInOut,
	}
end

-- the spot on a rod handle for the left hand: further down the rod from the right hand
function FishingVisuals.leftGrip(handle, gripPosition)
	local a = handle:FindFirstChild("LeftGrip")
	if not a then
		a = Instance.new("Attachment")
		a.Name = "LeftGrip"
		a.Position = gripPosition or Vector3.zero -- where the right hand holds; the left hand slides below it
		a.Parent = handle
	end
	return a
end

function ArmAnim:pose(name, speed) self:to(name, speed and (2.5 / speed) or 0.25) end

-- hold: rod goes all the way back
function ArmAnim:charge()
	self.power = 0
	self:to("charge", 0.38, easeOut)
end

function ArmAnim:setPower(p) self.power = p end

-- let go: whip it forward. Returns at the moment the line leaves the rod.
function ArmAnim:release()
	self:to("whip", 0.15, easeIn)
	task.wait(0.11)
	task.delay(0.1, function()
		if self.conn and self.mode == "whip" then
			self:to("waiting", 0.4, easeOut)
		end
	end)
end

-- a whole cast in one go (auto-fisher NPCs)
function ArmAnim:cast(hold)
	self:charge()
	task.wait(hold or 0.55)
	self:release()
end

function ArmAnim:waiting()
	if self.mode ~= "waiting" then self:to("waiting", 0.4, easeOut) end
end
function ArmAnim:bite() self:to("bite", 0.12, easeOut) end
function ArmAnim:reel() self:to("reel", 0.16, easeOut) end
function ArmAnim:idle() self:to("idle", 0.3, easeInOut) end

function ArmAnim:destroy()
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end

end

------------------------------------------------------------------------------------------
-- bobber + line
------------------------------------------------------------------------------------------
local Bobber = {}
Bobber.__index = Bobber

function FishingVisuals.bobber()
	local model = assets:WaitForChild("Bobber"):Clone()
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	model.Parent = fxFolder
	local self = setmetatable({ model = model, pos = Vector3.zero, bobbing = false, t = 0 }, Bobber)
	self.attachment = model:FindFirstChild("LineAttachment", true)
	self.conn = RunService.RenderStepped:Connect(function(dt)
		self.t += dt
		if self.bobbing then
			local y = FishingVisuals.waterY + math.sin(self.t * 2.4) * 0.08 + (self.dipAmount or 0)
			model:PivotTo(CFrame.new(self.pos.X, y, self.pos.Z))
		end
	end)
	return self
end

-- quadratic arc from `from` to `to`
function Bobber:fly(from, to, time)
	self.bobbing = false
	local peak = (from + to) / 2 + Vector3.new(0, (from - to).Magnitude * 0.35 + 3, 0)
	local start = os.clock()
	while true do
		local k = math.clamp((os.clock() - start) / time, 0, 1)
		local p = (1 - k) ^ 2 * from + 2 * (1 - k) * k * peak + k ^ 2 * to
		self.model:PivotTo(CFrame.new(p))
		if k >= 1 then break end
		RunService.RenderStepped:Wait()
	end
	self.pos = to
end

function Bobber:float(position)
	self.pos = position
	self.dipAmount = 0
	self.bobbing = true
end

-- the fish bites: bobber gets yanked under a few times
function Bobber:dip()
	task.spawn(function()
		for i = 1, 4 do
			if not self.model.Parent or not self.bobbing then return end
			self.dipAmount = -0.45
			task.wait(0.12)
			self.dipAmount = -0.1
			task.wait(0.18)
		end
	end)
end

function Bobber:reelTo(getTarget, time)
	self.bobbing = false
	local from = self.model:GetPivot().Position
	local start = os.clock()
	while true do
		local k = math.clamp((os.clock() - start) / time, 0, 1)
		local to = getTarget()
		local p = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 2, 0)
		self.model:PivotTo(CFrame.new(p))
		if k >= 1 then break end
		RunService.RenderStepped:Wait()
	end
end

function Bobber:destroy()
	if self.conn then self.conn:Disconnect() end
	if self.beam then self.beam:Destroy() end
	self.model:Destroy()
end

-- the line: rod tip -> bobber
function Bobber:attachLine(tipAttachment)
	if self.beam then self.beam:Destroy() end
	local beam = Instance.new("Beam")
	beam.Attachment0 = tipAttachment
	beam.Attachment1 = self.attachment
	beam.Width0 = 0.05
	beam.Width1 = 0.05
	beam.Color = ColorSequence.new(Color3.fromRGB(245, 245, 245))
	beam.LightEmission = 0.3
	beam.FaceCamera = true
	beam.Segments = 20
	beam.CurveSize0 = -1.5
	beam.CurveSize1 = 1
	beam.Parent = self.model
	self.beam = beam
end

------------------------------------------------------------------------------------------
-- splash + popups
------------------------------------------------------------------------------------------
function FishingVisuals.splash(position, size)
	size = size or 1
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = Vector3.new(position.X, FishingVisuals.waterY, position.Z)
	p.Parent = fxFolder

	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * size), NumberSequenceKeypoint.new(1, 1.2 * size) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Speed = NumberRange.new(6 * size, 10 * size)
	e.SpreadAngle = Vector2.new(35, 35)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -35, 0)
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Rate = 0
	e.Parent = p
	e:Emit(math.floor(16 * size))

	-- ring on the water
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.05, 1, 1)
	ring.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(235, 250, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Parent = fxFolder
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Size = Vector3.new(0.05, 5 * size, 5 * size), Transparency = 1 }):Play()

	task.delay(1.2, function()
		p:Destroy()
		ring:Destroy()
	end)
end

function FishingVisuals.popup(position, text, color, icon, big)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = fxFolder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(big and 7 or 4.5, big and 1.6 or 1.1)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = anchor

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.03, 0)
	layout.Parent = row

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.LayoutOrder = 1
	label.Parent = row
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Parent = label

	if icon then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.SizeConstraint = Enum.SizeConstraint.RelativeYY
		img.Image = icon
		img.LayoutOrder = 2
		img.Parent = row
	end

	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = row
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(anchor, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = position + Vector3.new(0, 3.5, 0) }):Play()
	task.delay(1, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		for _, c in ipairs(row:GetChildren()) do
			if c:IsA("ImageLabel") then
				TweenService:Create(c, TweenInfo.new(0.4), { ImageTransparency = 1 }):Play()
			end
		end
	end)
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

FishingVisuals.Icons = {
	FishMeal = "rbxassetid://76525471756310",
	Shells = "rbxassetid://92546803713299",
	Crabs = "rbxassetid://139727073151009",
}

function FishingVisuals.rarityColor(rarity)
	local r = FishingConfig.Rarities[FishingConfig.RarityIndex[rarity] or 1]
	return r and r.color or Color3.new(1, 1, 1)
end

return FishingVisuals
