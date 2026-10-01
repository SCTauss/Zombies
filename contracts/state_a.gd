extends RefCounted
## Camp state keys Lane A writes. Shared contract (AGENTS.md §4).
## A key ending in "." is a prefix: "res." covers "res.food", "res.ammo", ...

const KEYS: Array[String] = [
	"day",  # int, from 1
	"day_phase",  # "morning" | "day" | "night"
	"defense.integrity",  # float 0..1, overall wall/defense health
	"buildings",  # Array of building records (contracts/records.gd)
	"capacity.",  # capacity.housing, capacity.beds, capacity.labs, ... (ints, derived from buildings)
	"blueprints.known",  # Array of blueprint ids
]
