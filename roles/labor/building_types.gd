extends RefCounted
## Prefab building types for Labor. Placeholder numbers.
## `size` is the footprint in meters (X, Z). `cost` keys: "budget" (from
## budget.labor) and "materials" (res.materials). `capacity` is added to
## camp state capacity.<kind> once the building is finished.

const TYPES := {
	"house": {
		"name": "House", "size": Vector2(4, 4), "build_time": 5.0,
		"cost": {"budget": 40, "materials": 20}, "capacity": {"housing": 4},
	},
	"clinic": {
		"name": "Clinic", "size": Vector2(5, 4), "build_time": 8.0,
		"cost": {"budget": 80, "materials": 30}, "capacity": {"beds": 3},
	},
	"lab": {
		"name": "Lab", "size": Vector2(4, 4), "build_time": 10.0,
		"cost": {"budget": 120, "materials": 40}, "capacity": {"labs": 1},
	},
	"workshop": {
		"name": "Workshop", "size": Vector2(5, 5), "build_time": 7.0,
		"cost": {"budget": 60, "materials": 30}, "capacity": {"workshops": 1},
	},
	"farm": {
		"name": "Farm", "size": Vector2(6, 4), "build_time": 4.0,
		"cost": {"budget": 30, "materials": 10}, "capacity": {"farms": 1},
	},
	"water_tower": {
		"name": "Water tower", "size": Vector2(3, 3), "build_time": 6.0,
		"cost": {"budget": 50, "materials": 25}, "capacity": {"water": 1},
	},
}

## Build menu order (hotkeys 1..6).
const ORDER: Array[String] = ["house", "clinic", "lab", "workshop", "farm", "water_tower"]


static func get_type(type_id: String) -> Dictionary:
	return TYPES[type_id]


## Half the footprint (X, Z) for placement checks. A quarter or three-quarter
## turn swaps the sides.
static func half_extents(type_id: String, rotation := 0.0) -> Vector2:
	var half: Vector2 = TYPES[type_id]["size"] / 2.0
	var quarter_turns := roundi(rotation / (PI / 2.0))
	return Vector2(half.y, half.x) if absi(quarter_turns) % 2 == 1 else half


## Every capacity kind any building gives, so totals can be reset to 0.
static func capacity_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for type_id in TYPES:
		for kind: String in TYPES[type_id]["capacity"]:
			if not kinds.has(kind):
				kinds.append(kind)
	return kinds
