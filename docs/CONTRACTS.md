# Contracts (draft)

This is the **only** surface the two lanes share in code. Lane A and Lane B
systems talk through camp state and events. They never reach into each
other's nodes, scenes or scripts.

> Status: **draft names**. Phase 0 turns these into code under `contracts/`.
> Names may change until then. After that, changes follow `AGENTS.md` §4:
> additions are cheap, while renames and removals need the other lane's OK.

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

Each role exposes one entry scene, which the camp (Lane A) loads:

| Role | Entry scene | Owner |
|------|-------------|-------|
| Military | `roles/military/military_main.tscn` | A |
| Labor | `roles/labor/labor_main.tscn` | A |
| Politician | `roles/politician/politician_main.tscn` | B |
| Medic | `roles/medic/medic_main.tscn` | B |

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
