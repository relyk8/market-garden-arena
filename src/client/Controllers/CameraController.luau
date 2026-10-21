local Players = game:GetService("Players")

local CameraController = {}

-- state
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character: Model? = nil

-- config
local DEAD_DISTANCE = 10

local function setFirstPerson()
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	if character then
		camera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
	end
end

local function setDeathCam()
	print("📷 CameraController: Switching to Death Cam")

	-- 1. unlock mouse
	player.CameraMode = Enum.CameraMode.Classic

	-- 2. force zoom out
	player.CameraMinZoomDistance = DEAD_DISTANCE
	player.CameraMaxZoomDistance = DEAD_DISTANCE

	-- 3. focus on head (so camera doesn't stare at the floor)
	local head = character and character:FindFirstChild("Head")
	if head then
		camera.CameraSubject = head
	end
end

local function onCharacterAdded(newChar: Model)
	character = newChar
	local humanoid = newChar:WaitForChild("Humanoid") :: Humanoid

	-- 1. set alive mode (first person locked)
	setFirstPerson()

	-- 2. listen for death via HealthChanged, since Humanoid.Died doesn't fire with the state machine off
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
