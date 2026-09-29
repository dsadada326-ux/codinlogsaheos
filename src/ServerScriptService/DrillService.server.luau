-- DRILLING MANIA (server). The real rules for: the scrap field, the furnace, the drill
-- shop, drill plots + Oil, the craft shop and the Enhancer. Tuning lives in DrillConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DrillConfig = require(ReplicatedStorage:WaitForChild("DrillConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function remote(class, name)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = remotes
	end
	return r
end

local actionRemote = remote("RemoteFunction", "DrillAction") -- (action, ...) -> { ok, reason, ... }
local eventRemote = remote("RemoteEvent", "DrillEvent") -- server -> client: (kind, ...)
local collectRemote = remote("RemoteEvent", "CollectScrap") -- client -> server: { ids }

local spawnPart = workspace:WaitForChild("DrillingMania"):WaitForChild("SpawnPart")

local rng = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function up(player, id)
	return UpgradeConfig.valueAt(id, player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0)
end

local function add(player, attr, amount)
	player:SetAttribute(attr, (player:GetAttribute(attr) or 0) + amount)
end

local function loaded(player)
	return player:GetAttribute("DataLoaded") == true
end

------------------------------------------------------------------------------------------
-- SCRAP FIELD
------------------------------------------------------------------------------------------
local scrapState = {} -- [player] = { nextId, items = { [id] = { pos, kind, value } }, count, acc }

local totalWeight = 0
for _, k in ipairs(DrillConfig.Scrap.Kinds) do
	totalWeight += k.weight
end

local function pickKind()
	local roll = rng:NextNumber() * totalWeight
	for i, k in ipairs(DrillConfig.Scrap.Kinds) do
		roll -= k.weight
		if roll <= 0 then
			return i, k
		end
	end
	return 1, DrillConfig.Scrap.Kinds[1]
end

local function scrapStats(player)
	return {
		interval = up(player, "ScrapSpawnSpeed"),
		capacity = math.floor(up(player, "ScrapCapacity")),
		bulk = math.floor(up(player, "ScrapBulk")),
		range = up(player, "ScrapRange"),
	}
end

local function randomSpot()
	local size = spawnPart.Size
	local x = rng:NextNumber(-size.X / 2 + 2, size.X / 2 - 2)
	local z = rng:NextNumber(-size.Z / 2 + 2, size.Z / 2 - 2)
	return (spawnPart.CFrame * CFrame.new(x, size.Y / 2 + 0.45, z)).Position
end

local function spawnScrap(player, amount)
	local st = scrapState[player]
	if not st then
		return
	end
	local list = {}
	for _ = 1, amount do
		st.nextId += 1
		local kindIndex, kind = pickKind()
		local item = { id = st.nextId, pos = randomSpot(), kind = kindIndex, value = kind.value }
		st.items[item.id] = item
		st.count += 1
		table.insert(list, item)
	end
	if #list > 0 then
		eventRemote:FireClient(player, "scrap", list)
	end
end

local function clearScrap(player)
	local st = scrapState[player]
	if st then
		st.items = {}
		st.count = 0
	end
	eventRemote:FireClient(player, "scrapClear")
end

RunService.Heartbeat:Connect(function(dt)
	for player, st in pairs(scrapState) do
		if loaded(player) then
			local stats = scrapStats(player)
			st.acc += dt
			if st.acc >= stats.interval then
				st.acc = 0
				local room = stats.capacity - st.count
				if room > 0 then
					spawnScrap(player, math.min(room, stats.bulk))
				end
			end
		end
	end
end)

collectRemote.OnServerEvent:Connect(function(player, ids)
	local st = scrapState[player]
	if not st or type(ids) ~= "table" or not loaded(player) then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local reach = up(player, "ScrapRange") + 6 -- a little slack for lag
	local gained, got = 0, {}
	for i, id in ipairs(ids) do
		if i > 60 then
			break
		end
		local item = type(id) == "number" and st.items[id]
		if item then
			local flat = Vector3.new(item.pos.X - root.Position.X, 0, item.pos.Z - root.Position.Z)
			if flat.Magnitude <= reach and math.abs(item.pos.Y - root.Position.Y) < 14 then
				st.items[id] = nil
				st.count -= 1
				gained += item.value
				table.insert(got, id)
			end
		end
	end
	if gained > 0 then
		local amount = math.floor(gained * Multipliers.scrap(player) * 100 + 0.5) / 100
		add(player, "Scrap", amount)
		eventRemote:FireClient(player, "scrapGot", got, amount)
	end
end)

------------------------------------------------------------------------------------------
-- DRILL OIL: every second each placed drill fills up (until it's full)
------------------------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if loaded(player) then
				local placed = DrillConfig.placed(player)
				if next(placed) then
					local mult = Multipliers.oil(player)
					for cellText, id in pairs(placed) do
						local drill = DrillConfig.DrillById[id]
						local cell = tonumber(cellText)
						if drill and cell then
							local rate = drill.rate * mult
							local attr = DrillConfig.oilAttribute(cell)
							local stored = player:GetAttribute(attr) or 0
							local cap = rate * DrillConfig.StorageSeconds
							if stored < cap then
								player:SetAttribute(attr, math.min(cap, math.floor((stored + rate) * 100 + 0.5) / 100))
							end
						end
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------------------------------
-- ACTIONS
------------------------------------------------------------------------------------------
local Actions = {}

-- the scrap currently on your field (when the client (re)starts)
function Actions.scrapSync(player)
	local st = scrapState[player]
	local list = {}
	if st then
		for _, item in pairs(st.items) do
			table.insert(list, item)
		end
	end
	return { ok = true, items = list }
end

-- FURNACE -------------------------------------------------------------------------------
function Actions.furnaceStart(player, percent)
	local f = DrillConfig.Furnace
	if not table.find(f.Percents, percent) then
		return { ok = false, reason = "percent" }
	end
	if (player:GetAttribute("FurnaceScrap") or 0) > 0 then
		return { ok = false, reason = "busy" }
	end
	if now() < (player:GetAttribute("FurnaceCooldown") or 0) then
		return { ok = false, reason = "cooldown" }
	end
	local have = player:GetAttribute("Scrap") or 0
	local scrap = math.floor(have * percent / 100)
	if scrap < f.MinScrap then
		return { ok = false, reason = "scrap" }
	end
	local iron = math.max(1, math.floor(scrap / f.ScrapPerIron * Multipliers.iron(player)))
	local seconds = DrillConfig.furnaceSeconds(scrap, up(player, "FurnaceSpeed"))
	local t = now()
	player:SetAttribute("Scrap", math.max(0, have - scrap))
	player:SetAttribute("FurnaceScrap", scrap)
	player:SetAttribute("FurnaceIron", iron)
	player:SetAttribute("FurnaceStart", t)
	player:SetAttribute("FurnaceEnd", t + seconds)
	return { ok = true, iron = iron, seconds = seconds }
end

function Actions.furnaceClaim(player)
	if (player:GetAttribute("FurnaceScrap") or 0) <= 0 then
		return { ok = false, reason = "empty" }
	end
	if now() < (player:GetAttribute("FurnaceEnd") or 0) - 0.25 then
		return { ok = false, reason = "cooking" }
	end
	local iron = player:GetAttribute("FurnaceIron") or 0
	add(player, "Metal", iron)
	player:SetAttribute("FurnaceScrap", 0)
	player:SetAttribute("FurnaceIron", 0)
	player:SetAttribute("FurnaceStart", 0)
	player:SetAttribute("FurnaceEnd", 0)
	player:SetAttribute("FurnaceCooldown", now() + DrillConfig.Furnace.Cooldown)
	return { ok = true, iron = iron }
end

-- DRILL SHOP ----------------------------------------------------------------------------
function Actions.buyDrill(player, id)
	local drill = DrillConfig.DrillById[id]
	if not drill then
		return { ok = false, reason = "unknown" }
	end
	local inv = DrillConfig.inventory(player)
	if (inv[id] or 0) >= DrillConfig.MaxOwnedPerDrill then
		return { ok = false, reason = "full" }
	end
	local stock = DrillConfig.stock(player)
	if (stock[id] or 0) < 1 then
		return { ok = false, reason = "stock" }
	end
	local metal = player:GetAttribute("Metal") or 0
	if metal < drill.price then
		return { ok = false, reason = "iron" }
	end
	player:SetAttribute("Metal", metal - drill.price)
	stock[id] -= 1
	player:SetAttribute("DrillStock", DrillConfig.encode(stock))
	inv[id] = (inv[id] or 0) + 1
	player:SetAttribute("DrillInv", DrillConfig.encode(inv))
	return { ok = true }
end

-- STOCK ---------------------------------------------------------------------------------
-- everyone gets the same shop each restock window; a Robux restock rerolls just yours
local function restockDrills(player, forced)
	if not loaded(player) then
		return false
	end
	local window = DrillConfig.stockWindow(now())
	if not forced and player:GetAttribute("DrillStockWindow") == window then
		return false
	end
	local seed = window * 7919 + 17
	if forced then
		seed = rng:NextInteger(1, 2 ^ 30)
	end
	player:SetAttribute("DrillStock", DrillConfig.encode(DrillConfig.rollStock(seed)))
	player:SetAttribute("DrillStockWindow", window)
	eventRemote:FireClient(player, "restocked", forced == true)
	return true
end

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(restockDrills, player)
		end
		task.wait(1)
	end
end)

-- the 15 Robux restock (Developer Product, id in DrillConfig.Stock.RestockProductId)
if DrillConfig.Stock.RestockProductId ~= 0 then
	local ProductHandlers = require(script.Parent:WaitForChild("ProductHandlers"))
	ProductHandlers[DrillConfig.Stock.RestockProductId] = function(player)
		return restockDrills(player, true)
	end
end

-- no product id yet: in Studio the button restocks for free so you can test it
function Actions.restockTest(player)
	if DrillConfig.Stock.RestockProductId ~= 0 or not RunService:IsStudio() then
		return { ok = false, reason = "product" }
	end
	return { ok = restockDrills(player, true) }
end

-- PLOTS ---------------------------------------------------------------------------------
function Actions.buyPlot(player)
	local owned = player:GetAttribute("DrillPlots") or 0
	if owned >= DrillConfig.MaxPlots then
		return { ok = false, reason = "max" }
	end
	local price = DrillConfig.PlotPrices[owned + 1]
	local metal = player:GetAttribute("Metal") or 0
	if metal < price then
		return { ok = false, reason = "iron" }
	end
	player:SetAttribute("Metal", metal - price)
	player:SetAttribute("DrillPlots", owned + 1)
	return { ok = true, plot = owned + 1 }
end

local function collectCell(player, cell)
	local attr = DrillConfig.oilAttribute(cell)
	local stored = math.floor(player:GetAttribute(attr) or 0)
	if stored >= 1 then
		add(player, "Oil", stored)
		player:SetAttribute(attr, (player:GetAttribute(attr) or 0) - stored)
	end
	return stored
end

local function validCell(player, cell)
	return type(cell) == "number" and cell == math.floor(cell) and cell >= 1 and cell <= (player:GetAttribute("DrillPlots") or 0)
end

function Actions.place(player, cell, id)
	if not validCell(player, cell) or not DrillConfig.DrillById[id] then
		return { ok = false, reason = "bad" }
	end
	local placed = DrillConfig.placed(player)
	if placed[tostring(cell)] then
		return { ok = false, reason = "taken" }
	end
	local inv = DrillConfig.inventory(player)
	if (inv[id] or 0) < 1 then
		return { ok = false, reason = "none" }
	end
	inv[id] -= 1
	if inv[id] <= 0 then
		inv[id] = nil
	end
	placed[tostring(cell)] = id
	player:SetAttribute(DrillConfig.oilAttribute(cell), 0)
	player:SetAttribute("DrillInv", DrillConfig.encode(inv))
	player:SetAttribute("DrillPlaced", DrillConfig.encode(placed))
	return { ok = true }
end

function Actions.remove(player, cell)
	if not validCell(player, cell) then
		return { ok = false, reason = "bad" }
	end
	local placed = DrillConfig.placed(player)
	local id = placed[tostring(cell)]
	if not id then
		return { ok = false, reason = "empty" }
	end
	local oil = collectCell(player, cell)
	placed[tostring(cell)] = nil
	player:SetAttribute(DrillConfig.oilAttribute(cell), 0)
	local inv = DrillConfig.inventory(player)
	inv[id] = (inv[id] or 0) + 1
	player:SetAttribute("DrillInv", DrillConfig.encode(inv))
	player:SetAttribute("DrillPlaced", DrillConfig.encode(placed))
	return { ok = true, oil = oil }
end

function Actions.collect(player, cell)
	if not validCell(player, cell) then
		return { ok = false, reason = "bad" }
	end
	local oil = collectCell(player, cell)
	return { ok = oil > 0, oil = oil }
end

-- CRAFTING ------------------------------------------------------------------------------
function Actions.craft(player, recipeId, count)
	local r = DrillConfig.RecipeById[recipeId]
	if not r then
		return { ok = false, reason = "unknown" }
	end
	local oil = player:GetAttribute("Oil") or 0
	local metal = player:GetAttribute("Metal") or 0
	local most = math.min(math.floor(oil / r.oil), math.floor(metal / r.iron))
	if count == "max" then
		count = most
	elseif type(count) ~= "number" then
		return { ok = false, reason = "bad" }
	else
		count = math.floor(math.clamp(count, 0, 1e6))
	end
	if count < 1 or count > most then
		return { ok = false, reason = "cost" }
	end
	local coins = math.floor(r.coins * count * Multipliers.craftCoins(player))
	player:SetAttribute("Oil", oil - r.oil * count)
	player:SetAttribute("Metal", metal - r.iron * count)
	add(player, "Coins", coins)
	return { ok = true, coins = coins, count = count }
end

-- ENHANCER ------------------------------------------------------------------------------
function Actions.enhance(player)
	local tier = player:GetAttribute("DrillEnhance") or 0
	local def = DrillConfig.Enhancer[tier + 1]
	if not def then
		return { ok = false, reason = "max" }
	end
	if (player:GetAttribute("Oil") or 0) < def.oil then
		return { ok = false, reason = "oil" }
	end
	for _, c in ipairs(DrillConfig.ResetCurrencies) do
		player:SetAttribute(c, 0)
	end
	player:SetAttribute("DrillInv", "{}")
	player:SetAttribute("DrillPlaced", "{}")
	player:SetAttribute("DrillPlots", 0)
	for cell = 1, DrillConfig.MaxPlots do
		player:SetAttribute(DrillConfig.oilAttribute(cell), 0)
	end
	for _, a in ipairs({ "FurnaceScrap", "FurnaceIron", "FurnaceStart", "FurnaceEnd", "FurnaceCooldown" }) do
		player:SetAttribute(a, 0)
	end
	for _, id in ipairs(UpgradeConfig.Order) do
		if UpgradeConfig.Upgrades[id].Drill then
			player:SetAttribute(UpgradeConfig.levelAttribute(id), 0)
		end
	end
	clearScrap(player)
	player:SetAttribute("DrillEnhance", tier + 1)
	eventRemote:FireClient(player, "enhanced", tier + 1)
	return { ok = true, tier = tier + 1 }
end

local lastAction = {}
actionRemote.OnServerInvoke = function(player, action, ...)
	if type(action) ~= "string" or not Actions[action] then
		return { ok = false, reason = "unknown" }
	end
	if not loaded(player) then
		return { ok = false, reason = "loading" }
	end
	if action ~= "scrapSync" and action ~= "collect" then
		local t = os.clock()
		if t - (lastAction[player] or 0) < 0.12 then
			return { ok = false, reason = "cooldown" }
		end
		lastAction[player] = t
	end
	local ok, result = pcall(Actions[action], player, ...)
	if not ok then
		warn("[DrillService] " .. action .. ": " .. tostring(result))
		return { ok = false, reason = "error" }
	end
	return result
end

------------------------------------------------------------------------------------------
-- players
------------------------------------------------------------------------------------------
local function onPlayer(player)
	scrapState[player] = { nextId = 0, items = {}, count = 0, acc = 0 }
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(player)
	scrapState[player] = nil
	lastAction[player] = nil
end)
