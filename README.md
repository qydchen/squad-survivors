# Squad Survivors

**WoW + XCOM + Vampire Survivors.** A squad-based bullet-heaven: draft 5 characters
from your persistent roster, survive 20-minute runs, loot gear that carries over
between runs, and build your warband across sessions.

## Concept

Instead of one over-buffed hero, you command a squad of up to 5 characters with
WoW-classic-inspired kits (tank, healer, ranged, melee, support). Characters start
every run at level 1 and level up from kill XP. Gear drops in-run, equips immediately,
and persists in your stash after the run. Legendary affixes are build-defining and
telegraphed, guiding each character toward a build. Enemies are diverse and punish
bad team comps — positioning and drafting win, not just bigger numbers.

See [GAME_DESIGN.md](GAME_DESIGN.md) for the full design.

## Run it

1. Open this folder in **Godot 4.x** (GL Compatibility renderer).
2. Press F5. `scenes/main.tscn` is the entry point.

## Project layout

```
data/            JSON definitions: classes, abilities, items, enemies
scenes/         Godot scenes (main, characters, enemies, UI)
scripts/
  autoload/     SaveSystem, Roster, Stash, Game (run state)
  characters/   SquadMember base + per-class logic
  enemies/      Enemy base + AI
  ui/           HUD, draft screen, inventory, level-up
assets/         Sprites, audio (placeholder for now)
```

## Architecture notes

- **Data-driven:** classes, abilities, and items are JSON in `data/`. Add a class
  by adding a JSON file — no code changes needed for stats/abilities.
- **Autoloads:** `SaveSystem` (JSON save/load) → `Roster` (persistent characters)
  → `Stash` (persistent inventory) → `Game` (in-run state).
- **Saves** live at `user://squad_survivors_save.json` (Steam Cloud later).

## Roadmap

- **v0.1 vertical slice:** 3 classes (Bulwark / Arcanist / Cleric), 1 arena,
  10-minute run, leader-follow movement + tactical pause. Prove the fun.
- **v0.2:** 6 classes, gear drops + stash, 20-minute runs, elite affixes.
- **v0.3:** warband talent tree, bosses, draft threat forecast.
- **Steam:** GodotSteam integration, achievements, demo + Steam page.
