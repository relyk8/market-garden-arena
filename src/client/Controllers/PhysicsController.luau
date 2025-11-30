local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PhysicsController = {}
local Config = require(ReplicatedStorage.Shared.RocketConfig)

-- State
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character = nil
local humanoid = nil
local cm = nil
local hrp = nil

-- Controllers & Sensors
local ac, gc, groundSensor, climbSensor

-- Input State
local Cmd = {
    upMove = false, downMove = false,
    leftMove = false, rightMove = false,
    lastUp = false, lastLeft = false,
}
local sideMove = 0
local forwardMove = 0

function PhysicsController:Init()
    player.CharacterAdded:Connect(function(char) self:OnCharacterAdded(char) end)
    player.CharacterRemoving:Connect(function() self:Cleanup() end)
    
    if player.Character then self:OnCharacterAdded(player.Character) end
end

function PhysicsController:OnCharacterAdded(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
    
    -- BUG 2 FIX: Since we are a Singleton (StarterPlayerScripts), we must detect death manually.
    -- Your old script didn't need this because it was in StarterCharacter and died with you.
    humanoid.Died:Connect(function() self:Cleanup() end)

    player.CameraMode = Enum.CameraMode.LockFirstPerson

    cm = character:WaitForChild("ControllerManager", 10)
    if not cm then warn("⚠️ PhysicsController: ControllerManager not found!") return end
    
    ac = cm:WaitForChild("AirController")
    gc = cm:WaitForChild("GroundController")
    groundSensor = hrp:WaitForChild("GroundSensor")
    climbSensor = hrp:WaitForChild("ClimbSensor")
    
    -- Setup
    hrp.RootPriority = Config.ROOT_PRIORITY
    
    ac.BalanceRigidityEnabled = true
    ac.MaintainAngularMomentum = false
    ac.MoveMaxForce = Config.AIR_MAX_FORCE
    ac.TurnMaxTorque = Config.AIR_TURN_TORQUE
    
    gc.BalanceRigidityEnabled = true
    gc.FrictionWeight = Config.GROUND_FRICTION_WEIGHT
    
    cm:SetAttribute("JumpImpulse", Config.JUMP_IMPULSE)

    self:BindInputs()
    
    self.updateConnection = RunService.RenderStepped:Connect(function(dt)
        self:StepController(dt)
    end)
    
    -- make sure death actually kills.
    local deathConnection
    deathConnection = humanoid.HealthChanged:Connect(function(health)
        if health <= 0 then
            print("☠️ Client: Reset detected. Signaling Server...")
            deathConnection:Disconnect() -- Don't fire twice
            
            -- Stop Physics locally immediately
            self:Cleanup()
            
            -- Tell Server to Respawn us
            local remote = ReplicatedStorage.Shared.Remotes:WaitForChild("RespawnSignal")
            remote:FireServer()
        end
    end)
    print("✅ PhysicsController: Active")
end

function PhysicsController:Cleanup()
    if self.updateConnection then 
        self.updateConnection:Disconnect() 
        self.updateConnection = nil
    end
    -- Unbind inputs to stop movement after death
    ContextActionService:UnbindAction("Jump")
    ContextActionService:UnbindAction("Forward")
    ContextActionService:UnbindAction("Backward")
    ContextActionService:UnbindAction("Left")
    ContextActionService:UnbindAction("Right")
    
    character = nil
    cm = nil
end

-- =========================================================================
-- YOUR EXACT STATE LOGIC
-- =========================================================================

function PhysicsController:CheckRunningState()
    -- Matches your: cm.GroundSensor.SensedPart ~= nil and not isControllerActive(gc) and state ~= Jumping
    return groundSensor.SensedPart ~= nil 
        and not self:IsControllerActive(gc) 
        and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
end

function PhysicsController:CheckFreefallState()
    -- Matches your: (Sensors == nil and not Active(Air)) OR state == Jumping
    local isFalling = groundSensor.SensedPart == nil 
                  and climbSensor.SensedPart == nil 
                  and not self:IsControllerActive(ac)
    
    return isFalling or humanoid:GetState() == Enum.HumanoidStateType.Jumping
end

function PhysicsController:StepController(dt)
    if not cm or not humanoid or not hrp then return end

    -- 1. Input Direction
    local moveDir = camera.CFrame:VectorToWorldSpace(Vector3.new(sideMove, 0, forwardMove))
    moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
    if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end
    
    cm.MovingDirection = moveDir
    
    if moveDir.Magnitude > 0 then
        cm.FacingDirection = moveDir
    else
        cm.FacingDirection = hrp.CFrame.LookVector
    end

    -- 2. State Machine (Strict adherence to your logic)
    -- We removed CheckSwimming/Climbing for simplicity unless you need them back
    
    if self:CheckRunningState() then
        cm.ActiveController = gc
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        gc.Friction = Config.GROUND_FRICTION_MOVING
        
    elseif self:CheckFreefallState() then
        -- This block catches "Jumping" state and immediately flips it to Freefall
        cm.ActiveController = ac
        humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    end
    
    -- 3. Air Strafing
    if self:IsControllerActive(ac) then
        self:UpdateAirVelocity(dt)
    end
end

function PhysicsController:DoJump(actionName, inputState, inputObject)
    if not cm or inputState ~= Enum.UserInputState.Begin then return end

    if self:IsControllerActive(gc) then
        local jumpImpulse = cm:GetAttribute("JumpImpulse")
        cm.RootPart:ApplyImpulse(jumpImpulse)
        
        -- Set state to Jumping. 
        -- Next frame, CheckFreefallState() will see this, return TRUE, and switch us to Freefall/AirController.
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        cm.ActiveController = ac 

        local floor = groundSensor.SensedPart
        if floor then
            floor:ApplyImpulseAtPosition(-jumpImpulse, groundSensor.HitFrame.Position)
        end
    end
end

-- ... [BindInputs, UpdateAirVelocity, IsControllerActive match previous] ...

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

function PhysicsController:UpdateAirVelocity(dt)
    local lookCFrame = camera.CFrame
    local wishDir = lookCFrame:VectorToWorldSpace(Vector3.new(sideMove, 0, forwardMove))
    wishDir = Vector3.new(wishDir.X, 0, wishDir.Z)
    if wishDir.Magnitude > 0.001 then wishDir = wishDir.Unit else return end

    local vel = hrp.AssemblyLinearVelocity
    local currentSpeed = vel:Dot(wishDir)
    local addSpeed = math.clamp(Config.AIR_MAX_SPEED - currentSpeed, 0, Config.AIR_ACCEL * dt)
    if addSpeed > 0 then hrp.AssemblyLinearVelocity = vel + (wishDir * addSpeed) end
end

function PhysicsController:IsControllerActive(controller)
    return cm and cm.ActiveController == controller and controller.Active
end

return PhysicsController