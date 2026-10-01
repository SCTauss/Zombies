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
