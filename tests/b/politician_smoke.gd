extends Node
## Smoke test for the Politician desk (Lane B): documents, budget, policies.
## Run headless:  godot --headless --path . res://tests/b/politician_smoke.tscn

const ViewScene := preload("res://roles/politician/politician_view.tscn")

var _failures := 0


func _ready() -> void:
	CampState.load_mock()
	var view := ViewScene.instantiate()
	add_child(view)
	view.open_view(self)
	_run(view)
	print("politician_smoke: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _run(view: Node) -> void:
	# Inbox: sign the first document; it leaves the inbox and its effects apply.
	var inbox: Array = CampState.get_value("documents.inbox")
	_check(inbox.size() == 3, "3 documents waiting")
	var document: Dictionary = view.selected_document()
	_check(document["id"] == inbox[0]["id"], "first document selected")
	var money: int = CampState.get_value("money")
	view.decide_document("sign")
	_check(CampState.get_value("documents.inbox").size() == 2, "signed document left the inbox")
	_check(CampState.get_value("money") == money + int(document["effects_if_signed"].get("money", 0)), "money effect applied")
	view.decide_document("reject")
	_check(CampState.get_value("documents.inbox").size() == 1, "rejected document left the inbox")

	# Budget: draft first, apply moves money from the treasury.
	# (Signed documents above may already have changed budgets, so compare to "before".)
	money = CampState.get_value("money")
	var military: int = CampState.get_value("budget.military")
	var labor: int = CampState.get_value("budget.labor")
	view.show_tab(1)
	view.nudge_budget("military", 25)
	view.nudge_budget("military", 25)
	view.nudge_budget("labor", -25)
	_check(CampState.get_value("budget.military") == military, "draft doesn't change state yet")
	view.apply_budget()
	_check(CampState.get_value("budget.military") == military + 50, "military budget raised by 50")
	_check(CampState.get_value("budget.labor") == labor - 25, "labor budget cut by 25")
	_check(CampState.get_value("money") == money - 25, "treasury paid the difference")

	# Policies toggle.
	view.show_tab(2)
	view.toggle_policy("curfew")
	_check(CampState.get_value("policies.active").has("curfew"), "curfew enacted")
	view.toggle_policy("curfew")
	_check(not CampState.get_value("policies.active").has("curfew"), "curfew revoked")

	# Report tab copes with no report and with one.
	view.show_tab(3)
	for i in 3:
		GameClock.advance_phase()
	view.show_tab(3)
	_check(view._report.text.begins_with("LAST NIGHT"), "report shows last night")


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)
