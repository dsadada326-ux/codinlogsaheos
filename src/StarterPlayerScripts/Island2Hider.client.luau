-- Hides Island 2 completely on this player's screen until they unlock it (Island2Unlocked):
-- invisible, can't be walked on or touched, nothing on it can be clicked, no boards, no effects.
-- Everything comes back the moment it unlocks.
--
-- It only uses properties the other island scripts don't (LocalTransparencyModifier on
-- decals, CollisionGroup, gui MaxDistance, effect Transparency...), and on unlock it only
-- puts back what it changed itself, so ZoneReveal / the tree / the farm keep control of
-- their own reveal animations.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

-- everything that is part of Island 2
local ROOTS = {
	"Workspace.Islands.Island2",
	"Workspace.UpgradeBoards.Island2",
	"Workspace.OtherBoards.SellWheat",
	"Workspace.OtherBoards.SellOres",
	"Workspace.Runes.Wood",
	"Workspace.Runes.Ore",
	"Workspace.Runes.Gold",
	"Workspace.TreeUpgradeBoard",
	"Workspace.TreeBoardFrame",
}

local LOCKED_GROUP = "Island2Locked"
local HIDDEN_SEQUENCE = NumberSequence.new(1)

local function under(name, roots)
	for _, root in ipairs(roots) do
		if name == root or name:sub(1, #root + 1) == root .. "." then
			return true
		end
	end

	return false
end

-- parts whose showing/hiding belongs to another script (ZoneReveal's Island 2 areas and
-- boards, and the Island 2 Upgrade Tree): on unlock we leave their visibility to that script
local MANAGED = { "Workspace.UpgradeBoards.Island2.UpgradeTree" }

for _, zone in ipairs(ZoneConfig.Zones) do
	if zone.island == "Island2" and not zone.noIsland then
		table.insert(MANAGED, "Workspace.Islands.Island2.Zones." .. (zone.model or zone.name))
	end

	for _, path in ipairs(zone.boards or {}) do
		local full = "Workspace." .. table.concat(path, ".")

		if under(full, ROOTS) then
			table.insert(MANAGED, full)
		end
	end
end

local saved = {} -- [instance] = { [property] = { old = value, set = value } }
local watching = {}
local guards = {} -- [instance] = connection that keeps it hidden while locked

local function set(inst, property, value)
	local record = saved[inst]

	if not record then
		record = {}
		saved[inst] = record
	end

	if record[property] == nil then
		local ok, old = pcall(function()
			return inst[property]
		end)

		if not ok then
			return
		end

		record[property] = { old = old }
	end

	pcall(function()
		inst[property] = value
		-- remember what it actually reads back as (numbers get rounded, sequences are new objects)
		record[property].set = inst[property]
	end)
end

-- while locked, if anything else (an area reveal, a streaming refresh...) shows it again, hide it again
local function guard(inst)
	if guards[inst] then
		return
	end

	guards[inst] = inst:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
		if player:GetAttribute("Island2Unlocked") ~= true and inst.LocalTransparencyModifier < 1 then
			inst.LocalTransparencyModifier = 1
		end
	end)
end

local function hide(inst)
	if inst:IsA("BasePart") then
		set(inst, "LocalTransparencyModifier", 1)
		set(inst, "CollisionGroup", LOCKED_GROUP)
		guard(inst)
	elseif inst:IsA("Decal") then -- (Textures too)
		set(inst, "LocalTransparencyModifier", 1)
		guard(inst)
	elseif inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
		set(inst, "MaxDistance", 0.001) -- too close to ever draw (so nothing on it can be clicked either)
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
		set(inst, "Transparency", HIDDEN_SEQUENCE)
	elseif inst:IsA("Light") then
		set(inst, "Brightness", 0)
	elseif inst:IsA("Highlight") then
		set(inst, "FillTransparency", 1)
		set(inst, "OutlineTransparency", 1)
	elseif inst:IsA("ClickDetector") or inst:IsA("ProximityPrompt") then
		set(inst, "MaxActivationDistance", 0)
	elseif inst:IsA("Sound") then
		set(inst, "Volume", 0)
	end
end

local function hideAll()
	for _, root in ipairs(ROOTS) do
		-- "Workspace.Islands.Island2" -> workspace.Islands.Island2 (if it has streamed in)
		local inst = game

		for piece in root:gmatch("[^%.]+") do
			inst = inst and inst:FindFirstChild(piece)
		end

		if inst then
			hide(inst)

			for _, d in ipairs(inst:GetDescendants()) do
				hide(d)
			end
		end
	end
end

local function same(a, b)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 1e-4
	end

	if typeof(a) == "NumberSequence" and typeof(b) == "NumberSequence" then
		local ka, kb = a.Keypoints, b.Keypoints

		if #ka ~= #kb then
			return false
		end

		for n = 1, #ka do
			if math.abs(ka[n].Value - kb[n].Value) > 1e-4 or math.abs(ka[n].Time - kb[n].Time) > 1e-4 then
				return false
			end
		end

		return true
	end

	return a == b
end

local function restoreAll()
	for inst, record in pairs(saved) do
		if inst.Parent then
			local managed = under(inst:GetFullName(), MANAGED)

			for property, r in pairs(record) do
				pcall(function()
					-- only undo our own change, and only if nothing else has changed it since
					if not same(inst[property], r.set) then
						return
					end

					-- never hide anything on the way out, and let the scripts that own an
					-- area's reveal (ZoneReveal, the tree) decide when it shows
					-- (textures/decals: ZoneReveal fades those with Transparency, so theirs always comes back)
					if property == "LocalTransparencyModifier" and (r.old >= 1 or (managed and inst:IsA("BasePart"))) then
						return
					end

					inst[property] = r.old
				end)
			end
		end
	end

	table.clear(saved)
end

local function lock()
	if watching.added then
		return
	end

	hideAll()

	-- parts stream in as you move around, so catch everything that arrives
	watching.added = workspace.DescendantAdded:Connect(function(inst)
		if under(inst:GetFullName(), ROOTS) then
			hide(inst)
		end
	end)

	watching.removing = workspace.DescendantRemoving:Connect(function(inst)
		saved[inst] = nil

		if guards[inst] then
			guards[inst]:Disconnect()
			guards[inst] = nil
		end
	end)
end

local function unlock()
	for key, connection in pairs(watching) do
		connection:Disconnect()
		watching[key] = nil
	end

	for inst, connection in pairs(guards) do
		connection:Disconnect()
		guards[inst] = nil
	end

	restoreAll()
end

local function apply()
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	if player:GetAttribute("Island2Unlocked") == true then
		unlock()
	else
		lock()
	end
end

player:GetAttributeChangedSignal("DataLoaded"):Connect(apply)
player:GetAttributeChangedSignal("Island2Unlocked"):Connect(apply)
apply()
