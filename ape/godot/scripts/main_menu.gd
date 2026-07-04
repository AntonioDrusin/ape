extends CanvasLayer

## Standalone entry scene (the project main scene): shows the title and
## how-to-play text, then swaps to the level. The level never pauses for an
## intro — by the time main.tscn loads, the player has already read this.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
