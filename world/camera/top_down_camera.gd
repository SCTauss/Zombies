extends Node3D
## Top-down camera rig for the camp (tower defense, building).
## WASD / arrows pan, mouse wheel zooms. The rig sits on the ground; the camera
## looks down at it from `distance` away.

@export var pan_speed := 22.0
@export var distance := 42.0
@export var min_distance := 12.0
@export var max_distance := 75.0
@export var pitch_degrees := 58.0
@export var bounds := 40.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_apply_zoom()


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir == Vector2.ZERO:
		return
	var step := dir.normalized() * pan_speed * delta * (distance / 42.0)
	position.x = clampf(position.x + step.x, -bounds, bounds)
	position.z = clampf(position.z + step.y, -bounds, bounds)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance * 0.9)
			_apply_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance * 1.1)
			_apply_zoom()


## The ground (y = 0) point under a screen position, or null.
func ground_point(screen_pos: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, 0).intersects_ray(from, dir)


func _apply_zoom() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0, sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation = Vector3(-pitch, 0, 0)
