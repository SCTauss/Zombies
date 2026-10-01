# AGENTS.md: rules for working on Brain Drain

Two AI agents build this project in parallel, coordinated by one human owner.
These rules exist so the two agents **never edit the same files** and **never make
big design decisions the owner hasn't made**. Follow them every session.

Read order on your first session: this file → `docs/GAME_DESIGN.md` → `docs/ROADMAP.md`
→ `docs/CONTRACTS.md` → `docs/DECISIONS.md` → your lane's role docs and status file.

---

## 1. The two lanes

The project is split into two **lanes**. Each agent owns exactly one.

| Lane | Nickname | Owns | Why it's grouped this way |
|------|----------|------|---------------------------|
| **A** | **Body** | Engine core, networking, the 3D world, zombies, **Military**, **Labor** | Real-time, physical, in-world gameplay |
| **B** | **Brain** | Simulation rules, citizens/NPC data, infection model, economy, UI, **Politician**, **Medic** | Data-driven, desk/menu gameplay, the numbers behind the camp |

### Lane assignment (set by the owner only)

| Lane | Agent |
|------|-------|
| A | _unassigned: owner fills in_ |
| B | _unassigned: owner fills in_ |

If this table is still unassigned, **ask the owner which lane you are** before writing code.

---

## 2. Who owns which files

These folders don't all exist yet. Create them when you need them, but only
inside your own lane.

| Path | Owner | Contents |
|------|-------|----------|
| `project.godot` | **A** | Project settings, autoloads, input map. Lane B requests changes (see §4). |
| `core/` | **A** | Autoloads/singletons: event bus, camp state container, networking, save/load, game clock |
| `world/` | **A** | Camp map, terrain, outside world, zombies, AI navigation, cameras |
| `roles/military/` | **A** | Tower defense, expeditions, tactician, recruiting |
| `roles/labor/` | **A** | Building, maintenance, engineering/automation, vehicles ("Beyond") |
| `roles/politician/` | **B** | Documents, budget, policy, roster, judge |
| `roles/medic/` | **B** | Check-in, hospital, research |
| `sim/` | **B** | The *rules* that change camp state: economy, infection spread, citizens (needs, traits, relationships, thoughts), run/event generation |
| `ui/` | **B** | Theme, HUD shell, main menu, lobby & role-select screens, shared widgets |
| `contracts/` | **shared** | Code form of `docs/CONTRACTS.md` (state keys, event names, data classes). Change by proposal only. |
| `assets/a/`, `assets/b/` | A / B | Lane-specific art, audio, models |
| `assets/shared/` | **shared, add-only** | Add new files freely; never modify or delete existing ones without the other lane's OK |
| `tests/a/`, `tests/b/` | A / B | Tests |
| `docs/roles/military.md`, `docs/roles/labor.md` | **A** | |
| `docs/roles/politician.md`, `docs/roles/medic.md` | **B** | |
| `docs/status/lane-a.md` / `lane-b.md` | A / B | Your own status log |
| `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/*.md` (top level), `.gitignore`, `.gitattributes` | **shared** | Change by proposal only (§4) |

**Core rule: never create, edit, move, rename, or delete a file you don't own.**
You may *read* everything. If you need something changed in the other lane,
open an issue (§5) and build against a stub or mock until it lands.

### Grey areas

- **Core vs. sim:** `core/` (A) holds and syncs camp state. `sim/` (B) decides
  how that state changes (the formulas). A never writes economy or infection
  formulas, and B never writes networking or state storage.
- **Citizens:** their data and behavior are in `sim/` (B). Their 3D bodies,
  animation and movement are in `world/` (A). Labor's "Interact" screen reads
  citizen data through the contract.
- **A role screen needs a widget:** use or request one from `ui/`. Small
  role-specific UI can live inside your own `roles/<role>/` folder.

---

## 3. Git workflow

- `main` is always playable (or at least opens in Godot without errors).
- **Don't commit directly to `main`.** Work on a branch and open a PR:
  - Lane A: `lane-a/<short-topic>`, for example `lane-a/td-placement`
  - Lane B: `lane-b/<short-topic>`, for example `lane-b/document-signing`
  - Shared-file proposals: `shared/<topic>`
