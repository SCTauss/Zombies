extends Node3D
## Shows every defense in camp state ("defenses") as a tower and keeps its
## spot occupied on the camp map. It only reads state, so every peer sees the
## same towers. Towers deal damage only on the host; elsewhere they just aim
## and shoot for show.

const TowerScene := preload("res://roles/military/tower.tscn")
const Tower := preload("res://roles/military/tower.gd")

## The camp map (world/camp_greybox.gd). Found by group if not set.
var map: Node3D

var _towers: Dictionary = {}  # defense id -> tower


func _ready() -> void:
	if map == null:
		map = get_tree().get_first_node_in_group(&"camp_map")
	CampState.value_changed.connect(func(key: String, _o: Variant, _n: Variant) -> void:
		if key == "defenses":
			sync())
	CampState.state_reset.connect(sync)
	sync()


func tower_for(defense_id: int) -> Node3D:
	return _towers.get(defense_id)


func sync() -> void:
	var seen := {}
	for record: Dictionary in CampState.get_value("defenses", []):
		var id: int = record["id"]
		seen[id] = true
		var tower: Node3D = _towers.get(id)
		if tower == null:
			tower = TowerScene.instantiate()
			tower.defense_id = id
			tower.type_id = record["type"]
			tower.tier = record["tier"]
			tower.position = record["position"]
			add_child(tower)
			_towers[id] = tower
			if map:
				map.occupy(tower, Vector2(Tower.RADIUS, Tower.RADIUS))
			# Drop in with a bounce.
			tower.scale = Vector3(1.3, 0.4, 1.3)
			tower.create_tween().tween_property(tower, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		elif tower.tier != record["tier"]:
			tower.set_tier(record["tier"])
	for id: int in _towers.keys():
		if not seen.has(id):
			var tower: Node3D = _towers[id]
			_towers.erase(id)
			remove_child(tower)
			tower.queue_free()
