extends Node3D
## PROTOTYPE greybox camp map (Phase 1). Built from code so sizes are easy to tweak.
##
## Flat ground, a square wall with a gate on each side, spawn points near the
## map edge, and the camp center ("heart") that zombies walk to.
## Also tracks occupied spots, so Military and Labor can't place things on top
## of each other or on the walls.

signal navigation_ready

const Toon := preload("res://world/fx/toon.gd")

const GROUND_COLOR := Color(0.47, 0.72, 0.36)
const WALL_COLOR := Color(0.80, 0.52, 0.30)
const HEART_COLOR := Color(1.0, 0.80, 0.20)
const SKY_COLOR := Color(0.55, 0.80, 0.97)
const HEART_RADIUS := 2.0

@export var map_size := 80.0
@export var camp_size := 36.0
@export var wall_thickness := 1.0
@export var wall_height := 2.5
@export var gate_width := 6.0
@export var edge_margin := 2.0

var nav_region: NavigationRegion3D
var is_navigation_ready := false

var _wall_rects: Array[Rect2] = []  # XZ footprints
var _occupied: Array[Dictionary] = []  # {node, pos: Vector2, radius}
var _spawn_points: Array[Vector3] = []


func _ready() -> void:
	add_to_group(&"camp_map")
	_build_environment()

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	# Multiples of the default cell size/height (0.25) to avoid precision warnings.
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.75
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)

	_add_box(nav_region, "Ground", Vector3(0, -0.5, 0), Vector3(map_size, 1, map_size), GROUND_COLOR)
	_build_walls()
	_build_heart()
	_build_spawn_points()

	nav_region.bake_finished.connect(_on_bake_finished, CONNECT_ONE_SHOT)
	nav_region.bake_navigation_mesh(false)


func camp_center() -> Vector3:
	return Vector3.ZERO


func get_spawn_points() -> Array[Vector3]:
	return _spawn_points


## Half the map size minus the edge margin: the playable area is ±this on X and Z.
func build_limit() -> float:
	return map_size / 2.0 - edge_margin


func is_buildable(pos: Vector3, radius: float) -> bool:
	var limit := build_limit()
	if absf(pos.x) > limit or absf(pos.z) > limit:
		return false
	var p := Vector2(pos.x, pos.z)
	if p.length() < HEART_RADIUS + radius:
		return false
	for rect in _wall_rects:
		if rect.grow(radius).has_point(p):
			return false
	for spot in _occupied:
		if p.distance_to(spot["pos"]) < radius + spot["radius"]:
			return false
	return true


## Mark `node`'s spot as taken. Freed automatically when the node leaves the tree.
func occupy(node: Node3D, radius: float) -> void:
	_occupied.append({"node": node, "pos": Vector2(node.global_position.x, node.global_position.z), "radius": radius})
	node.tree_exiting.connect(release.bind(node), CONNECT_ONE_SHOT)


func release(node: Node3D) -> void:
	_occupied = _occupied.filter(func(spot: Dictionary) -> bool: return spot["node"] != node)


## The placed node whose spot contains `pos`, or null.
func occupant_at(pos: Vector3) -> Node3D:
	var p := Vector2(pos.x, pos.z)
	for spot in _occupied:
		if p.distance_to(spot["pos"]) <= spot["radius"]:
			return spot["node"]
	return null


func _on_bake_finished() -> void:
	# The map syncs asynchronously, and the first sync can still be the empty
	# region. Wait until a real path query works (a few physics frames).
	var map_rid := get_world_3d().navigation_map
	for i in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map_rid) > 0 \
				and not NavigationServer3D.map_get_path(map_rid, _spawn_points[0], camp_center(), false).is_empty():
			break
	is_navigation_ready = true
	navigation_ready.emit()


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)


func _build_walls() -> void:
	var h := camp_size / 2.0
	var t := wall_thickness
	# Each side is two segments with the gate gap in the middle. Segments
	# reach past the corners by t/2 so the corners close.
	var seg_len := h + t / 2.0 - gate_width / 2.0
	var seg_mid := (gate_width / 2.0 + h + t / 2.0) / 2.0
	for side in 4:
		for direction in [-1.0, 1.0]:
			var along: float = direction * seg_mid
			var pos: Vector3
			var size: Vector3
			match side:
				0:
					pos = Vector3(along, wall_height / 2.0, -h)
					size = Vector3(seg_len, wall_height, t)
				1:
					pos = Vector3(along, wall_height / 2.0, h)
					size = Vector3(seg_len, wall_height, t)
				2:
					pos = Vector3(-h, wall_height / 2.0, along)
					size = Vector3(t, wall_height, seg_len)
				_:
					pos = Vector3(h, wall_height / 2.0, along)
					size = Vector3(t, wall_height, seg_len)
			_add_box(nav_region, "Wall", pos, size, WALL_COLOR)
			_wall_rects.append(Rect2(pos.x - size.x / 2.0, pos.z - size.z / 2.0, size.x, size.z))


func _build_heart() -> void:
	# Visual only (no collision), so zombies can walk right up to it.
	var mesh := CylinderMesh.new()
	mesh.top_radius = HEART_RADIUS
	mesh.bottom_radius = HEART_RADIUS
	mesh.height = 0.3
	var heart := MeshInstance3D.new()
	heart.name = "Heart"
	heart.mesh = mesh
	heart.material_override = Toon.material(HEART_COLOR)
	heart.position = Vector3(0, 0.15, 0)
	add_child(heart)


func _build_spawn_points() -> void:
	var d := build_limit()
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1]:
			if x != 0 or z != 0:
				_spawn_points.append(Vector3(x * d, 0, z * d))


func _add_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	# No outline on the ground (it would just be a black frame at the map edge).
	mesh.material_override = Toon.material(color, node_name != "Ground", 0.06)
	body.add_child(mesh)
	parent.add_child(body, true)
	return body
