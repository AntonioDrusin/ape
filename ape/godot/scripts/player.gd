extends CharacterBody2D

signal water_level_changed(value: float)
signal pollen_changed(has_pollen: bool, pollen_type: PlantData.PlantType)
signal seed_changed(has_seed: bool, seed_type: PlantData.PlantType)
signal water_fired(position: Vector2, velocity: Vector2)

## Flight/water knobs live in data/player_tuning.tres (see GameplayTuning) so
## they're editable as data — swap in a different .tres for a different feel
## without touching this script.
@export var tuning: GameplayTuning = preload("res://data/player_tuning.tres")

@onready var wings: Node2D = $Visual/Wings
@onready var visual: Node2D = $Visual
@onready var proboscis: Node2D = $Visual/Proboscis
@onready var water_sensor: Area2D = $WaterSensor
@onready var proboscis_sensor: Area2D = $Visual/Proboscis/ProboscisSensor
@onready var pollen_blob: Polygon2D = $Visual/PollenBlob
@onready var pollen_collect_sound: AudioStreamPlayer2D = $Visual/PollenCollectSound
@onready var pollinate_sound: AudioStreamPlayer2D = $Visual/PollinateSound
@onready var pollen_puff_sound: AudioStreamPlayer2D = $Visual/PollenPuffSound
@onready var pollen_puff: CPUParticles2D = $Visual/PollenBlob/PollenPuff
@onready var seed_carry: Polygon2D = $Visual/SeedCarry
@onready var seed_pickup_sound: AudioStreamPlayer2D = $Visual/SeedPickupSound
@onready var seed_pickup_puff: CPUParticles2D = $Visual/SeedCarry/SeedPickupPuff
@onready var drink_sound: AudioStreamPlayer2D = $Visual/DrinkSound
@onready var goal_checked_sound: AudioStreamPlayer2D = $Visual/GoalCheckedSound
@onready var goal_confetti: Node2D = $Visual/GoalConfetti
## Reuses water_pour.wav as a placeholder launch sound (no dedicated "fire"
## clip exists yet) -- Step 5 plans a distinct one-shot for this.
@onready var fire_sound: AudioStreamPlayer2D = $Visual/FireSound

const FACING_TURN_SPEED := 12.0
const INPUT_DEADZONE := 0.1
const SFX_LOOP_VOLUME_DB := -1.0
const SFX_FADE_SPEED := 6.0
const CARRY_POP_DURATION := 0.18
const FIRE_POSE_SCALE := 1.35
const FIRE_POSE_DURATION := 0.12

var water_level: float = 0.0
var facing_x: float = 1.0
var has_pollen: bool = false
var pollen_type: PlantData.PlantType = PlantData.PlantType.DAISY
var has_seed: bool = false
var seed_type: PlantData.PlantType = PlantData.PlantType.DAISY
var _drink_volume: float = 0.0
var _proboscis_shake_phase: float = 0.0
var _fire_cooldown: float = 0.0
var _fire_pose_tween: Tween

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	velocity += input_dir * tuning.thrust * delta
	velocity.y += tuning.gravity * delta
	# Proportional drag (not a fixed friction constant) gives the floaty,
	# bug-like feel rather than instant stop/start.
	velocity -= velocity * tuning.air_drag * delta
	# Carrying a seed adds a slight heaviness (REQUIREMENTS.md fit-and-finish);
	# tune seed_carry_speed_multiplier to 1.0 in player_tuning.tres to cut it.
	var speed_limit := tuning.max_speed * (tuning.seed_carry_speed_multiplier if has_seed else 1.0)
	velocity = velocity.limit_length(speed_limit)

	move_and_slide()

	# Turn to face the direction of horizontal movement, smoothly flipping
	# the visual so the bug isn't shown flying backwards. Only Visual flips:
	# CollisionShape2D and Camera2D are siblings of Visual in player.tscn
	# precisely so this never affects physics or the view. The target facing
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
					var rest_y: float = area.get_surface_y() - tuning.water_rest_height
					if global_position.y >= rest_y:
						global_position.y = rest_y
						velocity.y = 0.0
						landed_on_water = true
				break

	if wings:
		wings.flapping = input_dir.length() > INPUT_DEADZONE or (not is_on_floor() and not landed_on_water)

	# Hovering over a seedling's HoverZone waters it and drives pollen
	# interactions; overlapping a loose seed or an empty plot drives seed
	# carrying/planting — same body-centered sensor, all "what's the bug over."
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

	# Sucking: automatic on proximity alone -- no button needed. Its tip
	# (ProboscisSensor, not the player's body) has to be close enough to a
	# water surface for the reach to land, so you still have to aim the
	# proboscis at the water, not just fly generally near it. Independent of
	# landed_on_water above (that's for physical resting only). Range
	# detection works whether or not the proboscis is currently visible,
	# since ProboscisSensor's Area2D collision doesn't depend on the
	# Polygon2D's visible flag -- so this can gate the auto-extend below.
	var water_surface_y: float = -INF
	for area in proboscis_sensor.get_overlapping_areas():
		if area.is_in_group("water"):
			water_surface_y = area.get_surface_y()
			break
	var holding_proboscis := Input.is_action_pressed("use_proboscis")
	var in_suck_range := water_surface_y > -INF \
		and (water_surface_y - proboscis_sensor.global_position.y) <= tuning.water_suck_distance
	var sucking := in_suck_range
	if sucking and water_level < 1.0:
		water_level = minf(water_level + delta / tuning.water_fill_time, 1.0)
		water_level_changed.emit(water_level)

	# Firing: hold-to-spray, gated purely on the same proximity check as
	# sucking above (near water -> sucks; away from it -> fires; no separate
	# mode-switch input). Resetting the cooldown to 0 whenever the gate is
	# false means the first eligible frame -- a fresh press, or drifting out
	# of suck range mid-hold -- always fires immediately, then repeats every
	# tuning.droplet_fire_interval for as long as the button/conditions hold.
	var can_fire := holding_proboscis and not in_suck_range and water_level > 0.0
	if can_fire:
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_fire_droplet()
			_fire_cooldown = tuning.droplet_fire_interval
	else:
		_fire_cooldown = 0.0

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
		_play_pollen_puff()

	if proboscis:
		proboscis.visible = sucking or holding_proboscis
		if not holding_proboscis and _fire_pose_tween:
			_fire_pose_tween.kill()
			proboscis.scale = Vector2.ONE
		if sucking:
			_proboscis_shake_phase += tuning.proboscis_shake_speed * delta
			proboscis.position.x = sin(_proboscis_shake_phase) * tuning.proboscis_shake_amplitude
		else:
			_proboscis_shake_phase = 0.0
			proboscis.position.x = 0.0

	_drink_volume = _update_loop_sound(drink_sound, sucking, _drink_volume, delta)


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
			_play_pollen_puff()


