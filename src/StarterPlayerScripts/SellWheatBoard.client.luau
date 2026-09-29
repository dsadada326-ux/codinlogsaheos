-- The Sell Wheat board on Island 2 (ported from the old game's SellWheatBoardManager).
-- Shows how much Wheat you have and how much Gold it's worth; Sell turns it all into Gold.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local FarmConfig = require(ReplicatedStorage:WaitForChild("FarmConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local sellRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SellWheat")

local holder = workspace:WaitForChild("OtherBoards"):WaitForChild("SellWheat")
	:WaitForChild("SurfaceGuiPart", math.huge):WaitForChild("SellWheatBoardTemplate"):WaitForChild("Holder")
local buttons = holder:WaitForChild("Buttons")
local canSell = buttons:WaitForChild("CanSell")
local cantSell = buttons:WaitForChild("CantSell")
local conversion = holder:WaitForChild("Conversion")
local wheatLabel = conversion:WaitForChild("WheatLabel")
local goldLabel = conversion:WaitForChild("GoldLabel")

local busy = false

local function bounce(button, from)
	local scale = button:FindFirstChild("AffordPopScale")

	if not scale then
		return
	end

	scale.Scale = from
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function refresh()
	local wheat = player:GetAttribute("Wheat") or 0
	local gold = math.floor(wheat * FarmConfig.goldRate(player))

	wheatLabel.Text = NumberFormat.abbreviate(wheat)
	goldLabel.Text = NumberFormat.abbreviate(gold)

	local can = wheat > 0
	canSell.Visible = can
	cantSell.Visible = not can
end

canSell.Activated:Connect(function()
	if busy then
		return
	end

	busy = true

	local ok, result = pcall(function()
		return sellRemote:InvokeServer()
	end)

	if ok and type(result) == "table" and result.ok then
		bounce(canSell, 1.18)
	else
		bounce(canSell, 0.85)
		MessageToPlayer.show("NoWheat")
	end

	refresh()
	task.wait(0.2)
	busy = false
end)

cantSell.Activated:Connect(function()
	bounce(cantSell, 0.85)
	MessageToPlayer.show("NoWheat")
end)

player:GetAttributeChangedSignal("Wheat"):Connect(refresh)
player:GetAttributeChangedSignal(UpgradeConfig.levelAttribute("FarmGoldMultiplier")):Connect(refresh)

refresh()
