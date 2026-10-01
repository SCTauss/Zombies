extends Node
## Two-process test of a real online camp (Phase 3). Start both (host first):
##   godot --headless --path . res://tests/a/net_camp_smoke.tscn -- --role=host
##   godot --headless --path . res://tests/a/net_camp_smoke.tscn -- --role=client
## Host = Military, client = Labor. Checks the lobby flow (names, roles, start),
## that the client sees the host's towers and zombies, that the client's
## character movement reaches the host, and that a client request (a house)
## is applied by the host and synced back.

const CampScene := preload("res://world/camp/camp_main.tscn")

const PORT := 24691
const TIMEOUT := 45.0

var _role := ""
var _done := false
var _camp: Node3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
	get_tree().create_timer(TIMEOUT, true, false, true).timeout.connect(_finish.bind(false, "timeout"))
	Net.run_started.connect(_on_run_started)
	match _role:
		"host":
			_host()
		"client":
			_client()
		_:
			_finish(false, "missing --role=host|client")


func _host() -> void:
	Net.set_player_name("Hosty")
	if Net.host(PORT) != OK:
		_finish(false, "host failed")
		return
	Net.request_role("military")
	Net.request_role("labor")  # then give it up, so the client can take it
	Net.request_role("military")
	print("net_camp host: listening")
	while not (Net.players.size() == 2 and Net.peer_for_role("labor") > 1):
		await Net.players_changed
	var client_id := Net.peer_for_role("labor")
	_check(Net.players[client_id]["name"] == "Clienty", "client's name arrived")
	_check(Net.peer_for_role("military") == 1, "host kept military")
	Net.start_run()


func _client() -> void:
	Net.set_player_name("Clienty")
	if Net.join("127.0.0.1", PORT) != OK:
		_finish(false, "join failed")
		return
	await Net.connected
	Net.request_role("military")  # taken by the host: refused
	Net.request_role("labor")


func _on_run_started() -> void:
	_camp = CampScene.instantiate()
	add_child(_camp)
	if not _camp.map.is_navigation_ready:
		await _camp.map.navigation_ready
	if _role == "host":
		await _host_run()
	else:
		await _client_run()


func _host_run() -> void:
	_check(_camp.controlled_role == "military" and not _camp.spectating, "host controls Military")
	_check(_camp.players["labor"].is_puppet(), "Labor is a puppet on the host")
	await get_tree().create_timer(1.5).timeout  # let the client's camp load
	_check(_camp.defense_rules.place("watchtower", Vector3(5, 0, -13)).is_empty(), "host placed a tower")
	_camp.spawner.start_wave()
	var labor: Node3D = _camp.players["labor"]
	var start := labor.global_position
	while labor.global_position.distance_to(start) < 1.5:
		await get_tree().physics_frame
	print("net_camp host: saw Labor walk %.1f m" % labor.global_position.distance_to(start))
	while CampState.get_value("buildings").size() < 8:
		await get_tree().physics_frame
	print("net_camp host: client's house request applied")
	await Net.peer_left
	_finish(true, "client finished")


func _client_run() -> void:
	_check(_camp.controlled_role == "labor", "client controls Labor")
	_check(_camp.players["military"].is_puppet(), "Military is a puppet on the client")
	_check(not _camp.players["labor"].is_puppet(), "own character isn't a puppet")
	while _camp.towers.get_child_count() < 1:
		await get_tree().physics_frame
	print("net_camp client: sees the host's tower")
	var zombie_sync: Node = _camp.get_node("ZombieSync")
	while zombie_sync.puppet_count() < 1:
		await get_tree().physics_frame
	print("net_camp client: sees %d zombie(s)" % zombie_sync.puppet_count())
	_check(_camp.spawner.is_active, "client knows a wave is on")

	# Walk (the host should see it), then ask for a house (the host applies it).
	var me: Node3D = _camp.players["labor"]
	me.move_override = Vector3(0, 0, 1)
	await get_tree().create_timer(1.2).timeout
	me.move_override = Vector3.ZERO
	var count: int = CampState.get_value("buildings").size()
	_check(_camp.construction.place("house", Vector3(-9, 0, -7)).is_empty(), "request sent")
	_check(CampState.get_value("buildings").size() == count, "client didn't change state itself")
	while CampState.get_value("buildings").size() == count:
		await get_tree().physics_frame
	print("net_camp client: house synced back")
	while _camp.buildings.get_child_count() < count + 1:
		await get_tree().physics_frame
	_finish(true, "all checks passed")


var _failures := 0


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL (%s): %s" % [_role, label])


func _finish(ok: bool, reason: String) -> void:
	if _done:
		return
	_done = true
	ok = ok and _failures == 0
	print("net_camp_smoke %s: %s (%s)" % [_role, "OK" if ok else "FAILED", reason])
	Net.leave()
	get_tree().quit(0 if ok else 1)
