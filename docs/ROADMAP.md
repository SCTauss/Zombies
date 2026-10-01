# Roadmap (draft)

The work is split into **phases**. Inside each phase, Lane A and Lane B work in
parallel on separate files (see `AGENTS.md` §2). Each phase ends at a **sync
point**: both lanes merge, the owner plays the build, and the owner settles
the open decisions blocking the next phase.

Tasks are **suggestions, not specs**. A lane may reorder, split or swap its own
tasks. If a task changes another lane's work or a pillar, write it up in
`DECISIONS.md` instead.

Lane A = **Body** (core, net, world, Military, Labor).
Lane B = **Brain** (sim, citizens, UI, Politician, Medic).

---

## Phase 0: Foundation
**Goal:** a shared skeleton that lets both lanes build without waiting on each other.

**Owner decisions needed first:** O-01 language, O-02 exact Godot version, O-07
test framework. These are quick calls.

| Lane A | Lane B |
|--------|--------|
| Create `project.godot`, folder layout, `.gitignore` check | UI theme, base fonts, placeholder style |
| `core/` autoloads: event bus, camp state container, game clock (day/phase ticks) | `ui/`: main menu, role-select screen (mocked), debug overlay that shows camp state |
| Mock camp-state mode, so role scenes run alone (F6) | `sim/` skeleton: citizen data class, simple citizen generator |
| **Networking spike:** 2 instances, sync one value and one event. Write up findings for O-03. | Turn the draft `contracts/` (state keys, events, data classes) into code. Ask Lane A to review. |

**Sync point:** the project opens, the debug overlay shows mock camp state
changing over days, and the networking spike report is written.

---

## Phase 1: Four toys
**Goal:** the *first* core loop of each role, playable on its own with mock
state. Ugly is fine. Fun is the question.

| Lane A | Lane B |
|--------|--------|
| Military: tower defense greybox (placement, waves, one upgrade path) | Politician: document signing desk with generated documents |
| Labor: place prefab buildings on a greybox camp map | Medic: check-in desk with generated survivors (docs and symptoms) |
| World: greybox camp map, basic zombie with navigation | Sim: first-pass economy rules (income, upkeep) |

**Sync point:** the owner plays all four toys and keeps, cuts or changes each
loop. Decide O-04 (time model) and O-05 (camera per role).

---

## Phase 2: One camp (local integration)
**Goal:** all four roles share **one** camp state on **one** machine
(role-switch hotkey or split screen *(open)*). Cross-role effects are visible.

| Lane A | Lane B |
|--------|--------|
| Camp scene that loads every role through its entry-point scene (see contracts) | Budget screen, so the Politician's money now limits A's builds and defenses |
| TD damage → repair jobs. Buildings → capacity in camp state. | Policies v1 (3–5) that change sim numbers |
| Zombie waves scale with the day and this run's virus parameters (read from sim) | Infection model v1: admitted infected → spread → zombies |
| | Citizens v1: needs and a job slot that Labor can assign through the contract |

**Sync point:** a full day/night cycle where at least one action per role
changes what another role sees. Decide O-06 (empty roles).

---

## Phase 3: Together (multiplayer)
**Goal:** 1–4 players, each in their own role, in one run over the network.

| Lane A | Lane B |
|--------|--------|
| Networking per O-03: host/join, state authority, event replication | Lobby and role-select UI on top of Lane A's net API |
| Player presence in the shared camp *(if O-05 says so)* | Empty-role behavior per O-06 (automatic rules / advisors) |
| Reconnect / late join *(nice to have)* | Make all sim updates authority-safe (run only on the authority) |

**Sync point:** 2+ real players finish a short run together.

---

## Phase 4: Depth (the remaining loops)
**Goal:** every loop from the role docs exists in some form.

| Lane A | Lane B |
|--------|--------|
| Military: expeditions, tactician (drawing-recognition spike first), recruit | Politician: roster, judge, the rest of the policies |
| Labor: maintenance, interact screen (reads citizens), engineer chain, vehicles | Medic: hospital, research tree, virus discovery |
| | Citizens: relationships, thoughts, traits (RimWorld-style) |

**Sync point:** a 30-minute run uses every loop at least once.

---

## Phase 5: Every run different
**Goal:** replayability. See "Replayability levers" in `GAME_DESIGN.md`.

| Lane A | Lane B |
|--------|--------|
| Map and expedition-site generation | Run generator: virus strain, factions, starting scenario |
| Blueprint and tactic random pools | Event system (hordes, elections, outbreaks, defectors) |
| Zombie variants tied to virus traits | Win/lose conditions per O-08 |

**Sync point:** three runs back to back feel clearly different.

---

## Phase 6: Make it a game
Art pass (per O-09), audio, onboarding/tutorials, balance, performance,
save/load, settings, builds and distribution (per O-10). Split by the same
ownership map: each lane polishes its own folders.

---

## Rules that apply in every phase
- The next phase doesn't start for a lane until its exit items are merged. The
  other lane is free to move ahead on its own work.
- Spikes and prototypes are welcome. Mark them `PROTOTYPE` in the scene or
  script header so nobody builds on them by accident.
- If a phase is blocked by an owner decision, build an easy-to-swap version and
  open a `decision-needed` issue.
