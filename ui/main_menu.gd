extends Control
## Main menu + lobby (Phase 3, Lane B). Uses only the Net session API
## (docs/CONTRACTS.md, "Session and lobby").
##
## Menu:  your name, Play solo, Host, Join (IP), Quit.
## Lobby: four role cards (take / give up), who's connected, your IP to share,
##        START for the host. When the host starts, everyone loads the camp.

const UITheme := preload("res://ui/theme.gd")
const BeanPortrait := preload("res://ui/widgets/bean_portrait.gd")

const CAMP_SCENE := "res://world/camp/camp_main.tscn"
const ROLES: Array[String] = ["politician", "military", "medic", "labor"]
const ROLE_INFO := {
	"politician": {"name": "Politician", "color": Color(0.55, 0.70, 1.0), "desc": "Paperwork, budgets, policies. Rule the camp."},
	"military": {"name": "Military", "color": Color(0.60, 0.85, 0.35), "desc": "Towers and waves. Hold the walls."},
	"medic": {"name": "Medic", "color": Color(1.0, 0.45, 0.45), "desc": "Check who gets in. Spot the bitten."},
	"labor": {"name": "Labor", "color": Color(1.0, 0.80, 0.25), "desc": "Build, repair, assign workers."},
}

## Tests turn this off so starting a run doesn't swap the scene.
var change_scene_on_start := true
var run_started := false

var _menu: Control
var _lobby: Control
var _name: LineEdit
var _address: LineEdit
var _status: Label
var _players: Label
var _ip_hint: Label
var _start: Button
var _role_buttons: Dictionary = {}  # role -> Button
var _role_owners: Dictionary = {}  # role -> Label


func _ready() -> void:
	theme = UITheme.cartoon()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Net.players_changed.connect(_refresh_lobby)
	Net.connected.connect(_on_connected)
	Net.connection_failed.connect(func() -> void: _show_menu("Couldn't connect. Check the IP, and that the host is waiting."))
	Net.disconnected.connect(func() -> void:
		if _lobby.visible:
			_show_menu("Disconnected from the game."))
	Net.run_started.connect(_on_run_started)
	_show_menu("")
	if Net.is_online():  # came back from a run while still connected
		_show_lobby()
	elif OS.get_cmdline_user_args().has("--solo"):  # dev shortcut: BrainDrain.exe -- --solo
		play_solo.call_deferred()


## Dev / screenshot helper: host and take a role to show the lobby.
func dev_demo() -> void:
	change_scene_on_start = false
	_name.text = "Juanjo"
	host_game()
	take_role("labor")


func play_solo() -> void:
	Net.leave()
	_start_camp()


func host_game() -> void:
	Net.set_player_name(_name.text)
	var err := Net.host()
	if err != OK:
		_status.text = "Couldn't host: %s (is another game already using port %d?)" % [error_string(err), Net.DEFAULT_PORT]
		return
	_show_lobby()


func join_game() -> void:
	Net.set_player_name(_name.text)
	var err := Net.join(_address.text.strip_edges())
	if err != OK:
		_status.text = "Couldn't join: %s" % error_string(err)
		return
	_status.text = "Connecting to %s..." % _address.text
	_set_menu_buttons_disabled(true)


func take_role(role: String) -> void:
	Net.request_role("" if Net.my_role() == role else role)


func leave_lobby() -> void:
	Net.leave()
	_show_menu("")


func _on_connected() -> void:
	if not Net.multiplayer.is_server():
		_show_lobby()


func _on_run_started() -> void:
	run_started = true
	_start_camp()


func _start_camp() -> void:
	if change_scene_on_start:
		get_tree().change_scene_to_file(CAMP_SCENE)


func _show_menu(message: String) -> void:
	_menu.visible = true
	_lobby.visible = false
	_status.text = message
	_set_menu_buttons_disabled(false)


func _show_lobby() -> void:
	_menu.visible = false
	_lobby.visible = true
	var addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	if Net.multiplayer.is_server():
		_ip_hint.text = "You're hosting. Friends join with your IP: %s\nOver the internet: open UDP port %d on your router, or use Tailscale / ZeroTier." % [
			", ".join(addresses) if not addresses.is_empty() else "(no network found)", Net.DEFAULT_PORT]
	else:
		_ip_hint.text = "Connected. Pick a role and wait for the host to start."
	_refresh_lobby()


