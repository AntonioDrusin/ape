extends Area2D

@export var wander_radius: float = 140.0
@export var speed: float = 55.0
@export var retarget_min: float = 0.8
@export var retarget_max: float = 2.2
@export var spin_speed: float = 3.0
@export var steal_amount: float = 0.35

@onready var visual: Node2D = $Visual
@onready var steal_sound: AudioStreamPlayer2D = $StealSound

var _home: Vector2
var _target: Vector2
var _retarget_timer: float = 0.0


func _ready() -> void:
	_home = position
	body_entered.connect(_on_body_entered)
	_pick_new_target()


func _process(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or position.distance_to(_target) < 4.0:
		_pick_new_target()
	position = position.move_toward(_target, speed * delta)
	visual.rotation += spin_speed * delta


func _pick_new_target() -> void:
	var offset := Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
	_target = _home + offset
	_retarget_timer = randf_range(retarget_min, retarget_max)


func _on_body_entered(body: Node) -> void:
	if body.has_method("steal_water"):
		body.steal_water(steal_amount)
		steal_sound.play()
