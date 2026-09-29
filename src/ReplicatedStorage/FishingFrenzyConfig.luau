-- Fishing Frenzy: a sub-island of Island 1 (Workspace.Islands["FishingFrenzySub-1"]).
--   Teleport menu card   -> arrives at FishingFrenzy.TeleportToPart (in front of the portal)
--   Rods / Sell / Magnets -> the buttons at the top of the screen jump you to the matching stall
local FishingFrenzyConfig = {}

-- the Teleport card's picture. Upload the island screenshot (Studio > Asset Manager > Import)
-- and paste its ID here, e.g. "rbxassetid://1234567890". "" = use Island 1's picture for now.
FishingFrenzyConfig.CardImage = ""

FishingFrenzyConfig.Title = "Fishing Frenzy"
FishingFrenzyConfig.Subtitle = "Rods, Selling & Shell Upgrades"
FishingFrenzyConfig.Color = Color3.fromRGB(60, 205, 255)

FishingFrenzyConfig.IslandName = "FishingFrenzySub-1"

-- shop name -> stall model in FishingStands
FishingFrenzyConfig.Shops = {
	Rods = "RodStand",
	Sell = "SellStand",
	Upgrades = "ShellUpgrades",
}

-- the area that counts as "on Fishing Frenzy" (the Teleport card's "You're Here")
FishingFrenzyConfig.Center = Vector3.new(-187, 0, -872)
FishingFrenzyConfig.HalfSize = Vector3.new(165, 80, 165)

function FishingFrenzyConfig.isInside(position)
	local d = position - FishingFrenzyConfig.Center
	local h = FishingFrenzyConfig.HalfSize
	return math.abs(d.X) <= h.X and math.abs(d.Z) <= h.Z and math.abs(d.Y) <= h.Y
end

------------------------------------------------------------------------------------------
-- where to put a character (server side; the whole island is always loaded there)
------------------------------------------------------------------------------------------
local function island()
	local islands = workspace:FindFirstChild("Islands")
	return islands and islands:FindFirstChild(FishingFrenzyConfig.IslandName)
end

local function flat(v)
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 0 and v.Unit or Vector3.new(0, 0, -1)
end

-- in front of the portal, facing away from it
function FishingFrenzyConfig.arrival()
	local model = island()
	local frenzy = model and model:FindFirstChild("FishingFrenzy")
	local arrive = frenzy and frenzy:FindFirstChild("TeleportToPart")
	local portal = frenzy and frenzy:FindFirstChild("TeleportPart")

	if not arrive then
		return nil
	end

	local pos = arrive.Position + Vector3.new(0, 1, 0)
	local away = portal and flat(pos - portal.Position) or flat(arrive.CFrame.LookVector)

	return CFrame.lookAt(pos, pos + away)
end

-- standing at the counter of a stall, facing the shopkeeper
function FishingFrenzyConfig.shopSpot(shopName)
	local model = island()
	local stands = model and model:FindFirstChild("FishingStands")
	local stand = stands and FishingFrenzyConfig.Shops[shopName] and stands:FindFirstChild(FishingFrenzyConfig.Shops[shopName])

	if not stand then
		return nil
	end

	local center = stand:GetBoundingBox().Position
	local front = flat(stand:GetPivot().LookVector) -- the shopkeeper faces out of the stall
	local pos = center + front * 9

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { stand }

	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	pos = Vector3.new(pos.X, (hit and hit.Position.Y or pos.Y) + 3.5, pos.Z)

	return CFrame.lookAt(pos, pos - front)
end

return FishingFrenzyConfig
