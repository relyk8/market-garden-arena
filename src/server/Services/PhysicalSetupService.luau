local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PhysicsSetupService = {}

local Config = require(ReplicatedStorage.Shared.RocketConfig)

function PhysicsSetupService:Init()
    workspace.Gravity = Config.GRAVITY_ACCEL
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            self:SetupCharacter(player, character)
        end)
        player.DevEnableMouseLock = false
    end)
end

function PhysicsSetupService:SetupCharacter(player, character)
    -- 1. WAIT FOR HUMANOID
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    
    -- 2. DISABLE STATE MACHINE (Restores your Physics/Momentum)
    task.wait() -- Wait for HipHeight calculation like your old code
    
    -- 3. SETUP CONTROLLER MANAGER
    local cm = Instance.new("ControllerManager")
    cm.Name = "ControllerManager"
    cm.RootPart = rootPart
    cm.FacingDirection = rootPart.CFrame.LookVector
    cm.BaseTurnSpeed = Config.BASE_TURN_SPEED
    
    -- Controllers
    local ac = Instance.new("AirController", cm)
    ac.Name = "AirController"
    ac.BalanceRigidityEnabled = true
    ac.MoveMaxForce = Config.AIR_MAX_FORCE -- 0
    ac.TurnMaxTorque = Config.AIR_TURN_TORQUE
    
    local gc = Instance.new("GroundController", cm)
    gc.Name = "GroundController"
    gc.BalanceRigidityEnabled = true
    gc.Friction = Config.GROUND_FRICTION_BASE
    gc.FrictionWeight = Config.GROUND_FRICTION_WEIGHT
    -- Dynamic Offset (Your Logic)
    gc.GroundOffset = humanoid.HipHeight + Config.GROUND_OFFSET 
    
    local climb = Instance.new("ClimbController", cm)
    climb.Name = "ClimbController"
    local swim = Instance.new("SwimController", cm)
    swim.Name = "SwimController"
    
    -- Sensors (In RootPart)
    local groundSensor = Instance.new("ControllerPartSensor")
    groundSensor.Name = "GroundSensor"
    groundSensor.SensorMode = Enum.SensorMode.Floor
    groundSensor.SearchDistance = gc.GroundOffset + 0.5
    groundSensor.Parent = rootPart
    
    local climbSensor = Instance.new("ControllerPartSensor")
    climbSensor.Name = "ClimbSensor"
    climbSensor.SensorMode = Enum.SensorMode.Ladder
    climbSensor.SearchDistance = 1.5
    climbSensor.Parent = rootPart
    
    cm.GroundSensor = groundSensor
    cm.ClimbSensor = climbSensor
    cm.ActiveController = gc
    cm.Parent = character

    humanoid.EvaluateStateMachine = false 

    print("✅ Physics Setup: StateMachine FALSE (Momentum Active)")
end

return PhysicsSetupService