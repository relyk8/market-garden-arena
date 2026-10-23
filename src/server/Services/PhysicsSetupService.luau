local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PhysicsSetupService = {}

local Config = require(ReplicatedStorage.Shared.GlobalConfig)

-- SpawnLocations give spawning characters a ForceField; this game has no spawn protection
local function removeForceField(child: Instance)
	if child:IsA("ForceField") then
		child:Destroy()
	end
end

local function setupCharacter(character: Model)
	for _, child in character:GetChildren() do
		removeForceField(child)
	end
	character.ChildAdded:Connect(removeForceField)

	-- 1. wait for humanoid
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- 2. wait a frame so the Humanoid has computed HipHeight before it's read below
	task.wait()

	-- 3. setup controller manager
	local cm = Instance.new("ControllerManager")
	cm.Name = "ControllerManager"
	cm.RootPart = rootPart
	cm.FacingDirection = rootPart.CFrame.LookVector
	cm.BaseTurnSpeed = Config.BASE_TURN_SPEED

	-- controllers
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
	-- hover height follows the rig's HipHeight
	gc.GroundOffset = humanoid.HipHeight + Config.GROUND_OFFSET
	gc.Parent = cm

	local climb = Instance.new("ClimbController")
	climb.Name = "ClimbController"
	climb.Parent = cm
	local swim = Instance.new("SwimController")
	swim.Name = "SwimController"
	swim.Parent = cm

	-- sensors (in RootPart)
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

	-- with the state machine off, the Humanoid no longer manages limb collisions, so animated feet
	-- scrape the floor every stride and drag the GroundController's speed down. only the
	-- CollisionPart (torso) collides, like a default Humanoid. RagdollService re-enables limbs on death
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part ~= rootPart and part.Name ~= "CollisionPart" then
			part.CanCollide = false
		end
	end

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