- A PR touches **only your lane's paths**. A `shared/` PR touches **only shared files**.
  Never mix the two.
- Keep PRs small and frequent: one feature or fix each. Large PRs lead to conflicts.
- Before opening a PR, run `git fetch && git rebase origin/main`. Fix anything
  that breaks.
- Never force-push `main`. Never rewrite another lane's history.
- Commit messages start with the lane: `A: add wave spawner`, `B: policy cards
  draft`, `shared: add event survivor_admitted`.
- The owner merges, or the owner tells agents they can merge their own PRs.
  Don't merge the other lane's PRs.

### Godot rules (Godot causes most merge conflicts)

- Use one Godot version throughout the project (see `docs/DECISIONS.md`).
- **Never open and save the other lane's scenes or resources.** The editor
  rewrites files on save, even when you change nothing.
- Only Lane A edits `project.godot`. Autoloads, input actions, layers and
  project settings for Lane B go through a request issue (§5).
- Commit `.import` and `.uid` files together with their assets/scripts.
  Never commit `.godot/`.
- Line endings are LF (`.gitattributes` enforces this). Don't reformat code you
  don't own.
- Prefer many small scenes over one big scene. Each role's main scene must be
  **runnable on its own (F6)** with mock camp state, so neither lane is ever
  blocked by the other.

---

## 4. Shared files and contracts

Shared files are the only places both lanes have a stake. Change them like this:

1. Open a GitHub issue labelled `contract` (for state, events or data) or
   `shared` (for docs and config), describing the change and why.
2. Make the change on a `shared/<topic>` branch and open a PR that only touches
   shared files. Link the issue.
3. **Additions** (a new event, a new state key, a new field) can be merged once
   the PR is open and doesn't break anything.
   **Renames, removals and meaning changes** need the other lane to agree in
   the issue, or the owner to approve.
4. Until it merges, keep building against a local mock in your own lane.

`docs/DECISIONS.md` is **append-only**. Prefix new entries with your lane
(`A-003`, `B-007`) so numbers never collide. The owner uses `H-xxx`.

---

## 5. Talking to the other lane

Agents don't share memory, so all coordination goes through GitHub and this repo:

- **GitHub Issues** carry requests and questions between lanes. Labels:
  - `lane:a`, `lane:b` (whose job it is)
  - `contract` (changes a shared interface)
  - `shared` (changes a shared doc or config)
  - `decision-needed` (the owner must decide; don't guess)
  - `blocked` (waiting on someone)
- **`docs/status/lane-X.md`** is your own log. Update it at the end of every
  session: what you did, what's in progress, what you're blocked on, and what
  you need from the other lane. Read the other lane's log at the start of every session.

---

## 6. Decisions: what you can and can't decide

The game is deliberately open-ended. The owner makes the big decisions.

**You may decide** implementation details inside your lane: code structure,
names, small UI layouts, placeholder numbers, prototype mechanics, and which
idea from the design docs to prototype first.

**You may not decide.** Write these up as an open question in
`docs/DECISIONS.md` with the `decision-needed` label:
- Anything listed as open in `docs/DECISIONS.md`.
- Anything that changes how *another* role plays.
- Scope cuts or additions to the four roles.
- New dependencies, plugins, addons or languages.
- Art style, tone, monetization, platforms, store pages.

When a decision is open, build something easy to swap out (data-driven, behind
a flag, or as two prototypes) and keep going. Don't sit idle.

---

## 7. Session checklists

**Start of session**
1. `git checkout main && git pull`
2. Read the other lane's status file and your open issues (`gh issue list --label lane:<you>`).
3. Check `docs/DECISIONS.md` for new owner decisions.
4. Create or update your branch: `git rebase origin/main`.

**End of session**
1. Make sure the project opens in Godot and your role scenes run on their own.
2. Commit, push your branch, and open or update the PR.
3. Update `docs/status/lane-X.md`.
4. Open issues for anything you need from the other lane or the owner.

## 8. Definition of done (for a feature)

- Runs on its own (F6) with mock data, and also runs inside the full camp
  once integration exists.
- Talks to other systems **only through the contracts** (events and camp
  state), never by reaching into the other lane's nodes or scripts.
- Has no editor errors or warnings in your own files.
- Has a short note in your status file. Update your role doc if the design changed.
