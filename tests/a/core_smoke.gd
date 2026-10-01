extends Node
## Smoke test for core/ autoloads. No test framework yet (O-07 is open).
## Run headless:  godot --headless --path . res://tests/a/core_smoke.tscn
## Exits with code 0 if every check passes, 1 otherwise.

var _failures := 0


func _ready() -> void:
	_test_camp_state()
	_test_event_bus()
	_test_game_clock()
	print("core_smoke: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)


func _test_camp_state() -> void:
	CampState.load_mock()
	_check(CampState.is_mock, "mock flag set")
	_check(CampState.is_authority(), "offline peer is authority")
	_check(CampState.get_value("day") == 1, "mock starts on day 1")
	_check(CampState.keys_with_prefix("res.").size() == 7, "mock has 7 resources")

	var changes: Array = []
	var on_change := func(key: String, old: Variant, new: Variant) -> void: changes.append([key, old, new])
	CampState.value_changed.connect(on_change)
	CampState.add_value("money", -100)
	CampState.set_value("money", 900)  # same value: no signal
	CampState.value_changed.disconnect(on_change)
	_check(CampState.get_value("money") == 900, "add_value applied")
	_check(changes.size() == 1 and changes[0] == ["money", 1000, 900], "value_changed fired once")

	var snap := CampState.snapshot()
	snap["money"] = 0
	_check(CampState.get_value("money") == 900, "snapshot is a copy")

	var copy: Array = CampState.get_copy("policies.active")
	copy.append("x")
	_check(CampState.get_value("policies.active").is_empty(), "get_copy returns a copy")

	# Contracts: every mock key is declared in contracts/state_*.gd.
	_check(CampState.is_declared("res.food") and CampState.is_declared("day"), "known keys declared")
	_check(not CampState.is_declared("nonsense.key"), "unknown key not declared")
	for key: String in CampState.snapshot():
		_check(CampState.is_declared(key), "mock key '%s' is declared" % key)
	for event_name in [&"day_started", &"resource_change_requested", &"survivor_admitted"]:
		_check(EventBus.is_declared(event_name), "event %s declared" % event_name)


func _test_event_bus() -> void:
	var received: Array = []
	var listener := func(payload: Dictionary) -> void: received.append(payload)
	EventBus.subscribe(&"test_ping", listener)
	EventBus.subscribe(&"test_ping", listener)  # duplicate ignored
	EventBus.emit_event(&"test_ping", {"n": 1})
	EventBus.unsubscribe(&"test_ping", listener)
	EventBus.emit_event(&"test_ping", {"n": 2})
	_check(received == [{"n": 1}], "subscribe/unsubscribe")


func _test_game_clock() -> void:
	CampState.load_mock()
	var events: Array = []
	for event_name in [&"day_started", &"day_phase_changed", &"day_ended"]:
		EventBus.subscribe(event_name, func(payload: Dictionary) -> void: events.append([event_name, payload]))

	GameClock.advance_phase()
	_check(GameClock.current_phase() == "day", "morning -> day")
	GameClock.advance_phase()
	_check(GameClock.current_phase() == "night", "day -> night")
	GameClock.advance_phase()
	_check(GameClock.current_day() == 2 and GameClock.current_phase() == "morning", "night -> next morning")

	var names := events.map(func(e: Array) -> StringName: return e[0])
	_check(names == [&"day_phase_changed", &"day_phase_changed", &"day_ended", &"day_started", &"day_phase_changed"],
		"clock event order")
	_check(events[2][1] == {"day": 1} and events[3][1] == {"day": 2}, "day payloads")
