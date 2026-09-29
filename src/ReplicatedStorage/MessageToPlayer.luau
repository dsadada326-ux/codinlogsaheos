-- Shared "toast" for StarterGui.MessageToPlayerText's two labels: ButtonUnavailable and
-- PurchaseUnavailable. Pops in, holds, fades out. A repeat call while one is showing just
-- resets its hold timer instead of stacking or restarting the pop.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local HOLD = 1.1
local FADE = 0.25

local M = {}
local state = {}

local function getLabel(name)
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("MessageToPlayerText", 10)
	return gui and gui:FindFirstChild(name)
end

function M.show(name)
	local label = getLabel(name)
	if not label then
		return
	end

	-- only one message at a time: a new one clears the others straight away
	for other, r in pairs(state) do
		if other ~= label and r.showing then
			r.hideAt = 0
			other.Visible = false
		end
	end

	local rec = state[label]
	if not rec then
		rec = { basePos = label.Position }
		state[label] = rec
	end
	rec.hideAt = os.clock() + HOLD

	if rec.showing then
		return -- already up: just extend how long it stays
	end
	rec.showing = true

	local stroke = label:FindFirstChildOfClass("UIStroke")
	if rec.tween then rec.tween:Cancel() end
	if rec.strokeTween then rec.strokeTween:Cancel() end

	-- on Fishing Frenzy the Rods / Sell / Upgrades buttons sit at the very top: show it just below them
	local base = rec.basePos
	local fishing = player.PlayerGui:FindFirstChild("Fishing")
	local top = fishing and fishing:FindFirstChild("Top")
	local screen = label:FindFirstAncestorOfClass("ScreenGui")
	if top and top.Visible and fishing.Enabled and screen then
		local row = top:FindFirstChild("Frame") or top
		-- AbsolutePosition is in the same space for every ScreenGui, so compare directly
		local rowBottom = row.AbsolutePosition.Y + row.AbsoluteSize.Y
		local labelTop = screen.AbsolutePosition.Y + base.Y.Scale * screen.AbsoluteSize.Y + base.Y.Offset
		local needed = rowBottom + 10 - labelTop
		if needed > 0 then
			base = base + UDim2.fromOffset(0, needed)
		end
	end

	label.Visible = true
	label.TextTransparency = 0
	if stroke then stroke.Transparency = 0 end
	label.Position = base - UDim2.fromScale(0, 0.02)
	TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = base }):Play()

	task.spawn(function()
		while os.clock() < rec.hideAt do
			task.wait(0.05)
		end

		local fadeInfo = TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		rec.tween = TweenService:Create(label, fadeInfo, { TextTransparency = 1 })
		rec.tween:Play()
		if stroke then
			rec.strokeTween = TweenService:Create(stroke, fadeInfo, { Transparency = 1 })
			rec.strokeTween:Play()
		end

		task.wait(FADE)
		label.Visible = false
		rec.showing = false
	end)
end

return M
