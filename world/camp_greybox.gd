extends Node3D
## PROTOTYPE greybox camp map (Phase 1). Built from code so sizes are easy to tweak.
##
## Flat ground, a square wall with a gate on each side, spawn points near the
## map edge, and the camp center ("heart") that zombies walk to. A cross of
## dirt roads runs from each gate to the heart; nothing can be built on it,
## so the way in can never be fully blocked.
## Also tracks occupied spots, so Military and Labor can't place things on top
## of each other or on the walls.
##
## Navigation: everything in the NAV_SOURCE_GROUP group (ground, walls, and
## buildings that add themselves) is baked into the navmesh. Call
## request_rebake() after adding or removing an obstacle.

signal navigation_ready
signal navigation_changed

const Toon := preload("res://world/fx/toon.gd")

const NAV_SOURCE_GROUP := &"nav_source"
const GROUND_COLOR := Color(0.47, 0.72, 0.36)
const ROAD_COLOR := Color(0.74, 0.60, 0.40)
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
var _baking := false
var _rebake_pending := false
var _rebake_queued := false


func _ready() -> void:
	add_to_group(&"camp_map")
	_build_environment()

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = NAV_SOURCE_GROUP
	# Multiples of the default cell size/height (0.25) to avoid precision warnings.
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.75
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)

	_add_box(nav_region, "Ground", Vector3(0, -0.5, 0), Vector3(map_size, 1, map_size), GROUND_COLOR)
	_build_roads()
	_build_walls()
	_build_heart()
	_build_spawn_points()

	nav_region.bake_finished.connect(_on_bake_finished)
	_baking = true
	nav_region.bake_navigation_mesh(false)


func camp_center() -> Vector3:
	return Vector3.ZERO


func get_spawn_points() -> Array[Vector3]:
	return _spawn_points


## Half the map size minus the edge margin: the playable area is ±this on X and Z.
func build_limit() -> float:
	return map_size / 2.0 - edge_margin


## The XZ footprint rectangle of something at `pos` with `half` extents.
static func footprint(pos: Vector3, half: Vector2) -> Rect2:
	return Rect2(pos.x - half.x, pos.z - half.y, half.x * 2.0, half.y * 2.0)


## True if a footprint with `half` extents at `pos` overlaps the road cross.
func is_on_road(pos: Vector3, half: Vector2) -> bool:
	var road := gate_width / 2.0
	return absf(pos.x) < road + half.x or absf(pos.z) < road + half.y


## True if a rectangle with `half` extents (meters, X and Z) fits at `pos`:
## inside the map, off the roads, the walls, the heart and anything placed.
func is_area_buildable(pos: Vector3, half: Vector2) -> bool:
	var limit := build_limit()
	if absf(pos.x) + half.x > limit or absf(pos.z) + half.y > limit:
		return false
	if is_on_road(pos, half):
		return false
	var rect := footprint(pos, half)
	# Closest point of the rectangle to the heart.
	var closest := Vector2(clampf(0.0, rect.position.x, rect.end.x), clampf(0.0, rect.position.y, rect.end.y))
	if closest.length() < HEART_RADIUS:
		return false
	for wall in _wall_rects:
		if rect.intersects(wall):
			return false
	for spot in _occupied:
		if rect.intersects(spot["rect"]):
			return false
	return true


## Square footprint shortcut (towers).
func is_buildable(pos: Vector3, radius: float) -> bool:
	return is_area_buildable(pos, Vector2(radius, radius))


## Mark `node`'s footprint as taken. Freed automatically when the node leaves the tree.
func occupy(node: Node3D, half: Vector2) -> void:
	_occupied.append({"node": node, "rect": footprint(node.global_position, half)})
	node.tree_exiting.connect(release.bind(node), CONNECT_ONE_SHOT)


func release(node: Node3D) -> void:
	_occupied = _occupied.filter(func(spot: Dictionary) -> bool: return spot["node"] != node)


## The placed node whose footprint contains `pos`, or null.
func occupant_at(pos: Vector3) -> Node3D:
	var p := Vector2(pos.x, pos.z)
	for spot in _occupied:
		if spot["rect"].has_point(p):
			return spot["node"]
	return null


## Rebake the navmesh soon (batched: many calls in one frame = one bake).
func request_rebake() -> void:
	if _rebake_queued:
		return
	_rebake_queued = true
	_start_rebake.call_deferred()


func _start_rebake() -> void:
	_rebake_queued = false
	if _baking:
		_rebake_pending = true
		return
	_baking = true
	nav_region.bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	_baking = false
	if _rebake_pending:
		_rebake_pending = false
		request_rebake()
	if is_navigation_ready:
		navigation_changed.emit()
		return
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


func _build_roads() -> void:
	# Visual only; the rule lives in is_on_road().
	for along_x in [true, false]:
		var road := MeshInstance3D.new()
		road.name = "Road"
		road.mesh = Toon.box(Vector3(map_size, 0.02, gate_width) if along_x else Vector3(gate_width, 0.02, map_size))
		road.material_override = Toon.material(ROAD_COLOR, false)
		road.position = Vector3(0, 0.01 if along_x else 0.012, 0)
		add_child(road)


func _add_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.add_to_group(NAV_SOURCE_GROUP)
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
