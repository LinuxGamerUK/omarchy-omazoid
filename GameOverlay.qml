// GameOverlay.qml — Main game overlay (fullscreen)
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtMultimedia
import qs.Commons
import "js/Utils.js" as Utils
import "js/World.js" as World
import "js/Items.js" as Items
import "js/Entities.js" as Entities
import "js/Render.js" as Render

Item {
    id: root

    // ─── Lifecycle ───
    property bool opened: false
    property string omarchyPath: Quickshell.env("OMARCHY_PATH")
    property string saveDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/com.github.LinuxGamerUK.Omazoid/saves"
    property string saveFile: saveDir + "/save.json"
    property bool saveExists: false
    property bool saveChecked: false

    // ─── Game state ───
    property string gameState: "menu" // menu, playing, paused, dead, inventory
    property var world: null
    property var player: null
    property var zombies: []
    property var projectiles: []
    property var zombieProjectiles: []
    property var effects: []
    property var groundItems: []
    property var noiseEvents: []
    property var barricades: ({})   // "x,y" -> {recipeId,tile,base,hp,maxHp,blocks,damagePerSecond}
    property int gameDay: 1
    property real gameHour: 8.0
    property bool permadeath: false
    property int killCount: 0
    property string deathCause: ""

    // ─── Input state ───
    property var keys: ({})
    property real mouseScreenX: 0
    property real mouseScreenY: 0
    property bool mouseDown: false
    property real zoom: 1.0  // 0.4 (zoomed out) to 3.0 (zoomed in)
    property real zoomChangedTimer: 0  // shows zoom indicator briefly after zooming

    // ─── Constants ───
    readonly property int tileSize: 32
    readonly property int mapW: 256
    readonly property int mapH: 256
    readonly property real playerSpeed: 120 // pixels per second
    readonly property real playerRunSpeed: 200
    readonly property int maxZombies: 80
    readonly property int spawnCheckInterval: 2000 // ms between spawn checks

    // ─── Timers ───
    property real lastSpawnCheck: 0
    property real gameTimeAccum: 0
    property real autoSaveTimer: 0
    readonly property real autoSaveInterval: 900 // 15 minutes in seconds

    // ─── Audio ───
    property bool audioMuted: false
    property real audioVolume: 0.5
    property real sfxVolume: 0.6
    property string currentAmbient: ""
    property real zombieGroanTimer: 0
    property real footstepTimer: 0  // footstep sound timing
    property real heartbeatTimer: 0

    // ─── Loot UI state ───
    property var lootContainer: null
    property var lootItems: []
    property int lootTileX: -1
    property int lootTileY: -1

    // ─── Status messages ───
    property string statusMessage: ""
    property real statusMessageTimer: 0

    // ════════════════════════════════════════════════
    // Lifecycle functions
    // ════════════════════════════════════════════════

    function open(payload) {
        root.opened = true
        if (!saveChecked) checkSaveFile()
        gameCanvas.requestPaint()
        // Grab keyboard focus — critical for keyboard input to work
        Qt.callLater(function() { keyFocus.forceActiveFocus() })
        // Restart game timer and ambient if a game is in progress
        if (gameState === "playing" || gameState === "paused" || gameState === "inventory" || gameState === "looting") {
            gameTimer.running = true
            Qt.callLater(function() { root.startAmbient() })
        }
    }

    function close() {
        if (gameState === "playing") {
            saveGame()
        }
        root.opened = false
        gameTimer.running = false
        stopAmbient()
    }

    function checkSaveFile() {
        saveChecked = true
        // Run via a shell so `&&` actually short-circuits; passing it as a raw
        // arg to `test` always failed, so `saveExists` stayed false and the
        // Continue button never appeared on the start menu.
        checkSaveProc.command = ["bash", "-c", "test -f '" + saveFile + "' && echo EXISTS"]
        checkSaveProc.running = true
    }

    function showMessage(msg) {
        statusMessage = msg
        statusMessageTimer = 3.0
    }

    // ════════════════════════════════════════════════
    // New game / load game
    // ════════════════════════════════════════════════

    function newGame(mode) {
        permadeath = (mode === "permadeath")
        var seed = Math.floor(Math.random() * 2147483647)
        world = World.generateWorld(seed, mapW, mapH)

        player = {
            x: world.spawnX * tileSize + tileSize / 2,
            y: world.spawnY * tileSize + tileSize / 2,
            tileX: world.spawnX, tileY: world.spawnY,
            health: 100, maxHealth: 100,
            hunger: 50, thirst: 50, stamina: 100, maxStamina: 100,
            facing: 0, walkPhase: 0, attackPhase: 0,
            moving: false, running: false,
            inventory: [],
            equippedWeapon: null,
            equippedAmmo: { pistol_ammo: 0, shotgun_ammo: 0, rifle_ammo: 0 },
            hasFlashlight: false,
            infected: false,
            infectionProgress: 0,
            infectedTime: 0
        }

        // Starting items
        player.inventory.push({ id: "water_bottle", count: 2 })
        player.inventory.push({ id: "bandage", count: 2 })
        player.inventory.push({ id: "kitchen_knife", count: 1 })
        equipWeapon("kitchen_knife")
        _refreshPlayer()  // Ensure inventory is visible from the start

        zombies = []
        projectiles = []
        zombieProjectiles = []
        effects = []
        groundItems = []
        noiseEvents = []
        barricades = ({})
        gameDay = 1
        gameHour = 8.0
        killCount = 0
        deathCause = ""
        gameTimeAccum = 0
        autoSaveTimer = 0
        gameState = "playing"
        gameTimer.running = true
        gameCanvas.requestPaint()
    }

    function loadGame() {
        loadProc.command = ["cat", saveFile]
        loadProc.running = true
    }

    function onLoadComplete(jsonStr) {
        try {
            var data = JSON.parse(jsonStr)
            if (!data || !data.world) {
                showMessage("Save file corrupted!")
                return
            }

            // Rebuild world from seed + changes
            world = World.generateWorld(data.world.seed, data.world.width, data.world.height)
            world.changes = data.world.changes || {}
            world.containers = data.world.containers || {}

            player = data.player
            if (!player.equippedWeapon && player.equippedWeaponId) {
                equipWeapon(player.equippedWeaponId)
            }

            zombies = data.zombies || []
            projectiles = []
            zombieProjectiles = []
            effects = []
            groundItems = data.groundItems || []
            noiseEvents = []
            barricades = data.barricades || ({})
            gameDay = data.gameDay || 1
            gameHour = data.gameHour || 8.0
            permadeath = data.permadeath || false
            killCount = data.killCount || 0
            deathCause = ""
            gameTimeAccum = 0
            autoSaveTimer = 0
            gameState = "playing"
            gameTimer.running = true
            gameCanvas.requestPaint()
            showMessage("Game loaded - Day " + gameDay)
        } catch (e) {
            showMessage("Failed to load save: " + e)
        }
    }

    // ════════════════════════════════════════════════
    // Save game
    // ════════════════════════════════════════════════

    function saveGame() {
        if (!world || !player || gameState !== "playing") return

        var data = {
            world: World.serialize(world),
            player: _serializePlayer(player),
            zombies: zombies,
            groundItems: groundItems,
            barricades: barricades,
            gameDay: gameDay,
            gameHour: gameHour,
            permadeath: permadeath,
            killCount: killCount
        }

        var jsonStr = JSON.stringify(data)
        // Escape for shell
        var escaped = jsonStr.replace(/'/g, "'\\''")
        saveProc.command = ["bash", "-c", "mkdir -p '" + saveDir + "'; printf '%s' '" + escaped + "' > '" + saveFile + "'"]
        saveProc.running = true
        autoSaveTimer = 0
    }

    function _serializePlayer(p) {
        var copy = {}
        for (var k in p) {
            if (typeof p[k] !== 'function') copy[k] = p[k]
        }
        // Store equipped weapon ID for reload
        copy.equippedWeaponId = p.equippedWeapon ? p.equippedWeapon.id : null
        copy.equippedWeapon = null // Don't serialize the object, just the ID
        return copy
    }

    // ════════════════════════════════════════════════
    // Player helpers (functions attached to player object)
    // ════════════════════════════════════════════════

    function equipWeapon(weaponId) {
        var w = Items.getItem(weaponId)
        if (w && Items.isWeapon(w)) {
            // Clone the def so per-instance durability doesn't mutate the shared
            // Items.WEAPONS table (otherwise breaking one bat breaks every bat
            // you find for the rest of the run).
            var copy = {}
            for (var k in w) copy[k] = w[k]
            player.equippedWeapon = copy
            _refreshPlayer()
            showMessage("Equipped: " + w.name)
        }
    }

    function useItem(itemId) {
        var item = Items.getItem(itemId)
        if (!item) return

        if (item.cat === Items.CAT.FOOD) {
            player.hunger = Utils.clamp(player.hunger + item.hunger, 0, 100)
            if (item.thirst) player.thirst = Utils.clamp(player.thirst + item.thirst, 0, 100)
            _removeFromInventory(itemId, 1)
            playSfx(sfxEat)
            showMessage("Ate " + item.name)
        } else if (item.cat === Items.CAT.DRINK) {
            player.thirst = Utils.clamp(player.thirst + item.thirst, 0, 100)
            if (item.hunger) player.hunger = Utils.clamp(player.hunger + item.hunger, 0, 100)
            _removeFromInventory(itemId, 1)
            playSfx(sfxEat)
            showMessage("Drank " + item.name)
        } else if (item.cat === Items.CAT.MEDICAL) {
            if (item.curesInfection && player.infected) {
                player.infected = false
                player.infectionProgress = 0
                showMessage("Infection cured!")
            } else if (item.healing) {
                player.health = Utils.clamp(player.health + item.healing, 0, player.maxHealth)
                showMessage("Used " + item.name + " (+" + item.healing + " HP)")
            }
            _removeFromInventory(itemId, 1)
        } else if (item.cat === Items.CAT.TOOL) {
            if (itemId === "flashlight") {
                player.hasFlashlight = !player.hasFlashlight
                _refreshPlayer()
                showMessage(player.hasFlashlight ? "Flashlight ON" : "Flashlight OFF")
            }
        } else if (Items.isWeapon(item)) {
            equipWeapon(itemId)
        }
    }

    // Force QML to detect inventory/player changes by creating a new object reference.
    // Without this, property var mutations (push, splice, count +=) are invisible to QML bindings.
    function _refreshPlayer() {
        if (!player) return
        var p = {}
        for (var k in player) {
            if (typeof player[k] !== 'function') p[k] = player[k]
        }
        p.inventory = player.inventory.slice()
        player = p
    }

    function _removeFromInventory(itemId, count) {
        for (var i = 0; i < player.inventory.length; i++) {
            if (player.inventory[i].id === itemId) {
                player.inventory[i].count -= count
                if (player.inventory[i].count <= 0) {
                    player.inventory.splice(i, 1)
                }
                _refreshPlayer()
                return
            }
        }
    }

    // Count of a given item id currently in the player's inventory (0 if none).
    function _invCount(itemId) {
        if (!player) return 0
        for (var i = 0; i < player.inventory.length; i++) {
            if (player.inventory[i].id === itemId) return player.inventory[i].count
        }
        return 0
    }

    function _addToInventory(itemId, count) {
        count = count || 1
        var item = Items.getItem(itemId)
        if (item && item.stackable) {
            for (var i = 0; i < player.inventory.length; i++) {
                if (player.inventory[i].id === itemId) {
                    player.inventory[i].count += count
                    _refreshPlayer()
                    return
                }
            }
        }
        player.inventory.push({ id: itemId, count: count })
        _refreshPlayer()
    }

    function getInventoryWeight() {
        if (!player) return 0
        var w = 0
        for (var i = 0; i < player.inventory.length; i++) {
            var item = Items.getItem(player.inventory[i].id)
            if (item) w += (item.weight || 0) * player.inventory[i].count
        }
        return Math.round(w * 10) / 10
    }

    // ════════════════════════════════════════════════
    // Combat
    // ════════════════════════════════════════════════

    function playerAttack() {
        if (!player || !player.equippedWeapon) {
            player.equippedWeapon = Items.WEAPONS["fists"]
        }
        if (player.attackPhase > 0) return // Already attacking

        var weapon = player.equippedWeapon
        player.attackPhase = 0.01

        if (Items.isRangedWeapon(weapon)) {
            _fireRangedWeapon(weapon)
        } else {
            _swingMeleeWeapon(weapon)
            playSfx(getSwingSound(weapon))
        }

        // Create noise event
        noiseEvents.push({
            x: player.x, y: player.y,
            radius: weapon.noise * 5,
            intensity: weapon.noise,
            age: 0
        })
    }

    function _swingMeleeWeapon(weapon) {
        var attackRange = weapon.range
        var attackAngle = 0.6 // ~35 degree arc

        for (var i = 0; i < zombies.length; i++) {
            var z = zombies[i]
            if (z.state === "dead" || z.state === "corpse") continue

            var dx = z.x - player.x
            var dy = z.y - player.y
            var d = Math.sqrt(dx * dx + dy * dy)

            if (d <= attackRange) {
                var angle = Math.atan2(dy, dx)
                var diff = Utils.angleDiff(player.facing, angle)
                if (Math.abs(diff) < attackAngle) {
                    var result = Entities.playerAttackZombie(player, z, weapon)
                    if (result.killed) {
                        killCount++
                        _createBloodEffect(z.x, z.y, 8)
                        playSfx(sfxZombieDeath)
                        playSfx(getHitSound(weapon))
                    } else {
                        _createBloodEffect(z.x, z.y, 3)
                        playSfx(getHitSound(weapon))
                    }
                }
            }
        }

        // Reduce weapon durability
        if (weapon.durability > 0) {
            weapon.durability--
            if (weapon.durability <= 0) {
                showMessage(weapon.name + " broke!")
                player.equippedWeapon = Items.WEAPONS["fists"]
            }
        }
    }

    function _fireRangedWeapon(weapon) {
        var ammoType = weapon.ammoType
        // Ammo lives in the inventory (loot adds it there); draw from it directly
        // so picked-up ammo is actually usable. The legacy equippedAmmo tracker
        // was only ever decremented, never refilled, so guns could never fire.
        if (_invCount(ammoType) <= 0) {
            showMessage("No ammo!")
            player.attackPhase = 0
            return
        }

        _removeFromInventory(ammoType, 1)
        playSfx(sfxGunshot)

        if (weapon.id === "shotgun") {
            // Multiple pellets with spread
            for (var i = 0; i < (weapon.pellets || 5); i++) {
                var spread = (Utils.randFloat(-1, 1)) * (weapon.spread || 0.3)
                projectiles.push({
                    x: player.x, y: player.y,
                    vx: Math.cos(player.facing + spread) * 600,
                    vy: Math.sin(player.facing + spread) * 600,
                    damage: weapon.damage,
                    life: 0.5
                })
            }
        } else {
            projectiles.push({
                x: player.x, y: player.y,
                vx: Math.cos(player.facing) * 800,
                vy: Math.sin(player.facing) * 800,
                damage: weapon.damage,
                life: 0.8
            })
        }
    }

    function _createBloodEffect(x, y, particles) {
        var parts = []
        for (var i = 0; i < particles; i++) {
            parts.push({
                x: Utils.randFloat(-8, 8),
                y: Utils.randFloat(-8, 8),
                size: Utils.randFloat(1, 3),
                alpha: 0.8,
                vx: Utils.randFloat(-30, 30),
                vy: Utils.randFloat(-30, 30)
            })
        }
        effects.push({ type: "blood", x: x, y: y, particles: parts, life: 0.5 })

        // Blood decals are transient only — don't persist in world.changes
        // (prevents unbounded memory growth in long sessions)
    }

    // ════════════════════════════════════════════════
    // Looting
    // ════════════════════════════════════════════════

    function tryInteract() {
        if (!player || !world) return

        var ptx = Math.floor(player.x / tileSize)
        var pty = Math.floor(player.y / tileSize)

        // 1. Check for doors first (4 adjacent tiles) — toggle open/closed
        var doorOffsets = [[1,0],[-1,0],[0,1],[0,-1]]
        for (var d = 0; d < doorOffsets.length; d++) {
            var dx = ptx + doorOffsets[d][0]
            var dy = pty + doorOffsets[d][1]
            if (World.isDoor(world, dx, dy)) {
                var opened = World.toggleDoor(world, dx, dy)
                if (opened === true) {
                    playSfx(sfxDoorOpen)
                    showMessage("Door opened")
                } else if (opened === false) {
                    playSfx(sfxDoorClose)
                    showMessage("Door closed")
                }
                return
            }
        }

        // 1.5. Check for zombie corpses (8 adjacent tiles) — search for loot
        var corpseOffsets = [[0,0],[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]]
        for (var co = 0; co < corpseOffsets.length; co++) {
            var ctx2 = ptx + corpseOffsets[co][0]
            var cty2 = pty + corpseOffsets[co][1]
            for (var zi = 0; zi < zombies.length; zi++) {
                var zc = zombies[zi]
                if (zc.state !== "corpse") continue
                var ztx = Math.floor(zc.x / tileSize)
                var zty = Math.floor(zc.y / tileSize)
                if (ztx === ctx2 && zty === cty2) {
                    if (zc.loot && zc.loot.length > 0 && !zc.looted) {
                        lootContainer = zc
                        lootItems = zc.loot.slice()
                        gameState = "looting"
                        gameTimer.running = false
                        gameCanvas.requestPaint()
                        return
                    } else if (!zc.looted) {
                        zc.looted = true
                        showMessage("Nothing useful on the body")
                        return
                    }
                }
            }
        }

        // 2. Check for containers adjacent to player (8 tiles)
        var offsets = [[0,0],[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]]
        for (var i = 0; i < offsets.length; i++) {
            var tx = ptx + offsets[i][0]
            var ty = pty + offsets[i][1]
            if (World.isContainer(world, tx, ty)) {
                var container = World.getContainer(world, tx, ty)
                if (container && !container.looted) {
                    lootContainer = container
                    lootTileX = tx
                    lootTileY = ty
                    var dist = World.getDistrictAt(world, tx, ty)
                    var quality = 1
                    if (dist) {
                        var distDef = World.DISTRICTS[dist.type]
                        quality = distDef.lootQuality
                    }
                    lootItems = Items.generateLoot(quality, World.getTile(world, tx, ty), dist ? dist.type : "RESIDENTIAL")
                    gameState = "looting"
                    gameTimer.running = false
                    gameCanvas.requestPaint()
                    return
                } else if (container && container.looted) {
                    showMessage("Already looted")
                    return
                }
            }
        }

        // 3. Check for ground items
        for (var j = 0; j < groundItems.length; j++) {
            var gi = groundItems[j]
            var d = Utils.dist(player.x, player.y, gi.x, gi.y)
            if (d < 30) {
                _addToInventory(gi.id, gi.count)
                var item = Items.getItem(gi.id)
                playSfx(sfxPickup)
                showMessage("Picked up " + (item ? item.name : gi.id))
                groundItems.splice(j, 1)
                return
            }
        }
    }

    function takeLootItem(index) {
        if (index < 0 || index >= lootItems.length) return
        var item = lootItems[index]
        _addToInventory(item.id, item.count)
        var itemDef = Items.getItem(item.id)
        playSfx(sfxPickup)
        showMessage("Looted " + (itemDef ? itemDef.name : item.id))
        lootItems.splice(index, 1)
    }

    function takeAllLoot() {
        for (var i = 0; i < lootItems.length; i++) {
            _addToInventory(lootItems[i].id, lootItems[i].count)
        }
        lootItems = []
    }

    function closeLoot() {
        if (lootContainer) {
            lootContainer.looted = true
        }
        lootContainer = null
        lootItems = []
        lootTileX = -1
        lootTileY = -1
        if (gameState === "looting") {
            gameState = "playing"
            gameTimer.running = true
            gameCanvas.requestPaint()
        }
    }

    // ════════════════════════════════════════════════
    // Zombie spawning
    // ════════════════════════════════════════════════

    function trySpawnZombies() {
        if (zombies.length >= maxZombies) return
        if (!world || !player) return

        var nf = Utils.nightFactor(gameHour)
        var ptx = Math.floor(player.x / tileSize)
        var pty = Math.floor(player.y / tileSize)
        var dist = World.getDistrictAt(world, ptx, pty)
        if (!dist) return

        var distDef = World.DISTRICTS[dist.type]
        if (!distDef) return

        // More zombies at night
        var spawnChance = distDef.zombieDensity * (0.3 + nf * 0.7)

        if (Math.random() > spawnChance * 0.1) return

        // Spawn off-screen but within range
        var angle = Utils.randFloat(0, Math.PI * 2)
        var distance = Utils.randFloat(350, 600) // Just outside view
        var sx = player.x + Math.cos(angle) * distance
        var sy = player.y + Math.sin(angle) * distance

        // Make sure spawn point is walkable
        var stx = Math.floor(sx / tileSize)
        var sty = Math.floor(sy / tileSize)
        if (!World.isWalkable(world, stx, sty)) return

        // Pick zombie type from district
        var zType = Utils.randChoice(distDef.zombieTypes)
        var zDef = Entities.ZOMBIE_TYPES[zType]
        if (!zDef) zType = "walker"

        var count = Utils.randInt(zDef.minGroup || 1, zDef.maxGroup || 1)
        Entities.spawnZombieGroup(zombies, zType, sx, sy, count)
    }

    // ════════════════════════════════════════════════
    // Game loop
    // ════════════════════════════════════════════════

    function gameTick() {
        // Keep ambient music alive during all game states
        checkAmbientSwitch()

        if (gameState !== "playing") {
            return  // No repaint needed — paint is requested on state change
        }

        var dt = 0.033 // ~30 FPS, fixed timestep

        // Game time is updated in _updateGameTime (24 game hours = 1 real hour)
        _updateGameTime(dt)
        _updatePlayer(dt)
        _updateZombies(dt)
        _updateProjectiles(dt)
        _updateZombieProjectiles(dt)
        _updateEffects(dt)
        _updateNoiseEvents(dt)
        _updateBarricades(dt)
        _updateStats(dt)

        // Audio: ambient switching, zombie groans, heartbeat
        checkAmbientSwitch()
        _updateZombieGroans(dt)
        _updateHeartbeat(dt)

        // Zombie spawning
        lastSpawnCheck += dt * 1000
        if (lastSpawnCheck >= spawnCheckInterval / 1000) {
            lastSpawnCheck = 0
            trySpawnZombies()
        }

        // Clean up dead zombies and cap corpse count — prevents memory accumulation.
        // cleanupDead() removes any "dead"-state zombies and trims the oldest
        // corpses once there are more than 40, so long sessions don't leak.
        if (zombies.length > 0) {
            zombies = Entities.cleanupDead(zombies)
        }

        // Auto-save
        autoSaveTimer += dt
        if (autoSaveTimer >= autoSaveInterval) {
            saveGame()
            showMessage("Auto-saved")
        }

        // Status message timer
        if (statusMessageTimer > 0) {
            statusMessageTimer -= dt
            if (statusMessageTimer <= 0) statusMessage = ""
        }

        // Zoom indicator timer
        if (zoomChangedTimer > 0) {
            zoomChangedTimer -= dt
            if (zoomChangedTimer < 0) zoomChangedTimer = 0
        }

        // Check death
        if (player.health <= 0) {
            _onPlayerDeath("killed by zombies")
        }

        gameCanvas.requestPaint()
    }

    function _updateGameTime(dt) {
        // 24 game hours = 1 real hour => 24/3600 game hours per real second
        gameHour += (24.0 / 3600.0) * dt

        if (gameHour >= 24) {
            gameHour -= 24
            gameDay++
            playSfx(sfxNewDay)
            showMessage("Day " + gameDay + " begins...")
        }
    }

    function _updatePlayer(dt) {
        if (!player) return

        // Movement input
        var mx = 0, my = 0
        if (keys[Qt.Key_W] || keys[Qt.Key_Up]) my -= 1
        if (keys[Qt.Key_S] || keys[Qt.Key_Down]) my += 1
        if (keys[Qt.Key_A] || keys[Qt.Key_Left]) mx -= 1
        if (keys[Qt.Key_D] || keys[Qt.Key_Right]) mx += 1

        // Normalize diagonal
        if (mx !== 0 && my !== 0) {
            mx *= 0.707
            my *= 0.707
        }

        player.moving = (mx !== 0 || my !== 0)
        player.running = (keys[Qt.Key_Shift] && player.stamina > 0 && player.moving)

        var speed = player.running ? playerRunSpeed : playerSpeed
        if (player.stamina <= 0) speed = playerSpeed * 0.5

        if (player.moving) {
            // Movement direction for body facing
            var moveAngle = Math.atan2(my, mx)

            // But facing should be towards mouse for aiming
            // In Project Zomboid, the character faces the mouse
            // Body rotates towards mouse, legs animate in movement direction
            // For simplicity, facing = mouse direction, walkPhase increments

            var dx = mx * speed * dt
            var dy = my * speed * dt

            // Collision detection
            _movePlayerWithCollision(dx, dy)

            player.walkPhase += dt * (player.running ? 12 : 8)

            // Footstep sounds — interval based on walk/run speed
            footstepTimer += dt
            var stepInterval = player.running ? 0.28 : 0.42
            if (footstepTimer >= stepInterval) {
                footstepTimer = 0
                var tile = World.getTile(world, player.tileX, player.tileY)
                playSfx(getFootstepSound(tile))
            }

            // Stamina drain when running
            if (player.running) {
                player.stamina = Utils.clamp(player.stamina - 25 * dt, 0, player.maxStamina)
            }
        } else {
            // Stamina regen
            player.stamina = Utils.clamp(player.stamina + 15 * dt, 0, player.maxStamina)
        }

        if (!player.running && player.moving) {
            player.stamina = Utils.clamp(player.stamina + 5 * dt, 0, player.maxStamina)
        }

        // Update facing to mouse direction
        var canvasW = gameCanvas.width
        var canvasH = gameCanvas.height
        var screenCenterX = canvasW / 2
        var screenCenterY = canvasH / 2
        player.facing = Math.atan2(mouseScreenY - screenCenterY, mouseScreenX - screenCenterX)

        // Update tile position
        player.tileX = Math.floor(player.x / tileSize)
        player.tileY = Math.floor(player.y / tileSize)

        // Attack phase animation
        if (player.attackPhase > 0) {
            var weapon = player.equippedWeapon || Items.WEAPONS["fists"]
            player.attackPhase += dt / weapon.attackSpeed
            if (player.attackPhase >= 1) {
                player.attackPhase = 0
            }
        }

        // Continuous attack while mouse held
        if (mouseDown && player.attackPhase <= 0) {
            playerAttack()
        }

        // Infection progression
        if (player.infected) {
            player.infectedTime += dt
            // Health slowly drains over game hours
            // Full progression over ~2 game days (48 game hours = 2 real hours)
            player.infectionProgress = Utils.clamp(player.infectedTime / 7200, 0, 1) // 2 hours real = 7200 seconds
            // Periodic health loss
            if (Math.random() < dt * 0.1) {
                player.health -= 1
            }
            // Fever increases thirst
            player.thirst = Utils.clamp(player.thirst - 2 * dt, 0, 100)
        }
    }

    function _movePlayerWithCollision(dx, dy) {
        var r = 10 // player collision radius

        // Try X movement
        var newX = player.x + dx
        var tileX = Math.floor(newX / tileSize)
        var tileYN = Math.floor((player.y - r) / tileSize)
        var tileYS = Math.floor((player.y + r) / tileSize)
        if (World.isWalkable(world, tileX, tileYN) && World.isWalkable(world, tileX, tileYS)) {
            player.x = newX
        }

        // Try Y movement
        var newY = player.y + dy
        var tileY2 = Math.floor(newY / tileSize)
        var tileXW = Math.floor((player.x - r) / tileSize)
        var tileXE = Math.floor((player.x + r) / tileSize)
        if (World.isWalkable(world, tileXW, tileY2) && World.isWalkable(world, tileXE, tileY2)) {
            player.y = newY
        }

        // Clamp to map bounds
        player.x = Utils.clamp(player.x, tileSize, (mapW - 1) * tileSize)
        player.y = Utils.clamp(player.y, tileSize, (mapH - 1) * tileSize)
    }

    function _updateZombies(dt) {
        Entities.setNightFactor(Utils.nightFactor(gameHour))
        var newZombies = []

        for (var i = 0; i < zombies.length; i++) {
            var z = zombies[i]
            // Keep corpses in the array (don't run AI on them)
            if (z.state === "corpse") {
                newZombies.push(z)
                continue
            }
            if (z.state === "dead") continue

            var result = Entities.updateZombie(z, player, world, dt, zombies, noiseEvents)

            // Check if zombie attacked player
            if (result && result.type === "attack") {
                _onZombieAttackPlayer(z, result)
            } else if (result && result.type === "spit") {
                // Spitter lobbed an acid spit — track it as a hostile projectile
                zombieProjectiles.push({
                    x: result.x, y: result.y,
                    vx: result.vx, vy: result.vy,
                    damage: result.damage,
                    life: 2.5
                })
            }

            newZombies.push(z)
        }

        zombies = newZombies
    }

    function _onZombieAttackPlayer(zombie, result) {
        var def = Entities.ZOMBIE_TYPES[zombie.type]
        player.health -= result.damage

        // Blood effect on player
        _createBloodEffect(player.x, player.y, 4)
        playSfx(sfxHurt)

        // Check for bite/scratch
        var attackResult = Entities.zombieAttackPlayer(zombie, player)

        if (attackResult.bitten) {
            if (!player.infected && Entities.rollInfection(true, false)) {
                player.infected = true
                player.infectedTime = 0
                showMessage("You were bitten! Infection risk!")
            } else if (!player.infected) {
                showMessage("You were bitten!")
            }
        } else if (attackResult.scratched) {
            if (!player.infected && Entities.rollInfection(false, true)) {
                player.infected = true
                player.infectedTime = 0
                showMessage("You were scratched! Infection risk!")
            } else if (!player.infected) {
                showMessage("You were scratched!")
            }
        }
    }

    function _updateProjectiles(dt) {
        var newProjs = []
        for (var i = 0; i < projectiles.length; i++) {
            var p = projectiles[i]
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.life -= dt

            if (p.life <= 0) continue

            // Check collision with zombies
            var hit = false
            for (var j = 0; j < zombies.length; j++) {
                var z = zombies[j]
                if (z.state === "dead" || z.state === "corpse") continue
                if (Utils.dist(p.x, p.y, z.x, z.y) < 14) {
                    var result = Entities.playerAttackZombie(player, z, {
                        damage: p.damage, knockback: 3, cat: "ranged"
                    })
                    if (result.killed) {
                        killCount++
                        playSfx(sfxZombieDeath)
                        _createBloodEffect(z.x, z.y, 8)
                    } else {
                        _createBloodEffect(z.x, z.y, 3)
                        playSfx(sfxHitBlunt)
                    }
                    hit = true
                    break
                }
            }

            // Check collision with walls
            if (!hit) {
                var tx = Math.floor(p.x / tileSize)
                var ty = Math.floor(p.y / tileSize)
                if (!World.isWalkable(world, tx, ty)) {
                    hit = true
                }
            }

            if (!hit) newProjs.push(p)
        }
        projectiles = newProjs
    }

    // Hostile projectiles (spitter acid spit) — travel, hit the player or a wall.
    function _updateZombieProjectiles(dt) {
        var newProjs = []
        for (var i = 0; i < zombieProjectiles.length; i++) {
            var p = zombieProjectiles[i]
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.life -= dt
            if (p.life <= 0) continue

            // Hit the player?
            if (Utils.dist(p.x, p.y, player.x, player.y) < 12) {
                player.health -= p.damage
                _createBloodEffect(player.x, player.y, 4)
                playSfx(sfxHurt)
                // Acid spit carries a small chance of infection
                if (!player.infected && Utils.chance(0.1)) {
                    player.infected = true
                    player.infectedTime = 0
                    showMessage("Spit got in a wound! Infection risk!")
                }
                continue
            }

            // Hit a wall? (stop, don't pass through)
            var tx = Math.floor(p.x / tileSize)
            var ty = Math.floor(p.y / tileSize)
            if (!World.isWalkable(world, tx, ty)) continue

            newProjs.push(p)
        }
        zombieProjectiles = newProjs
    }

    // ════════════════════════════════════════════════
    // Crafting / fortification (build menu, B key)
    // ════════════════════════════════════════════════

    // List of recipe ids for the build menu's Repeater.
    function recipeIds() {
        return Object.keys(Items.RECIPES)
    }

    // Human-readable "have/need" summary for a recipe's materials.
    function recipeMaterials(recipeId) {
        var r = Items.RECIPES[recipeId]
        if (!r) return ""
        var parts = []
        for (var mat in r.materials) {
            var def = Items.getItem(mat)
            var name = def ? def.name : mat
            parts.push(name + " " + _invCount(mat) + "/" + r.materials[mat])
        }
        return parts.join("  ·  ")
    }

    function canCraft(recipeId) {
        var r = Items.RECIPES[recipeId]
        if (!r) return false
        for (var mat in r.materials) {
            if (_invCount(mat) < r.materials[mat]) return false
        }
        return true
    }

    // Build a recipe on the tile directly in front of the player (facing dir).
    function tryBuild(recipeId) {
        if (!player || !world) return
        var r = Items.RECIPES[recipeId]
        if (!r) return
        if (!canCraft(recipeId)) {
            showMessage("Not enough materials for " + r.name)
            return
        }

        var fx = Math.round(Math.cos(player.facing))
        var fy = Math.round(Math.sin(player.facing))
        var tx = player.tileX + fx
        var ty = player.tileY + fy
        if (tx < 0 || ty < 0 || tx >= mapW || ty >= mapH) return

        var current = World.getTile(world, tx, ty)
        // Build on walkable ground, or reinforce a door/window. Never on walls,
        // containers, or an already-fortified tile.
        if (!World.WALKABLE[current] && current !== World.T.DOOR && current !== World.T.WINDOW) {
            showMessage("Can't build there")
            return
        }
        if (barricades[tx + "," + ty]) {
            showMessage("Already fortified there")
            return
        }

        // Consume materials
        for (var mat in r.materials) {
            _removeFromInventory(mat, r.materials[mat])
        }

        // Place the tile and track its health (record the underlying tile so
        // destruction reverts the map cleanly).
        barricades[tx + "," + ty] = {
            recipeId: recipeId,
            tile: r.tile,
            base: current,
            hp: r.hp,
            maxHp: r.hp,
            blocks: r.blocks,
            damagePerSecond: r.damagePerSecond || 0
        }
        World.setTile(world, tx, ty, r.tile)
        playSfx(sfxPickup)  // TODO: dedicated hammer/build SFX
        showMessage("Built " + r.name)
        gameCanvas.requestPaint()
    }

    function _removeBarricade(tx, ty) {
        var key = tx + "," + ty
        var b = barricades[key]
        if (!b) return
        World.setTile(world, tx, ty, b.base)
        delete barricades[key]
    }

    // Zombies beat down solid barricades; barbed wire shreds zombies walking
    // through it (and wears out as it does). Destroyed fortifications revert
    // to the underlying tile.
    function _updateBarricades(dt) {
        if (!player || !world) return
        var toRemove = []
        for (var key in barricades) {
            var b = barricades[key]
            var parts = key.split(",")
            var bx = parseInt(parts[0], 10)
            var by = parseInt(parts[1], 10)
            var cx = bx * tileSize + tileSize / 2
            var cy = by * tileSize + tileSize / 2

            if (b.tile === World.T.BARBED_WIRE) {
                for (var i = 0; i < zombies.length; i++) {
                    var z = zombies[i]
                    if (z.state === "dead" || z.state === "corpse") continue
                    if (Math.floor(z.x / tileSize) === bx && Math.floor(z.y / tileSize) === by) {
                        z.health -= b.damagePerSecond * dt
                        z.hitFlash = Math.max(z.hitFlash, 0.3)
                        b.hp -= 5 * dt
                        if (z.health <= 0 && z.state !== "corpse") {
                            z.state = "corpse"
                            z.loot = Entities.generateCorpseLoot(z.type)
                            z.looted = false
                            killCount++
                            _createBloodEffect(z.x, z.y, 6)
                            playSfx(sfxZombieDeath)
                        }
                    }
                }
            } else {
                // Solid barricade: adjacent chasing/attacking zombies smash it.
                for (var j = 0; j < zombies.length; j++) {
                    var z2 = zombies[j]
                    if (z2.state === "dead" || z2.state === "corpse") continue
                    if (z2.state !== "chase" && z2.state !== "attack") continue
                    if (Utils.dist(z2.x, z2.y, cx, cy) < 34 && z2.attackCooldown <= 0) {
                        var def = Entities.ZOMBIE_TYPES[z2.type]
                        z2.attackCooldown = def ? def.attackSpeed : 1.0
                        b.hp -= def ? def.damage : 8
                        z2.facing = Utils.angleTo(z2.x, z2.y, cx, cy)
                    }
                }
            }

            if (b.hp <= 0) toRemove.push([bx, by])
        }
        for (var k = 0; k < toRemove.length; k++) {
            _removeBarricade(toRemove[k][0], toRemove[k][1])
        }
    }

    function _updateEffects(dt) {
        var newEffects = []
        for (var i = 0; i < effects.length; i++) {
            var e = effects[i]
            e.life -= dt
            if (e.life <= 0) continue

            if (e.type === "blood") {
                for (var j = 0; j < e.particles.length; j++) {
                    var p = e.particles[j]
                    p.x += p.vx * dt
                    p.y += p.vy * dt
                    p.vx *= 0.9
                    p.vy *= 0.9
                    p.alpha = e.life / 0.5 * 0.8
                }
            }
            newEffects.push(e)
        }
        effects = newEffects
    }

    function _updateNoiseEvents(dt) {
        var newEvents = []
        for (var i = 0; i < noiseEvents.length; i++) {
            var ev = noiseEvents[i]
            ev.age += dt
            if (ev.age < 0.5) newEvents.push(ev) // Noise events last 0.5 seconds
        }
        noiseEvents = newEvents
    }

    function _updateZombieGroans(dt) {
        if (audioMuted || !player) return
        zombieGroanTimer += dt
        if (zombieGroanTimer < 1.5) return  // Check every 1.5 seconds (was 3)
        zombieGroanTimer = 0

        var nearby = 0
        var closestDist = 9999
        for (var i = 0; i < zombies.length; i++) {
            if (zombies[i].state === "dead" || zombies[i].state === "corpse") continue
            var d = Utils.dist(player.x, player.y, zombies[i].x, zombies[i].y)
            if (d < 300) {
                nearby++
                if (d < closestDist) closestDist = d
            }
        }
        if (nearby === 0) return

        var distFactor = Math.max(0, 1 - closestDist / 300)
        var chance = Math.min(0.12 * nearby * distFactor, 0.6)
        if (Math.random() < chance) {
            var grumbles = [sfxGrumble1, sfxGrumble2, sfxGrumble3, sfxGroan]
            playSfx(grumbles[Math.floor(Math.random() * grumbles.length)])
        }
    }

    function _updateHeartbeat(dt) {
        if (audioMuted || !player) return
        if (player.health > 30) {
            heartbeatTimer = 0
            return
        }
        heartbeatTimer += dt
        // Heartbeat rate increases as health decreases
        var rate = 1.2 - (30 - player.health) / 30 * 0.5  // 1.2s at 30hp, 0.7s at 0hp
        if (heartbeatTimer >= rate) {
            heartbeatTimer = 0
            playSfx(sfxHeartbeat)
        }
    }

    function _updateStats(dt) {
        if (!player) return

        // Hunger increases over time
        // Full hunger bar to empty in ~2 game days (48 game hours = 2 real hours)
        // Rate: 100 / 7200 seconds = 0.0139 per second
        player.hunger = Utils.clamp(player.hunger - 0.0139 * dt, 0, 100)

        // Thirst increases faster
        // Full thirst to empty in ~1.5 game days
        // Rate: 100 / 5400 seconds = 0.0185 per second
        player.thirst = Utils.clamp(player.thirst - 0.0185 * dt, 0, 100)

        // Health drain from starvation/dehydration
        if (player.hunger <= 0) {
            player.health -= 2 * dt
        }
        if (player.thirst <= 0) {
            player.health -= 3 * dt
        }

        // Slow health regen if well fed and hydrated
        if (player.hunger > 50 && player.thirst > 50 && player.health < player.maxHealth && !player.infected) {
            player.health = Utils.clamp(player.health + 0.5 * dt, 0, player.maxHealth)
        }
    }

    function _onPlayerDeath(cause) {
        deathCause = cause
        gameState = "dead"
        gameTimer.running = false
        stopAmbient()

        if (permadeath) {
            // Delete save file
            deleteSaveProc.command = ["rm", "-f", saveFile]
            deleteSaveProc.running = true
            saveExists = false
        }

        gameCanvas.requestPaint()
    }

    // ════════════════════════════════════════════════
    // Processes
    // ════════════════════════════════════════════════

    Process {
        id: checkSaveProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                saveExists = String(text).indexOf("EXISTS") >= 0
            }
        }
        onExited: {
            // If no file, the command fails but that's fine
        }
    }

    Process {
        id: loadProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.onLoadComplete(String(text || ""))
            }
        }
    }

    Process { id: saveProc }
    Process { id: deleteSaveProc }
    Process { id: wsProc }  // Hyprland workspace dispatch
    Process { id: floatProc }  // Toggle floating mode for game window

    // ════════════════════════════════════════════════
    // Audio system — ambient music + SFX
    // ════════════════════════════════════════════════

    property string audioDir: Qt.resolvedUrl("audio/")

    // Ambient background player (loops continuously)
    MediaPlayer {
        id: ambientPlayer
        source: audioDir + "ambient_day.ogg"
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput {
            id: ambientOutput
            volume: root.audioMuted ? 0 : root.audioVolume * 0.35
        }
        onSourceChanged: { if (root.gameState === "playing") ambientPlayer.play() }
    }

    // SFX players — one per sound for instant playback
    SoundEffect { id: sfxSwing;      source: audioDir + "sfx_swing.wav";         volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxHit;        source: audioDir + "sfx_hit.wav";           volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxGunshot;    source: audioDir + "sfx_gunshot.wav";       volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxDoorOpen;   source: audioDir + "sfx_door_open.wav";    volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxDoorClose;  source: audioDir + "sfx_door_close.wav";   volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxPickup;     source: audioDir + "sfx_pickup.wav";       volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxEat;        source: audioDir + "sfx_eat.wav";          volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxHurt;       source: audioDir + "sfx_hurt.wav";         volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxHeartbeat;  source: audioDir + "sfx_heartbeat.wav";    volume: root.audioMuted ? 0 : root.sfxVolume * 0.7 }
    SoundEffect { id: sfxGroan;      source: audioDir + "sfx_zombie_groan.wav";  volume: root.audioMuted ? 0 : root.sfxVolume * 0.5 }
    SoundEffect { id: sfxNewDay;     source: audioDir + "sfx_newday.wav";       volume: root.audioMuted ? 0 : root.sfxVolume * 0.6 }
    SoundEffect { id: sfxClick;      source: audioDir + "sfx_click.wav";        volume: root.audioMuted ? 0 : root.sfxVolume * 0.4 }

    // Footstep sounds (per surface type)
    SoundEffect { id: sfxStepGrass;    source: audioDir + "sfx_step_grass.wav";    volume: root.audioMuted ? 0 : root.sfxVolume * 0.3 }
    SoundEffect { id: sfxStepRoad;     source: audioDir + "sfx_step_road.wav";     volume: root.audioMuted ? 0 : root.sfxVolume * 0.3 }
    SoundEffect { id: sfxStepWood;     source: audioDir + "sfx_step_wood.wav";     volume: root.audioMuted ? 0 : root.sfxVolume * 0.3 }
    SoundEffect { id: sfxStepConcrete; source: audioDir + "sfx_step_concrete.wav"; volume: root.audioMuted ? 0 : root.sfxVolume * 0.3 }

    // Weapon-specific swing sounds
    SoundEffect { id: sfxSwingBlade;   source: audioDir + "sfx_swing_blade.wav";   volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxSwingBlunt;   source: audioDir + "sfx_swing_blunt.wav";    volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxSwingMetal;   source: audioDir + "sfx_swing_metal.wav";    volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxSwingFist;    source: audioDir + "sfx_swing_fist.wav";     volume: root.audioMuted ? 0 : root.sfxVolume * 0.6 }

    // Weapon-specific hit sounds
    SoundEffect { id: sfxHitBlade;    source: audioDir + "sfx_hit_blade.wav";     volume: root.audioMuted ? 0 : root.sfxVolume }
    SoundEffect { id: sfxHitBlunt;    source: audioDir + "sfx_hit_blunt.wav";     volume: root.audioMuted ? 0 : root.sfxVolume }

    // Zombie grumbles (3 variants for atmosphere)
    SoundEffect { id: sfxGrumble1;    source: audioDir + "sfx_zombie_grumble1.wav"; volume: root.audioMuted ? 0 : root.sfxVolume * 0.4 }
    SoundEffect { id: sfxGrumble2;    source: audioDir + "sfx_zombie_grumble2.wav"; volume: root.audioMuted ? 0 : root.sfxVolume * 0.4 }
    SoundEffect { id: sfxGrumble3;    source: audioDir + "sfx_zombie_grumble3.wav"; volume: root.audioMuted ? 0 : root.sfxVolume * 0.4 }

    // Zombie death sound
    SoundEffect { id: sfxZombieDeath; source: audioDir + "sfx_zombie_death.wav";  volume: root.audioMuted ? 0 : root.sfxVolume * 0.6 }

    // Helper: get weapon-appropriate swing sound
    function getSwingSound(weapon) {
        if (!weapon || weapon.id === "fists") return sfxSwingFist
        var blade = ["kitchen_knife", "machete"]
        var metal = ["crowbar", "frying_pan"]
        if (blade.indexOf(weapon.id) >= 0) return sfxSwingBlade
        if (metal.indexOf(weapon.id) >= 0) return sfxSwingMetal
        return sfxSwingBlunt  // baseball_bat, hammer, axe
    }

    // Helper: get weapon-appropriate hit sound
    function getHitSound(weapon) {
        if (!weapon) return sfxHitBlunt
        var blade = ["kitchen_knife", "machete", "axe"]
        if (blade.indexOf(weapon.id) >= 0) return sfxHitBlade
        return sfxHitBlunt
    }

    // Helper: get footstep sound based on tile type
    function getFootstepSound(tileType) {
        // Grass, dirt, flower, farmland
        if (tileType === 0 || tileType === 41 || tileType === 42 || tileType === 12) return sfxStepGrass
        // Road, sidewalk, asphalt, gravel, sand
        if (tileType === 1 || tileType === 29 || tileType === 40 || tileType === 10 || tileType === 11) return sfxStepRoad
        // Wood floor
        if (tileType === 2) return sfxStepWood
        // Concrete, floor tile, pavement
        if (tileType === 3 || tileType === 39 || tileType === 31) return sfxStepConcrete
        return sfxStepGrass  // default
    }

    function playSfx(sfx) {
        if (audioMuted) return
        if (sfx) sfx.play()
    }

    function startAmbient() {
        if (audioMuted) return
        var nf = Utils.nightFactor(gameHour)
        var track = nf > 0.5 ? "ambient_night" : "ambient_day"
        if (currentAmbient !== track) {
            currentAmbient = track
            ambientPlayer.source = audioDir + track + ".ogg"
        }
        // Always ensure it's playing
        if (ambientPlayer.playbackState !== MediaPlayer.PlayingState) {
            ambientPlayer.play()
        }
    }

    function stopAmbient() {
        if (ambientPlayer.playbackState === MediaPlayer.PlayingState) {
            ambientPlayer.stop()
        }
        currentAmbient = ""
    }

    // Called from game tick — keeps ambient playing and switches day/night
    function checkAmbientSwitch() {
        if (audioMuted) return
        // Run during any active game state (not menu/dead)
        if (gameState === "menu" || gameState === "dead") return
        var nf = Utils.nightFactor(gameHour)
        var track = nf > 0.5 ? "ambient_night" : "ambient_day"
        if (currentAmbient !== track) {
            currentAmbient = track
            ambientPlayer.source = audioDir + track + ".ogg"
            ambientPlayer.play()
        }
        // Watchdog: ensure ambient is actually playing
        if (ambientPlayer.playbackState !== MediaPlayer.PlayingState) {
            ambientPlayer.play()
        }
    }

    // ════════════════════════════════════════════════
    // Game loop timer
    // ════════════════════════════════════════════════

    Timer {
        id: gameTimer
        interval: 33 // ~30 FPS
        repeat: true
        running: false
        onTriggered: root.gameTick()
    }

    // Ambient music watchdog — ensures ambient keeps playing at all times
    // Runs independently of the game loop so music survives pauses/menus
    Timer {
        id: ambientWatchdog
        interval: 2000 // check every 2 seconds
        repeat: true
        running: root.opened && root.gameState !== "menu" && root.gameState !== "dead" && !root.audioMuted
        onTriggered: root.checkAmbientSwitch()
    }

    // Focus is managed by Hyprland with OnDemand keyboard focus.
    // We only grab focus on open() and mouse click — no periodic watchdog
    // so Hyprland shortcuts (Super+1, etc.) always work.

    // Focus watchdog — removed to allow Hyprland shortcuts to work.
    // With WlrKeyboardFocus.OnDemand, Hyprland manages keyboard focus.
    // The game gets focus when the user clicks on it; Hyprland shortcuts
    // (Super+key) are always intercepted by the compositor first.

    // Game surface — 90% of screen (not fullscreen)
    // ════════════════════════════════════════════════

    FloatingWindow {
        id: overlay
        visible: root.opened
        title: "Omazoid"
        implicitWidth: 2300
        implicitHeight: 1440
        color: "#000000"
        minimumSize: Qt.size(800, 600)

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(function() { keyFocus.forceActiveFocus() })
                if (gameState === "playing") {
                    gameTimer.running = true
                    startAmbient()
                }
                // Make the game window float (not tile) and center it
                Qt.callLater(function() {
                    floatProc.command = ["bash", "-c",
                        "hyprctl dispatch togglefloating title:Omazoid 2>/dev/null; " +
                        "sleep 0.1; " +
                        "hyprctl dispatch centerwindow 2>/dev/null"]
                    floatProc.running = true
                })
            }
        }

        // Focus Item: handles ALL keyboard input
        // In Wayland/Quickshell, key events go to the item with active focus,
        // not the PanelWindow itself. This Item fills the screen and grabs focus.
        Item {
            id: keyFocus
            anchors.fill: parent
            focus: true

            // Grab focus once when the overlay opens.
            // No periodic re-grabbing — let Hyprland manage focus with OnDemand.
            // User clicks on the game to regain focus after switching workspaces.
            Component.onCompleted: {
                if (root.opened) forceActiveFocus()
            }

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
                // ─── Hyprland shortcut passthrough ───
                // When the overlay has keyboard focus, Hyprland's keybindings may not
                // fire on the same monitor. We handle them here as a fallback.
                // If Hyprland already processed the shortcut, this handler never fires.

                // Super+1-0 → switch to workspace 1-10
                if ((event.modifiers & Qt.MetaModifier) && event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                    var ws = event.key === Qt.Key_0 ? 10 : event.key - Qt.Key_0
                    wsProc.command = ["hyprctl", "dispatch", "workspace", String(ws)]
                    wsProc.running = true
                    event.accepted = true
                    return
                }

                // Super+W or Super+Q → close the game (like closing a window)
                if ((event.modifiers & Qt.MetaModifier) && (event.key === Qt.Key_W || event.key === Qt.Key_Q)) {
                    root.close()
                    event.accepted = true
                    return
                }

                // Super+Tab → next workspace
                if ((event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_Tab) {
                    wsProc.command = ["hyprctl", "dispatch", "workspace", "e+1"]
                    wsProc.running = true
                    event.accepted = true
                    return
                }

                // Super+Shift+Tab → previous workspace
                if ((event.modifiers & Qt.MetaModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_Backtab) {
                    wsProc.command = ["hyprctl", "dispatch", "workspace", "e-1"]
                    wsProc.running = true
                    event.accepted = true
                    return
                }

                // Super+Enter → open terminal
                if ((event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_Return) {
                    wsProc.command = ["omarchy-default-terminal"]
                    wsProc.running = true
                    event.accepted = true
                    return
                }

                // Super+Escape → system menu (let Hyprland handle if possible)
                if ((event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_Escape) {
                    event.accepted = false  // Let Hyprland handle this one
                    return
                }

                // Emergency exit: Ctrl+Q always quits, no matter what
                if ((event.key === Qt.Key_Q) && (event.modifiers & Qt.ControlModifier)) {
                    root.close()
                    event.accepted = true
                    return
                }

                root.keys[event.key] = true

                if (event.key === Qt.Key_Escape) {
                    if (root.gameState === "playing") {
                        root.gameState = "paused"
                        root.gameTimer.running = false
                        root.saveGame()
                        root.gameCanvas.requestPaint()
                    } else if (root.gameState === "paused" || root.gameState === "inventory" || root.gameState === "looting" || root.gameState === "building") {
                        root.gameState = "playing"
                        root.closeLoot()
                        root.gameTimer.running = true
                        root.gameCanvas.requestPaint()
                    } else if (root.gameState === "menu" || root.gameState === "dead") {
                        root.close()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_E) {
                    if (root.gameState === "playing") root.tryInteract()
                    event.accepted = true
                } else if (event.key === Qt.Key_I) {
                    if (root.gameState === "playing") {
                        root.gameState = "inventory"
                        root.gameTimer.running = false
                        root.gameCanvas.requestPaint()
                    } else if (root.gameState === "inventory") {
                        root.gameState = "playing"
                        root.gameTimer.running = true
                        root.gameCanvas.requestPaint()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab) {
                    if (root.gameState === "playing") {
                        root.gameState = "inventory"
                        root.gameTimer.running = false
                        root.gameCanvas.requestPaint()
                    } else if (root.gameState === "inventory") {
                        root.gameState = "playing"
                        root.gameTimer.running = true
                        root.gameCanvas.requestPaint()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_B) {
                    if (root.gameState === "playing") {
                        root.gameState = "building"
                        root.gameTimer.running = false
                        root.gameCanvas.requestPaint()
                    } else if (root.gameState === "building") {
                        root.gameState = "playing"
                        root.gameTimer.running = true
                        root.gameCanvas.requestPaint()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_F) {
                    if (root.gameState === "playing") {
                        root.useItem("flashlight")
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_M) {
                    root.audioMuted = !root.audioMuted
                    if (root.audioMuted) {
                        root.stopAmbient()
                    } else if (root.gameState !== "menu" && root.gameState !== "dead") {
                        root.startAmbient()
                    }
                    root.showMessage(root.audioMuted ? "Audio muted" : "Audio on")
                    event.accepted = true
                }
            }

            Keys.onReleased: function(event) {
                root.keys[event.key] = false
            }
        }

        // ─── Emergency quit button (always mouse-clickable) ───
        Rectangle {
            visible: root.opened
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8
            width: quitMouse.containsMouse ? 90 : 32
            height: 32
            radius: 6
            color: quitMouse.containsMouse ? "#cc3333" : "#66000000"
            z: 9999

            Text {
                anchors.centerIn: parent
                text: quitMouse.containsMouse ? "✕ Quit" : "✕"
                color: "#ffffff"
                font.pixelSize: 14
                font.bold: true
            }

            MouseArea {
                id: quitMouse
                anchors.fill: parent
                hoverEnabled: true
                z: 9999
                onClicked: root.close()
            }
        }

        // ─── Game canvas ───
        Canvas {
            id: gameCanvas
            anchors.fill: parent
            renderStrategy: Canvas.Threaded

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var w = gameCanvas.width
                var h = gameCanvas.height

                // Clear
                ctx.fillStyle = "#000000"
                ctx.fillRect(0, 0, w, h)

                if (root.gameState === "menu") {
                    _drawMenuBackground(ctx, w, h)
                    return
                }

                if (!root.world || !root.player) return

                // Zoom-adjusted view dimensions (world space visible on screen)
                var viewW = w / root.zoom
                var viewH = h / root.zoom

                // Camera centered on player (in world coordinates)
                var camX = root.player.x - viewW / 2
                var camY = root.player.y - viewH / 2

                var nf = Utils.nightFactor(root.gameHour)

                // Apply zoom transform — everything inside this block is in world space
                // and gets scaled to screen space by the canvas transform
                ctx.save()
                ctx.scale(root.zoom, root.zoom)

                // Draw world (pass zoom-adjusted view dimensions)
                Render.drawWorld(ctx, root.world, camX, camY, viewW, viewH, root.tileSize, nf, root.player)

                // Draw ground items (cull to visible area)
                for (var i = 0; i < root.groundItems.length; i++) {
                    var gi = root.groundItems[i]
                    if (gi.x < camX - 50 || gi.x > camX + viewW + 50) continue
                    if (gi.y < camY - 50 || gi.y > camY + viewH + 50) continue
                    Render.drawGroundItem(ctx, gi, camX, camY, root.tileSize)
                }

                // Draw zombies (sorted by Y for depth, cull to visible area)
                var visibleZombies = []
                for (var z = 0; z < root.zombies.length; z++) {
                    var zb = root.zombies[z]
                    if (zb.state === "dead") continue
                    if (zb.x < camX - 50 || zb.x > camX + viewW + 50) continue
                    if (zb.y < camY - 50 || zb.y > camY + viewH + 50) continue
                    visibleZombies.push(zb)
                }
                visibleZombies.sort(function(a, b) { return a.y - b.y })
                for (var zi = 0; zi < visibleZombies.length; zi++) {
                    Render.drawZombie(ctx, visibleZombies[zi], camX, camY, nf)
                }

                // Draw player at center of zoom-adjusted view
                Render.drawPlayer(ctx, viewW / 2, viewH / 2, root.player.facing,
                    root.player.walkPhase, root.player.attackPhase,
                    root.player.equippedWeapon, root.player.moving)

                // Draw projectiles
                for (var pi = 0; pi < root.projectiles.length; pi++) {
                    Render.drawProjectile(ctx, root.projectiles[pi], camX, camY)
                }

                // Draw zombie spit projectiles
                for (var zpi = 0; zpi < root.zombieProjectiles.length; zpi++) {
                    Render.drawZombieProjectile(ctx, root.zombieProjectiles[zpi], camX, camY)
                }

                // Draw effects
                for (var ei = 0; ei < root.effects.length; ei++) {
                    Render.drawBloodEffect(ctx, root.effects[ei], camX, camY)
                }

                // Draw health bars on damaged fortifications
                for (var bkey in root.barricades) {
                    var bb = root.barricades[bkey]
                    if (bb.hp >= bb.maxHp) continue
                    var bparts = bkey.split(",")
                    var bhpX = parseInt(bparts[0], 10) * root.tileSize + root.tileSize/2 - camX
                    var bhpY = parseInt(bparts[1], 10) * root.tileSize - 6 - camY
                    Render.drawHealthBar(ctx, bhpX, bhpY, 20, bb.hp / bb.maxHp)
                }

                // Restore — back to screen space for UI elements
                ctx.restore()

                // Draw interaction prompt in screen coordinates (unscaled for readable text)
                if (root.gameState === "playing") {
                    _drawInteractionHint(ctx, w, h, camX, camY)
                }
            }

            function _drawMenuBackground(ctx, w, h) {
                // Dark gradient background
                var grad = ctx.createRadialGradient(w/2, h/2, 50, w/2, h/2, w)
                grad.addColorStop(0, "#1a1a2e")
                grad.addColorStop(1, "#0a0a0a")
                ctx.fillStyle = grad
                ctx.fillRect(0, 0, w, h)

                // Scattered "blood" splatters
                for (var i = 0; i < 15; i++) {
                    var x = (i * 137.5) % w
                    var y = (i * 73.3) % h
                    ctx.fillStyle = "rgba(80, 15, 15, 0.3)"
                    ctx.beginPath()
                    ctx.arc(x, y, 20 + (i % 10) * 5, 0, Math.PI * 2)
                    ctx.fill()
                }
            }

            function _drawInteractionHint(ctx, w, h, camX, camY) {
                // Convert world coordinates to screen coordinates (accounting for zoom)
                var z = root.zoom
                var ptx = Math.floor(root.player.x / root.tileSize)
                var pty = Math.floor(root.player.y / root.tileSize)

                // 1. Check for doors first (4 adjacent)
                var doorOffsets = [[1,0],[-1,0],[0,1],[0,-1]]
                for (var d = 0; d < doorOffsets.length; d++) {
                    var dx = ptx + doorOffsets[d][0]
                    var dy = pty + doorOffsets[d][1]
                    if (World.isDoor(root.world, dx, dy)) {
                        var dsx = (dx * root.tileSize + root.tileSize/2 - camX) * z
                        var dsy = (dy * root.tileSize - 10 - camY) * z
                        var label = World.isDoorOpen(root.world, dx, dy) ? "[E] Close door" : "[E] Open door"
                        Render.drawInteractionPrompt(ctx, dsx, dsy, label)
                        return
                    }
                }

                // 1.5. Check for zombie corpses (8 adjacent)
                var corpseOffs = [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]]
                for (var co = 0; co < corpseOffs.length; co++) {
                    var cx2 = ptx + corpseOffs[co][0]
                    var cy2 = pty + corpseOffs[co][1]
                    for (var zi = 0; zi < root.zombies.length; zi++) {
                        var zc = root.zombies[zi]
                        if (zc.state !== "corpse") continue
                        var ztx = Math.floor(zc.x / root.tileSize)
                        var zty = Math.floor(zc.y / root.tileSize)
                        if (ztx === cx2 && zty === cy2) {
                            if (zc.loot && zc.loot.length > 0 && !zc.looted) {
                                var csx = (zc.x - camX) * z
                                var csy = (zc.y - 20 - camY) * z
                                Render.drawInteractionPrompt(ctx, csx, csy, "[E] Search corpse")
                                return
                            }
                        }
                    }
                }

                // 2. Check for containers (8 adjacent)
                var offsets = [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]]
                for (var i = 0; i < offsets.length; i++) {
                    var tx = ptx + offsets[i][0]
                    var ty = pty + offsets[i][1]
                    if (World.isContainer(root.world, tx, ty)) {
                        var container = World.getContainer(root.world, tx, ty)
                        if (container && !container.looted) {
                            var sx = (tx * root.tileSize + root.tileSize/2 - camX) * z
                            var sy = (ty * root.tileSize - 10 - camY) * z
                            Render.drawInteractionPrompt(ctx, sx, sy, "[E] Search")
                            return
                        }
                    }
                }

                // 3. Check ground items
                for (var j = 0; j < root.groundItems.length; j++) {
                    var gi = root.groundItems[j]
                    if (Utils.dist(root.player.x, root.player.y, gi.x, gi.y) < 40) {
                        var gsx = (gi.x - camX) * z
                        var gsy = (gi.y - 20 - camY) * z
                        Render.drawInteractionPrompt(ctx, gsx, gsy, "[E] Pick up")
                        return
                    }
                }
            }
        }

        // ─── Mouse input ───
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            visible: root.opened && root.gameState === "playing"
            enabled: root.opened && root.gameState === "playing"
            // Don't steal keyboard focus from the keyFocus item
            focus: false

            onPositionChanged: function(mouse) {
                root.mouseScreenX = mouse.x
                root.mouseScreenY = mouse.y
            }

            onPressed: function(mouse) {
                root.mouseDown = true
                if (mouse.button === Qt.LeftButton && root.gameState === "playing") {
                    root.playerAttack()
                }
                // Re-grab keyboard focus after mouse click
                keyFocus.forceActiveFocus()
            }

            onReleased: {
                root.mouseDown = false
            }

            onWheel: function(wheel) {
                // Zoom in/out with mouse scroll
                if (wheel.angleDelta.y > 0) {
                    root.zoom = Math.min(3.0, root.zoom + 0.15)
                } else {
                    root.zoom = Math.max(0.4, root.zoom - 0.15)
                }
                root.zoomChangedTimer = 1.5  // show indicator for 1.5 seconds
                gameCanvas.requestPaint()
            }
        }

        // ════════════════════════════════════════════════
        // HUD
        // ════════════════════════════════════════════════

        // Top bar: clock, day, kills
        Rectangle {
            visible: root.gameState === "playing" || root.gameState === "paused"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 40
            color: "#aa000000"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 24

                Text {
                    text: "🧟 Omazoid"
                    color: "#dd5555"
                    font.pixelSize: 18
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Day " + root.gameDay
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: Utils.gameHoursToTimeString(root.gameHour)
                    color: root.gameHour > 19 || root.gameHour < 6 ? "#8888cc" : "#ffdd55"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Kills: " + root.killCount
                    color: "#aaaaaa"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: parent.width - 400; height: 1 } 
            }
        }

        // Bottom-left: Health/Hunger/Thirst/Stamina bars
        Column {
            visible: root.gameState === "playing"
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 16
            spacing: 6

            // Infection indicator (green, above stat bars)
            Text {
                visible: root.player && root.player.infected
                text: "☣ INFECTED (" + Math.round(root.player ? root.player.infectionProgress * 100 : 0) + "%)"
                color: "#33dd55"
                font.pixelSize: 14
                font.bold: true
                style: Text.Outline
                styleColor: "#000000"
            }

            // Health
            StatBar {
                label: "HP"
                value: root.player ? root.player.health : 0
                maxValue: root.player ? root.player.maxHealth : 100
                color: "#dd3333"
                width: 180
            }

            // Hunger
            StatBar {
                label: "Food"
                value: root.player ? root.player.hunger : 0
                maxValue: 100
                color: "#dd9933"
                width: 180
            }

            // Thirst
            StatBar {
                label: "Water"
                value: root.player ? root.player.thirst : 0
                maxValue: 100
                color: "#3399dd"
                width: 180
            }

            // Stamina
            StatBar {
                label: "Stam"
                value: root.player ? root.player.stamina : 0
                maxValue: root.player ? root.player.maxStamina : 100
                color: "#33dd55"
                width: 180
            }
        }

        // Bottom-right: weapon info
        Rectangle {
            visible: root.gameState === "playing"
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 16
            width: weaponCol.implicitWidth + 24
            height: weaponCol.implicitHeight + 16
            color: "#aa000000"
            radius: 6

            Column {
                id: weaponCol
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: root.player && root.player.equippedWeapon ?
                        root.player.equippedWeapon.name : "Bare Fists"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    text: {
                        if (!root.player || !root.player.equippedWeapon) return ""
                        var w = root.player.equippedWeapon
                        if (w.cat === "ranged") {
                            var ammo = root._invCount(w.ammoType)
                            return "Ammo: " + ammo
                        }
                        if (w.durability > 0) return "Durability: " + w.durability
                        return ""
                    }
                    color: "#aaaaaa"
                    font.pixelSize: 12
                }
            }
        }

        // Status message
        Text {
            visible: root.statusMessage !== "" && (root.gameState === "playing" || root.gameState === "paused")
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 80
            text: root.statusMessage
            color: "#ffdd55"
            font.pixelSize: 16
            font.bold: true
            style: Text.Outline
            styleColor: "#000000"
        }

        // Zoom level indicator (shows briefly when zooming)
        Text {
            id: zoomIndicator
            visible: root.zoomChangedTimer > 0 && root.gameState === "playing"
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: 70
            anchors.rightMargin: 16
            text: "🔍 " + Math.round(root.zoom * 100) + "%"
            color: "#aaaaaa"
            font.pixelSize: 13
            font.bold: true
            style: Text.Outline
            styleColor: "#000000"
        }

        // ════════════════════════════════════════════════
        // Start Menu
        // ════════════════════════════════════════════════

        Rectangle {
            id: startMenu
            visible: root.gameState === "menu" && root.opened
            anchors.fill: parent
            color: "#ee0a0a0a"

            Column {
                anchors.centerIn: parent
                spacing: 24

                Text {
                    text: "OMAZOID"
                    color: "#dd3333"
                    font.pixelSize: 72
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    style: Text.Outline
                    styleColor: "#330000"
                }

                Text {
                    text: "How long can you survive?"
                    color: "#888888"
                    font.pixelSize: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item { width: 1; height: 20 }

                // Continue button (only if save exists)
                MenuButton {
                    text: "Continue"
                    visible: root.saveExists
                    onClicked: root.loadGame()
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // New Game - Permadeath
                MenuButton {
                    text: "New Game — Permadeath"
                    subtext: "When you die, that's it. One life. No respawns."
                    onClicked: root.newGame("permadeath")
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // New Game - Respawn
                MenuButton {
                    text: "New Game — Respawn"
                    subtext: "Death sends you back to your last save."
                    onClicked: root.newGame("respawn")
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item { width: 1; height: 10 }

                Text {
                    text: "WASD: Move | Mouse: Aim | Click: Attack | Scroll: Zoom\nE: Interact/Doors | I: Inventory | F: Flashlight | M: Mute\nShift: Run | Esc: Pause | Super+W: Quit | Super+1-0: Workspace"
                    color: "#666666"
                    font.pixelSize: 13
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // ════════════════════════════════════════════════
        // Pause Menu
        // ════════════════════════════════════════════════

        Rectangle {
            visible: root.gameState === "paused"
            anchors.fill: parent
            color: "#cc000000"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "PAUSED"
                    color: "#ffffff"
                    font.pixelSize: 48
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Day " + root.gameDay + " | " + Utils.gameHoursToTimeString(root.gameHour) + " | Kills: " + root.killCount
                    color: "#aaaaaa"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item { width: 1; height: 10 }

                MenuButton {
                    text: "Resume"
                    onClicked: {
                        root.gameState = "playing"
                        root.gameTimer.running = true
                        root.gameCanvas.requestPaint()
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                MenuButton {
                    text: "Hide Game"
                    subtext: "Pause and free your screen — click 🧟 Omazoid to resume"
                    onClicked: {
                        root.saveGame()
                        root.gameTimer.running = false
                        root.opened = false
                        root.stopAmbient()
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                MenuButton {
                    text: "Save & Quit"
                    onClicked: {
                        root.saveGame()
                        root.close()
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ════════════════════════════════════════════════
        // Death Screen
        // ════════════════════════════════════════════════

        Rectangle {
            visible: root.gameState === "dead"
            anchors.fill: parent
            color: "#dd0a0000"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "YOU DIED"
                    color: "#ff3333"
                    font.pixelSize: 72
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    style: Text.Outline
                    styleColor: "#000000"
                }

                Text {
                    text: "Survived " + root.gameDay + " days | " + root.killCount + " kills"
                    color: "#cccccc"
                    font.pixelSize: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Cause: " + root.deathCause
                    color: "#999999"
                    font.pixelSize: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item { width: 1; height: 20 }

                MenuButton {
                    text: root.permadeath ? "New Game" : "Respawn at Last Save"
                    onClicked: {
                        if (root.permadeath) {
                            root.gameState = "menu"
                        } else {
                            root.loadGame()
                        }
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                MenuButton {
                    text: "Main Menu"
                    onClicked: root.gameState = "menu"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ════════════════════════════════════════════════
        // Inventory Screen
        // ════════════════════════════════════════════════

        Rectangle {
            visible: root.gameState === "inventory"
            anchors.fill: parent
            color: "#dd000000"

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 600)
                height: Math.min(parent.height - 80, 500)
                color: "#222222"
                radius: 8
                border.color: "#444444"
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Text {
                        text: "INVENTORY"
                        color: "#ffffff"
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Text {
                        text: "Weight: " + root.getInventoryWeight() + " kg"
                        color: "#888888"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#444444"
                    }

                    // Character stats summary
                    Row {
                        spacing: 20

                        Text {
                            text: "Health: " + Math.round(root.player ? root.player.health : 0) + "/" + (root.player ? root.player.maxHealth : 100)
                            color: "#dd3333"
                            font.pixelSize: 14
                        }
                        Text {
                            text: "Food: " + Math.round(root.player ? root.player.hunger : 0)
                            color: "#dd9933"
                            font.pixelSize: 14
                        }
                        Text {
                            text: "Water: " + Math.round(root.player ? root.player.thirst : 0)
                            color: "#3399dd"
                            font.pixelSize: 14
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#444444"
                    }

                    // Item list
                    Flickable {
                        width: parent.width
                        height: parent.height - 200
                        clip: true
                        contentHeight: invCol.implicitHeight
                        interactive: true

                        Column {
                            id: invCol
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.player ? root.player.inventory.length : 0

                                Rectangle {
                                    width: invCol.width
                                    height: 44
                                    color: invMouse.containsMouse ? "#333333" : "#2a2a2a"
                                    radius: 4

                                    property var invItem: root.player ? root.player.inventory[index] : null
                                    property var itemDef: invItem ? Items.getItem(invItem.id) : null

                                    MouseArea {
                                        id: invMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (invItem) root.useItem(invItem.id)
                                        }
                                    }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        spacing: 10

                                        Text {
                                            text: itemDef ? itemDef.name : invItem ? invItem.id : "?"
                                            color: "#ffffff"
                                            font.pixelSize: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: invItem && invItem.count > 1 ? "x" + invItem.count : ""
                                            color: "#888888"
                                            font.pixelSize: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: itemDef ? (itemDef.cat || "") : ""
                                            color: "#666666"
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            if (!itemDef) return ""
                                            if (Items.isWeapon(itemDef)) return "Click to equip"
                                            if (itemDef.cat === "food" || itemDef.cat === "drink") return "Click to consume"
                                            if (itemDef.cat === "medical") return "Click to use"
                                            if (itemDef.cat === "tool") return "Click to toggle"
                                            return ""
                                        }
                                        color: "#666666"
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#444444"
                    }

                    Text {
                        text: "Press I or Tab to close | Click items to use/equip"
                        color: "#666666"
                        font.pixelSize: 12
                    }
                }
            }
        }

        // ════════════════════════════════════════════════
        // Loot Screen
        // ════════════════════════════════════════════════

        Rectangle {
            visible: root.gameState === "looting"
            anchors.fill: parent
            color: "#aa000000"

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 500)
                height: Math.min(parent.height - 80, 400)
                color: "#222222"
                radius: 8
                border.color: "#444444"
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Text {
                        text: "SEARCHING"
                        color: "#ffffff"
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Text {
                        text: lootItems.length > 0 ? "You found:" : "Nothing here..."
                        color: "#888888"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#444444"
                    }

                    // Loot item list — simple Column + Repeater (no Flickable)
                    // Flickable was consuming click events, and loot only has 1-4 items
                    Column {
                        id: lootCol
                        width: parent.width
                        height: Math.min(parent.height - 140, implicitHeight)
                        spacing: 4

                        Repeater {
                            model: root.lootItems.length

                            Rectangle {
                                width: lootCol.width
                                height: 40
                                color: lootMouse.containsMouse ? "#444466" : "#2a2a3a"
                                radius: 4
                                border.color: lootMouse.containsMouse ? "#666688" : "transparent"
                                border.width: 1

                                property var lootItem: root.lootItems[index]
                                property var lootDef: lootItem ? Items.getItem(lootItem.id) : null

                                MouseArea {
                                    id: lootMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.takeLootItem(index)
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    text: (lootDef ? lootDef.name : lootItem ? lootItem.id : "?") +
                                          (lootItem && lootItem.count > 1 ? " x" + lootItem.count : "")
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: lootMouse.containsMouse ? "Click to take" : ""
                                    color: "#888888"
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 12
                        anchors.right: parent.right

                        MenuButton {
                            text: "Take All"
                            small: true
                            onClicked: root.takeAllLoot()
                            visible: root.lootItems.length > 0
                        }

                        MenuButton {
                            text: "Close"
                            small: true
                            onClicked: root.closeLoot()
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════
        // Build Menu (B)
        // ════════════════════════════════════════════════
        Rectangle {
            visible: root.gameState === "building"
            anchors.fill: parent
            color: "#dd000000"

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 560)
                height: Math.min(parent.height - 80, 360)
                color: "#222222"
                radius: 8
                border.color: "#444444"
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Text {
                        text: "BUILD"
                        color: "#ffffff"
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Text {
                        text: "Aim with the mouse — the fortification is placed on the tile in front of you."
                        color: "#888888"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Rectangle { width: parent.width; height: 1; color: "#444444" }

                    Repeater {
                        model: root.recipeIds()

                        Rectangle {
                            width: parent ? parent.width : 0
                            height: 60
                            radius: 6
                            color: buildRowMouse.containsMouse ? "#333344" : "#2a2a33"
                            border.color: root.canCraft(modelData) ? "#5acf3a" : "#444444"
                            border.width: 1

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    text: Items.RECIPES[modelData] ? Items.RECIPES[modelData].name : modelData
                                    color: "#ffffff"
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                Text {
                                    text: root.recipeMaterials(modelData)
                                    color: root.canCraft(modelData) ? "#9adf4a" : "#cc6666"
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.canCraft(modelData) ? "Build ►" : "need materials"
                                color: root.canCraft(modelData) ? "#5acf3a" : "#666666"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: buildRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.tryBuild(modelData)
                            }
                        }
                    }

                    Item { width: 1; height: 8 }

                    Text {
                        text: "B or Esc to close"
                        color: "#666666"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════
    // Reusable components
    // ════════════════════════════════════════════════

    component StatBar: Rectangle {
        property string label: ""
        property real value: 0
        property real maxValue: 100
        property color barColor: "#dd3333"
        width: 180
        height: 20
        color: "#66000000"
        radius: 3

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, parent.value / parent.maxValue))
            color: parent.barColor
            radius: 3
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label + ": " + Math.round(parent.value)
            color: "#ffffff"
            font.pixelSize: 11
            font.bold: true
        }
    }

    component MenuButton: Rectangle {
        property string text: ""
        property string subtext: ""
        property bool small: false
        signal clicked()

        width: (small ? 120 : 320)
        height: subtext ? 56 : (small ? 36 : 44)
        color: mouseArea3.containsMouse ? "#333344" : "#222233"
        radius: 6
        border.color: mouseArea3.containsMouse ? "#666688" : "#333344"
        border.width: 1

        MouseArea {
            id: mouseArea3
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: parent.parent.text
                color: "#ffffff"
                font.pixelSize: small ? 14 : 18
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: parent.parent.subtext
                color: "#888888"
                font.pixelSize: 11
                visible: parent.parent.subtext !== ""
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
