local Players = game:GetService("Players")

local CameraController = {}

-- State
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character: Model? = nil

-- Config
local DEAD_DISTANCE = 10

local function setFirstPerson()
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	if character then
		camera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
	end
end

local function setDeathCam()
	print("📷 CameraController: Switching to Death Cam")

	-- 1. Unlock Mouse
	player.CameraMode = Enum.CameraMode.Classic

	-- 2. Force Zoom Out
	player.CameraMinZoomDistance = DEAD_DISTANCE
	player.CameraMaxZoomDistance = DEAD_DISTANCE

	-- 3. Focus on Head (So camera doesn't stare at the floor)
	local head = character and character:FindFirstChild("Head")
	if head then
		camera.CameraSubject = head
	end
end

local function onCharacterAdded(newChar: Model)
	character = newChar
	local humanoid = newChar:WaitForChild("Humanoid") :: Humanoid

	-- 1. SET ALIVE MODE (First Person Locked)
	setFirstPerson()

	-- 2. LISTEN FOR DEATH (The Fix: Use HealthChanged)
	-- .Died event doesn't fire because state machine is off
	local deathConn: RBXScriptConnection
	deathConn = humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then
			deathConn:Disconnect()
			setDeathCam()
		end
	end)
end

function CameraController:Init()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
	print("📷 CameraController: Active")
end

function CameraController:OnCharacterAdded(newChar: Model)
	onCharacterAdded(newChar)
end

function CameraController:SetFirstPerson()
	setFirstPerson()
end

function CameraController:SetDeathCam()
	setDeathCam()
end

return CameraController
