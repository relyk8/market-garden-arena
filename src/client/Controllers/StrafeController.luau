local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GlobalConfig)

local StrafeController = {}

-- air acceleration steps on a fixed tick like a Source server, so strafe gain doesn't depend on frame rate
local TICK = Config.AIR_TICK_INTERVAL
-- after a long frame hitch, drop the excess ticks instead of applying them all at once
local MAX_TICKS_PER_FRAME = 8

local accumulator = 0

-- Source's AirAccelerate: tops up the speed along wishDir to the air cap, adding at most accel * dt
local function airAccelerate(vel: Vector3, wishDir: Vector3, dt: number): Vector3
	-- how fast the body already moves in the wished direction
	local currentSpeed = vel:Dot(wishDir)
	-- over the cap adds nothing, which is what lets strafing turn speed into more speed
	local addSpeed = Config.AIR_MAX_SPEED - currentSpeed
	if addSpeed <= 0 then
		return vel
	end
	return vel + wishDir * math.min(addSpeed, Config.AIR_ACCEL * dt)
end

function StrafeController:Update(hrp: BasePart, wishDir: Vector3, dt: number)
	accumulator += dt
	local ticks = math.floor(accumulator / TICK)
	accumulator -= ticks * TICK
	ticks = math.min(ticks, MAX_TICKS_PER_FRAME)

	-- no input keeps the trajectory unchanged
	if ticks == 0 or wishDir.Magnitude < 0.001 then
		return
	end

	local vel = hrp.AssemblyLinearVelocity
	for _ = 1, ticks do
		vel = airAccelerate(vel, wishDir, TICK)
	end
	hrp.AssemblyLinearVelocity = vel
end

return StrafeController
