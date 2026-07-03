extends CanvasLayer

## Runs while the level is paused, so it needs to keep processing input itself.
signal start_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		start_requested.emit()
		queue_free()
