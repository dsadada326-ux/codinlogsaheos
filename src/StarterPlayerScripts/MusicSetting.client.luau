local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))

local music = SoundService:WaitForChild("TycoonBackgroundMusic")
local fullVolume = music.Volume

local function apply()
	local on = player:GetAttribute(SettingsConfig.attributeOf("Music"))

	if on == nil then
		on = SettingsConfig.Settings.Music.Default
	end

	-- a local-only volume change: it does not affect other players
	music.Volume = on and fullVolume or 0
end

player:GetAttributeChangedSignal(SettingsConfig.attributeOf("Music")):Connect(apply)

if player:GetAttribute("DataLoaded") then
	apply()
else
	local connection

	connection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") then
			connection:Disconnect()
			apply()
		end
	end)
end
