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

## Multiplies max_speed while carrying a seed, for a slight "heaviness" cue
## (REQUIREMENTS.md fit-and-finish). Set to 1.0 to disable if it frustrates
## more than it adds.
@export_group("Seed carrying")
@export_range(0.5, 1.0) var seed_carry_speed_multiplier: float = 0.9
