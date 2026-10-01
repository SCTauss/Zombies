extends Node
## Global event bus (autoload `EventBus`).
##
## Lanes talk to each other only through events and camp state (docs/CONTRACTS.md).
## Events are identified by name and carry a plain Dictionary payload, so they can
## be serialized and sent over the network later.
##
## Event declarations: each lane owns its own file under `res://contracts/`
## named `events_<lane>.gd` (e.g. `events_a.gd`, `events_b.gd`) with a
## `const EVENTS: Array[StringName] = [...]`. The bus loads every such file at
## startup, so both lanes can add events without editing the same file.
## Emitting an undeclared event logs a warning (once) while declarations exist.

signal event_emitted(event_name: StringName, payload: Dictionary)

const CONTRACTS_DIR := "res://contracts"

var _listeners: Dictionary = {}  # StringName -> Array[Callable]
var _declared: Dictionary = {}  # StringName -> source file
var _warned: Dictionary = {}


func _ready() -> void:
	_load_declarations()


## Emit an event to every subscriber.
func emit_event(event_name: StringName, payload: Dictionary = {}) -> void:
	_check_declared(event_name)
	event_emitted.emit(event_name, payload)
	for callable: Callable in _listeners.get(event_name, []).duplicate():
		if callable.is_valid():
			callable.call(payload)
		else:
			unsubscribe(event_name, callable)


## Subscribe `callable(payload: Dictionary)` to an event.
func subscribe(event_name: StringName, callable: Callable) -> void:
	var list: Array = _listeners.get_or_add(event_name, [])
	if not list.has(callable):
		list.append(callable)


func unsubscribe(event_name: StringName, callable: Callable) -> void:
	var list: Array = _listeners.get(event_name, [])
	list.erase(callable)


func is_declared(event_name: StringName) -> bool:
	return _declared.has(event_name)


func declared_events() -> Array:
	return _declared.keys()


func _check_declared(event_name: StringName) -> void:
	if _declared.is_empty() or _declared.has(event_name) or _warned.has(event_name):
		return
	_warned[event_name] = true
	push_warning("EventBus: event '%s' is not declared in %s/events_*.gd" % [event_name, CONTRACTS_DIR])


func _load_declarations() -> void:
	var dir := DirAccess.open(CONTRACTS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		# Exported builds list scripts as .gd.remap.
		file_name = file_name.trim_suffix(".remap")
		if not (file_name.begins_with("events_") and file_name.ends_with(".gd")):
			continue
		var path := CONTRACTS_DIR.path_join(file_name)
		var script := load(path) as Script
		if script == null:
			push_error("EventBus: could not load %s" % path)
			continue
		var constants := script.get_script_constant_map()
		if not constants.has("EVENTS"):
			push_error("EventBus: %s has no EVENTS constant" % path)
			continue
		for event_name in constants["EVENTS"]:
			var key := StringName(event_name)
			if _declared.has(key):
				push_warning("EventBus: '%s' declared in both %s and %s" % [key, _declared[key], path])
			_declared[key] = path
