extends Node2D

## Main owns spawning new scene instances into the level — plants themselves
## don't know about scenes/spawning, per CODING.md's signals-over-tree-
## reaching rule. Connecting to every Seedling here (rather than wiring each
## instance's signal by hand in main.tscn) means new seedlings added to the
## level are covered automatically.
const SEED_SCENE: PackedScene = preload("res://scenes/seed.tscn")
const SEEDLING_SCENE: PackedScene = preload("res://scenes/seedling.tscn")
const WIN_OVERLAY_SCENE: PackedScene = preload("res://scenes/win_overlay.tscn")

## A seed pops out "beside" its parent plant rather than on top of it.
const SEED_SPAWN_OFFSET: Vector2 = Vector2(18.0, 0.0)

## This round's 4 target plants (1 base + 3 hybrids), rolled once in _ready().
## Emitted once the set is chosen so GoalPanel can build its rows.
signal goal_selected(goal_types: Array[PlantData.PlantType])

## Emitted each time a goal plant first reaches full bloom anywhere in the
## level. Progress only ever moves forward (REQUIREMENTS.md prefers the
## simpler "stays checked" rule over tracking un-checking).
signal goal_checked(goal_type: PlantData.PlantType)

## Emitted once every goal in goal_progress is true.
signal won

var goal_types: Array[PlantData.PlantType] = []
var goal_progress: Dictionary[PlantData.PlantType, bool] = {}

@onready var intro_screen: CanvasLayer = $IntroScreen


func _ready() -> void:
	get_tree().paused = true
	# "main" group membership comes from main.tscn's node definition (not
	# add_to_group here) so it exists before any sibling's _ready() runs —
	# GoalPanel looks Main up by group in its own _ready(), which fires
	# before this one (children ready before parents).
	intro_screen.start_requested.connect(_on_intro_start_requested)
	_select_goals()
	for child in get_children():
		_wire_seedling(child)
		if child.has_signal("seed_planted"):
			child.seed_planted.connect(_on_plot_seed_planted)


## Picks this round's goal set: 1 random base plant + 3 random hybrids, no
## repeats possible since both lists are already disjoint and unique.
## "Seeded at level start" (REQUIREMENTS.md) means rolled once here, not
## re-rolled during play — reload_current_scene() re-runs this for a fresh set.
func _select_goals() -> void:
	randomize()
	var hybrids: Array[PlantData.PlantType] = PlantData.HYBRID_TYPES.duplicate()
	hybrids.shuffle()
	goal_types = [PlantData.BASE_TYPES.pick_random()]
	goal_types.append_array(hybrids.slice(0, 3))
	for type: PlantData.PlantType in goal_types:
		goal_progress[type] = false
	goal_selected.emit(goal_types)


func _on_intro_start_requested() -> void:
	get_tree().paused = false


func _on_seedling_seed_popped(hybrid_type: PlantData.PlantType, at_position: Vector2) -> void:
	var seed: Area2D = SEED_SCENE.instantiate()
	seed.plant_type = hybrid_type
	seed.global_position = at_position + SEED_SPAWN_OFFSET
	add_child(seed)


func _on_plot_seed_planted(hybrid_type: PlantData.PlantType, at_position: Vector2) -> void:
	var seedling: Node2D = SEEDLING_SCENE.instantiate()
	seedling.growth = 0.0
	seedling.bloom_type = hybrid_type
	seedling.global_position = at_position
	add_child(seedling)
	_wire_seedling(seedling)


## Connects a Seedling's signals to Main so its progress counts toward goal
## tracking. Shared by the initial _ready() loop (existing level children)
## and _on_plot_seed_planted() (seedlings spawned mid-run from planted
## seeds) — the latter is the case that bit us: those nodes are added long
## after _ready()'s loop already ran, so without this they'd bloom silently
## uncounted.
func _wire_seedling(child: Node) -> void:
	if child.has_signal("seed_popped"):
		child.seed_popped.connect(_on_seedling_seed_popped)
	if child.has_signal("bloomed"):
		child.bloomed.connect(_on_seedling_bloomed)
		# Seedlings placed already-bloomed in the editor fire `bloomed` (if at
		# all) before this connection exists, since child _ready() runs
		# before Main's — check their current state directly too.
		if child.is_bloomed():
			_on_seedling_bloomed(child.bloom_type)


func _on_seedling_bloomed(bloom_type: PlantData.PlantType) -> void:
	if not goal_progress.has(bloom_type) or goal_progress[bloom_type]:
		return
	goal_progress[bloom_type] = true
	goal_checked.emit(bloom_type)
	for done: bool in goal_progress.values():
		if not done:
			return
	won.emit()
	get_tree().paused = true
	add_child(WIN_OVERLAY_SCENE.instantiate())
