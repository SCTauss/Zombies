extends Node3D
## PROTOTYPE cartoon gore: a zombie pops into bouncy chunks and leaves a splat.
## Usage: add it to the tree at the zombie's feet, then call burst(skin_color).
## It frees itself when done.

const Toon := preload("res://world/fx/toon.gd")

const CHUNKS := 9
const CHUNK_LIFETIME := 2.5
const SPLAT_LIFETIME := 6.0
const BLOOD := Color(0.75, 0.05, 0.10)


func burst(skin: Color) -> void:
	_splat()
	for i in CHUNKS:
		var chunk := RigidBody3D.new()
		chunk.collision_layer = 0
		chunk.collision_mask = 1
		chunk.physics_material_override = PhysicsMaterial.new()
		chunk.physics_material_override.bounce = 0.6
		var size := randf_range(0.15, 0.35)
		var shape := CollisionShape3D.new()
		shape.shape = SphereShape3D.new()
		shape.shape.radius = size * 0.5
		chunk.add_child(shape)
		var color := skin if i % 3 != 0 else BLOOD
		var mesh: PrimitiveMesh = Toon.box(Vector3.ONE * size) if i % 2 == 0 else Toon.sphere(size * 0.5)
		Toon.part(chunk, mesh, color, Vector3.ZERO, true)
		add_child(chunk)
		chunk.position = Vector3(0, 1.0, 0) + Vector3(randf_range(-0.3, 0.3), randf_range(0, 0.6), randf_range(-0.3, 0.3))
		chunk.apply_central_impulse(Vector3(randf_range(-1, 1), randf_range(1.2, 2.2), randf_range(-1, 1)) * 2.2 * chunk.mass)
		chunk.angular_velocity = Vector3(randf(), randf(), randf()) * 10.0
		var shrink := chunk.create_tween()
		shrink.tween_interval(CHUNK_LIFETIME - 0.4)
		shrink.tween_property(chunk, "scale", Vector3.ONE * 0.01, 0.4)
		shrink.tween_callback(chunk.queue_free)
	get_tree().create_timer(SPLAT_LIFETIME).timeout.connect(queue_free)


func _splat() -> void:
	var splat := MeshInstance3D.new()
	var disc := Toon.cylinder(randf_range(0.9, 1.4), 0.02)
	splat.mesh = disc
	splat.material_override = Toon.unshaded(BLOOD.darkened(0.15))
	splat.position = Vector3(0, 0.02, 0)
	splat.scale = Vector3(0.2, 1, 0.2)
	splat.rotation.y = randf() * TAU
	add_child(splat)
	var tween := splat.create_tween()
	tween.tween_property(splat, "scale", Vector3(1.0, 1, randf_range(0.6, 1.0)), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(SPLAT_LIFETIME - 1.2)
	tween.tween_property(splat, "scale", Vector3(0.01, 1, 0.01), 0.8)
