// Entities.js — Zombie types, AI, combat resolution
.pragma library

.import "Utils.js" as Utils
.import "Items.js" as Items

// ─── Zombie types ───
var ZOMBIE_TYPES = {
    "walker": {
        id: "walker", name: "Walker",
        health: 40, speed: 0.8, damage: 8, attackRange: 22, attackSpeed: 1.0,
        detectionRange: 120, noiseSensitivity: 60,
        color: "#5a7a4a", skinColor: "#6b8b5b", size: 1.0,
        biteChance: 0.25, scratchChance: 0.35,
        minGroup: 1, maxGroup: 3
    },
    "runner": {
        id: "runner", name: "Runner",
        health: 30, speed: 2.5, damage: 10, attackRange: 22, attackSpeed: 0.7,
        detectionRange: 180, noiseSensitivity: 80,
        color: "#7a5a4a", skinColor: "#8b6b5b", size: 0.9,
        biteChance: 0.2, scratchChance: 0.3,
        minGroup: 1, maxGroup: 2
    },
    "brute": {
        id: "brute", name: "Brute",
        health: 120, speed: 0.5, damage: 25, attackRange: 28, attackSpeed: 1.5,
        detectionRange: 100, noiseSensitivity: 40,
        color: "#4a5a3a", skinColor: "#5b6b4b", size: 1.4,
        biteChance: 0.35, scratchChance: 0.4,
        minGroup: 1, maxGroup: 1
    },
    "crawler": {
        id: "crawler", name: "Crawler",
        health: 20, speed: 1.2, damage: 6, attackRange: 20, attackSpeed: 0.8,
        detectionRange: 90, noiseSensitivity: 50,
        color: "#5a6a5a", skinColor: "#6b7b6b", size: 0.7,
        biteChance: 0.3, scratchChance: 0.25,
        minGroup: 1, maxGroup: 4
    },
    "spitter": {
        id: "spitter", name: "Spitter",
        health: 25, speed: 0.6, damage: 12, attackRange: 150, attackSpeed: 2.0,
        detectionRange: 200, noiseSensitivity: 70,
        color: "#6a8a3a", skinColor: "#7b9b4b", size: 0.9,
        biteChance: 0.1, scratchChance: 0.15, ranged: true,
        minGroup: 1, maxGroup: 2
    },
    "screamer": {
        id: "screamer", name: "Screamer",
        health: 15, speed: 1.0, damage: 5, attackRange: 20, attackSpeed: 1.0,
        detectionRange: 250, noiseSensitivity: 100,
        color: "#8a7a5a", skinColor: "#9b8b6b", size: 0.8,
        biteChance: 0.15, scratchChance: 0.2, alerts: true, alertRange: 300,
        minGroup: 1, maxGroup: 1
    },
    "swarmer": {
        id: "swarmer", name: "Swarmer",
        health: 15, speed: 1.5, damage: 5, attackRange: 18, attackSpeed: 0.6,
        detectionRange: 140, noiseSensitivity: 70,
        color: "#5a5a4a", skinColor: "#6b6b5b", size: 0.7,
        biteChance: 0.2, scratchChance: 0.3,
        minGroup: 3, maxGroup: 8
    },
    "soldier": {
        id: "soldier", name: "Infected Soldier",
        health: 80, speed: 1.0, damage: 15, attackRange: 24, attackSpeed: 0.9,
        detectionRange: 130, noiseSensitivity: 60,
        color: "#4a4a3a", skinColor: "#5b5b4b", size: 1.1, armored: true,
        biteChance: 0.2, scratchChance: 0.3,
        minGroup: 1, maxGroup: 3
    }
};

// ─── Create a zombie ───
function createZombie(typeId, x, y) {
    var def = ZOMBIE_TYPES[typeId];
    if (!def) def = ZOMBIE_TYPES["walker"];
    return {
        type: typeId,
        x: x, y: y,
        vx: 0, vy: 0,
        health: def.health,
        maxHealth: def.health,
        state: "wander", // wander, chase, attack, dead
        facing: Utils.randFloat(0, Math.PI * 2),
        walkPhase: Utils.randFloat(0, Math.PI * 2),
        attackCooldown: 0,
        targetX: x + Utils.randFloat(-50, 50),
        targetY: y + Utils.randFloat(-50, 50),
        wanderTimer: Utils.randFloat(2, 6),
        alertTimer: 0,
        hitFlash: 0
    };
}

