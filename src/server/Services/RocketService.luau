local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local RocketService = {}
local Config = require(ReplicatedStorage.Shared.GlobalConfig)

-- variables
local cooldowns: { [Player]: number } = {}
local rocketTemplate: Part? = nil

local function explode(rocket: BasePart)
	-- visual explosion only
	local explosion = Instance.new("Explosion")
	local offset = rocket.Size.Z / 2
	explosion.Position = rocket.Position + (rocket.CFrame.LookVector * offset)
	explosion.BlastRadius = Config.BLAST_RADIUS

	-- safe settings: ensure this does no damage and applies no force
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0

	explosion.Parent = workspace

	-- destroying the rocket triggers the "Boom" sound because PlayOnRemove is true
	rocket:Destroy()
end

local function onFire(player: Player, targetPos: Vector3)
	local myModel = player.Character
	local head = myModel and myModel:FindFirstChild("Head")
	if not myModel or not head or not head:IsA("BasePart") or not rocketTemplate then
		return
	end

	-- cooldown
	local lastShot = cooldowns[player] or 0
	if os.clock() - lastShot < Config.RELOAD_TIME then
		return
	end
	cooldowns[player] = os.clock()

	-- spawn rocket
	local rocketClone = rocketTemplate:Clone()
	rocketClone.BrickColor = player.TeamColor

	Debris:AddItem(rocketClone, 30)

	-- creator tag: identifies who fired the rocket
	local creatorTag = Instance.new("ObjectValue")
	creatorTag.Value = player
	creatorTag.Name = "creator"
	creatorTag.Parent = rocketClone

	-- physics setup
	local origin = head.CFrame.Position
	local desVec = CFrame.new(origin, targetPos).LookVector

	rocketClone.CFrame = CFrame.new(origin, targetPos) + desVec * 2
	rocketClone.AssemblyLinearVelocity = rocketClone.CFrame.LookVector * Config.ROCKET_SPEED

	rocketClone.Parent = workspace
	rocketClone:SetNetworkOwner(player)

	-- simple explosion logic (no damage loop)
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
	-- load assets (Swoosh and Boom sounds live in ReplicatedStorage.Shared.Assets.RocketAssets)
	local assets = ReplicatedStorage.Shared.Assets:WaitForChild("RocketAssets")
	local swooshSound = assets:WaitForChild("Swoosh")
	local boomSound = assets:WaitForChild("Boom") :: Sound

	-- build template
	local template = Instance.new("Part")
	template.Name = "Rocket"
	template.Size = Config.ROCKET_PART_SIZE
	template.CanCollide = false
	template.TopSurface = Enum.SurfaceType.Smooth
	template.BottomSurface = Enum.SurfaceType.Smooth

	local fire = Instance.new("Fire")
	fire.Heat = 5
	fire.Size = 2
	fire.Parent = template

	-- antigravity: a world-space upward force equal to the rocket's weight, so it flies straight
	local antigravityAttachment = Instance.new("Attachment")
	antigravityAttachment.Name = "AntigravityAttachment"
	antigravityAttachment.Parent = template

	local antigravity = Instance.new("VectorForce")
	antigravity.Name = "Antigravity"
	antigravity.Attachment0 = antigravityAttachment
	antigravity.RelativeTo = Enum.ActuatorRelativeTo.World
	antigravity.ApplyAtCenterOfMass = true
	antigravity.Force = Vector3.new(0, template:GetMass() * Config.GRAVITY_ACCEL, 0)
	antigravity.Parent = template

	local swooshClone = swooshSound:Clone()
	swooshClone.Parent = template
	local boomClone = boomSound:Clone()
	boomClone.PlayOnRemove = true
	boomClone.Parent = template

	rocketTemplate = template

	-- remote listener
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
