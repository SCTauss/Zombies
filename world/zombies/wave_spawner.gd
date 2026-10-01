extends Node3D
## PROTOTYPE wave spawner. Spawns zombies at the map's spawn points; they walk
## to the camp center. A zombie that gets there is a breach: it lowers
## `defense.integrity` and emits `camp_breached`.
## Only the authority spawns. Wave size grows with the wave number and the day;
## zombie toughness/speed scale with this run's `virus.toughness` / `virus.speed`
## (set by sim, Lane B; 1.0 if missing).
## When sim says a citizen turned (`citizen_turned`), a zombie bursts out of a
## house inside the camp (`zombie_spawned_inside`).

signal wave_started(wave: int, count: int)
signal wave_ended(wave: int, killed: int, breached: int)
signal zombie_spawned_inside(zombie: Node3D)

const ZombieScene := preload("res://world/zombies/zombie.tscn")
const BuildingTypes := preload("res://roles/labor/building_types.gd")

## The camp map (world/camp_greybox.gd). Found by group if not set.
var map: Node3D
## Start a wave whenever the night phase begins.
var auto_night_waves := true
var wave := 0
var is_active := false
var spawn_interval := 0.8
var breach_damage := 0.05

var alive := 0
var inside_alive := 0  # turned citizens, not part of any wave
var _to_spawn := 0
var _killed := 0
var _breached := 0
var _health_scale := 1.0
var _timer := 0.0
var _next_zombie_id := 1


func _ready() -> void:
	if map == null:
		map = get_tree().get_first_node_in_group(&"camp_map")
	EventBus.subscribe(&"day_phase_changed", _on_day_phase_changed)
	EventBus.subscribe(&"citizen_turned", _on_citizen_turned)
	EventBus.subscribe(&"wave_start_requested", _on_wave_start_requested)
	# Clients don't spawn anything; they show the host's wave from camp state.
	CampState.value_changed.connect(func(key: String, _o: Variant, _n: Variant) -> void:
		if key.begins_with("wave."):
			_read_wave_state())
	CampState.state_reset.connect(_read_wave_state)
	_read_wave_state()


func _exit_tree() -> void:
	EventBus.unsubscribe(&"day_phase_changed", _on_day_phase_changed)
	EventBus.unsubscribe(&"citizen_turned", _on_citizen_turned)
	EventBus.unsubscribe(&"wave_start_requested", _on_wave_start_requested)


func _on_wave_start_requested(_payload: Dictionary) -> void:
	start_wave()


func _read_wave_state() -> void:
	if CampState.is_authority():
		return
	wave = CampState.get_value("wave.number", 0)
	is_active = CampState.get_value("wave.active", false)


## Spawn a zombie inside the camp, next to a house (or near the heart if there are none).
func spawn_inside(citizen_id := -1) -> Node3D:
	if map == null or not CampState.is_authority():
		return null
	var houses: Array = CampState.get_value("buildings", []).filter(func(r: Dictionary) -> bool: return r["type"] == "house")
	var pos: Vector3
	if houses.is_empty():
		var angle := randf() * TAU
		pos = Vector3(cos(angle), 0, sin(angle)) * 8.0
	else:
		var house: Dictionary = houses.pick_random()
		var house_pos: Vector3 = house["position"]
		var half := BuildingTypes.half_extents(house["type"], house.get("rotation", 0.0))
		# Step out of the front door toward the heart.
		pos = house_pos + (map.camp_center() - house_pos).normalized() * (maxf(half.x, half.y) + 1.5)
	var zombie := _make_zombie(pos, 30.0 * _virus("toughness"))
	zombie.reached_target.connect(func(z: Node3D) -> void:
		inside_alive -= 1
		_breach(z))
	zombie.died.connect(func(_z: Node3D) -> void: inside_alive -= 1)
	add_child(zombie)
	inside_alive += 1
	EventBus.emit_event(&"zombie_spawned_inside", {"citizen_id": citizen_id, "position": pos})
	zombie_spawned_inside.emit(zombie)
	return zombie


func _on_citizen_turned(payload: Dictionary) -> void:
	spawn_inside(payload.get("citizen_id", -1))


func _virus(param: String) -> float:
	return float(CampState.get_value("virus." + param, 1.0))


func _on_day_phase_changed(payload: Dictionary) -> void:
	if auto_night_waves and payload.get("phase") == "night":
		start_wave()


static func wave_size(wave_number: int, day: int) -> int:
	return 5 + 3 * (wave_number - 1) + 2 * (day - 1)


## Zombies still to come this wave (alive + not spawned yet). On clients: the
## zombies we can see.
func remaining() -> int:
	if not CampState.is_authority():
		return get_tree().get_nodes_in_group(&"zombies").size()
	return alive + _to_spawn


func start_wave() -> bool:
	if is_active or map == null or not CampState.is_authority():
		return false
	wave += 1
	is_active = true
	var day: int = CampState.get_value("day", 1)
	_to_spawn = wave_size(wave, day)
	alive = 0
	_killed = 0
	_breached = 0
	_health_scale = 1.0 + 0.2 * (wave - 1)
	_timer = 0.0
	CampState.set_value("wave.number", wave)
	CampState.set_value("wave.active", true)
	EventBus.emit_event(&"wave_started", {"wave": wave, "count": _to_spawn, "day": day})
	wave_started.emit(wave, _to_spawn)
	return true


func _physics_process(delta: float) -> void:
	if not is_active or not CampState.is_authority():
		return
	if _to_spawn > 0:
		_timer -= delta
		if _timer <= 0.0:
			_timer = spawn_interval
			_spawn_one()
	elif alive == 0:
		_end_wave()


func _spawn_one() -> void:
	var points: Array[Vector3] = map.get_spawn_points()
	var pos: Vector3 = points.pick_random() + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	var zombie := _make_zombie(pos, 30.0 * _health_scale * _virus("toughness"))
	zombie.died.connect(_on_zombie_died)
	zombie.reached_target.connect(_on_zombie_reached)
	add_child(zombie)
	_to_spawn -= 1
	alive += 1


func _make_zombie(pos: Vector3, health: float) -> Node3D:
	var zombie := ZombieScene.instantiate()
	zombie.zombie_id = _next_zombie_id
	_next_zombie_id += 1
	zombie.max_health = health
	zombie.speed = randf_range(1.7, 2.3) * _virus("speed")
	zombie.target = map.camp_center()
	zombie.position = pos
	return zombie


func _on_zombie_died(_zombie: Node3D) -> void:
	alive -= 1
	_killed += 1


func _on_zombie_reached(zombie: Node3D) -> void:
	alive -= 1
	_breached += 1
	_breach(zombie)


func _breach(_zombie: Node3D) -> void:
	var integrity := maxf(0.0, CampState.get_value("defense.integrity", 1.0) - breach_damage)
	CampState.set_value("defense.integrity", integrity)
	EventBus.emit_event(&"camp_breached", {"wave": wave, "integrity": integrity})


func _end_wave() -> void:
	is_active = false
	CampState.set_value("wave.active", false)
	EventBus.emit_event(&"wave_ended", {"wave": wave, "killed": _killed, "breached": _breached})
	wave_ended.emit(wave, _killed, _breached)
