-- Pop-up menus opened from the HUD: Codes, Updates and Inventory (the Inventory's contents are
-- handled by InventoryMenu). Click the HUD button to open (or close), X to close. Opening one closes the others.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local buttons = playerGui:WaitForChild("Buttons")

-- ScreenGui name -> the HUD button that opens it
local MENUS = {
	Codes = buttons:WaitForChild("BottomContainer"):WaitForChild("Codes"),
	Updates = buttons:WaitForChild("BottomContainer"):WaitForChild("Updates"),
	Inventory = buttons:WaitForChild("Container"):WaitForChild("Inventory"),
}

local openInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local closeInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local menus = {}

local function setOpen(name, open)
	local m = menus[name]

	if not m or m.open == open then
		return
	end

	m.open = open

	if open then
		-- only one of these at a time
		for other in pairs(menus) do
			if other ~= name then
				setOpen(other, false)
			end
		end

		m.gui.Enabled = true
		m.scale.Scale = 0.6
		TweenService:Create(m.scale, openInfo, { Scale = 1 }):Play()

		if m.onOpen then
			m.onOpen()
		end
	else
		local t = TweenService:Create(m.scale, closeInfo, { Scale = 0.6 })
		t:Play()
		t.Completed:Connect(function()
			if not m.open then
				m.gui.Enabled = false
			end
		end)
	end
end

for name, openButton in pairs(MENUS) do
	local gui = playerGui:WaitForChild(name)
	local holder = gui:WaitForChild("Holder")

	local scale = holder:FindFirstChild("OpenScale") or Instance.new("UIScale")
	scale.Name = "OpenScale"
	scale.Parent = holder

	gui.Enabled = false

	menus[name] = { gui = gui, holder = holder, scale = scale, open = false }

	openButton.Activated:Connect(function()
		setOpen(name, not menus[name].open)
	end)

	local close = holder:FindFirstChild("Top") and holder.Top:FindFirstChild("Close")

	if close then
		close.Activated:Connect(function()
			setOpen(name, false)
		end)
	end
end

-- the top-bar menu (TopbarMenu) opens Codes / Updates too
ReplicatedStorage:WaitForChild("HudActions").Event:Connect(function(action)
	if menus[action] then
		setOpen(action, not menus[action].open)
	end
end)

------------------------------------------------------------------------------------------
-- Codes: type a code, press Redeem
------------------------------------------------------------------------------------------
do
	local holder = menus.Codes.holder
	local box = holder:WaitForChild("CodeBox")
	local redeem = holder:WaitForChild("RedeemButton")
	local status = holder:WaitForChild("StatusLabel")
	local redeemRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RedeemCode")

	local GOOD = Color3.fromRGB(110, 255, 120)
	local BAD = Color3.fromRGB(255, 110, 110)
	local busy = false
	local shown = 0

	local function say(text, good)
		shown += 1
		local mine = shown

		status.Text = text
		status.TextColor3 = good and GOOD or BAD
		status.TextTransparency = 0

		local pop = status:FindFirstChild("Pop") or Instance.new("UIScale")
		pop.Name = "Pop"
		pop.Parent = status
		pop.Scale = 1.15
		TweenService:Create(pop, openInfo, { Scale = 1 }):Play()

		task.delay(3, function()
			if shown == mine then
				TweenService:Create(status, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			end
		end)
	end

	local function submit()
		if busy then
			return
		end

		busy = true

		local ok, result = pcall(function()
			return redeemRemote:InvokeServer(box.Text)
		end)

		if ok and type(result) == "table" then
			say(result.message or "", result.ok)

			if result.ok then
				box.Text = ""
			end
		else
			say("Couldn't reach the server, try again!", false)
		end

		busy = false
	end

	redeem.Activated:Connect(submit)

	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)

	menus.Codes.onOpen = function()
		status.Text = ""
	end
end

