extends Node

## Autoload singleton for persisted user preferences (currently just the CRT
## toggle). Saved to user://settings.cfg so it survives across scenes and runs.

signal crt_enabled_changed(enabled: bool)

const SAVE_PATH := "user://settings.cfg"

var crt_enabled: bool = true:
	set(value):
		if crt_enabled == value:
			return
		crt_enabled = value
		crt_enabled_changed.emit(value)
		_save()

## Whether to play "Entropy of the Infinite" instead of the original level
## music. Only read at level start (main.gd), not live-toggled mid-game.
var good_music: bool = true:
	set(value):
		if good_music == value:
			return
		good_music = value
		_save()


func _ready() -> void:
	_load()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		crt_enabled = config.get_value("display", "crt_enabled", true)
		good_music = config.get_value("audio", "good_music", false)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "crt_enabled", crt_enabled)
	config.set_value("audio", "good_music", good_music)
	config.save(SAVE_PATH)
