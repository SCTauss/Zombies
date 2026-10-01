extends Node
## PROTOTYPE networking (autoload `Net`), from the Phase 0 spike.
## Findings and the O-03 recommendation: core/net/SPIKE_REPORT.md.
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

signal connected
signal disconnected
signal connection_failed
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 3  # 4 players including the host
const REQUEST_SUFFIX := "_requested"


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: connected.emit())
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
	connected.emit()
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
	disconnected.emit()


func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func is_request(event_name: StringName) -> bool:
	return String(event_name).ends_with(REQUEST_SUFFIX)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_receive_snapshot.rpc_id(peer_id, CampState.snapshot(), CampState.is_mock)
	peer_joined.emit(peer_id)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit()


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
