local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrestigeConfig = require(ReplicatedStorage:WaitForChild("PrestigeConfig"))

local tree = workspace:WaitForChild("Islands"):WaitForChild("Island1"):WaitForChild("UpgradeTree")
local island2Tree = workspace:WaitForChild("UpgradeBoards"):WaitForChild("Island2"):WaitForChild("UpgradeTree")
local fishTree = workspace:WaitForChild("Islands"):WaitForChild("FishingFrenzySub-1"):WaitForChild("UpgradeTree")

local lastTry = {} -- [player][node] = time

local function round2(number)
	return math.floor(number * 100 + 0.5) / 100
end

-- buys a node if its parent is owned (step on it, or click it).
-- Island 1 nodes cost Cash, Island 2 nodes cost Gold.
local function tryBuy(player, node)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	lastTry[player] = lastTry[player] or {}
	local now = os.clock()

	if now - (lastTry[player][node] or 0) < 0.5 then
		return
	end

	lastTry[player][node] = now

	if not PrestigeConfig.available(player, node) then
		return
	end

	local cost = PrestigeConfig.treeDef(node).cost
	local currency = PrestigeConfig.treeCurrency(node)
	local balance = player:GetAttribute(currency) or 0

	if balance < cost then
		return
	end

	player:SetAttribute(currency, round2(balance - cost))
	player:SetAttribute(PrestigeConfig.treeAttribute(node), true)
end

local function wire(folder, node)
	local model = folder:WaitForChild(node)
	local hitbox = model:WaitForChild("Hitbox")

	hitbox.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)

		if player then
			tryBuy(player, node)
		end
	end)

	local click = hitbox:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
	click.MaxActivationDistance = 80
	click.Parent = hitbox

	click.MouseClick:Connect(function(player)
		tryBuy(player, node)
	end)

	-- the sign on top has its own click detector on some nodes
	local display = model:FindFirstChild("Display")
	local signClick = display and display:FindFirstChildOfClass("ClickDetector")

	if signClick then
		signClick.MaxActivationDistance = 80
		signClick.MouseClick:Connect(function(player)
			tryBuy(player, node)
		end)
	end
end

for node in pairs(PrestigeConfig.Tree) do
	wire(tree, node)
end

for node in pairs(PrestigeConfig.Island2Tree) do
	wire(island2Tree, node)
end

-- Fishing Frenzy tree (paid in Crabs)
for node in pairs(PrestigeConfig.FishTree) do
	task.spawn(wire, fishTree, node)
end

Players.PlayerRemoving:Connect(function(player)
	lastTry[player] = nil
end)
