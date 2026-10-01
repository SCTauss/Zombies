extends RefCounted
## Infection model v1. Each night: infected citizens get worse, and at
## TURN_STAGE they turn. Infected people who aren't quarantined may infect a
## healthy resident. Quarantined patients don't spread it.

const Policies := preload("res://sim/policies.gd")

const TURN_STAGE := 4
const SPREAD_FROM_STAGE := 2
const SPREAD_CHANCE := 0.25
const SYMPTOMS_BY_STAGE := {2: "fever", 3: "grey_skin"}


## Advance one night. Returns {citizens (updated copy), turned: [records], infected: [ids]}.
static func night(citizens: Array, active_policies: Array, rng: RandomNumberGenerator) -> Dictionary:
	var updated: Array = citizens.duplicate(true)
	var turned: Array = []
	var newly_infected: Array = []
	var spread := SPREAD_CHANCE * Policies.modifier(active_policies, "spread", 1.0)
	var healthy: Array = updated.filter(func(c: Dictionary) -> bool:
		return c["infection_stage"] == 0 and c["legal_status"] == "resident")
	# Only people infected before tonight get worse tonight.
	var sick: Array = updated.filter(func(c: Dictionary) -> bool: return c["infection_stage"] > 0)
	for citizen: Dictionary in sick:
		citizen["infection_stage"] += 1
		var symptom: String = SYMPTOMS_BY_STAGE.get(citizen["infection_stage"], "")
		if symptom != "" and not citizen["symptoms"].has(symptom):
			citizen["symptoms"].append(symptom)
		citizen["health"] = maxf(0.0, citizen["health"] - 0.25)
		if citizen["infection_stage"] >= TURN_STAGE:
			turned.append(citizen)
		elif citizen["infection_stage"] >= SPREAD_FROM_STAGE and citizen["legal_status"] != "quarantined" \
				and not healthy.is_empty() and rng.randf() < spread:
			var victim: Dictionary = healthy.pop_at(rng.randi() % healthy.size())
			victim["infection_stage"] = 1
			newly_infected.append(victim["id"])
	for citizen in turned:
		updated.erase(citizen)
	return {"citizens": updated, "turned": turned, "infected": newly_infected}


## Share of the population that is infected (0..1).
static func level(citizens: Array) -> float:
	if citizens.is_empty():
		return 0.0
	var infected := citizens.filter(func(c: Dictionary) -> bool: return c["infection_stage"] > 0).size()
	return float(infected) / citizens.size()
