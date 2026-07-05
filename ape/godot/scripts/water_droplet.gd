extends Area2D

## A fired water droplet is the one active exception to pattern 2's passive
## detectables (see ARCHITECTURE.md's Patterns list) -- it carries its own
## velocity and polls gravity/lifetime/overlaps itself because it, not the
## player, is what's moving through the world while it's alive. Nothing else
## is positioned to poll for it every frame.

## Splash effect duration: how long HitSplash/MissSplash + their sounds get to
## play before the droplet frees itself, so despawn doesn't cut them off.
const SPLASH_LIFETIME := 25.35

@export var tuning: GameplayTuning = preload("res://data/player_tuning.tres")

var velocity: Vector2 = Vector2.ZERO
var _hit: bool = false

@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var visual: Polygon2D = $Visual
@onready var hit_splash: CPUParticles2D = $HitSplash
@onready var hit_splash_sound: AudioStreamPlayer2D = $HitSplashSound
@onready var miss_splash: CPUParticles2D = $MissSplash
@onready var miss_splash_sound: AudioStreamPlayer2D = $MissSplashSound


func _ready() -> void:
	lifetime_timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if _hit:
		return

	velocity.y += tuning.droplet_gravity * delta
	position += velocity * delta
	rotation = velocity.angle()

	for area in get_overlapping_areas():
		if area.is_in_group("seedling"):
			_splash(true, area.get_parent())
			return
		if area.is_in_group("water"):
			_splash(false, null)
			return
		# Hazards (small_swarm.gd, wasp.gd) duck-type knockback() the same way
		# a seedling duck-types water() -- landing a droplet on one knocks it
		# down instead of watering it. Plays the same hit-splash as a seedling
		# hit; the hazard itself (fall/vibrate) is the distinct reaction, not
		# a new droplet-side effect.
		if area.has_method("knockback"):
			area.knockback(velocity)
			_splash(true, null)
			return
	if not get_overlapping_bodies().is_empty():
		_splash(false, null)


## Freezes the droplet in place, plays the matching splash (a hit waters the
## seedling once; a miss is just visual/audio), and shortens the existing
## lifetime timer so the splash gets to finish before queue_free -- reusing
## Step 3's despawn wiring instead of adding a second timer.
func _splash(hit: bool, seedling: Node) -> void:
	_hit = true
	monitoring = false
	visual.visible = false

	if hit and seedling:
		seedling.water(tuning.water_per_droplet)
	if hit:
		hit_splash.restart()
		hit_splash.emitting = true
		hit_splash_sound.pitch_scale = randf_range(0.9, 1.1)
		hit_splash_sound.play()
	else:
		miss_splash.restart()
		miss_splash.emitting = true
		miss_splash_sound.pitch_scale = randf_range(0.9, 1.1)
		miss_splash_sound.play()

	lifetime_timer.start(SPLASH_LIFETIME)
