extends Node
## Medic view: the check-in desk at the gate (Phase 1, Lane B). Follows the
## view contract (docs/CONTRACTS.md); it's a 2D desk, so it ignores the camp.
##
## Survivors wait in camp state "gate.queue" (sim fills it every morning).
## Read their story and papers, use up to 3 exams to find symptoms, then
## admit, quarantine (needs a free bed) or reject. Decisions are requests to
## sim (`survivor_decision_requested`); infected people you let in will turn.
##
## Keys: 1-5 exams, A admit, Q quarantine, R reject, Esc leave.

signal exit_requested

const UITheme := preload("res://ui/theme.gd")
const BeanPortrait := preload("res://ui/widgets/bean_portrait.gd")

const EXAMS_PER_PERSON := 3
const EXAMS := [
	{"id": "thermometer", "label": "Thermometer", "finds": {"fever": "39.8°C. Burning up!"}, "clear": "36.9°C. Normal."},
	{"id": "flashlight", "label": "Flashlight", "finds": {"red_eyes": "Bloodshot red eyes."}, "clear": "Eyes look fine."},
	{"id": "arms", "label": "Check arms", "finds": {"bite": "A BITE MARK on the arm!"}, "clear": "No marks on the arms."},
	{"id": "listen", "label": "Stethoscope",
		"finds": {"shaking": "Hands won't stop shaking.", "cough": "A dry cough. Could be a cold."}, "clear": "Breathing normally."},
	{"id": "skin", "label": "Check skin",
		"finds": {"grey_skin": "Skin has a grey tinge.", "rash": "An itchy rash. Probably fleas."}, "clear": "Skin looks healthy."},
]
const VISIBLE := {"sneezing": "Sneezes constantly.", "limp": "Walks with a limp."}

var is_open := false

var _current_id := -1
var _exams_left := {}  # citizen id -> int
var _findings := {}  # citizen id -> Array[[text, symptom]]
var _layer: CanvasLayer
var _stats: Label
var _queue_row: HBoxContainer
var _portrait: Control
var _story: Label
var _id_card: Label
var _health: Label
var _exam_title: Label
var _exam_buttons: Array[Button] = []
var _results: Label
var _quarantine: Button
var _stamp: Label
var _people_panel: Control
var _empty: Label


func _ready() -> void:
	_build_ui()
	_layer.visible = false
	CampState.value_changed.connect(_on_value_changed)
	CampState.state_reset.connect(_refresh)


func open_view(_camp: Node) -> void:
	is_open = true
	_layer.visible = true
	_refresh()


func close_view() -> void:
	is_open = false
	_layer.visible = false


## The survivor being examined, or {}.
func current() -> Dictionary:
	for citizen: Dictionary in CampState.get_value("gate.queue", []):
		if citizen["id"] == _current_id:
			return citizen
	return {}


## Run exam `index` (0-4) on the current survivor. Returns the finding text.
func exam(index: int) -> String:
	var citizen := current()
	if citizen.is_empty() or _exams_left.get(_current_id, EXAMS_PER_PERSON) <= 0:
		return ""
	var data: Dictionary = EXAMS[index]
	var text: String = data["clear"]
	var found := ""
	for symptom: String in data["finds"]:
		if citizen["symptoms"].has(symptom):
			text = data["finds"][symptom]
			found = symptom
			break
	_exams_left[_current_id] = _exams_left.get(_current_id, EXAMS_PER_PERSON) - 1
	_findings.get_or_add(_current_id, []).append(["%s: %s" % [data["label"], text], found])
	_refresh()
	return text


func decide(decision: String) -> void:
	var citizen := current()
	if citizen.is_empty():
		return
	if decision == "quarantine" and _free_beds() <= 0:
		return
	EventBus.emit_event(&"survivor_decision_requested", {"citizen_id": citizen["id"], "decision": decision})
	_show_stamp({"admit": "ADMITTED", "quarantine": "QUARANTINE", "reject": "REJECTED"}[decision],
		{"admit": UITheme.GOOD, "quarantine": UITheme.WARN, "reject": UITheme.BAD}[decision])
	_findings.erase(citizen["id"])
	_exams_left.erase(citizen["id"])
	_current_id = -1
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			exam(event.keycode - KEY_1)
		KEY_A:
			decide("admit")
		KEY_Q:
			decide("quarantine")
		KEY_R:
			decide("reject")
		KEY_ESCAPE:
			exit_requested.emit()
		_:
			return
	get_viewport().set_input_as_handled()


