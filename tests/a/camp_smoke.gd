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
	_check(camp.views.has("military") and camp.views.has("labor"), "Lane A views loaded")
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

	# Desk roles without a view yet don't crash.
	camp.control("politician")
	_check(camp.controlled_role == "politician", "switched to Politician")
	camp.try_interact()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)


func _quit() -> void:
	print("camp_smoke: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)
