-- Rune stands (Workspace.Runes.<Pool>), one per pool in RuneConfig.
--   Info box   - "Runes" + a live list of what you've rolled since you stepped on the pad:
--                "50x Common", "30x Rare"... Each line is a copy of that rune's row in the
--                Runes list (same colours, same spacing). Clears when you step off.
--   Runes list - every rune with its chance ("Common (1 in 1.54)"), "???" until you find it.
--   Stats      - your Rune Luck and Rune Bulk.
-- The server (RuneService) does the rolling; this only shows it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local RuneConfig = require(ReplicatedStorage:WaitForChild("RuneConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local runeRolled = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RuneRolled")

local standsFolder = workspace:WaitForChild("Runes")

-- rarity colours, by position in the pool (1 = most common) - same order as the Runes menu
local RARITY = {
	Color3.fromRGB(170, 255, 127), -- green
	Color3.fromRGB(90, 225, 255), -- cyan
	Color3.fromRGB(195, 140, 255), -- purple
	Color3.fromRGB(255, 190, 60), -- orange
	Color3.fromRGB(255, 250, 175), -- pale yellow
	Color3.fromRGB(255, 255, 255), -- white
	Color3.fromRGB(255, 85, 85), -- red
	Color3.fromRGB(255, 130, 210), -- pink
}

local function settingOn(key)
	local value = player:GetAttribute(SettingsConfig.attributeOf(key))

	if value == nil then
		return SettingsConfig.Settings[key].Default
	end

	return value
end

local function uiFont()
	local ok, font = pcall(function()
		return player.PlayerGui.Currencies.MainCurrenciesFrame.CurrenciesFrame.Money.Value.FontFace
	end)

	return ok and font or Font.fromEnum(Enum.Font.FredokaOne)
end

local function trim(n)
	return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end

-- "1 in 1.54", "1 in 250", "1 in 12.5K"
local function oneIn(percent)
	if percent <= 0 then
		return "-"
	end

	local n = 100 / percent

	if n < 10 then
		return "1 in " .. trim(n)
	end

	return "1 in " .. NumberFormat.abbreviate(n)
end

-- effective % per roll, same math as the server (luck boosts every rune but the first)
local function effectiveChances(pool, luck)
	local total = 0

	for i, rune in ipairs(pool.runes) do
		total += rune.chance * (i == 1 and 1 or luck)
	end

	local out = {}

	for i, rune in ipairs(pool.runes) do
		out[i] = rune.chance * (i == 1 and 1 or luck) / total * 100
	end

	return out
end

local function setText(label, text)
	if label and label.Text ~= text then
		label.Text = text
	end
end

------------------------------------------------------------------------------------------
-- stands (each sets itself up when it streams in, so one far-away stand never holds up the rest)
------------------------------------------------------------------------------------------
local stands = {}

local function setupStand(poolName, pool, stand)
	local info = stand:WaitForChild("BillboardGuiPart"):WaitForChild("RuneTemplate")
	local above = stand:WaitForChild("AboveBillboardGuiPart"):WaitForChild("AboveRuneBillboardTemplate")
	local session = info:WaitForChild("Info"):WaitForChild("Main")
	local statsMain = info:WaitForChild("Stats"):WaitForChild("Main")

	local emitters = {}
	local fx = stand:FindFirstChild("Lighting-01")

	if fx then
		for _, d in ipairs(fx:GetDescendants()) do
			if d:IsA("ParticleEmitter") then
				d.Enabled = false
				table.insert(emitters, d)
			end
		end
	end

	stands[poolName] = {
		pool = pool,
		stand = stand,
		rows = info:WaitForChild("Runes"):WaitForChild("Main"),
		luck = statsMain:WaitForChild("RuneLuck"),
		bulk = statsMain:WaitForChild("RuneBulk"),
		aboveName = above:WaitForChild("Container"):WaitForChild("RuneNameText"),
		aboveCost = above:WaitForChild("Container"):WaitForChild("RuneCostText"),
		emitters = emitters,
		popupAnchor = stand:WaitForChild("AboveBillboardGuiPart"),
		session = session,
		sessionHint = session:WaitForChild("SessionHint"),
		sessionCounts = {},
		sessionRows = {},
	}
end

------------------------------------------------------------------------------------------
-- the Info box list: what you've rolled this visit
------------------------------------------------------------------------------------------
local function renderSession(poolName, s)
	local any = false

	for i, rune in ipairs(s.pool.runes) do
		local count = s.sessionCounts[rune.name]

		if count and count > 0 then
			any = true

			local row = s.sessionRows[rune.name]

			if not row then
				-- a copy of this rune's row in the Runes list, so it has the same colours
				local source = s.rows:FindFirstChild(rune.name) or s.rows:FindFirstChild("Template")
				row = source:Clone()
				row.Name = "Row_" .. rune.name
				row.LayoutOrder = 10 + i
				row.Visible = true

				local scale = Instance.new("UIScale")
				scale.Parent = row

				row.Parent = s.session
				s.sessionRows[rune.name] = row

				-- a new rune type: slide in
				scale.Scale = 0.4
				TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end

			local text = NumberFormat.abbreviate(count) .. "x " .. rune.name
			local label = row:FindFirstChild("RuneInfo") or row

			if label.Text ~= text then
				label.Text = text

				-- bump when the count goes up
				local scale = row:FindFirstChildOfClass("UIScale")

				if scale and scale.Scale >= 0.99 then
					scale.Scale = 1.12
					TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
			end
		end
	end

	if not any then
		local hintLabel = s.sessionHint:FindFirstChild("RuneInfo") or s.sessionHint
		hintLabel.Text = RuneConfig.isUnlocked(player, poolName) and "Stand here to roll!" or s.pool.unlock.text
	end

	s.sessionHint.Visible = not any
end

local function clearSession(poolName, s)
	s.sessionCounts = {}

	for _, row in pairs(s.sessionRows) do
		row:Destroy()
	end

	s.sessionRows = {}
	renderSession(poolName, s)
end

------------------------------------------------------------------------------------------
-- the rest of the board
------------------------------------------------------------------------------------------
local function refreshStand(poolName, s)
	local pool = s.pool
	local luck = Multipliers.runeLuck(player)
	local bulk = math.max(1, math.floor(Multipliers.runeBulk(player)))

	setText(s.aboveName, poolName)

	if RuneConfig.isUnlocked(player, poolName) then
		setText(s.aboveCost, NumberFormat.abbreviate(pool.cost) .. " " .. pool.currency .. " per roll")
	else
		setText(s.aboveCost, pool.unlock.text)
	end

	setText(s.luck, "Rune Luck: x" .. trim(luck))
	setText(s.bulk, "Rune Bulk: " .. NumberFormat.abbreviate(bulk))

	local chances = effectiveChances(pool, luck)

	for i, rune in ipairs(pool.runes) do
		local row = s.rows:FindFirstChild(rune.name)
		local label = row and row:FindFirstChild("RuneInfo")

		if label then
			local count = player:GetAttribute(RuneConfig.countAttribute(poolName, rune.name)) or 0
			setText(label, count > 0 and (rune.name .. " (" .. oneIn(chances[i]) .. ")") or "???")
		end
	end

	if not next(s.sessionCounts) then
		renderSession(poolName, s)
	end
end

local function refreshAll()
	for poolName, s in pairs(stands) do
		refreshStand(poolName, s)
	end
end

-- VFX: the stand's own lightning / impact particles run while you're rolling it
local function applyActive()
	local active = player:GetAttribute("RuneStand")

	for poolName, s in pairs(stands) do
		if poolName ~= active and next(s.sessionCounts) then
			clearSession(poolName, s) -- stepped off: the list starts fresh next time
		end

		local on = active == poolName and settingOn("VFX")

		for _, e in ipairs(s.emitters) do
			e.Enabled = on
		end
	end
end

for poolName, pool in pairs(RuneConfig.Pools) do
	if not pool.noStand then
		task.spawn(function()
			local stand = standsFolder:WaitForChild(poolName, math.huge)
			setupStand(poolName, pool, stand)
			refreshStand(poolName, stands[poolName])
			applyActive()
		end)
	end
end

------------------------------------------------------------------------------------------
-- roll effects
------------------------------------------------------------------------------------------
-- "+2 Common  +1 Rare!" above the stand after each roll
local function popup(s, results)
	local lines = {}

	for i, rune in ipairs(s.pool.runes) do
		local n = results[rune.name]

		if n then
			table.insert(lines, { text = "+" .. n .. " " .. rune.name, color = RARITY[i] or RARITY[1], rare = i >= 3 })
		end
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 30 * #lines)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = s.popupAnchor
	gui.Parent = s.popupAnchor

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui

	for _, l in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, l.rare and 32 or 26)
		label.Text = l.text .. (l.rare and "!" or "")
		label.TextScaled = true
		label.FontFace = uiFont()
		label.TextColor3 = l.color
		label.Parent = gui

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(20, 20, 30)
		stroke.Parent = label

		local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	end

	TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 6, 0),
	}):Play()

	Debris:AddItem(gui, 1.2)
