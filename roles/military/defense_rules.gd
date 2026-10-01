extends Node
## Military's rules for defenses (towers): placing and upgrading. Only the
## authority changes anything; it writes camp state "defenses". Other peers
## call the same functions, which send request events to the host instead.

const Records := preload("res://contracts/records.gd")
const TowerTypes := preload("res://roles/military/tower_types.gd")
const Tower := preload("res://roles/military/tower.gd")

const BUDGET_KEY := "budget.military"

## The camp map (world/camp_greybox.gd). Found by group if not set.
var map: Node3D


func _ready() -> void:
	add_to_group(&"defense_rules")
	if map == null:
		map = get_tree().get_first_node_in_group(&"camp_map")
	EventBus.subscribe(&"defense_placement_requested", _on_placement_requested)
	EventBus.subscribe(&"defense_upgrade_requested", _on_upgrade_requested)


func _exit_tree() -> void:
	EventBus.unsubscribe(&"defense_placement_requested", _on_placement_requested)
	EventBus.unsubscribe(&"defense_upgrade_requested", _on_upgrade_requested)


## Why a `type_id` defense can't go at `pos` right now, or "" if it can.
func check_place(type_id: String, pos: Vector3) -> String:
	if not TowerTypes.TYPES.has(type_id):
		return "Unknown defense"
	if map and not map.is_buildable(pos, Tower.RADIUS):
		return "Can't build there"
	var cost: int = TowerTypes.tier(type_id, 0)["cost"]
	if int(CampState.get_value(BUDGET_KEY, 0)) < cost:
		return "Not enough military budget (need $%d)" % cost
	return ""


## Place a defense. Returns "" on success (or once the request is sent), else why not.
func place(type_id: String, pos: Vector3) -> String:
	if not CampState.is_authority():
		EventBus.emit_event(&"defense_placement_requested", {"type": type_id, "position": pos})
		return ""
	var problem := check_place(type_id, pos)
	if not problem.is_empty():
		return problem
	_spend(TowerTypes.tier(type_id, 0)["cost"], "build %s" % type_id)
	var defenses: Array = CampState.get_copy("defenses", [])
	var top := 0
	for record: Dictionary in defenses:
		top = maxi(top, record["id"])
	var record := Records.defense(top + 1, type_id, pos)
	defenses.append(record)
	CampState.set_value("defenses", defenses)
	EventBus.emit_event(&"defense_placed", {"defense_id": record["id"], "type": type_id, "position": pos})
	return ""


## Upgrade cost of `defense_id`'s next tier, or 0 if it's maxed / unknown.
func upgrade_cost(defense_id: int) -> int:
	var record := find(defense_id)
	if record.is_empty() or record["tier"] + 1 >= TowerTypes.tier_count(record["type"]):
		return 0
	return TowerTypes.tier(record["type"], record["tier"] + 1)["cost"]


## Upgrade a defense one tier. Returns "" on success (or once the request is sent), else why not.
func upgrade(defense_id: int) -> String:
	if not CampState.is_authority():
		EventBus.emit_event(&"defense_upgrade_requested", {"defense_id": defense_id})
		return ""
	var cost := upgrade_cost(defense_id)
	if cost == 0:
		return "Already maxed out"
	if int(CampState.get_value(BUDGET_KEY, 0)) < cost:
		return "Not enough military budget (need $%d)" % cost
	_spend(cost, "upgrade defense")
	var defenses: Array = CampState.get_copy("defenses", [])
	for record: Dictionary in defenses:
		if record["id"] == defense_id:
			record["tier"] += 1
			CampState.set_value("defenses", defenses)
			EventBus.emit_event(&"defense_upgraded", {"defense_id": defense_id, "tier": record["tier"]})
	return ""


func find(defense_id: int) -> Dictionary:
	for record: Dictionary in CampState.get_value("defenses", []):
		if record["id"] == defense_id:
			return record
	return {}


func _spend(amount: int, reason: String) -> void:
	EventBus.emit_event(&"resource_change_requested", {"key": BUDGET_KEY, "amount": -amount, "reason": reason})


func _on_placement_requested(payload: Dictionary) -> void:
	if CampState.is_authority():
		place(payload.get("type", ""), payload.get("position", Vector3.ZERO))


func _on_upgrade_requested(payload: Dictionary) -> void:
	if CampState.is_authority():
		upgrade(payload.get("defense_id", -1))
