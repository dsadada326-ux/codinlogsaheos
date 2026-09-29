-- DRILLING MANIA: the scrap field (Workspace.SpawnPart). The server decides what spawns;
-- this draws it, picks up everything inside your pickup ring, and shows the field's stats.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local DrillConfig = require(ReplicatedStorage:WaitForChild("DrillConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = remotes:WaitForChild("DrillAction")
local eventRemote = remotes:WaitForChild("DrillEvent")
local collectRemote = remotes:WaitForChild("CollectScrap")

local templates = ReplicatedStorage:WaitForChild("Scrap")
local spawnPart = workspace:WaitForChild("DrillingMania"):WaitForChild("SpawnPart")

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local INK = Color3.fromRGB(20, 20, 26)

local folder = workspace:FindFirstChild("ClientScraps") or Instance.new("Folder")
folder.Name = "ClientScraps"
folder.Parent = workspace

local function up(id)
	return UpgradeConfig.valueAt(id, player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0)
end

------------------------------------------------------------------------------------------
-- drawing scrap
------------------------------------------------------------------------------------------
local items = {} -- [id] = { model, pos, base, pending, spin }

local function styleBillboards(model, kind, value)
	for _, bb in ipairs(model:GetChildren()) do
		if bb:IsA("BillboardGui") then
			bb.MaxDistance = 40
			bb.LightInfluence = 0
			bb.Size = UDim2.fromScale(2.2, 0.55)
			if bb.Name == "Top" then
				bb.StudsOffset = Vector3.new(0, 1.7, 0)
				local t = bb:FindFirstChildWhichIsA("TextLabel")
				if t then
					t.Text = kind.model
					t.Size = UDim2.fromScale(1, 1)
					t.TextScaled = true
				end
			else
				bb.StudsOffset = Vector3.new(0, 1.15, 0)
				bb.Size = UDim2.fromScale(1.6, 0.45)
				local t = bb:FindFirstChildWhichIsA("TextLabel")
				if t then
					t.Text = "+" .. value
					t.TextColor3 = Color3.fromRGB(190, 255, 170)
					t.Size = UDim2.fromScale(1, 1)
					t.TextScaled = true
				end
			end
		end
	end
end

local function addItem(item)
	if items[item.id] then
		return
	end
	local kind = DrillConfig.Scrap.Kinds[item.kind] or DrillConfig.Scrap.Kinds[1]
	local template = templates:FindFirstChild(kind.model)
	if not template then
		return
	end
	local model = template:Clone()
	model.Anchored = true
	model.CanCollide = false
	model.CanQuery = false
	model.CanTouch = false
	styleBillboards(model, kind, item.value)
	local yaw = math.random() * math.pi * 2
	local base = CFrame.new(item.pos) * CFrame.Angles(0, yaw, 0)
	local full = model.Size
	model.Size = full * 0.05
	model.CFrame = base * CFrame.new(0, 3, 0)
	model.Parent = folder
	TweenService:Create(model, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = full, CFrame = base }):Play()
	items[item.id] = { model = model, pos = item.pos, base = base, spin = (math.random() - 0.5) * 1.2, born = os.clock() }
end

local function removeItem(id, flyTo)
	local it = items[id]
	if not it then
		return
	end
	items[id] = nil
	local model = it.model
	if flyTo and model.Parent then
		for _, bb in ipairs(model:GetChildren()) do
			if bb:IsA("BillboardGui") then
				bb.Enabled = false
			end
		end
		local t = TweenService:Create(model, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(flyTo), Size = model.Size * 0.3,
		})
		t:Play()
		t.Completed:Connect(function()
			model:Destroy()
		end)
	else
		model:Destroy()
	end
end

local function clearAll()
	for id in pairs(items) do
		removeItem(id)
	end
end

------------------------------------------------------------------------------------------
-- "+12 Scrap" popups next to you
------------------------------------------------------------------------------------------
local popAnchor
local function popup(amount)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.StudsOffset = Vector3.new((math.random() - 0.5) * 2, 3, 0)
	gui.Adornee = root
	gui.Parent = player:WaitForChild("PlayerGui")
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.FontFace = FONT
	label.TextScaled = true
	label.Text = "+" .. NumberFormat.abbreviate(amount)
	label.TextColor3 = Color3.fromRGB(225, 230, 240)
	label.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = INK
	stroke.Parent = label
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.Image = DrillConfig.Icons.Scrap
	icon.Parent = holder
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = holder
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
	task.delay(0.55, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		TweenService:Create(icon, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
	end)
	task.delay(0.9, function()
		gui:Destroy()
	end)
end

------------------------------------------------------------------------------------------
-- server events
------------------------------------------------------------------------------------------
local flyTarget = {}
eventRemote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "scrap" then
		for _, item in ipairs(a) do
			addItem(item)
		end
	elseif kind == "scrapGot" then
		for _, id in ipairs(a) do
			if items[id] then
				removeItem(id, flyTarget[id])
			end
			flyTarget[id] = nil
		end
		popup(b)
	elseif kind == "scrapClear" then
		clearAll()
	end
end)

task.spawn(function()
	local ok, result = pcall(function()
		return actionRemote:InvokeServer("scrapSync")
	end)
	if ok and type(result) == "table" and result.items then
		for _, item in ipairs(result.items) do
			addItem(item)
		end
	end
end)

------------------------------------------------------------------------------------------
-- pickup ring + collecting
------------------------------------------------------------------------------------------
-- an invisible part carries two flat cylinder adornments: a faint fill and a hollow edge
local ring = Instance.new("Part")
ring.Name = "ScrapRing"
ring.Anchored = true
ring.CanCollide = false
ring.CanQuery = false
ring.CanTouch = false
ring.Transparency = 1
ring.Size = Vector3.new(0.2, 0.2, 0.2)
ring.Parent = folder

