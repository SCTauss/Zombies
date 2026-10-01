# Lane B (Brain): status log

Owned by Lane B only. Newest entry on top. Keep entries short.

Template:
```
## YYYY-MM-DD
- Done:
- In progress (branch / PR):
- Blocked on:
- Needs from Lane A:
- Questions for owner:
```

## 2026-10-01 (Lane A's agent, session 4)
- Done: `ui/main_menu.tscn` main menu + lobby on the Net session API: name, Play solo, Host,
  Join (IP), Quit; lobby with four role cards (take / give up), player list, local IP + port hint,
  START for the host; everyone loads the camp on `run_started`.
- Tests: `tests/b/menu_smoke.tscn`.

## 2026-10-01 (Lane A's agent, session 3)
- Done: Politician office `roles/politician/politician_view.tscn` (+ `politician_main.tscn`):
  tabs Inbox (sign/reject documents with effects shown), Budget (draft then apply a split of the
  treasury), Policies (enact/revoke cards), Report (last night). All actions are sim requests.
- Tests: `tests/b/politician_smoke.tscn`. With this, all four stations open a view in the camp.

## 2026-10-01 (Lane A's agent, session 2)
- Done: `ui/theme.gd` cartoon theme (paper panels, thick outlines, chunky buttons, helpers) and
  `ui/widgets/bean_portrait.gd` (2D citizen portrait; shows red eyes / fever / grey skin / bite).
- Done: Medic check-in desk `roles/medic/medic_view.tscn` (+ standalone `medic_main.tscn`):
  gate queue, story vs papers (forgeries), 5 exams with 3 uses per survivor, admit / quarantine
  (needs a free bed) / reject as requests to sim, stamp animation. Keys 1-5, A/Q/R, Esc.
- Tests: `tests/b/medic_smoke.tscn`.

## 2026-10-01 (Lane A's agent, at the owner's request)
- Note for Lane B's agent: the owner asked Lane A's agent to start Lane B too, in separate
  `lane-b/` PRs. Treat all of this as yours: review, change or replace freely.
- Done: `sim/` v1 (autoload `Sim`, registered in a Lane A PR):
  - `citizen_gen.gd`: residents and gate survivors (traits, skills, papers; ~30% infected with
    hidden stage + 0-2 real symptoms, harmless look-alike symptoms, ~20% forged papers with one tell).
  - `economy.gd`: nightly income/food/water/production/approval formulas (pure, tested).
  - `infection.gd`: stages, spread from stage 2 (not from quarantine), turning at stage 4.
  - `policies.gd`: 5 policies with modifiers. `document_gen.gd`: Politician inbox documents.
  - `sim.gd`: applies all request events, morning arrivals, nightly economy + infection,
    fills a fresh camp with citizens. Turns `MockRules` off.
- Tests: `tests/b/sim_smoke.tscn`.
- Next: UI theme, Medic check-in desk, Politician desk (budget, documents, policies).

## 2026-10-01
- Lane not started. Next: Phase 0 tasks in `docs/ROADMAP.md` once O-01 and O-02 are decided.
