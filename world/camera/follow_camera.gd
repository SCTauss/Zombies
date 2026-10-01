extends Node3D
## Third-person camera that follows a player character.
## Right mouse drag or the Left / Right arrows orbit, wheel zooms. A spring arm keeps the
## camera from going through walls and buildings.

@export var height := 1.6
@export var distance := 7.0
@export var min_distance := 3.0
@export var max_distance := 14.0
@export var pitch_degrees := -28.0
@export var orbit_keys_speed := 2.2
@export var mouse_sensitivity := 0.006
## Orbit/zoom only while active (the camp turns it off inside views).
@export var active := true

var target: Node3D
var yaw := 0.0
var pitch := 0.0

var _arm: SpringArm3D
var camera: Camera3D
var _dragging := false


func _ready() -> void:
	pitch = deg_to_rad(pitch_degrees)
	_arm = SpringArm3D.new()
	_arm.collision_mask = 1
	_arm.spring_length = distance
	_arm.margin = 0.2
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_arm.shape = probe
	add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 65.0
	camera.far = 300.0
	_arm.add_child(camera)


## Follow a new target (snaps there, and ignores its body for the spring arm).
func follow(new_target: Node3D) -> void:
	target = new_target
	_arm.clear_excluded_objects()
	if target is CollisionObject3D:
		_arm.add_excluded_object(target.get_rid())
	global_position = target.global_position + Vector3.UP * height


func _process(delta: float) -> void:
	if active:
		if Input.is_physical_key_pressed(KEY_LEFT):
			yaw += orbit_keys_speed * delta
		if Input.is_physical_key_pressed(KEY_RIGHT):
			yaw -= orbit_keys_speed * delta
	if target:
		var goal := target.global_position + Vector3.UP * height
		global_position = global_position.lerp(goal, 1.0 - exp(-12.0 * delta))
	rotation = Vector3(pitch, yaw, 0)
	_arm.spring_length = lerpf(_arm.spring_length, distance, 1.0 - exp(-10.0 * delta))


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance * 0.9)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance * 1.1)
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-70), deg_to_rad(10))
