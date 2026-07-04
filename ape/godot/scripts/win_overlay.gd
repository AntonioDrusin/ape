extends CanvasLayer

## Spawned by Main (Step 6) once every goal is checked. Runs while Main keeps
## the tree paused, so it needs PROCESS_MODE_ALWAYS to take button input and
## play its particles/sound.

@onready var play_again_button: Button = $VBoxContainer/PlayAgainButton
@onready var vbox: VBoxContainer = $VBoxContainer
# CelebrationAnchor is a zero-size Control anchored dead-center purely so
# this CPUParticles2D gets a screen-center origin (a Node2D can't have
# anchors of its own).
@onready var celebration: CPUParticles2D = $CelebrationAnchor/Celebration
@onready var win_sound: AudioStreamPlayer = $WinSound

const APPEAR_DURATION := 0.3


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	play_again_button.pressed.connect(_on_play_again_pressed)
	celebration.emitting = true
	win_sound.play()
	_play_appear(vbox)


## Fades and scale-pops the win text/button in rather than having them appear
## instantly alongside the particle burst ("nothing snaps", REQUIREMENTS.md).
func _play_appear(node: Control) -> void:
	node.modulate.a = 0.0
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * 0.85
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, APPEAR_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, APPEAR_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_play_again_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
