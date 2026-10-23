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
-- TF2 values convert at 15 hammer units per stud: the soldier runs 240 hu/s and the walk speed is 16 studs/s
Config.HU_PER_STUD = 15
Config.AIR_TICK_INTERVAL = 0.015 -- TF2 tick (66.67 Hz); air acceleration steps at this rate at any frame rate
Config.AIR_ACCEL = 10 * 240 / Config.HU_PER_STUD -- sv_airaccelerate 10 × soldier max speed 240 hu/s = 160 studs/s²
Config.AIR_MAX_SPEED = 30 / Config.HU_PER_STUD -- Source air speed cap 30 hu/s = 2 studs/s
Config.JUMP_IMPULSE = Vector3.new(0, 300, 0)
Config.WALK_SPEED = 16 -- ControllerManager.BaseMoveSpeed while walking

-- landing at more than walk speed bleeds speed with Source's ground friction until walk speed
Config.LANDING_FRICTION = 5.2 -- CS:GO sv_friction 5.2: about 8% of speed per tick (TF2 is 4)
Config.LANDING_STOP_SPEED = 80 / Config.HU_PER_STUD -- CS:GO sv_stopspeed 80 hu/s (TF2 is 100)
-- horizontal speed cropped to this on each jump. TF2 is 1.2 × run speed = 19.2 studs/s
Config.BHOP_MAX_SPEED = math.huge

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
-- ragdoll
-- ==========================================
Config.RAGDOLL_JOINT_FRICTION_SCALE = 0.3 -- multiplies the rig's stock joint friction on death (lower = floppier, 1 = stock)
Config.RAGDOLL_TOPPLE_SPEED = 4 -- studs/s sideways push on death so a standing body tips over
Config.RAGDOLL_TOPPLE_MAX_SPEED = 1 -- only push bodies that die slower than this (studs/s), i.e. standing still

-- ==========================================
-- 4. debug
-- ==========================================
Config.DEBUG_TELEMETRY = true -- Studio-only movement telemetry ("[tele]" lines in Output)
Config.DEBUG_KEYS = true -- Studio-only debug keys (P = kill self)

return Config
