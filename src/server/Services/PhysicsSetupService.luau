local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PhysicsSetupService = {}

local Config = require(ReplicatedStorage.Shared.GlobalConfig)

local function setupCharacter(character: Model)
	-- 1. WAIT FOR HUMANOID
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- 2. DISABLE STATE MACHINE (Restores your Physics/Momentum)
	task.wait() -- Wait for HipHeight calculation like your old code

	-- 3. SETUP CONTROLLER MANAGER
	local cm = Instance.new("ControllerManager")
	cm.Name = "ControllerManager"
	cm.RootPart = rootPart
	cm.FacingDirection = rootPart.CFrame.LookVector
	cm.BaseTurnSpeed = Config.BASE_TURN_SPEED

	-- Controllers
	local ac = Instance.new("AirController")
	ac.Name = "AirController"
	ac.BalanceRigidityEnabled = true
	ac.MoveMaxForce = Config.AIR_MAX_FORCE -- 0
	ac.TurnMaxTorque = Config.AIR_TURN_TORQUE
	ac.Parent = cm

	local gc = Instance.new("GroundController")
	gc.Name = "GroundController"
	gc.BalanceRigidityEnabled = true
	gc.Friction = Config.GROUND_FRICTION_BASE
	gc.FrictionWeight = Config.GROUND_FRICTION_WEIGHT
	-- Dynamic Offset (Your Logic)
	gc.GroundOffset = humanoid.HipHeight + Config.GROUND_OFFSET
	gc.Parent = cm

	local climb = Instance.new("ClimbController")
	climb.Name = "ClimbController"
	climb.Parent = cm
	local swim = Instance.new("SwimController")
	swim.Name = "SwimController"
	swim.Parent = cm

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

function PhysicsSetupService:Init()
	workspace.Gravity = Config.GRAVITY_ACCEL
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(setupCharacter)
		player.DevEnableMouseLock = false
	end)
end

function PhysicsSetupService:SetupCharacter(character: Model)
	setupCharacter(character)
end

return PhysicsSetupService
