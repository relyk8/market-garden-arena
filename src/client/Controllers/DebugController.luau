--!strict
-- Studio-only debug keys for playtesting. never active outside Studio.
--   P: kill the local character (runs the normal death, ragdoll and respawn flow)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.GlobalConfig)

local DebugController = {}

local player = Players.LocalPlayer

local function killSelf(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

function DebugController:Init()
	if not RunService:IsStudio() or not Config.DEBUG_KEYS then
		return
	end

	ContextActionService:BindAction("DebugKillSelf", killSelf, false, Enum.KeyCode.P)
	print("🛠️ DebugController: Active (P = kill self)")
end

return DebugController
