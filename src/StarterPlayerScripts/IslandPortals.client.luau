-- Walk-through portals (Touched), doing exactly what the Teleport menu does (IslandTransition:
-- black cut, eyes open, island name):
--   Island 1's Fishing Frenzy portal  (Islands.Island1.Portals.FishingFrenzy.TeleportPart)   -> Fishing Frenzy
--   Fishing Frenzy's portal           (Islands["FishingFrenzySub-1"].FishingFrenzy.TeleportPart) -> Island 1
--     (you come out of Island 1's Fishing Frenzy portal)
--   Island 2's Laboratory portal      (Islands.Island1.Portals.Labratory.TeleportPart)      -> the Laboratory
--   the Laboratory's way out          (Islands.Island1.Portals.labratoryback.TeleportPart)  -> Island 2
--     (you come out of Island 2's Laboratory portal)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local IslandTransition = require(ReplicatedStorage:WaitForChild("IslandTransition"))

local PORTALS = {
	{ path = { "Island1", "Portals", "FishingFrenzy", "TeleportPart" }, to = "FishingFrenzy" },
	{ path = { "FishingFrenzySub-1", "FishingFrenzy", "TeleportPart" }, to = "Island1", via = "portal" },
	{ path = { "Island1", "Portals", "Labratory", "TeleportPart" }, to = "Laboratory" },
	{ path = { "Island1", "Portals", "labratoryback", "TeleportPart" }, to = "Island2", via = "portal" },
}

local COOLDOWN = 3 -- seconds after a trip before another portal can grab you
local busy = false
local readyAt = 0

local function find(path)
	local node = workspace:FindFirstChild("Islands")
	for _, name in ipairs(path) do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function enter(portal, hit)
	if busy or os.clock() < readyAt then return end
	local character = player.Character
	if not character or not hit:IsDescendantOf(character) then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	busy = true
	local result = IslandTransition.travel(portal.to, portal.via)
	if type(result) == "table" and result.reason == "busy" then
		-- already travelling (e.g. from the menu)
	end
	readyAt = os.clock() + COOLDOWN
	busy = false
end

-- (re)connect whenever a portal part streams in or gets rebuilt
local bound = {}
local function bind()
	for _, portal in ipairs(PORTALS) do
		local part = find(portal.path)
		if part and part:IsA("BasePart") and bound[portal] ~= part then
			bound[portal] = part
			part.CanTouch = true
			part.Touched:Connect(function(hit)
				enter(portal, hit)
			end)
		end
	end
end

bind()
task.spawn(function()
	while true do
		task.wait(1)
		bind()
	end
end)

-- a fresh character spawned standing in a portal shouldn't get sent off straight away
player.CharacterAdded:Connect(function()
	readyAt = os.clock() + COOLDOWN
end)
