extends Area2D

## A drifting gnat-cloud hazard that steals water and knocks off carried
## pollen from the player on touch.
## Movement is a leash, not free-roaming: targets are picked within
## wander_radius of the spawn position, so swarms placed near different
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
@export var speck_orbit_radius_min: float = 7.0
@export var speck_orbit_radius_max: float = 16.0
@export var speck_orbit_speed_min: float = 2.0
@export var speck_orbit_speed_max: float = 6.0

## Tuning for each speck's individual knockout fall (see _fall_speck) --
## separate from the root's own fall in hazard_knockback.gd, which only
## drops the swarm's collision/root position, not the specks.
@export var speck_fall_gravity: float = 300.0
@export var speck_scatter_x_min: float = -10.0
@export var speck_scatter_x_max: float = 10.0
@export var speck_rest_y_min: float = 2.0
@export var speck_rest_y_max: float = 6.0
@export var speck_scatter_speed: float = 30.0
@export var speck_recover_speed: float = 60.0

## One droplet hit is enough to knock a swarm down (see wasp.gd's higher
## threshold -- the swarm is the fragile hazard, the wasp the tanky one).
@export var knockback_hit_threshold: int = 1

@onready var visual: Node2D = $Visual
@onready var steal_sound: AudioStreamPlayer2D = $StealSound
@onready var knockback_sound: AudioStreamPlayer2D = $KnockbackSound
@onready var _knockback: HazardKnockback = $KnockbackCast

var _home: Vector2
var _target: Vector2
var _retarget_timer: float = 0.0
var _hits_taken: int = 0

## Set true when a knockout recovers; forces the swarm to fly straight back
## to _home (ignoring retarget_timer/wander picks) before resuming its normal
## leash-wander, so a knocked-down swarm always re-forms at its original spot
## instead of picking up wandering from wherever it landed.
var _returning_home: bool = false

## Per-speck orbit state, one dictionary per child of Visual, built in
## _ready() so the speck count isn't hardcoded anywhere.
var _specks: Array[Dictionary] = []


func _ready() -> void:
	_home = position
	body_entered.connect(_on_body_entered)
	_knockback.knocked_out.connect(_on_knocked_out)
	_knockback.recovered.connect(_on_knockback_recovered)
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
	if _knockback.active:
		position += _knockback.step(delta)
		visual.position = _knockback.vibrate_offset
		for speck_state: Dictionary in _specks:
			_fall_speck(speck_state, delta)
		for area in get_overlapping_areas():
			if area.is_in_group("water"):
				queue_free()
				return
		return

	if _returning_home:
		if position.distance_to(_home) < 4.0:
			_returning_home = false
			_pick_new_target()
	else:
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
		var orbit_pos := center_offset + Vector2(cos(angle), sin(angle)) * radius
		# Grounded specks (see _fall_speck) ease back up into orbit formation
		# rather than snapping the instant the swarm recovers.
		if speck_state.get("grounded", false):
			speck.position = speck.position.move_toward(orbit_pos, speck_recover_speed * delta)
			if speck.position.distance_to(orbit_pos) < 2.0:
				speck_state["grounded"] = false
		else:
			speck.position = orbit_pos


## Fires when a droplet knocks the swarm down (hazard_knockback.gd's
## knocked_out signal, emitted once per knockback regardless of hit
## threshold). Gives each speck its own randomized resting spot near the
## ground and resets its fall state, so _fall_speck can drop each one there
## independently instead of the whole cluster staying frozen mid-air as one
## rigid blob while the root falls.
func _on_knocked_out() -> void:
	for speck_state: Dictionary in _specks:
		speck_state["fall_velocity"] = 0.0
		speck_state["grounded"] = false
		speck_state["rest_offset"] = Vector2(
			randf_range(speck_scatter_x_min, speck_scatter_x_max),
			randf_range(speck_rest_y_min, speck_rest_y_max)
		)


## Advances one speck's individual knockout fall by delta: gravity pulls it
## down toward its rest_offset (set in _on_knocked_out) while it eases
## sideways toward the same offset's x, so each member of the swarm visibly
## drops to its own spot on the ground rather than the cluster sinking as a
## single unit. Once it reaches rest_offset.y it's marked "grounded" and left
## alone until _process's normal branch eases it back into orbit formation.
func _fall_speck(speck_state: Dictionary, delta: float) -> void:
	if speck_state.get("grounded", false):
		return
	var speck: Node2D = speck_state["node"]
	var rest_offset: Vector2 = speck_state["rest_offset"]
	speck_state["fall_velocity"] += speck_fall_gravity * delta
	var pos: Vector2 = speck.position
	pos.y += speck_state["fall_velocity"] * delta
	pos.x = move_toward(pos.x, rest_offset.x, speck_scatter_speed * delta)
	if pos.y >= rest_offset.y:
		pos.y = rest_offset.y
		speck_state["grounded"] = true
	speck.position = pos


## Overrides whatever wander target was in progress: once knocked down and
## recovered, the swarm must fly straight back to its original spawn point
## before resuming leash-wander, rather than picking up wandering from
## wherever it landed.
func _on_knockback_recovered() -> void:
	_target = _home
	_returning_home = true


func _pick_new_target() -> void:
	var offset := Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
	_target = _home + offset
	_retarget_timer = randf_range(retarget_min, retarget_max)


## The player is a physics body, so this Area2D detects it directly via
## body_entered — no per-tick polling like the Area2D-vs-Area2D detectables.
## Duck-typed on steal_water()/lose_pollen() so the swarm doesn't depend on
## the player class; the player owns clamping its own state and notifying
## the HUD. Seeds are never touched here — losing a seed would be too
## punishing, per REQUIREMENTS.md. One steal_sound play per touch even
## though both effects can fire.
func _on_body_entered(body: Node) -> void:
	if _knockback.active:
		return
	var hit := false
	if body.has_method("steal_water"):
		body.steal_water(steal_amount)
		hit = true
	if body.has_method("lose_pollen"):
		body.lose_pollen()
		hit = true
	if hit:
		steal_sound.play()


## Duck-typed for water_droplet.gd, mirroring steal_water()/lose_pollen()'s
## contract: a droplet calls this unconditionally on any overlap, and this
## hazard decides what a hit means. No-op while already knocked down (can't
## be knocked down twice). See scripts/hazard_knockback.gd for the actual
## fall/land/vibrate/recover state machine, shared with wasp.gd.
func knockback(hit_velocity: Vector2) -> void:
	if _knockback.active:
		return
	_hits_taken += 1
	if _hits_taken < knockback_hit_threshold:
		return
	_hits_taken = 0
	knockback_sound.play()
	_knockback.start(hit_velocity)
