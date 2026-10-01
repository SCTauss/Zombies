extends Node
## Politician view: the office desk (Phase 1-2, Lane B). Follows the view
## contract (docs/CONTRACTS.md); it's a 2D desk, so it ignores the camp.
##
## Tabs:
##   1 Inbox    - documents from the other roles and citizens ("documents.inbox"):
##                read the effects, then SIGN (S) or REJECT (R).
##   2 Budget   - split the treasury between the four roles.
##   3 Policies - enact / revoke camp-wide policies (sim/policies.gd).
##   4 Report   - what happened last night.
## Every action is a request to sim; Esc leaves.

signal exit_requested

const UITheme := preload("res://ui/theme.gd")
const Policies := preload("res://sim/policies.gd")

const ROLES: Array[String] = ["politician", "military", "medic", "labor"]
const BUDGET_STEP := 25
const TABS: Array[String] = ["Inbox", "Budget", "Policies", "Report"]
const KEY_NAMES := {
	"money": "Treasury", "approval": "Approval",
	"budget.military": "Military budget", "budget.labor": "Labor budget",
	"budget.medic": "Medic budget", "budget.politician": "Your budget",
	"res.food": "Food", "res.water": "Water", "res.materials": "Materials",
	"res.medicine": "Medicine", "res.parts": "Parts", "res.ammo": "Ammo",
}

var is_open := false
var tab := 0

var _selected_doc := -1
var _budget_draft := {}  # role -> wanted amount
var _layer: CanvasLayer
var _stats: Label
var _approval: ProgressBar
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _doc_list: VBoxContainer
var _doc_paper: Label
var _doc_effects: Label
var _doc_buttons: HBoxContainer
var _budget_rows: Dictionary = {}  # role -> Label
var _budget_summary: Label
var _policy_buttons: Dictionary = {}  # policy id -> Button
var _report: Label
var _stamp: Label


## Camp state keys this desk shows (it only redraws when one changes).
const WATCHED: Array[String] = ["day", "money", "approval", "population", "infection.level",
	"documents.inbox", "policies.active", "report.last_day"]


func _ready() -> void:
	_build_ui()
	_layer.visible = false
	CampState.value_changed.connect(func(key: String, _o: Variant, _n: Variant) -> void:
		if is_open and (WATCHED.has(key) or key.begins_with("budget.")):
			_refresh())
	CampState.state_reset.connect(_refresh)


func open_view(_camp: Node) -> void:
	is_open = true
	_layer.visible = true
	_budget_draft.clear()
	_refresh()


func close_view() -> void:
	is_open = false
	_layer.visible = false


func show_tab(index: int) -> void:
	tab = clampi(index, 0, TABS.size() - 1)
	_refresh()


## The document being read, or {}.
func selected_document() -> Dictionary:
	for document: Dictionary in CampState.get_value("documents.inbox", []):
		if document["id"] == _selected_doc:
			return document
	return {}


func decide_document(decision: String) -> void:
	var document := selected_document()
	if document.is_empty():
		return
	EventBus.emit_event(&"document_decision_requested", {"document_id": document["id"], "decision": decision})
	if selected_document().is_empty():  # sim accepted it
		_show_stamp("SIGNED" if decision == "sign" else "REJECTED", UITheme.GOOD if decision == "sign" else UITheme.BAD)
	else:
		_show_stamp("CAN'T AFFORD", UITheme.WARN)
	_selected_doc = -1
	_refresh()


## Change a role's draft budget by `delta` (not applied until apply_budget()).
func nudge_budget(role: String, delta: int) -> void:
	var current := int(_budget_draft.get(role, CampState.get_value("budget." + role, 0)))
	_budget_draft[role] = maxi(0, current + delta)
	_refresh()


func apply_budget() -> void:
	if _budget_draft.is_empty():
		return
	EventBus.emit_event(&"budget_allocation_requested", {"budget": _budget_draft.duplicate()})
	_budget_draft.clear()
	_refresh()


func toggle_policy(policy_id: String) -> void:
	var active: Array = CampState.get_value("policies.active", [])
	EventBus.emit_event(&"policy_change_requested", {"policy_id": policy_id, "active": not active.has(policy_id)})
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			show_tab(event.keycode - KEY_1)
		KEY_S:
			if tab == 0:
				decide_document("sign")
		KEY_R:
			if tab == 0:
				decide_document("reject")
		KEY_ESCAPE:
			exit_requested.emit()
		_:
			return
	get_viewport().set_input_as_handled()


