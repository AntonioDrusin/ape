extends CharacterBody2D

signal water_level_changed(value: float)

@export var thrust: float = 900.0
@export var gravity: float = 260.0
@export var max_speed: float = 420.0
@export var air_drag: float = 3.5
@export var water_fill_time: float = 4.0
@export var water_rest_height: float = 7.0
@export var water_drain_time: float = 2.0

@onready var wings: Node2D = $Visual/Wings
@onready var visual: Node2D = $Visual
@onready var proboscis: Node2D = $Visual/Proboscis
@onready var water_drip: CPUParticles2D = $Visual/Proboscis/WaterDrip
@onready var water_sensor: Area2D = $WaterSensor

const FACING_TURN_SPEED := 12.0
const INPUT_DEADZONE := 0.1

var water_level: float = 0.0
var facing_x: float = 1.0

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
	# the visual so the bug isn't shown flying backwards. The target facing
	# only updates once velocity is decisive, but the interpolation itself
	# always runs so a quick direction tap can't strand the flip mid-turn
	# once velocity decays back under the threshold from air_drag.
	if absf(velocity.x) > 5.0:
		facing_x = signf(velocity.x)
	visual.scale.x = move_toward(visual.scale.x, facing_x, FACING_TURN_SPEED * delta)

	# Water is an Area2D and doesn't block movement like a floor, so resting
	# on its surface is emulated here: once the bug sinks to the surface
	# height while not thrusting upward, pin it there like a landing. If a
	# solid floor already stopped the bug above the water's rest height (e.g.
	# a puddle sitting on a platform ledge), it can never sink to rest_y, so
	# floor contact alone counts as landing on the water too.
	var landed_on_water := false
	if velocity.y >= 0.0:
		for area in water_sensor.get_overlapping_areas():
			if area.is_in_group("water"):
				if is_on_floor():
					landed_on_water = true
				else:
					var rest_y: float = area.get_surface_y() - water_rest_height
					if global_position.y >= rest_y:
						global_position.y = rest_y
						velocity.y = 0.0
						landed_on_water = true
				break

	if wings:
		wings.flapping = input_dir.length() > INPUT_DEADZONE or (not is_on_floor() and not landed_on_water)

	var drinking := landed_on_water and input_dir.length() < INPUT_DEADZONE
	if drinking and water_level < 1.0:
		water_level = minf(water_level + delta / water_fill_time, 1.0)
		water_level_changed.emit(water_level)

	# Hovering over a seedling's HoverZone waters it, same sensor used for
	# water detection since both are just "what's the bug currently over."
	var watering_seedling: Node = null
	if water_level > 0.0:
		for area in water_sensor.get_overlapping_areas():
			if area.is_in_group("seedling"):
				watering_seedling = area.get_parent()
				break
	if watering_seedling:
		watering_seedling.water(delta)
		water_level = maxf(water_level - delta / water_drain_time, 0.0)
		water_level_changed.emit(water_level)

	var watering := watering_seedling != null
	if proboscis:
		proboscis.visible = drinking or watering
	if water_drip:
		water_drip.emitting = watering


func steal_water(amount: float) -> void:
	water_level = maxf(water_level - amount, 0.0)
	water_level_changed.emit(water_level)
