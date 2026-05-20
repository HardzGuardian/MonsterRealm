# Monster Realm

A turn-based monster-catching RPG built with **Godot 4.6**, inspired by Monster Galaxy.
Explore the Sunshire world map, battle wild monsters, catch them, level them up, and evolve your team.

---

## Gameplay

| Battle | Capture | Evolution |
|--------|---------|-----------|
| ![Battle](demo/battle.gif) | ![Capture](demo/capture.gif) | ![Evolution](demo/evolution.gif) |

---

## Features

- **46-level world map** with branching paths and bezier dot trails
- **Turn-based battles** — speed-weighted turn order, status effects (poison, burn, paralysis), PP system
- **93 monsters** across 12 elements with stats, learnsets, evolutions, and signature moves
- **Rarity-based encounter and capture rates** — common, rare, epic, legendary
- **Full progression system** — XP, leveling, stat growth, move learning on level-up
- **Evolution system** — combine copies + potions to evolve monsters
- **Mogadex** — browse your collection, manage team, equip moves, toggle home roaming
- **Shop & inventory** — buy items, use them in battle
- **3 save slots** with persistent HP, PP, fainted state, and XP
- **In-editor map tool** — dock-based plugin to create, connect, and manage map nodes

---

## Project Structure

```
monster-realm/
├── addons/
│   └── map_editor/          # Godot editor plugin for building the world map
├── assets/
│   ├── audio/               # Music and SFX (ogg/wav)
│   ├── fonts/               # FredokaOne and other fonts
│   ├── map/                 # Battle backgrounds (one per level)
│   ├── monsters/            # Monster sprites (93 PNGs)
│   ├── ui/                  # UI buttons, icons, map node images
│   └── vfx/                 # VFX frame sequences (elements, status, hit)
├── data/
│   ├── game_config.json     # Element effectiveness, rarities, battle settings
│   ├── items.json           # Shop items and consumables
│   ├── levels.json          # All 46 levels — positions, enemies, rewards, unlock chain
│   ├── monsters.json        # All 93 monsters — stats, learnsets, evolutions
│   └── moves.json           # All moves — damage, buffs, debuffs, signatures
├── scenes/
│   ├── battle/              # Battle scene
│   ├── core/                # Monster node scene
│   ├── home/                # Home screen and roaming monster scenes
│   ├── map/                 # World map and MapNode scenes
│   └── ui/                  # UI panel scenes
└── scripts/
    ├── audio/               # AudioManager (music + SFX, persisted volume)
    ├── battle/              # Battle loop, AI, damage calc, animations, state
    ├── data/                # GameData, SaveData, GameState (autoloads)
    ├── home/                # Home screen, roaming monster behaviour
    ├── map/                 # WorldMap, MapNode, PathDots
    ├── monster/             # Monster node — stats, HP, status effects
    └── ui/                  # Mogadex, Shop, Settings, SaveSlot panels
```

---

## Data Format

All game data lives in `data/` as plain JSON — no code changes needed to add monsters, moves, or levels.

### Monster entry (`monsters.json`)
```json
"alyx": {
  "name": "Alyx",
  "hp": 90, "attack": 12, "defense": 8, "speed": 14,
  "element": "fire", "rarity": "common",
  "sprite": "res://assets/monsters/Alyx.png",
  "moves": ["kick", "roundhouse", "zodiac_armor", "zodiac_weakness"],
  "learnset": [
    { "level": 1,  "move": "kick" },
    { "level": 5,  "move": "roundhouse" },
    { "level": 25, "move": "catapult" }
  ],
  "signature_move": "feral_fire",
  "evolves_to": "alleaux",
  "evolve_monsters_needed": 3,
  "evolve_potions_needed": 2,
  "growth": { "hp": 8, "attack": 2, "defense": 1, "speed": 1 },
  "description": "Thanks to its big ears, the Alyx has excellent hearing and balance."
}
```

### Move entry (`moves.json`)
```json
"feral_fire": {
  "name": "Feral Fire",
  "kind": "damage",
  "element": "fire",
  "power": 50,
  "accuracy": 88,
  "signature": true,
  "ranged": true,
  "message": "erupts with wild Feral Fire!"
}
```

### Level entry (`levels.json`)
```json
"level_1": {
  "name": "West Summer Road",
  "order": 1,
  "position": [402, 187],
  "enemy_team": ["beefee", "chuuchilla", "dinho", "lambo"],
  "enemy_level": 2,
  "reward_gold": 10,
  "background": "res://assets/map/West Summer Road.png",
  "unlock_after_win": ["level_2"]
}
```

---

## Map Editor Plugin

The `addons/map_editor/` plugin adds a **Map Editor** dock to the Godot editor.

Enable it: **Project → Project Settings → Plugins → Map Editor → Enable**

| Button | Action |
|--------|--------|
| Create Next Node | Creates MapNode(max+1) from selected node, links it, updates levels.json |
| Delete & Relink | Removes selected node, repoints predecessors to its successor |
| Set SOURCE → Connect | Two-step branch creation for forking paths |
| Renumber Chain | Walks unlock chain from level_1 and renames everything contiguously |
| Refresh Path Dots | Forces path redraw in editor |
| Reset Map | Wipes all nodes and starts from level_1 (with confirmation) |

---

## Autoloads

| Singleton | Path | Purpose |
|-----------|------|---------|
| `GameData` | `scripts/data/GameData.gd` | Loads all JSON on boot, provides typed accessors |
| `SaveData` | `scripts/data/SaveData.gd` | 3-slot save system, all persistence logic |
| `GameState` | `scripts/data/GameState.gd` | Scene transitions and selected level tracking |
| `GameTheme` | `scripts/ui/GameTheme.gd` | Global UI theme applied at runtime |
| `AudioManager` | `scripts/audio/AudioManager.gd` | Music + SFX player with persisted volume |

---

## Requirements

- **Godot 4.6** (GL Compatibility renderer)
- No external dependencies — pure GDScript

---

## Getting Started

1. Clone the repo
2. Open `project.godot` in Godot 4.6
3. Run the project (`F5`) — starts on the Home screen
4. Your first monster (Alyx) is given automatically on first launch

---

## License

Assets used from:
- [Kenney](https://kenney.nl) — UI Pack, Game Icons (CC0)
- [CraftPix](https://craftpix.net) — Pixel VFX packs (free tier)
- Various free Itch.io pixel art VFX packs (see `VFx data/_extracted/*/License.txt`)

Game code is original.
