extends Node
## Smoke test for sim/ (Lane B): citizen generation, request handling,
## economy, infection and daily arrivals.
## Run headless:  godot --headless --path . res://tests/b/sim_smoke.tscn

const SimScript := preload("res://sim/sim.gd")
const CitizenGen := preload("res://sim/citizen_gen.gd")
const Economy := preload("res://sim/economy.gd")
const Infection := preload("res://sim/infection.gd")

var _failures := 0
var _events: Array = []
var sim: Node


func _ready() -> void:
	sim = get_node_or_null("/root/Sim")
	if sim == null:
		sim = SimScript.new()
		add_child(sim)
	sim.rng.seed = 12345
	CampState.load_mock()
	for event_name in [&"survivor_admitted", &"survivor_quarantined", &"survivor_rejected", &"budget_allocated",
			&"policy_enacted", &"document_signed", &"citizen_turned", &"survivor_arrived"]:
		EventBus.subscribe(event_name, func(p: Dictionary) -> void: _events.append([event_name, p]))
	_run()
	print("sim_smoke: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _run() -> void:
	# A fresh mock camp gets citizens, a gate queue and an inbox.
	var citizens: Array = CampState.get_value("citizens")
	_check(citizens.size() == 12, "12 residents generated (%d)" % citizens.size())
	_check(citizens.all(func(c: Dictionary) -> bool: return c["job"] != "" and c["infection_stage"] == 0), "residents have jobs, are healthy")
	_check(CampState.get_value("gate.queue").size() == 3, "3 survivors at the gate")
	_check(CampState.get_value("documents.inbox").size() == 3, "3 documents in the inbox")
	_check(not get_node("/root/MockRules").enabled, "MockRules turned off")

	# Generator: forged papers have a tell.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var forged := 0
	for i in 200:
		var s := CitizenGen.survivor(rng, i, 3)
		if CitizenGen.has_forged_papers(s):
			forged += 1
			var id_card: Dictionary = s["documents"][0]
			var health: Dictionary = s["documents"][1]
			_check(id_card["name"] != s["name"] or id_card["age"] != s["age"] or health["valid_until"] < 3, "forgery has a tell")
	_check(forged > 10 and forged < 80, "some papers are forged (%d / 200)" % forged)

	# Resources: refused when it would go negative.
	var materials: int = CampState.get_value("res.materials")
	EventBus.emit_event(&"resource_change_requested", {"key": "res.materials", "amount": -10_000})
	_check(CampState.get_value("res.materials") == materials, "overdraft refused")
	EventBus.emit_event(&"resource_change_requested", {"key": "res.materials", "amount": -5})
	_check(CampState.get_value("res.materials") == materials - 5, "spend applied")
	EventBus.emit_event(&"resource_change_requested", {"key": "approval", "amount": 1})
	_check(CampState.get_value("approval") == 0.6, "non-resource key refused")

	# Gate decisions.
	var queue: Array = CampState.get_value("gate.queue")
	var first: int = queue[0]["id"]
	EventBus.emit_event(&"survivor_decision_requested", {"citizen_id": first, "decision": "admit"})
	_check(CampState.get_value("population") == 13, "admitted: population 13")
	_check(CampState.get_value("citizens").size() == 13, "admitted: 13 citizens")
	_check(_saw(&"survivor_admitted"), "survivor_admitted emitted")
	EventBus.emit_event(&"survivor_decision_requested", {"citizen_id": CampState.get_value("gate.queue")[0]["id"], "decision": "quarantine"})
	_check(CampState.get_value("population") == 13, "quarantined don't count as residents")
	_check(CampState.get_value("citizens").size() == 14, "quarantined are tracked")
	EventBus.emit_event(&"survivor_decision_requested", {"citizen_id": CampState.get_value("gate.queue")[0]["id"], "decision": "reject"})
	_check(CampState.get_value("gate.queue").is_empty(), "queue empty")
	_check(_saw(&"survivor_rejected"), "survivor_rejected emitted")

	# Budget: moving $100 from the treasury to Military.
	EventBus.emit_event(&"budget_allocation_requested", {"budget": {"military": 350}})
	_check(CampState.get_value("budget.military") == 350 and CampState.get_value("money") == 900, "budget moved")
	EventBus.emit_event(&"budget_allocation_requested", {"budget": {"labor": 99_999}})
	_check(CampState.get_value("budget.labor") == 250, "can't allocate more than the treasury")

	# Policies.
	EventBus.emit_event(&"policy_change_requested", {"policy_id": "rationing", "active": true})
	_check(CampState.get_value("policies.active") == ["rationing"], "rationing enacted")

	# Documents: signing applies effects and removes it from the inbox.
	var document: Dictionary = CampState.get_value("documents.inbox")[0]
	var before := CampState.snapshot()
	EventBus.emit_event(&"document_decision_requested", {"document_id": document["id"], "decision": "sign"})
	_check(CampState.get_value("documents.inbox").size() == 2, "document left the inbox")
	for key: String in document["effects_if_signed"]:
		_check(CampState.get_value(key) != before.get(key) or document["effects_if_signed"][key] == 0, "effect on %s applied" % key)

	# Economy formulas.
	var report := Economy.daily_report(CampState.snapshot())
	_check(report["food_used"] == ceili(13 * 0.7), "rationing cuts food use (%d)" % report["food_used"])
	_check(report["income"] == 13 * Economy.TAX_PER_CITIZEN, "income = tax x population")

	# Infection: a stage-3 resident turns tonight.
	var sick: Array = CampState.get_copy("citizens")
	sick[0]["infection_stage"] = 3
	CampState.set_value("citizens", sick)
	var food: int = CampState.get_value("res.food")
	_events.clear()
	for i in 3:  # morning -> day -> night -> next morning
		GameClock.advance_phase()
	_check(_saw(&"citizen_turned"), "infected citizen turned")
	_check(CampState.get_value("population") == 12, "population 12 after turning (%d)" % CampState.get_value("population"))
	_check(CampState.get_value("res.food") != food, "food changed overnight")
	_check(CampState.has_value("report.last_day"), "daily report written")
	_check(_saw(&"survivor_arrived"), "new survivors in the morning")

	# Infection model alone: quarantine stops spreading.
	var group: Array = []
	for i in 6:
		group.append(CitizenGen.resident(rng, 500 + i))
	group[0]["infection_stage"] = 2
	group[0]["legal_status"] = "quarantined"
	var spread_any := false
	for i in 30:
		var night := Infection.night(group, [], rng)
		if not night["infected"].is_empty():
			spread_any = true
	_check(not spread_any, "quarantined patient never spreads")


func _saw(event_name: StringName) -> bool:
	return _events.any(func(e: Array) -> bool: return e[0] == event_name)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)
