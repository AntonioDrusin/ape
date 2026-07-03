class_name PlantIconSource

## Reads seedling.tscn's Bloom/<Name> polygon+color data off-tree, for
## combo_chart.gd's custom-draw icons. Never adds a live seedling (with its
## Area2D/collision/state machine/group membership) to the scene tree.

const _SEEDLING_SCENE: PackedScene = preload("res://scenes/seedling.tscn")


## One draw-ready shape per Polygon2D under Bloom/<Name>, sharing that
## group's common local origin.
static func bloom_shapes(type: PlantData.PlantType) -> Array[Dictionary]:
	var temp: Node2D = _SEEDLING_SCENE.instantiate()
	var bloom_node: Node2D = temp.get_node("Bloom/" + PlantData.display_name(type))
	var shapes: Array[Dictionary] = []
	for child in bloom_node.get_children():
		if child is Polygon2D:
			shapes.append({"polygon": child.polygon, "color": child.color})
	temp.free()
	return shapes
