print("🔌 Server: Booting up...")

-- services is a sibling folder of this script
local ServicesFolder = script.Parent:WaitForChild("Services")

local RocketService = require(ServicesFolder:WaitForChild("RocketService"))
RocketService:Init()

local PhysicsSetupService = require(ServicesFolder:WaitForChild("PhysicsSetupService"))
PhysicsSetupService:Init()

local RagdollService = require(ServicesFolder:WaitForChild("RagdollService"))
RagdollService:Init()

print("✅ Server: Startup Complete")