func _refresh_lobby() -> void:
	if _lobby == null or not _lobby.visible:
		return
	var mine := Net.my_role()
	for role in ROLES:
		var holder := Net.peer_for_role(role)
		var button: Button = _role_buttons[role]
		if holder == 0:
			_role_owners[role].text = "Free"
			button.text = "Take"
			button.disabled = false
		elif role == mine:
			_role_owners[role].text = "You"
			button.text = "Give up"
			button.disabled = false
		else:
			_role_owners[role].text = Net.players[holder]["name"]
			button.text = "Taken"
			button.disabled = true
	var lines := PackedStringArray()
	for peer_id: int in Net.players:
		var player: Dictionary = Net.players[peer_id]
		var role: String = player["role"]
		lines.append("%s%s — %s" % [player["name"], " (host)" if peer_id == 1 else "",
			ROLE_INFO[role]["name"] if role != "" else "no role yet"])
	_players.text = "\n".join(lines)
	var is_host := Net.is_online() and Net.multiplayer.is_server()
	_start.visible = is_host
	_start.text = "START!" if mine != "" else "START (you have no role)"


func _set_menu_buttons_disabled(disabled: bool) -> void:
	for button in _menu.find_children("*", "Button", true, false):
		button.disabled = disabled


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.40, 0.62, 0.38)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_menu = _build_menu()
	add_child(_menu)
	_lobby = _build_lobby()
	add_child(_lobby)


func _build_menu() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := UITheme.label("BRAIN DRAIN", 64, Color(0.95, 0.35, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", UITheme.INK)
	box.add_child(title)
	var subtitle := UITheme.label("a co-op zombie camp for 1-4 survivors", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	_name = LineEdit.new()
	_name.placeholder_text = "Your name"
	_name.text = Net.player_name
	_name.max_length = 20
	box.add_child(_name)
	var solo := UITheme.colored_button("PLAY SOLO", UITheme.GOOD, 26)
	solo.pressed.connect(play_solo)
	box.add_child(solo)
	var host := UITheme.colored_button("HOST A GAME", UITheme.BUTTON, 26)
	host.pressed.connect(host_game)
	box.add_child(host)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	box.add_child(join_row)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Host IP"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_address)
	var join := UITheme.colored_button("JOIN", Color(0.70, 0.88, 1.0), 26)
	join.custom_minimum_size.x = 140
	join.pressed.connect(join_game)
	join_row.add_child(join)
	var quit := UITheme.colored_button("Quit", UITheme.PAPER_DARK, 20)
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	_status = UITheme.label("", 18, UITheme.BAD.darkened(0.3))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	return center


func _build_lobby() -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title := UITheme.label("LOBBY — pick your job", 40, UITheme.PAPER)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", UITheme.INK)
	column.add_child(title)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(cards)
	for i in ROLES.size():
		var role: String = ROLES[i]
		var info: Dictionary = ROLE_INFO[role]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(270, 300)
		card.add_theme_stylebox_override("panel", UITheme.box(info["color"].lightened(0.55), 4, 16, 6))
		cards.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)
		var portrait := BeanPortrait.new()
		portrait.custom_minimum_size = Vector2(90, 110)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait.citizen = {"id": i * 7 + 3}
		box.add_child(portrait)
		var name_label := UITheme.label(info["name"], 28)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var desc := UITheme.label(info["desc"], 16)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(desc)
		var owner_label := UITheme.label("Free", 20)
		owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(owner_label)
		_role_owners[role] = owner_label
		var button := UITheme.colored_button("Take", UITheme.BUTTON, 22)
		button.pressed.connect(take_role.bind(role))
		box.add_child(button)
		_role_buttons[role] = button
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 16)
	info_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(info_row)
	var players_panel := PanelContainer.new()
	players_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(players_panel)
	var players_box := VBoxContainer.new()
	players_panel.add_child(players_box)
	players_box.add_child(UITheme.label("Survivors", 22))
	_players = UITheme.label("", 19)
	players_box.add_child(_players)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size.x = 520
	info_row.add_child(right)
	_ip_hint = UITheme.label("", 17, UITheme.PAPER)
	_ip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_ip_hint)
	_start = UITheme.colored_button("START!", UITheme.GOOD, 30)
	_start.custom_minimum_size.y = 64
	_start.pressed.connect(Net.start_run)
	right.add_child(_start)
	var back := UITheme.colored_button("Leave lobby", UITheme.PAPER_DARK, 20)
	back.pressed.connect(leave_lobby)
	right.add_child(back)
	return margin