// Helper - will be called from GameOverlay with district info
function spawnZombieGroup(zombies, typeId, x, y, count) {
    var def = ZOMBIE_TYPES[typeId];
    if (!def) def = ZOMBIE_TYPES["walker"];
    
    for (var i = 0; i < count; i++) {
        var angle = (i / count) * Math.PI * 2 + Utils.randFloat(0, 0.5);
        var offset = Utils.randFloat(10, 30);
        var zx = x + Math.cos(angle) * offset;
        var zy = y + Math.sin(angle) * offset;
        zombies.push(createZombie(typeId, zx, zy));
    }
}

// ─── Update zombie AI ───
function updateZombie(zombie, player, world, dt, zombies, noiseEvents) {
    if (zombie.state === "dead" || zombie.state === "corpse") return;
    
    var def = ZOMBIE_TYPES[zombie.type];
    zombie.hitFlash = Math.max(0, zombie.hitFlash - dt * 5);
    zombie.attackCooldown = Math.max(0, zombie.attackCooldown - dt);
    zombie.walkPhase += dt * def.speed * 3;
    
    var dx = player.x - zombie.x;
    var dy = player.y - zombie.y;
    var distToPlayer = Math.sqrt(dx * dx + dy * dy);
    
    // Check noise events
    var attracted = false;
    if (noiseEvents && noiseEvents.length > 0) {
        for (var i = 0; i < noiseEvents.length; i++) {
            var event_1 = noiseEvents[i];
            var ndx = event_1.x - zombie.x;
            var ndy = event_1.y - zombie.y;
            var ndist = Math.sqrt(ndx * ndx + ndy * ndy);
            if (ndist < event_1.radius && event_1.intensity > def.noiseSensitivity) {
                zombie.state = "chase";
                zombie.targetX = event_1.x;
                zombie.targetY = event_1.y;
                zombie.alertTimer = 5.0;
                attracted = true;
                // Screamer alerts other zombies
                if (def.alerts && ndist < 50) {
                    alertNearbyZombies(zombies, zombie.x, zombie.y, def.alertRange);
                }
                break;
            }
        }
    }
    
    // Vision detection
    if (!attracted && distToPlayer < def.detectionRange) {
        // Night reduces detection range
        var detectRange = def.detectionRange * (1 - 0.3 * (1 - nightFactorForPlayer(player)));
        if (distToPlayer < detectRange) {
            zombie.state = "chase";
            zombie.targetX = player.x;
            zombie.targetY = player.y;
            zombie.alertTimer = 8.0;
        }
    }
    
    // State machine
    if (zombie.state === "chase") {
        zombie.alertTimer -= dt;
        if (zombie.alertTimer <= 0 && distToPlayer > def.detectionRange * 1.5) {
            zombie.state = "wander";
            zombie.wanderTimer = Utils.randFloat(2, 5);
        }
        
        if (distToPlayer < def.attackRange) {
            zombie.state = "attack";
        } else {
            // Move toward target
            var angle = Math.atan2(zombie.targetY - zombie.y, zombie.targetX - zombie.x);
            zombie.facing = angle;
            var speed = def.speed * 30; // pixels per second
            var moveX = Math.cos(angle) * speed * dt;
            var moveY = Math.sin(angle) * speed * dt;
            
            // Try move with collision
            moveZombieWithCollision(zombie, world, moveX, moveY);
        }
    }
    
    if (zombie.state === "attack") {
        if (distToPlayer > def.attackRange + 5) {
            zombie.state = "chase";
        } else if (zombie.attackCooldown <= 0) {
            // Attack player
            zombie.attackCooldown = def.attackSpeed;
            return { type: "attack", damage: def.damage, zombie: zombie };
        }
        // Face the player
        zombie.facing = Math.atan2(dy, dx);
    }
    
    if (zombie.state === "wander") {
        zombie.wanderTimer -= dt;
        if (zombie.wanderTimer <= 0) {
            zombie.targetX = zombie.x + Utils.randFloat(-80, 80);
            zombie.targetY = zombie.y + Utils.randFloat(-80, 80);
            zombie.wanderTimer = Utils.randFloat(3, 8);
        }
        
        var wdx = zombie.targetX - zombie.x;
        var wdy = zombie.targetY - zombie.y;
        var wdist = Math.sqrt(wdx * wdx + wdy * wdy);
        if (wdist > 5) {
            var wangle = Math.atan2(wdy, wdx);
            zombie.facing = wangle;
            var wspeed = def.speed * 15 * dt;
            moveZombieWithCollision(zombie, world, Math.cos(wangle) * wspeed, Math.sin(wangle) * wspeed);
        }
    }
    
    return null;
}

