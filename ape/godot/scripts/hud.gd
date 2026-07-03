extends CanvasLayer

@onready var water_meter: ProgressBar = $Control/WaterMeter


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.water_level_changed.connect(_on_water_level_changed)


func _on_water_level_changed(value: float) -> void:
	water_meter.value = value
