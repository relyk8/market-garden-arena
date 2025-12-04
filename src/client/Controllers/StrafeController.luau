local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.RocketConfig)

local StrafeController = {}

-- THE SOURCE ENGINE ALGORITHM 🧮
-- 1. Project current velocity onto the direction we WANT to go.
-- 2. If we are already going fast in that direction, don't add speed.
-- 3. If we aren't, add speed up to the limit.
function StrafeController:Update(hrp, wishDir, dt)
	-- If no input, don't change trajectory (drag handles the rest)
	if wishDir.Magnitude < 0.001 then return end
	
	local vel = hrp.AssemblyLinearVelocity
	
	-- 1. How fast are we currently going in the wish direction?
	-- (Vector Projection)
	local currentSpeed = vel:Dot(wishDir)
	
	-- 2. How much speed are we allowed to add?
	-- We want to reach AIR_MAX_SPEED.
	local addSpeed = Config.AIR_MAX_SPEED - currentSpeed
	
	-- 3. Clamp acceleration
	-- We can only add 'AIR_ACCEL * dt' speed per frame.
	-- If addSpeed is negative (we are over the limit), add 0.
	if addSpeed > 0 then
		local accelSpeed = math.min(addSpeed, Config.AIR_ACCEL * dt)
		
		-- 4. Apply the new velocity
		hrp.AssemblyLinearVelocity = vel + (wishDir * accelSpeed)
	end
end

return StrafeController