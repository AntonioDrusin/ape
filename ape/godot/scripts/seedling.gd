@tool
extends Node2D

enum BloomType { DAISY, TULIP, BERRY, APPLE, SUNFLOWER }

const MIN_SCALE: float = 0.12
const BLOOM_START: float = 70.0

@export_range(0.0, 100.0) var growth: float = 100.0:
	set(value):
		growth = clamp(value, 0.0, 100.0)
		_update_visuals()

## Seconds of continuous watering to grow from 0% to 100%.
@export var grow_time: float = 5.0

@export var bloom_type: BloomType = BloomType.DAISY:
	set(value):
		bloom_type = value
		_update_visuals()

@onready var bud: Polygon2D = $Sprout/Bud
@onready var bloom: Node2D = $Bloom
@onready var _blooms: Dictionary = {
	BloomType.DAISY: $Bloom/Daisy,
	BloomType.TULIP: $Bloom/Tulip,
	BloomType.BERRY: $Bloom/Berry,
	BloomType.APPLE: $Bloom/Apple,
	BloomType.SUNFLOWER: $Bloom/Sunflower,
}


func _ready() -> void:
	_update_visuals()


func water(delta: float) -> void:
	growth += 100.0 / grow_time * delta


func _update_visuals() -> void:
	if not is_node_ready():
		return
	scale = Vector2.ONE * lerp(MIN_SCALE, 1.0, growth / 100.0)
	var bloom_t: float = clamp((growth - BLOOM_START) / (100.0 - BLOOM_START), 0.0, 1.0)
	bloom.visible = bloom_t > 0.0
	bloom.scale = Vector2.ONE * bloom_t
	bud.visible = bloom_t <= 0.0
	for type in _blooms:
		_blooms[type].visible = type == bloom_type