var _nightFactorCache = 1;
function setNightFactor(nf) { _nightFactorCache = nf; }
function nightFactorForPlayer(player) { return 1 - _nightFactorCache; }

function moveZombieWithCollision(zombie, world, dx, dy) {
    var tileSize = 32;
    var newX = zombie.x + dx;
    var newY = zombie.y + dy;
    
    // Check collision at new position
    var tileX = Math.floor(newX / tileSize);
    var tileY = Math.floor(newY / tileSize);
    
    if (!isSolidAt(world, tileX, tileY)) {
        zombie.x = newX;
        zombie.y = newY;
    } else {
        // Try sliding on one axis
        var tileX2 = Math.floor((zombie.x + dx) / tileSize);
        var tileY2 = Math.floor(zombie.y / tileSize);
        if (!isSolidAt(world, tileX2, tileY2)) {
            zombie.x = zombie.x + dx;
        }
        var tileX3 = Math.floor(zombie.x / tileSize);
        var tileY3 = Math.floor((zombie.y + dy) / tileSize);
        if (!isSolidAt(world, tileX3, tileY3)) {
            zombie.y = zombie.y + dy;
        }
    }
}

function isSolidAt(world, tileX, tileY) {
    if (tileX < 0 || tileY < 0 || tileX >= world.width || tileY >= world.height) return true;
    var key = tileX + "," + tileY;
    if (world.changes[key] !== undefined) {
        var t = world.changes[key];
        return !isWalkableType(t);
    }
    return !isWalkableType(world.tiles[tileY * world.width + tileX]);
}

function isWalkableType(t) {
    // Mirror World.WALKABLE
    var walkable = [0, 1, 2, 3, 43, 7, 12, 29, 39, 40, 41, 10, 11, 27, 28, 31, 42, 36, 38];
    return walkable.indexOf(t) >= 0;
}

function alertNearbyZombies(zombies, x, y, range) {
    for (var i = 0; i < zombies.length; i++) {
        var z = zombies[i];
        if (z.state === "dead" || z.state === "corpse") continue;
        var dx = z.x - x, dy = z.y - y;
        var d = Math.sqrt(dx * dx + dy * dy);
        if (d < range) {
            z.state = "chase";
            z.targetX = x;
            z.targetY = y;
            z.alertTimer = 10.0;
        }
    }
}

// ─── Combat: player attacks zombie ───
function playerAttackZombie(player, zombie, weapon) {
    if (!weapon) weapon = Items.WEAPONS["fists"];
    
    var def = ZOMBIE_TYPES[zombie.type];
    var damage = weapon.damage;
    
    // Armored zombies take reduced damage from melee
    if (def.armored && weapon.cat === Items.CAT.WEAPON_MELEE) {
        damage *= 0.5;
    }
    
    zombie.health -= damage;
    zombie.hitFlash = 1.0;
    zombie.state = "chase";
    zombie.targetX = player.x;
    zombie.targetY = player.y;
    zombie.alertTimer = 10.0;
    
    // Knockback
    var dx = zombie.x - player.x;
    var dy = zombie.y - player.y;
    var d = Math.sqrt(dx * dx + dy * dy);
    if (d > 0) {
        zombie.x += (dx / d) * weapon.knockback;
        zombie.y += (dy / d) * weapon.knockback;
    }
    
    if (zombie.health <= 0) {
        zombie.state = "corpse";
        zombie.loot = generateCorpseLoot(zombie.type);
        zombie.looted = false;
        return { killed: true, damage: damage };
    }
    
    return { killed: false, damage: damage };
}

