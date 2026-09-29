-- Island travel transition (client). Every travel button goes through IslandTransition.travel(name):
--   1. instant cut to black (eyes shut)
--   2. the server moves you (TravelIsland remote); we wait for the ground there to load
--   3. your eyes open in one smooth motion (blur clears) and the island's name shows at the top
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local travelRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TravelIsland")

local IslandTransition = {}

-- the name card at the top of the screen
IslandTransition.Islands = {
	Island1 = { title = "Island 1", subtitle = "Buttons, Rebirths & Prestige", color = Color3.fromRGB(120, 225, 90) },
	Island2 = { title = "Island 2", subtitle = "Wood, Farming & Mining", color = Color3.fromRGB(245, 180, 70) },
	FishingFrenzy = { title = "Fishing Frenzy", subtitle = "Rods, Selling & Shell Upgrades", color = Color3.fromRGB(60, 205, 255) },
	Laboratory = { title = "The Laboratory", subtitle = "Chemicals, Potions & Knowledge", color = Color3.fromRGB(110, 235, 120) },
}

local EDGE = 70 -- soft inner edge of each eyelid (pixels)
local busy = false

local function uiFont()
	local ok, font = pcall(function()
		return player.PlayerGui.Currencies.MainCurrenciesFrame.CurrenciesFrame.Money.Value.FontFace
	end)

	return ok and font or Font.fromEnum(Enum.Font.FredokaOne)
end

local function makeScreen()
	local gui = Instance.new("ScreenGui")
	gui.Name = "IslandTransition"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1001
	gui.Parent = player:WaitForChild("PlayerGui")

	local function lid(isTop)
		local frame = Instance.new("Frame")
		frame.Name = isTop and "TopLid" or "BottomLid"
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0, isTop and 0 or 1)
		frame.Position = UDim2.fromScale(0, isTop and 0 or 1)
		frame.Size = UDim2.new(1, 0, 0.5, 2) -- shut (2px overlap so no seam)
		frame.Parent = gui

		local edge = Instance.new("Frame")
		edge.Name = "Edge"
		edge.BackgroundColor3 = Color3.new(0, 0, 0)
		edge.BorderSizePixel = 0
		edge.AnchorPoint = Vector2.new(0, isTop and 0 or 1)
		edge.Position = UDim2.fromScale(0, isTop and 1 or 0)
		edge.Size = UDim2.new(1, 0, 0, EDGE)
		edge.Parent = frame

		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = isTop and NumberSequence.new(0, 1) or NumberSequence.new(1, 0)
		fade.Parent = edge

		return frame
	end

	local top, bottom = lid(true), lid(false)

	-- island name card
	local card = Instance.new("Frame")
	card.Name = "NameCard"
	card.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 40)
	card.Size = UDim2.new(0.6, 0, 0, 120)
	card.ZIndex = 5
	card.Parent = gui

	local function label(name, y, height, textSize)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y)
		l.Size = UDim2.new(1, 0, 0, height)
		l.FontFace = uiFont()
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextTransparency = 1
		l.ZIndex = 6
		l.Parent = card

		local size = Instance.new("UITextSizeConstraint")
		size.MaxTextSize = textSize
		size.Parent = l

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(15, 15, 25)
		stroke.Thickness = 3
		stroke.Transparency = 1
		stroke.Parent = l

		return l, stroke
	end

	local title, titleStroke = label("Title", 0, 72, 72)
	local subtitle, subtitleStroke = label("Subtitle", 74, 34, 30)

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = title

	local blur = Instance.new("BlurEffect")
	blur.Name = "IslandTransitionBlur"
	blur.Size = 18
	blur.Parent = Lighting

	return {
		gui = gui, top = top, bottom = bottom, blur = blur, card = card,
		title = title, titleStroke = titleStroke, subtitle = subtitle, subtitleStroke = subtitleStroke,
		gradient = gradient,
	}
end

local function openEyes(s, time)
	local info = TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(s.top, info, { Size = UDim2.fromScale(1, 0), Position = UDim2.new(0, 0, 0, -EDGE) }):Play()
	TweenService:Create(s.bottom, info, { Size = UDim2.fromScale(1, 0), Position = UDim2.new(0, 0, 1, EDGE) }):Play()
	TweenService:Create(s.blur, TweenInfo.new(time * 1.3, Enum.EasingStyle.Quad), { Size = 0 }):Play()
