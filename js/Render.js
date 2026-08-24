// Render.js — Canvas drawing functions for tiles, characters, zombies, effects
.pragma library

.import "Utils.js" as Utils

var TILE_SIZE = 32;

// ─── roundRect polyfill (Qt 6.2+ has it, but just in case) ───
function _roundRect(ctx, x, y, w, h, r) {
    if (typeof ctx.roundRect === "function") {
        ctx.roundRect(x, y, w, h, r);
        return;
    }
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
}

// ─── Tile colors ───
var TILE_COLORS = {
    0: "#3a5a28",   // GRASS
    1: "#3a3a3a",   // ROAD
    2: "#8B6B42",   // WOOD_FLOOR
    3: "#555555",   // CONCRETE
    4: "#9B8B6B",   // WALL
    5: "#7B5B3B",   // DOOR
    6: "#5B8BAA",   // WINDOW
    7: "#2A5A7A",   // WATER
    8: "#1E3A1E",   // TREE
    9: "#2A4A1A",   // BUSH
    10: "#6A6A5A",  // GRAVEL
    11: "#C4A868",  // SAND
    12: "#6A5A2A",  // FARMLAND
    13: "#8B6914",  // FENCE
    14: "#5A4A3A",  // COUNTER
    15: "#3A2A1A",  // SHELF
    16: "#3A4A5A",  // BED
    17: "#6A8A9A",  // TOILET
    18: "#6A8A9A",  // SINK
    19: "#5A5A4A",  // STOVE
    20: "#6A6A5A",  // FRIDGE
    21: "#7B5B2B",  // CRATE
    22: "#4A5A6A",  // LOCKER
    23: "#6A5A3A",  // CABINET
    24: "#4A5A4A",  // DUMPSTER
    25: "#3A3A4A",  // CAR
    26: "#7A6A4A",  // BARRICADE
    27: "#5A4A3A",  // RUBBLE
    28: "#6B1A1A",  // BLOOD
    29: "#6A6A6A",  // SIDEWALK
    30: "#2A5A2A",  // HEDGE
    31: "#7A7A7A",  // PAVEMENT
    32: "#5A4A2A",  // DESK
    33: "#4A3A2A",  // CHAIR
    34: "#6A5A3A",  // TABLE
    35: "#8A8A8A",  // BARBED_WIRE
    36: "#9A8A5A",  // SANDBAG
    37: "#4A4A3A",  // GENERATOR
    38: "#5A7A9A",  // WATER_COLLECTOR
    39: "#8A8A8A",  // FLOOR_TILE
    40: "#2A2A2A",  // ASPHALT
    41: "#5A4A2A",  // DIRT
    42: "#5A8A5A",  // FLOWER
    43: "#2B1B0B"   // DOOR_OPEN
};

// ─── Night tinting ───
function nightColor(hex, nightFactor) {
    var c = Utils.parseHex(hex);
    var f = 1 - nightFactor * 0.65;
    // Slight blue tint at night
    var bBoost = nightFactor * 15;
    return Utils.rgbStr(c.r * f, c.g * f, (c.b + bBoost) * f);
}

function nightOverlayColor(nightFactor) {
    if (nightFactor < 0.01) return null;
    var alpha = nightFactor * 0.35;
    return "rgba(10, 15, 40, " + alpha + ")";
}

