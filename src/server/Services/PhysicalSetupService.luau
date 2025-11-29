local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PhysicsSetupService = {}

local Config = require(ReplicatedStorage.Shared.RocketConfig)

function PhysicsSetupService:Init()
    -- 1. Connect for FUTURE players
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerAdded(player)
    end)
    
    -- 2. Handle EXISTING players
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function() 
            self:OnPlayerAdded(player) 
        end)
    end
end

function PhysicsSetupService:OnPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.EvaluateStateMachine = false 
        task.wait() 
        self:SetupCharacter(character)
    end)
    
    player.DevEnableMouseLock = false
end

function PhysicsSetupService:SetupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    -- 1. Create Manager
    local cm = Instance.new("ControllerManager")
    cm.Name = "ControllerManager"
    cm.RootPart = rootPart
    cm.FacingDirection = rootPart.CFrame.LookVector
    cm.BaseTurnSpeed = Config.BASE_TURN_SPEED

    -- 2. Create Controllers
    local ac = Instance.new("AirController", cm)
    ac.Name = "AirController"
    ac.BalanceRigidityEnabled = true
    ac.MoveMaxForce = Config.AIR_MAX_FORCE
    ac.TurnMaxTorque = Config.AIR_TURN_TORQUE
    
    local gc = Instance.new("GroundController", cm)
    gc.Name = "GroundController"
    gc.BalanceRigidityEnabled = true
    gc.Friction = Config.GROUND_FRICTION_BASE
    gc.FrictionWeight = Config.GROUND_FRICTION_WEIGHT
    gc.GroundOffset = humanoid.HipHeight + Config.GROUND_OFFSET
    
    local climb = Instance.new("ClimbController", cm)
    climb.Name = "ClimbController"
    local swim = Instance.new("SwimController", cm)
    swim.Name = "SwimController"
    
    -- 3. Create Sensors
    local groundSensor = Instance.new("ControllerPartSensor")
    groundSensor.Name = "GroundSensor"
    groundSensor.SensorMode = Enum.SensorMode.Floor
    groundSensor.SearchDistance = gc.GroundOffset + 0.5
    
    local climbSensor = Instance.new("ControllerPartSensor")
    climbSensor.Name = "ClimbSensor"
    climbSensor.SensorMode = Enum.SensorMode.Ladder
    climbSensor.SearchDistance = 1.5
    
    local waterSensor = Instance.new("BuoyancySensor")
    waterSensor.Name = "BuoyancySensor"
    
    -- 4. Assign & Parent
    cm.GroundSensor = groundSensor
    cm.ClimbSensor = climbSensor
    
    groundSensor.Parent = rootPart
    climbSensor.Parent = rootPart
    waterSensor.Parent = rootPart
    
    cm.ActiveController = gc
    cm.Parent = character

    -- 5. FIX BUG 2: FORCE DEATH STATE
    humanoid.HealthChanged:Connect(function(health)
        if health <= 0 then
            print("☠️ Server: Health is 0. Manually triggering Death.")
            
            -- A. Disconnect this listener so it doesn't fire twice
            -- (Optional, but good practice)
            
            -- B. Turn the brain back ON so Roblox knows to respawn
            humanoid.EvaluateStateMachine = true
            
            -- C. Force the Dead state
            humanoid:ChangeState(Enum.HumanoidStateType.Dead)
            
            -- D. Kill the physics controller so they flop
            cm.ActiveController = nil
        end
    end)
    
    print("✅ Physics Setup Complete | Offset:", gc.GroundOffset, "| Sensor:", groundSensor.SearchDistance)
end

return PhysicsSetupService