end

local function showName(s, islandName)
	local island = IslandTransition.Islands[islandName]

	if not island then
		return
	end

	s.title.Text = island.title
	s.subtitle.Text = island.subtitle
	s.gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), island.color)

	-- drop in and fade in
	s.card.Position = UDim2.new(0.5, 0, 0, 10)
	local inInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(s.card, inInfo, { Position = UDim2.new(0.5, 0, 0, 40) }):Play()

	for _, obj in ipairs({ s.title, s.subtitle }) do
		TweenService:Create(obj, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	end

	for _, obj in ipairs({ s.titleStroke, s.subtitleStroke }) do
		TweenService:Create(obj, TweenInfo.new(0.4), { Transparency = 0 }):Play()
	end
end

local function hideName(s, time)
	local info = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	for _, obj in ipairs({ s.title, s.subtitle }) do
		TweenService:Create(obj, info, { TextTransparency = 1 }):Play()
	end

	for _, obj in ipairs({ s.titleStroke, s.subtitleStroke }) do
		TweenService:Create(obj, info, { Transparency = 1 }):Play()
	end

	TweenService:Create(s.card, info, { Position = UDim2.new(0.5, 0, 0, 20) }):Play()
end

-- wait until there's solid ground under you (the new island has streamed in), max a few seconds
local function waitForGround(maxTime)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local start = os.clock()

	while os.clock() - start < maxTime do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if root then
			params.FilterDescendantsInstances = { character }

			if workspace:Raycast(root.Position, Vector3.new(0, -25, 0), params) then
				return
			end
		end

		task.wait(0.1)
	end
end

-- travel to "Island1" / "Island2" with the transition. Returns what the server returned.
-- `via` = "portal" when you walked through a portal (you arrive at the portal on the other side)
function IslandTransition.travel(islandName, via)
	if busy then
		return { ok = false, reason = "busy" }
	end

	busy = true

	local s = makeScreen() -- instant black
	task.wait(0.15)

	local ok, result = pcall(function()
		return travelRemote:InvokeServer(islandName, via)
	end)

	if not ok then
		result = { ok = false, reason = "error" }
	end

	local moved = type(result) == "table" and result.ok == true

	if moved then
		waitForGround(3)
		task.wait(0.25) -- let the camera settle behind you
		openEyes(s, 0.9)
		task.wait(0.15)
		showName(s, islandName)
		task.wait(2.2)
		hideName(s, 0.5)
		task.wait(0.5)
	else
		openEyes(s, 0.35)
		task.wait(0.45)
	end

	s.gui:Destroy()
	s.blur:Destroy()
	busy = false

	return result
end

function IslandTransition.isBusy()
	return busy
end

-- a quick blink for short hops (the fishing shop buttons): eyes shut, run move() (it should
-- teleport you and return the server's result), eyes open. No island name card.
function IslandTransition.blink(move)
	if busy then
		return { ok = false, reason = "busy" }
	end

	busy = true

	local s = makeScreen()
	s.blur.Size = 0

	-- start open, then shut
	s.top.Size = UDim2.fromScale(1, 0)
	s.top.Position = UDim2.new(0, 0, 0, -EDGE)
	s.bottom.Size = UDim2.fromScale(1, 0)
	s.bottom.Position = UDim2.new(0, 0, 1, EDGE)

	local shut = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(s.top, shut, { Size = UDim2.new(1, 0, 0.5, 2), Position = UDim2.fromScale(0, 0) }):Play()
	TweenService:Create(s.bottom, shut, { Size = UDim2.new(1, 0, 0.5, 2), Position = UDim2.fromScale(0, 1) }):Play()
	TweenService:Create(s.blur, shut, { Size = 12 }):Play()
	task.wait(0.18)

	local ok, result = pcall(move)

	if not ok then
		result = { ok = false, reason = "error" }
	end

	if type(result) == "table" and result.ok then
		waitForGround(2)
		task.wait(0.1)
	end

	openEyes(s, 0.45)
	task.wait(0.5)

	s.gui:Destroy()
	s.blur:Destroy()
	busy = false

	return result
end

return IslandTransition
