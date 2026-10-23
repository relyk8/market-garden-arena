--!strict
-- client side of the ragdoll. the dying player's client keeps network ownership of its corpse
-- (a server takeover would snap the body back to the server's lagged position), so impulses on
-- the corpse have to come from here. RagdollService sets up the joints on the server; once that
-- arrives, a body that died standing still gets a topple push, and hard landings bounce.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.GlobalConfig)

local CorpseController = {}

-- how long to wait for the server's ragdoll before giving up on the effects
local RAGDOLL_WAIT_TIMEOUT = 3

local player = Players.LocalPlayer

-- RagdollService destroys the root part as its last step, so its absence means the joints are
-- ready
local function waitForRagdoll(char: Model): boolean
	local start = os.clock()
	while char:FindFirstChild("HumanoidRootPart") do
		if not char.Parent or os.clock() - start > RAGDOLL_WAIT_TIMEOUT then
			return false
		end
		task.wait()
	end
	return char.Parent ~= nil
end

-- a body that dies standing still can balance on its feet; a small random sideways push tips it
-- over. moving bodies already fall on their own
local function topple(torso: BasePart)
	local angle = math.random() * 2 * math.pi
	local push = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.RAGDOLL_TOPPLE_SPEED
	torso:ApplyImpulse(push * torso.AssemblyMass)
end

-- an articulated body soaks up impacts in its joints, so part elasticity alone never makes it
-- rebound. instead, when the torso stops abruptly while falling fast, kick every body part back
-- up with a share of the impact speed. each limb is its own assembly, so each gets its own kick
local function bounce(char: Model, torso: BasePart)
	local bounces = 0
	local lastVy = torso.AssemblyLinearVelocity.Y
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if not torso.Parent or bounces >= Config.RAGDOLL_MAX_BOUNCES then
			connection:Disconnect()
			return
		end
		local vy = torso.AssemblyLinearVelocity.Y
		local impactSpeed = -lastVy
		-- impact: falling fast last frame, and most of that speed gone this frame
		if impactSpeed > Config.RAGDOLL_BOUNCE_MIN_IMPACT and vy > lastVy * 0.3 then
			bounces += 1
			local kick = Vector3.yAxis * impactSpeed * Config.RAGDOLL_BOUNCE
			for _, part in char:GetChildren() do
				if part:IsA("BasePart") then
					part:ApplyImpulse(kick * part.Mass)
				end
			end
		end
		lastVy = vy
	end)
end

local function onDeath(char: Model)
	-- read now: the root part is gone once the ragdoll arrives
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local deathSpeed = if hrp and hrp:IsA("BasePart") then hrp.AssemblyLinearVelocity.Magnitude else 0

	if not waitForRagdoll(char) then
		return
	end
	local torso = char:FindFirstChild("UpperTorso")
	if not torso or not torso:IsA("BasePart") then
		return
	end

	if deathSpeed < Config.RAGDOLL_TOPPLE_MAX_SPEED then
		topple(torso)
	end
	bounce(char, torso)
end

local function onCharacterAdded(char: Model)
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	local deathConnection: RBXScriptConnection
	deathConnection = humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then
			deathConnection:Disconnect()
			task.spawn(onDeath, char)
		end
	end)
end

function CorpseController:Init()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

function CorpseController:OnCharacterAdded(char: Model)
	onCharacterAdded(char)
end

return CorpseController
