extends CanvasLayer

## Spawned by Main (Step 6) once every goal is checked. Runs while Main keeps
## the tree paused, so it needs PROCESS_MODE_ALWAYS to take button input and
## play its particles/sound, the same reason intro_screen.gd sets it.

@onready var play_again_button: Button = $VBoxContainer/PlayAgainButton
@onready var celebration: CPUParticles2D = $CelebrationAnchor/Celebration
@onready var win_sound: AudioStreamPlayer = $WinSound


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	play_again_button.pressed.connect(_on_play_again_pressed)
	celebration.emitting = true
	win_sound.play()


func _on_play_again_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
