local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("ComboConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))
local clickReward = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("ClickReward")

local ClickHandler = {}

local rng = Random.new()

-- the real combo lives here on the server; the client only shows it
local combos = {} -- [player] = { start, last, count }

local function round2(number)
	return math.floor(number * 100 + 0.5) / 100
end

local function addCurrency(player, name, amount)
	local current = player:GetAttribute(name) or 0

	player:SetAttribute(name, round2(current + amount))
end

local function upgradeValue(player, id)
	return UpgradeConfig.valueAt(
		id,
		player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0
	)
end

-- Button Multiplier stacked with the Rebirth Buttons upgrade
local function buttonMultiplierOf(player)
	return Multipliers.buttons(player) -- upgrades x Gems x Buttons runes
end

-- Critical Multiplier stacked with the Rebirth Critical upgrade
local function critMultiplierOf(player)
	return upgradeValue(player, "CritMultiplier")
		* upgradeValue(player, "RebirthCritMultiplier")
end

-- called every time a player clicks the red button
function ClickHandler.click(player)
	-- wait until their saved data has loaded so nothing gets overwritten
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	local now = os.clock()
	local combo = combos[player]

	if not combo then
		combo = { start = nil, last = 0, count = 0 }
		combos[player] = combo
	end

	-- ignore impossibly fast clicking
	if now - combo.last < Config.MinClickInterval then
		return
	end

	-- combo ends after a pause
	if combo.start and now - combo.last > Config.ComboTimeout then
		combo.start = nil
		combo.count = 0
	end

	if not combo.start then
		combo.start = now
		combo.count = 0
	end

	combo.count += 1
	combo.last = now

	local progress = math.clamp(
		(now - combo.start) / Config.TimeToMax,
		0,
		1
	)

	local multiplier = 1 + (Config.MaxMultiplier - 1) * progress

	-- Button Multiplier upgrade: more buttons per click
	local amount = Config.BaseReward * multiplier * buttonMultiplierOf(player)

	-- critical click: the Critical Chance / Critical Multiplier upgrades
	local critChance = upgradeValue(player, "CritChance")
	local crit = critChance > 0 and rng:NextNumber() < critChance

	if crit then
		amount *= critMultiplierOf(player)
	end

	amount = round2(amount)

	addCurrency(player, "Buttons", amount)

	clickReward:FireClient(player, amount, multiplier, crit)

	return amount, multiplier, crit
end

-- Auto Clickers: `count` clicks at once. Button Multiplier and criticals apply,
-- but there is no combo (that stays with the player's own clicks) and it never touches their combo.
function ClickHandler.autoClicks(player, count)
	if player:GetAttribute("DataLoaded") ~= true or count < 1 then
		return
	end

	local buttonMultiplier = buttonMultiplierOf(player)
	local critChance = upgradeValue(player, "CritChance")
	local critMultiplier = critMultiplierOf(player)

	local total, crits = 0, 0

	for _ = 1, count do
		local amount = Config.BaseReward * buttonMultiplier

		if critChance > 0 and rng:NextNumber() < critChance then
			amount *= critMultiplier
			crits += 1
		end

		total += amount
	end

	total = round2(total)

	addCurrency(player, "Buttons", total)

	-- one popup for the whole batch (4th value = it came from Auto Clickers)
	clickReward:FireClient(player, total, 1, crits > 0, true)

	return total, crits
end

Players.PlayerRemoving:Connect(function(player)
	combos[player] = nil
end)

return ClickHandler
