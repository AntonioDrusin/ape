class_name PlantData

## Single source of truth for plant data (REQUIREMENTS.md "Architectural
## direction"): plant types, pollen colors, and — as later steps land — the
## hybrid combo table and display names. Gameplay and UI both read from here;
## nothing else may hardcode this data.

enum PlantType { DAISY, TULIP, BERRY, APPLE, SUNFLOWER }

## Pollen colors must stay tellable apart at bee-butt size and against all
## level backgrounds (see the readability notes in REQUIREMENTS.md).
const POLLEN_COLORS: Dictionary[PlantType, Color] = {
	PlantType.DAISY: Color(0.98, 0.98, 0.95),
	PlantType.TULIP: Color(1.0, 0.5, 0.75),
	PlantType.BERRY: Color(0.62, 0.3, 0.9),
	PlantType.APPLE: Color(0.88, 0.12, 0.12),
	PlantType.SUNFLOWER: Color(1.0, 0.58, 0.08),
}


static func pollen_color(type: PlantType) -> Color:
	return POLLEN_COLORS[type]
