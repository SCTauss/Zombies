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
