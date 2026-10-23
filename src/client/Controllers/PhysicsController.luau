local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PhysicsController = {}
local Config = require(ReplicatedStorage.Shared.GlobalConfig)

-- air strafing math
local Controllers = script.Parent
local StrafeController = require(Controllers:WaitForChild("StrafeController"))
local BhopController = require(Controllers:WaitForChild("BhopController"))

-- state
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid: Humanoid? = nil
local cm: ControllerManager? = nil
local hrp: BasePart? = nil
local updateConnection: RBXScriptConnection? = nil

-- controllers & sensors
local ac: AirController? = nil
local gc: GroundController? = nil
local groundSensor: ControllerPartSensor? = nil
local climbSensor: ControllerPartSensor? = nil

-- input state
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
	-- only land while not moving upward, so the ground can't re-catch a jump on takeoff
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

	-- 1. input direction
	-- built from flat yaw-only axes like Source, so camera pitch can't skew diagonals: flattening the
	-- pitched camera's forward shrinks it when looking up or down. right stays level at any pitch
	local right = camera.CFrame.RightVector
	right = Vector3.new(right.X, 0, right.Z).Unit
	local forward = Vector3.new(right.Z, 0, -right.X) -- up × right
	local moveDir = right * sideMove - forward * forwardMove
	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
	end

	manager.MovingDirection = moveDir

	-- face where the camera looks, not where the character moves: facing the move direction made
	-- the controller try to turn the body around when walking backwards, fighting the first-person
	-- camera lock, which showed as jitter to other players
	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.001 then
		manager.FacingDirection = flatLook.Unit
	end

	-- 2. state machine
	-- extend the sensor by the distance the next frames' fall covers, so fast falls can't skip
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
		BhopController:OnLand(root)
	elseif checkFreefallState(hum, sensor, climb) then
		manager.ActiveController = air
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	-- 3. air strafing and the landing bleed
	if isControllerActive(air) then
		BhopController:Stop(manager)
		StrafeController:Update(root, moveDir, dt)
	elseif isControllerActive(ground) then
		BhopController:UpdateGround(manager, root, dt)
	end
end

local function doJump(_actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
	local manager, hum, root, sensor = cm, humanoid, hrp, groundSensor
	-- each key press or wheel notch is one jump attempt. like TF2, holding jump never repeats, and a press
	-- in the air is spent rather than buffered for the landing
	local wheel = inputObject.UserInputType == Enum.UserInputType.MouseWheel
	local pressed = inputState == Enum.UserInputState.Begin or (wheel and inputState == Enum.UserInputState.Change)
	if not manager or not pressed then
		return
	end
	if not hum or not root or not sensor then
		return
	end

	if isControllerActive(gc) then
		BhopController:OnJump(manager, root)
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
	ContextActionService:BindAction("Jump", doJump, true, Enum.KeyCode.Space, Enum.UserInputType.MouseWheel)

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

	-- setup
	root.RootPriority = Config.ROOT_PRIORITY

	air.BalanceRigidityEnabled = true
	air.MaintainAngularMomentum = false
	air.MoveMaxForce = Config.AIR_MAX_FORCE
	air.TurnMaxTorque = Config.AIR_TURN_TORQUE

	ground.BalanceRigidityEnabled = true
	ground.FrictionWeight = Config.GROUND_FRICTION_WEIGHT

	-- hover at HipHeight so the legs stay above the floor instead of sinking into it on landing
	ground.GroundOffset = hum.HipHeight

	manager:SetAttribute("JumpImpulse", Config.JUMP_IMPULSE)
	manager.BaseMoveSpeed = Config.WALK_SPEED

	-- the character spawns with the state machine already off and a stale state (FallingDown), and
	-- stepController only sets the state on air/ground transitions. set it to match the starting
	-- controller so Animate plays walk/run before the first landing
	if manager.ActiveController == ground then
		hum:ChangeState(Enum.HumanoidStateType.Running)
	else
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	bindInputs()

	updateConnection = RunService.RenderStepped:Connect(stepController)

	local deathConnection: RBXScriptConnection
	deathConnection = hum.HealthChanged:Connect(function(health)
		if health <= 0 then
			deathConnection:Disconnect()
			-- release the body right away so it keeps its momentum; an active GroundController
			-- would hold it in place until the server's ragdoll arrives
			manager.ActiveController = nil
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
