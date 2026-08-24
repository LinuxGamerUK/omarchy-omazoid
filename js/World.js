// World.js — Procedural map generation with districts
.pragma library

.import "Utils.js" as Utils

// ─── Tile types ───
var T = {
    GRASS: 0, ROAD: 1, WOOD_FLOOR: 2, CONCRETE: 3,
    WALL: 4, DOOR: 5, WINDOW: 6, WATER: 7,
    TREE: 8, BUSH: 9, GRAVEL: 10, SAND: 11,
    FARMLAND: 12, FENCE: 13, COUNTER: 14, SHELF: 15,
    BED: 16, TOILET: 17, SINK: 18, STOVE: 19,
    FRIDGE: 20, CRATE: 21, LOCKER: 22, CABINET: 23,
    DUMPSTER: 24, CAR: 25, BARRICADE: 26, RUBBLE: 27,
    BLOOD: 28, SIDEWALK: 29, HEDGE: 30, PAVEMENT: 31,
    DESK: 32, CHAIR: 33, TABLE: 34, BARBED_WIRE: 35,
    SANDBAG: 36, GENERATOR: 37, WATER_COLLECTOR: 38,
    FLOOR_TILE: 39, ASPHALT: 40, DIRT: 41, FLOWER: 42,
    DOOR_OPEN: 43
};

// Walkable tiles
var WALKABLE = {};
[T.GRASS, T.ROAD, T.WOOD_FLOOR, T.CONCRETE, T.DOOR_OPEN, T.WATER,
 T.SIDEWALK, T.FARMLAND, T.DIRT, T.FLOOR_TILE, T.ASPHALT,
 T.GRAVEL, T.SAND, T.RUBBLE, T.BLOOD, T.PAVEMENT, T.FLOWER].forEach(function(t) { WALKABLE[t] = true; });

// Container tiles (can be looted)
var CONTAINERS = {};
[T.SHELF, T.CRATE, T.LOCKER, T.CABINET, T.FRIDGE, T.COUNTER,
 T.DUMPSTER, T.DESK, T.GENERATOR, T.WATER_COLLECTOR].forEach(function(t) { CONTAINERS[t] = true; });

// ─── District types ───
var DISTRICTS = {
    RESIDENTIAL: {
        name: "Residential",
        baseTerrain: T.GRASS,
        buildingDensity: 0.7,
        buildingSizeMin: 6, buildingSizeMax: 12,
        lootQuality: 1,
        zombieTypes: ["walker", "crawler"],
        zombieDensity: 0.6,
        treeDensity: 0.08
    },
    COMMERCIAL: {
        name: "Commercial",
        baseTerrain: T.PAVEMENT,
        buildingDensity: 0.85,
        buildingSizeMin: 10, buildingSizeMax: 20,
        lootQuality: 2,
        zombieTypes: ["walker", "runner", "screamer"],
        zombieDensity: 0.9,
        treeDensity: 0.02
    },
    DOWNTOWN: {
        name: "Downtown",
        baseTerrain: T.CONCRETE,
        buildingDensity: 0.95,
        buildingSizeMin: 14, buildingSizeMax: 28,
        lootQuality: 3,
        zombieTypes: ["walker", "runner", "brute"],
        zombieDensity: 1.2,
        treeDensity: 0.01
    },
    INDUSTRIAL: {
        name: "Industrial",
        baseTerrain: T.GRAVEL,
        buildingDensity: 0.6,
        buildingSizeMin: 12, buildingSizeMax: 24,
        lootQuality: 2,
        zombieTypes: ["walker", "brute"],
        zombieDensity: 0.7,
        treeDensity: 0.01
    },
    HOSPITAL: {
        name: "Hospital",
        baseTerrain: T.FLOOR_TILE,
        buildingDensity: 0.9,
        buildingSizeMin: 16, buildingSizeMax: 30,
        lootQuality: 4,
        zombieTypes: ["walker", "crawler", "spitter", "screamer"],
        zombieDensity: 1.5,
        treeDensity: 0.0
    },
    MILITARY: {
        name: "Military",
        baseTerrain: T.GRAVEL,
        buildingDensity: 0.5,
        buildingSizeMin: 8, buildingSizeMax: 16,
        lootQuality: 5,
        zombieTypes: ["walker", "brute", "soldier"],
        zombieDensity: 0.8,
        treeDensity: 0.0
    },
    FARM: {
        name: "Farmland",
        baseTerrain: T.FARMLAND,
        buildingDensity: 0.3,
        buildingSizeMin: 6, buildingSizeMax: 14,
        lootQuality: 1,
        zombieTypes: ["walker", "swarmer"],
        zombieDensity: 0.4,
        treeDensity: 0.05
    },
    PARK: {
        name: "Park",
        baseTerrain: T.GRASS,
        buildingDensity: 0.05,
        buildingSizeMin: 4, buildingSizeMax: 8,
        lootQuality: 1,
        zombieTypes: ["walker", "swarmer"],
        zombieDensity: 0.5,
        treeDensity: 0.25
    }
};

