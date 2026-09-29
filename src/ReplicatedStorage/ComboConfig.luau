-- Combo settings shared by the client (ButtonManager, for the visuals)
-- and the server (ButtonClickService, for the real rewards),
-- so what you see is what you get.
return {
	MaxMultiplier = 1.5,     -- multiplier at a full combo bar
	TimeToMax = 5,           -- seconds of steady clicking to reach it
	ComboTimeout = 1,        -- seconds without a click before the combo ends
	BaseReward = 1,          -- buttons per click at 1.00x
	MinClickInterval = 0.08, -- the server ignores clicks faster than this
	AutoClickInterval = 1,   -- seconds between clicks for each Auto Clicker (the cursors tap at this rate too)
}
