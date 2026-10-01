extends Node3D
## Shows the host's zombies on clients.
## Host: ~10 times a second, sends every live zombie's id, position and facing
## (unreliable; a lost packet is just a skipped frame).
## Clients: keep a puppet copy per id (world/zombies/zombie.gd, `is_puppet`),
## pop it on `zombie_died`, and quietly drop ones that stop showing up (they
## reached the camp heart).
## Offline it does nothing.

const ZombieScene := preload("res://world/zombies/zombie.tscn")

const SEND_INTERVAL := 0.1
const MISSING_SNAPSHOTS_TO_DROP := 4

## The wave spawner whose zombies are sent (host side). Found by group if not set.
var spawner: Node3D

var _timer := 0.0
var _puppets := {}  # zombie id -> puppet
var _missing := {}  # zombie id -> snapshots in a row it was missing


func _ready() -> void:
	if spawner == null:
		spawner = get_parent().get_node_or_null("WaveSpawner")
	EventBus.subscribe(&"zombie_died", _on_zombie_died)


func _exit_tree() -> void:
	EventBus.unsubscribe(&"zombie_died", _on_zombie_died)


func puppet_count() -> int:
	return _puppets.size()


func _physics_process(delta: float) -> void:
	if not Net.is_online() or not multiplayer.is_server() or spawner == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SEND_INTERVAL
	var data := PackedFloat32Array()
	for child in spawner.get_children():
		if child.is_in_group(&"zombies") and not child.is_puppet and child.health > 0.0:
			data.append_array([child.zombie_id, child.global_position.x, child.global_position.z, child.rotation.y])
	_receive_zombies.rpc(data)


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_zombies(data: PackedFloat32Array) -> void:
	var seen := {}
	for i in range(0, data.size(), 4):
		var id := int(data[i])
		seen[id] = true
		var pos := Vector3(data[i + 1], 0, data[i + 2])
		var puppet: Node3D = _puppets.get(id)
		if puppet == null:
			puppet = ZombieScene.instantiate()
			puppet.is_puppet = true
			puppet.zombie_id = id
			puppet.position = pos
			puppet.rotation.y = data[i + 3]
			add_child(puppet)
			_puppets[id] = puppet
		puppet.net_position = pos
		puppet.net_rotation = data[i + 3]
		_missing.erase(id)
	for id: int in _puppets.keys():
		if seen.has(id):
			continue
		_missing[id] = _missing.get(id, 0) + 1
		if _missing[id] >= MISSING_SNAPSHOTS_TO_DROP:
			_drop(id, false)


func _on_zombie_died(payload: Dictionary) -> void:
	if Net.is_online() and not multiplayer.is_server():
		_drop(int(payload.get("zombie_id", -1)), true)


func _drop(id: int, burst: bool) -> void:
	var puppet: Node3D = _puppets.get(id)
	_puppets.erase(id)
	_missing.erase(id)
	if puppet == null or not is_instance_valid(puppet):
		return
	if burst:
		puppet.pop()
	else:
		puppet.queue_free()
