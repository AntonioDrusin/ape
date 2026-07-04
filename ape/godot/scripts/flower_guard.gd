extends Area2D

## A patrolling hazard guarding a specific flower against point-blank
## camping (see REQUIREMENTS.md). Step 1: deterministic circular patrol
## around guarded_flower. Step 2: builds/decays aggro from player dwell
## time near guarded_flower and telegraphs a windup before it would ever
## lunge. Step 3 (this): once windup completes, dashes at the player's
## position captured at that instant (not homing), eases back onto the
## orbit circle, then resets aggro and gates re-noticing for
## reaggro_cooldown. Unlike enemy.gd's random leash-wander, the orbit is a
## fixed circle so the guard always reads as tied to the flower it
## protects rather than roaming free. The visual stays level (no spin) so
## the guard always reads as horizontal, unlike the gnat cloud's constant
## spin.

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

## Step 3 lunge/punishment tuning. Same local-@export precedent as above.
@export var lunge_speed: float = 260.0
@export var reaggro_cooldown: float = 1.5
@export var steal_amount: float = 0.35 ## matches enemy.gd's default so the two hazards feel like siblings

const FACING_TURN_SPEED := 12.0

enum State { PATROL, WINDUP, LUNGE, RETURN }

@onready var visual: Node2D = $Visual
@onready var wings: Node2D = $Visual/Wings
@onready var windup_buzz: AudioStreamPlayer2D = $WindupBuzz
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

var _center: Vector2
var _angle: float = 0.0
var _facing_x: float = 1.0
var _flower: Node2D
var _player: Node2D
var _base_flap_speed: float
var _base_color: Color
var _lunge_target: Vector2
var _reaggro_cooldown_timer: float = 0.0

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
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_update_aggro(delta)
	_update_state(delta)

	# Orbit halts while winding up -- the guard visibly stops mid-circle as
	# part of the "rearing back" telegraph, instead of a separate pose.
	# During LUNGE/RETURN, _update_state already wrote position directly
	# via move_toward, so the orbit-follow assignment must not run then.
	if state == State.PATROL or state == State.WINDUP:
		if state == State.PATROL:
			_angle += orbit_speed * delta
		position = _center + Vector2(cos(_angle), sin(_angle)) * orbit_radius

		# Tangential velocity along the circle; its x sign is which way the
		# guard is currently traveling. Mirrors player.gd's facing_x/scale.x
		# flip. Meaningless off-orbit, so skipped during LUNGE/RETURN, where
		# _facing_x instead holds the lunge direction set in _update_state.
		var velocity_x := -sin(_angle) * orbit_radius * orbit_speed
		if absf(velocity_x) > 0.1:
			_facing_x = signf(velocity_x)

	# Only Visual flips (so collision never mirrors), and the flip itself
	# smoothly interpolates rather than snapping, matching "nothing snaps".
	visual.scale.x = move_toward(visual.scale.x, _facing_x, FACING_TURN_SPEED * delta)

	_update_telegraph(delta)


## Aggro tracks dwell time near the *flower*, not the guard's own position,
## per REQUIREMENTS.md -- this is what makes point-blank camping (not just
## proximity to the guard itself) the thing that gets punished.
func _update_aggro(delta: float) -> void:
	# Gates re-noticing after a lunge resolves: fully blocks aggro rebuild
	# for the whole cooldown window, even if the player never leaves
	# notice_range, per REQUIREMENTS.md's "can't re-notice immediately".
	if _reaggro_cooldown_timer > 0.0:
		_reaggro_cooldown_timer = maxf(_reaggro_cooldown_timer - delta, 0.0)
		aggro = maxf(aggro - aggro_decay_rate * delta, 0.0)
		return
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
				windup_timer = minf(windup_timer + delta, windup_duration)
				windup_buzz.pitch_scale = lerpf(1.0, 2.0, windup_timer / windup_duration)
				if windup_timer >= windup_duration:
					# Commit: capture the player's position once -- a dash at
					# a fixed point, not a homing chase -- and stop the buzz
					# since the lunge whoosh/hit sound take over from here.
					windup_buzz.stop()
					if _player:
						_lunge_target = _player.global_position
						if not is_zero_approx(_lunge_target.x - position.x):
							_facing_x = signf(_lunge_target.x - position.x)
						state = State.LUNGE
					else:
						state = State.PATROL
						windup_timer = 0.0
		State.LUNGE:
			# Not cancelable -- no notice_range check here, matching "dashes
			# ... then reverts to patrol regardless of whether it connected".
			position = position.move_toward(_lunge_target, lunge_speed * delta)
			if position.distance_to(_lunge_target) < 4.0:
				state = State.RETURN
		State.RETURN:
			var orbit_point := _center + Vector2(cos(_angle), sin(_angle)) * orbit_radius
			position = position.move_toward(orbit_point, lunge_speed * delta)
			if position.distance_to(orbit_point) < 4.0:
				_resolve_lunge()


## Ends the lunge/return cycle regardless of hit or miss: aggro resets and
## reaggro_cooldown starts, so a single close call buys the player breathing
## room before the guard can threaten again.
func _resolve_lunge() -> void:
	state = State.PATROL
	aggro = 0.0
	_reaggro_cooldown_timer = reaggro_cooldown


## Mirrors enemy.gd's _on_body_entered exactly (duck-typed steal_water()/
## lose_pollen(), seeds untouched), but gated to the LUNGE dash itself --
## this Area2D has monitoring=true throughout patrol/windup too, so
## incidental overlap then must never punish.
func _on_body_entered(body: Node) -> void:
	if state != State.LUNGE:
		return
	var hit := false
	if body.has_method("steal_water"):
		body.steal_water(steal_amount)
		hit = true
	if body.has_method("lose_pollen"):
		body.lose_pollen()
		hit = true
	if hit:
		hit_sound.pitch_scale = randf_range(0.9, 1.1)
		hit_sound.play()


## Continuous visual/audio escalation, a pure function of aggro (and, while
## winding up, of windup progress) -- no snapping, per ARCHITECTURE.md's
## feedback convention.
func _update_telegraph(_delta: float) -> void:
	visual.modulate = _base_color.lerp(alert_color, aggro)
	wings.flap_speed = lerpf(_base_flap_speed, alert_flap_speed, aggro)