// ─── Combat: zombie attacks player ───
function zombieAttackPlayer(zombie, player) {
    var def = ZOMBIE_TYPES[zombie.type];
    var result = {
        damage: def.damage,
        bitten: false,
        scratched: false
    };
    
    // Check for bite/scratch
    if (Utils.chance(def.biteChance)) {
        result.bitten = true;
    } else if (Utils.chance(def.scratchChance)) {
        result.scratched = true;
    }
    
    return result;
}

// ─── Infection ───
function rollInfection(bitten, scratched) {
    if (bitten) return Utils.chance(0.85);
    if (scratched) return Utils.chance(0.15);
    return false;
}

// ─── Get district at position (standalone) ───
function getDistrictAtSafe(world, tileX, tileY) {
    if (!world.districts) return null;
    for (var i = 0; i < world.districts.length; i++) {
        var d = world.districts[i];
        if (tileX >= d.x && tileX < d.x + d.w && tileY >= d.y && tileY < d.y + d.h)
            return d;
    }
    return null;
}

// ─── Corpse loot generation ───
// Each zombie type has different loot chances
var CORPSE_LOOT = {
    "walker":   { chance: 0.10, minItems: 1, maxItems: 1, quality: 1 },
    "runner":   { chance: 0.15, minItems: 1, maxItems: 1, quality: 2 },
    "brute":    { chance: 0.25, minItems: 1, maxItems: 2, quality: 2 },
    "crawler":  { chance: 0.05, minItems: 1, maxItems: 1, quality: 1 },
    "spitter":  { chance: 0.15, minItems: 1, maxItems: 1, quality: 2 },
    "screamer": { chance: 0.10, minItems: 1, maxItems: 1, quality: 1 },
    "swarmer":  { chance: 0.05, minItems: 1, maxItems: 1, quality: 1 },
    "soldier":  { chance: 0.40, minItems: 1, maxItems: 3, quality: 5 }
};

// Possible items found on corpses (by quality tier)
var CORPSE_ITEMS = {
    1: ["bandage", "water_bottle", "chips", "chocolate", "kitchen_knife", "lighter", "nails", "rope"],
    2: ["bandage", "painkillers", "water_bottle", "soda", "crowbar", "baseball_bat", "pistol_ammo", "metal_scrap", "hammer_tool"],
    5: ["pistol", "shotgun", "pistol_ammo", "shotgun_ammo", "rifle_ammo", "first_aid_kit", "antibiotics", "machete", "bandage", "canned_beans"]
};

function generateCorpseLoot(zombieType) {
    var config = CORPSE_LOOT[zombieType] || CORPSE_LOOT["walker"];
    if (!Utils.chance(config.chance)) return [];

    var items = [];
    var count = Utils.randInt(config.minItems, config.maxItems);
    var pool = CORPSE_ITEMS[config.quality] || CORPSE_ITEMS[1];

    for (var i = 0; i < count; i++) {
        var itemId = Utils.randChoice(pool);
        items.push({ id: itemId, count: 1 });
    }
    return items;
}

// ─── Cleanup dead zombies (keep corpses) ───
function cleanupDead(zombies) {
    var alive = [];
    var corpseCount = 0;
    // Count corpses first
    for (var i = 0; i < zombies.length; i++) {
        if (zombies[i].state === "corpse") corpseCount++;
    }
    // Max 40 corpses — remove oldest (first in array) if over limit
    var corpsesToRemove = Math.max(0, corpseCount - 40);
    for (var j = 0; j < zombies.length; j++) {
        var z = zombies[j];
        if (z.state === "dead") continue; // Remove truly dead
        if (z.state === "corpse" && corpsesToRemove > 0) {
            corpsesToRemove--;
            continue; // Remove oldest corpse
        }
        alive.push(z);
    }
    return alive;
}