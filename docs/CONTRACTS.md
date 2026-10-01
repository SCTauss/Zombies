# Contracts (draft)

This is the **only** surface the two lanes share in code. Lane A and Lane B
systems talk through camp state and events. They never reach into each
other's nodes, scenes or scripts.

> Status: **in code** under `contracts/` (since 2026-10-01). Changes follow
> `AGENTS.md` §4: additions are cheap, while renames and removals need the
> other lane's OK.

## Where the code lives

| File | What |
|------|------|
| `contracts/events_a.gd`, `events_b.gd`, `events_shared.gd` | `const EVENTS` per lane. `EventBus` loads every `contracts/events_*.gd` and warns once on an undeclared event. |
| `contracts/state_a.gd`, `state_b.gd` | `const KEYS` per lane (a key ending in `.` is a prefix). `CampState` warns once on an undeclared key. |
| `contracts/records.gd` | Makers for the citizen and building records (plain Dictionaries). |

To add an event or key, edit **your own lane's file** in a `shared/` PR.

## Design constraints for the code version (Phase 0)

- **Either lane can add events and state keys without editing the same file.**
  For example, per-lane declaration files (`contracts/events_a.gd`,
  `contracts/events_b.gd`) or per-lane data registries. Lane A picks the
  mechanism when building `core/`. Lane B reviews it.
- Data travels as plain, serializable data (dictionaries, or `Resource`
  classes that serialize cleanly), so it can be sent over the network later.
- Only the **authority** changes camp state (exactly which machine is the
  authority is decided in O-03). Clients send *requests* as events and the
  authority applies them. Build this way from day one, even single-player, so
  Phase 3 doesn't need a rewrite.
- Every role scene works with a **mock** camp state (`core/` provides it).

## Role entry points

Per H-009, players walk around one shared 3D camp as characters. Each role
has a **station** in the camp. Interacting with it opens that role's **view**
(the "inside" game: tower defense, building, desk...). Leaving the view
returns the player to walking.

Each role exposes two scenes:

| Role | View (loaded by the camp) | Standalone (F6, mock world) | Owner |
|------|---------------------------|-----------------------------|-------|
| Military | `roles/military/military_view.tscn` | `roles/military/military_main.tscn` | A |
| Labor | `roles/labor/labor_view.tscn` | `roles/labor/labor_main.tscn` | A |
| Politician | `roles/politician/politician_view.tscn` | `roles/politician/politician_main.tscn` | B |
| Medic | `roles/medic/medic_view.tscn` | `roles/medic/medic_main.tscn` | B |

**View contract.** The view scene's root node implements:

```gdscript
signal exit_requested          # the player wants to leave the view (Esc, a "Leave" button)
func open_view(camp: Node) -> void   # called when the player enters; show UI, take input
func close_view() -> void            # called when the player leaves; hide UI, stop taking input
```

- The camp keeps every view loaded and calls `open_view` / `close_view`, so a
  view keeps its own state between visits. Views must ignore input while closed.
- `camp` is the camp scene root (`world/camp/camp_main.gd`). World views
  (Military, Labor) use `camp.map`, `camp.top_down_camera()`, `camp.buildings`,
  `camp.spawner`. Desk views (Politician, Medic) can ignore it and draw 2D UI on
  their own `CanvasLayer`.
- A view never moves the player or edits the camp scene; it talks to the rest
  of the game only through events and camp state.
- The standalone `<role>_main.tscn` wraps the view with a mock world and opens it
  right away, so each role still runs alone (F6).

## Camp state: draft keys

| Key | Meaning | Written by (rules) | Read by |
|-----|---------|--------------------|---------|
| `day`, `day_phase` | Clock | core (A) | all |
| `money` | Camp treasury | sim/economy (B) | all |
| `budget.<role>` | Money allotted to each role | Politician (B) | each role |
| `res.food`, `res.water`, `res.materials`, `res.parts`, `res.medicine`, `res.ammo`, `res.fuel` | Stockpiles *(the list itself is open)* | sim (B) applies the changes; any role can *request* one | all |
| `population` | Citizen count (details in the citizen registry) | sim (B) | all |
| `approval` | Camp mood / support for leadership | sim (B) | all |
| `infection.level` | Spread inside the camp | sim/infection (B) | all |
| `virus.*` | This run's virus parameters (revealed bit by bit through research) | sim (B) | Medic, Military, world |
| `policies.active` | Active policy ids | Politician (B) | all |
| `defense.integrity` | Overall wall/defense health | world/Military (A) | all |
| `buildings` | Building registry (type, health, capacity) | Labor (A) | all |
| `capacity.housing`, `capacity.beds`, `capacity.labs` | Derived from buildings | Labor (A) | sim, Medic |
| `blueprints.known` | Unlocked blueprint ids | Military (A) | Labor |
| `research.done` | Completed research ids | Medic (B) | all |

## Citizen record: draft fields (owned by `sim/`, Lane B)

`id`, `name`, `age`, `traits[]`, `skills{}`, `job`, `health`,
`infection_stage`, `mood`, `needs{}`, `relationships{id: value}`,
`documents[]` (some forged), `legal_status`, `faction`, `is_recruit`.

Lane A reads these, for example for Labor's Interact screen and recruits.
Lane A changes them **only** through request events, such as
`citizen_job_change_requested`.

## Events: draft list

| Event | Emitted by | Typical listeners |
|-------|-----------|-------------------|
| `day_started`, `day_phase_changed`, `day_ended` | core (A) | all |
| `survivor_arrived` | sim (B) | Medic |
| `survivor_admitted` / `survivor_rejected` / `survivor_quarantined` | Medic (B) | sim, Politician, Labor |
| `citizen_infected`, `citizen_turned`, `citizen_died` | sim (B) | all |
| `citizen_job_change_requested` | Labor/Military (A) | sim |
| `budget_allocated` | Politician (B) | all |
| `policy_enacted`, `policy_revoked` | Politician (B) | all |
| `document_signed` / `document_rejected` | Politician (B) | the role the document came from |
| `document_requested` | any role | Politician |
| `judgment_issued` | Politician (B) | sim, Military |
| `wave_started`, `wave_ended`, `camp_breached` | Military/world (A) | all |
| `expedition_departed`, `expedition_returned` (payload: loot, wounded, samples, survivors) | Military (A) | sim, Labor, Medic |
| `blueprint_found`, `tactic_unlocked` | Military (A) | Labor, UI |
| `building_placed`, `building_completed`, `building_damaged`, `building_destroyed` | Labor/world (A) | all |
| `vehicle_built` | Labor (A) | Military |
| `research_completed` | Medic (B) | all |
| `resource_change_requested` | any | sim (applies it) |
| `run_started`, `run_ended` (payload: reason) | core (A) / sim (B) *(open, see O-08)* | all |

## Changelog
Append-only. Format: `YYYY-MM-DD, lane, change, issue link`.

- 2026-10-01, owner, initial draft.
- 2026-10-01, A, contracts in code (`contracts/`); payload keys listed per event; added state key `citizens` (citizen records) and the shared `events_shared.gd`.
- 2026-10-01, A (for Lane B sim), state prefixes `gate.`, `report.`, `documents.`; document record; citizen fields `symptoms`, `arrived_day`; request events `survivor_decision_requested`, `budget_allocation_requested`, `policy_change_requested`, `document_decision_requested`; event `zombie_spawned_inside`.
- 2026-10-01, owner (H-009), role views opened from camp stations; view contract (`open_view` / `close_view` / `exit_requested`); Labor request events `building_placement_requested`, `building_demolish_requested`.
