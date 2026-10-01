extends Node
## Labor view: PROTOTYPE building over the shared camp world.
## Follows the view contract (docs/CONTRACTS.md): the camp calls open_view(camp)
## when the Labor player uses the workbench, close_view() when they leave.
##
## Controls (while open): WASD / arrows pan, wheel zooms.
##   1-6 = pick a building (hold Shift to keep placing), R = rotate,
##   left click = place / select, X = demolish selected (50% materials back),
##   F = repair selected (materials scale with the damage), J = workers panel (jobs),
##   G = grid on/off, right click = cancel, Esc = cancel / leave the view.
##   F9 (mock only) = +$500 Labor budget and +100 materials.

signal exit_requested

const BuildingTypes := preload("res://roles/labor/building_types.gd")
const BuildingView := preload("res://roles/labor/building_view.gd")
const BuildGrid := preload("res://world/build_grid.gd")
const WorkersPanel := preload("res://roles/labor/workers_panel.gd")

var is_open := false
var workers: PanelContainer

var _camp: Node3D
var _ghost: Node3D
var _ghost_rotation := 0.0
var _selected_id := -1
var _layer: CanvasLayer
var _info: Label
var _message: Label
var _message_time := 0.0


func _ready() -> void:
	_build_ui()
	_layer.visible = false
	EventBus.subscribe(&"building_completed", _on_building_completed)


func _exit_tree() -> void:
	EventBus.unsubscribe(&"building_completed", _on_building_completed)


func open_view(camp: Node) -> void:
	_camp = camp
	is_open = true
	_layer.visible = true
	var rig: Node3D = _camp.top_down_camera()
	rig.active = true
	rig.camera.make_current()
	_refresh_ui()


func close_view() -> void:
	_cancel()
	is_open = false
	_layer.visible = false
	if _camp:
		_camp.top_down_camera().active = false


## Dev / screenshot helper: queue a few buildings at different stages.
func dev_demo() -> void:
	CampState.add_value("budget.labor", 1000)
	CampState.add_value("res.materials", 500)
	for entry in [["house", Vector3(-9, 0, -7)], ["workshop", Vector3(11, 0, 7)], ["farm", Vector3(-8, 0, 15)]]:
		var problem: String = _camp.construction.place(entry[0], BuildGrid.snap(entry[1]))
		if not problem.is_empty():
			push_warning("dev_demo: %s at %s: %s" % [entry[0], entry[1], problem])
	workers.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < BuildingTypes.ORDER.size():
			_start_placing(BuildingTypes.ORDER[index])
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_R:
				_ghost_rotation = wrapf(_ghost_rotation + PI / 2.0, 0.0, TAU)
			KEY_X, KEY_DELETE:
				_demolish_selected()
			KEY_F:
				_repair_selected()
			KEY_J:
				workers.visible = not workers.visible
			KEY_G:
				BuildGrid.enabled = not BuildGrid.enabled
				_say("Grid " + ("on" if BuildGrid.enabled else "off (freeform)"))
			KEY_ESCAPE:
				if _ghost or _selected_id != -1:
					_cancel()
				else:
					exit_requested.emit()
			KEY_F9:
				if CampState.is_mock:
					EventBus.emit_event(&"resource_change_requested", {"key": "budget.labor", "amount": 500, "reason": "dev cheat"})
					EventBus.emit_event(&"resource_change_requested", {"key": "res.materials", "amount": 100, "reason": "dev cheat"})
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()


func _process(delta: float) -> void:
	if not is_open:
		return
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""
	if _ghost:
		var point: Variant = _camp.top_down_camera().ground_point(get_viewport().get_mouse_position())
		if point != null:
			_ghost.position = BuildGrid.snap(point)
			_ghost.rotation.y = _ghost_rotation
			_ghost.set_valid(_camp.construction.check_place(_ghost.type(), _ghost.position, _ghost_rotation).is_empty())
	_refresh_ui()


func _start_placing(type_id: String) -> void:
	_select(-1)
	if _ghost:
		_ghost.queue_free()
	_ghost = BuildingView.new()
	_ghost.is_ghost = true
	_ghost.ghost_type = type_id
	_camp.add_child(_ghost)
	var cost: Dictionary = BuildingTypes.get_type(type_id)["cost"]
	_say("%s: $%d + %d materials. R rotates." % [BuildingTypes.get_type(type_id)["name"], cost["budget"], cost["materials"]])


func _cancel() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_select(-1)


