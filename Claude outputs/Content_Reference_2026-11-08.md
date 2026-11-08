# Content Reference — levels, tiles, enemies, dice, materials, characters

_Generated 2026-11-08 from the files in `E:\Dev\Godot4\DiceRogueLite` (`data/`, `scenes/levels/`, `resources/`, `scenes/run/`). Level layouts were decoded straight from the `Layout` / `Markers` tile data in each `.tscn`, so the counts below are what the game reads._

> **Display order matters for three lists.** When you send the edited lists back, the order you write them in is the order the game will show them: **characters**, **dice materials** and **dice designs**. Characters already have an `order` field. Materials and designs do not: the dice designer currently shows materials alphabetically, and designs unlocked-first then alphabetically. Both need a new `order` property (see sections 6, 7 and 9).

## 1. How the pieces fit together

- A run walks six **biomes** in this order: 1 → (2 or 3) → (4 or 5) → 6. Each biome is a small graph of 4–7 layers, from one entry level to its boss. Every biome gets exactly one **challenge** level (somewhere in the middle layers), a 60% chance of a **shop** (25% of those are **shop & bank**), and a 70% chance of a **Mystery piece** on one layer.
- A biome's **stage** (1–4) decides which level pool it draws from: `stage = order / 2 + 1` (integer division) → Grasslands = 1, Badlands & Marsh = 2, Frost & Ashlands = 3, Abyss = 4. Level size grows with stage.
- Normal and challenge levels are picked **at random from the stage's pool, each used once before any repeats** (the "used" list is per type + stage, so Badlands and Marsh share one pool, as do Frost and Ashlands). A level is only eligible if its `exit_count` ≥ the number of onward connections the map node has (1–3). Shops ignore stage.
- Boss levels are **fixed per biome** (`BiomeData.boss_level`), never random.
- The biome supplies the **tile colours** (per terrain type), the **enemy list**, the **boss**, the **difficulty** (loot rarity weights) and the **enemy count range**. The level scene only supplies the shape, terrain and marker positions.

## 2. Which levels are used where

### Biomes

| Order | Biome | Stage | Difficulty | Normal/challenge pool | Boss level | Enemies on a normal level (min–max) | Leads to |
|---|---|---|---|---|---|---|---|
| 1 | Grasslands | 1 | 1 | `normal_s1_01–06`, `challenge_s1_01–02` | `boss_grasslands` | 2–3 | Badlands or Marsh |
| 2 | Badlands | 2 | 2 | `normal_s2_01–06`, `challenge_s2_01–02` | `boss_badlands` | 2–4 | Frost or Ashlands |
| 3 | Marsh | 2 | 3 | `normal_s2_01–06`, `challenge_s2_01–02` | `boss_marsh` | 2–4 | Frost or Ashlands |
| 4 | Frost | 3 | 4 | `normal_s3_01–06`, `challenge_s3_01–02` | `boss_frost` | 2–5 | Abyss |
| 5 | Ashlands | 3 | 5 | `normal_s3_01–06`, `challenge_s3_01–02` | `boss_ashlands` | 2–5 | Abyss |
| 6 | Abyss | 4 | 6 | `normal_s4_01–06`, `challenge_s4_01–02` | `boss_abyss` | 2–6 | — (final) |

Shops (`shop_01`, `shop_bank_01`) can appear in any biome.

### Every level

"Pts" = marker points in the scene. Only a subset of ENEMY and LOOT points is used on a normal level (see section 3), so the pool is larger than what you see in a given run.

