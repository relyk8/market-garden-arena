-- StarterPlayer/StarterPlayerScripts/ClientMain.client.lua

local ControllerFolder = script.Parent:WaitForChild("Controllers")

-- Require the RocketController
local RocketController = require(ControllerFolder:WaitForChild("RocketController"))

-- Boot it up
RocketController:Init()

print("Client Controllers Loaded")