func _on_click(screen_pos: Vector2) -> void:
	var point: Variant = _camp.top_down_camera().ground_point(screen_pos)
	if point == null:
		return
	if _ghost == null:
		var view: Node3D = _camp.buildings.view_at(point)
		_select(view.building_id() if view else -1)
		return
	var problem: String = _camp.construction.place(_ghost.type(), BuildGrid.snap(point), _ghost_rotation)
	if not problem.is_empty():
		_say(problem)
		return
	if not Input.is_key_pressed(KEY_SHIFT):
		_cancel()


func _select(building_id: int) -> void:
	if _camp == null:
		return
	var old: Node3D = _camp.buildings.view_for(_selected_id)
	if old:
		old.selected = false
	_selected_id = building_id
	var view: Node3D = _camp.buildings.view_for(building_id)
	if view:
		view.selected = true


func _demolish_selected() -> void:
	if _camp.buildings.view_for(_selected_id) == null:
		_say("Click a building first")
		return
	_camp.construction.demolish(_selected_id)
	_say("Demolished. Got half the materials back.")
	_selected_id = -1


func _repair_selected() -> void:
	if _camp.buildings.view_for(_selected_id) == null:
		_say("Click a building first")
		return
	var cost: int = _camp.construction.repair_cost(_selected_id)
	var problem: String = _camp.construction.repair(_selected_id)
	_say(problem if not problem.is_empty() else "Patched up for %d materials." % cost)


func _on_building_completed(payload: Dictionary) -> void:
	if is_open:
		_say("%s finished!" % BuildingTypes.get_type(payload["type"])["name"])


func _say(text: String) -> void:
	_message.text = text
	_message_time = 3.0


func _refresh_ui() -> void:
	if _info == null or _camp == null:
		return
	var lines := PackedStringArray([
		"LABOR   Day %d, %s" % [CampState.get_value("day", 1), CampState.get_value("day_phase", "")],
		"Budget: $%d   Materials: %d" % [CampState.get_value("budget.labor", 0), CampState.get_value("res.materials", 0)],
		"Housing %d / %d   Beds %d   Labs %d   Workshops %d   Farms %d   Water %d" % [
			CampState.get_value("population", 0), CampState.get_value("capacity.housing", 0),
			CampState.get_value("capacity.beds", 0), CampState.get_value("capacity.labs", 0),
			CampState.get_value("capacity.workshops", 0), CampState.get_value("capacity.farms", 0),
			CampState.get_value("capacity.water", 0)],
	])
	var damaged: int = _camp.construction.damaged_count()
	if damaged > 0:
		lines.append("Damaged buildings: %d (select one, F to repair)" % damaged)
	var view: Node3D = _camp.buildings.view_for(_selected_id)
	if view:
		var record: Dictionary = view.record
		var state := "built" if record["built"] else "building %d%%" % roundi(record["progress"] * 100)
		var repair := ""
		if record["health"] < 1.0:
			repair = "   [F] repair: %d materials" % _camp.construction.repair_cost(_selected_id)
		lines.append("Selected: %s (%s, health %d%%)   [X] demolish%s" % [
			BuildingTypes.get_type(record["type"])["name"], state, roundi(record["health"] * 100), repair])
	if CampState.is_mock:
		lines.append("(mock camp state, F9 = +$500 and +100 materials)")
	_info.text = "\n".join(lines)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20, 16)
	_layer.add_child(box)
	_info = _label(22)
	box.add_child(_info)
	_message = _label(30)
	_message.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	box.add_child(_message)

	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position.y -= 70
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.add_theme_constant_override("separation", 10)
	_layer.add_child(bar)
	for i in BuildingTypes.ORDER.size():
		var type_id: String = BuildingTypes.ORDER[i]
		var data: Dictionary = BuildingTypes.get_type(type_id)
		var button := Button.new()
		button.text = "%s $%d [%d]" % [data["name"], data["cost"]["budget"], i + 1]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 48)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_start_placing.bind(type_id))
		bar.add_child(button)
	var jobs := Button.new()
	jobs.text = "Workers [J]"
	jobs.focus_mode = Control.FOCUS_NONE
	jobs.custom_minimum_size = Vector2(0, 48)
	jobs.add_theme_font_size_override("font_size", 18)
	jobs.pressed.connect(func() -> void: workers.visible = not workers.visible)
	bar.add_child(jobs)

	workers = WorkersPanel.new()
	workers.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	workers.offset_left = -440
	workers.offset_top = 16
	workers.offset_bottom = -90
	workers.offset_right = -16
	workers.visible = false
	_layer.add_child(workers)

	var leave := Button.new()
	leave.text = "Leave [Esc]"
	leave.focus_mode = Control.FOCUS_NONE
	leave.custom_minimum_size = Vector2(0, 48)
	leave.add_theme_font_size_override("font_size", 18)
	leave.pressed.connect(exit_requested.emit)
	bar.add_child(leave)


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.10))
	return label
