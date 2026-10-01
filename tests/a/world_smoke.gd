extends Node3D
## Smoke test for the greybox world and tower defense.
## Run headless:  godot --headless --path . res://tests/a/world_smoke.tscn
## Exits 0 if every check passes, 1 otherwise.

const MapScene := preload("res://world/camp_greybox.tscn")
const SpawnerScript := preload("res://world/zombies/wave_spawner.gd")
const TowerScene := preload("res://roles/military/tower.tscn")
const Tower := preload("res://roles/military/tower.gd")

const TIMEOUT := 120.0

var _failures := 0


func _ready() -> void:
	Engine.time_scale = 4.0
	get_tree().create_timer(TIMEOUT, true, false, true).timeout.connect(func() -> void:
		_check(false, "timeout")
		_quit())
	CampState.load_mock()
	await _run()
	_quit()


func _run() -> void:
	var map := MapScene.instantiate()
	add_child(map)
	if not map.is_navigation_ready:
		await map.navigation_ready

	# Navigation: corner spawn must go around the wall, through a gate.
	var nav_map := get_world_3d().navigation_map
	var corner := Vector3(map.build_limit(), 0, map.build_limit())
	var path := NavigationServer3D.map_get_path(nav_map, corner, map.camp_center(), true)
	_check(path.size() >= 3, "corner path has turns (%d points)" % path.size())
	_check(path.size() > 0 and path[-1].distance_to(map.camp_center()) < 1.0, "path reaches the camp center")

	# Placement rules.
	_check(not map.is_buildable(Vector3(10, 0, -map.camp_size / 2.0), Tower.RADIUS), "can't build on a wall")
	_check(not map.is_buildable(Vector3.ZERO, Tower.RADIUS), "can't build on the heart")
	_check(map.is_buildable(Vector3(8, 0, 8), Tower.RADIUS), "can build inside the camp")

	# Wave with no defenses: everyone gets in.
	var spawner := SpawnerScript.new()
	spawner.map = map
	add_child(spawner)
	var breaches := [0]
	EventBus.subscribe(&"camp_breached", func(_p: Dictionary) -> void: breaches[0] += 1)
	_check(spawner.start_wave(), "wave 1 starts")
	var result: Array = await spawner.wave_ended
	_check(result[1] == 0 and result[2] == 5, "wave 1: 0 killed, 5 breached (got %d, %d)" % [result[1], result[2]])
	_check(breaches[0] == 5, "5 camp_breached events")
	_check(is_equal_approx(CampState.get_value("defense.integrity"), 0.75), "integrity dropped to 75%")

	# Towers: maxed watchtowers around the heart splat the next wave.
	for pos in [Vector3(4, 0, 4), Vector3(-4, 0, 4), Vector3(4, 0, -4), Vector3(-4, 0, -4)]:
		var tower := TowerScene.instantiate()
		tower.tier = 3
		add_child(tower)
		tower.global_position = pos
	_check(spawner.start_wave(), "wave 2 starts")
	result = await spawner.wave_ended
	print("wave 2: killed %d, breached %d" % [result[1], result[2]])
	_check(result[1] >= 6, "towers killed most of wave 2 (%d of 8)" % result[1])


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)


func _quit() -> void:
	print("world_smoke: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)
