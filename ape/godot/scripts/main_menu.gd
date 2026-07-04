extends CanvasLayer

## Standalone entry scene (the project main scene): shows the title and
## how-to-play text, then swaps to the level. The level never pauses for an
## intro — by the time main.tscn loads, the player has already read this.


func _ready() -> void:
	var crt_toggle: CheckButton = $VBoxContainer/CrtToggle
	crt_toggle.button_pressed = Settings.crt_enabled
	crt_toggle.toggled.connect(func(enabled: bool) -> void: Settings.crt_enabled = enabled)

	var good_music_toggle: CheckButton = $VBoxContainer/GoodMusicToggle
	good_music_toggle.button_pressed = Settings.good_music
	good_music_toggle.toggled.connect(func(enabled: bool) -> void: Settings.good_music = enabled)

	var start_button: Button = $VBoxContainer/StartPrompt
	start_button.pressed.connect(_start_game)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start_game()


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
