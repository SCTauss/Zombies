extends CharacterBody3D
## A player character (H-009): one per role, walks around the camp in third
## person. WASD moves relative to the camera, Shift sprints, Space jumps.
## Wobbly, bouncy animation in the friendslop style (H-008).
##
## `controlled` = this character takes the keyboard (the camp decides which one).
## `input_enabled` = false while its player is inside a role view.
## `move_override` = world-space XZ direction for tests/bots (overrides keys).

const CharacterLook := preload("res://world/players/character_look.gd")

@export var role := "military"
@export var walk_speed := 5.0
@export var sprint_speed := 8.5
@export var jump_velocity := 6.5
@export var gravity := 20.0

var controlled := false:
	set(value):
		controlled = value
		if _tag:
			_tag.visible = not value  # your own name would just cover the screen
var input_enabled := true
var move_override := Vector3.ZERO
## Camera yaw (radians), so "forward" means away from the camera.
var camera_yaw := 0.0

var look: Node3D
var _tag: Label3D
var _walk_phase := 0.0
var _was_on_floor := true
var _jump_queued := false


func _ready() -> void:
	add_to_group(&"players")
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.shape.radius = 0.42
	shape.shape.height = 1.6
	shape.position.y = 0.8
	add_child(shape)
	look = CharacterLook.new()
	look.role = role
	add_child(look)
	_tag = Label3D.new()
	_tag.text = CharacterLook.display_name(role)
	_tag.modulate = CharacterLook.tag_color(role)
	_tag.outline_modulate = Color(0.08, 0.06, 0.10)
	_tag.outline_size = 12
	_tag.font_size = 42
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.position.y = 2.45
	_tag.visible = not controlled
	add_child(_tag)


func _unhandled_input(event: InputEvent) -> void:
	if controlled and input_enabled and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE:
		_jump_queued = true


func _physics_process(delta: float) -> void:
	var move := move_override
	var sprinting := false
	if move == Vector3.ZERO and controlled and input_enabled:
		move = _key_direction()
		sprinting = Input.is_physical_key_pressed(KEY_SHIFT)
	move.y = 0
	if move.length() > 1.0:
		move = move.normalized()
	var speed := sprint_speed if sprinting else walk_speed
	var target := move * speed
	var blend := 1.0 - exp(-12.0 * delta)
	velocity.x = lerpf(velocity.x, target.x, blend)
	velocity.z = lerpf(velocity.z, target.z, blend)
	if is_on_floor():
		if _jump_queued:
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta
	_jump_queued = false
	move_and_slide()
	if move.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-move.x, -move.z), 1.0 - exp(-10.0 * delta))
	_animate(delta, Vector2(velocity.x, velocity.z).length())


func _key_direction() -> Vector3:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		input.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		input.y += 1
	var forward := Vector3(-sin(camera_yaw), 0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0, -sin(camera_yaw))
	return right * input.x - forward * input.y


func _animate(delta: float, ground_speed: float) -> void:
	var body: Node3D = look.body
	var moving := ground_speed > 0.3 and is_on_floor()
	if moving:
		_walk_phase += delta * ground_speed * 2.2
	# Bounce, lean and waddle while walking; settle when idle.
	var bounce := absf(sin(_walk_phase)) * 0.14 if moving else 0.0
	body.position.y = lerpf(body.position.y, bounce, 1.0 - exp(-20.0 * delta))
	body.rotation.z = lerpf(body.rotation.z, sin(_walk_phase) * 0.12 if moving else 0.0, 1.0 - exp(-10.0 * delta))
	body.rotation.x = lerpf(body.rotation.x, -minf(ground_speed / sprint_speed, 1.0) * 0.25, 1.0 - exp(-8.0 * delta))
	for i in look.arms.size():
		var swing := sin(_walk_phase + PI * i) * 0.9 if moving else 0.0
		if not is_on_floor():
			swing = -2.6  # arms up while airborne
		look.arms[i].rotation.x = lerpf(look.arms[i].rotation.x, swing, 1.0 - exp(-12.0 * delta))
	for i in look.feet.size():
		look.feet[i].position.z = sin(_walk_phase + PI * i) * 0.22 if moving else 0.0
	# Squash on landing.
	if is_on_floor() and not _was_on_floor:
		look.scale = Vector3(1.25, 0.7, 1.25)
		create_tween().tween_property(look, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_was_on_floor = is_on_floor()
