class_name PlantData

## Single source of truth for plant data (REQUIREMENTS.md "Architectural
## direction"): plant types, pollen colors, and the hybrid combo table.
## Gameplay and UI both read from here; nothing else may hardcode this data.

## NONE and the base five keep explicit values so ints already saved as
## `bloom_type` in main.tscn keep mapping to the same plants. Hybrids arrive
## with pollination (Step 2); their visuals land in Step 4.
enum PlantType {
	NONE = -1,
	DAISY = 0, TULIP = 1, BERRY = 2, APPLE = 3, SUNFLOWER = 4,
	ROSE = 5, LAVENDER = 6, STARBLOOM = 7, ORCHID = 8,
	FIRELILY = 9, PLUM = 10, PUMPKIN = 11, CHERRY = 12,
}

## Pollen colors must stay tellable apart at bee-butt size and against all
## level backgrounds (see the readability notes in REQUIREMENTS.md).
const POLLEN_COLORS: Dictionary[PlantType, Color] = {
	PlantType.DAISY: Color(0.98, 0.98, 0.95),
	PlantType.TULIP: Color(1.0, 0.5, 0.75),
	PlantType.BERRY: Color(0.62, 0.3, 0.9),
	PlantType.APPLE: Color(0.88, 0.12, 0.12),
	PlantType.SUNFLOWER: Color(1.0, 0.58, 0.08),
}

## Unordered base-pair combos (REQUIREMENTS.md "Hybrid combos"), keyed by
## _pair_key(a, b). Base pairs with no entry here (and not same-type) are
## fizzles — the 2 documented fizzles are exactly the pairs left over from
## the 10 possible base pairs minus these 8, so no separate fizzle table is
## needed.
const COMBO_TABLE: Dictionary[int, PlantType] = {
	1: PlantType.ROSE,      # Daisy + Tulip
	2: PlantType.LAVENDER,  # Daisy + Berry
	4: PlantType.STARBLOOM, # Daisy + Sunflower
	102: PlantType.ORCHID,   # Tulip + Berry
	104: PlantType.FIRELILY, # Tulip + Sunflower
	203: PlantType.PLUM,     # Berry + Apple
	304: PlantType.PUMPKIN,  # Apple + Sunflower
	103: PlantType.CHERRY,   # Tulip + Apple
}


static func pollen_color(type: PlantType) -> Color:
	return POLLEN_COLORS[type]


static func _pair_key(a: PlantType, b: PlantType) -> int:
	return mini(a, b) * 100 + maxi(a, b)


## Returns the hybrid result of an unordered base-pair pollination, or NONE
## if the pair fizzles. Callers are expected to handle same-type (a == b)
## themselves before calling this.
static func combo_result(a: PlantType, b: PlantType) -> PlantType:
	return COMBO_TABLE.get(_pair_key(a, b), PlantType.NONE)
