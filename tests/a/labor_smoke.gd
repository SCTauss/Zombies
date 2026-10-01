extends Node3D
## Smoke test for Labor: placement rules, costs, construction, capacity,
## demolish, damage, and navigation around buildings.
## Run headless:  godot --headless --path . res://tests/a/labor_smoke.tscn

const MapScene := preload("res://world/camp_greybox.tscn")
const LayerScript := preload("res://roles/labor/building_layer.gd")
const ConstructionScript := preload("res://roles/labor/construction.gd")

const TIMEOUT := 60.0

var _failures := 0
var _events: Array = []


func _ready() -> void:
	Engine.time_scale = 4.0
	get_tree().create_timer(TIMEOUT, true, false, true).timeout.connect(func() -> void:
		_check(false, "timeout")
		_quit())
	CampState.load_mock()
	for event_name in [&"building_placed", &"building_completed", &"building_destroyed", &"building_damaged"]:
		EventBus.subscribe(event_name, func(p: Dictionary) -> void: _events.append([event_name, p]))
	await _run()
	_quit()


func _run() -> void:
	var map := MapScene.instantiate()
	add_child(map)
	var layer := LayerScript.new()
	layer.map = map
	add_child(layer)
	var construction := ConstructionScript.new()
	construction.map = map
	add_child(construction)
	if not map.is_navigation_ready:
		await map.navigation_ready

	# Starting camp from mock state.
	var start_count: int = CampState.get_value("buildings").size()
	_check(start_count == 7, "mock camp has 7 buildings (%d)" % start_count)
	_check(layer.get_child_count() == 7, "layer shows 7 views")
	_check(CampState.get_value("capacity.housing") == 12, "3 houses = 12 housing")

	# Placement rules.
	var spot := Vector3(-9, 0, -7)
	_check(construction.check_place("house", spot).is_empty(), "free spot is buildable")
	_check(not construction.check_place("house", Vector3(0, 0, 10)).is_empty(), "can't build on the road")
	_check(not construction.check_place("house", Vector3(-14, 0, -7)).is_empty(), "can't build on a house")
	_check(not construction.check_place("castle", spot).is_empty(), "unknown type refused")

	# Place: costs go through requests (MockRules applies them).
	var budget: int = CampState.get_value("budget.labor")
	var materials: int = CampState.get_value("res.materials")
	_check(construction.place("house", spot).is_empty(), "house placed")
	_check(CampState.get_value("budget.labor") == budget - 40, "budget charged")
	_check(CampState.get_value("res.materials") == materials - 20, "materials charged")
	_check(CampState.get_value("buildings").size() == 8, "8 buildings")
	_check(not construction.check_place("house", spot).is_empty(), "spot now taken")
	var new_id: int = CampState.get_value("buildings")[-1]["id"]
	_check(_saw(&"building_placed"), "building_placed emitted")

	# Can't afford.
	CampState.set_value("budget.labor", 10)
	_check(construction.check_place("house", Vector3(8, 0, -7)).begins_with("Not enough Labor budget"), "budget limits building")
	# Squares, not circles: the workshop's corner would hit the water tower.
	CampState.set_value("budget.labor", 500)
	_check(construction.check_place("workshop", Vector3(9, 0, 9)) == "Can't build there", "corner overlap refused")
	# A 6x4 farm turned 90 degrees is 4x6.
	_check(construction.check_place("farm", Vector3(-8, 0, 15), 0.0).is_empty(), "farm fits unrotated")
	_check(not construction.check_place("farm", Vector3(-8, 0, 15), PI / 2.0).is_empty(), "rotated farm hits the wall")
	CampState.set_value("budget.labor", 500)

	# Navigation rebakes around the new building.
	await map.navigation_changed

	# Construction: a house takes 5 s.
	_check(not CampState.get_value("buildings")[-1]["built"], "starts unbuilt")
	await get_tree().create_timer(6.0).timeout
	_check(CampState.get_value("buildings")[-1]["built"], "house finished")
	_check(CampState.get_value("capacity.housing") == 16, "capacity.housing 16 (%s)" % CampState.get_value("capacity.housing"))
	_check(_saw(&"building_completed"), "building_completed emitted")

	# Damage, then destroy.
	construction.damage(new_id, 0.4)
	_check(is_equal_approx(CampState.get_value("buildings")[-1]["health"], 0.6), "damaged to 60%")
	_check(_saw(&"building_damaged"), "building_damaged emitted")
	construction.damage(new_id, 1.0)
	_check(CampState.get_value("buildings").size() == 7, "destroyed at 0 health")
	_check(CampState.get_value("capacity.housing") == 12, "capacity back to 12")

	# Demolish refunds half the materials.
	materials = CampState.get_value("res.materials")
	construction.demolish(1)  # a starting house (20 materials)
	_check(CampState.get_value("res.materials") == materials + 10, "demolish refunds 10")
	_check(CampState.get_value("buildings").size() == 6, "6 buildings left")
	await get_tree().process_frame
	_check(layer.get_child_count() == 6, "layer removed the view")
	_check(_saw(&"building_destroyed"), "building_destroyed emitted")


func _saw(event_name: StringName) -> bool:
	return _events.any(func(e: Array) -> bool: return e[0] == event_name)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)


func _quit() -> void:
	print("labor_smoke: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)