var DISTRICT_NAMES = Object.keys(DISTRICTS);

// ─── World generation ───
function generateWorld(seed, width, height) {
    Utils.setSeed(seed);
    
    var world = {
        seed: seed,
        width: width,
        height: height,
        tiles: new Array(width * height),
        changes: {},  // "x,y" -> tile type (player modifications)
        containers: {}, // "x,y" -> { looted: bool, items: [] }
        districts: [],
        spawnX: 0,
        spawnY: 0
    };
    
    // Initialize all tiles to grass
    for (var i = 0; i < width * height; i++) {
        world.tiles[i] = T.GRASS;
    }
    
    // Assign districts in a grid
    var districtGridSize = 4; // 4x4 = 16 districts
    var cellW = Math.floor(width / districtGridSize);
    var cellH = Math.floor(height / districtGridSize);
    
    for (var dy = 0; dy < districtGridSize; dy++) {
        for (var dx = 0; dx < districtGridSize; dx++) {
            var distFromCenter = Math.max(Math.abs(dx - 1.5), Math.abs(dy - 1.5));
            var dType;
            
            if (distFromCenter < 0.6) {
                dType = "DOWNTOWN";
            } else if (distFromCenter < 1.1) {
                // Inner ring: mix of commercial, hospital, industrial
                var inner = ["COMMERCIAL", "HOSPITAL", "INDUSTRIAL", "COMMERCIAL"];
                dType = inner[Utils.randInt(0, inner.length - 1)];
            } else {
                // Outer ring: residential, farm, park, military
                var outer = ["RESIDENTIAL", "FARM", "PARK", "RESIDENTIAL", "MILITARY", "FARM"];
                dType = outer[Utils.randInt(0, outer.length - 1)];
            }
            
            world.districts.push({
                type: dType,
                x: dx * cellW, y: dy * cellH,
                w: cellW, h: cellH
            });
        }
    }
    
    // Generate terrain per district
    for (var d = 0; d < world.districts.length; d++) {
        var dist = world.districts[d];
        var distDef = DISTRICTS[dist.type];
        fillDistrictTerrain(world, dist, distDef);
    }
    
    // Generate roads (main grid roads)
    generateRoads(world, districtGridSize, cellW, cellH);
    
    // Generate buildings per district
    for (var d = 0; d < world.districts.length; d++) {
        var dist = world.districts[d];
        var distDef = DISTRICTS[dist.type];
        generateBuildings(world, dist, distDef);
    }
    
    // Scatter decorations (trees, bushes, cars)
    scatterDecorations(world);
    
    // Find a safe spawn point (residential area, on grass/road)
    findSpawnPoint(world, districtGridSize, cellW, cellH);
    
    return world;
}

function fillDistrictTerrain(world, dist, distDef) {
    for (var y = dist.y; y < dist.y + dist.h && y < world.height; y++) {
        for (var x = dist.x; x < dist.x + dist.w && x < world.width; x++) {
            var noise = Utils.fbm(x * 0.05, y * 0.05, world.seed, 3);
            if (noise < 0.35 && distDef.baseTerrain === T.GRASS) {
                setTileRaw(world, x, y, T.DIRT);
            } else {
                setTileRaw(world, x, y, distDef.baseTerrain);
            }
        }
    }
}

