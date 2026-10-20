local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraController = {}

-- State
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character = nil
local humanoid = nil

-- Config
local DEAD_DISTANCE = 10

function CameraController:Init()
	player.CharacterAdded:Connect(function(char)
		self:OnCharacterAdded(char)
	end)
	if player.Character then
		self:OnCharacterAdded(player.Character)
	end
	print("📷 CameraController: Active")
end

function CameraController:OnCharacterAdded(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")

	-- 1. SET ALIVE MODE (First Person Locked)
	self:SetFirstPerson()

	-- 2. LISTEN FOR DEATH (The Fix: Use HealthChanged)
	-- .Died event doesn't fire because state machine is off
	local deathConn
	deathConn = humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then
			if deathConn then
				deathConn:Disconnect()
			end
			self:SetDeathCam()
		end
	end)
end

function CameraController:SetFirstPerson()
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	if character then
		camera.CameraSubject = character:FindFirstChild("Humanoid")
	end
end

function CameraController:SetDeathCam()
	print("📷 CameraController: Switching to Death Cam")

	-- 1. Unlock Mouse
	player.CameraMode = Enum.CameraMode.Classic

	-- 2. Force Zoom Out
	player.CameraMinZoomDistance = DEAD_DISTANCE
	player.CameraMaxZoomDistance = DEAD_DISTANCE

	-- 3. Focus on Head (So camera doesn't stare at the floor)
	local head = character:FindFirstChild("Head")
	if head then
		camera.CameraSubject = head
	end
end

return CameraController
