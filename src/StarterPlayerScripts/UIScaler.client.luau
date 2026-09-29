-- Scales pixel-based UI details with the screen size so the UI looks the same
-- on phones, tablets and PCs. Layouts themselves use scale; this handles what
-- scale can't: UIStroke thickness and fixed-size (non-TextScaled) text, including
-- UI that scripts build at runtime. Only affects ScreenGuis, not boards/billboards.

local Players = game:GetService("Players")

local REFERENCE = Vector2.new(1920, 1080) -- screen size the UI was designed at
local MIN_FACTOR = 0.4
local MAX_FACTOR = 1.5

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local factor = 1

local function computeFactor()
	local vp = camera.ViewportSize
	return math.clamp(math.min(vp.X / REFERENCE.X, vp.Y / REFERENCE.Y), MIN_FACTOR, MAX_FACTOR)
end

local function inScreenGui(obj)
	local gui = obj:FindFirstAncestorWhichIsA("LayerCollector")
	return gui ~= nil and gui:IsA("ScreenGui")
end

local function isScaledStroke(stroke)
	-- Strokes in ScaledSize mode are already a fraction of the object's size
	local ok, mode = pcall(function()
		return stroke.StrokeSizingMode
	end)
	return ok and mode == Enum.StrokeSizingMode.ScaledSize
end

local function apply(obj)
	if obj:IsA("UIStroke") then
		if isScaledStroke(obj) then return end
		local base = obj:GetAttribute("BaseThickness")
		if base == nil then
			base = obj.Thickness
			obj:SetAttribute("BaseThickness", base)
		end
		-- Anything under 1 is a scaled thickness set some other way; leave it
		if base < 1 then return end
		obj.Thickness = math.max(base * factor, 1)
	elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		if obj.TextScaled then return end
		local base = obj:GetAttribute("BaseTextSize")
		if base == nil then
			base = obj.TextSize
			obj:SetAttribute("BaseTextSize", base)
		end
		obj.TextSize = math.max(math.round(base * factor), 6)
	end
end

local function tryApply(obj)
	if (obj:IsA("UIStroke") or obj:IsA("GuiObject")) and inScreenGui(obj) then
		apply(obj)
	end
end

local function applyAll()
	for _, obj in playerGui:GetDescendants() do
		tryApply(obj)
	end
end

factor = computeFactor()
applyAll()

playerGui.DescendantAdded:Connect(function(obj)
	-- Wait a frame so scripts that build UI can finish setting TextSize/Thickness first
	task.defer(function()
		if obj.Parent then tryApply(obj) end
	end)
end)

camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	local new = computeFactor()
	if math.abs(new - factor) > 0.01 then
		factor = new
		applyAll()
	end
end)
