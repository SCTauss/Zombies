extends RefCounted
## Mock camp state so every role scene runs on its own (F6).
## Keys follow docs/CONTRACTS.md. Numbers are placeholders.


static func create_state() -> Dictionary:
	return {
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
		"buildings": [],
		"capacity.housing": 15,
		"capacity.beds": 4,
		"capacity.labs": 1,
		"blueprints.known": [],
		"research.done": [],
	}