| Level | Type | Stage → used in | Exits (`exit_count`) | Tiles | Normal | Diff. | Extreme | Water | Wall | Enemy pts | Loot pts | Obstacles | Other |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `normal_s1_01` | Normal | 1 → Grasslands | 2 | 26 | 19 | 3 | 2 | 1 | 1 | 6 | 2 | 1 | — |
| `normal_s1_02` | Normal | 1 → Grasslands | 3 | 30 | 21 | 4 | 1 | 1 | 3 | 6 | 2 | 1 | — |
| `normal_s1_03` | Normal | 1 → Grasslands | 3 | 34 | 23 | 3 | 2 | 3 | 3 | 6 | 2 | 1 | — |
| `normal_s1_04` | Normal | 1 → Grasslands | 3 | 38 | 28 | 3 | 2 | 3 | 2 | 6 | 2 | 0 | — |
| `normal_s1_05` | Normal | 1 → Grasslands | 3 | 42 | 34 | 3 | 1 | 2 | 2 | 6 | 2 | 2 | — |
| `normal_s1_06` | Normal | 1 → Grasslands | 3 | 45 | 33 | 3 | 3 | 4 | 2 | 6 | 2 | 2 | — |
| `normal_s2_01` | Normal | 2 → Badlands, Marsh | 2 | 39 | 30 | 2 | 2 | 3 | 2 | 7 | 2 | 1 | — |
| `normal_s2_02` | Normal | 2 → Badlands, Marsh | 3 | 45 | 34 | 4 | 3 | 2 | 2 | 7 | 2 | 2 | — |
| `normal_s2_03` | Normal | 2 → Badlands, Marsh | 3 | 51 | 42 | 3 | 2 | 2 | 2 | 7 | 3 | 2 | — |
| `normal_s2_04` | Normal | 2 → Badlands, Marsh | 3 | 57 | 46 | 3 | 2 | 4 | 2 | 7 | 3 | 2 | — |
| `normal_s2_05` | Normal | 2 → Badlands, Marsh | 3 | 63 | 49 | 5 | 2 | 3 | 4 | 7 | 3 | 2 | — |
| `normal_s2_06` | Normal | 2 → Badlands, Marsh | 3 | 68 | 53 | 5 | 3 | 3 | 4 | 7 | 3 | 2 | — |
| `normal_s3_01` | Normal | 3 → Frost, Ashlands | 2 | 46 | 37 | 2 | 2 | 3 | 2 | 8 | 2 | 2 | — |
| `normal_s3_02` | Normal | 3 → Frost, Ashlands | 3 | 52 | 41 | 4 | 2 | 3 | 2 | 8 | 3 | 2 | — |
| `normal_s3_03` | Normal | 3 → Frost, Ashlands | 3 | 60 | 47 | 3 | 2 | 5 | 3 | 8 | 3 | 2 | — |
| `normal_s3_04` | Normal | 3 → Frost, Ashlands | 3 | 66 | 54 | 4 | 3 | 3 | 2 | 8 | 3 | 2 | — |
| `normal_s3_05` | Normal | 3 → Frost, Ashlands | 3 | 74 | 59 | 3 | 6 | 3 | 3 | 8 | 3 | 2 | — |
| `normal_s3_06` | Normal | 3 → Frost, Ashlands | 3 | 79 | 62 | 6 | 4 | 3 | 4 | 8 | 3 | 2 | — |
| `normal_s4_01` | Normal | 4 → Abyss | 2 | 52 | 39 | 4 | 2 | 5 | 2 | 9 | 3 | 2 | — |
| `normal_s4_02` | Normal | 4 → Abyss | 3 | 60 | 48 | 3 | 4 | 2 | 3 | 9 | 3 | 2 | — |
| `normal_s4_03` | Normal | 4 → Abyss | 3 | 68 | 56 | 5 | 3 | 2 | 2 | 9 | 3 | 2 | — |
| `normal_s4_04` | Normal | 4 → Abyss | 3 | 76 | 61 | 5 | 3 | 4 | 3 | 9 | 3 | 2 | — |
| `normal_s4_05` | Normal | 4 → Abyss | 3 | 84 | 67 | 5 | 4 | 5 | 3 | 9 | 3 | 2 | — |
| `normal_s4_06` | Normal | 4 → Abyss | 3 | 90 | 75 | 5 | 2 | 4 | 4 | 9 | 3 | 2 | — |
| `challenge_s1_01` | Challenge | 1 → Grasslands | 3 | 46 | 37 | 2 | 3 | 2 | 2 | 5 | 2 | 2 | turn limit 6 |
| `challenge_s1_02` | Challenge | 1 → Grasslands | 3 | 46 | 36 | 5 | 1 | 2 | 2 | 5 | 2 | 2 | turn limit 6 |
| `challenge_s2_01` | Challenge | 2 → Badlands, Marsh | 3 | 69 | 54 | 5 | 4 | 3 | 3 | 6 | 2 | 2 | turn limit 6 |
| `challenge_s2_02` | Challenge | 2 → Badlands, Marsh | 3 | 69 | 52 | 6 | 4 | 4 | 3 | 6 | 2 | 2 | turn limit 6 |
| `challenge_s3_01` | Challenge | 3 → Frost, Ashlands | 3 | 80 | 65 | 4 | 3 | 5 | 3 | 7 | 2 | 2 | turn limit 6 |
| `challenge_s3_02` | Challenge | 3 → Frost, Ashlands | 3 | 80 | 66 | 4 | 3 | 4 | 3 | 7 | 2 | 2 | turn limit 6 |
| `challenge_s4_01` | Challenge | 4 → Abyss | 3 | 92 | 74 | 6 | 3 | 4 | 5 | 7 | 2 | 2 | turn limit 6 |
| `challenge_s4_02` | Challenge | 4 → Abyss | 3 | 92 | 74 | 5 | 5 | 5 | 3 | 7 | 2 | 2 | turn limit 6 |
| `boss_abyss` | Boss | Abyss boss (fixed) | 0 | 127 | 111 | 6 | 0 | 2 | 8 | 1 | 1 | 5 | 4 boss points |
| `boss_ashlands` | Boss | Ashlands boss (fixed) | 1 | 91 | 88 | 2 | 1 | 0 | 0 | 1 | 1 | 4 | — |
| `boss_badlands` | Boss | Badlands boss (fixed) | 2 | 127 | 91 | 0 | 0 | 0 | 36 | 1 | 1 | 0 | — |
| `boss_frost` | Boss | Frost boss (fixed) | 1 | 91 | 88 | 3 | 0 | 0 | 0 | 1 | 1 | 6 | — |
| `boss_grasslands` | Boss | Grasslands boss (fixed) | 2 | 37 | 34 | 3 | 0 | 0 | 0 | 1 | 1 | 3 | — |
| `boss_marsh` | Boss | Marsh boss (fixed) | 2 | 91 | 77 | 8 | 0 | 6 | 0 | 3 | 1 | 5 | — |
| `boss_s1_01` | Boss | **unused** (stage 1 boss, no biome points at it) | 2 | 29 | 21 | 2 | 2 | 2 | 2 | 4 | 1 | 1 | — |
| `boss_s1_02` | Boss | **unused** (stage 1 boss, no biome points at it) | 2 | 29 | 19 | 4 | 1 | 3 | 2 | 4 | 1 | 1 | — |
| `boss_s2_01` | Boss | **unused** (stage 2 boss, no biome points at it) | 2 | 44 | 33 | 3 | 2 | 4 | 2 | 5 | 1 | 2 | — |
| `boss_s2_02` | Boss | **unused** (stage 2 boss, no biome points at it) | 2 | 44 | 35 | 2 | 2 | 2 | 3 | 5 | 1 | 2 | — |
| `boss_s3_01` | Boss | **unused** (stage 3 boss, no biome points at it) | 2 | 51 | 37 | 3 | 4 | 6 | 1 | 6 | 1 | 2 | — |
| `boss_s3_02` | Boss | **unused** (stage 3 boss, no biome points at it) | 2 | 51 | 38 | 4 | 3 | 4 | 2 | 6 | 1 | 2 | — |
| `boss_s4_01` | Boss | **unused** (stage 4 boss, no biome points at it) | 2 | 58 | 42 | 3 | 5 | 5 | 3 | 7 | 1 | 2 | — |
| `boss_s4_02` | Boss | **unused** (stage 4 boss, no biome points at it) | 2 | 58 | 44 | 3 | 3 | 5 | 3 | 7 | 1 | 2 | — |
| `shop_01` | Shop | any biome | 2 | 17 | 17 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | Shop |
| `shop_bank_01` | Shop Bank | any biome | 2 | 23 | 21 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | Shop, Bank |

**Unused today:** `boss_s1_01`, `boss_s1_02`, `boss_s2_01`, `boss_s2_02`, `boss_s3_01`, `boss_s3_02`, `boss_s4_01`, `boss_s4_02`. Every biome has its own `boss_*` level, and the generic stage boss levels are only picked when a biome has no `boss_level` set.

## 3. Tiles and markers

Each level scene holds two hidden 2D `TileMapLayer`s: **Layout** (terrain) and **Markers** (where things go). Both use hex tiles, 128×148 px. In the tilesets the atlas X coordinate *is* the enum value, so atlas (0,0) = first entry, (1,0) = second, and so on.

### Terrain (Layout layer)

| Atlas X | Terrain | Move cost | Tile height | Other | Landing effect |
|---|---|---|---|---|---|
| 0 | Normal | 1 | 0.30 | — | grass blades |
| 1 | Difficult | 2 | 0.35 | — | dust puff |
| 2 | Extreme | 3 | 0.40 | — | stone chips |
| 3 | Water | 2 | 0.18 | Lower than everything else | water splash |
| 4 | Wall | impassable | 0.90 | Blocks line of sight too (nothing can be attacked through it) | none |

