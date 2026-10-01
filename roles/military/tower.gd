extends Node3D
## PROTOTYPE watchtower: hit-scan, shoots the zombie closest to the camp ("first").
## Cartoon look: wooden stilts, a platform and a helmeted soldier blob that
## turns to aim. Each upgrade tier makes the tower taller and adds a detail.
## Set `is_ghost` before adding it to show a placement preview instead.

const Toon := preload("res://world/fx/toon.gd")
const TowerTypes := preload("res://roles/military/tower_types.gd")

const RADIUS := 1.0
const WOOD := Color(0.70, 0.45, 0.25)
const PLATFORM := Color(0.85, 0.60, 0.35)
const UNIFORM := Color(0.35, 0.55, 0.30)
const SKIN := Color(1.0, 0.78, 0.60)
const TIER_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85), Color(0.30, 0.65, 1.0), Color(0.75, 0.35, 1.0), Color(1.0, 0.25, 0.25),
]

var type_id := "watchtower"
var tier := 0
var is_ghost := false
## Id of its record in camp state "defenses" (-1 for ghosts and test towers).
var defense_id := -1
var selected := false:
	set(value):
		selected = value
		_update_ring()

var _cooldown := 0.0
var _visual: Node3D
var _soldier: Node3D
var _pivot: Node3D
var _muzzle: Node3D
var _ring: MeshInstance3D
var _tracer: MeshInstance3D
var _flash: MeshInstance3D
var _tracer_time := 0.0


func _ready() -> void:
	if not is_ghost:
		add_to_group(&"towers")
	_ring = MeshInstance3D.new()
	_ring.mesh = Toon.cylinder(1.0, 0.04)
	add_child(_ring)
	_tracer = MeshInstance3D.new()
	_tracer.mesh = Toon.box(Vector3(0.12, 0.12, 1.0))
	_tracer.material_override = Toon.unshaded(Color(1.0, 0.95, 0.4))
	_tracer.top_level = true
	_tracer.visible = false
	add_child(_tracer)
	_build_visual()
	_update_ring()
	if is_ghost:
		set_valid(true)


func stats() -> Dictionary:
	return TowerTypes.tier(type_id, tier)


func can_upgrade() -> bool:
	return tier + 1 < TowerTypes.tier_count(type_id)


func upgrade_cost() -> int:
	return TowerTypes.tier(type_id, tier + 1)["cost"] if can_upgrade() else 0


func upgrade() -> void:
	if can_upgrade():
		set_tier(tier + 1)


## Show tier `new_tier` (from camp state), popping if it went up.
func set_tier(new_tier: int) -> void:
	if new_tier == tier and _visual != null:
		return
	tier = new_tier
	_build_visual()
	_update_ring()
	# Pop!
	_visual.scale = Vector3(0.6, 1.4, 0.6)
	create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Ghost only: green when it can be placed here, red when not.
func set_valid(valid: bool) -> void:
	var color := Color(0.3, 1.0, 0.4, 0.35) if valid else Color(1.0, 0.2, 0.2, 0.35)
	_ring.material_override = Toon.unshaded(color)


func _process(delta: float) -> void:
	if _tracer_time > 0.0:
		_tracer_time -= delta
		if _tracer_time <= 0.0:
			_tracer.visible = false
			_flash.visible = false
	if is_ghost:
		return
	# On clients the only zombies are puppet copies: shots there are for show
	# (puppets ignore damage); the host's towers do the real killing.
	_cooldown -= delta
	var target := _find_target()
	if target == null:
		return
	var aim := target.global_position - _soldier.global_position
	_soldier.rotation.y = atan2(-aim.x, -aim.z)
	if _cooldown <= 0.0:
		var s := stats()
		_cooldown = 1.0 / s["fire_rate"]
		_show_shot(target.global_position + Vector3(0, 1.1, 0))
		target.take_damage(s["damage"])


