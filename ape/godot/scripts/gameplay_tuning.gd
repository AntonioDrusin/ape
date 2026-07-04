extends Resource
class_name GameplayTuning

## Shared tuning knobs for player flight and water mechanics, factored out of
## player.gd so they live in one data file (data/player_tuning.tres) instead
## of the script — tweakable in the Inspector or by hand-editing the .tres,
## with no GDScript edit (and no editor restart) required.

@export_group("Flight")
@export var thrust: float = 900.0
@export var gravity: float = 260.0
@export var max_speed: float = 420.0
@export var air_drag: float = 3.5

@export_group("Water")
@export var water_fill_time: float = 4.0
@export var water_rest_height: float = 7.0
@export var water_drain_time: float = 2.0

## Step 2+: proboscis suck range and shake feedback. Amplitude/speed are raw
## pixels/radians-per-second so tuning is a direct Inspector slider.
@export_group("Proboscis")
@export var water_suck_distance: float = 24.0
@export var proboscis_shake_amplitude: float = 3.6  ## ~30% of Proboscis polygon width (12px, see player.tscn)
@export var proboscis_shake_speed: float = 54.0     ## radians/sec of the shake sine phase

## Step 3: hold-to-spray firing. Placeholder defaults -- unconfirmed by
## playtesting, expect these to change in Step 5's balance pass.
@export var water_per_shot: float = 0.12                ## fraction of a full tank (0..1) drained per droplet fired
@export var droplet_forward_speed: float = 65.0         ## px/s added to the player's own velocity, along facing_x
@export var droplet_gravity: float = 500.0              ## px/s^2 applied to a fired droplet in flight
@export var droplet_fire_interval: float = 0.2          ## seconds between shots while held in fire range (5/sec)
@export var droplet_forward_speed_jitter: float = 7.5   ## +/- px/s randomized onto droplet_forward_speed per shot

## Multiplies max_speed while carrying a seed, for a slight "heaviness" cue
## (REQUIREMENTS.md fit-and-finish). Set to 1.0 to disable if it frustrates
## more than it adds.
@export_group("Seed carrying")
@export_range(0.5, 1.0) var seed_carry_speed_multiplier: float = 0.9