Movement cost is per tile entered, so a 4-Move roll crosses four Normal tiles, two Difficult, or one Extreme plus one Normal. Teleport ignores terrain. Tile colours come from the biome, in this terrain order:

| Biome | Normal | Difficult | Extreme | Water | Wall | Gate / map colour |
|---|---|---|---|---|---|---|
| Grasslands | #739e59 | #96784f | #784f69 | #4f82bf | #737380 | #73e659 |
| Badlands | #cca86b | #a87347 | #8c4c38 | #408c99 | #996b4c | #ff9e33 |
| Marsh | #5c784c | #4c5c38 | #54454c | #406657 | #59544c | #4ce6bf |
| Frost | #99adc2 | #8091ab | #6b7899 | #4c85b8 | #707a8f | #8cd1ff |
| Ashlands | #594c4c | #734738 | #99331f | #f2731a | #332e33 | #ff5240 |
| Abyss | #4c4066 | #614073 | #803380 | #261a4c | #261f33 | #c780ff |

### Markers (Markers layer)

| Atlas X | Marker | What it becomes in the game |
|---|---|---|
| 0 | **PLAYER_START** | Where the player spawns. Exactly one per level; the next level grows out from the gate you walked through to this tile. (If missing, the game falls back to the first layout cell.) |
| 1 | **ENEMY** | A possible enemy spot. A normal level randomly uses the biome's `enemy_count` (min–max) of its ENEMY points, each filled by a random enemy from the biome list. **Challenge levels use every ENEMY point.** **Boss levels** put the boss on the ENEMY point farthest from the start and fill the next points with the boss's *starting* minions; every other point stays empty. |
| 2 | **OBSTACLE** | Always spawned (not randomised): a grey block that blocks both movement and line of sight. |
| 3 | **EXIT** | A possible gate. The game places one gate per onward connection on a random subset of EXIT points, sorted top-to-bottom on screen to match the map. Gates are locked until the level is clear. Keep EXIT points ≥ the level's `exit_count` in the `.tres` (they match in every level today). |
| 4 | **LOOT** | A possible gold chest (2–4 gold + biome difficulty; 15% chance of also holding a die, 10% an item). A normal level uses `round(points × (0.20 + 0.04 × levels cleared so far))`, at least 1. Walk onto it to collect; chests left behind vanish when the level is cleared. |
| 5 | **SHOP** | Always spawns a shop building (3 offers; price by rarity 10/20/35/55/80/120 gold). Usable once the level is clear. |
| 6 | **BANK** | Always spawns a bank building. Closes after one deposit/withdrawal. |
| 7 | **BOSS_POINT** | Draws a glowing ring on the tile. Only the **Overlord** uses it: when a health segment empties it teleports to the BOSS_POINT farthest from you and calls a Void Husk on the one closest to you. Only `boss_abyss` has them (4). |

Not a marker: the **Mystery piece** (question mark that unlocks a locked die or item) is placed by code, not by you. It goes on a free, reachable tile on the board's edge at least half the board's reach away from the start (falling back to near-edge, then the farthest tiles), so leave some open edge tiles in each level.

## 4. Enemies

Stats are fixed per type. Crit chance and miss chance are 5% on every enemy (nobody overrides the default). "First" = strikes before your attack lands when you hit it, and before it resolves when it retaliates.

### Regular enemies by biome

Each ENEMY point on a normal/challenge level rolls one of the biome's three types with equal chance.

**Grasslands** (order 1, stage 1, 2–3 per normal level; challenge levels fill every point)

| ID | Name | HP | Move | Atk | Def | Range | First | Gold | Inflicts |
|---|---|---|---|---|---|---|---|---|---|
| `grunt` | Grunt | 6 | 2 | 2 | 1 | 1 | — | 3 | — |
| `archer` | Archer | 4 | 2 | 2 | 0 | 3 | yes | 4 | — |
| `runt` | Runt | 4 | 3 | 2 | 0 | 1 | — | 2 | — |

**Badlands** (order 2, stage 2, 2–4 per normal level; challenge levels fill every point)

| ID | Name | HP | Move | Atk | Def | Range | First | Gold | Inflicts |
|---|---|---|---|---|---|---|---|---|---|
| `brute` | Brute | 13 | 2 | 3 | 1 | 1 | — | 5 | — |
| `slinger` | Slinger | 7 | 2 | 3 | 0 | 3 | yes | 5 | — |
| `stalker` | Stalker | 7 | 4 | 3 | 0 | 1 | yes | 5 | — |

**Marsh** (order 3, stage 2, 2–4 per normal level; challenge levels fill every point)

| ID | Name | HP | Move | Atk | Def | Range | First | Gold | Inflicts |
|---|---|---|---|---|---|---|---|---|---|
| `spitter` | Spitter | 7 | 2 | 2 | 0 | 3 | — | 5 | Poison |
| `lurker` | Lurker | 12 | 2 | 3 | 1 | 1 | — | 6 | Poison |
| `leech` | Leech | 6 | 3 | 2 | 0 | 1 | — | 4 | Poison |

**Frost** (order 4, stage 3, 2–5 per normal level; challenge levels fill every point)

| ID | Name | HP | Move | Atk | Def | Range | First | Gold | Inflicts |
|---|---|---|---|---|---|---|---|---|---|
| `sentinel` | Sentinel | 16 | 2 | 3 | 2 | 1 | — | 7 | — |
| `caster` | Caster | 10 | 2 | 3 | 0 | 3 | — | 7 | Stun |
| `howler` | Howler | 11 | 4 | 3 | 0 | 1 | yes | 7 | — |

**Ashlands** (order 5, stage 3, 2–5 per normal level; challenge levels fill every point)

| ID | Name | HP | Move | Atk | Def | Range | First | Gold | Inflicts |
|---|---|---|---|---|---|---|---|---|---|
| `ember` | Ember | 11 | 3 | 4 | 0 | 1 | yes | 8 | — |
| `juggernaut` | Juggernaut | 19 | 1 | 4 | 2 | 1 | — | 9 | Stun |
| `scorcher` | Scorcher | 11 | 2 | 3 | 0 | 4 | yes | 8 | — |

**Abyss** (order 6, stage 4, 2–6 per normal level; challenge levels fill every point)

