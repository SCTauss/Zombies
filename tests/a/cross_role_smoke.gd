extends Node3D
## Smoke test for Phase 2 cross-role effects (Lane A side):
## zombies smash buildings (→ Labor repair work), turned citizens burst out of
## houses inside the camp, virus parameters scale zombies.
## Run headless:  godot --headless --path . res://tests/a/cross_role_smoke.tscn

const MapScene := preload("res://world/camp_greybox.tscn")
const LayerScript := preload("res://roles/labor/building_layer.gd")
const ConstructionScript := preload("res://roles/labor/construction.gd")
const SpawnerScript := preload("res://world/zombies/wave_spawner.gd")
const ZombieScene := preload("res://world/zombies/zombie.tscn")
const Zombie := preload("res://world/zombies/zombie.gd")

const TIMEOUT := 60.0

var _failures := 0
var _events: Array = []


func _ready() -> void:
	Engine.time_scale = 4.0
	get_tree().create_timer(TIMEOUT, true, false, true).timeout.connect(func() -> void:
		_check(false, "timeout")
		_quit())
	CampState.load_mock()
	for event_name in [&"building_damaged", &"building_repaired", &"zombie_spawned_inside"]:
		EventBus.subscribe(event_name, func(p: Dictionary) -> void: _events.append([event_name, p]))
	await _run()
	_quit()


func _run() -> void:
	var map := MapScene.instantiate()
	add_child(map)
	var layer := LayerScript.new()
	add_child(layer)
	var construction := ConstructionScript.new()
	add_child(construction)
	var spawner := SpawnerScript.new()
	spawner.auto_night_waves = false
	add_child(spawner)
	if not map.is_navigation_ready:
		await map.navigation_ready

	# A finished house right next to the north road, outside the walls.
	CampState.set_value("budget.labor", 1000)
	CampState.set_value("res.materials", 500)
	_check(construction.place("house", Vector3(5, 0, -26)).is_empty(), "house placed by the road")
	var buildings: Array = CampState.get_copy("buildings")
	buildings[-1]["built"] = true
	buildings[-1]["progress"] = 1.0
	var house_id: int = buildings[-1]["id"]
	CampState.set_value("buildings", buildings)
	await map.navigation_changed

	# A zombie walking down the road always stops to smash it (chance forced to 1).
	Zombie.attack_chance = 1.0
	var zombie := ZombieScene.instantiate()
	zombie.target = map.camp_center()
	zombie.position = Vector3(2, 0, -34)
	spawner.add_child(zombie)
	while not _saw(&"building_damaged") and is_instance_valid(zombie):
		await get_tree().physics_frame
	var health: float = construction._find(house_id).get("health", 1.0)
	_check(_saw(&"building_damaged") and health < 1.0, "zombie damaged the house (health %.2f)" % health)
	Zombie.attack_chance = 0.35

	# Labor repairs it; cost scales with damage.
	await get_tree().create_timer(3.0).timeout  # let it finish its hits
	var cost: int = construction.repair_cost(house_id)
	var materials: int = CampState.get_value("res.materials")
	_check(cost > 0, "repair costs materials (%d)" % cost)
	_check(construction.repair(house_id).is_empty(), "repair succeeded")
	_check(construction._find(house_id)["health"] == 1.0, "back to full health")
	_check(CampState.get_value("res.materials") == materials - cost, "materials charged for repair")
	_check(_saw(&"building_repaired"), "building_repaired emitted")
	_check(construction.repair(house_id) == "Nothing to repair", "can't repair a healthy building")

	# A citizen turns: a zombie bursts out of a house inside the camp, tougher with the virus.
	CampState.set_value("virus.toughness", 2.0)
	EventBus.emit_event(&"citizen_turned", {"citizen_id": 1, "name": "Test Dummy"})
	_check(spawner.inside_alive == 1, "one zombie inside the camp")
	_check(_saw(&"zombie_spawned_inside"), "zombie_spawned_inside emitted")
	var inside: Dictionary = _events.filter(func(e: Array) -> bool: return e[0] == &"zombie_spawned_inside")[0][1]
	var pos: Vector3 = inside["position"]
	_check(absf(pos.x) < 18 and absf(pos.z) < 18, "spawned inside the walls (%s)" % pos)
	var inside_zombie: Node3D = spawner.get_children().filter(func(n: Node) -> bool:
		return n.is_in_group(&"zombies") and n.max_health == 60.0).front()
	_check(inside_zombie != null, "virus.toughness doubled its health")


func _saw(event_name: StringName) -> bool:
	return _events.any(func(e: Array) -> bool: return e[0] == event_name)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)


func _quit() -> void:
	print("cross_role_smoke: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)
