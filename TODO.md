# Omazoid — TODO & Roadmap

A Project Zomboid-style zombie survival game built as an Omarchy shell plugin.

## ✅ Done this session (review + repair pass)

The plugin was pulled from the Forgejo backup in a **corrupted state** — the
overlay would not parse and could not load at all. This pass repaired it and
fixed several critical logic bugs. See commit `99784f8` for the full detail.

### Structure repairs (game wouldn't load)
- Restored `}` on ~33 single-line object declarations whose closing brace had
  been stripped (26 `SoundEffect`, 2 `Process`, 4 `Item` spacers,
  1 `MediaPlayer.onSourceChanged`).
- Restored 5 multi-line `onClicked: {` handlers that had been mangled into a
  bare `}` (Pause menu ×3, Death screen ×1, Inventory item ×1).
- Closed the `MediaPlayer` block and the root `Item` so the `StatBar` /
  `MenuButton` inline components are top-level (required for inline components).
- Rewrote the broken `cleanupDead` block (an unclosed `if` + dead code) and now
  actually call `Entities.cleanupDead()` each tick to cap corpses at 40.

### Logic repairs
- `equipWeapon()` now **clones** the weapon definition, so per-swing durability
  drains a per-instance copy. Previously `weapon.durability--` mutated the
  shared `Items.WEAPONS` table — breaking one bat broke every bat found for the
  rest of the run.
- Ranged weapons now draw ammo from the **inventory** (`_invCount`) instead of
  the `equippedAmmo` tracker, which was initialised to 0 and only ever
  decremented — so guns could **never fire**. HUD ammo readout updated to match.
- `checkSaveFile()` now runs via `bash` so `&&` short-circuits. The previous
  raw-arg form always failed, leaving `saveExists=false` and hiding the
  **Continue** button on the start menu.
- `Render.drawCorpse` now reads `zombie.loot` / `zombie.looted` (matching what
  `Entities.playerAttackZombie` sets), so the corpse-loot sparkle indicator
  actually shows. It was reading the never-set `corpseLoot` / `corpseLooted`.
- Fixed the README install URL (`Omatoid.git` → `omarchy-omazoid.git`).

---

## 🐛 Known issues (remaining bugs / rough edges)

### Saving
- **Save is written via a shell `printf '%s' '…'` with the whole JSON on the
  command line.** Long-running saves (large `world.changes` + `containers`)
  can approach/exceed `ARG_MAX` (~2 MiB) and fail silently. Replace with a
  proper file write — Quickshell `Io` file API, or write to a temp file and
  `mv` into place (also makes saves atomic).
- `saveGame()` on `close()` only fires when `gameState === "playing"`; closing
  from `paused`/`inventory`/`looting` skips the save. The Escape→pause path
  does save, but a direct close (Super+W / quit button) from a paused state
  would lose progress. Consider saving on close from any active state.
- `_serializePlayer` copies all enumerable props including potentially large
  nested objects; verify it isn't carrying live QML object refs into the save.

### Determinism / RNG
- `Items.generateLoot()` calls `Utils.setSeed(Date.now() + …)` on every loot
  generation, which reseeds the **shared** PRNG and perturbs every subsequent
  `Utils.rand*` call (zombie spawning, AI wander, etc.). Either use a local
  RNG for loot or just use `Math.random()` for loot rolls and leave the
  seeded PRNG for world-gen only.
- `Entities.generateCorpseLoot()` uses the shared `Utils.rand*` without
  reseeding — fine, but inconsistent with `generateLoot`. Pick one model.

### Zombie AI / balance
- **Night detection looks backwards.** `updateZombie` computes
  `detectRange = detectionRange * (1 - 0.3 * nf)`, so zombies detect the
  player at **70% range at night** vs 100% by day — i.e. they notice you
  *less* at night, contradicting the README's "more aggressive … at night".
  Spawning does increase at night (correct). Decide intent and fix the
  detection formula (and the misleadingly-named `nightFactorForPlayer`,
  which actually returns a "day factor" = `1 - nightFactor`).
