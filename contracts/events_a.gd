extends RefCounted
## Events Lane A (core, world, Military, Labor) emits. Shared contract:
## additions are fine, renames/removals need Lane B's OK (AGENTS.md §4).
## Payloads are plain Dictionaries; the expected keys are listed per event.

const EVENTS: Array[StringName] = [
	# core: clock and run
	&"day_started",  # {day}
	&"day_phase_changed",  # {day, phase}
	&"day_ended",  # {day}
	&"run_started",  # {seed}
	# world / Military
	&"wave_started",  # {wave, count, day}
	&"wave_ended",  # {wave, killed, breached}
	&"camp_breached",  # {wave, integrity}
	&"expedition_departed",  # {expedition_id, squad: [citizen_id], destination}
	&"expedition_returned",  # {expedition_id, loot: {res_key: amount}, wounded: [citizen_id], samples, survivors: [citizen]}
	&"blueprint_found",  # {blueprint_id}
	&"tactic_unlocked",  # {tactic_id}
	# Labor
	&"building_placed",  # {building_id, type, position: Vector3}
	&"building_completed",  # {building_id, type}
	&"building_damaged",  # {building_id, health}
	&"building_destroyed",  # {building_id, type}
	&"vehicle_built",  # {vehicle_id, type}
	# requests to sim (Lane B applies them)
	&"citizen_job_change_requested",  # {citizen_id, job}
	# world: a turned citizen becomes a zombie inside the camp
	&"zombie_spawned_inside",  # {citizen_id, position: Vector3}
	# requests to Labor's construction (host applies them)
	&"building_placement_requested",  # {type, position: Vector3, rotation}
	&"building_demolish_requested",  # {building_id}
]
