extends RefCounted
## Camp state keys Lane B writes. Shared contract (AGENTS.md §4).
## A key ending in "." is a prefix: "res." covers "res.food", "res.ammo", ...

const KEYS: Array[String] = [
	"money",  # int, camp treasury
	"budget.",  # budget.<role>: int money allotted to each role
	"res.",  # res.food, res.water, res.materials, res.parts, res.medicine, res.ammo, res.fuel (ints)
	"population",  # int
	"citizens",  # Array of citizen records (contracts/records.gd)
	"approval",  # float 0..1
	"infection.",  # infection.level (float 0..1), ...
	"virus.",  # this run's virus parameters, revealed through research
	"policies.active",  # Array of policy ids
	"research.done",  # Array of research ids
]