| ID | Name | HP | Move | Atk | Def | Range | First | Gold | Inflicts |
|---|---|---|---|---|---|---|---|---|---|
| `shade` | Shade | 13 | 4 | 6 | 0 | 1 | yes | 10 | Poison |
| `voidcaller` | Voidcaller | 13 | 2 | 5 | 0 | 4 | yes | 10 | Stun |
| `horror` | Horror | 28 | 2 | 6 | 3 | 1 | — | 12 | — |

### Bosses and their minions

| Biome | Boss level | Boss | HP | Move | Atk | Def | Range | Atks/turn | Gold | Size | Special | Minion |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Grasslands | `boss_grasslands` | **Warlord** (`warlord`) | 26 | 2 | 2 | 1 | 1 | 2 | 15 | 1.6 | stun-immune | — |
| Badlands | `boss_badlands` | **Overseer** (`overseer`) | 26 | 5 | 4 | 1 | 1 | 1 | 20 | 1.6 | stun-immune | `overseer_minion` (Dust Raider) |
| Marsh | `boss_marsh` | **Brood Mother** (`brood_mother`) | 34 | 1 | 3 | 0 | 4 | 1 | 22 | 1.6 | stun-immune | `brood_minion` (Brood Spawn), 2 at level start |
| Frost | `boss_frost` | **Colossus** (`colossus`) | 56 | 3 | 5 | 0 | 3 | 1 | 28 | 1.7 | ice shield 16 (regen 3), stun-immune, Freeze | — |
| Ashlands | `boss_ashlands` | **Tyrant** (`tyrant`) | 90 | 3 | 4 | 0 | 1 | 2 | 32 | 1.6 | 4 health segments, stun-immune, Fire | — |
| Abyss | `boss_abyss` | **Overlord** (`overlord`) | 120 | 2 | 3 | 1 | 4 | 1 | 40 | 1.6 | 6 health segments, stun-immune | `overlord_minion` (Void Husk) |

Boss rules (the in-game description text):

- **Warlord**: Attacks twice each turn
- **Overseer**: Never walks: charges up to 5 tiles in a straight line towards you, ending at a wall · Every piece in the way takes an attack and is knocked aside · At half health calls 6 Dust Raiders, one on each side of the arena
- **Brood Mother**: Steps back to the furthest tile still in range before attacking · Calls 2 Brood Spawn beside it whenever none are alive; attacks instead if there is no room
- **Colossus**: An ice shield takes damage before its health and recovers 3 each round it takes none · Armour piercing attacks deal double damage to the shield · Shield up: closes in and attacks from adjacent · Shield broken: keeps away and attacks from range · A landed hit freezes you: half movement next turn
- **Tyrant**: Attacks twice each turn · Emptying a health segment sends flame bursts down all 6 lines (range 4) on its next turn instead · Damage it deals sets the target on fire: half again next turn
- **Overlord**: Emptying a health segment teleports it to the marked tile furthest from you and calls a Void Husk on the closest · Alternates form after each teleport: ranged (range 4, attack 3, def 1) and melee (attack 4, move 3, def 2)

Boss levels contain *only* the boss and its starting minions. Bosses can't be insta-killed (an Insta-kill face does fixed damage with a crit instead).

### Minions

| ID | Name | HP | Move | Atk | Def | Range | First | Gold | Inflicts |
|---|---|---|---|---|---|---|---|---|---|
| `overseer_minion` | Dust Raider | 2 | 2 | 1 | 0 | 1 | — | 0 | — |
| `brood_minion` | Brood Spawn | 1 | 3 | 1 | 0 | 1 | — | 0 | Poison |
| `overlord_minion` | Void Husk | 6 | 3 | 3 | 2 | 1 | — | 0 | — |

Minions only exist as summons: Brood Spawn (Brood Mother summons 2 whenever none are alive, and 2 are on the level at start), Dust Raider (Overseer calls 6 at half health), Void Husk (Overlord calls one each time a health segment empties).

### Where each enemy is used

| Enemy | Used in | As |
|---|---|---|
| Grunt (`grunt`) | Grasslands | regular |
| Archer (`archer`) | Grasslands | regular |
| Runt (`runt`) | Grasslands | regular |
| Warlord (`warlord`) | Grasslands | boss |
| Brute (`brute`) | Badlands | regular |
| Slinger (`slinger`) | Badlands | regular |
| Stalker (`stalker`) | Badlands | regular |
| Overseer (`overseer`) | Badlands | boss |
| Dust Raider (`overseer_minion`) | Badlands | Overseer minion |
| Spitter (`spitter`) | Marsh | regular |
| Lurker (`lurker`) | Marsh | regular |
| Leech (`leech`) | Marsh | regular |
| Brood Mother (`brood_mother`) | Marsh | boss |
| Brood Spawn (`brood_minion`) | Marsh | Brood Mother minion |
| Sentinel (`sentinel`) | Frost | regular |
| Caster (`caster`) | Frost | regular |
| Howler (`howler`) | Frost | regular |
| Colossus (`colossus`) | Frost | boss |
| Ember (`ember`) | Ashlands | regular |
| Juggernaut (`juggernaut`) | Ashlands | regular |
| Scorcher (`scorcher`) | Ashlands | regular |
| Tyrant (`tyrant`) | Ashlands | boss |
| Shade (`shade`) | Abyss | regular |
| Voidcaller (`voidcaller`) | Abyss | regular |
| Horror (`horror`) | Abyss | regular |
| Overlord (`overlord`) | Abyss | boss |
| Void Husk (`overlord_minion`) | Abyss | Overlord minion |

Enemy files not referenced by any biome or boss: none.

### Full enemy stat sheet (everything editable on an enemy)

One row per enemy file, with every field from `EnemyData`. Crit/Miss are chances. "Atks" = attacks per turn. Shield/Segments/Stun-immune/Minion only matter for bosses.

