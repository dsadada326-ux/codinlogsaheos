local ClickHandler = require(script:WaitForChild("ClickHandler"))

local clickDetector = workspace
	:WaitForChild("Islands")
	:WaitForChild("Island1")
	:WaitForChild("RedButton")
	:WaitForChild("Button")
	:WaitForChild("ClickPart")
	:WaitForChild("ClickDetector")

-- fires on the server with the player who clicked
clickDetector.MouseClick:Connect(ClickHandler.click)
