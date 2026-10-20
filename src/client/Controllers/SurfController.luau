local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GlobalConfig)

local SurfController = {}

--checks slope angle
-- Returns TRUE if the ground is too steep to walk on (Surf Mode)
function SurfController:IsSurfSlope(normalVector)
	if not normalVector then return false end

	-- Math: Compare Floor Normal against World Up (0,1,0)
	local up = Vector3.yAxis 
	local dot = math.clamp(normalVector:Dot(up), -1, 1)
	local angleRad = math.acos(dot)
	local angleDeg = math.deg(angleRad)
	
	-- If angle is 50 deg and Max is 45 deg, return TRUE (It is a surf ramp)
	return angleDeg > Config.MAX_SLOPE_ANGLE
end

return SurfController