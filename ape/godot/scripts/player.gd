extends CharacterBody2D

@export var thrust: float = 900.0
@export var gravity: float = 260.0
@export var max_speed: float = 420.0
@export var air_drag: float = 3.5

@onready var wings: Node2D = $Visual/Wings
@onready var visual: Node2D = $Visual

const FACING_TURN_SPEED := 12.0

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	velocity += input_dir * thrust * delta
	velocity.y += gravity * delta
	velocity -= velocity * air_drag * delta
	velocity = velocity.limit_length(max_speed)

	move_and_slide()

	# Turn to face the direction of horizontal movement, smoothly flipping
	# the visual so the bug isn't shown flying backwards.
	if absf(velocity.x) > 5.0:
		var target_scale_x := signf(velocity.x)
		visual.scale.x = move_toward(visual.scale.x, target_scale_x, FACING_TURN_SPEED * delta)

	if wings:
		wings.flapping = input_dir.length() > 0.1 or not is_on_floor()
