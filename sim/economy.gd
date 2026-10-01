extends RefCounted
## Daily economy formulas (pure functions, easy to test and tune).
## daily_report() reads a camp state snapshot and returns what changes at night.

const Policies := preload("res://sim/policies.gd")

const TAX_PER_CITIZEN := 8
const FOOD_PER_CITIZEN := 1.0
const WATER_PER_CITIZEN := 1.0
const FOOD_PER_FARM := 6
const FOOD_PER_FARMER := 2
const WATER_PER_TOWER := 10
const PARTS_PER_WORKSHOP := 3  # each part costs 2 materials
const STARVING_APPROVAL := -0.08
const HOMELESS_APPROVAL := -0.02  # per citizen without housing


static func daily_report(state: Dictionary) -> Dictionary:
	var population: int = state.get("population", 0)
	var active: Array = state.get("policies.active", [])
	var farmers := 0
	for citizen: Dictionary in state.get("citizens", []):
		if citizen.get("job") == "farmer" and citizen.get("legal_status") == "resident":
			farmers += 1
	var food_made: int = state.get("capacity.farms", 0) * FOOD_PER_FARM + farmers * FOOD_PER_FARMER
	var water_made: int = state.get("capacity.water", 0) * WATER_PER_TOWER
	var food_used := ceili(population * FOOD_PER_CITIZEN * Policies.modifier(active, "food_use", 1.0))
	var water_used := ceili(population * WATER_PER_CITIZEN)
	var workshops: int = state.get("capacity.workshops", 0)
	var parts_made := mini(workshops * PARTS_PER_WORKSHOP, floori(state.get("res.materials", 0) / 2.0))
	var income := roundi(population * TAX_PER_CITIZEN * Policies.modifier(active, "income", 1.0))
	var cost := roundi(Policies.modifier(active, "daily_cost", 0.0))
	var food_after: int = state.get("res.food", 0) + food_made - food_used
	var water_after: int = state.get("res.water", 0) + water_made - water_used
	var homeless := maxi(0, population - int(state.get("capacity.housing", 0)))
	var approval_delta := Policies.approval_per_day(active) + homeless * HOMELESS_APPROVAL
	if food_after < 0 or water_after < 0:
		approval_delta += STARVING_APPROVAL
	return {
		"income": income,
		"cost": cost,
		"food_made": food_made,
		"food_used": food_used,
		"water_made": water_made,
		"water_used": water_used,
		"parts_made": parts_made,
		"materials_used": parts_made * 2,
		"starving": food_after < 0,
		"thirsty": water_after < 0,
		"homeless": homeless,
		"approval_delta": approval_delta,
	}
