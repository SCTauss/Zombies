# Game Design: Brain Drain (draft)

> Status: **draft**. This sets direction but doesn't lock anything in. Items
> marked *(idea)* are suggestions to try. Items marked *(open)* are listed in
> `DECISIONS.md` and only the owner can settle them.

## Pitch

The world has fallen. A handful of survivors hold a camp, and 1–4 players run
it. Each player takes a **job**, and each job is a different genre: a political
desk sim, a tower-defense and expedition game, a triage and hospital sim, and a
colony builder. Nobody can keep the camp alive alone. The Politician's budget
feeds the Labor player's repairs, the Medic's gate decides who the Military has
to protect, and Military expeditions bring home the blueprints Labor builds from.

Runs are short and very different each time: a different virus, different
survivors, different factions, a different map.

## Pillars

1. **Four games, one camp.** Each role is a full game on its own, with its own
   controls, screens and pace. All four read and write the same camp.
2. **Everyone needs everyone.** No role can cover its own needs. Every role
   produces something another role uses up (see "Dependency web" below).
3. **Trade-offs, not right answers.** In the spirit of Pathologic, most choices
   hurt someone: approval against safety, compassion against the quarantine,
   speed against quality.
4. **Every run is different.** The systems are built to be driven by
   generated content, not scripted content.
5. **Works with 1, 2, 3 or 4 players.** The camp has to survive when roles
   are empty. How that works is *(open)*.

## Shape of a run *(open: one possible shape)*

A run is a series of **days**. One possible day loop:

| Phase | Politician | Military | Medic | Labor |
|-------|-----------|----------|-------|-------|
| **Morning** | Sign the day's documents, set the budget | Plan expeditions, assign squads | Check-in queue at the gate | Assign workers, queue builds |
| **Day** | Policy, roster, judge cases | Expeditions outside, recruiting | Hospital, research | Build, repair, engineer |
| **Night** | Deal with the night's fallout | **Tower defense waves** | Emergency triage | Repairs under fire |

A run might end when the camp falls, or when a goal is reached. Possible goals
include surviving N days, finding a cure, evacuating, or one faction winning
*(open)*. Real-time days and turn-based phases are both possible *(open)*.

## The camp (shared state)

All roles meet in one shared **camp state**: resources, population, approval,
infection, buildings, defenses, research and policies. Each role sees it
through its own screens. Exact keys and events are in `CONTRACTS.md`.

*(idea)* The camp is one physical 3D place that all players inhabit. The
Politician's office, the Medic's clinic and the Labor workshop are buildings
in it, and the walls the Military defends surround all of them. Players can
see each other working.

## Dependency web

This is the heart of the co-op design. Each arrow is a reason players need to
talk to each other.

| From → To | What flows |
|-----------|-----------|
| Politician → everyone | Budget, policies (buffs, debuffs, rules), legal verdicts |
| Politician → Medic | Quarantine policy, check-in rules (who is allowed in) |
| Military → Labor | Blueprints, materials and parts from expeditions |
| Military → Medic | Samples for research, wounded soldiers |
| Military → camp | Defense. When walls fail, everyone suffers. |
| Medic → Military | Healed soldiers, combat drugs/buffs from research *(idea)* |
| Medic → Politician | Infection reports, which drive approval and panic |
| Medic → camp | Admitted survivors, who become population, workers and recruits |
| Labor → Military | Walls, towers, vehicles for expeditions |
| Labor → Medic | Hospital beds, labs, equipment |
| Labor → Politician | Housing and services, which drive approval |
| Citizens → everyone | Workers, recruits, patients, defendants, voters |

**Conflict is built in:** the Politician's budget is limited, so every other
player is competing for it. *(idea)* Players can lobby, bribe or petition the
Politician in-game.

## Replayability levers *(ideas, all open)*

- **The virus is different every run.** Transmission method, incubation time,
  symptoms, weaknesses. The Medic's research uncovers this run's rules, and
  everyone else plays better once they're known.
- **Generated survivors** with traits, skills, secrets, relationships and
  documents, some of them forged.
- **Factions:** political parties, opponents, outside groups (raiders, other
  camps, cults).
- **Map seeds:** camp location, the outside world, expedition sites.
- **Events:** storms, hordes, outbreaks, defectors, supply drops, elections.
- **Random unlock pools:** which blueprints, tactics, policies and research
  nodes show up in this run.
- **Starting scenarios:** "the hospital camp", "the military base", "the town hall".

## The name *(idea)*

"Brain Drain" can mean several things at once:
- zombies, obviously;
- **talent leaving the camp**. *(idea)* Skilled citizens leave or defect when
  the camp is badly run, which weakens every role;
- the players' own brains being drained by juggling four jobs.

## Fewer than 4 players *(open)*

Options to prototype: empty roles run on simple automatic rules, one player
takes several roles, the camp scales down, or AI "advisors" run the empty roles
on a policy the player sets.

## Presentation *(open)*

The camera and perspective can differ by role. For example: a top-down view
for tower defense, first or third person for expeditions, a first-person desk
for the Politician and the Medic's check-in, and a free build camera for Labor.
Art style and tone are owner decisions.

## Big technical unknowns

- **Multiplayer for a simulation game**, meaning what is synced and who is the
  authority. This is the riskiest thing in the project, so it gets an early spike
  (see the roadmap).
- **Four genres in one project.** We handle this by building every role as a
  standalone scene that talks only through the contracts.
- **Recognizing drawn tactics** (Military Tactician). Needs a prototype.
