extends Area2D

## Passive detectable (group "water" in the .tscn); knows nothing about the
## player. An Area2D doesn't block movement like a floor, so the player polls
## overlapping water and emulates resting on the surface itself — all this
## script provides is where that surface is.

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func get_surface_y() -> float:
	var shape: RectangleShape2D = _collision_shape.shape
	return (_collision_shape.global_transform * Vector2(0, -shape.size.y * 0.5)).y
