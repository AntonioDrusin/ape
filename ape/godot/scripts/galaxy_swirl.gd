extends Node2D

## Purely decorative: slowly spins the galaxy backdrop for a psychedelic
## drifting-swirl feel. No gameplay significance.
@export var rotate_speed: float = 0.04

func _process(delta: float) -> void:
	rotation += rotate_speed * delta
