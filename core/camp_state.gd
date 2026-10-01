extends Node
## Camp state container (autoload `CampState`).
##
## Holds and (later) syncs the shared camp state. It does NOT contain game
## rules: sim/ (Lane B) decides how values change and writes them here.
##
## Keys are flat strings from docs/CONTRACTS.md, e.g. "money", "res.food",
## "budget.military". Values must be plain serializable data.
##
## Only the authority writes. Non-authority code sends request events
## (e.g. `resource_change_requested`) through EventBus instead.

signal value_changed(key: String, old_value: Variant, new_value: Variant)
signal state_reset

const MockCamp := preload("res://core/mock_camp.gd")

## True while running on mock data (role scenes started on their own with F6).
var is_mock := false

var _state: Dictionary = {}


func _ready() -> void:
	# Until a real run starts, every scene gets mock state so it runs alone.
	load_mock()


## True if this machine may change camp state. Offline, that's always us.
## Networking (O-03) may refine this.
func is_authority() -> bool:
	return multiplayer.is_server()


func get_value(key: String, default: Variant = null) -> Variant:
	return _state.get(key, default)


func has_value(key: String) -> bool:
	return _state.has(key)


## Set a value. Returns false (and changes nothing) if we're not the authority.
func set_value(key: String, value: Variant) -> bool:
	if not is_authority():
		push_error("CampState: '%s' written by a non-authority peer; send a request event instead" % key)
		return false
	var old: Variant = _state.get(key)
	if _state.has(key) and typeof(old) == typeof(value) and old == value:
		return true
	_state[key] = value
	value_changed.emit(key, old, value)
	return true


## Add `amount` (int or float) to a numeric value (missing keys count as 0).
## int + int stays int, so counters like `money` don't turn into floats.
func add_value(key: String, amount: Variant) -> bool:
	return set_value(key, get_value(key, 0) + amount)


## All keys that start with `prefix`, e.g. keys_with_prefix("res.").
func keys_with_prefix(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for key: String in _state:
		if key.begins_with(prefix):
			result.append(key)
	result.sort()
	return result


## Deep copy of the whole state (for saves, network sync, debug views).
func snapshot() -> Dictionary:
	return _state.duplicate(true)


## Replace the whole state, e.g. from a save or the authority's sync.
func load_snapshot(data: Dictionary, mock := false) -> void:
	_state = data.duplicate(true)
	is_mock = mock
	state_reset.emit()


func load_mock() -> void:
	load_snapshot(MockCamp.create_state(), true)
