extends Node3D
## Draws one building record (contracts/records.gd) in the cartoon style.
## Under construction: a foundation, scaffolding, and the building rising
## with `progress`. Finished: pops into shape. Damaged: darker.
## As a ghost (placement preview) it's see-through and has no collision.
##
## Set `record` (or `ghost_type` + `is_ghost`) before adding it to the tree,
## then call refresh() whenever the record changes.

const Toon := preload("res://world/fx/toon.gd")
const BuildingTypes := preload("res://roles/labor/building_types.gd")
const CampMap := preload("res://world/camp_greybox.gd")

const SCAFFOLD := Color(1.0, 0.70, 0.15)
const FOUNDATION := Color(0.62, 0.60, 0.58)
const HOUSE_COLORS: Array[Color] = [
	Color(1.0, 0.85, 0.55), Color(0.65, 0.85, 1.0), Color(1.0, 0.70, 0.70), Color(0.75, 0.95, 0.65),
]

var record: Dictionary = {}
var is_ghost := false
var ghost_type := "house"
var selected := false:
	set(value):
		selected = value
		if _ring:
			_ring.visible = selected or is_ghost

var _visual: Node3D
var _model: Node3D
var _scaffold: Node3D
var _ring: MeshInstance3D
var _body: StaticBody3D
var _was_built := false


func _ready() -> void:
	var type_id := type()
	var size: Vector2 = BuildingTypes.get_type(type_id)["size"]
	_visual = Node3D.new()
	add_child(_visual)
	_ring = MeshInstance3D.new()
	_ring.mesh = Toon.box(Vector3(size.x + 0.6, 0.04, size.y + 0.6))
	_ring.position.y = 0.03
	_ring.material_override = Toon.unshaded(Color(1, 1, 1, 0.25))
	_ring.visible = is_ghost or selected
	add_child(_ring)
	# Foundation slab.
	Toon.part(_visual, Toon.box(Vector3(size.x + 0.2, 0.15, size.y + 0.2)), FOUNDATION, Vector3(0, 0.075, 0), not is_ghost)
	_model = Node3D.new()
	_visual.add_child(_model)
	_build_model(type_id, size)
	if is_ghost:
		_make_ghostly(_visual)
		set_valid(true)
	else:
		add_to_group(&"building_views")
		_add_collision(size)
		_scaffold = _build_scaffold(size)
		_visual.add_child(_scaffold)
	_was_built = record.get("built", false)
	refresh()


func type() -> String:
	return ghost_type if is_ghost else record.get("type", "house")


func building_id() -> int:
	return record.get("id", -1)


## XZ footprint on the ground.
func footprint() -> Rect2:
	return CampMap.footprint(global_position, BuildingTypes.half_extents(type(), record.get("rotation", 0.0)))


## Shake when hit (zombies call this; visual only).
func shake() -> void:
	var tween := create_tween()
	tween.tween_property(_visual, "position:x", 0.12, 0.04)
	tween.tween_property(_visual, "position:x", -0.12, 0.06)
	tween.tween_property(_visual, "position:x", 0.0, 0.04)


## Ghost only: green when it can be placed here, red when not.
func set_valid(valid: bool) -> void:
	_ring.material_override = Toon.unshaded(Color(0.3, 1.0, 0.4, 0.4) if valid else Color(1.0, 0.2, 0.2, 0.4))


func refresh() -> void:
	if is_ghost:
		return
	rotation.y = record.get("rotation", 0.0)
	var built: bool = record.get("built", false)
	var progress: float = record.get("progress", 0.0)
	_scaffold.visible = not built
	_model.scale = Vector3(1, maxf(0.05, progress) if not built else 1.0, 1)
	if built and not _was_built:
		# Finished: pop!
		_visual.scale = Vector3(1.2, 0.7, 1.2)
		create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_was_built = built
	var health: float = record.get("health", 1.0)
	_tint(_model, Color.WHITE.lerp(Color(0.45, 0.30, 0.25), 1.0 - health))


func _add_collision(size: Vector2) -> void:
	# Collision + navmesh source, so zombies walk around buildings.
	_body = StaticBody3D.new()
	_body.add_to_group(CampMap.NAV_SOURCE_GROUP)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(size.x, 2.0, size.y)
	shape.position.y = 1.0
	_body.add_child(shape)
	add_child(_body)


func _build_scaffold(size: Vector2) -> Node3D:
	var scaffold := Node3D.new()
	var h := 2.6
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Toon.part(scaffold, Toon.box(Vector3(0.12, h, 0.12)), SCAFFOLD, Vector3(x * size.x / 2.0, h / 2.0, z * size.y / 2.0))
	for y in [1.0, 2.2]:
		for z in [-1.0, 1.0]:
			Toon.part(scaffold, Toon.box(Vector3(size.x, 0.08, 0.08)), SCAFFOLD, Vector3(0, y, z * size.y / 2.0))
		for x in [-1.0, 1.0]:
			Toon.part(scaffold, Toon.box(Vector3(0.08, 0.08, size.y)), SCAFFOLD, Vector3(x * size.x / 2.0, y, 0))
	return scaffold


