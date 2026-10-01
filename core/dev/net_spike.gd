extends Control
## PROTOTYPE: manual networking test. Run two instances of this scene
## (Debug > Customize Run Instances in the editor), Host in one, Join in the other.
## Host: Space advances the phase. Anyone: F asks for -5 food (a request event).

@onready var _address: LineEdit = %Address
@onready var _status: Label = %Status
@onready var _log: Label = %Log

var _lines: PackedStringArray = []


func _ready() -> void:
	%Host.pressed.connect(func() -> void: _report("host", Net.host()))
	%Join.pressed.connect(func() -> void: _report("join", Net.join(_address.text)))
	%Leave.pressed.connect(Net.leave)
	Net.connected.connect(_add_line.bind("connected"))
	Net.disconnected.connect(_add_line.bind("disconnected"))
	Net.connection_failed.connect(_add_line.bind("connection failed"))
	Net.peer_joined.connect(func(id: int) -> void: _add_line("peer %d joined" % id))
	Net.peer_left.connect(func(id: int) -> void: _add_line("peer %d left" % id))
	EventBus.event_emitted.connect(func(event_name: StringName, payload: Dictionary) -> void:
		_add_line("event %s %s" % [event_name, payload]))
	# Stand-in for sim (Lane B), which normally applies resource requests.
	EventBus.subscribe(&"resource_change_requested", func(payload: Dictionary) -> void:
		if CampState.is_authority():
			CampState.add_value(payload["key"], payload["amount"]))
	CampState.value_changed.connect(func(_k: String, _o: Variant, _n: Variant) -> void: _refresh())
	CampState.state_reset.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			GameClock.advance_phase()
		KEY_F:
			EventBus.emit_event(&"resource_change_requested", {"key": "res.food", "amount": -5})


func _refresh() -> void:
	var role := "offline"
	if Net.is_online():
		role = "host (authority)" if multiplayer.is_server() else "client %d" % multiplayer.get_unique_id()
	_status.text = "%s\nDay %d, %s   Food: %s\n[Space] next phase (host)   [F] request -5 food" % [
		role, GameClock.current_day(), GameClock.current_phase(), CampState.get_value("res.food")]


func _report(action: String, err: Error) -> void:
	if err != OK:
		_add_line("%s failed: %s" % [action, error_string(err)])
	_refresh()


func _add_line(text: String) -> void:
	_lines.append(text)
	if _lines.size() > 14:
		_lines.remove_at(0)
	_log.text = "\n".join(_lines)
	_refresh()
