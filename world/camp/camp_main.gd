extends "res://world/camp/camp_base.gd"
## The shared camp (Phase 2, H-009): one world, four player characters, four
## role stations. Walk with WASD (camera-relative), Shift sprints, Space jumps,
## right drag / arrows orbit the camera, wheel zooms.
## E at your own station opens your role's view; Esc leaves it.
## Tab switches which character you control (solo play; O-06/O-11 still open).
## F1 = skip to the next day phase (dev).

const PlayerScene := preload("res://world/players/player.tscn")
const StationScript := preload("res://world/stations/station.gd")
const CharacterLook := preload("res://world/players/character_look.gd")

const ROLES: Array[String] = ["politician", "military", "medic", "labor"]
const STATION_SPOTS := {
	"politician": Vector3(-5, 0, -6),
	"medic": Vector3(6, 0, -6),
	"military": Vector3(6, 0, 6),
	"labor": Vector3(-6, 0, 6),
}
const VIEW_SCENES := {
	"politician": "res://roles/politician/politician_view.tscn",
	"military": "res://roles/military/military_view.tscn",
	"medic": "res://roles/medic/medic_view.tscn",
	"labor": "res://roles/labor/labor_view.tscn",
}

var players := {}  # role -> player
var stations := {}  # role -> station
var views := {}  # role -> view (missing until that role's view exists)
var controlled_role := "military"
var active_view := ""  # role whose view is open, or ""

var _hud: CanvasLayer
var _who: Label
var _clock: Label
var _resources: Label
var _prompt: Label
var _message: Label
var _message_time := 0.0

@onready var follow_camera: Node3D = $FollowCamera


func _ready() -> void:
	top_down_camera().active = false
	GameClock.auto_advance = true
	for role in ROLES:
		_add_station(role)
		_add_player(role)
		_add_view(role)
	map.request_rebake()
	_build_hud()
	control(controlled_role)


func _exit_tree() -> void:
	GameClock.auto_advance = false


## Dev / screenshot helper: open the Military view from inside the camp, with towers and a wave.
func dev_demo() -> void:
	open_view("military")
	views["military"].dev_demo()


## Take control of `role`'s character (solo play).
func control(role: String) -> void:
	for r: String in players:
		players[r].controlled = r == role
	controlled_role = role
	follow_camera.yaw = players[role].rotation.y  # start behind the character
	follow_camera.follow(players[role])
	follow_camera.camera.make_current()
	_who.text = "You are the %s   (Tab: switch character)" % CharacterLook.display_name(role).to_upper()
	_who.add_theme_color_override("font_color", CharacterLook.tag_color(role))


## The station the controlled player is standing at, or null.
func station_in_range() -> Node3D:
	var pos: Vector3 = players[controlled_role].global_position
	for station: Node3D in stations.values():
		if station.in_range(pos):
			return station
	return null


## Use the station in range. Returns true if a view opened.
func try_interact() -> bool:
	var station := station_in_range()
	if station == null:
		return false
	if station.role != controlled_role:
		_say("That's the %s's %s." % [CharacterLook.display_name(station.role), StationScript.title(station.role).to_lower()])
		return false
	if not views.has(station.role):
		_say("The %s view isn't built yet (Lane B)." % CharacterLook.display_name(station.role))
		return false
	open_view(station.role)
	return true


func open_view(role: String) -> void:
	if active_view != "":
		close_view()
	active_view = role
	players[controlled_role].input_enabled = false
	follow_camera.active = false
	_hud.visible = false
	views[role].open_view(self)


func close_view() -> void:
	if active_view == "":
		return
	views[active_view].close_view()
	active_view = ""
	players[controlled_role].input_enabled = true
	follow_camera.active = true
	follow_camera.camera.make_current()
	_hud.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if active_view != "" or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_E:
			try_interact()
		KEY_TAB:
			control(ROLES[(ROLES.find(controlled_role) + 1) % ROLES.size()])
		KEY_F1:
			GameClock.advance_phase()
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	players[controlled_role].camera_yaw = follow_camera.yaw
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""
	var near := station_in_range() if active_view == "" else null
	for station: Node3D in stations.values():
		station.highlighted = station == near
	if near == null:
		_prompt.text = ""
	elif near.role == controlled_role:
		_prompt.text = "[E] Use the %s" % StationScript.title(near.role).to_lower()
	else:
		_prompt.text = "%s's %s" % [CharacterLook.display_name(near.role), StationScript.title(near.role).to_lower()]
	var spawner_text := ""
	if spawner.is_active:
		spawner_text = "   WAVE %d: %d zombies!" % [spawner.wave, spawner.remaining()]
	_clock.text = "Day %d, %s (%d%%)%s" % [GameClock.current_day(), GameClock.current_phase(),
		roundi(GameClock.phase_progress() * 100), spawner_text]
	_resources.text = "$%d   Food %d   Water %d   Materials %d\nPeople %d / %d homes   Approval %d%%   Infection %d%%   Walls %d%%" % [
		CampState.get_value("money", 0), CampState.get_value("res.food", 0), CampState.get_value("res.water", 0),
		CampState.get_value("res.materials", 0), CampState.get_value("population", 0),
		CampState.get_value("capacity.housing", 0), roundi(CampState.get_value("approval", 0.0) * 100),
		roundi(CampState.get_value("infection.level", 0.0) * 100), roundi(CampState.get_value("defense.integrity", 1.0) * 100)]


func _add_station(role: String) -> void:
	var station := StationScript.new()
	station.role = role
	station.position = STATION_SPOTS[role]
	$Stations.add_child(station)
	stations[role] = station
	map.occupy(station, StationScript.HALF)


func _add_player(role: String) -> void:
	var player := PlayerScene.instantiate()
	player.role = role
	# Stand between the station and the heart, facing the station.
	var spot: Vector3 = STATION_SPOTS[role]
	player.position = spot - spot.normalized() * 2.2
	player.rotation.y = atan2(-spot.x, -spot.z)
	$Players.add_child(player)
	players[role] = player


func _add_view(role: String) -> void:
	if not ResourceLoader.exists(VIEW_SCENES[role]):
		return
	var view: Node = (load(VIEW_SCENES[role]) as PackedScene).instantiate()
	$Views.add_child(view)
	view.exit_requested.connect(close_view)
	views[role] = view


func _say(text: String) -> void:
	_message.text = text
	_message_time = 3.0


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var top := VBoxContainer.new()
	top.position = Vector2(20, 16)
	_hud.add_child(top)
	_who = _label(24)
	top.add_child(_who)
	_clock = _label(22)
	top.add_child(_clock)
	_message = _label(26)
	_message.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	top.add_child(_message)
	_resources = _label(20)
	_resources.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_resources.offset_left = -560
	_resources.offset_right = -20
	_resources.offset_top = 16
	_resources.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # long text grows left, not off-screen
	_resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_resources)
	_prompt = _label(30)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position.y -= 110
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_prompt)
	var hint := _label(18)
	hint.text = "WASD move · Shift sprint · Space jump · right drag / arrows: camera · E use station · F1 next phase"
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 40
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(hint)


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.10))
	return label