local ringFill = Instance.new("CylinderHandleAdornment")
ringFill.Adornee = ring
ringFill.Height = 0.05
ringFill.Color3 = Color3.fromRGB(255, 225, 120)
ringFill.Transparency = 1
ringFill.CFrame = CFrame.Angles(math.pi / 2, 0, 0)
ringFill.Parent = ring

local ringEdge = Instance.new("CylinderHandleAdornment")
ringEdge.Adornee = ring
ringEdge.Height = 0.08
ringEdge.Color3 = Color3.fromRGB(255, 205, 70)
ringEdge.Transparency = 1
ringEdge.CFrame = CFrame.Angles(math.pi / 2, 0, 0)
ringEdge.Parent = ring

local function nearField(pos, extra)
	local p = spawnPart.CFrame:PointToObjectSpace(pos)
	return math.abs(p.X) <= spawnPart.Size.X / 2 + extra and math.abs(p.Z) <= spawnPart.Size.Z / 2 + extra and math.abs(p.Y) < 20
end

local queue = {}
local lastSend = 0
local ringShown = 0

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	-- gentle bob + spin
	for _, it in pairs(items) do
		if not it.pending and t - it.born > 0.5 then
			it.model.CFrame = it.base * CFrame.new(0, math.sin(t * 2 + it.pos.X) * 0.15 + 0.15, 0) * CFrame.Angles(0, t * it.spin, 0)
		end
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local range = up("ScrapRange")
	local show = root ~= nil and nearField(root.Position, range + 12)
	ringShown += ((show and 1 or 0) - ringShown) * math.min(1, dt * 8)
	if root then
		local floorY = spawnPart.Position.Y + spawnPart.Size.Y / 2 + 0.06
		ring.CFrame = CFrame.new(root.Position.X, floorY, root.Position.Z)
		ringFill.Radius = range
		ringFill.Transparency = 1 - ringShown * 0.14
		ringEdge.Radius = range
		ringEdge.InnerRadius = math.max(0, range - 0.35)
		ringEdge.Transparency = 1 - ringShown * 0.75
	end

	if not show then
		return
	end

	for id, it in pairs(items) do
		if not it.pending then
			local d = Vector3.new(it.pos.X - root.Position.X, 0, it.pos.Z - root.Position.Z).Magnitude
			if d <= range then
				it.pending = true
				flyTarget[id] = root.Position
				table.insert(queue, id)
				-- start flying right away (feels instant); the server confirms
				TweenService:Create(it.model, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = CFrame.new(root.Position + Vector3.new(0, 0.5, 0)),
				}):Play()
				local model = it.model
				task.delay(0.2, function()
					if model.Parent then
						model.Transparency = 1
						for _, bb in ipairs(model:GetChildren()) do
							if bb:IsA("BillboardGui") then bb.Enabled = false end
						end
					end
				end)
				-- if the server never confirms (out of range / lag), put it back
				task.delay(2.5, function()
					local still = items[id]
					if still and still.model == model then
						still.pending = false
						model.Transparency = 0
						for _, bb in ipairs(model:GetChildren()) do
							if bb:IsA("BillboardGui") then bb.Enabled = true end
						end
					end
				end)
			end
		end
	end

	if #queue > 0 and t - lastSend > 0.1 then
		lastSend = t
		collectRemote:FireServer(queue)
		queue = {}
	end
end)

------------------------------------------------------------------------------------------
-- field stats sign
------------------------------------------------------------------------------------------
local info = Instance.new("BillboardGui")
info.Name = "ScrapFieldInfo"
info.Size = UDim2.fromScale(13, 5)
info.StudsOffsetWorldSpace = Vector3.new(0, 12, -spawnPart.Size.Z / 2)
info.MaxDistance = 140
info.LightInfluence = 0
info.Adornee = spawnPart
info.Parent = player:WaitForChild("PlayerGui")

local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Size = UDim2.fromScale(1, 1)
list.Parent = info
local ll = Instance.new("UIListLayout")
ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
ll.VerticalAlignment = Enum.VerticalAlignment.Bottom
ll.SortOrder = Enum.SortOrder.LayoutOrder
ll.Parent = list

local function line(order, height, color, strokeColor)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, height)
	l.FontFace = FONT
	l.TextScaled = true
	l.TextColor3 = color
	l.Parent = list
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = strokeColor or INK
	s.Parent = l
	return l
end

local title = line(1, 0.34, Color3.fromRGB(235, 240, 250))
title.Text = "Scrap Field"
local g = Instance.new("UIGradient")
g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 160, 180))
g.Rotation = 90
g.Parent = title
local capLine = line(2, 0.2, Color3.fromRGB(255, 225, 120))
local cdLine = line(3, 0.2, Color3.fromRGB(150, 220, 255))
local bulkLine = line(4, 0.2, Color3.fromRGB(170, 255, 150))

local function paintInfo()
	capLine.Text = math.floor(up("ScrapCapacity")) .. " Scrap Capacity"
	cdLine.Text = string.format("%.1fs Cooldown", up("ScrapSpawnSpeed"))
	bulkLine.Text = math.floor(up("ScrapBulk")) .. " Bulk Respawn"
end
for _, id in ipairs({ "ScrapCapacity", "ScrapSpawnSpeed", "ScrapBulk" }) do
	player:GetAttributeChangedSignal(UpgradeConfig.levelAttribute(id)):Connect(paintInfo)
end
paintInfo()
