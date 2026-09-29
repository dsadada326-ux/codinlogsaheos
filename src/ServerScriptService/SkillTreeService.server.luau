-- Skill Tree (server): buying nodes with Stars, and the Stars timer.
--   BuySkillNode(nodeId) -> { ok, reason }. Checks the node exists, isn't maxed, its Requires node
--   is owned, and you have the Stars. Levels are saved as Skill_<NodeId> attributes.
--   Stars: every SkillTreeConfig.starSeconds(player) you get starAmount(player) Stars.
--   StarsNextAt (server time) is set on the player so the tree can show the countdown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillTreeConfig = require(ReplicatedStorage:WaitForChild("SkillTreeConfig"))
local buyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuySkillNode")

local function round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

buyRemote.OnServerInvoke = function(player, id)
	if player:GetAttribute("DataLoaded") ~= true then
		return { ok = false, reason = "loading" }
	end

	local node = typeof(id) == "string" and SkillTreeConfig.Nodes[id]

	if not node or id == SkillTreeConfig.Root then
		return { ok = false, reason = "invalid" }
	end

	local level = SkillTreeConfig.level(player, id)

	if level >= (node.Levels or 1) then
		return { ok = false, reason = "max" }
	end

	if node.Requires and SkillTreeConfig.level(player, node.Requires) < 1 then
		return { ok = false, reason = "requires" }
	end

	local price = SkillTreeConfig.priceForLevel(node, level + 1)
	local stars = player:GetAttribute(SkillTreeConfig.Currency) or 0

	if stars < price then
		return { ok = false, reason = "stars" }
	end

	player:SetAttribute(SkillTreeConfig.Currency, round2(stars - price))
	player:SetAttribute(SkillTreeConfig.attribute(id), level + 1)

	return { ok = true }
end

-- the Stars timer
task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()

		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("DataLoaded") == true then
				local nextAt = player:GetAttribute("StarsNextAt")

				if not nextAt then
					player:SetAttribute("StarsNextAt", now + SkillTreeConfig.starSeconds(player))
				elseif now >= nextAt then
					local stars = player:GetAttribute(SkillTreeConfig.Currency) or 0
					player:SetAttribute(SkillTreeConfig.Currency, round2(stars + SkillTreeConfig.starAmount(player)))
					player:SetAttribute("StarsNextAt", now + SkillTreeConfig.starSeconds(player))
				end
			end
		end

		task.wait(0.5)
	end
end)
