extends Area2D

## A drifting gnat-cloud hazard that steals water and knocks off carried
## pollen from the player on touch.
## Movement is a leash, not free-roaming: targets are picked within
## wander_radius of the spawn position, so enemies placed near different
## platforms in the level stay spread out instead of drifting into one
## cluster.
## Each speck under Visual orbits its own center point at its own radius and
## angular speed (randomized per speck in _ready), so the cloud reads as a
## swarm of individually-moving gnats instead of one rigid spinning cluster.

@export var wander_radius: float = 140.0
@export var speed: float = 55.0
@export var retarget_min: float = 0.8
@export var retarget_max: float = 2.2
@export var steal_amount: float = 0.35
@export var speck_orbit_center_spread: float = 4.0
@export var speck_orbit_radius_min: float = 3.0
@export var speck_orbit_radius_max: float = 7.0
@export var speck_orbit_speed_min: float = 2.0
@export var speck_orbit_speed_max: float = 5.0

@onready var visual: Node2D = $Visual
@onready var steal_sound: AudioStreamPlayer2D = $StealSound

var _home: Vector2
var _target: Vector2
var _retarget_timer: float = 0.0

## Per-speck orbit state, one dictionary per child of Visual, built in
## _ready() so the speck count isn't hardcoded anywhere.
var _specks: Array[Dictionary] = []


func _ready() -> void:
	_home = position
	body_entered.connect(_on_body_entered)
	_pick_new_target()
	for speck: Node2D in visual.get_children():
		var center_offset := Vector2(
			randf_range(-speck_orbit_center_spread, speck_orbit_center_spread),
			randf_range(-speck_orbit_center_spread, speck_orbit_center_spread)
		)
		var radius := randf_range(speck_orbit_radius_min, speck_orbit_radius_max)
		var angular_speed := randf_range(speck_orbit_speed_min, speck_orbit_speed_max)
		if randf() < 0.5:
			angular_speed = -angular_speed
		_specks.append({
			"node": speck,
			"center_offset": center_offset,
			"radius": radius,
			"angular_speed": angular_speed,
			"angle": randf_range(0.0, TAU),
		})


func _process(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or position.distance_to(_target) < 4.0:
		_pick_new_target()
	position = position.move_toward(_target, speed * delta)
	for speck_state: Dictionary in _specks:
		speck_state["angle"] += speck_state["angular_speed"] * delta
		var angle: float = speck_state["angle"]
		var center_offset: Vector2 = speck_state["center_offset"]
		var radius: float = speck_state["radius"]
		var speck: Node2D = speck_state["node"]
		speck.position = center_offset + Vector2(cos(angle), sin(angle)) * radius


func _pick_new_target() -> void:
	var offset := Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
	_target = _home + offset
	_retarget_timer = randf_range(retarget_min, retarget_max)


## The player is a physics body, so this Area2D detects it directly via
## body_entered — no per-tick polling like the Area2D-vs-Area2D detectables.
## Duck-typed on steal_water()/lose_pollen() so the enemy doesn't depend on
## the player class; the player owns clamping its own state and notifying
## the HUD. Seeds are never touched here — losing a seed would be too
## punishing, per REQUIREMENTS.md. One steal_sound play per touch even
## though both effects can fire.
func _on_body_entered(body: Node) -> void:
	var hit := false
	if body.has_method("steal_water"):
		body.steal_water(steal_amount)
		hit = true
	if body.has_method("lose_pollen"):
		body.lose_pollen()
		hit = true
	if hit:
		steal_sound.play()
