local ControllerFolder = script.Parent:WaitForChild("Controllers")

-- Load PhysicsController
local PhysicsController = require(ControllerFolder:WaitForChild("PhysicsController"))
PhysicsController:Init()

-- Load RocketController
local RocketController = require(ControllerFolder:WaitForChild("RocketController"))
RocketController:Init()

-- Load CameraController
local CameraController = require(ControllerFolder:WaitForChild("CameraController"))
CameraController:Init()

-- Load PackageController
local PackageController = require(ControllerFolder:WaitForChild("PackageController"))
PackageController:Init()

print("Client Controllers Loaded")