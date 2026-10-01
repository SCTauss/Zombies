extends RefCounted
## Mock camp state so every role scene runs on its own (F6).
## Keys follow contracts/state_*.gd. Numbers are placeholders.
## The camp starts with a few finished buildings; capacity.* matches them.

const Records := preload("res://contracts/records.gd")

## [type, position, capacity] of the starting buildings.
const STARTING_BUILDINGS := [
	["house", Vector3(-14, 0, -7), {"housing": 4}],
	["house", Vector3(-14, 0, -13), {"housing": 4}],
	["house", Vector3(-8, 0, -13), {"housing": 4}],
	["clinic", Vector3(10, 0, -13), {"beds": 3}],
	["lab", Vector3(14, 0, -7), {"labs": 1}],
	["farm", Vector3(-11, 0, 11), {"farms": 1}],
	["water_tower", Vector3(12, 0, 12), {"water": 1}],
]


static func create_state() -> Dictionary:
	var buildings: Array = []
	var capacity := {"housing": 0, "beds": 0, "labs": 0, "workshops": 0, "farms": 0, "water": 0}
	for entry in STARTING_BUILDINGS:
		var record := Records.building(buildings.size() + 1, entry[0], entry[1])
		record["built"] = true
		record["progress"] = 1.0
		record["capacity"] = entry[2].duplicate()
		buildings.append(record)
		for kind: String in entry[2]:
			capacity[kind] += entry[2][kind]
	var state := {
		"day": 1,
		"day_phase": "morning",
		"money": 1000,
		"budget.politician": 250,
		"budget.military": 250,
		"budget.medic": 250,
		"budget.labor": 250,
		"res.food": 100,
		"res.water": 100,
		"res.materials": 80,
		"res.parts": 20,
		"res.medicine": 15,
		"res.ammo": 200,
		"res.fuel": 30,
		"population": 12,
		"citizens": [],
		"approval": 0.6,
		"infection.level": 0.0,
		"policies.active": [],
		"defense.integrity": 1.0,
		"buildings": buildings,
		"blueprints.known": [],
		"research.done": [],
	}
	for kind: String in capacity:
		state["capacity." + kind] = capacity[kind]
	return state