function generateRoads(world, grid, cellW, cellH) {
    var roadWidth = 3;
    
    // Horizontal main roads
    for (var gy = 0; gy <= grid; gy++) {
        var roadY = gy * cellH;
        for (var w = 0; w < roadWidth; w++) {
            var ry = roadY + w - 1;
            if (ry < 0 || ry >= world.height) continue;
            for (var x = 0; x < world.width; x++) {
                setTileRaw(world, x, ry, T.ROAD);
            }
        }
    }
    
    // Vertical main roads
    for (var gx = 0; gx <= grid; gx++) {
        var roadX = gx * cellW;
        for (var w = 0; w < roadWidth; w++) {
            var rx = roadX + w - 1;
            if (rx < 0 || rx >= world.width) continue;
            for (var y = 0; y < world.height; y++) {
                setTileRaw(world, rx, y, T.ROAD);
            }
        }
    }
    
    // Sidewalks alongside roads
    for (var gy = 0; gy <= grid; gy++) {
        var ry2 = gy * cellH;
        for (var x = 0; x < world.width; x++) {
            if (ry2 - 2 >= 0 && getTileRaw(world, x, ry2 - 2) !== T.ROAD)
                setTileRaw(world, x, ry2 - 2, T.SIDEWALK);
            if (ry2 + 2 < world.height && getTileRaw(world, x, ry2 + 2) !== T.ROAD)
                setTileRaw(world, x, ry2 + 2, T.SIDEWALK);
        }
    }
    for (var gx = 0; gx <= grid; gx++) {
        var rx2 = gx * cellW;
        for (var y = 0; y < world.height; y++) {
            if (rx2 - 2 >= 0 && getTileRaw(world, rx2 - 2, y) !== T.ROAD)
                setTileRaw(world, rx2 - 2, y, T.SIDEWALK);
            if (rx2 + 2 < world.width && getTileRaw(world, rx2 + 2, y) !== T.ROAD)
                setTileRaw(world, rx2 + 2, y, T.SIDEWALK);
        }
    }
}

function generateBuildings(world, dist, distDef) {
    var attempts = Math.floor(dist.w * dist.h * distDef.buildingDensity * 0.02);
    var placed = 0;
    var maxBuildings = Math.floor(dist.w * dist.h * distDef.buildingDensity * 0.015);
    
    for (var i = 0; i < attempts && placed < maxBuildings; i++) {
        var bw = Utils.randInt(distDef.buildingSizeMin, distDef.buildingSizeMax);
        var bh = Utils.randInt(distDef.buildingSizeMin, distDef.buildingSizeMax);
        var bx = dist.x + Utils.randInt(3, dist.w - bw - 3);
        var by = dist.y + Utils.randInt(3, dist.h - bh - 3);
        
        // Check if area is mostly free (not overlapping roads/other buildings)
        if (!isAreaFree(world, bx, by, bw, bh)) continue;
        
        generateBuilding(world, bx, by, bw, bh, distDef, dist.type);
        placed++;
    }
}

function isAreaFree(world, x, y, w, h) {
    for (var dy = -1; dy <= h; dy++) {
        for (var dx = -1; dx <= w; dx++) {
            var tx = x + dx, ty = y + dy;
            if (tx < 0 || ty < 0 || tx >= world.width || ty >= world.height) return false;
            var t = getTileRaw(world, tx, ty);
            if (t === T.WALL || t === T.ROAD || t === T.WOOD_FLOOR ||
                t === T.CONCRETE || t === T.FLOOR_TILE) return false;
        }
    }
    return true;
}

