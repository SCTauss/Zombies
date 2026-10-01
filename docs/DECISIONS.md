# Decisions

**Append-only.** Never edit or delete an old entry. To change a decision, add a
new one that replaces it (`Replaces H-002`).
IDs: `H-xxx` = owner (human), `A-xxx` = Lane A, `B-xxx` = Lane B. Agents only
record *lane-internal* decisions (see `AGENTS.md` §6). Big ones are
`decision-needed` questions for the owner.

## Decided

| ID | Date | Decision |
|----|------|----------|
| H-001 | 2026-10-01 | Engine is **Godot 4** (owner has 4.7 installed). 3D. |
| H-002 | 2026-10-01 | 1–4 players, co-op. Four roles: Politician, Military, Medic, Labor. Each role plays like a different game. |
| H-003 | 2026-10-01 | Hosted on GitHub (`SCTauss/Zombies`). Two AI agents work in two lanes per `AGENTS.md`. |
| H-004 | 2026-10-01 | Working title: **Brain Drain**. |
| H-005 | 2026-10-01 | Design stays open-ended. Agents prototype, and the owner decides direction at each phase sync point. |
| H-006 | 2026-10-01 | Language is **GDScript** (closes O-01). |
| H-007 | 2026-10-01 | Godot version pinned to **4.7.2 stable** (closes O-02). |
| H-008 | 2026-10-01 | Art style and tone: **friendslop, brutal cartoon, like PEAK**. Bright toon colors with outlines, goofy characters, over-the-top cartoon gore (closes O-09). |

## Open (owner decides)

When one is settled, add an `H-xxx` row above and mark it **Closed → H-xxx** here.

| ID | Question | Needed by | Notes |
|----|----------|-----------|-------|
| O-01 | **Closed → H-006.** **Language:** GDScript, C#, or both? | Phase 0 (blocking) | GDScript has the least setup and works everywhere in Godot. C# needs the .NET build of Godot. Both lanes must use the same. |
| O-02 | **Closed → H-007.** **Exact Godot version** to pin (e.g. 4.7.x) | Phase 0 (blocking) | Everyone must use the same version, or scenes churn. |
| O-03 | **Networking model:** listen-server (one player hosts), dedicated server, or Steam relay? Authority model? | End of Phase 0 (after the spike) | Lane A's spike recommends; the owner decides. |
| O-04 | **Time model:** real-time days, turn-based phases, or a hybrid? | End of Phase 1 | Affects every role's pace. |
| O-05 | **Camera / presence:** do players walk around one shared 3D camp, or does each role have its own view? Camera per role? | End of Phase 1 | |
| O-06 | **Empty roles** with fewer than 4 players: automatic rules, one player with several roles, scaling, or AI advisors? | End of Phase 2 | |
| O-07 | **Test framework** (e.g. GUT, gdUnit4, or none for now) | Phase 0 | It's an addon, so it's the owner's call. |
| O-08 | **Win/lose conditions:** survive N days, cure, evacuation, faction victory, endless? | Phase 5 | |
| O-09 | **Closed → H-008.** **Art style and tone** | Phase 6 (earlier if wanted) | Greybox until then. |
| O-10 | **Platforms and distribution** (Steam? itch? PC only?) | Phase 6 | |
| O-11 | Can players **switch roles** mid-run? | Phase 3 | |
| O-12 | **Meta-progression** between runs (unlocks), or pure roguelike? | Phase 5 | |
| O-13 | **Building:** grid or freeform? Terrain editing? | Phase 1 | Affects Military tower placement too, so it crosses lanes. |
| O-14 | **Expeditions:** direct control, sent squads, or both? | Phase 4 | |
| O-15 | **Politician power over other players** (not just NPCs): how much? | Phase 2 | Core to the co-op social dynamic. |

## Lane-internal decisions
Agents append here: `A-001 · date · decision · why`.
