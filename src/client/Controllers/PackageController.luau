local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PackageController = {}

-- State
local character = nil
local animator = nil
local currentAnim = nil

-- The folder where you stored your animations
local AnimFolder = ReplicatedStorage.Shared.Animations:WaitForChild("r6Animations")

local anims = {
	idle = nil,
	walk = nil,
	jump = nil,
	fall = nil
}

function PackageController:Init()
	Players.LocalPlayer.CharacterAdded:Connect(function(char) 
		self:OnCharacterAdded(char) 
	end)
	if Players.LocalPlayer.Character then
		self:OnCharacterAdded(Players.LocalPlayer.Character)
	end
	print("📦 PackageController: Active (Folder Mode)")
end

function PackageController:OnCharacterAdded(newChar)
	character = newChar
	
	-- 1. KILL DEFAULT ANIMATE SCRIPT
	local defaultAnimate = character:WaitForChild("Animate", 5)
	if defaultAnimate then defaultAnimate.Disabled = true end

	-- 2. SETUP ANIMATOR
	local humanoid = character:WaitForChild("Humanoid")
	animator = humanoid:WaitForChild("Animator")

	-- 3. LOAD ANIMATIONS FROM FOLDER
	-- We look for the Animation Object by name, then load it onto the Humanoid
	local function load(name)
		local animObject = AnimFolder:FindFirstChild(name)
		if animObject then
			return animator:LoadAnimation(animObject)
		else
			warn("⚠️ PackageController: Could not find animation '" .. name .. "' in R6Animations folder!")
			return nil
		end
	end

	-- Using the exact names you listed:
	anims.idle = load("Classic Idle")
	anims.walk = load("Classic Walk") -- Using standard "walk", not "walk (delay)"
	anims.jump = load("Classic Jump")
	anims.fall = load("Classic Fall")

	-- 4. SET PRIORITIES
	-- This ensures actions (Jumping) override movement (Walking) which overrides Idle.
	if anims.jump then anims.jump.Priority = Enum.AnimationPriority.Action end
	if anims.fall then anims.fall.Priority = Enum.AnimationPriority.Action end
	if anims.walk then anims.walk.Priority = Enum.AnimationPriority.Movement end
	if anims.idle then anims.idle.Priority = Enum.AnimationPriority.Idle end
end

-- PUBLIC API
function PackageController:Play(animName)
	local track = anims[animName]
	if not track then return end
	
	-- Don't restart if already playing
	if currentAnim == track and track.IsPlaying then return end

	-- Crossfade (0.15s) for smooth transition
	if currentAnim then currentAnim:Stop(0.15) end
	track:Play(0.1)
	currentAnim = track
end

function PackageController:StopAll()
	if currentAnim then currentAnim:Stop(0.1) end
	currentAnim = nil
end

return PackageController