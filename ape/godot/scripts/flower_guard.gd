extends Area2D

## A patrolling hazard guarding a specific flower against point-blank
## camping (see REQUIREMENTS.md). Step 1: deterministic circular patrol
## around guarded_flower. Step 2 (this): builds/decays aggro from player
## dwell time near guarded_flower and telegraphs a windup before it would
## ever lunge (lunge itself lands in Step 3). Unlike enemy.gd's random
## leash-wander, the orbit is a fixed circle so the guard always reads as
## tied to the flower it protects rather than roaming free. The visual
## stays level (no spin) so the guard always reads as horizontal, unlike
## the gnat cloud's constant spin.

## A plain @export var of a Node-derived type only auto-resolves when wired
## through the editor's node picker (which serializes an internal object
## reference); a hand-authored .tscn value like `NodePath("../Seedling10")`
## deserializes into nothing and silently leaves this null. Exporting
## NodePath and resolving it once in _ready() works for both cases.
@export var guarded_flower: NodePath
@export var orbit_radius: float = 40.0
@export var orbit_speed: float = 1.2
## Orbit center sits this far above the flower (not centered on it), so the
## guard always reads as hovering watch over it rather than circling through
## it. Kept >= orbit_radius so the circle never dips below the flower.
@export var orbit_height_offset: float = 50.0

## Step 2 aggro/telegraph tuning. Kept as local @exports (not GameplayTuning)
## to stay consistent with this script's own Step 1 precedent and enemy.gd's
## style; see REQUIREMENTS.md's architectural direction. Placeholder values,
## meant to be tuned against the player's real droplet range in Step 4.
@export var notice_range: float = 144.0
@export var aggro_build_rate: float = 0.8
@export var aggro_decay_rate: float = 0.6
@export var aggro_threshold: float = 0.7
@export var windup_duration: float = 0.5
@export var alert_flap_speed: float = 34.0
@export var alert_color: Color = Color(1.0, 0.35, 0.3)

const FACING_TURN_SPEED := 12.0

enum State { PATROL, WINDUP }

@onready var visual: Node2D = $Visual
@onready var wings: Node2D = $Visual/Wings
@onready var windup_buzz: AudioStreamPlayer2D = $WindupBuzz

var _center: Vector2
var _angle: float = 0.0
var _facing_x: float = 1.0
var _flower: Node2D
var _player: Node2D
var _base_flap_speed: float
var _base_color: Color

var state: State = State.PATROL
var aggro: float = 0.0
var windup_timer: float = 0.0


func _ready() -> void:
	_flower = get_node(guarded_flower) as Node2D if not guarded_flower.is_empty() else null
	_center = _flower.position + Vector2(0, -orbit_height_offset) if _flower else position
	_angle = (position - _center).angle() if position != _center else 0.0
	_player = get_tree().get_first_node_in_group("player")
	_base_flap_speed = wings.flap_speed
	_base_color = visual.modulate


func _process(delta: float) -> void:
	_update_aggro(delta)
	_update_state(delta)

	# Orbit halts while winding up -- the guard visibly stops mid-circle as
	# part of the "rearing back" telegraph, instead of a separate pose.
	if state != State.WINDUP:
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

	_update_telegraph(delta)


## Aggro tracks dwell time near the *flower*, not the guard's own position,
## per REQUIREMENTS.md -- this is what makes point-blank camping (not just
## proximity to the guard itself) the thing that gets punished.
func _update_aggro(delta: float) -> void:
	if not _flower or not _player:
		aggro = maxf(aggro - aggro_decay_rate * delta, 0.0)
		return
	var distance := _flower.global_position.distance_to(_player.global_position)
	if distance <= notice_range:
		aggro = minf(aggro + aggro_build_rate * delta, 1.0)
	else:
		aggro = maxf(aggro - aggro_decay_rate * delta, 0.0)


func _update_state(delta: float) -> void:
	match state:
		State.PATROL:
			if aggro >= aggro_threshold:
				state = State.WINDUP
				windup_timer = 0.0
				windup_buzz.pitch_scale = 1.0
				windup_buzz.play()
		State.WINDUP:
			var distance := _flower.global_position.distance_to(_player.global_position) if _flower and _player else INF
			if distance > notice_range:
				# Bail: player left notice_range during windup, so the lunge
				# never fires and aggro simply resumes decaying as normal.
				state = State.PATROL
				windup_timer = 0.0
				windup_buzz.stop()
			else:
				# Clamped rather than left to grow unbounded: Step 3 hooks the
				# actual lunge at windup_timer >= windup_duration.
				windup_timer = minf(windup_timer + delta, windup_duration)
				windup_buzz.pitch_scale = lerpf(1.0, 2.0, windup_timer / windup_duration)


## Continuous visual/audio escalation, a pure function of aggro (and, while
## winding up, of windup progress) -- no snapping, per ARCHITECTURE.md's
## feedback convention.
func _update_telegraph(_delta: float) -> void:
	visual.modulate = _base_color.lerp(alert_color, aggro)
	wings.flap_speed = lerpf(_base_flap_speed, alert_flap_speed, aggro)
