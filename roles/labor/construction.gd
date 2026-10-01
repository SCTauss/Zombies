extends Node
## Labor's building rules: placing, construction progress, damage,
## demolishing, and capacity totals. Only the authority changes anything; it
## writes camp state "buildings" and "capacity.*". Other peers call the same
## functions, which send request events to the host instead.

const Records := preload("res://contracts/records.gd")
const BuildingTypes := preload("res://roles/labor/building_types.gd")
const CampMap := preload("res://world/camp_greybox.gd")

const TICK := 0.25  # seconds between construction updates
const BUILDER_BONUS := 0.5  # each citizen with job "builder" adds +50% speed
const REFUND := 0.5  # share of materials returned on demolish

## The camp map (world/camp_greybox.gd), for placement rules. Found by group if not set.
var map: Node3D

var _accum := 0.0


func _ready() -> void:
	add_to_group(&"construction")
	if map == null:
		map = get_tree().get_first_node_in_group(&"camp_map")
	EventBus.subscribe(&"building_placement_requested", _on_placement_requested)
	EventBus.subscribe(&"building_demolish_requested", _on_demolish_requested)
	EventBus.subscribe(&"building_repair_requested", _on_repair_requested)
	if CampState.is_authority():
		recompute_capacity()


func _exit_tree() -> void:
	EventBus.unsubscribe(&"building_placement_requested", _on_placement_requested)
	EventBus.unsubscribe(&"building_demolish_requested", _on_demolish_requested)
	EventBus.unsubscribe(&"building_repair_requested", _on_repair_requested)


func _process(delta: float) -> void:
	if not CampState.is_authority():
		return
	_accum += delta
	if _accum < TICK:
		return
	_tick(_accum)
	_accum = 0.0


## Why `type_id` can't be built at `pos` right now, or "" if it can.
func check_place(type_id: String, pos: Vector3, rotation := 0.0) -> String:
	if not BuildingTypes.TYPES.has(type_id):
		return "Unknown building"
	var half := BuildingTypes.half_extents(type_id, rotation)
	if map and not map.is_area_buildable(pos, half):
		return "Can't build there"
	var rect := CampMap.footprint(pos, half)
	for record: Dictionary in CampState.get_value("buildings", []):
		var other_half := BuildingTypes.half_extents(record["type"], record.get("rotation", 0.0))
		if rect.intersects(CampMap.footprint(record["position"], other_half)):
			return "Overlaps another building"
	var cost: Dictionary = BuildingTypes.get_type(type_id)["cost"]
	if int(CampState.get_value("budget.labor", 0)) < cost["budget"]:
		return "Not enough Labor budget (need $%d)" % cost["budget"]
	if int(CampState.get_value("res.materials", 0)) < cost["materials"]:
		return "Not enough materials (need %d)" % cost["materials"]
	return ""


## Place a building. Returns "" on success (or once the request is sent), else why not.
func place(type_id: String, pos: Vector3, rotation := 0.0) -> String:
	if not CampState.is_authority():
		EventBus.emit_event(&"building_placement_requested", {"type": type_id, "position": pos, "rotation": rotation})
		return ""
	var problem := check_place(type_id, pos, rotation)
	if not problem.is_empty():
		return problem
	var cost: Dictionary = BuildingTypes.get_type(type_id)["cost"]
	_request_resource("budget.labor", -cost["budget"], "build %s" % type_id)
	_request_resource("res.materials", -cost["materials"], "build %s" % type_id)
	var buildings: Array = CampState.get_copy("buildings", [])
	var record := Records.building(_next_id(buildings), type_id, pos)
	record["rotation"] = rotation
	record["capacity"] = BuildingTypes.get_type(type_id)["capacity"].duplicate()
	buildings.append(record)
	CampState.set_value("buildings", buildings)
	EventBus.emit_event(&"building_placed", {"building_id": record["id"], "type": type_id, "position": pos})
	return ""


func demolish(building_id: int) -> void:
	if not CampState.is_authority():
		EventBus.emit_event(&"building_demolish_requested", {"building_id": building_id})
		return
	var record := _find(building_id)
	if record.is_empty():
		return
	var materials: int = BuildingTypes.get_type(record["type"])["cost"]["materials"]
	_request_resource("res.materials", roundi(materials * REFUND), "demolish %s" % record["type"])
	_remove(building_id, "demolished")


## Materials a full repair of `building_id` costs now (0 if undamaged or unknown).
func repair_cost(building_id: int) -> int:
	var record := _find(building_id)
	if record.is_empty():
		return 0
	var materials: int = BuildingTypes.get_type(record["type"])["cost"]["materials"]
	return ceili((1.0 - record["health"]) * materials)