- **Spitter zombies are melee-only.** `ZOMBIE_TYPES.spitter` has
  `ranged: true, attackRange: 150` but no projectile logic exists in
  `updateZombie`/`zombieAttackPlayer` — spitters just walk up and melee.
  Implement a spit projectile (like the player's, but damaging the player).
- **Walkable-tile tables are duplicated and drift.** `World.WALKABLE` (used
  for the player) and `Entities.isWalkableType` (used for zombies) are two
  separate hand-maintained lists. `Entities` extra-includes `SANDBAG` (36)
  and `WATER_COLLECTOR` (38), so zombies can walk through sandbags while the
  player cannot. Single-source this (e.g. `Entities` imports `World.WALKABLE`)
  so fortifications block both consistently.
- Corpse cleanup caps at 40 corpses but they're removed oldest-first by array
  order, which isn't strictly "oldest by death time". Fine for now; note if
  it ever matters visually.

### Performance
- `World.deserialize()` regenerates the full 256×256 world from seed on every
  load (65536 tiles + all buildings + furniture + decorations). Loading a
  long-running save can stall the shell briefly. Options: cache the
  generated base world in memory across sessions, or persist tiles more
  cleverly.
- `_updateZombies` allocates a fresh `newZombies` array every tick (30×/s).
  Mutate in place (mark/skip dead) to reduce GC pressure.
- `World.getDistrictAt` is an O(16) linear scan called per-tile during
  generation and per-spawn; build a district index grid for O(1) lookup.
- `scatterDecorations` iterates every tile and calls `getDistrictAt` for
  each — fine at gen time but it's a big chunk of gen cost.

### Rendering / UX
- Canvas redraws the whole visible world every frame at 30 FPS with no dirty
  tracking. For a 256² map with many entities this is OK on modern hardware
  but worth profiling once gameplay is heavier.
- No minimap — easy to get lost in a 256² city. A small minimap (districts +
  player + nearby zombies) would help a lot.
- No health/damage feedback on the player beyond blood particles (no screen
  edge vignette, no hit direction indicator).
- Inventory has weight but **no encumbrance effect** — weight is cosmetic.
  Either make weight matter (slower move / less stamina when heavy) or
  remove the display.
- No way to **drop** items, only pick up / use / equip.

---

## 🧐 Design questions to settle
- Night detection direction (above) — should zombies detect *more* at night
  (PZ-style) or *less* (darkness hides you)? Current code says less.
- Permadeath vs Respawn: Respawn mode currently reloads the last save on
  death, but the save is also written on pause/autosave, so "last save" can
  be moments before death. Decide how far back respawn should roll.
- Map size: 256² is large for a first session. Consider a smaller default
  (e.g. 128²) or a difficulty-tied size.

---

## 🗺️ Feature roadmap (Project Zomboid-style)

Roughly in priority order. Each is independent — pick what sounds fun.

### Core survival depth
- [ ] **Crafting system** — materials already exist (wood_plank, nails,
      metal_scrap, rope, duct_tape, sheet). Recipes: barricades, bandages
      (cloth → sheet), makeshift weapons, water collector, traps.
- [ ] **Barricading / fortification** — `BARRICADE`, `BARBED_WIRE`,
      `SANDBAG` tiles exist but aren't buildable. Let the player board up
      doors/windows with planks+nails (and let zombies break them down).
- [ ] **Water & power shutoff over time** — taps/toilets give water early,
      run dry after N days; fridges stop preserving food. Drives
      `WATER_COLLECTOR` and rain-barrel crafting.
- [ ] **Food perishability** — `perishable: true` is defined on items but
      unused. Track spoilage so fridges matter.
- [ ] **Cooking** — `STOVE` tile exists; raw meat/veg → cooked (better
      hunger, no sickness). Raw food has a food-poisoning chance.
- [ ] **Infection depth** — symptoms by stage (fever, tremor, slowed
      movement), and let the player "revoke" infection via early
      antibiotics only. Add a visible infection timer/percentage in HUD
      (currently a single line).

### Combat & enemies
- [ ] **Spitter ranged spit** (see bugs) — acid projectile, pools on ground.
- [ ] **Screamer chain-alert** is implemented; add a scream SFX + visual
      radius so the player learns to prioritise them.
- [ ] **Stamina-based attack** — heavy weapons cost stamina to swing.
- [ ] **Push/kick** — shove a grabbing zombie back (costs stamina).
- [ ] **Fire** — molotovs, lighters + fuel; fire spreads and burns corpses.
- [ ] **More zombie variety** — bloater (ranged acid on death), runner
      variants, armoured soldier already in.

### World & exploration
- [ ] **Multi-floor buildings** — stairs up/down; rooftop access. Big render
      change (z-levels) but huge for gameplay.
- [ ] **Vehicle** — find keys, fuel, drive (run over zombies, but noise
      attracts). Large feature; maybe later.
- [ ] **NPC survivors** — friendly/ hostile, trade, rescue quests.
- [ ] **Weather** — rain (fills water collectors, slows), fog (reduced
      view), cold (need warmth).
- [ ] **More districts / landmarks** — police station (guns), gun store,
      pharmacy, gas station, warehouse.

### Meta / progression
- [ ] **Skills** — fitness (stamina), strength (carry/melee), aiming
      (ranged accuracy), cooking, first-aid. Level up by doing.
- [ ] **Traits / occupation** at character creation (PZ-style).
- [ ] **Time-of-day events** — horde migrations at dusk, helicopter event.
- [ ] **Settings panel** — volume, difficulty, key rebinds, map size,
      save in-game (not just autosave).
- [ ] **Achievements / stats** — longest survival, kills, days survived.

### Polish
- [ ] Minimap.
- [ ] Damage direction indicator + low-health vignette.
- [ ] Tile/set transitions (grass→road edges) for nicer look.
- [ ] Footstep/heartbeat already in; add breath sounds when running,
      door-banging when zombies attack barricades.
- [ ] Controller support? (low priority — keyboard+mouse is the target).

---

## 📁 Repo / packaging
- [ ] Add a `CHANGELOG.md`.
- [ ] Add CI: run `qmllint` (note: this qmllint doesn't understand inline
      `component` — filter that one warning) + a brace-balance check so the
      corruption that crept in last time can't recur.
- [ ] Tag a `v0.1.0` release once the above "game wouldn't load" class of
      bugs are confirmed in-game.
- [ ] Submit to the Omarchy plugin marketplace per its process.