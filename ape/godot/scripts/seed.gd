extends Area2D

## A loose popped seed. Passive detectable (group "seed" in the .tscn):
## pickup logic lives entirely in the player's sensor poll, which reads
## plant_type off this node and frees it — there is deliberately no pickup
## code or signal here.

## The plant type this seed will grow into once planted (Step 4). Colors the
## seed's visual via PlantData, the single source of truth for plant data.
@export var plant_type: PlantData.PlantType = PlantData.PlantType.NONE

@onready var body: Polygon2D = $Body

const POP_HEIGHT: float = 22.0
const POP_SIDE: float = 14.0
const POP_DURATION: float = 0.35


func _ready() -> void:
	body.color = PlantData.seed_color(plant_type)
	_play_pop_in()


## A short arc-with-a-bounce entrance (REQUIREMENTS.md fit-and-finish:
## 0.15-0.4s, "nothing snaps").
## Arcs to one side and up, then lands with a bounce ease at the original
## spot, so the seed reads as having just popped out of the plant beside it.
func _play_pop_in() -> void:
	var rest_position: Vector2 = position
	var side: float = POP_SIDE * (1.0 if randf() < 0.5 else -1.0)
	position += Vector2(0.0, POP_HEIGHT)
	scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", rest_position + Vector2(side, 0.0) * 0.4, POP_DURATION * 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, POP_DURATION * 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "position", rest_position, POP_DURATION * 0.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