func _free_beds() -> int:
	var quarantined: int = CampState.get_value("citizens", []).filter(func(c: Dictionary) -> bool:
		return c["legal_status"] == "quarantined").size()
	return int(CampState.get_value("capacity.beds", 0)) - quarantined


func _on_value_changed(key: String, _old: Variant, _new: Variant) -> void:
	if is_open and key in ["gate.queue", "citizens", "capacity.beds", "day", "infection.level"]:
		_refresh()


func _refresh() -> void:
	if _layer == null:
		return
	var queue: Array = CampState.get_value("gate.queue", [])
	if current().is_empty():
		_current_id = queue[0]["id"] if not queue.is_empty() else -1
	var day: int = CampState.get_value("day", 1)
	_stats.text = "Day %d   ·   At the gate: %d   ·   Free beds: %d / %d   ·   Infection: %d%%" % [
		day, queue.size(), maxi(0, _free_beds()), CampState.get_value("capacity.beds", 0),
		roundi(CampState.get_value("infection.level", 0.0) * 100)]
	for child in _queue_row.get_children():
		child.queue_free()
	for citizen: Dictionary in queue:
		var thumb := BeanPortrait.new()
		thumb.custom_minimum_size = Vector2(56, 68)
		thumb.citizen = citizen
		thumb.modulate = Color.WHITE if citizen["id"] == _current_id else Color(1, 1, 1, 0.55)
		thumb.mouse_filter = Control.MOUSE_FILTER_STOP
		thumb.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				_current_id = citizen["id"]
				_refresh())
		_queue_row.add_child(thumb)

	var citizen := current()
	_people_panel.visible = not citizen.is_empty()
	_empty.visible = citizen.is_empty()
	if citizen.is_empty():
		return
	var found: Array = _findings.get(citizen["id"], [])
	_portrait.citizen = citizen
	_portrait.revealed = found.map(func(f: Array) -> String: return f[1]).filter(func(s: String) -> bool: return s != "")
	var notes := PackedStringArray()
	for symptom: String in VISIBLE:
		if citizen["symptoms"].has(symptom):
			notes.append(VISIBLE[symptom])
	_story.text = "\"I'm %s, %d years old.\nPlease, let me in!\"\n\n%s" % [citizen["name"], citizen["age"], "\n".join(notes)]
	var papers: Array = citizen["documents"]
	var id_card: Dictionary = papers[0] if papers.size() > 0 else {}
	var health: Dictionary = papers[1] if papers.size() > 1 else {}
	_id_card.text = "ID CARD\nName: %s\nAge: %s" % [id_card.get("name", "?"), id_card.get("age", "?")]
	_health.text = "HEALTH CERTIFICATE\nName: %s\nStatus: %s\nValid until: day %s\n(today is day %d)" % [
		health.get("name", "?"), "CLEAN" if health.get("clean", false) else "NOT CLEAN",
		health.get("valid_until", "?"), day]
	var left: int = _exams_left.get(citizen["id"], EXAMS_PER_PERSON)
	_exam_title.text = "Exams (%d left)" % left
	for button in _exam_buttons:
		button.disabled = left <= 0
	_results.text = "\n".join(found.map(func(f: Array) -> String: return f[0])) if not found.is_empty() else "No exams yet."
	var beds := _free_beds()
	_quarantine.disabled = beds <= 0
	_quarantine.text = "QUARANTINE [Q]" if beds > 0 else "NO FREE BEDS"