| ID | Name | Biome | Role | HP | Move | Atk | Def | Range | Crit | Miss | First | Atks | Gold | Stun | Poison | Freeze | Fire | Size | Shield (regen) | Segments | Stun-immune | Minion (at start) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `grunt` | Grunt | Grasslands | regular | 6 | 2 | 2 | 1 | 1 | 5% | 5% | — | 1 | 3 | — | — | — | — | 1.0 | — | — | — | — |
| `archer` | Archer | Grasslands | regular | 4 | 2 | 2 | 0 | 3 | 5% | 5% | yes | 1 | 4 | — | — | — | — | 1.0 | — | — | — | — |
| `runt` | Runt | Grasslands | regular | 4 | 3 | 2 | 0 | 1 | 5% | 5% | — | 1 | 2 | — | — | — | — | 1.0 | — | — | — | — |
| `warlord` | Warlord | Grasslands | boss | 26 | 2 | 2 | 1 | 1 | 5% | 5% | — | 2 | 15 | — | — | — | — | 1.6 | — | — | yes | — |
| `brute` | Brute | Badlands | regular | 13 | 2 | 3 | 1 | 1 | 5% | 5% | — | 1 | 5 | — | — | — | — | 1.0 | — | — | — | — |
| `slinger` | Slinger | Badlands | regular | 7 | 2 | 3 | 0 | 3 | 5% | 5% | yes | 1 | 5 | — | — | — | — | 1.0 | — | — | — | — |
| `stalker` | Stalker | Badlands | regular | 7 | 4 | 3 | 0 | 1 | 5% | 5% | yes | 1 | 5 | — | — | — | — | 1.0 | — | — | — | — |
| `overseer` | Overseer | Badlands | boss | 26 | 5 | 4 | 1 | 1 | 5% | 5% | — | 1 | 20 | — | — | — | — | 1.6 | — | — | yes | `overseer_minion` |
| `overseer_minion` | Dust Raider | Badlands | minion | 2 | 2 | 1 | 0 | 1 | 5% | 5% | — | 1 | 0 | — | — | — | — | 1.0 | — | — | — | — |
| `spitter` | Spitter | Marsh | regular | 7 | 2 | 2 | 0 | 3 | 5% | 5% | — | 1 | 5 | — | yes | — | — | 1.0 | — | — | — | — |
| `lurker` | Lurker | Marsh | regular | 12 | 2 | 3 | 1 | 1 | 5% | 5% | — | 1 | 6 | — | yes | — | — | 1.0 | — | — | — | — |
| `leech` | Leech | Marsh | regular | 6 | 3 | 2 | 0 | 1 | 5% | 5% | — | 1 | 4 | — | yes | — | — | 1.0 | — | — | — | — |
| `brood_mother` | Brood Mother | Marsh | boss | 34 | 1 | 3 | 0 | 4 | 5% | 5% | — | 1 | 22 | — | — | — | — | 1.6 | — | — | yes | `brood_minion` (2) |
| `brood_minion` | Brood Spawn | Marsh | minion | 1 | 3 | 1 | 0 | 1 | 5% | 5% | — | 1 | 0 | — | yes | — | — | 1.0 | — | — | — | — |
| `sentinel` | Sentinel | Frost | regular | 16 | 2 | 3 | 2 | 1 | 5% | 5% | — | 1 | 7 | — | — | — | — | 1.0 | — | — | — | — |
| `caster` | Caster | Frost | regular | 10 | 2 | 3 | 0 | 3 | 5% | 5% | — | 1 | 7 | yes | — | — | — | 1.0 | — | — | — | — |
| `howler` | Howler | Frost | regular | 11 | 4 | 3 | 0 | 1 | 5% | 5% | yes | 1 | 7 | — | — | — | — | 1.0 | — | — | — | — |
| `colossus` | Colossus | Frost | boss | 56 | 3 | 5 | 0 | 3 | 5% | 5% | — | 1 | 28 | — | — | yes | — | 1.7 | 16 (3) | — | yes | — |
| `ember` | Ember | Ashlands | regular | 11 | 3 | 4 | 0 | 1 | 5% | 5% | yes | 1 | 8 | — | — | — | — | 1.0 | — | — | — | — |
| `juggernaut` | Juggernaut | Ashlands | regular | 19 | 1 | 4 | 2 | 1 | 5% | 5% | — | 1 | 9 | yes | — | — | — | 1.0 | — | — | — | — |
| `scorcher` | Scorcher | Ashlands | regular | 11 | 2 | 3 | 0 | 4 | 5% | 5% | yes | 1 | 8 | — | — | — | — | 1.0 | — | — | — | — |
| `tyrant` | Tyrant | Ashlands | boss | 90 | 3 | 4 | 0 | 1 | 5% | 5% | — | 2 | 32 | — | — | — | yes | 1.6 | — | 4 | yes | — |
| `shade` | Shade | Abyss | regular | 13 | 4 | 6 | 0 | 1 | 5% | 5% | yes | 1 | 10 | — | yes | — | — | 1.0 | — | — | — | — |
| `voidcaller` | Voidcaller | Abyss | regular | 13 | 2 | 5 | 0 | 4 | 5% | 5% | yes | 1 | 10 | yes | — | — | — | 1.0 | — | — | — | — |
| `horror` | Horror | Abyss | regular | 28 | 2 | 6 | 3 | 1 | 5% | 5% | — | 1 | 12 | — | — | — | — | 1.0 | — | — | — | — |
| `overlord` | Overlord | Abyss | boss | 120 | 2 | 3 | 1 | 4 | 5% | 5% | — | 1 | 40 | — | — | — | — | 1.6 | — | 6 | yes | `overlord_minion` |
| `overlord_minion` | Void Husk | Abyss | minion | 6 | 3 | 3 | 2 | 1 | 5% | 5% | — | 1 | 0 | — | — | — | — | 1.0 | — | — | — | — |

Boss behaviours (`resources/bosses/`): Warlord → `none`, Overseer → `charge_behaviour`, Brood Mother → `summoner_behaviour`, Colossus → `frost_behaviour`, Tyrant → `burst_behaviour`, Overlord → `teleport_phase_behaviour`. Behaviour parameters: Brood Mother summon count 2; Tyrant burst reach 4, damage 3.

## 5. Dice

**Rarity tiers** (in order): Common → Uncommon → Rare → Epic → Legendary → Mythic. Rarity tints the die; Mythic also glows.

**Face order** is the order in the file: index 0 top, 1 right, 2 front, 3 back, 4 left, 5 bottom (opposite faces are 0↔5, 1↔4, 2↔3). Notation: `Atk`/`Def`/`Move` with a count; `Crit`, `Stun`, `Poison`, `Teleport`, `Dodge`, `Insta-kill`; `Pen n` = Penetrate n, `Range n` = extra range n; `+1 Atk buff` = a Buff face that adds 1 to every rolled face of that category.

**Columns:** *Loot* = can be awarded from chests, level/boss/challenge rewards and shops. *Starts unlocked* = loot is available from the very first run; if "no", it is unlocked for good by collecting a Mystery piece (which unlocks a random still-locked die or item). Dice that aren't loot are never found — they are only starting dice, and for them the "Starts unlocked" flag has no effect.

