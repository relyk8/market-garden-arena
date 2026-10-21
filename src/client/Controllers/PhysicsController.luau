local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PhysicsController = {}
local Config = require(ReplicatedStorage.Shared.GlobalConfig)

-- NEW: Import the strafe logic
local Controllers = script.Parent
local StrafeController = require(Controllers:WaitForChild("StrafeController"))

-- State
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid: Humanoid? = nil
local cm: ControllerManager? = nil
local hrp: BasePart? = nil
local updateConnection: RBXScriptConnection? = nil

-- Controllers & Sensors
local ac: AirController? = nil
local gc: GroundController? = nil
local groundSensor: ControllerPartSensor? = nil
local climbSensor: ControllerPartSensor? = nil

-- Input State
local Cmd = {
	upMove = false,
	downMove = false,
	leftMove = false,
	rightMove = false,
	lastUp = false,
	lastLeft = false,
}
local sideMove = 0
local forwardMove = 0

-- GroundSensor reach beyond GroundOffset while standing (matches PhysicsSetupService)
local SENSOR_MARGIN = 0.5

local function isControllerActive(controller: ControllerBase?): boolean
	return cm ~= nil and controller ~= nil and cm.ActiveController == controller and controller.Active
end

local function checkRunningState(hum: Humanoid, root: BasePart, sensor: ControllerPartSensor): boolean
	-- Only land while not moving upward, so the ground can't re-catch a jump on takeoff
	return sensor.SensedPart ~= nil
		and not isControllerActive(gc)
		and hum:GetState() ~= Enum.HumanoidStateType.Jumping
		and root.AssemblyLinearVelocity.Y <= 0
end

local function checkFreefallState(hum: Humanoid, sensor: ControllerPartSensor, climb: ControllerPartSensor): boolean
	local isFalling = sensor.SensedPart == nil and climb.SensedPart == nil and not isControllerActive(ac)

	return isFalling or hum:GetState() == Enum.HumanoidStateType.Jumping
end

local function stepController(dt: number)
	local manager, hum, root = cm, humanoid, hrp
	local air, ground, sensor, climb = ac, gc, groundSensor, climbSensor
	if not manager or not hum or not root then
		return
	end
	if not air or not ground or not sensor or not climb then
		return
	end

	-- 1. Input Direction
	local moveDir = camera.CFrame:VectorToWorldSpace(Vector3.new(sideMove, 0, forwardMove))
	moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
	end

	manager.MovingDirection = moveDir

	if moveDir.Magnitude > 0 then
		manager.FacingDirection = moveDir
	else
		manager.FacingDirection = root.CFrame.LookVector
	end

	-- 2. State Machine
	-- Extend the sensor by the distance the next frames' fall covers, so fast falls can't skip
	-- past the sensing window and hit the floor physically (which bounces)
	local fallSpeed = math.max(-root.AssemblyLinearVelocity.Y, 0)
	sensor.SearchDistance = ground.GroundOffset + SENSOR_MARGIN + fallSpeed * dt * 2

	if checkRunningState(hum, root, sensor) then
		-- Landing: place the root at standing height and drop the fall speed, so the
		-- GroundController's stand spring has nothing to correct and can't bounce the root
		-- back out of sensor range
		local standY = sensor.HitFrame.Position.Y + ground.GroundOffset + root.Size.Y / 2
		root.CFrame += Vector3.new(0, standY - root.Position.Y, 0)
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		manager.ActiveController = ground
		hum:ChangeState(Enum.HumanoidStateType.Running)
		ground.Friction = Config.GROUND_FRICTION_MOVING
	elseif checkFreefallState(hum, sensor, climb) then
		manager.ActiveController = air
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	-- 3. Air Strafing (Delegated to StrafeController) 🚀
	if isControllerActive(air) then
		StrafeController:Update(root, moveDir, dt)
	end
end

