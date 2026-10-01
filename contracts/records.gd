extends RefCounted
## Shapes of the records stored in camp state. Shared contract (AGENTS.md §4).
## Records are plain Dictionaries so they serialize and sync over the network.
## Use these makers so every record has every field; add fields, don't rename.

## Citizen record (owned by sim/, Lane B). Stored in CampState "citizens".
## Lane A reads it, and changes it only through request events.
static func citizen(id: int, citizen_name: String) -> Dictionary:
	return {
		"id": id,
		"name": citizen_name,
		"age": 30,
		"traits": [],  # trait ids
		"skills": {},  # skill id -> level 0..10
		"job": "",  # "" = unassigned; job ids like "builder", "soldier", "medic", "farmer"
		"health": 1.0,  # 0..1
		"infection_stage": 0,  # 0 = healthy; higher = further along (sim defines the stages)
		"mood": 0.5,  # 0..1
		"needs": {},  # need id -> 0..1 (1 = satisfied)
		"relationships": {},  # other citizen id -> -1..1
		"documents": [],  # document records; some may be forged
		"legal_status": "resident",  # "resident" | "visitor" | "quarantined" | "prisoner" | ...
		"faction": "",
		"is_recruit": false,
	}


## Building record (owned by Labor, Lane A). Stored in CampState "buildings".
static func building(id: int, type: String, position: Vector3) -> Dictionary:
	return {
		"id": id,
		"type": type,  # building type id, e.g. "house", "clinic", "workshop", "wall"
		"position": position,
		"rotation": 0.0,  # radians around Y
		"health": 1.0,  # 0..1
		"built": false,  # false while under construction
		"progress": 0.0,  # 0..1 construction progress
		"capacity": {},  # e.g. {"housing": 4} or {"beds": 2}; summed into capacity.<kind>
	}


## True if `record` has every field of `template` (extra fields are fine).
static func has_fields(record: Dictionary, template: Dictionary) -> bool:
	for key in template:
		if not record.has(key):
			return false
	return true
