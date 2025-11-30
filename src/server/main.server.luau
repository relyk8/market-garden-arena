-- src/server/init.server.lua
print("🔌 Server: Booting up...")

-- 1. DEFINE VARIABLES (Crucial Step)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 2. FIND SERVICES FOLDER
-- Looking in script.Parent because Services is a sibling folder
local ServicesFolder = script.Parent:WaitForChild("Services")

local activeServices = {}

-- 3. LOAD MODULES
for _, module in ipairs(ServicesFolder:GetChildren()) do
	if module:IsA("ModuleScript") then
		local success, service = pcall(require, module)
		if success then
			table.insert(activeServices, service)
			print("   Loaded Service: " .. module.Name)
		else
			warn("❌ FAILED to load " .. module.Name .. ": " .. tostring(service))
		end
	end
end

-- 4. INIT SERVICES
print("🔌 Server: Initializing Services...")
for _, service in ipairs(activeServices) do
	if type(service.Init) == "function" then
		task.spawn(function() service:Init() end)
	end
end

-- 3. THE RESPAWN LISTENER (No Loops!)
-- We wait for the Client to tell us "I Reset"
local respawnRemote = ReplicatedStorage.Shared.Remotes:WaitForChild("RespawnSignal")

respawnRemote.OnServerEvent:Connect(function(player)
    print(" Server: Received respawn signal from " .. player.Name)
    
    -- Optional: Wait the standard respawn time (e.g. 3-5 seconds)
    -- or remove this task.wait to respawn instantly.
    task.wait(game.Players.RespawnTime) 
    
    player:LoadCharacter()
end)

print("✅ Server: Startup Complete")