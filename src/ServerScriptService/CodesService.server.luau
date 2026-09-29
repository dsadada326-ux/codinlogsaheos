-- Redeeming codes from the Codes menu (StarterGui.Codes). The list lives in CodesConfig.
-- Each redeemed code is saved on the player as the attribute Code_<CODE> = true.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodesConfig = require(script.Parent:WaitForChild("CodesConfig"))
local redeemRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RedeemCode")

local function attributeFor(code)
	return "Code_" .. code:gsub("[^%w]", "")
end

local cooldown = {}

redeemRemote.OnServerInvoke = function(player, text)
	if player:GetAttribute("DataLoaded") ~= true then
		return { ok = false, message = "Still loading, try again!" }
	end

	-- a little anti-spam
	local now = os.clock()
	if cooldown[player] and now - cooldown[player] < 1 then
		return { ok = false, message = "Slow down!" }
	end
	cooldown[player] = now

	if typeof(text) ~= "string" then
		return { ok = false, message = "Invalid code!" }
	end

	local code = text:gsub("^%s+", ""):gsub("%s+$", ""):upper()

	if code == "" then
		return { ok = false, message = "Type a code first!" }
	end

	local def
	for name, d in pairs(CodesConfig) do
		if name:upper() == code then
			def = d
			code = name:upper()
			break
		end
	end

	if not def then
		return { ok = false, message = "Invalid code!" }
	end

	if def.expired then
		return { ok = false, message = "That code has expired!" }
	end

	local attribute = attributeFor(code)

	if player:GetAttribute(attribute) == true then
		return { ok = false, message = "Already redeemed!" }
	end

	player:SetAttribute(attribute, true)

	local parts = {}
	for currency, amount in pairs(def.rewards or {}) do
		player:SetAttribute(currency, (player:GetAttribute(currency) or 0) + amount)
		table.insert(parts, "+" .. tostring(amount) .. " " .. currency)
	end

	return { ok = true, message = "Redeemed! " .. table.concat(parts, ", ") }
end

Players.PlayerRemoving:Connect(function(player)
	cooldown[player] = nil
end)
