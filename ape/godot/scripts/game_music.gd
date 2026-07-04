extends AudioStreamPlayer

## Picks the level's music track from Settings.good_music at level start.
## Not live-toggled — the choice is locked in for the run once playing starts.
@export var good_music_stream: AudioStream
@export var good_music_volume_db: float = -14.0
@export var default_stream: AudioStream
@export var default_volume_db: float = -20.0


func _ready() -> void:
	if Settings.good_music:
		stream = good_music_stream
		volume_db = good_music_volume_db
	else:
		stream = default_stream
		volume_db = default_volume_db
	play()
