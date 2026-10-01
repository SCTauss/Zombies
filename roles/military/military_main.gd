extends Node3D
## Military entry scene: PROTOTYPE tower defense greybox. Runs alone on mock state (F6).
##
## Controls: WASD / arrows pan, wheel zooms.
##   1 = place a watchtower (hold Shift to keep placing), left click = place / select,
##   U = upgrade selected, N = start a wave, G = grid on/off, Esc / right click = cancel.
##   F9 (mock only) = +500 military budget.
## The night phase also starts a wave.

const TowerScene := preload("res://roles/military/tower.tscn")
const TowerTypes := preload("res://roles/military/tower_types.gd")
const Tower := preload("res://roles/military/tower.gd")
const BuildGrid := preload("res://world/build_grid.gd")

const BUDGET_KEY := "budget.military"
const TOWER_TYPE := "watchtower"

var _ghost: Node3D
var _selected: Node3D
var _info: Label
var _message: Label
var _message_time := 0.0

@onready var map: Node3D = $CampGreybox
@onready var rig: Node3D = $CameraRig
@onready var spawner: Node3D = $WaveSpawner
@onready var towers: Node3D = $Towers


func _ready() -> void:
	spawner.map = map
	_build_ui()
	EventBus.subscribe(&"day_phase_changed", _on_day_phase_changed)
	CampState.value_changed.connect(func(_k: String, _o: Variant, _n: Variant) -> void: _refresh_ui())
	spawner.wave_started.connect(func(wave: int, count: int) -> void: _say("Wave %d: %d zombies!" % [wave, count]))
	spawner.wave_ended.connect(func(wave: int, killed: int, breached: int) -> void:
		_say("Wave %d over. Splatted %d, %d got in." % [wave, killed, breached]))
	_refresh_ui()


func _exit_tree() -> void:
	EventBus.unsubscribe(&"day_phase_changed", _on_day_phase_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_start_placing()
			KEY_U:
				_upgrade_selected()
			KEY_N:
				_start_wave()
			KEY_G:
				_toggle_grid()
			KEY_ESCAPE:
				_cancel()
			KEY_F9:
				if CampState.is_mock:
					EventBus.emit_event(&"resource_change_requested", {"key": BUDGET_KEY, "amount": 500, "reason": "dev cheat"})
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""
	if _ghost:
		var point: Variant = rig.ground_point(get_viewport().get_mouse_position())
		if point != null:
			_ghost.global_position = BuildGrid.snap(point)
			_ghost.set_valid(_can_place_at(_ghost.global_position))
	_refresh_ui()


## Dev / screenshot helper: a few towers and a wave.
func dev_demo() -> void:
	for pos in [Vector3(-5, 0, -13), Vector3(5, 0, -13), Vector3(13, 0, 5), Vector3(-13, 0, 5)]:
		var tower := _place_tower(BuildGrid.snap(pos))
		tower.tier = randi_range(0, 2)
		tower.upgrade()
	_start_wave()


func _budget() -> int:
	return int(CampState.get_value(BUDGET_KEY, 0))


func _build_cost() -> int:
	return TowerTypes.tier(TOWER_TYPE, 0)["cost"]


func _can_place_at(pos: Vector3) -> bool:
	return map.is_buildable(pos, Tower.RADIUS) and _budget() >= _build_cost()


## Ask for money. Returns false (and says why) if the budget is too low.
func _spend(amount: int, reason: String) -> bool:
	if _budget() < amount:
		_say("Not enough military budget (need %d)" % amount)
		return false
	EventBus.emit_event(&"resource_change_requested", {"key": BUDGET_KEY, "amount": -amount, "reason": reason})
	return true


func _start_placing() -> void:
	_select(null)
	if _ghost:
		return
	_ghost = TowerScene.instantiate()
	_ghost.is_ghost = true
	add_child(_ghost)


func _cancel() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_select(null)


func _on_click(screen_pos: Vector2) -> void:
	var point: Variant = rig.ground_point(screen_pos)
	if point == null:
		return
	if _ghost == null:
		var hit: Node3D = map.occupant_at(point)
		_select(hit if hit != null and hit.is_in_group(&"towers") else null)
		return
	var pos := BuildGrid.snap(point)
	if not map.is_buildable(pos, Tower.RADIUS):
		_say("Can't build there")
		return
	if not _spend(_build_cost(), TOWER_TYPE):
		return
	_place_tower(pos)
	if not Input.is_key_pressed(KEY_SHIFT):
		_cancel()


func _place_tower(pos: Vector3) -> Node3D:
	var tower := TowerScene.instantiate()
	towers.add_child(tower)
	tower.global_position = pos
	map.occupy(tower, Tower.RADIUS)
	# Drop in with a bounce.
	tower.scale = Vector3(1.3, 0.4, 1.3)
	tower.create_tween().tween_property(tower, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tower


func _select(tower: Node3D) -> void:
	if is_instance_valid(_selected):
		_selected.selected = false
	_selected = tower
	if tower:
		tower.selected = true


func _upgrade_selected() -> void:
	if not is_instance_valid(_selected):
		_say("Click a tower first")
		return
	if not _selected.can_upgrade():
		_say("Already maxed out")
		return
	var next: Dictionary = TowerTypes.tier(TOWER_TYPE, _selected.tier + 1)
	if _spend(next["cost"], "%s upgrade" % TOWER_TYPE):
		_selected.upgrade()
		_say("Upgraded to %s!" % next["label"])


func _start_wave() -> void:
	if not spawner.start_wave():
		_say("A wave is already coming" if spawner.is_active else "Only the host starts waves")


func _toggle_grid() -> void:
	BuildGrid.enabled = not BuildGrid.enabled
	_say("Grid " + ("on" if BuildGrid.enabled else "off (freeform)"))


func _on_day_phase_changed(payload: Dictionary) -> void:
	if payload.get("phase") == "night":
		_start_wave()


func _say(text: String) -> void:
	_message.text = text
	_message_time = 3.0


func _refresh_ui() -> void:
	if _info == null:
		return
	var lines := PackedStringArray([
		"MILITARY   Day %d, %s" % [CampState.get_value("day", 1), CampState.get_value("day_phase", "")],
		"Budget: $%d   Walls: %d%%" % [_budget(), roundi(CampState.get_value("defense.integrity", 1.0) * 100)],
		"Wave %d %s" % [spawner.wave, "(%d zombies left)" % spawner.remaining() if spawner.is_active else "(clear)"],
	])
	if is_instance_valid(_selected):
		var s: Dictionary = _selected.stats()
		lines.append("Selected: %s (tier %d)   dmg %d, range %d, %.1f shots/s" % [
			s["label"], _selected.tier + 1, s["damage"], s["range"], s["fire_rate"]])
		lines.append("[U] upgrade: $%d" % _selected.upgrade_cost() if _selected.can_upgrade() else "Max tier")
	if CampState.is_mock:
		lines.append("(mock camp state, F9 = +$500)")
	_info.text = "\n".join(lines)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20, 16)
	layer.add_child(box)
	_info = _label(22)
	box.add_child(_info)
	_message = _label(30)
	_message.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	box.add_child(_message)

	var buttons := HBoxContainer.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.position.y -= 70
	buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	buttons.add_theme_constant_override("separation", 12)
	layer.add_child(buttons)
	for entry in [
		["Watchtower $%d [1]" % _build_cost(), _start_placing],
		["Upgrade [U]", _upgrade_selected],
		["Send wave [N]", _start_wave],
		["Grid [G]", _toggle_grid],
	]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 48)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(entry[1])
		buttons.add_child(button)


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.10))
	return label
