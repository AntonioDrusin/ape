extends Node2D

## Main owns spawning new scene instances into the level — plants themselves
## don't know about scenes/spawning, per CODING.md's signals-over-tree-
## reaching rule. Connecting to every Seedling here (rather than wiring each
## instance's signal by hand in main.tscn) means new seedlings added to the
## level are covered automatically.
const SEED_SCENE: PackedScene = preload("res://scenes/seed.tscn")
const SEEDLING_SCENE: PackedScene = preload("res://scenes/seedling.tscn")

## A seed pops out "beside" its parent plant rather than on top of it.
const SEED_SPAWN_OFFSET: Vector2 = Vector2(18.0, 0.0)

@onready var intro_screen: CanvasLayer = $IntroScreen


func _ready() -> void:
	get_tree().paused = true
	intro_screen.start_requested.connect(_on_intro_start_requested)
	for child in get_children():
		if child.has_signal("seed_popped"):
			child.seed_popped.connect(_on_seedling_seed_popped)
		if child.has_signal("seed_planted"):
			child.seed_planted.connect(_on_plot_seed_planted)


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
