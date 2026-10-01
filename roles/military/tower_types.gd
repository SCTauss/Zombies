extends RefCounted
## Defense types and their upgrade path (BTD6-style tiers). Placeholder numbers.
## Tier 0 `cost` is the build cost; later tiers' `cost` is the upgrade cost.

const TYPES := {
	"watchtower": {
		"name": "Watchtower",
		"tiers": [
			{"label": "Rifle", "cost": 60, "damage": 8.0, "range": 8.0, "fire_rate": 1.2},
			{"label": "Scoped rifle", "cost": 40, "damage": 12.0, "range": 10.0, "fire_rate": 1.4},
			{"label": "Marksman", "cost": 80, "damage": 20.0, "range": 12.0, "fire_rate": 1.6},
			{"label": "Sniper nest", "cost": 140, "damage": 40.0, "range": 15.0, "fire_rate": 1.6},
		],
	},
}


static func tier(type_id: String, index: int) -> Dictionary:
	return TYPES[type_id]["tiers"][index]


static func tier_count(type_id: String) -> int:
	return TYPES[type_id]["tiers"].size()


static func display_name(type_id: String) -> String:
	return TYPES[type_id]["name"]
