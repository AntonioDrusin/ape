extends RayCast2D
class_name HazardKnockback

## Shared knockout physics for hazards that a water droplet can knock back
## (small_swarm.gd, wasp.gd) -- factored out once both needed the identical
## fall/land/vibrate/recover state machine (CODING.md point 3: shared
## behavior gets its own script once a second case exists, not before).
## A RayCast2D rather than a plain helper object because landing needs a
## downward ground check and only a Node can host that query; instanced as a
## direct child of the hazard so the cast always originates at the hazard's
## own position. Deliberately doesn't reach up to mutate its parent (that
## would break CODING.md's "script owns its own node" rule) -- the owning
## hazard script calls step() every frame it's active and applies the
## returned position delta itself, exactly like it already owns applying its
## own movement.
##
## Landing only ever checks against physics bodies (RayCast2D's
## collide_with_areas defaults off), so it hits platform.tscn/wall.tscn but
## passes straight through water.tscn's Area2D -- the owning hazard is
## responsible for polling its own overlaps for the "water" group while
## active and freeing itself if it lands in water, same as the death rule
## anywhere else in this project is a poll, not a physics collision.

signal knocked_out
signal recovered

@export var fall_velocity_scale: float = 0.1 ## how much of the droplet's hit velocity carries into the fall -- small enough that gravity below dominates and the hazard drops mostly straight down instead of flying off
@export var fall_gravity: float = 260.0
@export var knockout_duration: float = 5.0 ## seconds spent knocked out once landed, before the hazard recovers (kept as an @export, not hardcoded, so it's tunable as data per CODING.md point 2)
@export var vibrate_amplitude: float = 1.5
@export var vibrate_speed: float = 40.0

var active: bool = false
var landed: bool = false
var vibrate_offset: Vector2 = Vector2.ZERO

var _fall_velocity: Vector2 = Vector2.ZERO
var _recover_timer: float = 0.0
var _vibrate_phase: float = 0.0


func _ready() -> void:
	target_position = Vector2(0, 24.0)
	enabled = false


## Begins the knockback. hit_velocity is the droplet's velocity at impact
## (see water_droplet.gd); ignored if already active since a hazard already
## down can't be knocked down again.
func start(hit_velocity: Vector2) -> void:
	if active:
		return
	active = true
	landed = false
	_fall_velocity = hit_velocity * fall_velocity_scale
	_vibrate_phase = 0.0
	vibrate_offset = Vector2.ZERO
	enabled = true
	knocked_out.emit()


## Advances the fall/land/vibrate/recover state by delta and returns the
## position delta the caller should add to its own global_position this
## frame -- Vector2.ZERO once landed, since landing pins position instead of
## moving it. No-op (returns Vector2.ZERO) if not active.
func step(delta: float) -> Vector2:
	if not active:
		return Vector2.ZERO
	if not landed:
		_fall_velocity.y += fall_gravity * delta
		force_raycast_update()
		if is_colliding():
			landed = true
			_recover_timer = knockout_duration
			enabled = false
			return get_collision_point() - global_position
		return _fall_velocity * delta

	_vibrate_phase += vibrate_speed * delta
	vibrate_offset = Vector2(sin(_vibrate_phase), 0.0) * vibrate_amplitude
	_recover_timer -= delta
	if _recover_timer <= 0.0:
		active = false
		landed = false
		vibrate_offset = Vector2.ZERO
		recovered.emit()
	return Vector2.ZERO
