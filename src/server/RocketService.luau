-- ServerScriptService/Services/RocketService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local RocketService = {}
local Config = require(ReplicatedStorage.Shared.RocketConfig)
local FireRemote = ReplicatedStorage.Remotes.FireRocket

-- Cooldown tracking
local cooldowns = {}

function RocketService:Init()
    FireRemote.OnServerEvent:Connect(function(player, targetPos)
        self:OnFire(player, targetPos)
    end)
end

function RocketService:OnFire(player, targetPos)
    -- 1. Security & Cooldown Check
    local lastFire = cooldowns[player] or 0
    if os.clock() - lastFire < Config.RELOAD_TIME then return end
    cooldowns[player] = os.clock()

    local char = player.Character
    if not char then return end
    local root = char.HumanoidRootPart
    
    -- 2. Create Projectile
    local rocket = Instance.new("Part")
    rocket.Size = Vector3.new(1, 1, 3)
    rocket.BrickColor = player.TeamColor
    rocket.CanCollide = false
    rocket.Name = "Projectile"
    
    -- Anti-Gravity (Modern method: VectorForce)
    local attachment = Instance.new("Attachment", rocket)
    local force = Instance.new("VectorForce", rocket)
    force.Attachment0 = attachment
    force.Force = Vector3.new(0, rocket:GetMass() * workspace.Gravity, 0)
    force.RelativeTo = Enum.ActuatorRelativeTo.World
    
    -- Position & Velocity
    local origin = char.Head.Position
    local direction = (targetPos - origin).Unit
    
    rocket.CFrame = CFrame.new(origin, targetPos) + (direction * 4) -- Spawn slightly in front
    rocket.AssemblyLinearVelocity = direction * Config.ROCKET_SPEED
    rocket.Parent = workspace
    
    -- Set Network Owner so the firing player sees it fly smoothly
    rocket:SetNetworkOwner(player)
    
    -- 3. Explosion Logic (Touched event handles impact)
    local exploded = false
    rocket.Touched:Connect(function(hit)
        if exploded then return end
        if hit:IsDescendantOf(char) then return end -- Don't explode on shooter instantly
        
        exploded = true
        self:Explode(rocket.Position, player)
        rocket:Destroy()
    end)
    
    -- Cleanup if it never hits anything
    Debris:AddItem(rocket, 10)
end

function RocketService:Explode(position, attacker)
    -- Visuals
    local explosion = Instance.new("Explosion")
    explosion.Position = position
    explosion.BlastRadius = 0 -- We handle damage manually
    explosion.Parent = workspace
    
    -- Damage Logic
    local origin = position
    local radius = Config.BLAST_RADIUS
    
    -- SphereCast or GetPartBoundsInRadius could work here, 
    -- but looping players is cheaper for small servers.
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = player.Character.HumanoidRootPart
            local dist = (targetRoot.Position - origin).Magnitude
            
            if dist <= radius then
                -- Calculate Damage falloff based on distance
                -- (Closer = More damage)
                local damage = 100 * (1 - (dist / radius))
                player.Character.Humanoid:TakeDamage(damage)
            end
        end
    end
end

return RocketService