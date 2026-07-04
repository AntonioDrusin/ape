extends Area2D

## A patrolling hazard that will eventually guard a specific flower against
## point-blank camping (see REQUIREMENTS.md). Step 1 only: deterministic
## circular patrol around guarded_flower, with no aggro/notice/touch
## behavior yet. Unlike enemy.gd's random leash-wander, the orbit is a fixed
## circle so the guard always reads as tied to the flower it protects
## rather than roaming free. The visual stays level (no spin) so the guard
## always reads as horizontal, unlike the gnat cloud's constant spin.

@export var guarded_flower: Node2D
@export var orbit_radius: float = 70.0
@export var orbit_speed: float = 1.2

const FACING_TURN_SPEED := 12.0

@onready var visual: Node2D = $Visual

var _center: Vector2
var _angle: float = 0.0
var _facing_x: float = 1.0


func _ready() -> void:
	_center = guarded_flower.position if guarded_flower else position
	_angle = (position - _center).angle() if position != _center else 0.0


func _process(delta: float) -> void:
	_angle += orbit_speed * delta
	position = _center + Vector2(cos(_angle), sin(_angle)) * orbit_radius

	# Tangential velocity along the circle; its x sign is which way the guard
	# is currently traveling. Mirrors player.gd's facing_x/scale.x flip: only
	# Visual flips (so collision never mirrors), and the flip itself smoothly
	# interpolates rather than snapping, matching the "nothing snaps" rule.
	var velocity_x := -sin(_angle) * orbit_radius * orbit_speed
	if absf(velocity_x) > 0.1:
		_facing_x = signf(velocity_x)
	visual.scale.x = move_toward(visual.scale.x, _facing_x, FACING_TURN_SPEED * delta)
