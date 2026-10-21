local Config = {}

-- ==========================================
-- 1. physics setup (server injection)
-- ==========================================
Config.ROOT_PRIORITY = 127 -- force physics engine to respect RootPart
Config.BASE_TURN_SPEED = 8 -- how fast the manager tries to turn (default 8)
Config.GROUND_OFFSET = 0 -- hover height (leg room)
Config.SENSOR_SEARCH_DIST = 4.5 -- ground detection range (must be > offset + LegLength)

-- air controller
Config.AIR_MAX_FORCE = 0 -- must be 0 to allow script-based strafing
Config.AIR_TURN_TORQUE = 2000000 -- snappy turning in air

-- ground controller
Config.GROUND_FRICTION_BASE = 8 -- starting friction (slippery)
Config.GROUND_FRICTION_MOVING = 2 -- high friction when walking
Config.GROUND_FRICTION_WEIGHT = 5 -- override material friction

-- ==========================================
-- 2. gameplay physics (client logic)
-- ==========================================
Config.AIR_ACCEL = 230 -- Source air strafing acceleration
Config.AIR_MAX_SPEED = 4 -- Source air strafing cap
Config.JUMP_IMPULSE = Vector3.new(0, 300, 0)

Config.BLAST_RADIUS = 10 -- rocket jump radius
Config.BLAST_FORCE = 750 -- rocket jump force

-- ==========================================
-- 3. weapon stats
-- ==========================================
Config.RELOAD_TIME = 0.8
Config.ROCKET_SPEED = 75
Config.ROCKET_PART_SIZE = Vector3.new(1, 1, 3)
Config.GRAVITY_ACCEL = 50
Config.ANIMATION_ID = "rbxassetid://121276080744696"

-- ==========================================
-- 4. debug
-- ==========================================
Config.DEBUG_TELEMETRY = true -- Studio-only movement telemetry ("[tele]" lines in Output)

return Config
