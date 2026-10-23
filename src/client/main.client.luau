local ControllerFolder = script.Parent:WaitForChild("Controllers")

-- load PhysicsController
local PhysicsController = require(ControllerFolder:WaitForChild("PhysicsController"))
PhysicsController:Init()

-- load RocketController
local RocketController = require(ControllerFolder:WaitForChild("RocketController"))
RocketController:Init()

-- load CameraController
local CameraController = require(ControllerFolder:WaitForChild("CameraController"))
CameraController:Init()

-- load TelemetryController (Studio only, see GlobalConfig.DEBUG_TELEMETRY)
local TelemetryController = require(ControllerFolder:WaitForChild("TelemetryController"))
TelemetryController:Init()

-- load DebugController (Studio only, see GlobalConfig.DEBUG_KEYS)
local DebugController = require(ControllerFolder:WaitForChild("DebugController"))
DebugController:Init()

print("Client Controllers Loaded")
