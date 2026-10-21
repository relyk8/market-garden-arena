local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RagdollService = {}

-- R6 CONFIG: Joints that will be welded (Stiff) instead of socketed
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
	-- A. Loop through every object in the character
	for _, descendant in ipairs(char:GetDescendants()) do
		-- Handle Joints
		local part0 = if descendant:IsA("Motor6D") then descendant.Part0 else nil
		local part1 = if descendant:IsA("Motor6D") then descendant.Part1 else nil
		if part0 and part1 then
			local name = descendant.Name

			-- 1. Check if this joint should be Stiff or Floppy
			local isStiff = false
			for _, stiffName in ipairs(STIFF_JOINTS) do
				if name == stiffName then
					isStiff = true
					break
				end
			end

			if isStiff then
				-- R6 LOOK: WeldConstraint (Stiff)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = part0
				weld.Part1 = part1
				weld.Parent = part1
			else
				-- RAGDOLL LOOK: BallSocketConstraint (Floppy)
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

			-- 2. Prevent Spazzing (Basic NoCollision)
			local noCol = Instance.new("NoCollisionConstraint")
			noCol.Part0 = part0
			noCol.Part1 = part1
			noCol.Parent = part1

			-- 3. Delete the Motor
			descendant:Destroy()
		end

		-- Handle Collisions (So you don't fall through the earth)
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.CanCollide = true
		end
	end

	-- B. Destroy RootPart (Fixes floating)
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

	-- 1. STOP EVERYTHING
	local cm = char:FindFirstChild("ControllerManager")
	if cm then
		cm:Destroy()
	end

	local anim = char:FindFirstChild("Animate")
	if anim then
		anim:Destroy()
	end

	-- 2. REMOVE WEAPONS (THE FIX) 🛑
	-- Clean hands (Character)
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") then
			t:Destroy()
		end
	end

	-- Clean inventory (Backpack) <-- THIS FIXES THE BUG
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		backpack:ClearAllChildren()
	end

	-- 3. DISABLE HUMANOID (PlatformStand prevents the phasing)
	if hum then
		hum.PlatformStand = true
		hum:ChangeState(Enum.HumanoidStateType.Physics) -- Force physics state
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- Hide Name
		hum.Health = 0
	end

	-- 4. RAGDOLL
	ragdollCharacter(char)

	-- 5. RESPAWN
	task.wait(Players.RespawnTime)
	player:LoadCharacter()
end

return RagdollService