func _find_target() -> Node3D:
	var reach: float = stats()["range"]
	var best: Node3D = null
	var best_left := INF
	for zombie: Node3D in get_tree().get_nodes_in_group(&"zombies"):
		var offset := zombie.global_position - global_position
		if Vector2(offset.x, offset.z).length() > reach:
			continue
		var left: float = zombie.remaining_distance()
		if left < best_left:
			best_left = left
			best = zombie
	return best


func _show_shot(to: Vector3) -> void:
	var from := _muzzle.global_position
	var length := from.distance_to(to)
	if length < 0.05:
		return
	_tracer.global_transform = Transform3D(Basis.looking_at(to - from), (from + to) / 2.0).scaled_local(Vector3(1, 1, length))
	_tracer.visible = true
	_flash.visible = true
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
	_tracer_time = 0.06
	# Recoil kick (the soldier faces -Z, so +Z is backwards).
	_pivot.position.z = 0.12
	create_tween().tween_property(_pivot, "position:z", 0.0, 0.12)


func _update_ring() -> void:
	if _ring == null:
		return
	var reach: float = stats()["range"]
	_ring.scale = Vector3(reach, 1, reach)
	_ring.position.y = 0.03
	_ring.visible = is_ghost or selected
	if not is_ghost:
		_ring.material_override = Toon.unshaded(Color(1, 1, 1, 0.18))


func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var height := 2.2 + tier * 0.5
	var outline := not is_ghost
	# Four stilts and a platform.
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			var leg := Toon.part(_visual, Toon.box(Vector3(0.18, height, 0.18)), WOOD, Vector3(x, height / 2.0, z), outline)
			leg.rotation.z = -x * 0.08
	Toon.part(_visual, Toon.box(Vector3(1.6, 0.2, 1.6)), PLATFORM, Vector3(0, height, 0), outline)
	# Tier flag.
	Toon.part(_visual, Toon.box(Vector3(0.05, 1.0, 0.05)), WOOD, Vector3(0.7, height + 0.6, 0.7), outline)
	Toon.part(_visual, Toon.box(Vector3(0.45, 0.3, 0.04)), TIER_COLORS[tier], Vector3(0.95, height + 0.95, 0.7), outline)
	if tier >= 2:  # sandbags
		for i in 4:
			var angle := i * TAU / 4.0 + PI / 4.0
			Toon.part(_visual, Toon.box(Vector3(0.5, 0.25, 0.3)), Color(0.80, 0.72, 0.50),
				Vector3(cos(angle) * 0.6, height + 0.22, sin(angle) * 0.6), outline).rotation.y = -angle
	# Soldier: body, head, helmet, rifle.
	_soldier = Node3D.new()
	_soldier.position = Vector3(0, height + 0.1, 0)
	_visual.add_child(_soldier)
	var pivot := Node3D.new()
	_pivot = pivot
	_soldier.add_child(pivot)
	Toon.part(pivot, Toon.box(Vector3(0.5, 0.55, 0.35)), UNIFORM, Vector3(0, 0.38, 0), outline)
	Toon.part(pivot, Toon.sphere(0.25), SKIN, Vector3(0, 0.85, 0), outline)
	Toon.part(pivot, Toon.sphere(0.29), UNIFORM.darkened(0.3), Vector3(0, 0.95, 0.02), outline).scale = Vector3(1, 0.6, 1)
	var rifle_length := 0.8 + tier * 0.25
	Toon.part(pivot, Toon.box(Vector3(0.08, 0.08, rifle_length)), Color(0.2, 0.2, 0.22), Vector3(0.22, 0.5, -rifle_length / 2.0), outline)
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.22, 0.5, -rifle_length)
	pivot.add_child(_muzzle)
	_flash = MeshInstance3D.new()
	_flash.mesh = Toon.sphere(0.18)
	_flash.material_override = Toon.unshaded(Color(1.0, 0.85, 0.3))
	_flash.visible = false
	_muzzle.add_child(_flash)
	if is_ghost:
		_make_ghostly(_visual)


func _make_ghostly(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat := (child.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.next_pass = null
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.45
			child.material_override = mat
		_make_ghostly(child)
