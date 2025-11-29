-- src/server/init.server.lua
-- Mapped to: ServerScriptService/Main

print("🔌 Server: Booting up...")

-- 1. Locate the Services Folder
-- Since 'Services' is a folder inside src/server, it appears as a child of this script in Studio.
local ServicesFolder = script.Parent:WaitForChild("Services")

local activeServices = {}

-- 2. Require (Load) all Modules
for _, module in ipairs(ServicesFolder:GetChildren()) do
	if module:IsA("ModuleScript") then
		print("   loading service: " .. module.Name)
		
		-- This line forces the ModuleScript to run its code
		local service = require(module)
		
		table.insert(activeServices, service)
	end
end
-- 3. Initialize all Services
print("🔌 Server: Initializing Services...")
for _, service in ipairs(activeServices) do
	if type(service.Init) == "function" then
		-- This calls the function where you connected your RemoteEvents
		service:Init()
	end
end

-- 4. Start all Services (Optional, for game loops)
for _, service in ipairs(activeServices) do
	if type(service.Start) == "function" then
		service:Start()
	end
end

print("✅ Server: Startup Complete")