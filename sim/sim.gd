extends Node
## Camp simulation rules (autoload `Sim`, Lane B). Runs on the authority only.
##
## - Applies request events from every role: resources, survivor decisions,
##   budget allocation, policies, document decisions, job changes.
## - Each morning: survivors arrive at the gate, documents land in the inbox.
## - Each night: economy (income, food, water, production), infection, approval.
## - Fills a fresh camp with citizen records when there are none.
## - Ends the run (`run_ended`): PLACEHOLDER rules until O-08 is decided:
##   win by surviving TARGET_DAYS days; lose if the walls fall or nobody's left.
##
## Replaces core/mock_rules.gd (turns MockRules off on start).

const CitizenGen := preload("res://sim/citizen_gen.gd")
const DocumentGen := preload("res://sim/document_gen.gd")
const Economy := preload("res://sim/economy.gd")
const Infection := preload("res://sim/infection.gd")
const Policies := preload("res://sim/policies.gd")

const ROLES: Array[String] = ["politician", "military", "medic", "labor"]
const SURVIVORS_PER_DAY := Vector2i(2, 4)
const DOCUMENTS_PER_DAY := Vector2i(1, 3)
const MAX_QUEUE := 8
const MAX_INBOX := 8
## Keys any role may ask to change with resource_change_requested.
const RESOURCE_PREFIXES: Array[String] = ["res.", "budget.", "money"]
## Win condition placeholder (O-08 is open).
const TARGET_DAYS := 5

var rng := RandomNumberGenerator.new()
var run_over := false
var _next_id := 1000


func _ready() -> void:
	if has_node("/root/MockRules"):
		get_node("/root/MockRules").enabled = false
	for event_name: StringName in [
		&"resource_change_requested", &"survivor_decision_requested", &"budget_allocation_requested",
		&"policy_change_requested", &"document_decision_requested", &"citizen_job_change_requested",
		&"day_started", &"day_ended", &"camp_breached",
	]:
		EventBus.subscribe(event_name, Callable(self, "_on_" + String(event_name)))
	CampState.state_reset.connect(_on_state_reset)
	_on_state_reset()


## Fill in what a fresh camp needs: citizens matching `population`, a gate
## queue and an inbox so the Medic and Politician have something on day 1.
func _on_state_reset() -> void:
	run_over = false
	if not CampState.is_authority():
		return
	var citizens: Array = CampState.get_copy("citizens", [])
	var population: int = CampState.get_value("population", 0)
	if citizens.is_empty() and population > 0:
		for i in population:
			citizens.append(CitizenGen.resident(rng, _new_id()))
		CampState.set_value("citizens", citizens)
	else:
		for citizen: Dictionary in citizens:
			_next_id = maxi(_next_id, citizen["id"] + 1)
	if not CampState.has_value("gate.queue"):
		CampState.set_value("gate.queue", [])
		_survivors_arrive(3)
	if not CampState.has_value("documents.inbox"):
		CampState.set_value("documents.inbox", [])
		_documents_arrive(3)
	CampState.set_value("infection.level", Infection.level(CampState.get_value("citizens", [])))


# --- Requests -----------------------------------------------------------------

func _on_resource_change_requested(payload: Dictionary) -> void:
	if not CampState.is_authority():
		return
	var key: String = payload.get("key", "")
	var amount: Variant = payload.get("amount", 0)
	if not RESOURCE_PREFIXES.any(func(prefix: String) -> bool: return key.begins_with(prefix)) \
			or not (amount is int or amount is float):
		push_warning("Sim: refused resource change %s" % payload)
		return
	var current: Variant = CampState.get_value(key, 0)
	if amount < 0 and current + amount < 0:
		push_warning("Sim: not enough %s for %s" % [key, payload])
		return
	CampState.set_value(key, current + amount)