| ID | Name | Rarity | Loot | Starts unlocked | Unlock condition | Used by (starting dice) | Face 0 | Face 1 | Face 2 | Face 3 | Face 4 | Face 5 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `brawler` | Brawler Die | Common | yes | yes | Available from the start | — | 1 Atk | 2 Atk | 2 Atk | 3 Atk | 1 Def | 1 Move |
| `runner` | Runner Die | Common | yes | yes | Available from the start | — | 1 Move | 2 Move | 2 Move | 3 Move | 1 Atk | 1 Def |
| `sentry` | Sentry Die | Common | yes | yes | Available from the start | — | 1 Def | 2 Def | 2 Def | 3 Def | 1 Atk | 1 Move |
| `all_rounder` | All-Rounder Die | Common | no | yes | Not obtainable (see notes) | — | 1 Atk | 1 Def | 1 Move | 2 Move | 2 Def | 2 Atk |
| `attack` | Attack Die | Common | no | yes | Starting die only | Acrobat, Assassin, Knight, Mage, Monk, Pyro, Sniper, Tank, Void Dancer | 1 Atk | 1 Atk | 1 Atk | 2 Atk | 2 Atk | 3 Atk |
| `defence` | Defence Die | Common | no | yes | Starting die only | Acrobat, Assassin, Knight, Mage, Monk, Pyro, Sniper, Tank, Void Dancer | 1 Def | 1 Def | 1 Def | 2 Def | 2 Def | 3 Def |
| `movement` | Movement Die | Common | no | yes | Starting die only | Acrobat, Assassin, Knight, Mage, Monk, Pyro, Sniper, Tank, Void Dancer | 1 Move | 2 Move | 2 Move | 2 Move | 3 Move | 3 Move |
| `all_rounder_improved` | Improved All-Rounder Die | Uncommon | yes | no | Mystery piece | — | 2 Atk | 2 Def | 2 Move | 3 Move | 3 Def | 3 Atk |
| `scout` | Scout Die | Uncommon | yes | no | Mystery piece | — | 2 Move | 3 Move | 3 Move | 2 Move + Teleport | 2 Atk | 2 Def |
| `striker` | Striker Die | Uncommon | yes | yes | Available from the start | — | 2 Atk | 2 Atk | 3 Atk | 3 Atk | 2 Atk + Crit | 2 Def |
| `warden` | Warden Die | Uncommon | yes | yes | Available from the start | — | 2 Def | 3 Def | 3 Def | Dodge | 2 Atk | 2 Move |
| `cinder` | Cinder Die | Uncommon | no | yes | Starting die only | Pyro | 2 Atk | 2 Atk | 2 Atk | 1 Atk + Crit | 2 Def | 2 Move |
| `guardian` | Guardian Die | Uncommon | no | yes | Starting die only | Knight | 1 Atk | 2 Atk | 2 Atk | 2 Def | Dodge | 2 Def |
| `mantra` | Mantra Die | Uncommon | no | yes | Starting die only | Monk | 2 Atk | 1 Atk + Stun | 2 Def | 2 Def | Dodge | 2 Move |
| `phase` | Phase Die | Uncommon | no | yes | Starting die only | Mage | Dodge | 2 Atk | 1 Atk | 2 Atk | 4 Move + Teleport | 2 Move + Teleport |
| `rampart` | Rampart Die | Uncommon | no | yes | Starting die only | Tank | 3 Def | 2 Def | 2 Def | 2 Atk | 2 Atk | 1 Move |
| `rift` | Rift Die | Uncommon | no | yes | Starting die only | Void Dancer | 3 Move + Teleport | Dodge | Dodge | 2 Atk | 1 Atk + Crit | 2 Atk |
| `scope` | Scope Die | Uncommon | no | yes | Starting die only | Sniper | 2 Atk | 2 Atk | 2 Atk | 1 Atk + Pen 1 | 1 Def | 2 Move |
| `tumble` | Tumble Die | Uncommon | no | yes | Starting die only | Acrobat | 3 Move | 2 Move + Teleport | Dodge | 2 Atk | 2 Atk | 1 Atk + Crit |
| `viper` | Viper Die | Uncommon | no | yes | Starting die only | Assassin | Dodge | 2 Atk | 1 Atk | 1 Atk + Poison | 1 Atk + Poison | 3 Move |
| `all_rounder_super` | Super All-Rounder Die | Rare | yes | no | Mystery piece | — | 3 Atk | 3 Def | 3 Move | 4 Move | 4 Def | 4 Atk |
| `attack_improved` | Improved Attack Die | Rare | yes | yes | Available from the start | — | 2 Atk | 2 Atk | 2 Atk | 3 Atk | 3 Atk | 4 Atk |
| `defence_improved` | Improved Defence Die | Rare | yes | yes | Available from the start | — | 2 Def | 2 Def | 2 Def | 3 Def | 3 Def | 4 Def |
| `movement_improved` | Improved Movement Die | Rare | yes | yes | Available from the start | — | 2 Move | 2 Move | 3 Move | 3 Move | 4 Move | 4 Move |
| `piercer` | Piercer Die | Rare | yes | yes | Available from the start | — | 2 Atk + Pen 1 | 3 Atk + Pen 2 | 3 Atk | 3 Atk + Range 1 | 2 Def | 2 Move |
| `rally` | Rally Die | Rare | yes | no | Mystery piece | — | +1 Atk buff | +1 Move buff | 3 Atk | 3 Def | 3 Move | +1 Def buff |
| `venom` | Venom Die | Rare | yes | yes | Available from the start | — | 2 Atk + Poison | 3 Atk | 3 Atk + Poison | 2 Atk | 2 Def | 2 Move |
| `phantom` | Phantom Die | Epic | yes | no | Mystery piece | — | 3 Move + Teleport | 4 Move | Dodge | Dodge | 3 Atk | 3 Def |
| `reaper` | Reaper Die | Epic | yes | no | Mystery piece | — | Insta-kill | 4 Atk | 4 Atk + Crit | 3 Atk | 3 Def | 3 Move |
| `stunner` | Stunner Die | Epic | yes | yes | Available from the start | — | 3 Atk + Stun | 3 Atk | 4 Atk | 3 Atk + Stun | 3 Def | 3 Move |
| `aegis` | Aegis Die | Legendary | yes | no | Mystery piece | — | Dodge | 4 Def | 5 Def | 4 Def | 4 Atk | +1 Def buff |
| `attack_super` | Super Attack Die | Legendary | yes | no | Mystery piece | — | 3 Atk | 3 Atk | 3 Atk | 4 Atk | 4 Atk | 5 Atk |
| `conqueror` | Conqueror Die | Legendary | yes | no | Mystery piece | — | 4 Atk + Pen 2 | 5 Atk + Crit | Insta-kill | 4 Atk + Poison | +1 Atk buff | 4 Move |
| `defence_super` | Super Defence Die | Legendary | yes | no | Mystery piece | — | 3 Def | 3 Def | 3 Def | 4 Def | 4 Def | 5 Def |
| `movement_super` | Super Movement Die | Legendary | yes | no | Mystery piece | — | 3 Move | 3 Move | 4 Move | 4 Move | 5 Move | 5 Move |
| `tempest` | Tempest Die | Legendary | yes | yes | Available from the start | — | 4 Atk + Crit | 4 Atk + Range 2 | 5 Atk | 4 Atk + Stun | 4 Def | 4 Move |
| `ascendant` | Ascendant Die | Mythic | yes | no | Mystery piece | — | 5 Atk + Crit + Pen 3 | 5 Atk + Poison + Stun | 5 Def | Dodge | 5 Move + Teleport | +1 Atk buff |
| `doom` | Doom Die | Mythic | yes | yes | Available from the start | — | Insta-kill | 4 Atk + Pen 1 | 5 Atk + Crit | 5 Atk + Stun | Dodge | 5 Move + Teleport |

