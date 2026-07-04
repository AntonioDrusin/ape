extends Panel

## Shows this round's 4 goal plants (Step 6), generated from whatever Main
## rolled for goal_types rather than anything hand-authored here. Toggled
## with the "toggle_goal_panel" action ("2"), independent of hud.gd and
## combo_chart.gd, mirroring how ComboChart owns its own input/drawing.

const ROW_HEIGHT: float = 28.0
const PADDING: float = 16.0
const TITLE_HEIGHT: float = 22.0
const ICON_SCALE: float = 1.2
const ICON_ORIGIN: Vector2 = Vector2(0, -17)
const FLOURISH_TIME: float = 0.4

var _goal_types: Array[PlantData.PlantType] = []
var _checked: Dictionary[PlantData.PlantType, bool] = {}
var _flourish: Dictionary[PlantData.PlantType, float] = {}
var _icon_shapes: Dictionary = {}
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	custom_minimum_size = Vector2(200.0, TITLE_HEIGHT + PADDING)
	# Safe this early (a child's _ready() runs before Main's) only because
	# Main's group membership is set in main.tscn, not via add_to_group().
	var main: Node = get_tree().get_first_node_in_group("main")
	if main:
		main.goal_selected.connect(_on_goal_selected)
		main.goal_checked.connect(_on_goal_checked)


func _process(delta: float) -> void:
	if _flourish.is_empty():
		return
	var finished: Array[PlantData.PlantType] = []
	for type: PlantData.PlantType in _flourish:
		_flourish[type] -= delta
		if _flourish[type] <= 0.0:
			finished.append(type)
	for type: PlantData.PlantType in finished:
		_flourish.erase(type)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_goal_panel"):
		visible = not visible


func _on_goal_selected(goal_types: Array[PlantData.PlantType]) -> void:
	_goal_types = goal_types
	for type: PlantData.PlantType in _goal_types:
		_checked[type] = false
		if not _icon_shapes.has(type):
			_icon_shapes[type] = PlantIconSource.bloom_shapes(type)
	custom_minimum_size = Vector2(200.0, TITLE_HEIGHT + PADDING * 2.0 + ROW_HEIGHT * _goal_types.size())
	queue_redraw()


func _on_goal_checked(goal_type: PlantData.PlantType) -> void:
	_checked[goal_type] = true
	_flourish[goal_type] = FLOURISH_TIME
	queue_redraw()


func _draw() -> void:
	draw_string(_font, Vector2(PADDING, TITLE_HEIGHT), "Goals", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	for i in _goal_types.size():
		_draw_row(_goal_types[i], TITLE_HEIGHT + PADDING + ROW_HEIGHT * i + ROW_HEIGHT * 0.5)


func _draw_row(type: PlantData.PlantType, cy: float) -> void:
	var pop: float = 1.0
	if _flourish.has(type):
		pop = 1.0 + 0.6 * (_flourish[type] / FLOURISH_TIME)
	_draw_icon(Vector2(28, cy), type, pop)
	draw_string(_font, Vector2(52, cy + 5), PlantData.display_name(type), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	if _checked.get(type, false):
		draw_string(_font, Vector2(176, cy + 6), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.4, 1.0, 0.5))


func _draw_icon(center: Vector2, type: PlantData.PlantType, pop: float) -> void:
	for shape: Dictionary in _icon_shapes[type]:
		var scaled := PackedVector2Array()
		for p in shape["polygon"]:
			scaled.append((p - ICON_ORIGIN) * ICON_SCALE * pop + center)
		draw_colored_polygon(scaled, shape["color"])


func _get_tooltip(at_position: Vector2) -> String:
	var index := int((at_position.y - TITLE_HEIGHT - PADDING) / ROW_HEIGHT)
	if index < 0 or index >= _goal_types.size():
		return ""
	var type: PlantData.PlantType = _goal_types[index]
	var status: String = "grown" if _checked.get(type, false) else "not grown yet"
	return "%s — %s" % [PlantData.display_name(type), status]
