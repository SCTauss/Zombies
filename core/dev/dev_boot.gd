extends Control
## PROTOTYPE: placeholder main scene until Lane B's main menu (ui/) exists.
## Shows the clock from mock camp state. Space advances the phase,
## A toggles real-time auto-advance.

@onready var _label: Label = $Label


func _ready() -> void:
	CampState.value_changed.connect(func(_key: String, _old: Variant, _new: Variant) -> void: _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				GameClock.advance_phase()
			KEY_A:
				GameClock.auto_advance = not GameClock.auto_advance
				_refresh()


func _refresh() -> void:
	_label.text = "Brain Drain (dev boot)\nDay %d, %s%s\nMoney: %s   Population: %s\n\n[Space] next phase   [A] auto-advance: %s" % [
		GameClock.current_day(),
		GameClock.current_phase(),
		"  (mock state)" if CampState.is_mock else "",
		CampState.get_value("money"),
		CampState.get_value("population"),
		"on" if GameClock.auto_advance else "off",
	]
