extends Node
## Dev tool: open a scene, wait, save a screenshot, quit. Needs a window (not --headless).
##   godot --path . res://tests/a/screenshot.tscn -- --scene=res://roles/military/military_main.tscn --out=C:/tmp/shot.png --wait=6
## Calls the scene's dev_demo() first, if it has one (skip with --no-demo).

func _ready() -> void:
	var args := {"scene": "", "out": "user://screenshot.png", "wait": "3"}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() == 2 else "true"
	var scene := (load(args["scene"]) as PackedScene).instantiate()
	add_child(scene)
	if scene.has_method("dev_demo") and not args.has("no-demo"):
		scene.dev_demo()
	await get_tree().create_timer(float(args["wait"])).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(args["out"])
	print("screenshot: %s -> %s" % [error_string(err), args["out"]])
	var camera := get_viewport().get_camera_3d()
	if camera:
		print("camera: %s at %s" % [camera.get_path(), camera.global_position])
	get_tree().quit(0 if err == OK else 1)
