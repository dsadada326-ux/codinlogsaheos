-- The Island 2 Upgrade Tree (Workspace.UpgradeBoards.Island2.UpgradeTree), working like the
-- Island 1 tree (UpgradeTree.lua): a node shows up once it can be bought, glows gold while
-- it's available, turns green once owned, and new nodes rise into place as the tree grows.
-- Step on a node (or click it) to buy it with Gold - TreeService does the buying.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local PrestigeConfig = require(ReplicatedStorage:WaitForChild("PrestigeConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local treeFolder = workspace:WaitForChild("UpgradeBoards"):WaitForChild("Island2"):WaitForChild("UpgradeTree")

local COLOR_LOCKED = Color3.fromRGB(110, 110, 120)
local COLOR_AVAILABLE = Color3.fromRGB(255, 205, 60)
local COLOR_OWNED = Color3.fromRGB(90, 255, 110)

local RISE_FROM = 8
local RISE_TIME = 0.8

local CURRENCY = PrestigeConfig.Island2TreeCurrency

------------------------------------------------------------------------------------------
-- a node's parts, hidden / shown on this screen only (same as the Island 1 tree)
------------------------------------------------------------------------------------------
local function makeGroup(root)
	local group = { parts = {}, guis = {}, textures = {}, shown = nil }

	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(group.parts, {
				inst = d, cframe = d.CFrame,
				canCollide = d.CanCollide, canQuery = d.CanQuery, canTouch = d.CanTouch,
			})
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			table.insert(group.guis, { inst = d, enabled = d.Enabled })
		elseif d:IsA("Texture") or d:IsA("Decal") then
			table.insert(group.textures, { inst = d, transparency = d.Transparency })
		end
	end

	return group
end

local function setGroup(group, show, animate)
	if group.shown == show then
		return
	end

	group.shown = show

	for _, g in ipairs(group.guis) do
		g.inst.Enabled = show
	end

	for _, t in ipairs(group.textures) do
		if show and animate then
			t.inst.Transparency = 1
			TweenService:Create(t.inst, TweenInfo.new(RISE_TIME * 0.6), { Transparency = t.transparency }):Play()
		else
			t.inst.Transparency = show and t.transparency or 1
		end
	end

	for i, p in ipairs(group.parts) do
		local part = p.inst

		part.CanCollide = show and p.canCollide
		part.CanQuery = show and p.canQuery
		part.CanTouch = show and p.canTouch

		if show and animate then
			local canMove = part.Anchored and #part:GetJoints() == 0

			part.LocalTransparencyModifier = 1

			if canMove then
				part.CFrame = p.cframe * CFrame.new(0, -RISE_FROM, 0)
			end

			task.delay((i % 6) * 0.05, function()
				TweenService:Create(part, TweenInfo.new(RISE_TIME * 0.6), { LocalTransparencyModifier = 0 }):Play()

				if canMove then
					TweenService:Create(
						part,
						TweenInfo.new(RISE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ CFrame = p.cframe }
					):Play()
				end
			end)
		else
			part.LocalTransparencyModifier = show and 0 or 1

			if part.Anchored and #part:GetJoints() == 0 then
				part.CFrame = p.cframe
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- nodes (set up whenever a node model streams in)
------------------------------------------------------------------------------------------
local nodes = {} -- [nodeName] = node

local function nodeState(nodeName)
	if PrestigeConfig.owns(player, nodeName) then
		return "owned"
	elseif PrestigeConfig.available(player, nodeName) then
		return "available"
	elseif PrestigeConfig.island2TreeUnlocked(player) and PrestigeConfig.comingSoon(player, nodeName) then
		return "soon"
	end

	return "locked"
end

local function refreshNode(nodeName, node)
	local state = nodeState(nodeName)
	local def = node.def

	if node.cost then
		if state == "owned" then
			node.cost.Text = '<stroke color="#0F5C1E" thickness="4"><font color="#67ff30">Owned!</font></stroke>'
		elseif state == "available" then
			node.cost.Text = '<stroke color="#3A3E44" thickness="4"><font color="#AEB4BC">Cost:</font></stroke> '
				.. '<stroke color="#6B4A00" thickness="4"><font color="#FFD23C">' .. NumberFormat.abbreviate(def.cost) .. " " .. CURRENCY .. '</font></stroke>'
		elseif state == "soon" then
			node.cost.Text = '<stroke color="#3A3E44" thickness="4"><font color="#AEB4BC">Coming Soon</font></stroke>'
		else
			node.cost.Text = '<stroke color="#3A3E44" thickness="4"><font color="#AEB4BC">Locked</font></stroke>'
		end
	end

	local color = state == "owned" and COLOR_OWNED or (state == "available" and COLOR_AVAILABLE or COLOR_LOCKED)

	for _, part in ipairs(node.neon) do
		if part.Parent then
			TweenService:Create(part, TweenInfo.new(0.3), { Color = color }):Play()
		end
	end

	if node.highlight then
		node.highlight.Enabled = state == "available"
		node.highlight.FillColor = COLOR_AVAILABLE
		node.highlight.OutlineColor = COLOR_AVAILABLE
	end

	node.state = state
end

local function refreshOne(nodeName, node, animate)
	local visible = nodeState(nodeName) ~= "locked"

	setGroup(node.group, visible, animate)

	if visible then
		refreshNode(nodeName, node)
	end
end

local function refresh(animate)
	for nodeName, node in pairs(nodes) do
		refreshOne(nodeName, node, animate)
	end
end

local function setupNode(model)
	local nodeName = model.Name
	local def = PrestigeConfig.Island2Tree[nodeName]

	if not def or not model:IsA("Model") then
		return
	end

	local display = model:FindFirstChild("Display")
	local costLabel, multLabel

	if display then
		for _, d in ipairs(display:GetDescendants()) do
			if d:IsA("TextLabel") and d.Name == "Cost" and not costLabel then costLabel = d end
			if d:IsA("TextLabel") and d.Name == "Multiplier" and not multLabel then multLabel = d end
		end
	end

	local neon = {}
	local neonFolder = model:FindFirstChild("NeonColored")

	if neonFolder then
		for _, d in ipairs(neonFolder:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(neon, d) end
		end
	end

	local node = {
		model = model,
		def = def,
		group = makeGroup(model),
		cost = costLabel,
		mult = multLabel,
		neon = neon,
		highlight = model:FindFirstChildOfClass("Highlight"),
		state = nil,
	}

	nodes[nodeName] = node
	refreshOne(nodeName, node, false)

	-- streamed back out: forget it (a fresh copy arrives when it streams back in)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and nodes[nodeName] == node then
			nodes[nodeName] = nil
		end
	end)
end

for _, child in ipairs(treeFolder:GetChildren()) do
	setupNode(child)
end

treeFolder.ChildAdded:Connect(function(child)
	task.defer(setupNode, child)
end)

------------------------------------------------------------------------------------------
local function settled()
	return player:GetAttribute("_ZonesSettled") == true
end

player:GetAttributeChangedSignal("Island2Unlocked"):Connect(function()
	refresh(settled())
end)

for nodeName in pairs(PrestigeConfig.Island2Tree) do
	player:GetAttributeChangedSignal(PrestigeConfig.treeAttribute(nodeName)):Connect(function()
		refresh(true)
	end)
end

player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
	task.delay(2, function()
		refresh(false)
	end)
end)