func _build_model(type_id: String, size: Vector2) -> void:
	var w := size.x
	var d := size.y
	var o := not is_ghost
	var m := _model
	match type_id:
		"house":
			var color: Color = HOUSE_COLORS[absi(building_id()) % HOUSE_COLORS.size()]
			Toon.part(m, Toon.box(Vector3(w - 0.6, 2.0, d - 0.6)), color, Vector3(0, 1.15, 0), o)
			var roof := PrismMesh.new()
			roof.size = Vector3(w, 1.4, d - 0.2)
			Toon.part(m, roof, Color(0.85, 0.30, 0.25), Vector3(0, 2.85, 0), o)
			Toon.part(m, Toon.box(Vector3(0.8, 1.3, 0.1)), Color(0.45, 0.28, 0.15), Vector3(0, 0.8, d / 2.0 - 0.3), o)
			for x in [-1.0, 1.0]:
				Toon.part(m, Toon.box(Vector3(0.6, 0.6, 0.1)), Color(0.60, 0.85, 1.0), Vector3(x * 1.05, 1.4, d / 2.0 - 0.3), o)
			Toon.part(m, Toon.box(Vector3(0.4, 0.9, 0.4)), Color(0.55, 0.50, 0.50), Vector3(w / 4.0, 3.2, -0.5), o)
		"clinic":
			Toon.part(m, Toon.box(Vector3(w - 0.4, 2.4, d - 0.4)), Color(0.96, 0.96, 0.96), Vector3(0, 1.35, 0), o)
			Toon.part(m, Toon.box(Vector3(w, 0.25, d)), Color(0.75, 0.80, 0.85), Vector3(0, 2.65, 0), o)
			# Red cross on the front and on the roof.
			Toon.part(m, Toon.box(Vector3(1.4, 0.4, 0.1)), Color(0.95, 0.15, 0.20), Vector3(0, 1.6, d / 2.0 - 0.15), o)
			Toon.part(m, Toon.box(Vector3(0.4, 1.4, 0.1)), Color(0.95, 0.15, 0.20), Vector3(0, 1.6, d / 2.0 - 0.15), o)
			Toon.part(m, Toon.box(Vector3(1.6, 0.1, 0.5)), Color(0.95, 0.15, 0.20), Vector3(0, 2.8, 0), o)
			Toon.part(m, Toon.box(Vector3(0.5, 0.1, 1.6)), Color(0.95, 0.15, 0.20), Vector3(0, 2.8, 0), o)
		"lab":
			Toon.part(m, Toon.box(Vector3(w - 0.4, 2.2, d - 0.4)), Color(0.80, 0.84, 0.88), Vector3(0, 1.25, 0), o)
			Toon.part(m, Toon.sphere(1.3), Color(0.30, 0.80, 0.75), Vector3(0, 2.35, 0), o).scale = Vector3(1, 0.7, 1)
			Toon.part(m, Toon.box(Vector3(0.08, 1.4, 0.08)), Color(0.3, 0.3, 0.35), Vector3(1.2, 3.0, 1.2), o)
			Toon.part(m, Toon.sphere(0.15), Color(1.0, 0.2, 0.2), Vector3(1.2, 3.75, 1.2), o)
			var glow := Toon.part(m, Toon.box(Vector3(2.0, 0.6, 0.1)), Color(0.4, 1.0, 0.5), Vector3(0, 1.4, d / 2.0 - 0.15), o)
			var glow_mat := glow.material_override as StandardMaterial3D
			glow_mat.emission_enabled = true
			glow_mat.emission = Color(0.4, 1.0, 0.5)
		"workshop":
			Toon.part(m, Toon.box(Vector3(w - 0.4, 2.4, d - 0.4)), Color(0.60, 0.55, 0.50), Vector3(0, 1.35, 0), o)
			var roof := PrismMesh.new()
			roof.size = Vector3(w, 1.0, d)
			Toon.part(m, roof, Color(0.40, 0.42, 0.48), Vector3(0, 3.05, 0), o)
			Toon.part(m, Toon.cylinder(0.3, 1.8), Color(0.35, 0.30, 0.30), Vector3(-w / 4.0, 3.6, -0.8), o)
			var gear := Toon.part(m, Toon.cylinder(0.8, 0.2), Color(1.0, 0.75, 0.20), Vector3(0, 1.5, d / 2.0 - 0.1), o)
			gear.rotation.x = PI / 2.0
			Toon.part(m, Toon.box(Vector3(2.0, 1.8, 0.1)), Color(0.30, 0.25, 0.22), Vector3(1.0, 0.95, d / 2.0 - 0.15), o)
		"farm":
			Toon.part(m, Toon.box(Vector3(w - 0.3, 0.25, d - 0.3)), Color(0.55, 0.38, 0.22), Vector3(0, 0.2, 0), o)
			for row in 4:
				var z := -d / 2.0 + 0.7 + row * (d - 1.4) / 3.0
				for col in 6:
					var x := -w / 2.0 + 0.7 + col * (w - 1.4) / 5.0
					Toon.part(m, Toon.sphere(0.28), Color(0.35, 0.80, 0.25), Vector3(x, 0.5, z), o)
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					Toon.part(m, Toon.box(Vector3(0.12, 0.8, 0.12)), Color(0.70, 0.50, 0.30), Vector3(x * w / 2.0, 0.4, z * d / 2.0), o)
		"water_tower":
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					Toon.part(m, Toon.box(Vector3(0.15, 3.0, 0.15)), Color(0.55, 0.40, 0.28), Vector3(x * 0.9, 1.5, z * 0.9), o)
			Toon.part(m, Toon.cylinder(1.3, 1.8), Color(0.35, 0.65, 0.95), Vector3(0, 3.8, 0), o)
			Toon.part(m, Toon.cylinder(1.4, 0.3), Color(0.25, 0.45, 0.75), Vector3(0, 4.85, 0), o)


func _tint(node: Node, tint: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = child.material_override
			if not mat.has_meta("base_color"):
				mat.set_meta("base_color", mat.albedo_color)
			mat.albedo_color = (mat.get_meta("base_color") as Color) * tint
		_tint(child, tint)


func _make_ghostly(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mat := (child.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.next_pass = null
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.45
			child.material_override = mat
		_make_ghostly(child)
