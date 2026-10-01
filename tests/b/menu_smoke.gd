extends Node
## Smoke test for the main menu + lobby (Lane B): host, take / give up roles,
## start, leave.
## Run headless:  godot --headless --path . res://tests/b/menu_smoke.tscn

const MenuScene := preload("res://ui/main_menu.tscn")

var _failures := 0


func _ready() -> void:
	var menu := MenuScene.instantiate()
	menu.change_scene_on_start = false
	add_child(menu)
	_run(menu)
	Net.leave()
	print("menu_smoke: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _run(menu: Control) -> void:
	_check(menu._menu.visible and not menu._lobby.visible, "starts on the menu")
	menu._name.text = "Tester"
	menu.host_game()
	_check(Net.is_online() and Net.multiplayer.is_server(), "hosting")
	_check(menu._lobby.visible, "lobby shown")
	_check(Net.players[1]["name"] == "Tester", "name sent")

	menu.take_role("medic")
	_check(Net.my_role() == "medic", "took Medic")
	_check(menu._role_owners["medic"].text == "You", "card says You")
	menu.take_role("labor")
	_check(Net.my_role() == "labor", "switched to Labor")
	_check(Net.peer_for_role("medic") == 0, "Medic is free again")
	menu.take_role("labor")
	_check(Net.my_role() == "", "gave Labor up")
	menu.take_role("military")

	Net.start_run()
	_check(menu.run_started, "start reached the menu")

	menu.leave_lobby()
	_check(not Net.is_online(), "left the session")
	_check(menu._menu.visible, "back on the menu")


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)
