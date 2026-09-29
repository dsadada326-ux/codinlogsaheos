local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))

local clickSound = Instance.new("Sound")
clickSound.Name = "UIClickSound"
clickSound.SoundId = "rbxassetid://139719503904449"
clickSound.Volume = 0.6
clickSound.Parent = SoundService

local function settingOn()
	local on = player:GetAttribute(SettingsConfig.attributeOf("SFX"))

	if on == nil then
		on = SettingsConfig.Settings.SFX.Default
	end

	return on
end

local function playClick()
	if not settingOn() then
		return
	end

	clickSound:Stop()
	clickSound.TimePosition = 0
	clickSound:Play()
end

local connected = {}

-- every TextButton/ImageButton, anywhere in this player's UI, now and later
local function watch(button)
	if connected[button] then
		return
	end

	connected[button] = true

	button.Activated:Connect(playClick)

	button.Destroying:Connect(function()
		connected[button] = nil
	end)
end

local function scan(root)
	if root:IsA("GuiButton") then
		watch(root)
	end

	for _, child in ipairs(root:GetChildren()) do
		scan(child)
	end
end

scan(playerGui)

playerGui.DescendantAdded:Connect(function(inst)
	if inst:IsA("GuiButton") then
		watch(inst)
	end
end)

-- the upgrade board and conversion board are SurfaceGuis in the world, not PlayerGui,
-- but their Buy / Convert buttons should click just the same
local function watchWorldBoard(getRoot)
	task.spawn(function()
		local root = getRoot()

		if root then
			scan(root)

			root.DescendantAdded:Connect(function(inst)
				if inst:IsA("GuiButton") then
					watch(inst)
				end
			end)
		end
	end)
end

watchWorldBoard(function()
	return workspace
		:WaitForChild("UpgradeBoards")
		:WaitForChild("Island1")
		:WaitForChild("Starter")
		:WaitForChild("SurfaceGuiPart")
		:WaitForChild("UpgradeBoardTemplate")
end)

watchWorldBoard(function()
	return workspace
		:WaitForChild("OtherBoards")
		:WaitForChild("Conversion")
		:WaitForChild("SurfaceGuiPart")
		:WaitForChild("ConversionBoardTemplaet")
end)


-- the rest of the boards with buttons
for _, path in ipairs({
	{ "OtherBoards", "Rebirth" },
	{ "UpgradeBoards", "Island1", "RebirthBoosts" },
	{ "UpgradeBoards", "Island1", "Time" },
	{ "UpgradeBoards", "Island1", "Gems" },
	{ "UpgradeBoards", "Island1", "TimeBoosts" },
	{ "OtherBoards", "Prestige" },
	{ "UpgradeBoards", "Island1", "Coins" },
	{ "UpgradeBoards", "Island1", "Tycoon" },
	{ "UpgradeBoards", "Island2", "TreeUpgrades" },
	{ "Islands", "Island2", "Tiers" },
}) do
	watchWorldBoard(function()
		local node = workspace

		for _, name in ipairs(path) do
			node = node:WaitForChild(name)
		end

		return node
	end)
end