function generateBuilding(world, x, y, w, h, distDef, distType) {
    var floorTile = T.WOOD_FLOOR;
    var wallTile = T.WALL;
    
    if (distType === "DOWNTOWN" || distType === "COMMERCIAL") {
        floorTile = T.FLOOR_TILE;
    } else if (distType === "INDUSTRIAL" || distType === "MILITARY") {
        floorTile = T.CONCRETE;
    } else if (distType === "HOSPITAL") {
        floorTile = T.FLOOR_TILE;
    }
    
    // Fill interior with floor
    for (var dy = 1; dy < h - 1; dy++) {
        for (var dx = 1; dx < w - 1; dx++) {
            setTileRaw(world, x + dx, y + dy, floorTile);
        }
    }
    
    // Walls around perimeter
    for (var dx = 0; dx < w; dx++) {
        setTileRaw(world, x + dx, y, wallTile);
        setTileRaw(world, x + dx, y + h - 1, wallTile);
    }
    for (var dy = 0; dy < h; dy++) {
        setTileRaw(world, x, y + dy, wallTile);
        setTileRaw(world, x + w - 1, y + dy, wallTile);
    }
    
    // Door (random wall position, not corners)
    var doorSide = Utils.randInt(0, 3);
    var doorPos;
    switch (doorSide) {
        case 0: doorPos = [x + Utils.randInt(1, w - 2), y]; break;
        case 1: doorPos = [x + w - 1, y + Utils.randInt(1, h - 2)]; break;
        case 2: doorPos = [x + Utils.randInt(1, w - 2), y + h - 1]; break;
        case 3: doorPos = [x, y + Utils.randInt(1, h - 2)]; break;
    }
    setTileRaw(world, doorPos[0], doorPos[1], T.DOOR);
    
    // Windows (1-3 random wall positions)
    var numWindows = Utils.randInt(1, 3);
    for (var i = 0; i < numWindows; i++) {
        var wSide = Utils.randInt(0, 3);
        var wPos;
        switch (wSide) {
            case 0: wPos = [x + Utils.randInt(1, w - 2), y]; break;
            case 1: wPos = [x + w - 1, y + Utils.randInt(1, h - 2)]; break;
            case 2: wPos = [x + Utils.randInt(1, w - 2), y + h - 1]; break;
            case 3: wPos = [x, y + Utils.randInt(1, h - 2)]; break;
        }
        if (getTileRaw(world, wPos[0], wPos[1]) === T.WALL) {
            setTileRaw(world, wPos[0], wPos[1], T.WINDOW);
        }
    }
    
    // Interior furniture based on district type
    furnishBuilding(world, x, y, w, h, distType, floorTile);
}

function furnishBuilding(world, x, y, w, h, distType, floorTile) {
    var interiorW = w - 2;
    var interiorH = h - 2;
    
    // Place furniture in the interior
    var furnitureCount = Math.floor(interiorW * interiorH * 0.15);
    
    for (var i = 0; i < furnitureCount; i++) {
        var fx = x + Utils.randInt(1, w - 2);
        var fy = y + Utils.randInt(1, h - 2);
        if (getTileRaw(world, fx, fy) !== floorTile) continue;
        if (isAdjacentToDoor(world, fx, fy)) continue; // Keep doorways clear
        
        var furniture;
        switch (distType) {
            case "RESIDENTIAL":
                furniture = [T.BED, T.CABINET, T.FRIDGE, T.STOVE, T.SINK, T.TABLE, T.CHAIR, T.CABINET];
                break;
            case "COMMERCIAL":
                furniture = [T.SHELF, T.COUNTER, T.SHELF, T.DESK, T.SHELF, T.CABINET];
                break;
            case "DOWNTOWN":
                furniture = [T.DESK, T.SHELF, T.COUNTER, T.LOCKER, T.DESK, T.TABLE];
                break;
            case "INDUSTRIAL":
                furniture = [T.CRATE, T.CRATE, T.LOCKER, T.SHELF, T.CRATE];
                break;
            case "HOSPITAL":
                furniture = [T.CABINET, T.LOCKER, T.COUNTER, T.BED, T.SHELF, T.CABINET];
                break;
            case "MILITARY":
                furniture = [T.LOCKER, T.CRATE, T.LOCKER, T.SHELF, T.CRATE];
                break;
            case "FARM":
                furniture = [T.CRATE, T.TABLE, T.CABINET, T.CRATE];
                break;
            default:
                furniture = [T.TABLE, T.CHAIR, T.CABINET];
        }
        
        var item = Utils.randChoice(furniture);
        setTileRaw(world, fx, fy, item);
        
        // Register as loot container
        if (CONTAINERS[item]) {
            var key = fx + "," + fy;
            world.containers[key] = { looted: false, tileType: item, districtType: distType };
        }
    }
}

function scatterDecorations(world) {
    for (var y = 0; y < world.height; y++) {
        for (var x = 0; x < world.width; x++) {
            var t = getTileRaw(world, x, y);
            if (t !== T.GRASS && t !== T.FARMLAND && t !== T.DIRT) continue;
            
            // Check district for density
            var dist = getDistrictAt(world, x, y);
            if (!dist) continue;
            var distDef = DISTRICTS[dist.type];
            var treeChance = distDef.treeDensity;
            
            var n = Utils.fbm(x * 0.1, y * 0.1, world.seed + 999, 3);
            if (n < treeChance) {
                setTileRaw(world, x, y, T.TREE);
            } else if (n < treeChance + 0.03) {
                setTileRaw(world, x, y, T.BUSH);
            } else if (n < treeChance + 0.04 && t === T.GRASS) {
                setTileRaw(world, x, y, T.FLOWER);
            }
        }
    }
    
    // Scatter cars on roads
    for (var y2 = 0; y2 < world.height; y2++) {
        for (var x2 = 0; x2 < world.width; x2++) {
            if (getTileRaw(world, x2, y2) === T.ROAD) {
                if (Utils.chance(0.015)) {
                    setTileRaw(world, x2, y2, T.CAR);
                }
            }
        }
    }
}

