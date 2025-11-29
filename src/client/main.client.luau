local ControllerFolder = script.Parent:WaitForChild("Controllers")

-- Load PhysicsController
local PhysicsController = require(ControllerFolder:WaitForChild("PhysicsController"))
PhysicsController:Init()

-- Load RocketController
local RocketController = require(ControllerFolder:WaitForChild("RocketController"))
RocketController:Init()

print("Client Controllers Loaded")