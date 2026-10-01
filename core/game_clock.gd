extends Node
## Game clock (autoload `GameClock`).
##
## Drives days and day phases, writes `day` / `day_phase` to CampState and
## emits `day_started`, `day_phase_changed`, `day_ended` on EventBus.
##
## The time model is still open (O-04): this runs real-time phases by default,
## but `auto_advance = false` plus `advance_phase()` gives turn-based phases.
## Only the authority advances the clock.

const PHASES: Array[String] = ["morning", "day", "night"]

## Real seconds per phase while auto-advancing. Placeholder.
@export var phase_seconds: Dictionary = {"morning": 60.0, "day": 120.0, "night": 90.0}
@export var auto_advance := false
var paused := false

var _elapsed := 0.0


func _ready() -> void:
	CampState.state_reset.connect(func() -> void: _elapsed = 0.0)


func _process(delta: float) -> void:
	if not auto_advance or paused or not CampState.is_authority():
		return
	_elapsed += delta
	if _elapsed >= phase_seconds.get(current_phase(), 60.0):
		advance_phase()


func current_day() -> int:
	return CampState.get_value("day", 1)


func current_phase() -> String:
	return CampState.get_value("day_phase", PHASES[0])


## Fraction of the current phase that has passed (0..1), for UI.
func phase_progress() -> float:
	return clampf(_elapsed / phase_seconds.get(current_phase(), 60.0), 0.0, 1.0)


func advance_phase() -> void:
	if not CampState.is_authority():
		return
	_elapsed = 0.0
	var index := PHASES.find(current_phase())
	if index == PHASES.size() - 1:
		var finished_day := current_day()
		EventBus.emit_event(&"day_ended", {"day": finished_day})
		CampState.set_value("day", finished_day + 1)
		CampState.set_value("day_phase", PHASES[0])
		EventBus.emit_event(&"day_started", {"day": finished_day + 1})
	else:
		CampState.set_value("day_phase", PHASES[index + 1])
	EventBus.emit_event(&"day_phase_changed", {"day": current_day(), "phase": current_phase()})
