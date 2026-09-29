-- A collision group that collides with nothing. Island2Hider (client) puts Island 2's parts
-- in it on the screens of players who haven't unlocked Island 2, so they can't stand on,
-- bump into, or touch anything there. (Only on their screen - the server copy is untouched.)
local PhysicsService = game:GetService("PhysicsService")

local GROUP = "Island2Locked"

if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
	PhysicsService:RegisterCollisionGroup(GROUP)
end

local function refresh()
	for _, group in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
		PhysicsService:CollisionGroupSetCollidable(GROUP, group.name, false)
	end
end

refresh()
task.delay(5, refresh) -- catch groups other scripts register a little later
