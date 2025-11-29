local Config = {}

-- Physics (Client Side)
Config.BLAST_FORCE = 1000        -- Force applied to the jumper
Config.BLAST_RADIUS = 17         -- Radius for the jump check

-- Server Stats
Config.RELOAD_TIME = 0.7
Config.ROCKET_SPEED = 150 
Config.ROCKET_PART_SIZE = Vector3.new(1, 1, 3)
Config.GRAVITY_ACCEL = workspace.Gravity

-- Visuals
Config.ANIMATION_ID = "rbxassetid://121276080744696"

return Config