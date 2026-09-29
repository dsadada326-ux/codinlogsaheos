local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- the same settings the server uses
local Config = require(ReplicatedStorage:WaitForChild("ConversionConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))
local convertRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("ConvertButtons")

local board = workspace
	:WaitForChild("OtherBoards")
	:WaitForChild("Conversion")
	:WaitForChild("SurfaceGuiPart")
	:WaitForChild("ConversionBoardTemplaet")
	:WaitForChild("Convert")

-- "1 Button =" + "X Cash" sit in one row that centers itself (PriceLine)
local cashAmount = board:WaitForChild("PriceLine"):WaitForChild("CashAmount") -- "X Cash" -> what one button is worth
local costLabel = board:WaitForChild("Cost")        -- "+1 Cash" -> what you'd get right now
local convertButton = board:WaitForChild("Buttons"):WaitForChild("CanBuy")
local popScale = convertButton:WaitForChild("AffordPopScale")

-- settings
local FLASH_TIME = 1.2 -- seconds the "SOLD +X Cash" result stays after converting

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1 -> "1", 1.5 -> "1.5", 1.27 -> "1.27", 12345 -> "12.3K"
local function formatCash(value)
	if value >= 1000 then
		local index = 0

		while value >= 1000 and index < #SUFFIXES - 1 do
			value /= 1000
			index += 1
		end

		local text = string.format("%.1f", math.floor(value * 10) / 10)
		text = text:gsub("%.0$", "")

		return text .. SUFFIXES[index + 1]
	end

	local text = string.format("%.2f", value)
	text = text:gsub("0+$", "")
	text = text:gsub("%.$", "")

	return text
end

local function round2(number)
	return math.floor(number * 100 + 0.5) / 100
end

-- the price line pops every time Button Value visibly ticks up
local valuePop = Instance.new("UIScale")
valuePop.Name = "ValuePop"
valuePop.Parent = cashAmount

local function popValue()
	valuePop.Scale = 1.18

	TweenService:Create(
		valuePop,
		TweenInfo.new(
			0.4,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{ Scale = 1 }
	):Play()
end

local flashText = ""
local flashUntil = 0
local started = false

RunService.Heartbeat:Connect(function()
	local buttons = player:GetAttribute("Buttons") or 0
	local value = player:GetAttribute("ButtonValue") or Config.StartValue

	-- every Cash multiplier you have (same function the server pays out with)
	local cashMultiplier = Multipliers.money(player)

	-- "1 Button = X Cash": what one button is worth to you (Button Value x Cash Multiplier)
	local valueText = formatCash(round2(value * cashMultiplier)) .. " Cash"

	if cashAmount.Text ~= valueText then
		cashAmount.Text = valueText

		if started then
			popValue()
		end
	end

	started = true

	-- "+X Cash": what converting all your buttons would give right now
	local costText

	if os.clock() < flashUntil then
		costText = flashText
	else
		costText = "+" .. formatCash(Config.cashFor(buttons, value, cashMultiplier)) .. " Cash"
	end

	if costLabel.Text ~= costText then
		costLabel.Text = costText
	end
end)

-- the Convert! button ------------------------------------------------------
local busy = false

local function bounce(from)
	popScale.Scale = from

	TweenService:Create(
		popScale,
		TweenInfo.new(
			0.3,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{ Scale = 1 }
	):Play()
end

convertButton.Activated:Connect(function()
	if busy then
		return
	end

	busy = true

	local ok, result = pcall(function()
		return convertRemote:InvokeServer()
	end)

	if ok and type(result) == "table" and result.ok then
		bounce(1.15)

		flashText = "SOLD +" .. formatCash(result.cash) .. " Cash"
		flashUntil = os.clock() + FLASH_TIME
	else
		bounce(0.88) -- nothing to sell
	end

	task.wait(0.15)
	busy = false
end)


-- tutorial lock: the "Finish Tutorial" screen shows until Button Multiplier is 3/5 ------------
local boardGui = board.Parent
local lockedScreen = boardGui:WaitForChild("Locked")

local lockScale = Instance.new("UIScale")
lockScale.Name = "UnlockPop"
lockScale.Parent = board

local wasUnlocked = nil

local function applyLock()
	local unlocked = UpgradeConfig.isUnlocked(player, "CashMultiplier")

	lockedScreen.Visible = not unlocked
	board.Visible = unlocked

	if unlocked and wasUnlocked == false then
		-- just unlocked: the board pops in
		lockScale.Scale = 0.8

		TweenService:Create(
			lockScale,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end

	wasUnlocked = unlocked
end

player:GetAttributeChangedSignal(UpgradeConfig.unlockAttribute("CashMultiplier")):Connect(applyLock)
player:GetAttributeChangedSignal(UpgradeConfig.levelAttribute("CashMultiplier")):Connect(applyLock)

applyLock()
