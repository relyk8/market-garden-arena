-- StarterPlayerScripts/Controllers/RocketController.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local RocketController = {}

-- Imports
local Config = require(ReplicatedStorage.Shared.RocketConfig)
local FireRemote = ReplicatedStorage.Remotes:WaitForChild("FireRocket")

-- State
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local equipped = false
local viewModel = nil
local swayCFrame = CFrame.new()

-- Assets
local vmTemplate = ReplicatedStorage:WaitForChild("RocketVM") -- Assumes you moved the model here
local animController, animator, shootTrack

function RocketController:Init()
    -- Listen for tool equip (Assuming you still use a Tool instance for inventory)
    player.CharacterAdded:Connect(function(char)
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and child.Name == "RocketLauncher" then
                self:Equip(child)
            end
        end)
        char.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") and child.Name == "RocketLauncher" then
                self:Unequip()
            end
        end)
    end)
    
    -- Bind RenderStepped for ViewModel
    RunService.RenderStepped:Connect(function(dt)
        self:UpdateViewModel(dt)
    end)
end

function RocketController:Equip(tool)
    equipped = true
    
    -- Setup ViewModel
    viewModel = vmTemplate:Clone()
    viewModel.Parent = camera
    
    -- Setup Animation
    animController = Instance.new("AnimationController", viewModel)
    animator = Instance.new("Animator", animController)
    
    local anim = Instance.new("Animation")
    anim.AnimationId = Config.ANIMATION_ID
    shootTrack = animator:LoadAnimation(anim)
    
    -- Connect Input
    self.inputConnection = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:Fire()
        end
    end)
end

function RocketController:Unequip()
    equipped = false
    if viewModel then viewModel:Destroy() end
    if self.inputConnection then self.inputConnection:Disconnect() end
end

function RocketController:Fire()
    local mouse = player:GetMouse()
    local targetPos = mouse.Hit.Position
    local myRoot = player.Character.HumanoidRootPart
    
    -- Network: Tell server to spawn the REAL damage rocket
    FireRemote:FireServer(targetPos) 
    
    -- CLIENT PREDICTION (The "Feel")
    -- We spawn a "Ghost" rocket locally to calculate the jump physics
    self:SimulateLocalProjectile(myRoot.Position, targetPos)
end

function RocketController:SimulateLocalProjectile(origin, targetPos)
    local direction = (targetPos - origin).Unit
    local position = origin
    local speed = Config.ROCKET_SPEED -- e.g., 150 studs/sec
    
    local connection
    connection = RunService.RenderStepped:Connect(function(dt)
        -- 1. Calculate how far we move this frame
        local stepDistance = speed * dt
        
        -- 2. Raycast ahead to see if we will hit something THIS FRAME
        local result = workspace:Raycast(position, direction * stepDistance, self.rayParams)
        
        if result then
            -- WE HIT SOMETHING!
            connection:Disconnect() -- Stop the loop
            
            -- Apply the Jump Force NOW, exactly when it hits
            self:ApplyRocketJump(result.Position)
        else
            -- No hit, move the ghost position forward
            position = position + (direction * stepDistance)
            
            -- Optional: Update a visual projectile part here so you see it fly
        end
        
        -- Failsafe: If it flies too far (5 seconds), kill it
    end)
end

function RocketController:ApplyRocketJump(explosionPos)
    local myRoot = player.Character.HumanoidRootPart
    local dist = (myRoot.Position - explosionPos).Magnitude
    
    if dist < Config.BLAST_RADIUS then
        -- This logic now happens with PERFECT timing relative to distance
        local knockbackDir = (myRoot.Position - explosionPos).Unit
        myRoot:ApplyImpulse(knockbackDir * Config.SELF_KNOCKBACK_FORCE)
    end
endR

function RocketController:UpdateViewModel(dt)
    if not equipped or not viewModel then return end
    
    -- Sway Logic
    local delta = UserInputService:GetMouseDelta() / 100
    local swayX = math.clamp(delta.X, -Config.VM_SWAY_AMOUNT, Config.VM_SWAY_AMOUNT)
    local swayY = math.clamp(delta.Y, -Config.VM_SWAY_AMOUNT, Config.VM_SWAY_AMOUNT)
    
    local targetSway = CFrame.new(swayX, swayY, 0)
    swayCFrame = swayCFrame:Lerp(targetSway, Config.VM_LERP_SPEED)
    
    -- Apply to camera (using PivotTo is cleaner than SetPrimaryPartCFrame)
    viewModel:PivotTo(camera.CFrame * swayCFrame)
end

return RocketController