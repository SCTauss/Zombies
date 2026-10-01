extends RefCounted
## Policies v1 (Politician). Placeholder numbers. `modifiers` are read by the
## economy and sim rules; `approval_per_day` is applied each night while active.

const POLICIES := {
	"rationing": {
		"name": "Rationing", "desc": "Everyone eats 30% less. Grumbling guaranteed.",
		"modifiers": {"food_use": 0.7}, "approval_per_day": -0.03,
	},
	"tax_hike": {
		"name": "Tax hike", "desc": "+50% income. Nobody likes you.",
		"modifiers": {"income": 1.5}, "approval_per_day": -0.04,
	},
	"open_gates": {
		"name": "Open gates", "desc": "Twice the survivors arrive. Some of them are definitely bitten.",
		"modifiers": {"survivors": 2.0, "infected_chance": 1.4}, "approval_per_day": 0.02,
	},
	"curfew": {
		"name": "Curfew", "desc": "Infection spreads half as fast. Freedom-lovers fume.",
		"modifiers": {"spread": 0.5}, "approval_per_day": -0.02,
	},
	"festival": {
		"name": "Weekly festival", "desc": "Costs $40 a day. People love a party.",
		"modifiers": {"daily_cost": 40}, "approval_per_day": 0.05,
	},
}


static func modifier(active: Array, key: String, default: float) -> float:
	var value := default
	for policy_id in active:
		var mods: Dictionary = POLICIES.get(policy_id, {}).get("modifiers", {})
		if mods.has(key):
			if key == "daily_cost":
				value += mods[key]
			else:
				value *= mods[key]
	return value


static func approval_per_day(active: Array) -> float:
	var total := 0.0
	for policy_id in active:
		total += POLICIES.get(policy_id, {}).get("approval_per_day", 0.0)
	return total