### Loot pool at a glance

| Rarity | Available from the start | Needs a Mystery piece |
|---|---|---|
| Common | `brawler`, `runner`, `sentry` | — |
| Uncommon | `striker`, `warden` | `all_rounder_improved`, `scout` |
| Rare | `attack_improved`, `defence_improved`, `movement_improved`, `piercer`, `venom` | `all_rounder_super`, `rally` |
| Epic | `stunner` | `phantom`, `reaper` |
| Legendary | `tempest` | `aegis`, `attack_super`, `conqueror`, `defence_super`, `movement_super` |
| Mythic | `doom` | `ascendant` |

When a roll lands on a rarity with nothing available, the game falls back to the next rarity up that has something (then down). Rarity weights per biome difficulty are in `resources/dice/dice_loot.gd`.

## 6. Dice materials (finishes)

Cosmetic only. The player picks a main finish (and, for designs with a trim, a trim finish) in the dice designer; the die's rarity colour is mixed in by `tint`. All twelve are unlocked from the start — there is no unlock field on `DieFinish`. **There is also no order field:** the designer currently sorts them alphabetically by display name. Send the list back in the order you want them displayed.

| ID | Name | Shader pattern | Base colour | Tint | Detail colour | Roughness | Metallic | Opacity |
|---|---|---|---|---|---|---|---|---|
| `brass` | Brass | Metal | #d9a64c | 0.7 | #333333 | 0.3 | 0.95 | 1.0 |
| `flecked` | Flecked | Flecked | #ffffff | 1.0 | #1a1a1a | 0.45 | 0.0 | 1.0 |
| `galaxy` | Galaxy | Galaxy | #05050f | 0.12 | #6633e6 | 0.2 | 0.0 | 1.0 |
| `glass` | Glass | Glass | #ffffff | 1.0 | #333333 | 0.05 | 0.0 | 0.25 |
| `marble` | Marble | Marble | #ffffff | 0.85 | #404047 | 0.25 | 0.0 | 1.0 |
| `matte` | Matte | Plastic | #ffffff | 1.0 | #333333 | 0.85 | 0.0 | 1.0 |
| `metal` | Metal | Metal | #ccccd1 | 0.75 | #333333 | 0.3 | 0.9 | 1.0 |
| `obsidian` | Obsidian | Obsidian | #0a0a0d | 0.3 | #333333 | 0.08 | 0.1 | 1.0 |
| `pearl` | Pearl | Pearl | #ffffff | 0.85 | #333333 | 0.25 | 0.0 | 1.0 |
| `plastic` | Plastic | Plastic | #ffffff | 1.0 | #333333 | 0.4 | 0.0 | 1.0 |
| `rust` | Rusted Metal | Rust | #99999e | 0.6 | #733314 | 0.35 | 0.8 | 1.0 |
| `wood` | Wood | Wood | #8c592e | 0.35 | #4c2e14 | 0.7 | 0.0 | 1.0 |

The shader pattern list is fixed in code: Plastic, Metal, Glass, Rust, Marble, Obsidian, Galaxy, Flecked, Wood, Pearl. Matte and Plastic share the Plastic pattern; Brass and Metal share Metal.

## 7. Dice designs (body shapes)

A design is the 3D shape of the die body (an `.obj` mesh in `assets/dice/designs/`), independent of the symbols on its faces. Physics always uses a 1×1×1 cube, so designs must fit inside it and have a flat square area on each face for the symbols. A design with a second mesh surface has a **trim** (frame, studs, edges) drawn in a separate trim finish, picked from the same material list. The player's choice is saved as `die_design`; default is Classic.

> **Display order:** the dice designer currently lists unlocked designs first, then locked ones, each alphabetically. To show them in your order, `DieDesign` needs a new `order` property. Send the list back in the order you want.

| ID | Name | Starts unlocked | Unlock condition | Stat tracked | Face size | Face offset | Mesh |
|---|---|---|---|---|---|---|---|
| `chamfer` | Chamfer | yes | — | — | 0.84 | 0.5 | `assets/dice/designs/chamfer.obj` |
| `classic` | Classic | yes | — | — | 0.74 | 0.5 | `classic_mesh.res` |
| `sharp` | Sharp | yes | — | — | 0.86 | 0.5 | `built-in box mesh` |
| `blink` | Blink | no | Teleport 100 times. | `teleport` | 0.68 | 0.5 | `assets/dice/designs/blink.obj` |
| `bog` | Bog | no | Defeat the Brood Mother (Marsh boss) 20 times. | `boss_defeated` (brood_mother) | 0.74 | 0.5 | `assets/dice/designs/bog.obj` |
| `crowned` | Crowned | no | Win 5 runs. | `victories` | 0.8 | 0.485 | `assets/dice/designs/crowned.obj` |
| `ember` | Ember | no | Set enemies on fire 50 times. | `burn` | 0.76 | 0.5 | `assets/dice/designs/ember.obj` |
| `gilded` | Gilded | no | Land 250 critical hits. | `crits` | 0.68 | 0.485 | `assets/dice/designs/gilded.obj` |
| `glacier` | Glacier | no | Defeat the Colossus (Frost boss) 10 times. | `boss_defeated` (colossus) | 0.74 | 0.5 | `assets/dice/designs/glacier.obj` |
| `inferno` | Inferno | no | Defeat the Tyrant (Ashlands boss) 10 times. | `boss_defeated` (tyrant) | 0.78 | 0.5 | `assets/dice/designs/inferno.obj` |
| `iron` | Iron | no | Defeat the Warlord (Grasslands boss) 10 times. | `boss_defeated` (warlord) | 0.8 | 0.485 | `assets/dice/designs/iron.obj` |
| `pebble` | Pebble | no | Recover 100 health. | `healed` | 0.58 | 0.5 | `assets/dice/designs/pebble.obj` |
| `sandstorm` | Sandstorm | no | Defeat the Overseer (Badlands boss) 10 times. | `boss_defeated` (overseer) | 0.72 | 0.485 | `assets/dice/designs/sandstorm.obj` |
| `thunder` | Thunder | no | Stun enemies 100 times. | `stun` | 0.62 | 0.5 | `assets/dice/designs/thunder.obj` |
| `venom` | Venom | no | Poison enemies 100 times. | `poison` | 0.55 | 0.485 | `assets/dice/designs/venom.obj` |
| `void` | Void | no | Defeat the Overlord (Abyss boss) 5 times. | `boss_defeated` (overlord) | 0.76 | 0.42 | `assets/dice/designs/void.obj` |

