-- Coins island (Workspace.Islands.Island1.Zones.Coins, spawn area = its Hitbox part).
-- A coin appears every Coin Spawn Speed seconds (only for you), walk into it to collect.
-- With Auto Pickup Coins, the coin goes straight to you instead.
local CoinConfig = {}

CoinConfig.CoinValue = 1      -- before the Coin Multiplier and other boosts
CoinConfig.MaxOnGround = 20   -- stop spawning once this many are waiting
CoinConfig.PickupRange = 9    -- studs; the server checks you're really next to the coin

return CoinConfig
