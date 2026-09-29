local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local PrestigeConfig = require(ReplicatedStorage:WaitForChild("PrestigeConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local doPrestige = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DoPrestige")

local gui = workspace:WaitForChild("OtherBoards"):WaitForChild("Prestige")
	:WaitForChild("SurfaceGuiPart"):WaitForChild("PrestigeBoardTemplate")

local holder = gui:WaitForChild("Holder")
local title = holder:WaitForChild("Title")
local lines = holder:WaitForChild("MultipliedCurrencies")
local moneyLine = lines:WaitForChild("MoneyMultiplier")
local rebirthLine = lines:WaitForChild("RebirthsMultiplier")
local timeLine = lines:WaitForChild("TimeMultiplier")
local perkLine = lines:WaitForChild("AutomatesBoardStarter")
local buttons = holder:WaitForChild("Buttons")
local canBuy = buttons:WaitForChild("CanBuy")
local cantBuy = buttons:WaitForChild("CantBuy")
local costLabel = gui:WaitForChild("Cost")

local locked = gui:FindFirstChild("Locked")
if locked then
	locked.Visible = false -- leftover template panel, not used
end

-- the board's own colors for each currency
local COLORS = {
	Money = { stroke = "#0F5C1E", font = "#7BE38B" },
	Rebirths = { stroke = "#3B1E66", font = "#C9A6FF" },
	Time = { stroke = "#731717", font = "#FF8A8A" },
}

local function fmt(x)
	return (string.format("%g", x))
end

local function line(currency, from, to)
	local c = COLORS[currency]
	local piece = function(text)
		return string.format('<stroke color="%s" thickness="2"><font color="%s">%s</font></stroke>', c.stroke, c.font, text)
	end

	if to == nil then
		return piece("x" .. fmt(from) .. " " .. currency)
	end

	return piece("x" .. fmt(from) .. " " .. currency)
		.. ' <stroke color="#3A3E44" thickness="2"><font color="#AEB4BC">→</font></stroke> '
		.. piece("x" .. fmt(to) .. " " .. currency)
end

local function bounce(button, from)
	local scale = button:FindFirstChild("AffordPopScale")

	if not scale then
		return
	end

	scale.Scale = from

	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function refresh()
	local level = PrestigeConfig.level(player)
	local now = PrestigeConfig.multipliersAt(level)
	local nextDef = PrestigeConfig.Levels[level + 1]

	if not nextDef then
		title.Text = "Prestige " .. level .. " (MAX)"
		moneyLine.Text = line("Money", now.money)
		rebirthLine.Text = line("Rebirths", now.rebirths)
		timeLine.Text = line("Time", now.time)
		perkLine.Text = '<font color="#FFA333">MAX</font> Prestige reached on this island'
		costLabel.Text = "Maxed!"
		canBuy.Visible = false
		cantBuy.Visible = true
		return
	end

	title.Text = "Prestige " .. level .. " → " .. (level + 1)
	moneyLine.Text = line("Money", now.money, nextDef.money)
	rebirthLine.Text = line("Rebirths", now.rebirths, nextDef.rebirths)
	timeLine.Text = line("Time", now.time, nextDef.time)
	perkLine.Text = nextDef.perkText or ""
	perkLine.Visible = nextDef.perkText ~= nil

	local rebirths = player:GetAttribute("Rebirths") or 0
	costLabel.Text = NumberFormat.abbreviate(rebirths) .. " / " .. NumberFormat.abbreviate(nextDef.cost) .. " Rebirths"

	local affordable = rebirths >= nextDef.cost
	canBuy.Visible = affordable
	cantBuy.Visible = not affordable
end

local busy = false

canBuy.Activated:Connect(function()
	if busy then
		return
	end

	busy = true

	local ok, result = pcall(function()
		return doPrestige:InvokeServer()
	end)

	bounce(canBuy, ok and type(result) == "table" and result.ok and 1.2 or 0.85)
	refresh()

	task.wait(0.3)
	busy = false
end)

cantBuy.Activated:Connect(function()
	bounce(cantBuy, 0.85)
end)

for _, attribute in ipairs({ "Prestige", "Rebirths" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end

refresh()
