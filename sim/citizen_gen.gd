extends RefCounted
## Generates citizen records (contracts/records.gd) and their papers.
## Survivors at the gate may be infected (hidden `infection_stage`) and may
## carry forged documents; the Medic finds out by checking them.
## Pass a RandomNumberGenerator so runs can be seeded.

const Records := preload("res://contracts/records.gd")

const FIRST_NAMES: Array[String] = [
	"Bob", "Doris", "Gus", "Marge", "Pip", "Rita", "Otto", "Nell", "Hank", "Ivy", "Lou", "Mabel",
	"Ned", "Olga", "Rex", "Sue", "Tito", "Vera", "Walt", "Zelda", "Buzz", "Clem", "Dot", "Fritz",
]
const LAST_NAMES: Array[String] = [
	"Potts", "Crumb", "Wobble", "Bunker", "Picklesby", "Hatch", "Moss", "Grubb", "Tumble", "Fink",
	"Shovel", "Noodle", "Barker", "Gristle", "Puddle", "Sprocket",
]
const TRAITS: Array[String] = [
	"brave", "coward", "lazy", "hard_worker", "gossip", "optimist", "pessimist",
	"clumsy", "green_thumb", "night_owl", "glutton", "tough",
]
const SKILLS: Array[String] = ["building", "shooting", "medicine", "farming", "talking"]
const JOB_FOR_SKILL := {
	"building": "builder", "shooting": "soldier", "medicine": "medic", "farming": "farmer", "talking": "clerk",
}
## Symptoms of the virus, and harmless look-alikes healthy people can have too.
const INFECTED_SYMPTOMS: Array[String] = ["fever", "bite", "red_eyes", "shaking", "grey_skin"]
const HARMLESS_SYMPTOMS: Array[String] = ["cough", "rash", "sneezing", "limp"]
const INFECTED_CHANCE := 0.3
const FORGED_CHANCE := 0.2


## A survivor arriving at the gate on `day`.
static func survivor(rng: RandomNumberGenerator, id: int, day: int, infected_chance := INFECTED_CHANCE) -> Dictionary:
	var citizen := _person(rng, id)
	citizen["arrived_day"] = day
	citizen["legal_status"] = "visitor"
	if rng.randf() < infected_chance:
		citizen["infection_stage"] = 1
		# Early infections don't always show: 0-2 real symptoms.
		var shown := rng.randi_range(0, 2)
		for symptom in _pick(rng, INFECTED_SYMPTOMS, shown):
			citizen["symptoms"].append(symptom)
	if rng.randf() < 0.35:
		citizen["symptoms"].append(HARMLESS_SYMPTOMS[rng.randi() % HARMLESS_SYMPTOMS.size()])
	citizen["documents"] = _papers(rng, citizen, day)
	return citizen


## A healthy resident for the starting camp, with a job.
static func resident(rng: RandomNumberGenerator, id: int) -> Dictionary:
	var citizen := _person(rng, id)
	var best := ""
	for skill: String in citizen["skills"]:
		if best == "" or citizen["skills"][skill] > citizen["skills"][best]:
			best = skill
	citizen["job"] = JOB_FOR_SKILL[best]
	citizen["documents"] = _papers(rng, citizen, 1, false)
	return citizen


## True if any of the citizen's papers is forged (for tests and the Medic's results).
static func has_forged_papers(citizen: Dictionary) -> bool:
	return citizen["documents"].any(func(d: Dictionary) -> bool: return d.get("forged", false))


static func _person(rng: RandomNumberGenerator, id: int) -> Dictionary:
	var full_name := "%s %s" % [FIRST_NAMES[rng.randi() % FIRST_NAMES.size()], LAST_NAMES[rng.randi() % LAST_NAMES.size()]]
	var citizen := Records.citizen(id, full_name)
	citizen["age"] = rng.randi_range(16, 78)
	citizen["traits"] = _pick(rng, TRAITS, rng.randi_range(1, 2))
	for skill in SKILLS:
		citizen["skills"][skill] = rng.randi_range(0, 10)
	citizen["needs"] = {"food": 1.0, "rest": 1.0, "safety": 0.7}
	citizen["mood"] = rng.randf_range(0.4, 0.8)
	return citizen


## ID card + health certificate. Forged papers have one tell: wrong name,
## wrong age, or an expired date.
static func _papers(rng: RandomNumberGenerator, citizen: Dictionary, day: int, may_forge := true) -> Array:
	var id_card := {"kind": "id_card", "name": citizen["name"], "age": citizen["age"], "forged": false}
	var health := {
		"kind": "health_certificate", "name": citizen["name"],
		"clean": citizen["infection_stage"] == 0, "valid_until": day + rng.randi_range(2, 10), "forged": false,
	}
	if may_forge and rng.randf() < FORGED_CHANCE:
		match rng.randi() % 3:
			0:
				id_card["name"] = "%s %s" % [FIRST_NAMES[rng.randi() % FIRST_NAMES.size()], citizen["name"].get_slice(" ", 1)]
				id_card["forged"] = true
			1:
				id_card["age"] = citizen["age"] + rng.randi_range(8, 20)
				id_card["forged"] = true
			_:
				health["valid_until"] = day - rng.randi_range(1, 5)
				health["forged"] = true
	# An infected person with forged papers claims to be clean.
	if citizen["infection_stage"] > 0 and (id_card["forged"] or health["forged"]):
		health["clean"] = true
	return [id_card, health]


static func _pick(rng: RandomNumberGenerator, from: Array[String], count: int) -> Array:
	var pool := from.duplicate()
	var result := []
	for i in mini(count, pool.size()):
		result.append(pool.pop_at(rng.randi() % pool.size()))
	return result
