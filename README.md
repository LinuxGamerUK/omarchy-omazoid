# Omazoid

A Project Zomboid-style zombie survival game built as an Omarchy shell plugin. Survive the apocalypse in a procedurally generated city with scarce resources, dangerous undead, and the eternal question: how long can you last?

## Features

- **Procedurally generated world** — 256×256 tile map with 8 district types (residential, commercial, downtown, industrial, hospital, military, farmland, park), each with unique buildings, loot, and zombie types
- **Real-time combat** — melee weapons with swing animations, ranged weapons with projectiles and ammo management
- **8 zombie types** — walkers, runners, brutes, crawlers, spitters, screamers, swarmers, and infected soldiers, each with distinct AI behaviors and stats
- **Survival mechanics** — health, hunger, thirst, stamina, and infection systems
- **Day/night cycle** — 24 game hours = 1 real hour. Zombies are more aggressive and numerous at night
- **Looting** — search containers (shelves, crates, lockers, fridges, cabinets, etc.) for food, weapons, tools, materials, and medical supplies
- **Inventory system** — manage your items, equip weapons, consume food/drink, use medical supplies
- **Permadeath or Respawn** — choose your difficulty at game start
- **Auto-save** — game saves every 15 minutes and on exit
- **Infection mechanic** — bites (85% infection chance) and scratches (15% chance) can lead to a slow death. Find antibiotics to cure it

## Install

```sh
omarchy plugin add https://github.com/LinuxGamerUK/Omazoid.git --enable --yes
```

## Usage

Click the **🧟 Omazoid** bar widget to open the launch panel, then click **Continue** or **New Game** to start playing.

### Controls

| Key | Action |
|-----|--------|
| WASD / Arrows | Move |
| Mouse | Aim |
| Left Click | Attack / Shoot |
| Scroll Wheel | Zoom in/out (40% – 300%) |
| Shift | Run (drains stamina) |
| E | Interact / Loot / Pick up items |
| I or Tab | Inventory |
| F | Toggle flashlight |
| M | Mute / unmute audio |
| Escape | Pause / Close menus |

### Audio

Omazoid includes procedurally generated, royalty-free audio:
- **Ambient music** — separate day and night atmospheric tracks that switch automatically
- **Combat SFX** — weapon swings, hits, gunshots
- **Environmental SFX** — door creaks, item pickups, eating/drinking
- **Tension SFX** — zombie groans (based on nearby count), heartbeat (when health < 30%)
- **UI SFX** — new day chime, menu interactions

All audio is generated with ffmpeg and bundled as OGG files in the `audio/` directory.

### Game Modes

- **Permadeath** — One life. When you die, your save is deleted and you start fresh.
- **Respawn** — Death sends you back to your last save point.

## Configure

```sh
omarchy bar move io.github.LinuxGamerUK.Omazoid --section left
```

## Remove

```sh
omarchy plugin remove io.github.LinuxGamerUK.Omazoid
```

## How It Works

Omazoid runs as an Omarchy shell plugin with two entry points:

- **`overlay`** (`GameOverlay.qml`) — the fullscreen game with Canvas-based tile rendering, entity management, and game loop
- **`bar-widget`** (`BarWidget.qml` + `Panel.qml`) — a bar chip with a launch panel

The game uses `keepLoaded: true` so state persists in memory between sessions. Save files are stored in `~/.config/omarchy/plugins/io.github.LinuxGamerUK.Omazoid/saves/save.json`.

### Architecture

| File | Purpose |
|------|---------|
| `GameOverlay.qml` | Main game overlay — rendering, input, game loop, HUD, menus |
| `BarWidget.qml` | Bar widget entry point |
| `Panel.qml` | Bar widget launch panel |
| `js/Utils.js` | PRNG, noise, math helpers, time functions |
| `js/World.js` | Procedural map generation, tile system, districts |
| `js/Items.js` | Item/weapon definitions, loot tables |
| `js/Entities.js` | Zombie types, AI, combat resolution |
| `js/Render.js` | Canvas drawing — tiles, characters, zombies, effects |

## Dependencies

- Omarchy with Quattro shell
- Quickshell (bundled with Omarchy)
- No external dependencies — all rendering is procedural via QML Canvas

## License

MIT — see [LICENSE](LICENSE)