// ─── Draw the visible world ───
function drawWorld(ctx, world, cameraX, cameraY, viewW, viewH, tileSize, nightFactor, player) {
    var startTX = Math.floor(cameraX / tileSize) - 1;
    var startTY = Math.floor(cameraY / tileSize) - 1;
    var endTX = Math.ceil((cameraX + viewW) / tileSize) + 1;
    var endTY = Math.ceil((cameraY + viewH) / tileSize) + 1;
    
    // Draw base tiles
    for (var ty = startTY; ty <= endTY; ty++) {
        for (var tx = startTX; tx <= endTX; tx++) {
            if (tx < 0 || ty < 0 || tx >= world.width || ty >= world.height) {
                // Out of bounds - draw void
                ctx.fillStyle = "#0a0a0a";
                ctx.fillRect(tx * tileSize - cameraX, ty * tileSize - cameraY, tileSize, tileSize);
                continue;
            }
            var tile = _getTile(world, tx, ty);
            var px = Math.floor(tx * tileSize - cameraX);
            var py = Math.floor(ty * tileSize - cameraY);
            drawTile(ctx, tile, px, py, tileSize, nightFactor, tx, ty, world.seed);
        }
    }
    
    // Draw night overlay
    var nColor = nightOverlayColor(nightFactor);
    if (nColor) {
        ctx.fillStyle = nColor;
        ctx.fillRect(0, 0, viewW, viewH);
    }
    
    // Draw flashlight cone at night if player has one
    if (nightFactor > 0.3 && player && player.hasFlashlight) {
        drawFlashlight(ctx, viewW, viewH, player, nightFactor);
    }
}

function _getTile(world, x, y) {
    var key = x + "," + y;
    if (world.changes[key] !== undefined) return world.changes[key];
    return world.tiles[y * world.width + x];
}

