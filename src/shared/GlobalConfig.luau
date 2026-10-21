local Config = {}

-- ==========================================
-- 1. PHYSICS SETUP (Server Injection)
-- ==========================================
Config.ROOT_PRIORITY = 127 -- Force physics engine to respect RootPart
Config.BASE_TURN_SPEED = 8 -- How fast the Manager tries to turn (Default 8)
Config.GROUND_OFFSET = 0 -- Hover height (Leg room)
Config.SENSOR_SEARCH_DIST = 4.5 -- Ground detection range (Must be > Offset + LegLength)

-- Air Controller
Config.AIR_MAX_FORCE = 0 -- Must be 0 to allow script-based strafing
Config.AIR_TURN_TORQUE = 2000000 -- Snappy turning in air

-- Ground Controller
Config.GROUND_FRICTION_BASE = 8 -- Starting friction (Slippery)
Config.GROUND_FRICTION_MOVING = 2 -- High friction when walking
Config.GROUND_FRICTION_WEIGHT = 5 -- Override material friction

-- ==========================================
-- 2. GAMEPLAY PHYSICS (Client Logic)
-- ==========================================
Config.AIR_ACCEL = 230 -- Source Air Strafing Acceleration
Config.AIR_MAX_SPEED = 4 -- Source Air Strafing Cap
Config.JUMP_IMPULSE = Vector3.new(0, 300, 0)

Config.BLAST_RADIUS = 10 -- Rocket Jump Radius
Config.BLAST_FORCE = 750 -- Rocket Jump Force

-- ==========================================
-- 3. WEAPON STATS
-- ==========================================
Config.RELOAD_TIME = 0.8
Config.ROCKET_SPEED = 75
Config.ROCKET_PART_SIZE = Vector3.new(1, 1, 3)
Config.GRAVITY_ACCEL = 50
Config.ANIMATION_ID = "rbxassetid://121276080744696"

-- ==========================================
-- 4. DEBUG
-- ==========================================
Config.DEBUG_TELEMETRY = true -- Studio-only movement telemetry ("[tele]" lines in Output)

return Config
