local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ComboConfig = require(ReplicatedStorage:WaitForChild("ComboConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))

local root = workspace
	:WaitForChild("Islands")
	:WaitForChild("Island1")
	:WaitForChild("RedButton")
	:WaitForChild("ClickCursors")

-- One cursor appears for every Auto Clicker level (Upgrade_Autoclicker, 0 - 8).
-- Each cursor taps the button once every ComboConfig.AutoClickInterval seconds, which is
-- also how often the server pays out for it, and the button squashes on every tap.
--
-- Attribute on Workspace.Islands.Island1.RedButton.ClickCursors:
--   PushDistance   how far a cursor pokes toward the button, in studs

local TAP_IN = 0.18 -- the poke in takes this fraction of a tap, the rest is the return

local center = root:GetAttribute("Center")

local cursors = {}

for _, model in ipairs(root:GetChildren()) do
	if model:IsA("Model") then
		local pivot = model:GetPivot()
		local toButton = Vector3.new(
			center.X - pivot.Position.X,
			0,
			center.Z - pivot.Position.Z
		).Unit

		local cursor = {
			model = model,
			base = pivot,
			direction = toButton,
			parts = {},
			shown = nil,
			lastPhase = nil,
		}

		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(cursor.parts, part)
			end
		end

		table.insert(cursors, cursor)
	end
end

-- Cursor1, Cursor2, ... Cursor8
table.sort(cursors, function(a, b)
	return tonumber(a.model.Name:match("%d+")) < tonumber(b.model.Name:match("%d+"))
end)

local pressVFX = nil -- made by ButtonManager; firing it squashes the button

RunService.RenderStepped:Connect(function()
	local level = player:GetAttribute(UpgradeConfig.levelAttribute("Autoclicker")) or 0
	local speed = 1 / ComboConfig.AutoClickInterval
	local push = root:GetAttribute("PushDistance") or 1.1
	local now = os.clock()

	pressVFX = pressVFX or ReplicatedStorage:FindFirstChild("LocalButtonPressVFX")

	for index, cursor in ipairs(cursors) do
		-- show / hide (only touches the parts when it changes)
		local visible = index <= level

		if cursor.shown ~= visible then
			cursor.shown = visible

			for _, part in ipairs(cursor.parts) do
				part.LocalTransparencyModifier = visible and 0 or 1
			end
		end

		if visible then
			-- every cursor taps a little after the one before it
			local phase = (now * speed + (index - 1) / #cursors) % 1
			local amount

			if phase < TAP_IN then
				amount = phase / TAP_IN
			else
				amount = ((1 - phase) / (1 - TAP_IN)) ^ 2
			end

			-- the moment the cursor touches the button, the button clicks
			if pressVFX
				and cursor.lastPhase
				and cursor.lastPhase < TAP_IN
				and phase >= TAP_IN then
				pressVFX:Fire()
			end

			cursor.lastPhase = phase
			cursor.model:PivotTo(cursor.base + cursor.direction * (amount * push))
		else
			cursor.lastPhase = nil
		end
	end
end)
