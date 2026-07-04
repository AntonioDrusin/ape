extends CanvasLayer

func _ready() -> void:
	visible = Settings.crt_enabled
	Settings.crt_enabled_changed.connect(func(enabled: bool) -> void: visible = enabled)
