local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local RocketService = {}
local Config = require(ReplicatedStorage.Shared.RocketConfig)

-- Variables
local cooldowns = {}
local rocketTemplate = nil

function RocketService:Init()
    -- Load Assets (Make sure you moved Swoosh/Boom to ReplicatedStorage/RocketAssets)
    local assets = ReplicatedStorage.Shared.Assets:WaitForChild("RocketAssets")
    local swooshSound = assets:WaitForChild("Swoosh")
    local boomSound = assets:WaitForChild("Boom")
    
    -- Build Template (Your Original Setup)
    rocketTemplate = Instance.new('Part')
    rocketTemplate.Name = 'Rocket'
    rocketTemplate.FormFactor = Enum.FormFactor.Custom
    rocketTemplate.Size = Config.ROCKET_PART_SIZE
    rocketTemplate.CanCollide = false
    rocketTemplate.TopSurface = Enum.SurfaceType.Smooth
    rocketTemplate.BottomSurface = Enum.SurfaceType.Smooth

    local fire = Instance.new('Fire', rocketTemplate)
    fire.Heat = 5
    fire.Size = 2

    local bodyForce = Instance.new('BodyForce', rocketTemplate)
    bodyForce.Name = 'Antigravity'
    bodyForce.Force = Vector3.new(0, rocketTemplate:GetMass() * Config.GRAVITY_ACCEL, 0)

    local swooshClone = swooshSound:Clone()
    swooshClone.Parent = rocketTemplate
    local boomClone = boomSound:Clone()
    boomClone.PlayOnRemove = true
    boomClone.Parent = rocketTemplate

    -- Remote Listener
    local remote = ReplicatedStorage.Shared.Remotes:WaitForChild("FireRocket")
    remote.OnServerEvent:Connect(function(player, targetPos)
        self:OnFire(player, targetPos)
    end)
end

function RocketService:OnFire(player, targetPos)
    local myModel = player.Character
    if not myModel or not myModel:FindFirstChild("Head") then return end
    
    -- Cooldown
    local lastShot = cooldowns[player] or 0
    if os.clock() - lastShot < Config.RELOAD_TIME then return end
    cooldowns[player] = os.clock()

    -- Spawn Rocket
    local rocketClone = rocketTemplate:Clone()
    rocketClone.BrickColor = player.TeamColor
    
    Debris:AddItem(rocketClone, 30)

    -- Your Original Creator Tag Logic (Kept just in case you use it for other things)
    local creatorTag = Instance.new('ObjectValue', rocketClone)
    creatorTag.Value = player
    creatorTag.Name = 'creator'
    
    -- Physics Setup
    local origin = myModel.Head.CFrame.Position
    local desVec = CFrame.new(origin, targetPos).LookVector
    
    rocketClone.CFrame = CFrame.new(origin, targetPos) + desVec * 2
    rocketClone.Velocity = rocketClone.CFrame.LookVector * Config.ROCKET_SPEED
    
    rocketClone.Parent = workspace
    rocketClone:SetNetworkOwner(player)
    
    -- Simple Explosion Logic (No Damage Loop)
    local connection
    connection = rocketClone.Touched:Connect(function(hit)
        if hit:IsDescendantOf(myModel) then return end
        if hit.Name == "Rocket" then return end
        
        connection:Disconnect()
        self:Explode(rocketClone)
    end)
end

function RocketService:Explode(rocket)
    local position = rocket.Position
    
    -- Visual Explosion Only
    local explosion = Instance.new("Explosion")
    local offset = rocket.Size.Z / 2
    explosion.Position = rocket.Position + (rocket.CFrame.LookVector * offset)
    explosion.BlastRadius = Config.BLAST_RADIUS
    
    -- SAFE SETTINGS: Ensure this does NO damage and applies NO force
    explosion.BlastPressure = 0 
    explosion.DestroyJointRadiusPercent = 0 
    
    explosion.Parent = workspace
    
    -- Destroying the rocket triggers the "Boom" sound because PlayOnRemove is true
    rocket:Destroy()
end

return RocketService