func _on_survivor_decision_requested(payload: Dictionary) -> void:
	if not CampState.is_authority():
		return
	var queue: Array = CampState.get_copy("gate.queue", [])
	var index := queue.find_custom(func(c: Dictionary) -> bool: return c["id"] == payload.get("citizen_id"))
	if index < 0:
		return
	var citizen: Dictionary = queue.pop_at(index)
	CampState.set_value("gate.queue", queue)
	match payload.get("decision", ""):
		"admit":
			citizen["legal_status"] = "resident"
			_add_citizen(citizen)
			EventBus.emit_event(&"survivor_admitted", {"citizen_id": citizen["id"]})
		"quarantine":
			citizen["legal_status"] = "quarantined"
			_add_citizen(citizen)
			EventBus.emit_event(&"survivor_quarantined", {"citizen_id": citizen["id"]})
		_:
			EventBus.emit_event(&"survivor_rejected", {"citizen_id": citizen["id"]})


func _on_budget_allocation_requested(payload: Dictionary) -> void:
	if not CampState.is_authority():
		return
	var wanted: Dictionary = payload.get("budget", {})
	var delta := 0
	for role: String in wanted:
		if ROLES.has(role):
			delta += int(wanted[role]) - int(CampState.get_value("budget." + role, 0))
	if delta > int(CampState.get_value("money", 0)):
		push_warning("Sim: budget needs $%d more than the treasury has" % delta)
		return
	for role: String in wanted:
		if ROLES.has(role):
			CampState.set_value("budget." + role, maxi(0, int(wanted[role])))
	CampState.add_value("money", -delta)
	var budget := {}
	for role in ROLES:
		budget[role] = CampState.get_value("budget." + role, 0)
	EventBus.emit_event(&"budget_allocated", {"budget": budget})


func _on_policy_change_requested(payload: Dictionary) -> void:
	if not CampState.is_authority():
		return
	var policy_id: String = payload.get("policy_id", "")
	if not Policies.POLICIES.has(policy_id):
		return
	var active: Array = CampState.get_copy("policies.active", [])
	var on: bool = payload.get("active", true)
	if on and not active.has(policy_id):
		active.append(policy_id)
		CampState.set_value("policies.active", active)
		EventBus.emit_event(&"policy_enacted", {"policy_id": policy_id})
	elif not on and active.has(policy_id):
		active.erase(policy_id)
		CampState.set_value("policies.active", active)
		EventBus.emit_event(&"policy_revoked", {"policy_id": policy_id})


func _on_document_decision_requested(payload: Dictionary) -> void:
	if not CampState.is_authority():
		return
	var inbox: Array = CampState.get_copy("documents.inbox", [])
	var index := inbox.find_custom(func(d: Dictionary) -> bool: return d["id"] == payload.get("document_id"))
	if index < 0:
		return
	var document: Dictionary = inbox.pop_at(index)
	var signed: bool = payload.get("decision") == "sign"
	var effects: Dictionary = document["effects_if_signed" if signed else "effects_if_rejected"]
	if signed and int(CampState.get_value("money", 0)) + int(effects.get("money", 0)) < 0:
		push_warning("Sim: can't afford document %d" % document["id"])
		return
	CampState.set_value("documents.inbox", inbox)
	_apply_effects(effects)
	EventBus.emit_event(&"document_signed" if signed else &"document_rejected",
		{"document_id": document["id"], "from_role": document["from_role"]})


func _on_citizen_job_change_requested(payload: Dictionary) -> void:
	if not CampState.is_authority():
		return
	var citizens: Array = CampState.get_copy("citizens", [])
	for citizen: Dictionary in citizens:
		if citizen["id"] == payload.get("citizen_id"):
			citizen["job"] = payload.get("job", "")
			CampState.set_value("citizens", citizens)
			return


# --- Clock ------------------------------------------------------------------

func _on_day_started(_payload: Dictionary) -> void:
	if not CampState.is_authority():
		return
	var active: Array = CampState.get_value("policies.active", [])
	var count := roundi(rng.randi_range(SURVIVORS_PER_DAY.x, SURVIVORS_PER_DAY.y) * Policies.modifier(active, "survivors", 1.0))
	_survivors_arrive(count)
	_documents_arrive(rng.randi_range(DOCUMENTS_PER_DAY.x, DOCUMENTS_PER_DAY.y))


