extends CharacterBody2D

signal water_level_changed(value: float)
signal pollen_changed(has_pollen: bool, pollen_type: PlantData.PlantType)
signal seed_changed(has_seed: bool, seed_type: PlantData.PlantType)

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
@onready var pollen_blob: Polygon2D = $Visual/PollenBlob
@onready var pollen_collect_sound: AudioStreamPlayer2D = $Visual/PollenCollectSound
@onready var pollinate_sound: AudioStreamPlayer2D = $Visual/PollinateSound
@onready var pollen_puff_sound: AudioStreamPlayer2D = $Visual/PollenPuffSound
@onready var pollen_puff: CPUParticles2D = $Visual/PollenBlob/PollenPuff
@onready var seed_carry: Polygon2D = $Visual/SeedCarry
@onready var seed_pickup_sound: AudioStreamPlayer2D = $Visual/SeedPickupSound
@onready var seed_pickup_puff: CPUParticles2D = $Visual/SeedCarry/SeedPickupPuff
@onready var goal_checked_sound: AudioStreamPlayer2D = $Visual/GoalCheckedSound
@onready var goal_confetti: Node2D = $Visual/GoalConfetti

const FACING_TURN_SPEED := 12.0
const INPUT_DEADZONE := 0.1

var water_level: float = 0.0
var facing_x: float = 1.0
var has_pollen: bool = false
var pollen_type: PlantData.PlantType = PlantData.PlantType.DAISY
var has_seed: bool = false
var seed_type: PlantData.PlantType = PlantData.PlantType.DAISY

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

	# Hovering over a seedling's HoverZone waters it and drives pollen
	# interactions; overlapping a loose seed or an empty plot drives seed
	# carrying/planting — same sensor used for water detection since all of
	# this is just "what's the bug currently over."
	var hovered_seedling: Node = null
	var hovered_seed: Area2D = null
	var hovered_plot: Area2D = null
	for area in water_sensor.get_overlapping_areas():
		if area.is_in_group("seedling"):
			hovered_seedling = area.get_parent()
		elif area.is_in_group("seed"):
			hovered_seed = area
		elif area.is_in_group("plot"):
			hovered_plot = area

	if hovered_seedling and water_level > 0.0:
		hovered_seedling.water(delta)
		water_level = maxf(water_level - delta / water_drain_time, 0.0)
		water_level_changed.emit(water_level)

	if hovered_seedling:
		_handle_pollen_hover(hovered_seedling)

	# Flying into a loose seed picks it up instantly (no hover-and-wait, unlike
	# watering/pollen) as long as the seed slot is free.
	if hovered_seed and not has_seed:
		_pick_up_seed(hovered_seed)

	# Hovering an empty plot while carrying a seed plants it there.
	if hovered_plot and has_seed and hovered_plot.is_empty:
		hovered_plot.plant(seed_type)
		_set_seed(false, seed_type)

	if Input.is_action_just_pressed("shed_pollen") and has_pollen:
		_set_pollen(false, pollen_type)
		pollen_puff.restart()
		pollen_puff.emitting = true
		pollen_puff_sound.pitch_scale = randf_range(0.9, 1.1)
		pollen_puff_sound.play()

	var watering := hovered_seedling != null and water_level > 0.0
	if proboscis:
		proboscis.visible = drinking or watering
	if water_drip:
		water_drip.emitting = watering


## Hovering a BLOOMED flower with an empty pollen slot collects it; carrying
## a different-colored pollen attempts to pollinate it (fizzle or success);
## carrying the same-colored pollen is a no-op. Self-limiting: once the
## flower leaves BLOOMED, further hovering does nothing more, so no
## debounce is needed (same reasoning the watering poll above relies on).
func _handle_pollen_hover(seedling: Node) -> void:
	if seedling.state != seedling.State.BLOOMED:
		return
	if not PlantData.accepts_pollen(seedling.bloom_type):
		return
	if not has_pollen:
		_set_pollen(true, seedling.collect_pollen())
		pollen_collect_sound.pitch_scale = randf_range(0.9, 1.1)
		pollen_collect_sound.play()
		return
	if pollen_type == seedling.bloom_type:
		return
	match seedling.pollinate(pollen_type):
		seedling.PollinateResult.SUCCESS:
			_set_pollen(false, pollen_type)
			pollinate_sound.pitch_scale = randf_range(0.9, 1.1)
			pollinate_sound.play()
		seedling.PollinateResult.FIZZLE:
			_set_pollen(false, pollen_type)
			pollen_puff.restart()
			pollen_puff.emitting = true
			pollen_puff_sound.pitch_scale = randf_range(0.9, 1.1)
			pollen_puff_sound.play()


func _set_pollen(carrying: bool, type: PlantData.PlantType) -> void:
	if carrying == has_pollen and type == pollen_type:
		return
	has_pollen = carrying
	pollen_type = type
	pollen_blob.visible = has_pollen
	if has_pollen:
		pollen_blob.color = PlantData.pollen_color(pollen_type)
	pollen_changed.emit(has_pollen, pollen_type)


## Picks up a loose seed area: reads its plant_type, frees the seed node
## (it's consumed, unlike a flower that keeps offering pollen), and plays the
## pickup feedback on the player.
func _pick_up_seed(seed_area: Area2D) -> void:
	_set_seed(true, seed_area.plant_type)
	seed_area.queue_free()
	seed_pickup_puff.restart()
	seed_pickup_puff.emitting = true
	seed_pickup_sound.pitch_scale = randf_range(0.9, 1.1)
	seed_pickup_sound.play()


func _set_seed(carrying: bool, type: PlantData.PlantType) -> void:
	if carrying == has_seed and type == seed_type:
		return
	has_seed = carrying
	seed_type = type
	seed_carry.visible = has_seed
	if has_seed:
		seed_carry.color = PlantData.seed_color(seed_type)
	seed_changed.emit(has_seed, seed_type)


## Fired by Main when a goal plant reaches full bloom (Step 6): a big multi-
## colored confetti burst from the bee plus a chime, distinct from the
## smaller single-color puffs used for pollen/seed feedback elsewhere.
func celebrate_goal() -> void:
	for particles: CPUParticles2D in goal_confetti.get_children():
		particles.restart()
		particles.emitting = true
	goal_checked_sound.pitch_scale = randf_range(0.95, 1.05)
	goal_checked_sound.play()


func steal_water(amount: float) -> void:
	water_level = maxf(water_level - amount, 0.0)
	water_level_changed.emit(water_level)
