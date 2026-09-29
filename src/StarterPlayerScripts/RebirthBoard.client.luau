local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local doRebirth = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("DoRebirth")

local card = workspace
	:WaitForChild("OtherBoards")
	:WaitForChild("Rebirth")
	:WaitForChild("SurfaceGuiPart")
	:WaitForChild("RebirthBoardTemplate")
	:WaitForChild("UpgradeTemplate")

local amountLabel = card:WaitForChild("Amount") -- "X (+Y)"
local buttons = card:WaitForChild("Buttons")
local canBuy = buttons:WaitForChild("CanBuy")   -- green
local cantBuy = buttons:WaitForChild("CantBuy") -- red

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function abbreviate(value)
	value = math.floor(value)

	if value < 1000 then
		return tostring(value)
	end

	local index = 0

	while value >= 1000 and index < #SUFFIXES - 1 do
		value /= 1000
		index += 1
	end

	local text = string.format("%.1f", math.floor(value * 10) / 10)
	text = text:gsub("%.0$", "")

	return text .. SUFFIXES[index + 1]
end

local function setText(label, text)
	if label.Text ~= text then
		label.Text = text
	end
end

local function setVisible(object, visible)
	if object.Visible ~= visible then
		object.Visible = visible
	end
end

local function bounce(scale, from)
	scale.Scale = from

	TweenService:Create(
		scale,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

local function refresh()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local potential = RebirthConfig.potentialFor(player) -- same as the server, incl. Gems

	setText(amountLabel, string.format("%s (+%s)", abbreviate(rebirths), abbreviate(potential)))

	local canAfford = potential >= 1

	setVisible(canBuy, canAfford)
	setVisible(cantBuy, not canAfford)
end

player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
player:GetAttributeChangedSignal("Cash"):Connect(refresh)
for _, attribute in ipairs({ "Upgrade_GemRebirthMultiplier", "Upgrade_TimeRebirthBoost", "Prestige", "Tree_Upgrade2", "Tree_Upgrade5", "Tree_Upgrade6", "Tree_Upgrade10" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()

-- the Rebirth button ---------------------------------------------------------------
local busy = false

canBuy.Activated:Connect(function()
	if busy then
		return
	end

	busy = true

	local ok, result = pcall(function()
		return doRebirth:InvokeServer()
	end)

	local pop = canBuy:FindFirstChild("AffordPopScale")

	if ok and type(result) == "table" and result.ok then
		if pop then
			bounce(pop, 1.2)
		end
	elseif pop then
		bounce(pop, 0.85)
	end

	task.wait(0.15)
	busy = false
end)

cantBuy.Activated:Connect(function()
	local pop = cantBuy:FindFirstChild("AffordPopScale")

	if pop then
		bounce(pop, 0.85)
	end
end)
