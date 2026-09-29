-- The Shop: gamepasses, Robux products (Gems, Global Runes) and the Ticket shop.
--
-- SETTING UP A PASS / PRODUCT: make it on the Creator Hub (your experience > Monetization >
-- Passes / Developer Products), then paste its ID into `id` below. While an id is 0 the card still
-- shows, but buying says "Coming soon". `price` is only what the card shows until Roblox tells us
-- the real price (it's read from the pass/product itself once the id is set).
--
-- TICKETS: everyone gets `Tickets.GrantAmount` Ticket(s) every `Tickets.GrantInterval` seconds of
-- playtime (the timer is saved, so it carries over between sessions). Spend them in the Tickets tab.
local ShopConfig = {}

------------------------------------------------------------------------------------------
-- gamepasses (Pass_<key> = true once owned). `effect` is what Multipliers / the services read.
------------------------------------------------------------------------------------------
-- `tickets` = the price when the shop's switch is on Tickets (bought that way it's yours for good too)
ShopConfig.Passes = {
	{ key = "x2Money", name = "x2 Money", description = "Doubles Money gain", price = 199, tickets = 60, id = 0,
		icon = "rbxassetid://74760303647639", color = Color3.fromRGB(95, 220, 70) },
	{ key = "x2Time", name = "x2 Time", description = "Doubles Time gain", price = 249, tickets = 75, id = 0,
		icon = "rbxassetid://104436607164470", color = Color3.fromRGB(235, 70, 80) },
	{ key = "x2Coins", name = "x2 Coins", description = "Doubles Coins gain", price = 249, tickets = 75, id = 0,
		icon = "rbxassetid://99928751746150", color = Color3.fromRGB(255, 190, 40) },
	{ key = "x2Gold", name = "x2 Gold", description = "Doubles Gold gain", price = 249, tickets = 75, id = 0,
		icon = "rbxassetid://130575145070200", color = Color3.fromRGB(255, 215, 70) },
	{ key = "x2RuneLuck", name = "x2 Rune Luck", description = "Doubles your Rune Luck", price = 79, tickets = 25, id = 0,
		icon = "rbxassetid://109852325141348", color = Color3.fromRGB(80, 220, 120) },
	{ key = "x2RuneSpeed", name = "x2 Rune Speed", description = "Open runes twice as fast", price = 79, tickets = 25, id = 0,
		icon = "rbxassetid://101935509296686", color = Color3.fromRGB(80, 190, 255) },
	{ key = "AutoButton", name = "Auto Button", description = "Clicks the button for you", price = 79, tickets = 25, id = 0,
		icon = "rbxassetid://74619804770161", color = Color3.fromRGB(180, 110, 255) },
}

-- owns every pass above (and any added later)
ShopConfig.Bundle = {
	key = "Bundle", name = "Gamepass Bundle", description = "Every gamepass - now and in the future!",
	price = 999, tickets = 300, id = 0, discount = "20% OFF",
	icons = { "rbxassetid://74760303647639", "rbxassetid://104436607164470", "rbxassetid://99928751746150", "rbxassetid://129309614855160" },
}

-- how many extra auto-clicks the Auto Button pass adds each Auto Clicker tick
ShopConfig.AutoButtonClicks = 3

------------------------------------------------------------------------------------------
-- developer products
------------------------------------------------------------------------------------------
-- Gems packs (the "Gems" currency)
ShopConfig.GemIcon = "rbxassetid://133407500845523"
ShopConfig.Gems = {
	{ key = "Gems10", amount = 10, price = 29, tickets = 3, id = 0, icon = "rbxassetid://133407500845523" },
	{ key = "Gems100", amount = 100, price = 199, tickets = 15, id = 0, icon = "rbxassetid://123949112842482" },
	{ key = "Gems800", amount = 800, price = 999, tickets = 80, id = 0, icon = "rbxassetid://117154589302294", tag = "POPULAR" },
	{ key = "Gems1800", amount = 1800, price = 1999, tickets = 170, id = 0, icon = "rbxassetid://98945127664334" },
	{ key = "Gems6500", amount = 6500, price = 4999, tickets = 450, id = 0, icon = "rbxassetid://134455950086049", tag = "BEST VALUE" },
}

-- Global Runes: opens Global runes for EVERY player in the server (you included)
ShopConfig.GlobalRunes = {
	icon = "rbxassetid://101935509296686",
	pool = "Global",
	options = {
		{ key = "Global1", amount = 1, price = 49, tickets = 5, id = 0 },
		{ key = "Global10", amount = 10, price = 199, tickets = 20, id = 0 },
		{ key = "Global100", amount = 100, price = 899, tickets = 90, id = 0 },
		{ key = "Global1k", amount = 1000, price = 2999, tickets = 300, id = 0 },
		{ key = "Global10k", amount = 10000, price = 9999, tickets = 1000, id = 0 },
	},
}

------------------------------------------------------------------------------------------
-- Tickets
------------------------------------------------------------------------------------------
ShopConfig.Tickets = {
	GrantInterval = 300, -- seconds of playtime per grant
	GrantAmount = 1,
	icon = "rbxassetid://120042006882088",
}

-- (every item above also has a `tickets` price: flip the shop's switch to Tickets to use them)
ShopConfig.Boosts = {} -- (no timed boosts right now)

------------------------------------------------------------------------------------------
-- helpers (client + server)
------------------------------------------------------------------------------------------
ShopConfig.PassByKey = {}
for _, p in ipairs(ShopConfig.Passes) do ShopConfig.PassByKey[p.key] = p end

-- every buyable thing by key: { kind = "pass" | "gems" | "global", def = ... }
ShopConfig.ItemByKey = {}
for _, p in ipairs(ShopConfig.Passes) do ShopConfig.ItemByKey[p.key] = { kind = "pass", def = p } end
ShopConfig.ItemByKey[ShopConfig.Bundle.key] = { kind = "pass", def = ShopConfig.Bundle }
for _, g in ipairs(ShopConfig.Gems) do ShopConfig.ItemByKey[g.key] = { kind = "gems", def = g } end
for _, o in ipairs(ShopConfig.GlobalRunes.options) do ShopConfig.ItemByKey[o.key] = { kind = "global", def = o } end

function ShopConfig.passAttribute(key)
	return "Pass_" .. key
end

function ShopConfig.hasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true or player:GetAttribute("Pass_Bundle") == true
end

function ShopConfig.boostAttribute(boost)
	return "Boost_" .. boost
end

local function now()
	return workspace:GetServerTimeNow()
end

-- seconds left on a timed boost (0 = off)
function ShopConfig.boostLeft(player, boost)
	local untilT = player:GetAttribute("Boost_" .. boost) or 0
	return math.max(0, untilT - now())
end

-- x2 from a pass and x2 from a Ticket boost stack
function ShopConfig.multiplier(player, passKey, boost)
	local m = 1
	if passKey and ShopConfig.hasPass(player, passKey) then m *= 2 end
	if boost and ShopConfig.boostLeft(player, boost) > 0 then m *= 2 end
	return m
end

return ShopConfig
