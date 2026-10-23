local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GlobalConfig)

local BhopController = {}

-- the landing bleed steps on the same fixed tick as air acceleration
local TICK = Config.AIR_TICK_INTERVAL
local MAX_TICKS_PER_FRAME = 8

-- true from a landing faster than walk speed until the bleed reaches walk speed or the player leaves the ground
local bleeding = false
local accumulator = 0

-- Source's Friction: below stop speed, the drop is computed as if moving at stop speed, so slow bodies still stop
local function sourceFriction(speed: number, dt: number): number
	local control = math.max(speed, Config.LANDING_STOP_SPEED)
	return math.max(speed - control * Config.LANDING_FRICTION * dt, 0)
end

local function stopBleed(manager: ControllerManager)
	bleeding = false
	manager.BaseMoveSpeed = Config.WALK_SPEED
end

-- called on the frame the GroundController takes over. no tick runs on this frame, so a jump pressed
-- before the next frame keeps all of the landing speed, like a jump on Source's first ground tick
function BhopController:OnLand(root: BasePart)
	local v = root.AssemblyLinearVelocity
	bleeding = Vector3.new(v.X, 0, v.Z).Magnitude > Config.WALK_SPEED
	accumulator = 0
end

-- runs every frame while grounded. during the bleed, the GroundController is pointed at the bled velocity,
-- since with zero AccelerationTime it would otherwise snap to walk speed in one frame
function BhopController:UpdateGround(manager: ControllerManager, root: BasePart, dt: number)
	if not bleeding then
		return
	end

	accumulator += dt
	local ticks = math.floor(accumulator / TICK)
	accumulator -= ticks * TICK
	ticks = math.min(ticks, MAX_TICKS_PER_FRAME)

	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	for _ = 1, ticks do
		speed = sourceFriction(speed, TICK)
	end

	if speed <= Config.WALK_SPEED then
		stopBleed(manager)
		return
	end

	local dir = flat.Unit
	manager.MovingDirection = dir
	manager.BaseMoveSpeed = speed
	root.AssemblyLinearVelocity = dir * speed + Vector3.new(0, v.Y, 0)
end

-- called right before the jump impulse: ends the bleed and crops the horizontal speed to the bhop cap
function BhopController:OnJump(manager: ControllerManager, root: BasePart)
	stopBleed(manager)

	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	if speed > Config.BHOP_MAX_SPEED then
		flat *= Config.BHOP_MAX_SPEED / speed
		root.AssemblyLinearVelocity = flat + Vector3.new(0, v.Y, 0)
	end
end

-- leaving the ground any way other than a jump (walking off a ledge, death) ends the bleed
function BhopController:Stop(manager: ControllerManager)
	if bleeding then
		stopBleed(manager)
	end
end

return BhopController
