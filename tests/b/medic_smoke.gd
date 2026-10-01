extends Node
## Smoke test for the Medic check-in desk (Lane B): exams reveal the truth,
## the exam budget runs out, decisions go to sim, quarantine needs beds.
## Run headless:  godot --headless --path . res://tests/b/medic_smoke.tscn

const ViewScene := preload("res://roles/medic/medic_view.tscn")

var _failures := 0


func _ready() -> void:
	CampState.load_mock()
	var view := ViewScene.instantiate()
	add_child(view)
	view.open_view(self)
	_run(view)
	print("medic_smoke: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _run(view: Node) -> void:
	var queue: Array = CampState.get_value("gate.queue")
	_check(queue.size() == 3, "3 survivors waiting")
	_check(view.current()["id"] == queue[0]["id"], "first in line is examined")

	# Plant a known patient: bitten, with a fever.
	var patient: Dictionary = view.current().duplicate(true)
	patient["symptoms"] = ["bite", "fever"]
	patient["infection_stage"] = 1
	queue = CampState.get_copy("gate.queue")
	queue[0] = patient
	CampState.set_value("gate.queue", queue)
	_check(view.exam(2).contains("BITE"), "arms exam finds the bite")
	_check(view.exam(0).contains("39.8"), "thermometer finds the fever")
	_check(view.exam(1) == "Eyes look fine.", "flashlight finds nothing")
	_check(view.exam(3) == "", "only 3 exams per survivor")

	# Reject: leaves the queue, nobody joins the camp.
	var population: int = CampState.get_value("population")
	view.decide("reject")
	_check(CampState.get_value("gate.queue").size() == 2, "rejected survivor left the queue")
	_check(CampState.get_value("population") == population, "population unchanged")

	# Admit the next one.
	view.decide("admit")
	_check(CampState.get_value("population") == population + 1, "admitted survivor is a resident")

	# Quarantine needs a free bed.
	CampState.set_value("capacity.beds", 0)
	view.decide("quarantine")
	_check(CampState.get_value("gate.queue").size() == 1, "no quarantine without beds")
	CampState.set_value("capacity.beds", 2)
	view.decide("quarantine")
	_check(CampState.get_value("gate.queue").is_empty(), "quarantined with a free bed")
	var quarantined: Array = CampState.get_value("citizens").filter(func(c: Dictionary) -> bool:
		return c["legal_status"] == "quarantined")
	_check(quarantined.size() == 1, "one patient in quarantine")
	_check(view.current().is_empty(), "nobody left to examine")


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)