func _set_pollen(carrying: bool, type: PlantData.PlantType) -> void:
	if carrying == has_pollen and type == pollen_type:
		return
	has_pollen = carrying
	pollen_type = type
	pollen_blob.visible = has_pollen
	if has_pollen:
		pollen_blob.color = PlantData.pollen_color(pollen_type)
		_play_carry_pop(pollen_blob)
	pollen_changed.emit(has_pollen, pollen_type)


## Plays the small "pollen lost" puff + sound, shared by shedding, a fizzled
## pollination attempt, and an enemy knocking pollen off on touch.
func _play_pollen_puff() -> void:
	pollen_puff.restart()
	pollen_puff.emitting = true
	pollen_puff_sound.pitch_scale = randf_range(0.9, 1.1)
	pollen_puff_sound.play()


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
		_play_carry_pop(seed_carry)
	seed_changed.emit(has_seed, seed_type)


## Scale-pops a carry indicator in from zero, shared by pollen pickup and seed
## pickup so both cues appear with the same brief "nothing snaps" beat rather
## than an instant visibility flip.
func _play_carry_pop(node: Node2D) -> void:
	node.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, CARRY_POP_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fires one water droplet from the proboscis tip: emits water_fired for Main
## to spawn (pattern 1 -- the player never instantiates world scenes itself),
## drains a fixed cost regardless of the jittered velocity, and plays the fire
## pose + a pitch-varied launch sound. Called repeatedly while holding the
## button in fire range (see the cooldown loop in _physics_process), so the
## per-shot jitter on droplet_forward_speed is what keeps a sustained press
## from reading as identical repeated shots.
func _fire_droplet() -> void:
	var jitter := randf_range(-tuning.droplet_forward_speed_jitter, tuning.droplet_forward_speed_jitter)
	var fire_velocity := velocity + Vector2(facing_x * (tuning.droplet_forward_speed + jitter), 0.0)
	water_fired.emit(proboscis_sensor.global_position, fire_velocity)
	water_level = maxf(water_level - tuning.water_per_shot, 0.0)
	water_level_changed.emit(water_level)
	_play_fire_pose()
	fire_sound.pitch_scale = randf_range(0.9, 1.1)
	fire_sound.play()


## Brief proboscis "fire" pose: grows then settles back to normal size for the
## pulse duration. Uniform scale is a first-pass approximation (REQUIREMENTS.md
## Step 5 may refine it to a bottom-anchored tip flare if this doesn't read
## well). Kills any in-flight tween first since hold-to-spray can re-trigger
## this faster than one grow+settle cycle completes at tuned intervals.
func _play_fire_pose() -> void:
	if _fire_pose_tween:
		_fire_pose_tween.kill()
	proboscis.scale = Vector2.ONE
	_fire_pose_tween = create_tween()
	_fire_pose_tween.tween_property(proboscis, "scale", Vector2.ONE * FIRE_POSE_SCALE, FIRE_POSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fire_pose_tween.tween_property(proboscis, "scale", Vector2.ONE, FIRE_POSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


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


## Called by an enemy on touch (duck-typed, mirrors steal_water()): knocks
## the carried pollen off. No-op if not carrying any, since the enemy calls
## this unconditionally on every touch.
func lose_pollen() -> void:
	if not has_pollen:
		return
	_set_pollen(false, pollen_type)
	_play_pollen_puff()


## Fades a looping woosh's volume toward on/off rather than hard-cutting it,
## since starting/stopping an AudioStreamPlayer2D mid-waveform clicks. Starts
## the stream once the fade-in begins and stops it once faded fully out so it
## isn't silently spinning in the background while inactive.
func _update_loop_sound(sound: AudioStreamPlayer2D, active: bool, volume: float, delta: float) -> float:
	volume = move_toward(volume, 1.0 if active else 0.0, SFX_FADE_SPEED * delta)
	if volume > 0.0 and not sound.playing:
		sound.play()
	sound.volume_db = SFX_LOOP_VOLUME_DB + linear_to_db(maxf(volume, 0.001))
	if volume <= 0.0 and sound.playing:
		sound.stop()
	return volume
