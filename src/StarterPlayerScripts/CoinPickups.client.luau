local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local CoinConfig = require(ReplicatedStorage:WaitForChild("CoinConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local coinSpawned = remotes:WaitForChild("CoinSpawned")
local coinRemoved = remotes:WaitForChild("CoinRemoved")
local collectCoin = remotes:WaitForChild("CollectCoin")

local folder = Instance.new("Folder")
folder.Name = "MyCoins"
folder.Parent = workspace

local coins = {} -- [id] = { part, requested }

local GOLD = Color3.fromRGB(255, 205, 50)

local coinTemplate = ReplicatedStorage:WaitForChild("CoinModel")
local FULL_SIZE = coinTemplate.Size

local function makeCoin(position)
	local coin = coinTemplate:Clone()
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CanTouch = false
	coin.CFrame = CFrame.new(position)
	coin.Parent = folder

	-- pop in
	coin.Size = FULL_SIZE * 0.15
	TweenService:Create(coin, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = FULL_SIZE }):Play()

	return coin
end

coinSpawned.OnClientEvent:Connect(function(id, position)
	if coins[id] then
		return
	end

	coins[id] = { part = makeCoin(position), base = position, requested = false, born = os.clock() }
end)

coinRemoved.OnClientEvent:Connect(function(id)
	local c = coins[id]

	if not c then
		return
	end

	coins[id] = nil

	-- fly up, shrink, gone
	local part = c.part
	TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = part.CFrame + Vector3.new(0, 3, 0),
		Size = FULL_SIZE * 0.15,
	}):Play()
	Debris:AddItem(part, 0.35)
end)

-- spin + bob, and pick up the ones you walk into
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()

	for id, c in pairs(coins) do
		local bob = math.sin((now - c.born) * 3) * 0.3
		c.part.CFrame = CFrame.new(c.base + Vector3.new(0, bob, 0)) * CFrame.Angles(0, now * 3, 0) -- upright, spinning

		if root and not c.requested and (root.Position - c.base).Magnitude <= CoinConfig.PickupRange * 0.7 then
			c.requested = true
			collectCoin:FireServer(id)

			task.delay(1, function()
				if coins[id] then
					coins[id].requested = false -- try again if the server didn't take it
				end
			end)
		end
	end
end)