end

-- the orb that flies from the stand to you on each roll. Uses ReplicatedStorage.RuneOrb
-- (or ReplicatedStorage.Assets.RuneOrb) when it exists; otherwise a glowing ball.
local function orbTemplate()
	local direct = ReplicatedStorage:FindFirstChild("RuneOrb")

	if direct then
		return direct
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")

	return assets and assets:FindFirstChild("RuneOrb") or nil
end

local lastOrb = 0

local function flyOrb(s, color)
	local now = os.clock()

	if now - lastOrb < 0.2 then
		return
	end

	lastOrb = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return
	end

	local from = s.popupAnchor.Position
	local template = orbTemplate()
	local orb

	if template then
		orb = template:Clone()
	else
		orb = Instance.new("Part")
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(1.4, 1.4, 1.4)
		orb.Material = Enum.Material.Neon

		local light = Instance.new("PointLight")
		light.Range = 8
		light.Brightness = 2
		light.Color = color
		light.Parent = orb

		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.5, 0)
		a0.Parent = orb
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.5, 0)
		a1.Parent = orb

		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.25
		trail.Color = ColorSequence.new(color)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.LightEmission = 1
		trail.Parent = orb
	end

	local parts = orb:IsA("BasePart") and { orb } or {}

	for _, d in ipairs(orb:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end

	-- tint it with the rune's colour
	for _, d in ipairs(orb:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Color = ColorSequence.new(color)
		elseif d:IsA("PointLight") then
			d.Color = color
		end
	end

	for _, p in ipairs(parts) do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false

		if not template then
			p.Color = color
		end
	end

	local main = orb:IsA("BasePart") and orb or parts[1]

	if not main then
		orb:Destroy()
		return
	end

	local function place(position)
		if orb:IsA("Model") then
			orb:PivotTo(CFrame.new(position))
		else
			orb.CFrame = CFrame.new(position)
		end
	end

	place(from)
	orb.Parent = workspace

	-- arc out to the side and up, then home in on you
	local toPlayer = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	local dir = toPlayer.Magnitude > 0.01 and toPlayer.Unit or Vector3.new(0, 0, 1)
	local side = Vector3.new(-dir.Z, 0, dir.X) * (math.random(0, 1) == 0 and -1 or 1)
	local control = from + side * 7 + Vector3.new(0, 5, 0)

	task.spawn(function()
		local t = 0

		while orb.Parent and t < 0.85 do
			t += RunService.Heartbeat:Wait()

			local target = root.Parent and root.Position or from
			local a = 1 - (1 - math.clamp(t / 0.85, 0, 1)) ^ 2
			place(from:Lerp(control, a):Lerp(control:Lerp(target, a), a))
		end

		orb:Destroy()
	end)
end

runeRolled.OnClientEvent:Connect(function(poolName, results, best)
	local s = stands[poolName]

	if not s then
		return
	end

	local bestIndex = 1

	for i, rune in ipairs(s.pool.runes) do
		if rune.name == best then
			bestIndex = i
		end
	end

	if settingOn("VFX") then
		flyOrb(s, RARITY[bestIndex] or RARITY[1])

		for _, e in ipairs(s.emitters) do
			e:Emit(3)
		end
	end

	for name, n in pairs(results) do
		s.sessionCounts[name] = (s.sessionCounts[name] or 0) + n
	end

	renderSession(poolName, s)
	refreshStand(poolName, s)
end)

-- keep numbers live (balances and rune counts change constantly)
local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt

	if accum >= 0.5 then
		accum = 0
		refreshAll()
	end
end)

player:GetAttributeChangedSignal("RuneStand"):Connect(applyActive)
player:GetAttributeChangedSignal(SettingsConfig.attributeOf("VFX")):Connect(applyActive)
