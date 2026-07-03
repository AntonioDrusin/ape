extends Area2D

## Emitted once planting completes, so whoever owns spawning (Main) can
## instantiate a Seedling here — plots stay passive detectables per
## REQUIREMENTS.md, they don't touch scenes themselves.
signal seed_planted(hybrid_type: PlantData.PlantType, at_position: Vector2)

var is_empty: bool = true

@onready var marker: Node2D = $Marker
@onready var plant_puff: CPUParticles2D = $PlantPuff
@onready var plant_sound: AudioStreamPlayer2D = $PlantSound

var _marker_t: float = 0.0


func _process(delta: float) -> void:
	if not is_empty:
		return
	_marker_t += delta
	marker.modulate.a = 0.6 + 0.4 * sin(_marker_t * 3.0)


## Plants a seed of `type` here if the plot is still empty. Plays its own
## feedback (scale-pop, dust puff, sound) and hands the hybrid type off via
## seed_planted for Main to spawn the actual Seedling.
func plant(type: PlantData.PlantType) -> void:
	if not is_empty:
		return
	is_empty = false
	marker.visible = false
	plant_puff.restart()
	plant_puff.emitting = true
	plant_sound.pitch_scale = randf_range(0.9, 1.1)
	plant_sound.play()
	scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	seed_planted.emit(type, global_position)
