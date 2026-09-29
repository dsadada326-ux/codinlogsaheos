local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local PrestigeConfig = require(ReplicatedStorage:WaitForChild("PrestigeConfig"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local setSetting = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSetting")

local board = workspace:WaitForChild("UpgradeBoards"):WaitForChild("Island1"):WaitForChild("Starter")
local panel = board:WaitForChild("AutoUpgradeSurfacePart")
local back = board:WaitForChild("AutoUpgradeBackGround")
local gui = panel:WaitForChild("AutoUpgradeGui")
local onButton = gui:WaitForChild("On")
local offButton = gui:WaitForChild("Off")

local KEY = "AutoUpgradeStarter"

local function isOn()
	local value = player:GetAttribute(SettingsConfig.attributeOf(KEY))

	if value == nil then
		return SettingsConfig.Settings[KEY].Default
	end

	return value
end

local shown = nil

local function refresh()
	local unlocked = PrestigeConfig.hasPerk(player, "AutoStarter")

	if unlocked ~= shown then
		shown = unlocked

		for _, part in ipairs({ panel, back }) do
			part.LocalTransparencyModifier = unlocked and 0 or 1
			part.CanCollide = unlocked
			part.CanQuery = unlocked
		end

		gui.Enabled = unlocked
	end

	onButton.Visible = isOn()
	offButton.Visible = not isOn()
end

local function bounce(button)
	local scale = button:FindFirstChild("AffordPopScale")

	if scale then
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

for _, button in ipairs({ onButton, offButton }) do
	button.Activated:Connect(function()
		setSetting:FireServer(KEY, not isOn())
		bounce(button)
	end)
end

player:GetAttributeChangedSignal("Prestige"):Connect(refresh)
player:GetAttributeChangedSignal(SettingsConfig.attributeOf(KEY)):Connect(refresh)

refresh()
