local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- MODULES
local Controllers = script.Parent
local Config = require(ReplicatedStorage.Shared.RocketConfig)
local StrafeController = require(Controllers:WaitForChild("StrafeController")) -- NEW

local PhysicsController = {}

-- STATE
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character = nil
local humanoid = nil
local hrp = nil
local cm, ac, gc, groundSensor

-- INPUT STATE
local sideMove, forwardMove = 0, 0
local Cmd = { up=false, down=false, left=false, right=false, lastUp=false, lastLeft=false }

function PhysicsController:Init()
	player.CharacterAdded:Connect(function(c) self:OnCharacterAdded(c) end)
	player.CharacterRemoving:Connect(function() self:Cleanup() end)
	if player.Character then self:OnCharacterAdded(player.Character) end
	self:BindInputs()
end

function PhysicsController:OnCharacterAdded(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")
	hrp = character:WaitForChild("HumanoidRootPart")
	
	cm = character:WaitForChild("ControllerManager", 5)
	if not cm then return end
	
	ac = cm:WaitForChild("AirController")
	gc = cm:WaitForChild("GroundController")
	groundSensor = hrp:WaitForChild("GroundSensor")
	
	-- CONFIG
	ac.MoveMaxForce = Config.AIR_MAX_FORCE
	ac.BalanceRigidityEnabled = true
	gc.BalanceRigidityEnabled = true
	cm:SetAttribute("JumpImpulse", Config.JUMP_IMPULSE)
	
	-- RENDER LOOP
	self.updateConnection = RunService.RenderStepped:Connect(function(dt)
		self:StepController(dt)
	end)
end

function PhysicsController:StepController(dt)
	if not cm then return end

	-- 1. CALCULATE WISH DIRECTION (Where do we want to go?)
	local wishDir = camera.CFrame:VectorToWorldSpace(Vector3.new(sideMove, 0, forwardMove))
	wishDir = Vector3.new(wishDir.X, 0, wishDir.Z) -- Flatten Y
	if wishDir.Magnitude > 0 then wishDir = wishDir.Unit end
	
	-- Update ControllerManager intents
	cm.MovingDirection = wishDir
	local lookDir = camera.CFrame.LookVector
	cm.FacingDirection = Vector3.new(lookDir.X, 0, lookDir.Z).Unit

	-- 2. STATE MACHINE
	local isGrounded = groundSensor.SensedPart ~= nil
	
	if isGrounded and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
		-- >> GROUND STATE <<
		if cm.ActiveController ~= gc then
			cm.ActiveController = gc
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	else
		-- >> AIR STATE <<
		if cm.ActiveController ~= ac then
			cm.ActiveController = ac
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		
		-- DELEGATE TO STRAFE CONTROLLER 🚀
		StrafeController:Update(hrp, wishDir, dt)
	end
end

function PhysicsController:Cleanup()
	if self.updateConnection then 
		self.updateConnection:Disconnect() 
		self.updateConnection = nil 
	end
end

-- (Keep your existing DoJump and BindInputs functions exactly the same below)
function PhysicsController:DoJump(actionName, inputState, inputObject)
	if not cm or inputState ~= Enum.UserInputState.Begin then return end
	if cm.ActiveController == gc then
		local jumpImpulse = cm:GetAttribute("JumpImpulse")
		cm.RootPart:ApplyImpulse(jumpImpulse)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		cm.ActiveController = ac 
		
		local floor = groundSensor.SensedPart
		if floor then
			floor:ApplyImpulseAtPosition(-jumpImpulse, groundSensor.HitFrame.Position)
		end
	end
end

function PhysicsController:BindInputs()
	ContextActionService:BindAction("Jump", function(n, s, i) self:DoJump(n,s,i) end, true, Enum.KeyCode.Space)
	
	local function handleMove(actionName, inputState, inputObject)
		local state = (inputState == Enum.UserInputState.Begin)
		if actionName == "Forward" then Cmd.upMove = state; if state then Cmd.lastUp = true end end
		if actionName == "Backward" then Cmd.downMove = state; if state then Cmd.lastUp = false end end
		if actionName == "Left" then Cmd.leftMove = state; if state then Cmd.lastLeft = true end end
		if actionName == "Right" then Cmd.rightMove = state; if state then Cmd.lastLeft = false end end
		
		if Cmd.leftMove and Cmd.rightMove then sideMove = Cmd.lastLeft and -1 or 1
		else sideMove = Cmd.leftMove and -1 or (Cmd.rightMove and 1 or 0) end
		
		if Cmd.upMove and Cmd.downMove then forwardMove = Cmd.lastUp and -1 or 1
		else forwardMove = Cmd.upMove and -1 or (Cmd.downMove and 1 or 0) end
	end
	
	ContextActionService:BindAction("Forward", handleMove, false, Enum.KeyCode.W)
	ContextActionService:BindAction("Backward", handleMove, false, Enum.KeyCode.S)
	ContextActionService:BindAction("Left", handleMove, false, Enum.KeyCode.A)
	ContextActionService:BindAction("Right", handleMove, false, Enum.KeyCode.D)
end

return PhysicsController