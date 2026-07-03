@tool
extends Node2D

## Plant lifecycle: GROWING -> BLOOMED -> POLLINATED -> SEED_GROWING -> (seed
## pops) -> BLOOMED. Watering drives GROWING; the POLLINATED and SEED_GROWING
## states are entered by the pollination/seed mechanics of later build steps.
enum State { GROWING, BLOOMED, POLLINATED, SEED_GROWING }

const MIN_SCALE: float = 0.12
const BLOOM_START: float = 70.0

var state: State = State.GROWING:
	set(value):
		state = value
		_update_visuals()

## Progress through the GROWING state; kept exported so instances in the level
## can start part-grown and the @tool preview stays live in the editor.
@export_range(0.0, 100.0) var growth: float = 100.0:
	set(value):
		growth = clampf(value, 0.0, 100.0)
		if state == State.GROWING and growth >= 100.0:
			state = State.BLOOMED
		elif state == State.BLOOMED and growth < 100.0:
			state = State.GROWING
		else:
			_update_visuals()

## Seconds of continuous watering to grow from 0% to 100%.
@export var grow_time: float = 5.0

@export var bloom_type: PlantData.PlantType = PlantData.PlantType.DAISY:
	set(value):
		bloom_type = value
		_update_visuals()

@onready var bud: Polygon2D = $Sprout/Bud
@onready var bloom: Node2D = $Bloom
@onready var pollen_cue: Node2D = $Bloom/PollenCue
@onready var _blooms: Dictionary = {
	PlantData.PlantType.DAISY: $Bloom/Daisy,
	PlantData.PlantType.TULIP: $Bloom/Tulip,
	PlantData.PlantType.BERRY: $Bloom/Berry,
	PlantData.PlantType.APPLE: $Bloom/Apple,
	PlantData.PlantType.SUNFLOWER: $Bloom/Sunflower,
}


func _ready() -> void:
	# Instances that keep the default growth value never run its setter, so
	# derive the starting state here instead of trusting the default.
	state = State.BLOOMED if growth >= 100.0 else State.GROWING


func water(delta: float) -> void:
	growth += 100.0 / grow_time * delta


## Every visual is a function of (state, progress, bloom_type) — no visual
## state is stored anywhere else.
func _update_visuals() -> void:
	if not is_node_ready():
		return
	scale = Vector2.ONE * lerpf(MIN_SCALE, 1.0, growth / 100.0)
	var bloom_t: float = clampf((growth - BLOOM_START) / (100.0 - BLOOM_START), 0.0, 1.0)
	bloom.visible = bloom_t > 0.0
	bloom.scale = Vector2.ONE * bloom_t
	bud.visible = bloom_t <= 0.0
	for type: PlantData.PlantType in _blooms:
		_blooms[type].visible = type == bloom_type
	pollen_cue.visible = state == State.BLOOMED
	pollen_cue.modulate = PlantData.pollen_color(bloom_type)