local function doJump(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	local manager, hum, root, sensor = cm, humanoid, hrp, groundSensor
	if not manager or inputState ~= Enum.UserInputState.Begin then
		return
	end
	if not hum or not root or not sensor then
		return
	end

	if isControllerActive(gc) then
		local jumpImpulse = manager:GetAttribute("JumpImpulse") :: Vector3
		root:ApplyImpulse(jumpImpulse)

		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		manager.ActiveController = ac

		local floor = sensor.SensedPart
		if floor then
			floor:ApplyImpulseAtPosition(-jumpImpulse, sensor.HitFrame.Position)
		end
	end
end

local function handleMove(actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	local state = (inputState == Enum.UserInputState.Begin)
	if actionName == "Forward" then
		Cmd.upMove = state
		if state then
			Cmd.lastUp = true
		end
	end
	if actionName == "Backward" then
		Cmd.downMove = state
		if state then
			Cmd.lastUp = false
		end
	end
	if actionName == "Left" then
		Cmd.leftMove = state
		if state then
			Cmd.lastLeft = true
		end
	end
	if actionName == "Right" then
		Cmd.rightMove = state
		if state then
			Cmd.lastLeft = false
		end
	end

	if Cmd.leftMove and Cmd.rightMove then
		sideMove = Cmd.lastLeft and -1 or 1
	else
		sideMove = Cmd.leftMove and -1 or (Cmd.rightMove and 1 or 0)
	end

	if Cmd.upMove and Cmd.downMove then
		forwardMove = Cmd.lastUp and -1 or 1
	else
		forwardMove = Cmd.upMove and -1 or (Cmd.downMove and 1 or 0)
	end
end

local function bindInputs()
	ContextActionService:BindAction("Jump", doJump, true, Enum.KeyCode.Space)

	ContextActionService:BindAction("Forward", handleMove, false, Enum.KeyCode.W)
	ContextActionService:BindAction("Backward", handleMove, false, Enum.KeyCode.S)
	ContextActionService:BindAction("Left", handleMove, false, Enum.KeyCode.A)
	ContextActionService:BindAction("Right", handleMove, false, Enum.KeyCode.D)
end

local function cleanup()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	ContextActionService:UnbindAction("Jump")
	ContextActionService:UnbindAction("Forward")
	ContextActionService:UnbindAction("Backward")
	ContextActionService:UnbindAction("Left")
	ContextActionService:UnbindAction("Right")

	cm = nil
end

local function onCharacterAdded(newChar: Model)
	local hum = newChar:WaitForChild("Humanoid") :: Humanoid
	local root = newChar:WaitForChild("HumanoidRootPart") :: BasePart
	humanoid, hrp = hum, root

	hum.Died:Connect(cleanup)

	player.CameraMode = Enum.CameraMode.LockFirstPerson

	local manager = newChar:WaitForChild("ControllerManager", 10) :: ControllerManager?
	cm = manager
	if not manager then
		warn("⚠️ PhysicsController: ControllerManager not found!")
		return
	end

	local air = manager:WaitForChild("AirController") :: AirController
	local ground = manager:WaitForChild("GroundController") :: GroundController
	ac, gc = air, ground
	groundSensor = root:WaitForChild("GroundSensor") :: ControllerPartSensor
	climbSensor = root:WaitForChild("ClimbSensor") :: ControllerPartSensor

	-- Setup
	root.RootPriority = Config.ROOT_PRIORITY

	air.BalanceRigidityEnabled = true
	air.MaintainAngularMomentum = false
	air.MoveMaxForce = Config.AIR_MAX_FORCE
	air.TurnMaxTorque = Config.AIR_TURN_TORQUE

	ground.BalanceRigidityEnabled = true
	ground.FrictionWeight = Config.GROUND_FRICTION_WEIGHT

	-- 🛑 PHASING FIX 🛑
	-- This stops the controller from dragging your legs underground when you land.
	ground.GroundOffset = hum.HipHeight

	manager:SetAttribute("JumpImpulse", Config.JUMP_IMPULSE)

	bindInputs()

	updateConnection = RunService.RenderStepped:Connect(stepController)

	local deathConnection: RBXScriptConnection
	deathConnection = hum.HealthChanged:Connect(function(health)
		if health <= 0 then
			deathConnection:Disconnect()
			cleanup()
			local remote = ReplicatedStorage.Shared.Remotes:WaitForChild("RespawnSignal") :: RemoteEvent
			remote:FireServer()
		end
	end)
	print("✅ PhysicsController: Active")
end

function PhysicsController:Init()
	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(cleanup)

	if player.Character then
		onCharacterAdded(player.Character)
	end
end

function PhysicsController:OnCharacterAdded(newChar: Model)
	onCharacterAdded(newChar)
end

function PhysicsController:Cleanup()
	cleanup()
end

return PhysicsController
