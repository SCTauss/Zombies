extends Node
## Smoke test for the shared camp (H-009): 4 characters and stations, walking,
## station interaction opens/closes role views, Tab-style switching.
## Run headless:  godot --headless --path . res://tests/a/camp_smoke.tscn

const CampScene := preload("res://world/camp/camp_main.tscn")

const TIMEOUT := 60.0

var _failures := 0


func _ready() -> void:
	get_tree().create_timer(TIMEOUT, true, false, true).timeout.connect(func() -> void:
		_check(false, "timeout")
		_quit())
	CampState.load_mock()
	await _run()
	_quit()


func _run() -> void:
	var camp := CampScene.instantiate()
	add_child(camp)
	if not camp.map.is_navigation_ready:
		await camp.map.navigation_ready

	_check(camp.players.size() == 4, "4 player characters")
	_check(camp.stations.size() == 4, "4 stations")
	_check(camp.views.size() == 4, "all 4 role views loaded (%s)" % [camp.views.keys()])
	_check(camp.controlled_role == "military", "starts as Military")
	_check(camp.follow_camera.camera.current, "third-person camera active")

	# Each character starts at its own station.
	for role: String in camp.players:
		_check(camp.stations[role].in_range(camp.players[role].global_position), "%s starts at its station" % role)

	# Walking: push the Military character away from the station for a bit.
	var player: Node3D = camp.players["military"]
	var start := player.global_position
	player.move_override = Vector3(-1, 0, 0)  # toward the road, away from every station
	await get_tree().create_timer(0.8).timeout
	player.move_override = Vector3.ZERO
	_check(player.global_position.distance_to(start) > 2.0, "player walked (%.1f m)" % player.global_position.distance_to(start))
	_check(player.is_on_floor(), "player stands on the ground")
	_check(not camp.try_interact(), "nothing to use away from the station")

	# Back to the station: E opens the Military view with the top-down camera.
	player.global_position = start
	await get_tree().physics_frame
	_check(camp.try_interact(), "interact at own station")
	_check(camp.active_view == "military", "military view open")
	_check(camp.views["military"].is_open, "view got open_view()")
	_check(camp.top_down_camera().camera.current, "top-down camera active in the view")
	_check(not player.input_enabled, "walking disabled inside the view")

	# Leaving through the view's exit signal.
	camp.views["military"].exit_requested.emit()
	_check(camp.active_view == "", "view closed")
	_check(not camp.views["military"].is_open, "view got close_view()")
	_check(camp.follow_camera.camera.current, "back to third-person camera")
	_check(player.input_enabled, "walking enabled again")

	# Someone else's station: Labor's character can't open Military's table.
	camp.control("labor")
	camp.players["labor"].global_position = start
	await get_tree().physics_frame
	_check(not camp.try_interact(), "can't use another role's station")
	_check(camp.active_view == "", "no view opened")

	# A desk role: the Politician opens the office from its own desk.
	camp.control("politician")
	_check(camp.controlled_role == "politician", "switched to Politician")
	_check(camp.try_interact(), "Politician uses the office desk")
	_check(camp.active_view == "politician" and camp.views["politician"].is_open, "office view open")
	camp.views["politician"].exit_requested.emit()
	_check(camp.active_view == "", "office closed")

	# Esc menu: freezes your character while open.
	camp._toggle_pause()
	_check(camp._pause.visible and not camp.players["politician"].input_enabled, "menu open, walking off")
	camp._toggle_pause()
	_check(not camp._pause.visible and camp.players["politician"].input_enabled, "menu closed, walking on")

	# Labor's workers panel: a job change goes to sim.
	var WorkersPanel := load("res://roles/labor/workers_panel.gd")
	var citizen: Dictionary = CampState.get_value("citizens")[0]
	var next: String = WorkersPanel.next_job(citizen["job"])
	EventBus.emit_event(&"citizen_job_change_requested", {"citizen_id": citizen["id"], "job": next})
	_check(CampState.get_value("citizens")[0]["job"] == next, "job changed to %s" % next)

	# Run end: the end screen takes over and the clock stops.
	EventBus.emit_event(&"run_ended", {"reason": "survived", "won": true, "day": 5, "population": 12})
	_check(camp.run_result.get("won", false), "camp got the run result")
	_check(not GameClock.auto_advance, "clock stopped")
	_check(not camp.players[camp.controlled_role].input_enabled, "walking off on the end screen")


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)


func _quit() -> void:
	print("camp_smoke: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)
