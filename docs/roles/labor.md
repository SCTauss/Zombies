# Role: Labor (owner: Lane A)

> Draft. Items marked *(idea)* are suggestions. Big changes go through `DECISIONS.md`.

**Feels like:** RimWorld × Satisfactory × Minecraft.
**Fantasy:** The camp is literally your build. You turn scrap into homes,
walls, machines and, eventually, ways out.

## Core loops

### 1. Build
Make homes, upgrade the base, and place walls, towers, hospital wings and
offices for the other roles.
- *(idea)* Grid or freeform placement in the shared 3D camp *(open)*.
- *(idea)* Blueprints come from Military expeditions. What you can build
  depends on what was found this run.

### 2. Maintenance
Use your budget to make repairs. Night waves, weather and time wear the camp down.
- *(idea)* Damage from tower-defense waves shows up as repair jobs. A neglected
  building fails at the worst possible moment.

### 3. Interact
Manage NPCs. They have relationships, thoughts, needs and moods (RimWorld-style).
- Citizen data and behavior are in `sim/` (Lane B). This role is the main
  *interface* for managing them: job assignment, schedules, housing, and
  resolving fights.

### 4. Engineer
Automate resource gathering instead of relying only on workers.
- *(idea)* Satisfactory-style production chains: scrap → materials → parts,
  generators, water purification. Automation frees citizens for other roles.

### 5. Beyond
Build vehicles to help expeditions, and unlock new technology.
- *(idea)* Vehicles extend Military expedition range and carrying capacity.
  Late-game tech might be a radio tower, a wall upgrade or an evacuation vehicle.

## Gives to other roles
Buildings and capacity (homes, beds, labs, offices), defenses, vehicles,
production, repairs.

## Needs from other roles
Blueprints and materials (Military), budget (Politician), workers (citizens /
Medic admissions).

## When no one plays this role *(open)*
*(idea)* Auto-repair at a slow rate, a fixed build queue, and no automation.

## Open questions
- Grid-based or freeform building?
- How Minecraft is it: block-level terrain editing, or prefab buildings only?
- Is building done by citizens over time (RimWorld) or instantly by the player
  (Minecraft)?

## Suggested prototype order
Place prefab buildings on the camp map → buildings write capacity to camp state
→ damage and repair → one production chain → citizen job assignment UI → vehicle.
