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

## Which plant types currently offer/accept pollen. A property of the type,
## not derivable from "is it one of the original five" — REQUIREMENTS.md
## notes hybrids may accept pollen in a future update, so this stays a table
## rather than a range check on PlantType's int value.
const ACCEPTS_POLLEN: Dictionary[PlantType, bool] = {
	PlantType.DAISY: true,
	PlantType.TULIP: true,
	PlantType.BERRY: true,
	PlantType.APPLE: true,
	PlantType.SUNFLOWER: true,
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


## Seed colors cover all 13 types (unlike POLLEN_COLORS, which only covers
## the 5 base plants that actually offer pollen) — used for the seed pod
## swelling on the parent plant and the loose seed.tscn visual, both of
## which need to show a hybrid's color too.
const SEED_COLORS: Dictionary[PlantType, Color] = {
	PlantType.DAISY: Color(0.98, 0.98, 0.95),
	PlantType.TULIP: Color(1.0, 0.5, 0.75),
	PlantType.BERRY: Color(0.62, 0.3, 0.9),
	PlantType.APPLE: Color(0.88, 0.12, 0.12),
	PlantType.SUNFLOWER: Color(1.0, 0.58, 0.08),
	PlantType.ROSE: Color(0.95, 0.35, 0.45),
	PlantType.LAVENDER: Color(0.7, 0.6, 0.9),
	PlantType.STARBLOOM: Color(0.95, 0.92, 0.75),
	PlantType.ORCHID: Color(0.8, 0.35, 0.75),
	PlantType.FIRELILY: Color(0.95, 0.4, 0.15),
	PlantType.PLUM: Color(0.4, 0.15, 0.4),
	PlantType.PUMPKIN: Color(0.9, 0.5, 0.1),
	PlantType.CHERRY: Color(0.7, 0.05, 0.15),
}

## Human-readable names, used for the Step 5 combo chart's tooltips. These
## also double as the lookup key into seedling.tscn's Bloom/<Name> children
## (every Bloom child is named exactly one of these strings), so a second
## name table isn't needed for plant_icon_source.gd.
const DISPLAY_NAMES: Dictionary[PlantType, String] = {
	PlantType.DAISY: "Daisy",
	PlantType.TULIP: "Tulip",
	PlantType.BERRY: "Berry",
	PlantType.APPLE: "Apple",
	PlantType.SUNFLOWER: "Sunflower",
	PlantType.ROSE: "Rose",
	PlantType.LAVENDER: "Lavender",
	PlantType.STARBLOOM: "Starbloom",
	PlantType.ORCHID: "Orchid",
	PlantType.FIRELILY: "Firelily",
	PlantType.PLUM: "Plum",
	PlantType.PUMPKIN: "Pumpkin",
	PlantType.CHERRY: "Cherry",
}

static func pollen_color(type: PlantType) -> Color:
	return POLLEN_COLORS[type]


static func display_name(type: PlantType) -> String:
	return DISPLAY_NAMES[type]


static func accepts_pollen(type: PlantType) -> bool:
	return ACCEPTS_POLLEN.get(type, false)


static func seed_color(type: PlantType) -> Color:
	return SEED_COLORS[type]


static func _pair_key(a: PlantType, b: PlantType) -> int:
	return mini(a, b) * 100 + maxi(a, b)


## Returns the hybrid result of an unordered base-pair pollination, or NONE
## if the pair fizzles. Callers are expected to handle same-type (a == b)
## themselves before calling this.
static func combo_result(a: PlantType, b: PlantType) -> PlantType:
	return COMBO_TABLE.get(_pair_key(a, b), PlantType.NONE)


## Decodes COMBO_TABLE's packed keys back into their two base-type operands,
## so the Step 5 combo chart can be generated from this table instead of
## hand-listed. Each entry: {"a": PlantType, "b": PlantType, "result": PlantType}.
static func all_combos() -> Array[Dictionary]:
	var combos: Array[Dictionary] = []
	for key: int in COMBO_TABLE:
		var a: PlantType = key / 100 as PlantType
		var b: PlantType = key % 100 as PlantType
		combos.append({"a": a, "b": b, "result": COMBO_TABLE[key]})
	return combos
