local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))

local INTERVAL = 45 -- seconds between hints

local HINTS = {
	"Tip: hold a click combo going to boost your multiplier up to 1.5x!",
	"Tip: bigger Button stacks convert at a better rate, so let them build up.",
	"Tip: Auto Clickers keep earning buttons even while you're away.",
	"Tip: critical clicks pay out extra, and the chance/multiplier can both be upgraded.",
	"Tip: press VIEW near the button for a close-up camera angle.",
	"Tip: you can turn this off any time in Settings > Chat Hints.",
}

local function settingOn()
	local on = player:GetAttribute(SettingsConfig.attributeOf("Chat Hints"))

	if on == nil then
		on = SettingsConfig.Settings["Chat Hints"].Default
	end

	return on
end

local function sendHint(text)
	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = text,
			Color = Color3.fromRGB(120, 200, 255),
			Font = Enum.Font.SourceSansBold,
		})
	end)
end

task.spawn(function()
	-- wait for data to load so the setting is correct from the start
	if not player:GetAttribute("DataLoaded") then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	local index = 0

	while true do
		task.wait(INTERVAL)

		if settingOn() then
			index = index % #HINTS + 1
			sendHint(HINTS[index])
		end
	end
end)