function getDistrictAt(world, x, y) {
    for (var i = 0; i < world.districts.length; i++) {
        var d = world.districts[i];
        if (x >= d.x && x < d.x + d.w && y >= d.y && y < d.y + d.h)
            return d;
    }
    return null;
}

function findSpawnPoint(world, grid, cellW, cellH) {
    // Find a residential district and spawn on a road/sidewalk near it
    for (var i = 0; i < world.districts.length; i++) {
        var d = world.districts[i];
        if (d.type === "RESIDENTIAL") {
            var sx = d.x + Math.floor(d.w / 2);
            var sy = d.y + Math.floor(d.h / 2);
            // Find nearest walkable tile
            for (var r = 0; r < 20; r++) {
                for (var dy = -r; dy <= r; dy++) {
                    for (var dx = -r; dx <= r; dx++) {
                        var tx = sx + dx, ty = sy + dy;
                        if (isWalkable(world, tx, ty)) {
                            world.spawnX = tx;
                            world.spawnY = ty;
                            return;
                        }
                    }
                }
            }
        }
    }
    // Fallback
    world.spawnX = Math.floor(world.width / 2);
    world.spawnY = Math.floor(world.height / 2);
}

// ─── Tile access ───
function getTileRaw(world, x, y) {
    if (x < 0 || y < 0 || x >= world.width || y >= world.height) return T.WALL;
    return world.tiles[y * world.width + x];
}

function setTileRaw(world, x, y, tile) {
    if (x < 0 || y < 0 || x >= world.width || y >= world.height) return;
    world.tiles[y * world.width + x] = tile;
}

function getTile(world, x, y) {
    if (x < 0 || y < 0 || x >= world.width || y >= world.height) return T.WALL;
    var key = x + "," + y;
    if (world.changes[key] !== undefined) return world.changes[key];
    return world.tiles[y * world.width + x];
}

function setTile(world, x, y, tile) {
    if (x < 0 || y < 0 || x >= world.width || y >= world.height) return;
    world.changes[x + "," + y] = tile;
}

function isWalkable(world, x, y) {
    var t = getTile(world, x, y);
    return !!WALKABLE[t];
}

function isAdjacentToDoor(world, x, y) {
    var offsets = [[1,0],[-1,0],[0,1],[0,-1]];
    for (var i = 0; i < offsets.length; i++) {
        var t = getTileRaw(world, x + offsets[i][0], y + offsets[i][1]);
        if (t === T.DOOR || t === T.DOOR_OPEN) return true;
    }
    return false;
}

function isDoor(world, x, y) {
    var t = getTile(world, x, y);
    return t === T.DOOR || t === T.DOOR_OPEN;
}

function isDoorOpen(world, x, y) {
    return getTile(world, x, y) === T.DOOR_OPEN;
}

function toggleDoor(world, x, y) {
    var t = getTile(world, x, y);
    if (t === T.DOOR) {
        setTile(world, x, y, T.DOOR_OPEN);
        return true;
    } else if (t === T.DOOR_OPEN) {
        setTile(world, x, y, T.DOOR);
        return false;
    }
    return null;
}
function isContainer(world, x, y) {
    var t = getTile(world, x, y);
    return !!CONTAINERS[t];
}

function getContainer(world, x, y) {
    return world.containers[x + "," + y] || null;
}

function isSolid(world, x, y) {
    return !isWalkable(world, x, y);
}

// ─── Serialization (for save/load) ───
function serialize(world) {
    return {
        seed: world.seed,
        width: world.width,
        height: world.height,
        changes: world.changes,
        containers: world.containers,
        spawnX: world.spawnX,
        spawnY: world.spawnY
    };
}

function deserialize(data) {
    // Regenerate base world from seed, then apply changes
    var world = generateWorld(data.seed, data.width, data.height);
    world.changes = data.changes || {};
    world.containers = data.containers || {};
    if (data.spawnX) world.spawnX = data.spawnX;
    if (data.spawnY) world.spawnY = data.spawnY;
    return world;
}