local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local TycoonConfig = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local tycoonDrop = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TycoonDrop")
local tycoonSold = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TycoonSold")

local root = workspace:WaitForChild("Islands"):WaitForChild("Island1"):WaitForChild("Zones")
	:WaitForChild("Tycoon"):WaitForChild("TycoonMain"):WaitForChild("TycoonDroppers")
local dropperFolder = root:WaitForChild("Droppers")
local upgraderFolder = root:WaitForChild("Upgraders")
local buttonFolder = root:WaitForChild("BuyButtons")
local seller = root:WaitForChild("Seller"):FindFirstChildWhichIsA("BasePart", true)

local tycoonZone = ZoneConfig.find("Tycoon")

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

-- every part of a machine, and how it should look once bought
local machines = {} -- [item] = { parts = { {inst, visibleT} }, guis = {} }

local function collectMachine(model, isUpgrader)
	local entry = { parts = {}, guis = {} }

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local visibleT = 0

			if d.Name == "DropPosition" then
				visibleT = d.Transparency -- the drop spot keeps the look it was built with
			elseif isUpgrader and d.Name == "UpgraderPart" then
				visibleT = 0.55 -- the glowing upgrade field
			end

			table.insert(entry.parts, { inst = d, visibleT = visibleT, canCollide = d.CanCollide })
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			table.insert(entry.guis, d)
		end
	end

	return entry
end

for _, m in ipairs(dropperFolder:GetChildren()) do machines[m.Name] = collectMachine(m, false) end
for _, m in ipairs(upgraderFolder:GetChildren()) do machines[m.Name] = collectMachine(m, true) end

-- the upgrade field glows
for item, entry in pairs(machines) do
	if item:find("^Upgrader") then
		for _, p in ipairs(entry.parts) do
			if p.inst.Name == "UpgraderPart" then
				p.inst.Material = Enum.Material.ForceField
				p.inst.Color = Color3.fromRGB(80, 200, 255)
				p.inst.CanCollide = false
				p.canCollide = false
			end
		end
	end
end

local buttons = {} -- [item] = { parts, tag, name, price }

for _, b in ipairs(buttonFolder:GetChildren()) do
	local entry = { parts = {} }

	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(entry.parts, { inst = d, visibleT = d.Name == "ButtonHitbox" and 1 or 0, canCollide = d.CanCollide })
		elseif d:IsA("BillboardGui") then
			entry.tag = d
		end
	end

	if entry.tag then
		entry.name = entry.tag:FindFirstChild("NameLabel", true)
		entry.price = entry.tag:FindFirstChild("PriceLabel", true)
	end

	buttons[b.Name] = entry
end

local function setParts(entry, shown)
	for _, p in ipairs(entry.parts) do
		p.inst.Transparency = shown and p.visibleT or 1
		p.inst.CanCollide = shown and p.canCollide
		p.inst.LocalTransparencyModifier = 0
	end

	for _, g in ipairs(entry.guis or {}) do
		g.Enabled = shown
	end
end

local function refresh()
	local open = ZoneConfig.isRevealed(player, tycoonZone)

	for item, entry in pairs(machines) do
		setParts(entry, open and TycoonConfig.owns(player, item))
	end

	for item, entry in pairs(buttons) do
		local def = TycoonConfig.Items[item]
		-- every button you haven't bought yet is laid out (the Click Dropper is free)
		local show = open and def and def.cost > 0 and not TycoonConfig.owns(player, item)

		setParts(entry, show)

		if entry.tag then
			entry.tag.Enabled = show and true or false
		end

		if show then
			if entry.name then entry.name.Text = def.name end
			if entry.price then entry.price.Text = NumberFormat.abbreviate(def.cost) end
		end
	end
end

-- drops: a little cube falls from the dropper onto the belt and rides to the Seller
local dropFolder = Instance.new("Folder")
dropFolder.Name = "MyTycoonDrops"
dropFolder.Parent = workspace

local DROP_COLORS = {
	ClickDropper = Color3.fromRGB(255, 70, 70),
	Dropper1 = Color3.fromRGB(255, 205, 60), Dropper2 = Color3.fromRGB(255, 170, 50),
	Dropper3 = Color3.fromRGB(120, 230, 90), Dropper4 = Color3.fromRGB(80, 200, 255),
	Dropper5 = Color3.fromRGB(185, 120, 255), Dropper6 = Color3.fromRGB(255, 110, 190),
	Dropper7 = Color3.fromRGB(255, 255, 255),
}

local function sellPopup(amount)
	if not seller then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = seller
	gui.Parent = seller

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "+" .. NumberFormat.abbreviate(amount) .. " Coins"
	label.TextScaled = true
	label.FontFace = uiFont()
	label.TextColor3 = Color3.fromRGB(255, 220, 90)
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 25, 0)
	stroke.Parent = label

	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(0, 7, 0) }):Play()
	local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	Debris:AddItem(gui, 1)
end

local drops = {} -- { part, amount, born }

tycoonDrop.OnClientEvent:Connect(function(item, id, amount)
	local model = dropperFolder:FindFirstChild(item)
	local spawnPart = model and model:FindFirstChild("DropPosition")

	if not spawnPart then
		return
	end

	-- a coin (the same model as the Coins island), lying flat so it slides along the belt
	local cube = ReplicatedStorage:WaitForChild("CoinModel"):Clone()
	cube.Size = Vector3.new(0.35, 1.6, 1.6)
	cube.Anchored = false
	cube.CanCollide = true
	cube.CanQuery = false
	cube.CanTouch = false

	local light = cube:FindFirstChildOfClass("PointLight")
	if light then light:Destroy() end -- lots of drops: keep it light

	cube.CFrame = spawnPart.CFrame * CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90))
	cube.Parent = dropFolder

	table.insert(drops, { part = cube, amount = amount, born = os.clock(), id = id })
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	for i = #drops, 1, -1 do
		local d = drops[i]
		local sold = seller and (d.part.Position - seller.Position).Magnitude < 5
		local tooOld = now - d.born > 15

		if sold or tooOld or not d.part.Parent then
			if sold then
				tycoonSold:FireServer(d.id) -- the server pays it now
				sellPopup(d.amount)
			end

			d.part:Destroy()
			table.remove(drops, i)
		end
	end
end)

-- keep it in sync with purchases and the island unlocking
player:GetAttributeChangedSignal(ZoneConfig.flagAttribute(tycoonZone)):Connect(refresh)
player:GetAttributeChangedSignal("Prestige"):Connect(refresh)

for item in pairs(TycoonConfig.Items) do
	player:GetAttributeChangedSignal(TycoonConfig.ownedAttribute(item)):Connect(refresh)
end

refresh()

player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
	task.delay(2, refresh)
end)
