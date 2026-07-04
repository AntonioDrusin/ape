extends Area2D

## Step 3: a fired water droplet is the one active exception to pattern 2's
## passive detectables (see ARCHITECTURE.md's Patterns list) -- it carries its
## own velocity and polls gravity/lifetime itself because it, not the player,
## is what's moving through the world while it's alive. Step 4 adds
## seedling/ground overlap handling on top of this; this step only arcs and
## despawns via LifetimeTimer, no collision response yet.

@export var tuning: GameplayTuning = preload("res://data/player_tuning.tres")

var velocity: Vector2 = Vector2.ZERO

@onready var lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	lifetime_timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	velocity.y += tuning.droplet_gravity * delta
	position += velocity * delta
	rotation = velocity.angle()
