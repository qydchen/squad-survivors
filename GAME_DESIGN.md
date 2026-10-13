# Squad Survivors — Game Design (v0.1)

**Working title.** One-liner: *WoW's classes and progression × XCOM's squad tactics ×
Vampire Survivors' bullet-heaven loop.*

## Design pillars

1. **Squad tactics beat stat sticks.** Winning comes from team comp, positioning,
   and focus fire — not from out-gearing content.
2. **Your roster is the RPG.** Characters persist across runs: they level up,
   collect gear, get wounded, and retire. The warband is the progression system.
3. **Bullet-heaven power fantasy, earned.** The dopamine of VS level-ups stays,
   but every spike is a *decision* (who levels, what they take, what they wear).

## Fantasy

You are a warband commander. Before each run you draft 5 champions from your
roster, kit them from your stash, read the threat forecast, and deploy. Twenty
minutes later you extract with loot — or bury your mistakes.

## Core loop

```
DRAFT (pick 5, gear up, read forecast)
  → DEPLOY (20-min run, all start at level 1)
    → SURVIVE (kill mobs → XP gems → level-ups → loot)
      → EXTRACT (keep loot + roster XP; wounded sit out)
        → PROGRESS (stash, roster levels, warband tree)
          → DRAFT again (harder forecast)
```

### In-run rules

- **Squad of 5.** Drafted from the roster before the run. No mid-run swaps.
- **Everyone starts at level 1** every run. No exceptions — the run is the equalizer.
- **Shared XP pool.** Kill XP gems are collected by any squad member into one pool.
  On level-up: **pick which character levels**, then pick **1 of 3 upgrades** for them.
  (The level-up *target* is the tactical decision; the upgrade *choice* is the build decision.)
- **Upgrade types:** new ability, ability rank-up, stat boost, passive trait.
  Offered upgrades are weighted by the character's class and current build.
- **Downed, not dead.** A character at 0 HP is downed. Move another member onto them
  and channel 3s to revive (at 50% HP). If the run ends with a character downed,
  they are **Wounded** and sit out the next run. (XCOM wound system, lite.)
- **Timer:** 20:00. Boss at 10:00, final boss at 20:00, extract on kill.

### Squad control

You do **not** command five characters. You control **one group** that happens to
contain five characters. There is no per-character micro — ever.

- **Move the group.** WASD / mouse steers the group anchor. Members automatically
  hold formation slots by role: tanks and melee front, healer center, ranged rear.
  All attacks are automatic (VS-style).
- **Group-level orders only** — the entire tactical layer:
  - **Right-click an enemy:** group focus target. Single-target abilities and
    attacks prioritize it. (The answer to Menders and priority targets.)
  - **Stance toggle (C):** *Tight* (clustered: +mitigation aura, vulnerable to AoE
    and Volatile) vs *Spread* (loose: safe vs artillery/explosions, weaker
    focused damage). Stance is the moment-to-moment positioning decision.
  - **Space — tactical pause:** freezes the sim for *decisions* (level-up picks,
    inventory, assessing a boss phase), not for issuing unit orders.
- **Revive:** steer the group onto a downed ally and hold 3s to channel
  (interruptible by damage — rescue missions are tense on purpose).

Skill expression is: *where the group stands, what stance it's in, what it
focuses* — plus everything decided in the draft. The XCOM half lives in
preparation and group-level calls, not in unit micromanagement.

## Classes

WoW-classic-inspired kits, **all names and art original** (see IP note). Five roles:
**Tank / Healer / Melee DPS / Ranged DPS / Support.**

Vertical-slice trio (the trinity — proves the comp loop):
| Class | Role | Kit sketch |
|---|---|---|
| **Bulwark** | Tank | Cleave arc, Taunt Shout, Shield Wall, Shockwave stun |
| **Arcanist** | Ranged DPS | Frostbolt (slow), Blizzard (AoE zone), Blink (reposition) |
| **Cleric** | Healer | Heal, Power Shield, Smite (ranged DPS when nobody needs healing) |

v0.2 adds three more:
| Class | Role | Kit sketch |
|---|---|---|
| **Ranger** | Ranged DPS | Pet companion, Aimed Shot (execute), Frost Trap (zone control) |
| **Shadowblade** | Melee DPS | Stealth opener burst, Fan of Knives, mobility dash |
| **Stormcaller** | Support | Totems (deployable turrets/wards), Chain Lightning, Bloodlust (haste aura) |

v0.3+: 3 more (summoner, shapeshifter, battlemage-ish) → 9 total, mirroring the
classic class count without copying it.

Class definitions are data (`data/classes/*.json`): base stats, basic attack,
ability unlocks. New classes should need **zero code changes** — only JSON + art.

## Gear & items

- **3 slots per character:** Weapon, Armor, Trinket. Tight enough that every
  equip is a decision; loose enough for build expression.
- **Drops:** elites, bosses, and chests drop gear mid-run. Equip immediately from
  the loot toast, or stash it in the run bag (Tab) for later.
- **Rarities:** Common → Magic → Rare → Epic → **Legendary**.
- **After the run**, all loot goes to the persistent **stash**. Between runs, gear
  your roster from the stash (loadout screen in the draft phase).
