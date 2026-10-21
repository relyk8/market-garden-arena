local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GlobalConfig)

local StrafeController = {}

function StrafeController:Update(hrp: BasePart, wishDir: Vector3, dt: number)
	-- if player isn't pressing keys, don't change trajectory
	if wishDir.Magnitude < 0.001 then
		return
	end

	local vel = hrp.AssemblyLinearVelocity

	-- 1. project velocity
	-- "how fast am i already going in the direction i want to go?"
	local currentSpeed = vel:Dot(wishDir)

	-- 2. calculate needed speed
	-- we want to reach AIR_MAX_SPEED.
	local addSpeed = Config.AIR_MAX_SPEED - currentSpeed

	-- 3. clamp acceleration
	-- we can only add 'accel * dt' speed per frame.
	-- if addSpeed is negative (we are over the limit), add 0.
	if addSpeed > 0 then
		local accelSpeed = math.min(addSpeed, Config.AIR_ACCEL * dt)

		-- 4. apply
		hrp.AssemblyLinearVelocity = vel + (wishDir * accelSpeed)
	end
end

return StrafeController