Targets: Blink 100; Bog 20; Crowned 5; Ember 50; Gilded 250; Glacier 10; Inferno 10; Iron 10; Pebble 100; Sandstorm 10; Thunder 100; Venom 100; Void 5.

Notes: Classic and Sharp are also hard-coded as the default `unlocked_die_designs` in `progression_data.gd`; Chamfer is unlocked by its own `starts_unlocked = true`. Five designs use the slightly smaller face offset 0.485 (Crowned, Gilded, Iron, Sandstorm, Venom), and Void uses 0.42. I did not check which meshes have a trim surface.

## 8. Characters

Displayed on the character select in `order` (lowest first); send the list back in the order you want. Every character has 5 HP and a 5-die starting pool of Movement, Defence, Attack plus two copies of their own die.

| Order | Character | Starts unlocked | Unlock condition | Attack range | Starting dice | Passive | Active (every 3 turns) |
|---|---|---|---|---|---|---|---|
| 0 | **Knight** (`knight`) | yes | — | 1 | `movement`, `defence`, `attack`, `guardian`, `guardian` | **Bulwark** — every defence die you roll gets +1 shield. | **Shield Block** — completely block one attack. |
| 1 | **Assassin** (`assassin`) | yes | — | 1 | `movement`, `defence`, `attack`, `viper`, `viper` | **Quick Strike** — you always strike first, even against enemies that strike first, and your first attack each turn is a crit. | **Ambush** — double the highest die of one attack (stacks with a crit). |
| 2 | **Mage** (`mage`) | yes | — | 3 | `movement`, `defence`, `attack`, `phase`, `phase` | **Arcane** — your attacks ignore enemy defence. | **Blast** — an attack also hits every tile next to the target for the same damage. |
| 3 | **Monk** (`monk`) | no | Win a run without taking any damage from a boss. | 1 | `movement`, `defence`, `attack`, `mantra`, `mantra` | **Inner Peace** — heal 1 at the end of every round, even when you took damage. | **Redirect** — when an enemy strikes back: send its hit to any enemy as close to you as the striker is. |
| 4 | **Acrobat** (`acrobat`) | no | Dodge an attack from every boss. | 1 | `movement`, `defence`, `attack`, `tumble`, `tumble` | **Nimble** — every movement die you roll gets +1 move. | **Leap** — leap up to 4 tiles (like a teleport), dealing 3 damage to every enemy you leap over. |
| 5 | **Pyro** (`pyro`) | no | Defeat the Tyrant (Ashlands boss) 5 times. | 3 | `movement`, `defence`, `attack`, `cinder`, `cinder` | **Smoke** — ranged enemies have 1 less range. | **Ignite** — an attack sets what it hits on fire - half the damage dealt again at the start of the next round. |
| 6 | **Void Dancer** (`void_dancer`) | no | Win a run. | 1 | `movement`, `defence`, `attack`, `rift`, `rift` | **Blur** — enemy attacks are twice as likely to miss you. | **Rift Step** — teleport up to 5 tiles; your next attack this turn is a crit. |
| 7 | **Tank** (`tank`) | no | Defeat a boss with only 1 health left and fewer dice than your pool can hold. | 1 | `movement`, `defence`, `attack`, `rampart`, `rampart` | **Iron Wall** — you always roll an extra defence die showing 2. | **Shield Charge** — charge up to 3 tiles (like a teleport), dealing 3 damage that ignores defence to every enemy in the way and knocking them aside. |
| 8 | **Sniper** (`sniper`) | no | Kill 100 ranged enemies. | 5 | `movement`, `defence`, `attack`, `scope`, `scope` | **Deadeye** — +1 damage against enemies 3 tiles away, +2 at 4 and +3 at 5 or more, added after crits. | **Armour Piercer** — as an action: your attacks for the rest of the turn ignore defence. |

Unlock challenges, in detail (`data/challenges/unlock_*.tres`):

| Character | Stat tracked | Target |
|---|---|---|
| Monk | `flawless_victory` | 1 |
| Acrobat | `dodged_boss` | each of: warlord, overseer, brood_mother, colossus, tyrant, overlord |
| Pyro | `boss_defeated` | 5 (counted per: tyrant) |
| Void Dancer | `victories` | 1 |
| Tank | `clutch_boss_kill` | 1 |
| Sniper | `ranged_kill` | 100 |

## 9. Things I noticed while reading

- **`all_rounder` is orphaned.** It isn't a loot die and no character starts with it, so it can never appear. Its "improved" and "super" versions are loot dice.
- **`Improved` and `Super` dice are separate dice,** not upgrades of the base die. The code has a `dice_upgraded` stat and a `TODO - track effects and upgraded dice`, but nothing upgrades dice yet.
- **Unused boss levels:** the eight `boss_s1_01` … `boss_s4_02` scenes (see section 2).
- **Stale comments in `biome_data.gd`:** `difficulty` is documented as raising "how many enemy and loot points are used", but it only drives loot rarity (and the gold in chests); the enemy count comes from `enemy_count`. `enemy_count` also says challenge levels use "the max + 2", but the code uses every ENEMY point on the level.
- **Enemy count vs. points:** normal levels have 6/7/8/9 ENEMY points (stages 1–4) but the biomes only use 2–3, 2–4, 2–5, 2–6. Extra points are just a pool of possible positions — useful when you redesign layouts.
- **Dice materials have no order or unlock field** (see section 6) and **dice designs have none either** (section 7), so both need a new `order` property, like characters have.
- **Debug dice** (`data/dice_debug/`, six files, one per rarity) exist but I left them out of the tables.

