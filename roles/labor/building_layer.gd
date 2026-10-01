extends Node3D
## Shows every building in camp state ("buildings") and keeps each one's spot
## occupied on the camp map. It only reads state, so it works the same on the
## host and on clients. Used by Labor, Military and the camp scene.

const BuildingView := preload("res://roles/labor/building_view.gd")
const BuildingTypes := preload("res://roles/labor/building_types.gd")
const CampMap := preload("res://world/camp_greybox.gd")

## The camp map (world/camp_greybox.gd). Found by group if not set.
var map: Node3D

var _views: Dictionary = {}  # building id -> BuildingView


func _ready() -> void:
	if map == null:
		map = get_tree().get_first_node_in_group(&"camp_map")
	CampState.value_changed.connect(_on_value_changed)
	CampState.state_reset.connect(sync)
	sync()


func view_for(building_id: int) -> Node3D:
	return _views.get(building_id)


## The building view whose footprint contains `pos`, or null.
func view_at(pos: Vector3) -> Node3D:
	for view: Node3D in _views.values():
		var half := BuildingTypes.half_extents(view.type(), view.record.get("rotation", 0.0))
		if CampMap.footprint(view.position, half).has_point(Vector2(pos.x, pos.z)):
			return view
	return null


## Rebuild the views from camp state.
func sync() -> void:
	var seen := {}
	var obstacles_changed := false
	for record: Dictionary in CampState.get_value("buildings", []):
		var id: int = record["id"]
		seen[id] = true
		var view: Node3D = _views.get(id)
		if view != null and (view.type() != record["type"] or view.position != record["position"]
				or view.record.get("rotation") != record.get("rotation")):
			_remove(id)
			view = null
		if view == null:
			view = BuildingView.new()
			view.record = record
			view.position = record["position"]
			add_child(view)
			_views[id] = view
			if map:
				map.occupy(view, BuildingTypes.half_extents(record["type"], record.get("rotation", 0.0)))
			obstacles_changed = true
		else:
			view.record = record
			view.refresh()
	for id: int in _views.keys():
		if not seen.has(id):
			_remove(id)
			obstacles_changed = true
	if obstacles_changed and map:
		map.request_rebake()


func _remove(building_id: int) -> void:
	var view: Node3D = _views[building_id]
	_views.erase(building_id)
	# Leave the tree now (frees the map spot and drops it from the next navmesh bake).
	remove_child(view)
	view.queue_free()


func _on_value_changed(key: String, _old: Variant, _new: Variant) -> void:
	if key == "buildings":
		sync()