// ─── Draw a single tile with details ───
function drawTile(ctx, tile, x, y, size, nf, tx, ty, seed) {
    var color = TILE_COLORS[tile] || "#000000";
    ctx.fillStyle = nightColor(color, nf);
    ctx.fillRect(x, y, size, size);
    
    // Add tile-specific details
    switch (tile) {
        case 0: // GRASS - subtle texture
            var n = Utils._hash(tx, ty, seed) ;
            if (n < 0.15) {
                ctx.fillStyle = nightColor("#4a6a38", nf);
                ctx.fillRect(x + (n * size) % size, y + (n * size * 2) % size, 2, 2);
            }
            break;
        case 1: // ROAD - lane markings
            ctx.fillStyle = nightColor("#5a5a3a", nf);
            if (ty % 6 < 1) {
                ctx.fillRect(x + size/2 - 1, y, 2, size/2);
                ctx.fillRect(x + size/2 - 1, y + size/2, 2, size/2);
            }
            break;
        case 8: // TREE
            // Trunk
            ctx.fillStyle = nightColor("#3B2A1A", nf);
            ctx.fillRect(x + size/2 - 2, y + size/2 - 2, 4, 6);
            // Canopy
            ctx.fillStyle = nightColor("#1E4A1E", nf);
            ctx.beginPath();
            ctx.arc(x + size/2, y + size/2 - 2, size * 0.35, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = nightColor("#2A5A2A", nf);
            ctx.beginPath();
            ctx.arc(x + size/2 - 3, y + size/2 - 4, size * 0.2, 0, Math.PI * 2);
            ctx.fill();
            break;
        case 9: // BUSH
            ctx.fillStyle = nightColor("#2A4A1A", nf);
            ctx.beginPath();
            ctx.arc(x + size/2, y + size/2, size * 0.3, 0, Math.PI * 2);
            ctx.fill();
            break;
        case 4: // WALL - brick texture
            ctx.fillStyle = nightColor("#8B7B5B", nf);
            ctx.fillRect(x, y, size, 2);
            ctx.fillRect(x, y + size/2, size, 1);
            ctx.fillRect(x + size/3, y + 2, 1, size/2 - 2);
            ctx.fillRect(x + 2*size/3, y + 2, 1, size/2 - 2);
            ctx.fillRect(x + size/6, y + size/2 + 1, 1, size/2 - 3);
            ctx.fillRect(x + size/2, y + size/2 + 1, 1, size/2 - 3);
            ctx.fillRect(x + 5*size/6, y + size/2 + 1, 1, size/2 - 3);
            break;
        case 5: // DOOR (closed)
            ctx.fillStyle = nightColor("#5B3B1B", nf);
            ctx.fillRect(x + 4, y + 2, size - 8, size - 4);
            ctx.fillStyle = nightColor("#3B2B0B", nf);
            ctx.fillRect(x + size - 8, y + size/2 - 1, 2, 2); // door handle
            break;
        case 43: // DOOR_OPEN
            // Draw open door — door swung inward, dark gap
            ctx.fillStyle = nightColor("#2B1B0B", nf);
            ctx.fillRect(x + 2, y + 2, 4, size - 4); // door panel swung to side
            ctx.fillStyle = nightColor("#1A1A1A", nf);
            ctx.fillRect(x + 6, y + 2, size - 8, size - 4); // dark opening
            break;
        case 6: // WINDOW
            ctx.fillStyle = nightColor("#7BAAcA", nf);
            ctx.fillRect(x + 4, y + 4, size - 8, size - 8);
            ctx.strokeStyle = nightColor("#8B7B5B", nf);
            ctx.lineWidth = 1;
            ctx.strokeRect(x + 4, y + 4, size - 8, size - 8);
            ctx.beginPath();
            ctx.moveTo(x + size/2, y + 4);
            ctx.lineTo(x + size/2, y + size - 4);
            ctx.moveTo(x + 4, y + size/2);
            ctx.lineTo(x + size - 4, y + size/2);
            ctx.stroke();
            break;
        case 7: // WATER - animated waves
            ctx.fillStyle = nightColor("#3A6A8A", nf);
            ctx.fillRect(x, y, size, size);
            ctx.strokeStyle = nightColor("#5A8AAA", nf);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(x + 2, y + size * 0.3);
            ctx.quadraticCurveTo(x + size/4, y + size * 0.25, x + size/2, y + size * 0.3);
            ctx.quadraticCurveTo(x + 3*size/4, y + size * 0.35, x + size - 2, y + size * 0.3);
            ctx.stroke();
            break;
        case 25: // CAR
            ctx.fillStyle = nightColor(["#3A3A4A", "#4A3A3A", "#3A4A3A", "#4A4A3A"][Math.floor(Utils._hash(tx, ty, 0) * 4)], nf);
            ctx.fillRect(x + 3, y + 4, size - 6, size - 8);
            ctx.fillStyle = nightColor("#2A2A3A", nf);
            ctx.fillRect(x + 6, y + 7, size - 12, 5);
            ctx.fillRect(x + 6, y + size - 12, size - 12, 4);
            break;
        case 14: // COUNTER
            ctx.fillStyle = nightColor("#4A3A2A", nf);
            ctx.fillRect(x + 2, y + 2, size - 4, size - 4);
            ctx.fillStyle = nightColor("#6A5A4A", nf);
            ctx.fillRect(x + 2, y + 2, size - 4, 3);
            break;
        case 15: // SHELF
            ctx.fillStyle = nightColor("#5A4A2A", nf);
            ctx.fillRect(x + 2, y + 2, size - 4, 4);
            ctx.fillRect(x + 2, y + size/2 - 2, size - 4, 4);
            ctx.fillRect(x + 2, y + size - 6, size - 4, 4);
            break;
        case 20: // FRIDGE
            ctx.fillStyle = nightColor("#7A7A7A", nf);
            ctx.fillRect(x + 4, y + 2, size - 8, size - 4);
            ctx.fillStyle = nightColor("#5A5A5A", nf);
            ctx.fillRect(x + size - 8, y + 6, 2, 8);
            break;
        case 21: // CRATE
            ctx.strokeStyle = nightColor("#5B3B1B", nf);
            ctx.lineWidth = 2;
            ctx.strokeRect(x + 2, y + 2, size - 4, size - 4);
            ctx.beginPath();
            ctx.moveTo(x + 2, y + 2);
            ctx.lineTo(x + size - 2, y + size - 2);
            ctx.moveTo(x + size - 2, y + 2);
            ctx.lineTo(x + 2, y + size - 2);
            ctx.stroke();
            break;
        case 22: // LOCKER
            ctx.fillStyle = nightColor("#5A6A7A", nf);
            ctx.fillRect(x + 4, y + 2, size - 8, size - 4);
            ctx.strokeStyle = nightColor("#3A4A5A", nf);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(x + size/2, y + 2);
            ctx.lineTo(x + size/2, y + size - 2);
            ctx.stroke();
            break;
        case 13: // FENCE
            ctx.strokeStyle = nightColor("#7B5914", nf);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(x + 4, y);
            ctx.lineTo(x + 4, y + size);
            ctx.moveTo(x + size - 4, y);
            ctx.lineTo(x + size - 4, y + size);
            ctx.moveTo(x, y + size/3);
            ctx.lineTo(x + size, y + size/3);
            ctx.moveTo(x, y + 2*size/3);
            ctx.lineTo(x + size, y + 2*size/3);
            ctx.stroke();
            break;
        case 26: // BARRICADE
            ctx.fillStyle = nightColor("#8B6B42", nf);
            ctx.fillRect(x, y + 4, size, 3);
            ctx.fillRect(x, y + size - 7, size, 3);
            ctx.fillStyle = nightColor("#6B4B22", nf);
            ctx.fillRect(x + 3, y + 2, 2, size - 4);
            ctx.fillRect(x + size - 5, y + 2, 2, size - 4);
            break;
        case 16: // BED
            ctx.fillStyle = nightColor("#5A6A7A", nf);
            ctx.fillRect(x + 3, y + 3, size - 6, size - 6);
            ctx.fillStyle = nightColor("#7A8A9A", nf);
            ctx.fillRect(x + 3, y + 3, size - 6, 6);
            break;
        case 19: // STOVE
            ctx.fillStyle = nightColor("#4A4A3A", nf);
            ctx.fillRect(x + 3, y + 3, size - 6, size - 6);
            ctx.fillStyle = nightColor("#2A2A1A", nf);
            ctx.beginPath();
            ctx.arc(x + 10, y + 12, 3, 0, Math.PI * 2);
            ctx.arc(x + 22, y + 12, 3, 0, Math.PI * 2);
            ctx.fill();
            break;
        case 28: // BLOOD
            ctx.fillStyle = "rgba(107, 26, 26, 0.6)";
            ctx.beginPath();
            ctx.arc(x + size/2, y + size/2, size * 0.4, 0, Math.PI * 2);
            ctx.fill();
            break;
        case 29: // SIDEWALK
            ctx.strokeStyle = nightColor("#5A5A5A", nf);
            ctx.lineWidth = 0.5;
            ctx.strokeRect(x, y, size, size);
            break;
        case 42: // FLOWER
            var fn = Utils._hash(tx, ty, seed);
            ctx.fillStyle = nightColor(["#FF6B6B", "#FFD93D", "#FF9F40", "#C9B1FF"][Math.floor(fn * 4)], nf);
            ctx.beginPath();
            ctx.arc(x + size/2, y + size/2, 2, 0, Math.PI * 2);
            ctx.fill();
            break;
        case 37: // GENERATOR
            ctx.fillStyle = nightColor("#3A3A2A", nf);
            ctx.fillRect(x + 4, y + 4, size - 8, size - 8);
            ctx.fillStyle = nightColor("#5A5A3A", nf);
            ctx.fillRect(x + 6, y + 8, 4, 4);
            break;
    }
}

// ─── Draw the player character ───
function drawPlayer(ctx, x, y, facing, walkPhase, attackPhase, weapon, moving) {
    ctx.save();
    ctx.translate(x, y);
    
    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.3)";
    ctx.beginPath();
    ctx.ellipse(0, 3, 9, 5, 0, 0, Math.PI * 2);
    ctx.fill();
    
    ctx.rotate(facing);
    
    // Legs (animated when walking)
    var legOffset = moving ? Math.sin(walkPhase) * 4 : 0;
    ctx.fillStyle = "#3A3A4A";
    ctx.fillRect(-3, -legOffset - 4, 3, 8);
    ctx.fillRect(0, legOffset - 4, 3, 8);
    
    // Body/torso
    ctx.fillStyle = "#4A5A6A";
    ctx.beginPath();
    _roundRect(ctx, -6, -6, 12, 12, 3);
    ctx.fill();
    
    // Body highlight
    ctx.fillStyle = "#5A6A7A";
    ctx.fillRect(-5, -5, 3, 3);
    
    // Head
    ctx.fillStyle = "#D4A574";
    ctx.beginPath();
    ctx.arc(0, 0, 4.5, 0, Math.PI * 2);
    ctx.fill();
    
    // Hair
    ctx.fillStyle = "#5A3A1A";
    ctx.beginPath();
    ctx.arc(0, -1, 4.5, Math.PI * 0.8, Math.PI * 2.2);
    ctx.fill();
    
    // Arms + weapon
    if (attackPhase > 0) {
        drawWeaponAttack(ctx, attackPhase, weapon);
    } else {
        drawHeldWeapon(ctx, weapon);
    }
    
    ctx.restore();
}

