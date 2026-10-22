local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local RocketController = {}

-- imports
local Config = require(ReplicatedStorage.Shared.GlobalConfig)
local FireRemote = ReplicatedStorage.Shared.Remotes:WaitForChild("FireRocket") :: RemoteEvent
local RocketVMTemplate = ReplicatedStorage.Shared.ViewModels:WaitForChild("RocketVM") :: Model

-- state
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local equipped = false
local equippedTool: Tool? = nil
local isReloading = false
local clickConnection: RBXScriptConnection? = nil

-- ViewModel
local viewModel: Model? = nil
local animationController: AnimationController? = nil
local animator: Animator? = nil
local shootingAnimation = Instance.new("Animation")
shootingAnimation.AnimationId = Config.ANIMATION_ID

local swayCF = CFrame.new()

local function fire()
	if isReloading then
		return
	end

	local myModel = player.Character
	local myHumanoid = myModel and myModel:FindFirstChildOfClass("Humanoid")
	if myHumanoid and myHumanoid.Health <= 0 then
		return
	end

	isReloading = true
	-- unlock firing after reload time
	task.delay(Config.RELOAD_TIME, function()
		isReloading = false
	end)
	local Pos = mouse.Hit.Position

	-- 1. play shooting animation
	if animator then
		local shootAnimationTrack = animator:LoadAnimation(shootingAnimation)
		shootAnimationTrack.Looped = false
		shootAnimationTrack:Play()
	end

	-- 2. tell server
	FireRemote:FireServer(Pos)

	-- 3. rocket jump: predict the explosion locally and apply the blast to our own character
	local head = myModel and myModel:FindFirstChild("Head")
	if not myModel or not head or not head:IsA("BasePart") then
		return
	end

	-- calculate direction
	local startPos = head.CFrame.Position
	local direction = (Pos - startPos).Unit

	-- adjust start position (barrel offset)
	-- start 2 studs forward, matching where RocketService spawns the rocket
	local rocketStartPos = startPos + (direction * 2)

	-- physics formula: time = distance / speed
	local distance = (Pos - rocketStartPos).Magnitude

	local explosionTime = distance / Config.ROCKET_SPEED

	-- wait logic
	task.delay(explosionTime, function()
		local hrp = myModel:FindFirstChild("HumanoidRootPart")
		if not hrp or not hrp:IsA("BasePart") then
			return
		end
		local blastVector = hrp.Position - Pos
		local blastDistance = blastVector.Magnitude
		print("BOOM")
		if blastDistance <= Config.BLAST_RADIUS then
			hrp:ApplyImpulse(blastVector * Config.BLAST_FORCE / blastDistance)
		end
	end)
end

local function equip(tool: Tool)
	equipped = true
	equippedTool = tool
	isReloading = false

	-- ViewModel setup
	local vm = RocketVMTemplate:Clone()
	vm.Parent = camera -- "Camera.RocketVM"
	viewModel = vm

	-- assign a PrimaryPart if the model doesn't have one
	if not vm.PrimaryPart then
		local root = vm:FindFirstChild("Handle") or vm:FindFirstChild("Body") or vm:GetChildren()[1]
		if root and root:IsA("BasePart") then
			vm.PrimaryPart = root
			warn("⚠️ Fixed missing PrimaryPart for RocketVM automatically.")
		else
			error("❌ RocketVM has no parts! Cannot set PrimaryPart.")
		end
	end

	-- load animation stuff
	local controller = Instance.new("AnimationController")
	controller.Parent = vm
	animationController = controller
	local newAnimator = Instance.new("Animator")
	newAnimator.Parent = controller
	animator = newAnimator

	-- bind click
	clickConnection = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			fire()
		end
	end)
end

local function unequip()
	equipped = false
	equippedTool = nil

	-- cleanup
	if animator then
		animator:Destroy()
	end
	if animationController then
		animationController:Destroy()
	end
	if viewModel then
		viewModel:Destroy()
	end

	if clickConnection then
		clickConnection:Disconnect()
	end
end

local function updateViewModel()
	local vm = viewModel

	-- safety check
	local myHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if myHumanoid and myHumanoid.Health <= 0 and vm ~= nil then
		vm:Destroy()
		return
	end

	if equipped == true and vm ~= nil then
		-- hide the real tool for the local player only. Roblox resets
		-- LocalTransparencyModifier every frame, so it's reapplied here in RenderStepped.
		if equippedTool then
			for _, part in pairs(equippedTool:GetDescendants()) do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 1
				end
			end
		end

		-- follow the camera, with sway from mouse movement
		-- PivotTo moves the pivot, which sits at the PrimaryPart's PivotOffset; applying the offset
		-- places the PrimaryPart itself at the target, matching the old SetPrimaryPartCFrame
		local pivotOffset = if vm.PrimaryPart then vm.PrimaryPart.PivotOffset else CFrame.identity
		vm:PivotTo(camera.CFrame * pivotOffset)

		for _, v in pairs(vm:GetChildren()) do
			if v:IsA("BasePart") then
				v.CanCollide = false
			end
		end

		local mouseDelta = UserInputService:GetMouseDelta() / 50

		local swayX = math.clamp(mouseDelta.X, -0.2, 0.2)
		local swayY = math.clamp(mouseDelta.Y, -0.2, 0.2)

		swayCF = swayCF:Lerp(CFrame.new(swayX, swayY, 0), 0.3)
		vm:PivotTo(camera.CFrame * swayCF * pivotOffset)
	end
end

function RocketController:Init()
	-- tool listener
	player.CharacterAdded:Connect(function(character: Model)
		character.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Tool") and child.Name == "RocketLauncher" then
				equip(child)
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child == equippedTool then
				unequip()
			end
		end)
	end)

	-- render loop
	RunService.RenderStepped:Connect(updateViewModel)
end

function RocketController:Equip(tool: Tool)
	equip(tool)
end

function RocketController:Unequip()
	unequip()
end

function RocketController:Fire()
	fire()
end

function RocketController:UpdateViewModel()
	updateViewModel()
end

return RocketController
