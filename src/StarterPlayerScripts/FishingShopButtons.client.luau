-- The Rods / Sell / Magnets buttons at the top of the screen (StarterGui.Fishing.Top) jump you to
-- the matching Fishing Frenzy stall with a quick blink. Magnets goes to Shell Upgrades.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local IslandTransition = require(ReplicatedStorage:WaitForChild("IslandTransition"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FishingShopTeleport")

local row = player:WaitForChild("PlayerGui"):WaitForChild("Fishing"):WaitForChild("Top"):WaitForChild("Frame")

-- button frame -> shop
local BUTTONS = {
	Rods = "Rods",
	MyHome = "Sell", -- the Sell button's frame is named MyHome
	Magnets = "Upgrades",
}

local function bounce(frame)
	local scale = frame:FindFirstChild("PressScale") or Instance.new("UIScale")
	scale.Name = "PressScale"
	scale.Parent = frame
	scale.Scale = 0.88
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

for frameName, shop in pairs(BUTTONS) do
	local frame = row:WaitForChild(frameName)
	local main = frame:WaitForChild("MainButton")

	local function go()
		bounce(frame)

		if IslandTransition.isBusy() then
			return
		end

		IslandTransition.blink(function()
			return remote:InvokeServer(shop)
		end)
	end

	-- the MainButton and its lighter BG layer are both ImageButtons. BG sits on top and eats the
	-- click, but it had Active = false so its Activated never fired: listen to every button layer.
	local busy = false
	local function press()
		if busy then return end
		busy = true
		task.delay(0.25, function() busy = false end)
		go()
	end
	for _, b in ipairs(main:GetDescendants()) do
		if b:IsA("GuiButton") then
			b.Active = true
			b.Activated:Connect(press)
		end
	end
	main.Activated:Connect(press)
end