function drawHeldWeapon(ctx, weapon) {
    if (!weapon) {
        // Bare fists
        ctx.fillStyle = "#D4A574";
        ctx.beginPath();
        ctx.arc(6, -4, 2.5, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.arc(6, 4, 2.5, 0, Math.PI * 2);
        ctx.fill();
        return;
    }
    
    if (weapon.cat === "melee") {
        // Melee weapon - held to the side
        ctx.save();
        ctx.translate(5, 0);
        
        switch (weapon.id) {
            case "baseball_bat":
                ctx.fillStyle = "#8B6914";
                ctx.fillRect(0, -1.5, 16, 3);
                break;
            case "axe":
                ctx.fillStyle = "#5A3A1A";
                ctx.fillRect(0, -1, 10, 2);
                ctx.fillStyle = "#AAA";
                ctx.beginPath();
                ctx.moveTo(10, -1);
                ctx.lineTo(16, -5);
                ctx.lineTo(16, 5);
                ctx.lineTo(10, 1);
                ctx.fill();
                break;
            case "kitchen_knife":
            case "machete":
                ctx.fillStyle = "#CCC";
                ctx.fillRect(0, -1, 12, 2);
                ctx.fillStyle = "#3A2A1A";
                ctx.fillRect(-3, -1.5, 4, 3);
                break;
            case "crowbar":
                ctx.fillStyle = "#5A5A4A";
                ctx.fillRect(0, -1.5, 14, 3);
                ctx.beginPath();
                ctx.arc(14, 0, 3, -Math.PI/2, Math.PI/2);
                ctx.lineWidth = 3;
                ctx.strokeStyle = "#5A5A4A";
                ctx.stroke();
                break;
            case "hammer":
                ctx.fillStyle = "#5A3A1A";
                ctx.fillRect(0, -1, 8, 2);
                ctx.fillStyle = "#666";
                ctx.fillRect(7, -4, 5, 8);
                break;
            case "frying_pan":
                ctx.fillStyle = "#333";
                ctx.beginPath();
                ctx.arc(8, 0, 6, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = "#5A3A1A";
                ctx.fillRect(0, -1, 4, 2);
                break;
            default:
                ctx.fillStyle = "#D4A574";
                ctx.beginPath();
                ctx.arc(0, -4, 2.5, 0, Math.PI * 2);
                ctx.fill();
        }
        ctx.restore();
    } else if (weapon.cat === "ranged") {
        // Ranged weapon - held forward
        ctx.save();
        ctx.translate(4, 0);
        
        switch (weapon.id) {
            case "pistol":
                ctx.fillStyle = "#2A2A2A";
                ctx.fillRect(0, -2, 8, 4);
                ctx.fillRect(0, 0, 3, 6);
                break;
            case "shotgun":
                ctx.fillStyle = "#3A2A1A";
                ctx.fillRect(0, -2, 18, 3);
                ctx.fillStyle = "#2A2A2A";
                ctx.fillRect(12, -2.5, 6, 4);
                break;
            case "rifle":
                ctx.fillStyle = "#3A2A1A";
                ctx.fillRect(0, -1.5, 24, 3);
                ctx.fillStyle = "#2A2A2A";
                ctx.fillRect(18, -2.5, 6, 5);
                break;
            default:
                ctx.fillStyle = "#2A2A2A";
                ctx.fillRect(0, -2, 8, 4);
        }
        ctx.restore();
    }
}

function drawWeaponAttack(ctx, phase, weapon) {
    // phase: 0 to 1 (0 = start, 1 = end of swing)
    var swingAngle = Math.sin(phase * Math.PI) * 1.3;
    
    if (!weapon || weapon.cat === "melee" || weapon.id === "fists") {
        // Melee swing arc
        ctx.save();
        ctx.rotate(swingAngle);
        ctx.translate(5, 0);
        
        // Arm
        ctx.fillStyle = "#D4A574";
        ctx.fillRect(0, -2, 8, 4);
        
        // Weapon follows arm
        if (weapon && weapon.id !== "fists") {
            drawHeldWeapon(ctx, weapon);
        } else {
            ctx.fillStyle = "#D4A574";
            ctx.beginPath();
            ctx.arc(8, 0, 3, 0, Math.PI * 2);
            ctx.fill();
        }
        
        // Swing arc effect
        if (phase < 0.7) {
            ctx.strokeStyle = "rgba(255, 255, 255, " + (0.5 * (1 - phase / 0.7)) + ")";
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(0, 0, 22, -swingAngle - 0.5, -swingAngle + 0.5);
            ctx.stroke();
        }
        
        ctx.restore();
    } else if (weapon.cat === "ranged") {
        // Gun recoil
        var recoil = phase < 0.2 ? (1 - phase / 0.2) * 4 : 0;
        ctx.save();
        ctx.translate(-recoil, 0);
        drawHeldWeapon(ctx, weapon);
        
        // Muzzle flash
        if (phase < 0.15) {
            var flashSize = (1 - phase / 0.15) * 8;
            ctx.fillStyle = "rgba(255, 220, 80, " + (1 - phase / 0.15) + ")";
            ctx.beginPath();
            ctx.arc(20, 0, flashSize, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = "rgba(255, 150, 50, " + (1 - phase / 0.15) * 0.5 + ")";
            ctx.beginPath();
            ctx.arc(20, 0, flashSize * 1.5, 0, Math.PI * 2);
            ctx.fill();
        }
        
        ctx.restore();
    }
}

// ─── Draw a zombie ───
function drawZombie(ctx, zombie, cameraX, cameraY, nf) {
    if (zombie.state === "dead") return;
    
    // Draw corpse separately
    if (zombie.state === "corpse") {
        drawCorpse(ctx, zombie, cameraX, cameraY, nf);
        return;
    }
    
    var x = zombie.x - cameraX;
    var y = zombie.y - cameraY;
    var def = _getZombieDef(zombie.type);
    var scale = def.size;
    
    ctx.save();
    ctx.translate(x, y);
    
    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(0, 3, 7 * scale, 4 * scale, 0, 0, Math.PI * 2);
    ctx.fill();
    
    ctx.rotate(zombie.facing);
    ctx.scale(scale, scale);
    
    // Hit flash
    var bodyColor = zombie.hitFlash > 0 ? "#FFFFFF" : nightColor(def.color, nf);
    var skinColor = zombie.hitFlash > 0 ? "#FFDDDD" : nightColor(def.skinColor, nf);
    
    // Legs (shambling)
    var legOffset = Math.sin(zombie.walkPhase) * 3;
    ctx.fillStyle = nightColor("#3A3A2A", nf);
    ctx.fillRect(-3, -legOffset - 3, 3, 6);
    ctx.fillRect(0, legOffset - 3, 3, 6);
    
    // Body
    ctx.fillStyle = bodyColor;
    ctx.beginPath();
    _roundRect(ctx, -5, -5, 10, 10, 2);
    ctx.fill();
    
    // Torn clothing details
    ctx.fillStyle = nightColor("#3A4A2A", nf);
    ctx.fillRect(-4, -2, 3, 2);
    
    // Head
    ctx.fillStyle = skinColor;
    ctx.beginPath();
    ctx.arc(0, 0, 4, 0, Math.PI * 2);
    ctx.fill();
    
    // Eyes (glowing red at night)
    if (nf > 0.5) {
        ctx.fillStyle = "rgba(255, 50, 50, " + nf + ")";
        ctx.beginPath();
        ctx.arc(2, -1.5, 1, 0, Math.PI * 2);
        ctx.arc(2, 1.5, 1, 0, Math.PI * 2);
        ctx.fill();
    }
    
    // Arms reaching forward
    ctx.fillStyle = skinColor;
    var armReach = zombie.state === "attack" ? 7 : 5;
    ctx.fillRect(3, -4, armReach, 2);
    ctx.fillRect(3, 2, armReach, 2);
    
    // Crawler: draw lower to ground
    if (zombie.type === "crawler") {
        ctx.fillStyle = nightColor("#3A3A2A", nf);
        ctx.fillRect(-5, 2, 10, 3);
    }
    
    // Health bar if damaged
    if (zombie.health < zombie.maxHealth) {
        ctx.save();
        ctx.rotate(-zombie.facing); // un-rotate for health bar
        var barW = 16;
        var barH = 2;
        var barY = -12;
        ctx.fillStyle = "rgba(0,0,0,0.6)";
        ctx.fillRect(-barW/2, barY, barW, barH);
        ctx.fillStyle = zombie.health > zombie.maxHealth * 0.5 ? "#5Acf3A" :
                       zombie.health > zombie.maxHealth * 0.25 ? "#cfA53A" : "#cf3A3A";
        ctx.fillRect(-barW/2, barY, barW * (zombie.health / zombie.maxHealth), barH);
        ctx.restore();
    }
    
    ctx.restore();
}

function _getZombieDef(typeId) {
    // Minimal zombie def for rendering
    var defs = {
        "walker": { color: "#5a7a4a", skinColor: "#6b8b5b", size: 1.0 },
        "runner": { color: "#7a5a4a", skinColor: "#8b6b5b", size: 0.9 },
        "brute": { color: "#4a5a3a", skinColor: "#5b6b4b", size: 1.4 },
        "crawler": { color: "#5a6a5a", skinColor: "#6b7b6b", size: 0.7 },
        "spitter": { color: "#6a8a3a", skinColor: "#7b9b4b", size: 0.9 },
        "screamer": { color: "#8a7a5a", skinColor: "#9b8b6b", size: 0.8 },
        "swarmer": { color: "#5a5a4a", skinColor: "#6b6b5b", size: 0.7 },
        "soldier": { color: "#4a4a3a", skinColor: "#5b5b4b", size: 1.1 }
    };
    return defs[typeId] || defs["walker"];
}

// ─── Draw a zombie corpse (lying on ground) ───
function drawCorpse(ctx, zombie, cameraX, cameraY, nf) {
    var x = zombie.x - cameraX;
    var y = zombie.y - cameraY;
    var def = _getZombieDef(zombie.type);
    var scale = def.size;

    // Dark blood pool under corpse
    ctx.fillStyle = "rgba(80, 15, 15, 0.5)";
    ctx.beginPath();
    ctx.ellipse(x, y, 12 * scale, 7 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    // Body lying flat (dark, desaturated)
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(zombie.facing + Math.PI / 4); // Body splayed at angle
    ctx.scale(scale, scale);

    // Torso (dark)
    ctx.fillStyle = nightColor("#3a4a2a", nf);
    ctx.beginPath();
    _roundRect(ctx, -6, -4, 12, 8, 3);
    ctx.fill();

    // Head (dark)
    ctx.fillStyle = nightColor("#4a5a3a", nf);
    ctx.beginPath();
    ctx.arc(5, -3, 3.5, 0, Math.PI * 2);
    ctx.fill();

    // Arms splayed
    ctx.strokeStyle = nightColor("#3a4a2a", nf);
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-2, -2);
    ctx.lineTo(-8, -6);
    ctx.moveTo(-2, 2);
    ctx.lineTo(-7, 7);
    ctx.stroke();

    // Legs splayed
    ctx.beginPath();
    ctx.moveTo(-4, -1);
    ctx.lineTo(-10, -3);
    ctx.moveTo(-4, 1);
    ctx.lineTo(-10, 4);
    ctx.stroke();

    ctx.restore();

    // Loot indicator — small sparkle if corpse has unlooted items
    if (zombie.loot && zombie.loot.length > 0 && !zombie.looted) {
        var pulse = (Math.sin(Date.now() / 300) + 1) / 2;
        ctx.fillStyle = "rgba(255, 220, 100, " + (0.4 + pulse * 0.4) + ")";
        ctx.beginPath();
        ctx.arc(x, y - 14, 2 + pulse, 0, Math.PI * 2);
        ctx.fill();
    }
}

// ─── Draw projectiles ───
function drawProjectile(ctx, proj, cameraX, cameraY) {
    var x = proj.x - cameraX;
    var y = proj.y - cameraY;
    
    ctx.strokeStyle = "rgba(255, 220, 100, 0.8)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x - proj.vx * 0.02, y - proj.vy * 0.02);
    ctx.stroke();
    
    // Bullet dot
    ctx.fillStyle = "#FFD700";
    ctx.beginPath();
    ctx.arc(x, y, 1.5, 0, Math.PI * 2);
    ctx.fill();
}

// ─── Draw zombie spit projectiles (acid glob with a trailing tail) ───
function drawZombieProjectile(ctx, proj, cameraX, cameraY) {
    var x = proj.x - cameraX;
    var y = proj.y - cameraY;

    // Trailing tail
    ctx.strokeStyle = "rgba(140, 220, 80, 0.5)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x - proj.vx * 0.03, y - proj.vy * 0.03);
    ctx.stroke();

    // Acid splatter halo
    ctx.fillStyle = "rgba(120, 200, 60, 0.45)";
    ctx.beginPath();
    ctx.arc(x, y, 4, 0, Math.PI * 2);
    ctx.fill();

    // Bright glob core
    ctx.fillStyle = "#9adf4a";
    ctx.beginPath();
    ctx.arc(x, y, 2, 0, Math.PI * 2);
    ctx.fill();
}

// ─── Draw ground items ───
function drawGroundItem(ctx, item, cameraX, cameraY, tileSize) {
    var x = item.x - cameraX;
    var y = item.y - cameraY;
    
    // Small item bag icon
    ctx.fillStyle = "rgba(180, 140, 60, 0.8)";
    ctx.beginPath();
    _roundRect(ctx, x - 4, y - 4, 8, 8, 1);
    ctx.fill();
    
    ctx.fillStyle = "rgba(100, 70, 30, 0.9)";
    ctx.fillRect(x - 3, y - 1, 6, 2);
}

// ─── Draw blood splatter effect ───
function drawBloodEffect(ctx, effect, cameraX, cameraY) {
    var x = effect.x - cameraX;
    var y = effect.y - cameraY;
    
    for (var i = 0; i < effect.particles.length; i++) {
        var p = effect.particles[i];
        ctx.fillStyle = "rgba(139, 26, 26, " + p.alpha + ")";
        ctx.beginPath();
        ctx.arc(x + p.x, y + p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
    }
}

// ─── Draw flashlight cone ───
function drawFlashlight(ctx, viewW, viewH, player, nightFactor) {
    var cx = viewW / 2;
    var cy = viewH / 2;
    var angle = player.facing;
    var coneAngle = 0.5;
    var range = 200;
    
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    
    var grad = ctx.createRadialGradient(cx, cy, 10, cx, cy, range);
    grad.addColorStop(0, "rgba(255, 240, 180, " + (0.25 * nightFactor) + ")");
    grad.addColorStop(1, "rgba(255, 240, 180, 0)");
    
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, range, angle - coneAngle, angle + coneAngle);
    ctx.closePath();
    ctx.fill();
    
    ctx.restore();
}

// ─── Draw interaction prompt ───
function drawInteractionPrompt(ctx, x, y, text) {
    ctx.fillStyle = "rgba(0, 0, 0, 0.7)";
    var w = text.length * 7 + 10;
    _roundRect(ctx, x - w/2, y - 10, w, 16, 3);
    ctx.fill();
    
    ctx.fillStyle = "#FFFFFF";
    ctx.font = "11px monospace";
    ctx.textAlign = "center";
    ctx.fillText(text, x, y + 2);
}