extends Node3D
## PROTOTYPE wave spawner. Spawns zombies at the map's spawn points; they walk
## to the camp center. A zombie that gets there is a breach: it lowers
## `defense.integrity` and emits `camp_breached`.
## Only the authority spawns. Wave size grows with the wave number and the day.
## Later: zombie types and stats from this run's `virus.*` (sim, Lane B).

signal wave_started(wave: int, count: int)
signal wave_ended(wave: int, killed: int, breached: int)

const ZombieScene := preload("res://world/zombies/zombie.tscn")

## The camp map (world/camp_greybox.gd). Found by group if not set.
var map: Node3D
## Start a wave whenever the night phase begins.
var auto_night_waves := true
var wave := 0
var is_active := false
var spawn_interval := 0.8
var breach_damage := 0.05

var alive := 0
var _to_spawn := 0
var _killed := 0
var _breached := 0
var _health_scale := 1.0
var _timer := 0.0


func _ready() -> void:
	if map == null:
		map = get_tree().get_first_node_in_group(&"camp_map")
	EventBus.subscribe(&"day_phase_changed", _on_day_phase_changed)


func _exit_tree() -> void:
	EventBus.unsubscribe(&"day_phase_changed", _on_day_phase_changed)


func _on_day_phase_changed(payload: Dictionary) -> void:
	if auto_night_waves and payload.get("phase") == "night":
		start_wave()


static func wave_size(wave_number: int, day: int) -> int:
	return 5 + 3 * (wave_number - 1) + 2 * (day - 1)


## Zombies still to come this wave (alive + not spawned yet).
func remaining() -> int:
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
	EventBus.emit_event(&"wave_started", {"wave": wave, "count": _to_spawn, "day": day})
	wave_started.emit(wave, _to_spawn)
	return true


func _physics_process(delta: float) -> void:
	if not is_active:
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
	var zombie := ZombieScene.instantiate()
	zombie.max_health = 30.0 * _health_scale
	zombie.speed = randf_range(1.7, 2.3)
	zombie.target = map.camp_center()
	zombie.position = points.pick_random() + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	zombie.died.connect(_on_zombie_died)
	zombie.reached_target.connect(_on_zombie_reached)
	add_child(zombie)
	_to_spawn -= 1
	alive += 1


func _on_zombie_died(_zombie: Node3D) -> void:
	alive -= 1
	_killed += 1


func _on_zombie_reached(_zombie: Node3D) -> void:
	alive -= 1
	_breached += 1
	var integrity := maxf(0.0, CampState.get_value("defense.integrity", 1.0) - breach_damage)
	CampState.set_value("defense.integrity", integrity)
	EventBus.emit_event(&"camp_breached", {"wave": wave, "integrity": integrity})


func _end_wave() -> void:
	is_active = false
	EventBus.emit_event(&"wave_ended", {"wave": wave, "killed": _killed, "breached": _breached})
	wave_ended.emit(wave, _killed, _breached)
