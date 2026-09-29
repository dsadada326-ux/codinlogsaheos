-- The Shop (server): gamepass ownership, Robux products (Gems, Global Runes), Tickets
-- (earned every few minutes of playtime, spent in the Ticket shop) and the Profile stats that
-- come from the shop (Robux Spent) and from playing (Total Buttons).
-- Everything to edit is in ReplicatedStorage.ShopConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local ProductHandlers = require(script.Parent:WaitForChild("ProductHandlers"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyTicketRemote = remotes:WaitForChild("BuyTicketItem")
local shopEvent = remotes:WaitForChild("ShopEvent")

local function add(player, attribute, amount)
	player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + amount)
end

------------------------------------------------------------------------------------------
-- gamepasses
------------------------------------------------------------------------------------------
local function allPasses()
	local list = table.clone(ShopConfig.Passes)
	table.insert(list, ShopConfig.Bundle)
	return list
end

local function checkPasses(player)
	while player.Parent and player:GetAttribute("DataLoaded") ~= true do task.wait(0.5) end
	for _, pass in ipairs(allPasses()) do
		if pass.id and pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns and player.Parent then
				player:SetAttribute(ShopConfig.passAttribute(pass.key), true)
			end
		end
	end
end

Players.PlayerAdded:Connect(checkPasses)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(checkPasses, p) end

local priceCache = {}
local function passPrice(id, fallback)
	if priceCache[id] == nil then
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
		end)
		priceCache[id] = ok and info and info.PriceInRobux or fallback or 0
	end
	return priceCache[id]
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased or passId == 0 then return end
	for _, pass in ipairs(allPasses()) do
		if pass.id == passId then
			player:SetAttribute(ShopConfig.passAttribute(pass.key), true)
			add(player, "RobuxSpent", passPrice(passId, pass.price))
			shopEvent:FireClient(player, "pass", pass.key)
		end
	end
end)

------------------------------------------------------------------------------------------
-- developer products (PurchaseService adds Robux Spent for these)
------------------------------------------------------------------------------------------
for _, g in ipairs(ShopConfig.Gems) do
	if g.id and g.id ~= 0 then
		ProductHandlers[g.id] = function(player)
			add(player, "Gems", g.amount)
			shopEvent:FireClient(player, "gems", g.amount)
			return true
		end
	end
end

local grantRunes = ServerStorage:WaitForChild("GrantRunes", 30)
local grantGlobal -- (defined below)
local function grantGlobalRunes(...) return grantGlobal(...) end
for _, option in ipairs(ShopConfig.GlobalRunes.options) do
	if option.id and option.id ~= 0 then
		ProductHandlers[option.id] = function(buyer)
			grantGlobalRunes(buyer.DisplayName, option.amount)
			return true
		end
	end
end

------------------------------------------------------------------------------------------
-- Tickets: +GrantAmount every GrantInterval seconds played (TicketSeconds is saved)
------------------------------------------------------------------------------------------
local interval = ShopConfig.Tickets.GrantInterval
local amount = ShopConfig.Tickets.GrantAmount

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("DataLoaded") == true then
				local s = (player:GetAttribute("TicketSeconds") or 0) + 1
				if s >= interval then
					local grants = math.floor(s / interval)
					s -= grants * interval
					add(player, "Tickets", grants * amount)
					shopEvent:FireClient(player, "tickets", grants * amount)
				end
				player:SetAttribute("TicketSeconds", s)
			end
		end
	end
end)

-- the shop's Tickets switch: anything can be bought with Tickets instead of Robux
grantGlobal = function(buyerName, amount)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("DataLoaded") == true and grantRunes then
			grantRunes:Fire(p, ShopConfig.GlobalRunes.pool, amount)
		end
	end
	shopEvent:FireAllClients("global", buyerName, amount)
end

local lastBuy = {}
buyTicketRemote.OnServerInvoke = function(player, key)
	local entry = type(key) == "string" and ShopConfig.ItemByKey[key]
	if not entry or not entry.def.tickets or player:GetAttribute("DataLoaded") ~= true then
		return { ok = false, reason = "unknown" }
	end
	local now = os.clock()
	if now - (lastBuy[player] or 0) < 0.3 then
		return { ok = false, reason = "busy" }
	end
	lastBuy[player] = now

	local def = entry.def
	if entry.kind == "pass" and ShopConfig.hasPass(player, def.key) then
		return { ok = false, reason = "owned" }
	end
	local tickets = player:GetAttribute("Tickets") or 0
	if tickets < def.tickets then
		return { ok = false, reason = "tickets" }
	end
	player:SetAttribute("Tickets", tickets - def.tickets)

	if entry.kind == "pass" then
		player:SetAttribute(ShopConfig.passAttribute(def.key), true)
		shopEvent:FireClient(player, "pass", def.key)
	elseif entry.kind == "gems" then
		add(player, "Gems", def.amount)
		shopEvent:FireClient(player, "gems", def.amount)
	elseif entry.kind == "global" then
		grantGlobal(player.DisplayName, def.amount)
	end
	return { ok = true, tickets = player:GetAttribute("Tickets") }
end

------------------------------------------------------------------------------------------
-- Total Buttons: every Button ever earned (Buttons itself resets when you prestige)
------------------------------------------------------------------------------------------
local lastButtons = {}

local function watchButtons(player)
	local function start()
		lastButtons[player] = player:GetAttribute("Buttons") or 0
		player:GetAttributeChangedSignal("Buttons"):Connect(function()
			local value = player:GetAttribute("Buttons") or 0
			local last = lastButtons[player] or value
			if value > last then
				add(player, "TotalButtons", value - last)
			end
			lastButtons[player] = value
		end)
	end
	if player:GetAttribute("DataLoaded") == true then
		start()
	else
		local c
		c = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			if player:GetAttribute("DataLoaded") == true then
				c:Disconnect()
				start()
			end
		end)
	end
end

Players.PlayerAdded:Connect(watchButtons)
for _, p in ipairs(Players:GetPlayers()) do watchButtons(p) end

Players.PlayerRemoving:Connect(function(player)
	lastButtons[player] = nil
	lastBuy[player] = nil
end)
