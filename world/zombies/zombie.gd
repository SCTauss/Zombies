extends CharacterBody3D
## PROTOTYPE basic zombie: walks to `target` on the navigation mesh.
## Set `target`, `max_health` and `speed` before adding it to the tree.
## Cartoon look: big head, mismatched googly eyes, stubby arms. Pops into
## chunks on death (world/fx/gore_pop.gd).

signal died(zombie: Node3D)
signal reached_target(zombie: Node3D)

const Toon := preload("res://world/fx/toon.gd")
const GorePop := preload("res://world/fx/gore_pop.gd")

const SKIN := Color(0.55, 0.82, 0.35)
const SHIRT_COLORS: Array[Color] = [
	Color(0.55, 0.30, 0.75), Color(0.95, 0.45, 0.25), Color(0.25, 0.55, 0.90), Color(0.95, 0.80, 0.25),
]

@export var speed := 2.0
@export var max_health := 30.0
@export var arrive_distance := 1.8

var health := 0.0
var target := Vector3.ZERO

var _visual: Node3D
var _flash_materials: Array[StandardMaterial3D] = []
var _wobble := randf() * TAU

@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	add_to_group(&"zombies")
	health = max_health
	agent.target_position = target
	_build_body()


func _physics_process(delta: float) -> void:
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return
	if remaining_distance() < arrive_distance:
		reached_target.emit(self)
		queue_free()
		return
	var to_next := agent.get_next_path_position() - global_position
	to_next.y = 0
	if to_next.length() > 0.01:
		var dir := to_next.normalized()
		velocity = dir * speed
		rotation.y = atan2(-dir.x, -dir.z)
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	# Dumb shamble: sway side to side while walking.
	_wobble += delta * speed * 3.0
	_visual.rotation.z = sin(_wobble) * 0.18


## Straight-line (XZ) distance to the target. Towers use it to pick who's closest to the camp.
func remaining_distance() -> float:
	return Vector2(global_position.x - target.x, global_position.z - target.z).length()


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		died.emit(self)
		var pop := GorePop.new()
		get_parent().add_child(pop)
		pop.global_position = global_position
		pop.burst(SKIN)
		queue_free()
		return
	_hit_feedback()


func _hit_feedback() -> void:
	# Squash + white flash.
	for mat in _flash_materials:
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = 1.5
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.25, 0.75, 1.25), 0.05)
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_callback(func() -> void:
		for mat in _flash_materials:
			mat.emission_enabled = false).set_delay(0.06)


func _build_body() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var shirt: Color = SHIRT_COLORS.pick_random()
	var body := Toon.part(_visual, Toon.box(Vector3(0.7, 0.8, 0.45)), shirt, Vector3(0, 0.75, 0))
	var head := Toon.part(_visual, Toon.sphere(0.42), SKIN, Vector3(0, 1.45, 0))
	head.rotation.z = randf_range(-0.3, 0.3)  # head lolls to one side
	for side in [-1.0, 1.0]:
		Toon.part(_visual, Toon.box(Vector3(0.16, 0.16, 0.6)), SKIN, Vector3(side * 0.3, 1.0, -0.35))
		Toon.part(_visual, Toon.box(Vector3(0.2, 0.4, 0.22)), shirt.darkened(0.4), Vector3(side * 0.18, 0.2, 0))
	# Mismatched googly eyes.
	var big := randf() < 0.5
	for side in [-1.0, 1.0]:
		var eye_size := 0.15 if (side < 0) == big else 0.1
		var eye := Toon.part(head, Toon.sphere(eye_size), Color.WHITE, Vector3(side * 0.17, 0.08, -0.34), false)
		Toon.part(eye, Toon.sphere(eye_size * 0.45), Color.BLACK, Vector3(randf_range(-0.03, 0.03), 0, -eye_size * 0.75), false)
	for part in [body, head]:
		_flash_materials.append(part.material_override)
