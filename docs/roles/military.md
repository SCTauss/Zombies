# Role: Military (owner: Lane A)

> Draft. Items marked *(idea)* are suggestions. Big changes go through `DECISIONS.md`.

**Feels like:** The Last of Us × Bloons TD 6.
**Fantasy:** You're the wall between the camp and the dead. Defend at night,
scout during the day, keep order always.

## Core loops

### 1. Tower defense (endless)
The camp is always under threat. Place and upgrade defenses and soldiers, and
hold the waves.
- *(idea)* BTD6-style upgrade paths per defense type, plus soldiers placed as
  "towers" who have names, can get hurt, and need the Medic.
- *(idea)* Walls and towers are *built* by Labor. Military mans them.
- *(idea)* Waves grow over time, and the zombie types follow this run's virus.

### 2. Expedition
Leave the camp to look for supplies, blueprints, survivors and samples.
- *(idea)* A Last of Us-style stealth/action segment in a generated location,
  with a choice between pushing deeper and coming home.
- *(idea)* Vehicles built by Labor change how far and how much you can carry.
- *(open)* Does the player control expeditions directly, or send squads?
  Maybe both?

### 3. Tactician
Unlock tactics as buffs, by **drawing them on paper**. The game recognizes
what you drew.
- *(idea)* Draw a formation or arrow plan on a map/notebook UI. A gesture
  recognizer (for example the $1/$P recognizer family) matches it to a known
  tactic. The cleaner the drawing, the stronger the buff.
- *(open)* What exactly gets recognized: shapes, arrows, formations?

### 4. Recruit
Shape up and recruit people from the citizens to grow the force.
- *(idea)* Recruits come from the shared citizen pool, so taking workers from
  Labor is a real cost. Conscription is a Politician policy.

### Keeping order *(idea)*
Riots, rebellions and crimes inside the camp need soldiers too. This ties into
the Politician's Judge loop.

## Gives to other roles
Defense, materials, blueprints, samples, rescued survivors, order.

## Needs from other roles
Budget (Politician), healing (Medic), walls, towers and vehicles (Labor),
recruits (citizens).

## When no one plays this role *(open)*
*(idea)* Defenses auto-fire at a weaker level, and expeditions run as
off-screen dice rolls.

## Open questions
- Camera: top-down for tower defense, and third person for expeditions?
- Can soldiers die for good? How does losing them feel?

## Suggested prototype order
Tower defense on a test map with mock waves → place/upgrade → hook defenses to
camp state → expedition greybox → drawing recognizer spike → recruit.
