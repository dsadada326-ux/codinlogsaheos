local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local PrestigeConfig = require(ReplicatedStorage:WaitForChild("PrestigeConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local island = workspace:WaitForChild("Islands"):WaitForChild("Island1")
local tree = island:WaitForChild("UpgradeTree")
local ground = island:WaitForChild("Zones"):WaitForChild("TreeGround")

local treeZone = ZoneConfig.find("UpgradeTree")

local COLOR_LOCKED = Color3.fromRGB(110, 110, 120)
local COLOR_AVAILABLE = Color3.fromRGB(255, 205, 60)
local COLOR_OWNED = Color3.fromRGB(90, 255, 110)

local RISE_FROM = 8 -- studs a ground stage rises from when it appears
local RISE_TIME = 0.8

------------------------------------------------------------------------------------------
-- a group of parts that can be hidden / shown on this screen only
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
		g.inst.Enabled = show -- node screens are always on while the node is showing
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
			-- lerp up out of the water into place, with a little stagger
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
-- nodes
------------------------------------------------------------------------------------------
local nodes = {}

for nodeName, def in pairs(PrestigeConfig.Tree) do
	local model = tree:WaitForChild(nodeName)
	local display = model:WaitForChild("Display")

	local costLabel, multLabel

	for _, d in ipairs(display:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "Cost" and not costLabel then costLabel = d end
		if d:IsA("TextLabel") and d.Name == "Multiplier" and not multLabel then multLabel = d end
	end

	local neon = {}
	local neonFolder = model:FindFirstChild("NeonColored")

	if neonFolder then
		for _, d in ipairs(neonFolder:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(neon, d) end
		end
	end

	nodes[nodeName] = {
		def = def,
		group = makeGroup(model),
		cost = costLabel,
		mult = multLabel,
		neon = neon,
		highlight = model:FindFirstChildOfClass("Highlight"),
		state = nil,
	}
end

local function nodeState(nodeName)
	if PrestigeConfig.owns(player, nodeName) then
		return "owned"
	elseif PrestigeConfig.available(player, nodeName) then
		return "available"
	end

	return "locked"
end

local function costText(text, color)
	return string.format('<stroke color="#3A3E44" thickness="4"><font color="#AEB4BC">%s</font></stroke>', text)
		.. (color and "" or "")
end

local function refreshNode(nodeName, node)
	local state = nodeState(nodeName)
	local def = node.def

	if node.cost then
		if state == "owned" then
			node.cost.Text = '<stroke color="#0F5C1E" thickness="4"><font color="#67ff30">Owned!</font></stroke>'
		elseif state == "available" then
			node.cost.Text = '<stroke color="#3A3E44" thickness="4"><font color="#AEB4BC">Cost:</font></stroke> '
				.. '<stroke color="#0F5C1E" thickness="4"><font color="#67ff30">' .. NumberFormat.abbreviate(def.cost) .. ' Cash</font></stroke>'
		else
			node.cost.Text = '<stroke color="#3A3E44" thickness="4"><font color="#AEB4BC">Locked</font></stroke>'
		end
	end

	local color = state == "owned" and COLOR_OWNED or (state == "available" and COLOR_AVAILABLE or COLOR_LOCKED)

	for _, part in ipairs(node.neon) do
		TweenService:Create(part, TweenInfo.new(0.3), { Color = color }):Play()
	end

	if node.highlight then
		node.highlight.Enabled = state == "available"
		node.highlight.FillColor = COLOR_AVAILABLE
		node.highlight.OutlineColor = COLOR_AVAILABLE
	end

	node.state = state
end

------------------------------------------------------------------------------------------
-- ground stages (Zones.TreeGround.<stage>, Nodes = "Upgrade3,Upgrade4")
------------------------------------------------------------------------------------------
local stages = {}

for _, stage in ipairs(ground:GetChildren()) do
	local list = {}

	for name in string.gmatch(stage:GetAttribute("Nodes") or "", "[^,%s]+") do
		table.insert(list, name)
	end

	-- OpensWithZone: this stage also rises when that area unlocks (the entry is the path to the trader)
	local zoneName = stage:GetAttribute("OpensWithZone")

	table.insert(stages, { nodes = list, group = makeGroup(stage), zone = zoneName and ZoneConfig.find(zoneName) })
end

local function stageUp(stage)
	if stage.zone and ZoneConfig.isRevealed(player, stage.zone) then
		return true
	end

	if not ZoneConfig.isRevealed(player, treeZone) then
		return false
	end

	for _, name in ipairs(stage.nodes) do
		if PrestigeConfig.owns(player, name) or PrestigeConfig.available(player, name) then
			return true
		end
	end

	return false
end

------------------------------------------------------------------------------------------
local function refresh(animate)
	local open = ZoneConfig.isRevealed(player, treeZone)

	for nodeName, node in pairs(nodes) do
		-- a node appears once it can be bought (or is owned), like the tree growing
		local visible = open and nodeState(nodeName) ~= "locked"

		setGroup(node.group, visible, animate)

		if visible then
			refreshNode(nodeName, node)
		end
	end

	for _, stage in ipairs(stages) do
		setGroup(stage.group, stageUp(stage), animate)
	end
end

refresh(false)

local function settled()
	return player:GetAttribute("_ZonesSettled") == true
end

player:GetAttributeChangedSignal(ZoneConfig.flagAttribute(treeZone)):Connect(function()
	refresh(settled())
end)

player:GetAttributeChangedSignal("Prestige"):Connect(function()
	refresh(settled())
end)

-- stages tied to another area (the trader path)
for _, stage in ipairs(stages) do
	if stage.zone then
		player:GetAttributeChangedSignal(ZoneConfig.flagAttribute(stage.zone)):Connect(function()
			refresh(settled())
		end)
	end
end

for nodeName in pairs(PrestigeConfig.Tree) do
	player:GetAttributeChangedSignal(PrestigeConfig.treeAttribute(nodeName)):Connect(function()
		refresh(true)
	end)
end

player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
	task.delay(2, function()
		refresh(false)
	end)
end)
