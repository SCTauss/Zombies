extends RefCounted
## Generates documents for the Politician's inbox: requests from the other
## roles and petitions from citizens. Each has effects if signed / rejected,
## applied by sim (state key -> delta).

const Records := preload("res://contracts/records.gd")

const TEMPLATES: Array[Dictionary] = [
	{
		"kind": "budget_request", "from": "military", "title": "More bullets, please",
		"body": "The night shift keeps running out of ammo. Requesting $%d for the armory.",
		"amount": [60, 140], "signed": {"budget.military": 1, "money": -1}, "rejected": {"approval": -0.01},
	},
	{
		"kind": "budget_request", "from": "labor", "title": "Lumber shipment",
		"body": "We found a lumber yard. $%d buys us a truck of materials.",
		"amount": [40, 100], "signed": {"res.materials": 1, "money": -1}, "rejected": {},
	},
	{
		"kind": "budget_request", "from": "medic", "title": "Medical supplies",
		"body": "Bandages are made of old socks now. $%d for real medicine.",
		"amount": [50, 120], "signed": {"res.medicine": 0.2, "money": -1}, "rejected": {"approval": -0.01},
	},
	{
		"kind": "petition", "from": "citizens", "title": "Double rations night",
		"body": "The people demand a feast! It would cost %d food.",
		"amount": [10, 25], "signed": {"res.food": -1, "approval": 0.04}, "rejected": {"approval": -0.03},
	},
	{
		"kind": "petition", "from": "citizens", "title": "Fix the roof, Mayor!",
		"body": "Rain is leaking into the bunkhouse. Give Labor $%d to patch it up.",
		"amount": [30, 60], "signed": {"budget.labor": 1, "money": -1, "approval": 0.02}, "rejected": {"approval": -0.02},
	},
	{
		"kind": "permit", "from": "military", "title": "Permission to blow something up",
		"body": "There is a horde nest outside the east gate. Dynamite costs %d materials.",
		"amount": [15, 30], "signed": {"res.materials": -1, "approval": 0.02}, "rejected": {"approval": -0.01},
	},
]


## A random document for `day`. Amounts scale each effect: 1 = +amount, -1 = -amount,
## other numbers multiply; effects on "approval" are used as-is.
static func make(rng: RandomNumberGenerator, id: int, day: int) -> Dictionary:
	var template: Dictionary = TEMPLATES[rng.randi() % TEMPLATES.size()]
	var amount := rng.randi_range(template["amount"][0], template["amount"][1])
	var document := Records.document(id, template["kind"], template["from"], template["title"])
	document["body"] = template["body"] % amount
	document["day"] = day
	document["effects_if_signed"] = _scaled(template["signed"], amount)
	document["effects_if_rejected"] = _scaled(template["rejected"], amount)
	return document


static func _scaled(effects: Dictionary, amount: int) -> Dictionary:
	var result := {}
	for key: String in effects:
		if key == "approval":
			result[key] = effects[key]
		elif effects[key] != 0:
			result[key] = roundi(effects[key] * amount)
	return result
