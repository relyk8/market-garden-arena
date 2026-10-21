local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RagdollService = {}

-- R6 config: joints that will be welded (stiff) instead of socketed
local STIFF_JOINTS = {
	"RightElbow",
	"RightWrist",
	"LeftElbow",
	"LeftWrist",
	"RightKnee",
	"RightAnkle",
	"LeftKnee",
	"LeftAnkle",
}

local function ragdollCharacter(char: Model)
	-- a. loop through every object in the character
	for _, descendant in ipairs(char:GetDescendants()) do
		-- handle joints
		local part0 = if descendant:IsA("Motor6D") then descendant.Part0 else nil
		local part1 = if descendant:IsA("Motor6D") then descendant.Part1 else nil
		if part0 and part1 then
			local name = descendant.Name

			-- 1. check if this joint should be stiff or floppy
			local isStiff = false
			for _, stiffName in ipairs(STIFF_JOINTS) do
				if name == stiffName then
					isStiff = true
					break
				end
			end

			if isStiff then
				-- R6 look: WeldConstraint (stiff)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = part0
				weld.Part1 = part1
				weld.Parent = part1
			else
				-- ragdoll look: BallSocketConstraint (floppy)
				local a0 = part0:FindFirstChild(name .. "RigAttachment")
					or part0:FindFirstChild(name .. "RigAttachment", true)
				local a1 = part1:FindFirstChild(name .. "RigAttachment")
					or part1:FindFirstChild(name .. "RigAttachment", true)

				if a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") then
					local socket = Instance.new("BallSocketConstraint")
					socket.Attachment0 = a0
					socket.Attachment1 = a1
					socket.LimitsEnabled = true
					socket.TwistLimitsEnabled = true
					socket.Parent = part1
				end
			end

			-- 2. prevent spazzing (basic NoCollision)
			local noCol = Instance.new("NoCollisionConstraint")
			noCol.Part0 = part0
			noCol.Part1 = part1
			noCol.Parent = part1

			-- 3. delete the motor
			descendant:Destroy()
		end

		-- enable collisions on limbs so the ragdoll rests on the floor instead of falling through
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.CanCollide = true
		end
	end

	-- b. destroy RootPart (fixes floating)
	local hrp = char:FindFirstChild("HumanoidRootPart")
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
	player:LoadCharacter()
end

return RagdollService
