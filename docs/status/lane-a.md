# Lane A (Body): status log

Owned by Lane A only. Newest entry on top. Keep entries short.

Template:
```
## YYYY-MM-DD
- Done:
- In progress (branch / PR):
- Blocked on:
- Needs from Lane B:
- Questions for owner:
```

## 2026-10-01 (session 6)
- Done: Phase 2 cross-role effects. `Sim` (Lane B) registered as an autoload. Zombies stop to
  smash buildings they pass (damage via `construction.damage`, so it becomes Labor repair work).
  Labor repairs (F) for materials scaled by damage (`building_repair_requested`, `building_repaired`).
  `citizen_turned` → a zombie bursts out of a house inside the camp (`zombie_spawned_inside`).
  Waves scale with `virus.toughness` / `virus.speed`.
- Tests: `tests/a/cross_role_smoke.tscn`.

## 2026-10-01 (session 5)
- Done: H-009 shared camp (`world/camp/camp_main.tscn`, now the main scene). 4 cartoon "bean"
  characters (one per role, `world/players/`), third-person follow camera, 4 stations
  (`world/stations/`). E at your own station opens your role view; Esc / Leave returns.
  Tab switches character (solo). Day/night runs in real time (F1 skips a phase).
- Military and Labor split into `<role>_view.tscn` (view contract) + `<role>_main.tscn`
  (standalone, extends `world/camp/camp_base.gd`). Night waves moved into the wave spawner.
- Tests: `tests/a/camp_smoke.tscn`.
- Needs from Lane B: `politician_view.tscn` / `medic_view.tscn` per the view contract; the camp
  loads them automatically when they exist.

## 2026-10-01 (session 4)
- Done: merged #1–#7 (owner OK'd Lane A merging its own PRs). CI added (#5). Contracts in code (#6).
  CampState checks keys against `contracts/state_*.gd` (#7).
- Done: Phase 1 Labor toy (`roles/labor/`): 6 prefab buildings (house, clinic, lab, workshop, farm,
  water tower), cartoon models, scaffolding + rise while building, pop on finish. Buildings live in
  camp state `buildings`; `BuildingLayer` draws them from state (works on clients); `Construction`
  (authority) places/charges/builds/damages/demolishes and writes `capacity.*`. Footprints are
  rectangles (rotation aware). Buildings block zombies (navmesh rebakes). Road cross from the gates
  is unbuildable. Mock camp starts with 7 buildings.
- Next: owner decision O-05 → 4 walking player characters, role views on interaction (camp scene).
- Needs from Lane B: requests `building_placement_requested` / `building_demolish_requested` are
  being added to `contracts/events_a.gd` (shared PR).

## 2026-10-01 (session 3)
- Done: Phase 1 Military toy + world greybox.
  - `world/camp_greybox.tscn`: map built from code (ground, square wall with 4 gates, heart,
    spawn points), runtime navmesh bake, placement rules (`is_buildable`, `occupy`).
  - `world/zombies/`: cartoon zombie (navigation, hit squash/flash, gore pop) + wave spawner
    (`wave_started`, `wave_ended`, `camp_breached`, writes `defense.integrity`).
  - `roles/military/military_main.tscn`: TD greybox. Watchtower with a 4-tier upgrade path,
    ghost placement, grid/freeform toggle (O-13), night starts a wave. Costs go through
    `resource_change_requested` on `budget.military`.
  - `core/mock_rules.gd` (`MockRules`): applies resource requests on mock state only.
  - Look: owner direction "friendslop, brutal cartoon, like PEAK" (toon shading + outlines, gore pop).
  - Tests: `tests/a/world_smoke.tscn` passes. `tests/a/screenshot.tscn` saves a screenshot of any scene.
- In progress (branch / PR): `lane-a/td-greybox` (stacked on `lane-a/net-spike`).
- Next: Labor toy (place prefab buildings → `buildings`, `capacity.*`).
- Needs from Lane B: when `sim/` applies `resource_change_requested`, set `MockRules.enabled = false`.

## 2026-10-01 (session 2)
- Done: networking spike. `Net` autoload (PROTOTYPE): ENet listen-server, host = authority,
  snapshot on join + per-key state sync, host→client event relay, client→host `*_requested`
  events (host adds `peer_id`). Two-process test `tests/a/net_smoke.tscn` passes on localhost.
  Manual test: `core/dev/net_spike.tscn`. Findings + O-03 recommendation: `core/net/SPIKE_REPORT.md`.
- In progress (branch / PR): `lane-a/net-spike` (stacked on `lane-a/foundation`, PR #1).
- Next: Phase 0 sync point, then Phase 1 (TD greybox, Labor placement, greybox map + zombie).
- Needs from Lane B: sim must validate `*_requested` payloads before applying (host-side).
- Questions for owner: O-03, see the report. A real two-PC test needs port forwarding or Tailscale.

## 2026-10-01 (session 1)
- Done: `project.godot` (Godot 4.7.2, GDScript, Forward+). `core/` autoloads:
  `EventBus` (named events + Dictionary payloads), `CampState` (flat keys from
  CONTRACTS.md, authority-only writes, snapshot/load), `GameClock` (morning/day/night,
  manual or real-time advance). Mock camp state loads by default so scenes run alone (F6).
  Placeholder main scene `core/dev/dev_boot.tscn`. Smoke test `tests/a/core_smoke.tscn` passes headless.
- Event declaration mechanism (for Lane B review): each lane adds
  `contracts/events_<lane>.gd` with `const EVENTS: Array[StringName] = [...]`;
  `EventBus` loads all of them at startup and warns on undeclared events.
- In progress (branch / PR): `lane-a/foundation`.
- Next: networking spike (2 instances, sync one value + one event) for O-03.
- Needs from Lane B: review the contracts mechanism above; replace `run/main_scene` with
  the `ui/` main menu when ready (request it, Lane A edits `project.godot`).
- Questions for owner: O-01 (GDScript) and O-02 (4.7.2) assumed per Lane A's setup; please confirm as H-entries.

## 2026-10-01
- Lane not started. Next: Phase 0 tasks in `docs/ROADMAP.md` once O-01 and O-02 are decided.
