extends Node2D

@export var flap_speed: float = 22.0
@export var idle_flap_speed: float = 8.0
@export var flap_amount: float = 0.7

var flapping: bool = true
var _time: float = 0.0

func _process(delta: float) -> void:
	var speed := flap_speed if flapping else idle_flap_speed
	_time += delta * speed
	rotation = sin(_time) * flap_amount
