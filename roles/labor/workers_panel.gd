extends PanelContainer
## Labor's "Interact" v1: the residents and their jobs. Click a job to cycle
## it; the change is a request to sim (`citizen_job_change_requested`).
## Builders speed up construction; farmers add food each night.

const UITheme := preload("res://ui/theme.gd")

const JOBS: Array[String] = ["", "builder", "farmer", "soldier", "medic", "clerk"]
const JOB_NAMES := {"": "idle", "builder": "Builder", "farmer": "Farmer", "soldier": "Soldier", "medic": "Medic", "clerk": "Clerk"}

var _summary: Label
var _rows: VBoxContainer


func _ready() -> void:
	theme = UITheme.cartoon()
	custom_minimum_size = Vector2(420, 0)
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(UITheme.label("WORKERS  (J to close)", 22))
	_summary = UITheme.label("", 16)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	CampState.value_changed.connect(func(key: String, _o: Variant, _n: Variant) -> void:
		if visible and key == "citizens":
			refresh())
	visibility_changed.connect(func() -> void:
		if visible:
			refresh())


## The next job after `job` in the cycle.
static func next_job(job: String) -> String:
	return JOBS[(JOBS.find(job) + 1) % JOBS.size()]


func refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var counts := {}
	for citizen: Dictionary in CampState.get_value("citizens", []):
		if citizen["legal_status"] != "resident":
			continue
		counts[citizen["job"]] = counts.get(citizen["job"], 0) + 1
		var row := HBoxContainer.new()
		_rows.add_child(row)
		var best := _best_skill(citizen)
		var who := UITheme.label("%s (%s %d)" % [citizen["name"], best, citizen["skills"].get(best, 0)], 16)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		var job: String = citizen["job"]
		var button := UITheme.colored_button(JOB_NAMES.get(job, job), UITheme.PAPER_DARK if job == "" else UITheme.BUTTON, 16)
		button.custom_minimum_size.x = 110
		button.pressed.connect(func() -> void:
			EventBus.emit_event(&"citizen_job_change_requested", {"citizen_id": citizen["id"], "job": next_job(job)}))
		row.add_child(button)
	var parts := PackedStringArray()
	for job in JOBS:
		if counts.has(job):
			parts.append("%s %d" % [JOB_NAMES[job], counts[job]])
	_summary.text = " · ".join(parts) + "\nBuilders: +50% build speed each. Farmers: +2 food a night each."


static func _best_skill(citizen: Dictionary) -> String:
	var best := ""
	for skill: String in citizen["skills"]:
		if best == "" or citizen["skills"][skill] > citizen["skills"][best]:
			best = skill
	return best
