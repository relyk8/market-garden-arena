-- src/server/init.server.lua
print("🔌 Server: Booting up...")

-- 1. DEFINE VARIABLES (Crucial Step)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 2. FIND SERVICES FOLDER
-- Looking in script.Parent because Services is a sibling folder
local ServicesFolder = script.Parent:WaitForChild("Services")

local RocketService = require(ServicesFolder:WaitForChild("RocketService"))
RocketService:Init()

local PhysicsSetupService = require(ServicesFolder:WaitForChild("PhysicsSetupService"))
PhysicsSetupService:Init()

local RagdollService = require(ServicesFolder:WaitForChild("RagdollService"))
RagdollService:Init()

print("✅ Server: Startup Complete")