func _draft_total_delta() -> int:
	var delta := 0
	for role: String in _budget_draft:
		delta += int(_budget_draft[role]) - int(CampState.get_value("budget." + role, 0))
	return delta


func _effects_text(effects: Dictionary) -> String:
	if effects.is_empty():
		return "nothing"
	var parts := PackedStringArray()
	for key: String in effects:
		var value: Variant = effects[key]
		var what: String = KEY_NAMES.get(key, key)
		if key == "approval":
			parts.append("%s %+d%%" % [what, roundi(value * 100)])
		elif key == "money" or key.begins_with("budget."):
			parts.append("%s %s$%d" % [what, "+" if value >= 0 else "-", absi(value)])
		else:
			parts.append("%s %+d" % [what, value])
	return ", ".join(parts)


func _refresh() -> void:
	if _layer == null:
		return
	var approval: float = CampState.get_value("approval", 0.5)
	_stats.text = "Day %d   ·   Treasury $%d   ·   Population %d   ·   Infection %d%%" % [
		CampState.get_value("day", 1), CampState.get_value("money", 0), CampState.get_value("population", 0),
		roundi(CampState.get_value("infection.level", 0.0) * 100)]
	_approval.value = approval * 100
	var inbox: Array = CampState.get_value("documents.inbox", [])
	_tab_buttons[0].text = "1 Inbox (%d)" % inbox.size()
	for i in _pages.size():
		_pages[i].visible = i == tab
		_tab_buttons[i].add_theme_stylebox_override("normal", UITheme.box(UITheme.BUTTON if i == tab else UITheme.PAPER_DARK, 3, 12, 4))
	match tab:
		0:
			_refresh_inbox(inbox)
		1:
			_refresh_budget()
		2:
			_refresh_policies()
		3:
			_refresh_report()


func _refresh_inbox(inbox: Array) -> void:
	if selected_document().is_empty():
		_selected_doc = inbox[0]["id"] if not inbox.is_empty() else -1
	for child in _doc_list.get_children():
		child.queue_free()
	for document: Dictionary in inbox:
		var button := UITheme.colored_button("%s\nfrom %s" % [document["title"], document["from_role"].capitalize()],
			UITheme.BUTTON if document["id"] == _selected_doc else UITheme.PAPER, 16)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void:
			_selected_doc = document["id"]
			_refresh())
		_doc_list.add_child(button)
	var document := selected_document()
	_doc_buttons.visible = not document.is_empty()
	if document.is_empty():
		_doc_paper.text = "Your inbox is empty. New paperwork arrives every morning."
		_doc_effects.text = ""
		return
	_doc_paper.text = "%s\nFrom: %s · Day %d\n\n%s" % [document["title"].to_upper(), document["from_role"].capitalize(),
		document["day"], document["body"]]
	_doc_effects.text = "If you sign: %s\nIf you reject: %s" % [
		_effects_text(document["effects_if_signed"]), _effects_text(document["effects_if_rejected"])]


func _refresh_budget() -> void:
	for role in ROLES:
		var current: int = CampState.get_value("budget." + role, 0)
		var wanted := int(_budget_draft.get(role, current))
		_budget_rows[role].text = "%s: $%d%s" % [role.capitalize(), wanted, "  (now $%d)" % current if wanted != current else ""]
	var delta := _draft_total_delta()
	var after := int(CampState.get_value("money", 0)) - delta
	_budget_summary.text = "Treasury after: $%d%s" % [after, "   NOT ENOUGH MONEY" if after < 0 else ""]


func _refresh_policies() -> void:
	var active: Array = CampState.get_value("policies.active", [])
	for policy_id: String in _policy_buttons:
		var on := active.has(policy_id)
		var button: Button = _policy_buttons[policy_id]
		button.text = "Revoke" if on else "Enact"
		button.add_theme_stylebox_override("normal", UITheme.box(UITheme.BAD if on else UITheme.GOOD, 3, 12, 4))


func _refresh_report() -> void:
	var report: Dictionary = CampState.get_value("report.last_day", {})
	if report.is_empty():
		_report.text = "No report yet. Come back after the first night."
		return
	_report.text = "LAST NIGHT (day %d)\n\nIncome: $%d   Costs: $%d\nFood: +%d made, -%d eaten%s\nWater: +%d made, -%d drunk%s\nParts made: %d\nHomeless: %d\nNew infections: %d   Turned: %d\nApproval change: %+d%%" % [
		report.get("day", 0), report.get("income", 0), report.get("cost", 0),
		report.get("food_made", 0), report.get("food_used", 0), "  (STARVING!)" if report.get("starving") else "",
		report.get("water_made", 0), report.get("water_used", 0), "  (THIRSTY!)" if report.get("thirsty") else "",
		report.get("parts_made", 0), report.get("homeless", 0), report.get("infected", 0), report.get("turned", 0),
		roundi(report.get("approval_delta", 0.0) * 100)]


