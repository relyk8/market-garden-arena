local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local RocketController = {}

-- Imports
local Config = require(ReplicatedStorage.Shared.RocketConfig)
local FireRemote = ReplicatedStorage.Shared.Remotes:WaitForChild("FireRocket") 
local RocketVMTemplate = ReplicatedStorage.Shared.ViewModels:WaitForChild("RocketVM")

-- State
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local equipped = false
local equippedTool = nil

-- ViewModel Variables (From your script)
local viewModel
local animationController
local animator
local shootingAnimation = Instance.new("Animation")
shootingAnimation.AnimationId = Config.ANIMATION_ID

local swayCF = CFrame.new()

function RocketController:Init()
    -- Tool Listener
    player.CharacterAdded:Connect(function(character)
        character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and child.Name == "RocketLauncher" then
                self:Equip(child)
            end
        end)
        character.ChildRemoved:Connect(function(child)
            if child == equippedTool then
                self:Unequip()
            end
        end)
    end)
    
    -- Render Loop
    RunService.RenderStepped:Connect(function()
        self:UpdateViewModel()
    end)
end

function RocketController:Equip(tool)
    equipped = true
    equippedTool = tool
    
    -- YOUR VIEWMODEL SETUP
    viewModel = RocketVMTemplate:Clone()
    viewModel.Parent = camera -- "Camera.RocketVM"

    -- SAFETY FIX: Auto-assign PrimaryPart if missing
    if not viewModel.PrimaryPart then
        local root = viewModel:FindFirstChild("Handle") or viewModel:FindFirstChild("Body") or viewModel:GetChildren()[1]
        if root then
            viewModel.PrimaryPart = root
            warn("⚠️ Fixed missing PrimaryPart for RocketVM automatically.")
        else
            error("❌ RocketVM has no parts! Cannot set PrimaryPart.")
        end
    end
    
    -- Load animation stuff
    animationController = Instance.new("AnimationController")
    animationController.Parent = viewModel
    animator = Instance.new("Animator")
    animator.Parent = animationController
    
    -- Bind Click
    self.clickConnection = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:Fire()
        end
    end)
end

function RocketController:Unequip()
    equipped = false
    equippedTool = nil
    
    -- Cleanup
    if animator then animator:Destroy() end
    if animationController then animationController:Destroy() end
    if viewModel then viewModel:Destroy() end
    
    if self.clickConnection then self.clickConnection:Disconnect() end
end

function RocketController:Fire()
    local myModel = player.Character
    local Pos = mouse.Hit.Position
    
    -- 1. PLAY SHOOTING ANIMATION
    local shootAnimationTrack = animator:LoadAnimation(shootingAnimation)
    shootAnimationTrack.Looped = false
    shootAnimationTrack:Play()
    
    -- 2. TELL SERVER (Replaces MouseLoc RemoteFunction)
    FireRemote:FireServer(Pos)

    -- 3. ROCKET JUMP STUFF (Your Exact Math)
    local desVec = CFrame.new(myModel.Head.CFrame.Position, Pos).LookVector
    local rocketStart = CFrame.new(myModel.Head.CFrame.Position, Pos) + desVec * 2
    local rocketSpeed = rocketStart.LookVector * Config.ROCKET_SPEED

    local explosionTime = ((rocketStart.Position - Pos) / rocketSpeed).Magnitude * .9

    -- Wait logic
    task.delay(explosionTime, function()
        local hrp = myModel.HumanoidRootPart
        local blastVector = hrp.Position - Pos
        local distance = blastVector.Magnitude
        if distance <= Config.BLAST_RADIUS then
            hrp:ApplyImpulse(blastVector * Config.BLAST_FORCE / distance)
        end
    end)
end

function RocketController:UpdateViewModel()
    -- Safety Check
    if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health <= 0 and viewModel ~= nil then
        viewModel:Destroy()
        return -- Added return to stop error
    end
    
    if equipped == true and viewModel ~= nil then
        -- We loop through the real tool parts and make them invisible to ONLY you.
        -- We use LocalTransparencyModifier because Roblox resets it every frame, 
        -- so we must enforce it here in RenderStepped.
        if equippedTool then
            for _, part in pairs(equippedTool:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.LocalTransparencyModifier = 1 
                end
            end
        end

        -- Original Logic
        viewModel:SetPrimaryPartCFrame(camera.CFrame)
        
        for i, v in pairs(viewModel:GetChildren()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
        
        local mouseDelta = UserInputService:GetMouseDelta()/50
        
        local swayX = math.clamp(mouseDelta.X, -0.2, 0.2)
        local swayY = math.clamp(mouseDelta.Y, -0.2, 0.2)
        
        swayCF = swayCF:Lerp(CFrame.new(swayX, swayY, 0), 0.3)
        viewModel:SetPrimaryPartCFrame(camera.CFrame * swayCF)
    end
end

return RocketController