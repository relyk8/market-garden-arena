--!strict
-- Studio-only movement telemetry. observes the character after each physics step and
-- prints compact "[tele]" lines to the Output, so a playtest can be reviewed after it ends.
-- read-only: it never writes to the character or the controllers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.GlobalConfig)

local TelemetryController = {}

-- sampling settings (debug only, not gameplay tuning)
local SUMMARY_INTERVAL = 1 -- seconds between summary lines
local IMPULSE_THRESHOLD = 10 -- studs/s change in one step, beyond gravity, to report as an impulse
local LANDING_FOLLOWUP = 0.25 -- seconds after landing to report speed again (shows friction loss)
local IDLE_SPEED = 0.5 -- summary lines are skipped while grounded, still and with no keys held

local KEYS: { { key: Enum.KeyCode, label: string } } = {
	{ key = Enum.KeyCode.W, label = "W" },
	{ key = Enum.KeyCode.A, label = "A" },
	{ key = Enum.KeyCode.S, label = "S" },
	{ key = Enum.KeyCode.D, label = "D" },
	{ key = Enum.KeyCode.Space, label = "_" },
}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local hrp: BasePart? = nil
local cm: ControllerManager? = nil
local groundSensor: ControllerPartSensor? = nil
local stepConnection: RBXScriptConnection? = nil

-- per-life state
local startTime = 0
local lastVelocity = Vector3.zero
local lastController = ""
local lastSensed = false
local lastYaw = 0
local landingFollowupAt: number? = nil

-- per-summary accumulators
local windowStart = 0
local windowFrames = 0
local windowSpeedSum = 0
local windowSpeedMax = 0
local windowYawSum = 0
local windowSensorFlips = 0

local function horizontal(v: Vector3): number
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function heldKeys(): string
	local held = ""
	for _, entry in KEYS do
		if UserInputService:IsKeyDown(entry.key) then
			held ..= entry.label
		end
	end
	return held == "" and "-" or held
end

local function slopeDegrees(sensor: ControllerPartSensor): number
	if not sensor.SensedPart then
		return 0
	end
	local dot = math.clamp(sensor.HitNormal:Dot(Vector3.yAxis), -1, 1)
	return math.deg(math.acos(dot))
end

local function cameraYaw(): number
	local look = camera.CFrame.LookVector
	return math.deg(math.atan2(-look.X, -look.Z))
end

local function controllerName(manager: ControllerManager): string
	local active = manager.ActiveController
	return if active then active.Name else "none"
end

local function emit(event: string, fields: string)
	print(string.format("[tele] t=%.2f %s %s", os.clock() - startTime, event, fields))
end

local function resetWindow(now: number)
	windowStart = now
	windowFrames = 0
	windowSpeedSum = 0
	windowSpeedMax = 0
	windowYawSum = 0
	windowSensorFlips = 0
end

local function step(dt: number)
	local root, manager, sensor = hrp, cm, groundSensor
	if not root or not manager or not sensor then
		return
	end

	local now = os.clock()
	local velocity = root.AssemblyLinearVelocity
	local speed = horizontal(velocity)
	local controller = controllerName(manager)
	local sensed = sensor.SensedPart ~= nil

	-- Impulses: velocity change in one step beyond what gravity explains (jumps, blasts, physics kicks)
	local expected = lastVelocity - Vector3.new(0, workspace.Gravity * dt, 0)
	local delta = velocity - expected
	if delta.Magnitude > IMPULSE_THRESHOLD then
		emit(
			"impulse",
			string.format(
				"dv=(%.1f,%.1f,%.1f) hspd=%.1f->%.1f vy=%.1f->%.1f ctrl=%s",
				delta.X,
				delta.Y,
				delta.Z,
				horizontal(lastVelocity),
				speed,
				lastVelocity.Y,
				velocity.Y,
				controller
			)
		)
	end

	-- controller switches
	if controller ~= lastController then
		local event = if controller == "GroundController"
			then "land"
			elseif controller == "AirController" then "takeoff"
			else "ctrl"
		emit(
			event,
			string.format(
				"%s->%s hspd=%.1f vy=%.1f slope=%.0f keys=%s",
				lastController,
				controller,
				speed,
				velocity.Y,
				slopeDegrees(sensor),
				heldKeys()
			)
		)
		if event == "land" then
			landingFollowupAt = now + LANDING_FOLLOWUP
		end
		lastController = controller
	end

	if landingFollowupAt and now >= landingFollowupAt then
		emit("land+" .. LANDING_FOLLOWUP, string.format("hspd=%.1f ctrl=%s", speed, controller))
		landingFollowupAt = nil
	end

	-- ground sensor gaining or losing the floor
	if sensed ~= lastSensed then
		windowSensorFlips += 1
		lastSensed = sensed
	end

	-- summary window
	local yaw = cameraYaw()
	local yawDelta = (yaw - lastYaw + 180) % 360 - 180
	lastYaw = yaw

	windowFrames += 1
	windowSpeedSum += speed
	windowSpeedMax = math.max(windowSpeedMax, speed)
	windowYawSum += math.abs(yawDelta) -- total turning, so left-right sweeps don't cancel out

	local elapsed = now - windowStart
	local keys = heldKeys()
	local idle = windowSpeedMax < IDLE_SPEED and sensed and windowSensorFlips == 0 and keys == "-"
	if elapsed >= SUMMARY_INTERVAL and idle then
		resetWindow(now)
	elseif elapsed >= SUMMARY_INTERVAL then
		emit(
			"sec",
			string.format(
				"hspd avg=%.1f max=%.1f vy=%.1f ctrl=%s sensed=%s slope=%.0f flips=%d turn=%.0fdeg/s keys=%s",
				windowSpeedSum / windowFrames,
				windowSpeedMax,
				velocity.Y,
				controller,
				if sensed then "y" else "n",
				slopeDegrees(sensor),
				windowSensorFlips,
				windowYawSum / elapsed,
				keys
			)
		)
		resetWindow(now)
	end

	lastVelocity = velocity
end

local function cleanup()
	if stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
	hrp, cm, groundSensor = nil, nil, nil
end

local function onCharacterAdded(char: Model)
	cleanup()

	local root = char:WaitForChild("HumanoidRootPart") :: BasePart
	local manager = char:WaitForChild("ControllerManager", 10)
	if not manager or not manager:IsA("ControllerManager") then
		warn("[tele] ControllerManager not found, telemetry off for this life")
		return
	end
	local sensor = root:WaitForChild("GroundSensor") :: ControllerPartSensor

	hrp, cm, groundSensor = root, manager, sensor

	local now = os.clock()
	startTime = now
	lastVelocity = root.AssemblyLinearVelocity
	lastController = controllerName(manager)
	lastSensed = sensor.SensedPart ~= nil
	lastYaw = cameraYaw()
	landingFollowupAt = nil
	resetWindow(now)

	emit("spawn", string.format("mass=%.2f gravity=%.1f", root.AssemblyMass, workspace.Gravity))

	stepConnection = RunService.Heartbeat:Connect(step)
end

function TelemetryController:Init()
	if not RunService:IsStudio() or not Config.DEBUG_TELEMETRY then
		return
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(cleanup)

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	print("📈 TelemetryController: Active")
end

function TelemetryController:OnCharacterAdded(char: Model)
	onCharacterAdded(char)
end

function TelemetryController:Cleanup()
	cleanup()
end

return TelemetryController