func _show_stamp(text: String, color: Color) -> void:
	_stamp.text = text
	_stamp.add_theme_color_override("font_color", color)
	_stamp.visible = true
	_stamp.scale = Vector2(2.2, 2.2)
	_stamp.modulate.a = 1.0
	var tween := _stamp.create_tween()
	tween.tween_property(_stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.8)
	tween.tween_property(_stamp, "modulate:a", 0.0, 0.4)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.cartoon()
	_layer.add_child(root)
	var desk := ColorRect.new()
	desk.color = UITheme.DESK
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(desk)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(UITheme.label("MEDIC · Check-in desk", 30, UITheme.PAPER))
	_stats = UITheme.label("", 20, UITheme.PAPER)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_stats)
	var leave := UITheme.colored_button("Leave [Esc]", UITheme.PAPER_DARK, 18)
	leave.pressed.connect(exit_requested.emit)
	header.add_child(leave)

	_queue_row = HBoxContainer.new()
	_queue_row.custom_minimum_size.y = 70
	_queue_row.add_theme_constant_override("separation", 8)
	column.add_child(_queue_row)

	_empty = UITheme.label("Nobody at the gate. More survivors show up every morning.", 26, UITheme.PAPER)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(_empty)

	var people := VBoxContainer.new()
	people.size_flags_vertical = Control.SIZE_EXPAND_FILL
	people.add_theme_constant_override("separation", 12)
	column.add_child(people)
	_people_panel = people
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 14)
	people.add_child(main)

	var who := PanelContainer.new()
	who.custom_minimum_size.x = 330
	main.add_child(who)
	var who_box := VBoxContainer.new()
	who.add_child(who_box)
	_portrait = BeanPortrait.new()
	_portrait.custom_minimum_size = Vector2(170, 200)
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	who_box.add_child(_portrait)
	_story = UITheme.label("", 19)
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who_box.add_child(_story)

	var papers := VBoxContainer.new()
	papers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	papers.add_theme_constant_override("separation", 12)
	main.add_child(papers)
	for i in 2:
		var paper := PanelContainer.new()
		paper.add_theme_stylebox_override("panel", UITheme.box(Color(0.92, 0.96, 1.0) if i == 0 else Color(0.95, 1.0, 0.92), 3, 6, 5))
		paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
		papers.add_child(paper)
		var text := UITheme.label("", 21)
		paper.add_child(text)
		if i == 0:
			_id_card = text
		else:
			_health = text

	var exams := PanelContainer.new()
	exams.custom_minimum_size.x = 340
	main.add_child(exams)
	var exam_box := VBoxContainer.new()
	exam_box.add_theme_constant_override("separation", 6)
	exams.add_child(exam_box)
	_exam_title = UITheme.label("Exams", 22)
	exam_box.add_child(_exam_title)
	for i in EXAMS.size():
		var button := UITheme.colored_button("%d  %s" % [i + 1, EXAMS[i]["label"]], Color(0.70, 0.88, 1.0), 18)
		button.pressed.connect(exam.bind(i))
		exam_box.add_child(button)
		_exam_buttons.append(button)
	_results = UITheme.label("", 17)
	_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exam_box.add_child(_results)

	var decisions := HBoxContainer.new()
	decisions.alignment = BoxContainer.ALIGNMENT_CENTER
	decisions.add_theme_constant_override("separation", 20)
	people.add_child(decisions)
	for entry in [["ADMIT [A]", UITheme.GOOD, "admit"], ["QUARANTINE [Q]", UITheme.WARN, "quarantine"], ["REJECT [R]", UITheme.BAD, "reject"]]:
		var button := UITheme.colored_button(entry[0], entry[1], 26)
		button.custom_minimum_size = Vector2(240, 60)
		button.pressed.connect(decide.bind(entry[2]))
		decisions.add_child(button)
		if entry[2] == "quarantine":
			_quarantine = button

	_stamp = UITheme.label("", 90)
	_stamp.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_stamp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stamp.grow_vertical = Control.GROW_DIRECTION_BOTH
	_stamp.add_theme_constant_override("outline_size", 14)
	_stamp.add_theme_color_override("font_outline_color", UITheme.INK)
	_stamp.rotation = -0.2
	_stamp.visible = false
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stamp)