- **Legendary affixes are build-defining and telegraphed.** The affix text tells
  you the build it's for. Examples:
  - *"Chain Lightning forks to 4 additional targets and can crit."*
    → Stormcaller lightning build.
  - *"Your heals also grant a shield for 50% of the amount."*
    → Cleric mitigation build.
  - *"Taunt Shout also grants 30% attack speed to the squad."*
    → Bulwark support-tank build.
- **Auto-pause on Legendary drop.** The game stops so you can feel it. Juice matters.
- Gear never drops *for* a class you didn't bring — but affixes nudge builds, so
  drafting around your stash's legendaries is a legit strategy.

## Meta progression (out of run)

Kept deliberately modest — target **~15% power** from meta systems so comp and
play still decide runs (pillar 1).

- **Roster levels:** characters earn persistent XP per run → small stat gains +
  talent rows (pick 1 of 2 every few levels, e.g. "+10% crit" vs "+15% move speed").
- **Warband tree (account-wide):** QoL and strategic power, not raw stats —
  +XP gain, faster revive channel, extra stash tabs, starting consumable slot,
  threat-forecast detail.
- **Anti-snowball:** enemy scaling keys off *run time* and a squad-power estimate,
  not flat numbers. A fully-geared roster faces fiercer forecasts, not free wins.

## Enemies — comp testers, not HP bags

Every enemy type exists to punish a specific lazy comp:

| Enemy | Punishes | Counter |
|---|---|---|
| **Swarmer** (fast, weak, many) | Low AoE / kiting comps | AoE, slows, chokepoints |
| **Shieldbearer** (frontal block) | Single-direction DPS | Flanking, pierce, repositioning |
| **Stinger** (ranged artillery) | Turtling / clumping | Movement, spread formation, dive |
| **Mender** (heals allies) | No focus fire | Focus-fire orders, burst |
| **Nullifier** (silence zones) | Caster-heavy comps | Ranged physical, move out |
| **Bulwark-breaker** (armor-piercing charge) | Tank-and-spank | Kite, slows, taunt timing |

**Elite affixes** (Mythic+-style, telegraphed with icons):
- *Enraging* — soft DPS check (enrages at 60s).
- *Volatile* — explodes on death → spacing discipline.
- *Swift / Shielded / Vampiric* — stat twists that change target priority.

**Bosses** (10:00 and 20:00): phased — add waves, safe zones, target swaps that
force repositioning via tactical pause. The final boss tests everything at once.

## Draft phase (the XCOM intel layer)

Before each run:
1. See your roster: level, gear, wounds, synergies.
2. See the **threat forecast**: the run's enemy mix, elite affixes, and boss
   mechanics — with specificity that scales with your warband tree.
   ("Heavy swarmers + nullifiers, Enraging elites, boss with silence phases.")
3. Pick 5. This is a real decision: the forecast says what comp the run wants,
   your stash says what comps you *can* field, wounds say who must sit out.

## Difficulty philosophy

- The director does **not** adapt to cover your weaknesses. It presents a varied,
  telegraphed threat mix; if your comp is wrong, you lose — and the forecast told
  you so. That's the game.
- Failure teaches: post-run debrief shows damage taken by source, so the lesson
  ("we had no answer for Stingers") is legible.

## Non-goals (v1)

Multiplayer · mobile · modding support · trading/economy. Single-player PC first.

## Tech

- **Godot 4.x, GDScript.** Data-driven: classes/abilities/items/enemies as JSON.
- **Autoloads:** `SaveSystem` → `Roster` → `Stash` → `Game` (run state).
- Saves are local JSON now; Steam Cloud later.
- **Steam:** GodotSteam module for achievements/leaderboards/cloud; put the Steam
  page up early, ship a free demo, run a Steam Playtest before launch.
- **IP note:** WoW-inspired *mechanics* are fine. Do not use Blizzard names —
  no "Frostbolt" (use "Frostbite"), no class names lifted verbatim where avoidable,
  no Blizzard art/assets/music. All names, lore, and art must be original.
  (Generic fantasy terms like "warrior" or "heal" are fine; distinctive spell and
  character names are not.)
- **Steam AI disclosure:** Steam's submission form requires disclosing
  AI-generated content (pre-generated art/code vs. live-generated). Using AI
  assistance is allowed — just answer the questionnaire honestly.

## Roadmap

- **v0.1 — vertical slice.** 3 classes, 1 arena, 10-minute run, leader-follow +
  tactical pause, basic enemies (swarmer/shieldbearer/stinger), no meta systems.
  Question to answer: *does steering a 5-character group as one unit feel good?*
- **v0.2 — the loop.** 6 classes, gear drops + stash, 20-minute runs, elites +
  affixes, draft screen with forecast, roster wounds.
- **v0.3 — the warband.** Warband talent tree, roster levels, bosses with phases,
  post-run debrief, 9 classes.
- **Steam.** Page + demo → playtest → Early Access.

## Open questions

- Stance design: is Tight/Spread enough tactical texture, or do we need a third stance (e.g. Focus: +damage, -defense)? Playtest in v0.1.
- Should XP gems magnetize to the nearest member or the anchor? (Try anchor first.)
- Revive channel: interruptible by damage? (Yes, leaning — creates rescue tension.)
- Roguelite run modifiers (heat system)? Post-launch.
