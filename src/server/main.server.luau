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

-- HELPER: Converts rigid joints to floppy constraints
local function ragdollCharacter(char)
    -- 1. Loosen the joints (Motor6D -> BallSocket)
    for _, descendant in ipairs(char:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            local part0 = descendant.Part0
            local part1 = descendant.Part1
            
            -- Look for the matching attachments (Standard R15 naming)
            local attachmentName = descendant.Name .. "RigAttachment"
            local a0 = part0:FindFirstChild(attachmentName) or part0:FindFirstChild(attachmentName, true)
            local a1 = part1:FindFirstChild(attachmentName) or part1:FindFirstChild(attachmentName, true)
            
            if a0 and a1 then
                -- Create the loose joint
                local socket = Instance.new("BallSocketConstraint")
                socket.Attachment0 = a0
                socket.Attachment1 = a1
                socket.LimitsEnabled = true -- Prevents limbs from spinning 360 degrees
                socket.TwistLimitsEnabled = true
                socket.Parent = part1
                
                -- Delete the stiff joint
                descendant:Destroy()
            end
        end
        
        -- 2. Enable Physics Collisions
        -- Limbs are usually CanCollide=false while walking. We must turn them ON so they hit the floor.
        if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
            descendant.CanCollide = true
        end
    end
    
    -- 3. Turn off the RootPart so it doesn't anchor the body weirdly
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CanCollide = false
    end
end

-- 3. THE RESPAWN LISTENER 
local respawnRemote = ReplicatedStorage.Shared.Remotes:WaitForChild("RespawnSignal")

respawnRemote.OnServerEvent:Connect(function(player)
    local char = player.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then
                child:Destroy()
            end
        end
        -- Disable the ControllerManager
        -- This stops the "Invisible Hand" from holding the character upright
        local cm = char:FindFirstChild("ControllerManager")
        if cm then
            cm.ActiveController = nil -- Turns off Air/Ground controllers
        end
        
        -- Force Visual Death
        -- Standard Roblox "BreakJoints" makes the character collapse/fall apart
        ragdollCharacter(char)
        
        -- f you want to force the state explicitly
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Dead)
        end
    end
    
    task.wait(game.Players.RespawnTime) 
    
    player:LoadCharacter()
end)

print("✅ Server: Startup Complete")