## Repair a building back to full health. Returns "" on success (or once the
## request is sent), else why not.
func repair(building_id: int) -> String:
	if not CampState.is_authority():
		EventBus.emit_event(&"building_repair_requested", {"building_id": building_id})
		return ""
	var cost := repair_cost(building_id)
	if cost <= 0:
		return "Nothing to repair"
	if int(CampState.get_value("res.materials", 0)) < cost:
		return "Not enough materials (need %d)" % cost
	_request_resource("res.materials", -cost, "repair")
	var buildings: Array = CampState.get_copy("buildings", [])
	for record: Dictionary in buildings:
		if record["id"] == building_id:
			record["health"] = 1.0
	CampState.set_value("buildings", buildings)
	EventBus.emit_event(&"building_repaired", {"building_id": building_id, "cost": cost})
	return ""


## Buildings below full health.
func damaged_count() -> int:
	return CampState.get_value("buildings", []).filter(func(r: Dictionary) -> bool: return r["health"] < 1.0).size()


## Damage a building by `amount` (0..1 of its health). Destroyed at 0. Authority only.
func damage(building_id: int, amount: float) -> void:
	if not CampState.is_authority():
		return
	var buildings: Array = CampState.get_copy("buildings", [])
	for record: Dictionary in buildings:
		if record["id"] == building_id:
			record["health"] = maxf(0.0, record["health"] - amount)
			if record["health"] <= 0.0:
				_remove(building_id, "destroyed")
				return
			CampState.set_value("buildings", buildings)
			EventBus.emit_event(&"building_damaged", {"building_id": building_id, "health": record["health"]})
			return


## capacity.<kind> = sum of finished buildings' capacity.
func recompute_capacity() -> void:
	var totals := {}
	for kind in BuildingTypes.capacity_kinds():
		totals[kind] = 0
	for record: Dictionary in CampState.get_value("buildings", []):
		if record["built"]:
			for kind: String in record["capacity"]:
				totals[kind] = totals.get(kind, 0) + record["capacity"][kind]
	for kind: String in totals:
		CampState.set_value("capacity." + kind, totals[kind])


func builders() -> int:
	var count := 0
	for citizen: Dictionary in CampState.get_value("citizens", []):
		if citizen.get("job") == "builder":
			count += 1
	return count


func _tick(elapsed: float) -> void:
	var buildings: Array = CampState.get_value("buildings", [])
	if not buildings.any(func(r: Dictionary) -> bool: return not r["built"]):
		return
	buildings = CampState.get_copy("buildings", [])
	var speed := 1.0 + BUILDER_BONUS * builders()
	var finished: Array[Dictionary] = []
	for record: Dictionary in buildings:
		if record["built"]:
			continue
		var build_time: float = BuildingTypes.get_type(record["type"])["build_time"]
		record["progress"] = minf(1.0, record["progress"] + elapsed * speed / build_time)
		if record["progress"] >= 1.0:
			record["built"] = true
			finished.append(record)
	CampState.set_value("buildings", buildings)
	if not finished.is_empty():
		recompute_capacity()
		for record in finished:
			EventBus.emit_event(&"building_completed", {"building_id": record["id"], "type": record["type"]})


func _remove(building_id: int, reason: String) -> void:
	var buildings: Array = CampState.get_copy("buildings", [])
	var removed: Dictionary = {}
	for record: Dictionary in buildings:
		if record["id"] == building_id:
			removed = record
	if removed.is_empty():
		return
	buildings.erase(removed)
	CampState.set_value("buildings", buildings)
	recompute_capacity()
	EventBus.emit_event(&"building_destroyed", {"building_id": building_id, "type": removed["type"], "reason": reason})


func _find(building_id: int) -> Dictionary:
	for record: Dictionary in CampState.get_value("buildings", []):
		if record["id"] == building_id:
			return record
	return {}


func _next_id(buildings: Array) -> int:
	var top := 0
	for record: Dictionary in buildings:
		top = maxi(top, record["id"])
	return top + 1


func _request_resource(key: String, amount: int, reason: String) -> void:
	if amount != 0:
		EventBus.emit_event(&"resource_change_requested", {"key": key, "amount": amount, "reason": reason})


func _on_placement_requested(payload: Dictionary) -> void:
	if CampState.is_authority():
		place(payload.get("type", ""), payload.get("position", Vector3.ZERO), payload.get("rotation", 0.0))


func _on_demolish_requested(payload: Dictionary) -> void:
	if CampState.is_authority():
		demolish(payload.get("building_id", -1))


func _on_repair_requested(payload: Dictionary) -> void:
	if CampState.is_authority():
		repair(payload.get("building_id", -1))
