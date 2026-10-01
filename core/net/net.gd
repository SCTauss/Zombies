extends Node
## Networking and the play session (autoload `Net`).
## Spike findings and the O-03 recommendation: core/net/SPIKE_REPORT.md.
## Session API for menus: docs/CONTRACTS.md, "Session and lobby".
##
## Model: listen-server over ENet. One player hosts and is the authority
## (peer id 1). Offline play is the same code with no peer connected.
##
## What gets replicated:
## - Camp state: the host sends a full snapshot when a peer joins, then every
##   CampState change, key by key. Clients never write state themselves.
## - Events: the host forwards every event it emits to all clients, except
##   requests. Clients forward only request events (names ending in
##   `_requested`) to the host, which re-emits them locally with `peer_id`
##   added to the payload. Other client-side events stay local.
## - Session: the host keeps `players` (peer id -> name and role) and sends it
##   to everyone when it changes. start_run() tells every peer to load the camp.
## Characters and zombies sync themselves (world/players, world/zombies).

signal connected
signal disconnected
signal connection_failed
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal players_changed
signal run_started

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 3  # 4 players including the host
const REQUEST_SUFFIX := "_requested"
const ROLES: Array[String] = ["politician", "military", "medic", "labor"]

## peer id -> {"name": String, "role": String} ("" = no role yet). Empty offline.
var players: Dictionary = {}
var player_name := "Survivor"


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(leave)
	CampState.value_changed.connect(_on_value_changed)
	EventBus.event_emitted.connect(_on_event_emitted)


func host(port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players = {1: {"name": player_name, "role": ""}}
	connected.emit()
	players_changed.emit()
	return OK


func join(address: String, port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if not is_online():
		return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	disconnected.emit()
	players_changed.emit()


func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func is_request(event_name: StringName) -> bool:
	return String(event_name).ends_with(REQUEST_SUFFIX)


## This peer's display name (sent to the host when connected).
func set_player_name(new_name: String) -> void:
	player_name = new_name.strip_edges().left(20)
	if player_name.is_empty():
		player_name = "Survivor"
	if not is_online():
		return
	if multiplayer.is_server():
		_set_player(1, player_name, players.get(1, {}).get("role", ""))
	else:
		_register.rpc_id(1, player_name)


## Ask for `role` ("" gives yours up). The host grants it only if it's free.
func request_role(role: String) -> void:
	if not is_online():
		return
	if multiplayer.is_server():
		_assign_role(1, role)
	else:
		_request_role.rpc_id(1, role)


## This peer's role, "" if none or offline.
func my_role() -> String:
	if not is_online():
		return ""
	return players.get(multiplayer.get_unique_id(), {}).get("role", "")


## The peer playing `role`, or 0 if nobody.
func peer_for_role(role: String) -> int:
	for peer_id: int in players:
		if players[peer_id]["role"] == role:
			return peer_id
	return 0


## Host only: everyone loads the camp now.
func start_run() -> void:
	if is_online() and multiplayer.is_server():
		_start_run.rpc()


# --- Session internals --------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_receive_snapshot.rpc_id(peer_id, CampState.snapshot(), CampState.is_mock)
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server() and players.erase(peer_id):
		_broadcast_players()
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	_register.rpc_id(1, player_name)
	connected.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit()


func _set_player(peer_id: int, new_name: String, role: String) -> void:
	players[peer_id] = {"name": new_name, "role": role}
	_broadcast_players()


func _assign_role(peer_id: int, role: String) -> void:
	if not players.has(peer_id) or (role != "" and not ROLES.has(role)):
		return
	var holder := peer_for_role(role)
	if role != "" and holder != 0 and holder != peer_id:
		return  # taken
	players[peer_id]["role"] = role
	_broadcast_players()


func _broadcast_players() -> void:
	_receive_players.rpc(players)
	players_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _register(new_name: String) -> void:
	if multiplayer.is_server():
		var peer_id := multiplayer.get_remote_sender_id()
		_set_player(peer_id, new_name.left(20), players.get(peer_id, {}).get("role", ""))


@rpc("any_peer", "call_remote", "reliable")
func _request_role(role: String) -> void:
	if multiplayer.is_server():
		_assign_role(multiplayer.get_remote_sender_id(), role)


@rpc("authority", "call_remote", "reliable")
func _receive_players(new_players: Dictionary) -> void:
	players = new_players
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start_run() -> void:
	run_started.emit()


# --- State and event replication ----------------------------------------------

func _on_value_changed(key: String, _old: Variant, new_value: Variant) -> void:
	if is_online() and multiplayer.is_server():
		_receive_value.rpc(key, new_value)


func _on_event_emitted(event_name: StringName, payload: Dictionary) -> void:
	if not is_online():
		return
	if multiplayer.is_server():
		if not is_request(event_name):
			_receive_event.rpc(event_name, payload)
	elif is_request(event_name):
		_receive_event.rpc_id(1, event_name, payload)


@rpc("authority", "call_remote", "reliable")
func _receive_snapshot(data: Dictionary, mock: bool) -> void:
	CampState.load_snapshot(data, mock)


@rpc("authority", "call_remote", "reliable")
func _receive_value(key: String, value: Variant) -> void:
	CampState.apply_remote_value(key, value)


@rpc("any_peer", "call_remote", "reliable")
func _receive_event(event_name: StringName, payload: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		if not is_request(event_name):
			push_warning("Net: peer %d sent non-request event '%s', ignored" % [sender, event_name])
			return
		payload = payload.duplicate(true)
		payload["peer_id"] = sender
	elif sender != 1:
		return
	EventBus.emit_event(event_name, payload)
