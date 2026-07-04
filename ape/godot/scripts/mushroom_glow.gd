extends Node2D

## Purely decorative: gently pulses scale and cycles the cap through the
## rainbow for a psychedelic look. No gameplay significance. Each instance
## starts at a random phase so a cluster of mushrooms doesn't pulse in sync.
@export var pulse_speed: float = 1.5
@export var hue_speed: float = 0.12

@onready var cap: Polygon2D = $Cap

var _t: float = 0.0

func _ready() -> void:
	_t = randf() * 20.0

func _process(delta: float) -> void:
	_t += delta
	scale = Vector2.ONE * (1.0 + 0.05 * sin(_t * pulse_speed))
	cap.color = Color.from_hsv(wrapf(_t * hue_speed, 0.0, 1.0), 0.75, 1.0)
