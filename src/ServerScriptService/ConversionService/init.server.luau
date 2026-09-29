local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Conversion = require(script:WaitForChild("Conversion"))
local Config = require(ReplicatedStorage:WaitForChild("ConversionConfig"))

local convertRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("ConvertButtons")

-- the Convert! button on the board calls this
convertRemote.OnServerInvoke = function(player)
	return Conversion.convert(player)
end

-- Button Value grows every few seconds, for everyone
task.spawn(function()
	while true do
		task.wait(Config.TickSeconds)
		Conversion.tick()
	end
end)
