-- Redeemable codes (server only, so nobody can read the list from their client).
-- Add a code:   ["CODE"] = { rewards = { Gems = 10 }, expired = false },
--   rewards: any saved currency attribute -> amount to add (Gems, Cash, Coins, Stars...)
--   Codes are not case-sensitive. Each player can redeem each code once (saved).
-- Redeemable codes (server only, so nobody can read the list from their client).
-- Add a code:   ["CODE"] = { rewards = { Gems = 10 }, expired = false },
--   rewards: any saved currency attribute -> amount to add (Gems, Cash, Coins, Stars...)
--   Codes are not case-sensitive. Each player can redeem each code once (saved).
return {
	["RELEASE"] = { rewards = { Gems = 25 }, expired = false },
	["BUTTON"] = { rewards = { Gems = 25 }, expired = false },
	["EVENT"] = { rewards = { Gems = 25 }, expired = false },
	["UPDATE"] = { rewards = { Gems = 25 }, expired = false },
}