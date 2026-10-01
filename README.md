# Brain Drain

A 1–4 player co-op game about running a survivor camp during the zombie apocalypse.
Each player has a **job**, and each job is a different game. Runs are short, very
replayable, and no two play out the same way.

| Role | Feels like | In one line |
|------|------------|-------------|
| **Politician** | Pathologic 2 × political sims | Rule the camp with documents, budgets, policies, allies and verdicts. |
| **Military** | The Last of Us × BTD6 | Hold the walls, scout outside, bring supplies back, keep order. |
| **Medic** | Quarantine Zone × Animal Hospital | Decide who gets in, treat the sick, research the virus. |
| **Labor** | RimWorld × Satisfactory × Minecraft | Build the camp, keep it running, automate it, build machines. |

Engine: **Godot 4** (3D, multiplayer). Status: **draft / pre-production**.

## Where things are

| File | What it is |
|------|------------|
| [AGENTS.md](AGENTS.md) | **Rules for anyone writing code here, human or AI. Read this first.** |
| [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) | The overall game: pillars, the camp, how the roles depend on each other |
| [docs/roles/](docs/roles/) | One design doc per role |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Phases, and what each lane does in each phase |
| [docs/CONTRACTS.md](docs/CONTRACTS.md) | The shared interfaces between systems (state, events, data) |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Decisions already made, and the open questions |
| [docs/status/](docs/status/) | What each lane is doing right now |

Everything in `docs/` is a draft. It sets direction but doesn't lock anything in.
Ideas are marked as ideas. Anything not decided yet is listed in `DECISIONS.md`.
