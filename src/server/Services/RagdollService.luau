local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RagdollService = {}
local Config = require(ReplicatedStorage.Shared.GlobalConfig)

-- legacy Motor6D rigs only: limits for the BallSockets created in place of each motor
local LEGACY_CONE_ANGLE = 60
local LEGACY_TWIST_ANGLE = 45

-- the character is an R15 rig with a blocky body that looks like R6, and its animations only move
-- the neck, shoulders and hips. the joints inside each R6 limb stay locked so the corpse moves
-- like an R6 ragdoll instead of bending at the waist, elbows and knees
local R6_RIGID_JOINTS = {
	Waist = true,
	LeftElbow = true,
	RightElbow = true,
	LeftWrist = true,
	RightWrist = true,
	LeftKnee = true,
	RightKnee = true,
	LeftAnkle = true,
	RightAnkle = true,
}

-- keeps two connected limbs from colliding with each other where they overlap at the joint
local function addNoCollision(part0: BasePart, part1: BasePart)
	local noCol = Instance.new("NoCollisionConstraint")
	noCol.Part0 = part0
	noCol.Part1 = part1
	noCol.Parent = part1
end

-- locks two parts together in their current pose
local function addWeld(part0: BasePart, part1: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1
end

local function attachmentPart(attachment: Attachment?): BasePart?
	return attachment and attachment:FindFirstAncestorWhichIsA("BasePart")
end

local function ragdollCharacter(char: Model)
	local hrp = char:FindFirstChild("HumanoidRootPart")

	for _, descendant in char:GetDescendants() do
		if descendant:IsA("AnimationConstraint") then
			-- AvatarJointUpgrade rigs: kinematic AnimationConstraints hold every limb in its animated
			-- pose. disabling them hands the body to the BallSocketConstraints the rig already ships
			-- with, which carry per-joint ragdoll limits
			descendant.Enabled = false
			if R6_RIGID_JOINTS[descendant.Name] then
				local part0 = attachmentPart(descendant.Attachment0)
				local part1 = attachmentPart(descendant.Attachment1)
				if part0 and part1 then
					addWeld(part0, part1)
				end
			end
		elseif descendant:IsA("BallSocketConstraint") then
			if R6_RIGID_JOINTS[(descendant.Name:gsub("BallSocket$", ""))] then
				-- the weld from the matching AnimationConstraint holds this joint
				descendant:Destroy()
				continue
			end

			-- the rig's stock friction is strong enough to hold a dead body standing upright
			descendant.MaxFrictionTorque *= Config.RAGDOLL_JOINT_FRICTION_SCALE

			local part0 = attachmentPart(descendant.Attachment0)
			local part1 = attachmentPart(descendant.Attachment1)
			if part0 and part1 and part0 ~= part1 then
				addNoCollision(part0, part1)
			end
		elseif descendant:IsA("Motor6D") then
			-- legacy rigs: replace each motor with a loose BallSocket on its rig attachments, or a
			-- weld for joints inside an R6 limb
			local part0, part1 = descendant.Part0, descendant.Part1
			local a0 = part0 and part0:FindFirstChild(descendant.Name .. "RigAttachment")
			local a1 = part1 and part1:FindFirstChild(descendant.Name .. "RigAttachment")
			if part0 and part1 and part0 ~= hrp and R6_RIGID_JOINTS[descendant.Name] then
				addWeld(part0, part1)
			elseif part0 and part1 and part0 ~= hrp and a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") then
				local socket = Instance.new("BallSocketConstraint")
				socket.Attachment0 = a0
				socket.Attachment1 = a1
				socket.LimitsEnabled = true
				socket.UpperAngle = LEGACY_CONE_ANGLE
				socket.TwistLimitsEnabled = true
				socket.TwistLowerAngle = -LEGACY_TWIST_ANGLE
				socket.TwistUpperAngle = LEGACY_TWIST_ANGLE
				socket.Parent = part1
				addNoCollision(part0, part1)
			end
			descendant:Destroy()
		end
	end

	-- body parts collide so the ragdoll rests on the floor. accessories stay non-colliding so their
	-- handles don't snag on the body. the rig marks every body part Massless (the root part carries
	-- the mass while alive); without the root part, weightless limbs let the sockets' friction
	-- torque hold them almost rigid, so they get their mass back
	for _, child in char:GetChildren() do
		if child:IsA("BasePart") and child ~= hrp then
			child.CanCollide = true
			child.Massless = false
		end
	end

	-- CollisionPart is the living character's torso collider, welded to the root part. the limbs
	-- collide on their own now, and it would come loose once the root part is gone
	local collisionPart = char:FindFirstChild("CollisionPart")
	if collisionPart then
		collisionPart:Destroy()
	end

	-- the root part has no ragdoll socket and would hang off the body as dead weight. its removal
	-- also tells the owning client the ragdoll is ready (CorpseController). the corpse stays owned
	-- by that client: a server takeover would snap it back to the server's older, lagged position
	if hrp then
		hrp:Destroy()
	end
end

function RagdollService:Init()
	local respawnRemote = ReplicatedStorage.Shared.Remotes:WaitForChild("RespawnSignal")
	respawnRemote.OnServerEvent:Connect(function(player)
		RagdollService:OnRespawnRequest(player)
	end)
	print("💀 RagdollService: Active")
end

function RagdollService:OnRespawnRequest(player: Player)
	local char = player.Character
	if not char then
		return
	end

	local hum = char:FindFirstChildOfClass("Humanoid")

	-- 1. stop everything
	local cm = char:FindFirstChild("ControllerManager")
	if cm then
		cm:Destroy()
	end

	local anim = char:FindFirstChild("Animate")
	if anim then
		anim:Destroy()
	end

	-- 2. remove weapons
	-- equipped tools (in the character)
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") then
			t:Destroy()
		end
	end

	-- unequipped tools (in the backpack)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		backpack:ClearAllChildren()
	end

	-- 3. disable humanoid (PlatformStand prevents the phasing)
	if hum then
		hum.PlatformStand = true
		hum:ChangeState(Enum.HumanoidStateType.Physics) -- force physics state
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- hide name
		hum.Health = 0
	end

	-- 4. ragdoll
	ragdollCharacter(char)

	-- 5. respawn
	task.wait(Players.RespawnTime)
	player:LoadCharacterAsync()
end

return RagdollService
