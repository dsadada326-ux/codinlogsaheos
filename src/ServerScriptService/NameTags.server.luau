-- "@username" above every player's head (replaces Roblox's default name).
local Players = game:GetService("Players")

local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local STROKE_COLOR = Color3.fromRGB(35, 35, 40)

local function addTag(player, character)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)

	if not head or not humanoid then
		return
	end

	-- hide Roblox's own name so there aren't two
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local old = head:FindFirstChild("NameTag")

	if old then
		old:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(7, 1.1) -- in studs, so it shrinks with distance like a real name
	gui.StudsOffset = Vector3.new(0, 2.3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Name = "Username"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = TEXT_COLOR
	label.Text = "@" .. player.Name
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE_COLOR
	stroke.Thickness = 2.5
	stroke.Parent = label

	gui.Parent = head
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(character)
		addTag(player, character)
	end)

	if player.Character then
		task.spawn(addTag, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
