local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local RocketService = {}
local Config = require(ReplicatedStorage.Shared.GlobalConfig)

-- Variables
local cooldowns: { [Player]: number } = {}
local rocketTemplate: Part? = nil

local function explode(rocket: BasePart)
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

local function onFire(player: Player, targetPos: Vector3)
	local myModel = player.Character
	local head = myModel and myModel:FindFirstChild("Head")
	if not myModel or not head or not head:IsA("BasePart") or not rocketTemplate then
		return
	end

	-- Cooldown
	local lastShot = cooldowns[player] or 0
	if os.clock() - lastShot < Config.RELOAD_TIME then
		return
	end
	cooldowns[player] = os.clock()

	-- Spawn Rocket
	local rocketClone = rocketTemplate:Clone()
	rocketClone.BrickColor = player.TeamColor

	Debris:AddItem(rocketClone, 30)

	-- Your Original Creator Tag Logic (Kept just in case you use it for other things)
	local creatorTag = Instance.new("ObjectValue")
	creatorTag.Value = player
	creatorTag.Name = "creator"
	creatorTag.Parent = rocketClone

	-- Physics Setup
	local origin = head.CFrame.Position
	local desVec = CFrame.new(origin, targetPos).LookVector

	rocketClone.CFrame = CFrame.new(origin, targetPos) + desVec * 2
	rocketClone.Velocity = rocketClone.CFrame.LookVector * Config.ROCKET_SPEED

	rocketClone.Parent = workspace
	rocketClone:SetNetworkOwner(player)

	-- Simple Explosion Logic (No Damage Loop)
	local connection: RBXScriptConnection
	connection = rocketClone.Touched:Connect(function(hit)
		if hit:IsDescendantOf(myModel) then
			return
		end
		if hit.Name == "Rocket" then
			return
		end

		connection:Disconnect()
		explode(rocketClone)
	end)
end

function RocketService:Init()
	-- Load Assets (Make sure you moved Swoosh/Boom to ReplicatedStorage/RocketAssets)
	local assets = ReplicatedStorage.Shared.Assets:WaitForChild("RocketAssets")
	local swooshSound = assets:WaitForChild("Swoosh")
	local boomSound = assets:WaitForChild("Boom") :: Sound

	-- Build Template (Your Original Setup)
	local template = Instance.new("Part")
	template.Name = "Rocket"
	template.FormFactor = Enum.FormFactor.Custom
	template.Size = Config.ROCKET_PART_SIZE
	template.CanCollide = false
	template.TopSurface = Enum.SurfaceType.Smooth
	template.BottomSurface = Enum.SurfaceType.Smooth

	local fire = Instance.new("Fire")
	fire.Heat = 5
	fire.Size = 2
	fire.Parent = template

	local bodyForce = Instance.new("BodyForce")
	bodyForce.Name = "Antigravity"
	bodyForce.Force = Vector3.new(0, template:GetMass() * Config.GRAVITY_ACCEL, 0)
	bodyForce.Parent = template

	local swooshClone = swooshSound:Clone()
	swooshClone.Parent = template
	local boomClone = boomSound:Clone()
	boomClone.PlayOnRemove = true
	boomClone.Parent = template

	rocketTemplate = template

	-- Remote Listener
	local remote = ReplicatedStorage.Shared.Remotes:WaitForChild("FireRocket") :: RemoteEvent
	remote.OnServerEvent:Connect(onFire)
end

function RocketService:OnFire(player: Player, targetPos: Vector3)
	onFire(player, targetPos)
end

function RocketService:Explode(rocket: BasePart)
	explode(rocket)
end

return RocketService
