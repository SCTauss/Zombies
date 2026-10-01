extends Node
## Two-process network smoke test. Start both (host first):
##   godot --headless --path . res://tests/a/net_smoke.tscn -- --role=host
##   godot --headless --path . res://tests/a/net_smoke.tscn -- --role=client
## Checks: snapshot on join, value sync, event relay host->client, request client->host.
## Each process exits 0 on success, 1 on failure or timeout.

const PORT := 24690
const TIMEOUT := 15.0

var _role := ""
var _got_phase_event := false
var _request_from := 0
var _done := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
	get_tree().create_timer(TIMEOUT).timeout.connect(_finish.bind(false, "timeout"))
	match _role:
		"host":
			_start_host()
		"client":
			_start_client()
		_:
			_finish(false, "missing --role=host|client")


func _start_host() -> void:
	# Stand-in for sim (Lane B), which normally applies resource requests.
	EventBus.subscribe(&"resource_change_requested", func(payload: Dictionary) -> void:
		_request_from = payload.get("peer_id", 0)
		CampState.add_value(payload["key"], payload["amount"]))
	Net.peer_joined.connect(func(_id: int) -> void: GameClock.advance_phase())
	Net.peer_left.connect(func(_id: int) -> void:
		_finish(_request_from > 1, "request from peer %d" % _request_from))
	var err := Net.host(PORT)
	if err != OK:
		_finish(false, "host failed: %s" % error_string(err))
	print("net_smoke host: listening on %d" % PORT)


func _start_client() -> void:
	EventBus.subscribe(&"day_phase_changed", func(payload: Dictionary) -> void:
		_got_phase_event = payload.get("phase") == "day")
	CampState.state_reset.connect(func() -> void:
		EventBus.emit_event(&"resource_change_requested", {"key": "res.food", "amount": -5}),
		CONNECT_ONE_SHOT)
	CampState.value_changed.connect(func(_key: String, _old: Variant, _new: Variant) -> void:
		if _got_phase_event and CampState.get_value("res.food") == 95:
			_finish(not CampState.is_authority() and CampState.get_value("day_phase") == "day", "synced"))
	var err := Net.join("127.0.0.1", PORT)
	if err != OK:
		_finish(false, "join failed: %s" % error_string(err))


func _finish(ok: bool, reason: String) -> void:
	if _done:
		return
	_done = true
	print("net_smoke %s: %s (%s)" % [_role, "OK" if ok else "FAILED", reason])
	Net.leave()
	get_tree().quit(0 if ok else 1)