func _on_day_ended(payload: Dictionary) -> void:
	if not CampState.is_authority():
		return
	var report := Economy.daily_report(CampState.snapshot())
	report["day"] = payload.get("day", CampState.get_value("day", 1))
	CampState.add_value("money", report["income"] - report["cost"])
	CampState.set_value("res.food", maxi(0, CampState.get_value("res.food", 0) + report["food_made"] - report["food_used"]))
	CampState.set_value("res.water", maxi(0, CampState.get_value("res.water", 0) + report["water_made"] - report["water_used"]))
	CampState.add_value("res.parts", report["parts_made"])
	CampState.add_value("res.materials", -report["materials_used"])

	var night := Infection.night(CampState.get_value("citizens", []), CampState.get_value("policies.active", []), rng)
	CampState.set_value("citizens", night["citizens"])
	CampState.set_value("population", night["citizens"].filter(func(c: Dictionary) -> bool:
		return c["legal_status"] == "resident").size())
	CampState.set_value("infection.level", Infection.level(night["citizens"]))
	for citizen_id in night["infected"]:
		EventBus.emit_event(&"citizen_infected", {"citizen_id": citizen_id})
	for citizen: Dictionary in night["turned"]:
		EventBus.emit_event(&"citizen_turned", {"citizen_id": citizen["id"], "name": citizen["name"]})
	report["turned"] = night["turned"].size()
	report["infected"] = night["infected"].size()

	CampState.set_value("approval", clampf(CampState.get_value("approval", 0.5) + report["approval_delta"], 0.0, 1.0))
	CampState.set_value("report.last_day", report)

	if CampState.get_value("population", 0) <= 0:
		_end_run("everyone_gone")
	elif report["day"] >= TARGET_DAYS:
		_end_run("survived")


func _on_camp_breached(payload: Dictionary) -> void:
	if CampState.is_authority() and payload.get("integrity", 1.0) <= 0.0:
		_end_run("walls_fell")


func _end_run(reason: String) -> void:
	if run_over:
		return
	run_over = true
	EventBus.emit_event(&"run_ended", {
		"reason": reason, "won": reason == "survived", "day": CampState.get_value("day", 1),
		"population": CampState.get_value("population", 0), "target_days": TARGET_DAYS,
	})


# --- Helpers ------------------------------------------------------------------

func _survivors_arrive(count: int) -> void:
	var queue: Array = CampState.get_copy("gate.queue", [])
	var day: int = CampState.get_value("day", 1)
	var chance := CitizenGen.INFECTED_CHANCE * Policies.modifier(CampState.get_value("policies.active", []), "infected_chance", 1.0)
	for i in count:
		if queue.size() >= MAX_QUEUE:
			break
		var survivor := CitizenGen.survivor(rng, _new_id(), day, chance)
		queue.append(survivor)
		EventBus.emit_event(&"survivor_arrived", {"citizen": survivor})
	CampState.set_value("gate.queue", queue)


func _documents_arrive(count: int) -> void:
	var inbox: Array = CampState.get_copy("documents.inbox", [])
	var day: int = CampState.get_value("day", 1)
	for i in count:
		if inbox.size() >= MAX_INBOX:
			break
		inbox.append(DocumentGen.make(rng, _new_id(), day))
	CampState.set_value("documents.inbox", inbox)


func _add_citizen(citizen: Dictionary) -> void:
	var citizens: Array = CampState.get_copy("citizens", [])
	citizens.append(citizen)
	CampState.set_value("citizens", citizens)
	if citizen["legal_status"] == "resident":
		CampState.add_value("population", 1)
	CampState.set_value("infection.level", Infection.level(citizens))


func _apply_effects(effects: Dictionary) -> void:
	for key: String in effects:
		var value: Variant = CampState.get_value(key, 0)
		if key == "approval":
			CampState.set_value(key, clampf(value + effects[key], 0.0, 1.0))
		else:
			CampState.set_value(key, maxi(0, value + effects[key]))


func _new_id() -> int:
	_next_id += 1
	return _next_id
