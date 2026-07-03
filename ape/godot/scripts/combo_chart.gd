extends Panel

## Always-visible reference panel listing the 8 pollen combos, generated
## from PlantData.all_combos() rather than hand-authored in the scene.
## Toggled with the "toggle_combo_chart" action ("1").

const ROW_HEIGHT: float = 28.0
const PADDING: float = 16.0
const ICON_SCALE: float = 1.2
const ICON_ORIGIN: Vector2 = Vector2(0, -17)

var _combos: Array[Dictionary] = []
var _icon_shapes: Dictionary = {}
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	_combos = PlantData.all_combos()
	for combo: Dictionary in _combos:
		for key in ["a", "b", "result"]:
			var type: PlantData.PlantType = combo[key]
			if not _icon_shapes.has(type):
				_icon_shapes[type] = PlantIconSource.bloom_shapes(type)
	custom_minimum_size = Vector2(200.0, PADDING * 2.0 + ROW_HEIGHT * _combos.size())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_combo_chart"):
		visible = not visible


func _draw() -> void:
	for i in _combos.size():
		_draw_row(_combos[i], PADDING + ROW_HEIGHT * i + ROW_HEIGHT * 0.5)


func _draw_row(combo: Dictionary, cy: float) -> void:
	_draw_icon(Vector2(28, cy), combo["a"])
	_draw_glyph("+", Vector2(52, cy))
	_draw_icon(Vector2(76, cy), combo["b"])
	_draw_glyph("=", Vector2(100, cy))
	_draw_icon(Vector2(150, cy), combo["result"])


func _draw_glyph(text: String, center: Vector2) -> void:
	draw_string(_font, center + Vector2(-5, 5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)


func _draw_icon(center: Vector2, type: PlantData.PlantType) -> void:
	for shape: Dictionary in _icon_shapes[type]:
		var scaled := PackedVector2Array()
		for p in shape["polygon"]:
			scaled.append((p - ICON_ORIGIN) * ICON_SCALE + center)
		draw_colored_polygon(scaled, shape["color"])


func _get_tooltip(at_position: Vector2) -> String:
	var index := int((at_position.y - PADDING) / ROW_HEIGHT)
	if index < 0 or index >= _combos.size():
		return ""
	var combo: Dictionary = _combos[index]
	return "%s + %s = %s" % [
		PlantData.display_name(combo["a"]),
		PlantData.display_name(combo["b"]),
		PlantData.display_name(combo["result"]),
	]
