local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GlobalConfig)

local StrafeController = {}

function StrafeController:Update(hrp, wishDir, dt)
	-- If player isn't pressing keys, don't change trajectory
	if wishDir.Magnitude < 0.001 then return end
	
	local vel = hrp.AssemblyLinearVelocity
	
	-- 1. Project Velocity
	-- "How fast am I already going in the direction I want to go?"
	local currentSpeed = vel:Dot(wishDir)
	
	-- 2. Calculate needed speed
	-- We want to reach AIR_MAX_SPEED.
	local addSpeed = Config.AIR_MAX_SPEED - currentSpeed
	
	-- 3. Clamp acceleration
	-- We can only add 'ACCEL * dt' speed per frame.
	-- If addSpeed is negative (we are over the limit), add 0.
	if addSpeed > 0 then
		local accelSpeed = math.min(addSpeed, Config.AIR_ACCEL * dt)
		
		-- 4. Apply
		hrp.AssemblyLinearVelocity = vel + (wishDir * accelSpeed)
	end
end

return StrafeController