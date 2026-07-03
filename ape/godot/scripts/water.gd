extends Area2D

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func get_surface_y() -> float:
	var shape: RectangleShape2D = _collision_shape.shape
	return (_collision_shape.global_transform * Vector2(0, -shape.size.y * 0.5)).y
