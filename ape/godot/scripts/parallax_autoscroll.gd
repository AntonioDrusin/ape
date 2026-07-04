extends ParallaxLayer

## Gives a ParallaxLayer autonomous rightward motion on top of the normal
## camera-driven scroll (pattern 5 in ARCHITECTURE.md). motion_offset is
## additive with the ParallaxBackground's camera-tracked scroll_offset, so
## this doesn't disturb the screen-anchored positioning of layer children.
## Decreasing motion_offset.x shifts layer content rightward on screen;
## wrapping at motion_mirroring.x keeps the seam invisible, same tile width
## already used for the camera-driven wrap.
@export var scroll_speed: float = 10.0

func _process(delta: float) -> void:
	motion_offset.x -= scroll_speed * delta
	if motion_mirroring.x > 0:
		motion_offset.x = wrapf(motion_offset.x, -motion_mirroring.x, 0.0)