func _show_stamp(text: String, color: Color) -> void:
	_stamp.text = text
	_stamp.add_theme_color_override("font_color", color)
	_stamp.visible = true
	_stamp.scale = Vector2(2.2, 2.2)
	_stamp.modulate.a = 1.0
	var tween := _stamp.create_tween()
	tween.tween_property(_stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.7)
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
	desk.color = Color(0.32, 0.20, 0.16)
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
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	header.add_child(UITheme.label("POLITICIAN · Office", 30, UITheme.PAPER))
	_stats = UITheme.label("", 19, UITheme.PAPER)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_stats)
	var approval_box := VBoxContainer.new()
	approval_box.add_child(UITheme.label("Approval", 16, UITheme.PAPER))
	_approval = ProgressBar.new()
	_approval.custom_minimum_size = Vector2(160, 26)
	approval_box.add_child(_approval)
	header.add_child(approval_box)
	var leave := UITheme.colored_button("Leave [Esc]", UITheme.PAPER_DARK, 18)
	leave.pressed.connect(exit_requested.emit)
	header.add_child(leave)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	for i in TABS.size():
		var button := UITheme.colored_button("%d %s" % [i + 1, TABS[i]], UITheme.PAPER_DARK, 20)
		button.pressed.connect(show_tab.bind(i))
		tabs.add_child(button)
		_tab_buttons.append(button)

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(pages)
	_pages = [_build_inbox(), _build_budget(), _build_policies(), _build_report()]
	for page in _pages:
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages.add_child(page)

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


func _build_inbox() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 380
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_doc_list = VBoxContainer.new()
	_doc_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_doc_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_doc_list)
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	paper.add_child(box)
	_doc_paper = UITheme.label("", 22)
	_doc_paper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_doc_paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_doc_paper)
	_doc_effects = UITheme.label("", 19, Color(0.35, 0.25, 0.20))
	_doc_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_doc_effects)
	_doc_buttons = HBoxContainer.new()
	_doc_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_doc_buttons.add_theme_constant_override("separation", 20)
	box.add_child(_doc_buttons)
	for entry in [["SIGN [S]", UITheme.GOOD, "sign"], ["REJECT [R]", UITheme.BAD, "reject"]]:
		var button := UITheme.colored_button(entry[0], entry[1], 26)
		button.custom_minimum_size = Vector2(220, 58)
		button.pressed.connect(decide_document.bind(entry[2]))
		_doc_buttons.add_child(button)
	return row


func _build_budget() -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UITheme.label("Split the treasury. Money you give a role is theirs to spend.", 22))
	for role in ROLES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var minus := UITheme.colored_button("-$%d" % BUDGET_STEP, UITheme.BAD, 20)
		minus.pressed.connect(nudge_budget.bind(role, -BUDGET_STEP))
		row.add_child(minus)
		var plus := UITheme.colored_button("+$%d" % BUDGET_STEP, UITheme.GOOD, 20)
		plus.pressed.connect(nudge_budget.bind(role, BUDGET_STEP))
		row.add_child(plus)
		var label := UITheme.label("", 24)
		row.add_child(label)
		_budget_rows[role] = label
	_budget_summary = UITheme.label("", 22)
	box.add_child(_budget_summary)
	var apply := UITheme.colored_button("Apply budget", UITheme.BUTTON, 24)
	apply.custom_minimum_size = Vector2(260, 56)
	apply.pressed.connect(apply_budget)
	box.add_child(apply)
	return panel


func _build_policies() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for policy_id: String in Policies.POLICIES:
		var data: Dictionary = Policies.POLICIES[policy_id]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(390, 150)
		grid.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		box.add_child(UITheme.label(data["name"], 24))
		var desc := UITheme.label(data["desc"], 17)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(desc)
		box.add_child(UITheme.label("Approval %+d%% / day" % roundi(data["approval_per_day"] * 100), 16, Color(0.35, 0.25, 0.20)))
		var button := UITheme.colored_button("Enact", UITheme.GOOD, 20)
		button.pressed.connect(toggle_policy.bind(policy_id))
		box.add_child(button)
		_policy_buttons[policy_id] = button
	return grid


func _build_report() -> Control:
	var panel := PanelContainer.new()
	_report = UITheme.label("", 24)
	panel.add_child(_report)
	return panel
