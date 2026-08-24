// Items.js — Item definitions, weapons, loot tables
.pragma library

.import "Utils.js" as Utils

// ─── Item categories ───
var CAT = {
    WEAPON_MELEE: "melee",
    WEAPON_RANGED: "ranged",
    FOOD: "food",
    DRINK: "drink",
    TOOL: "tool",
    MATERIAL: "material",
    MEDICAL: "medical",
    AMMO: "ammo",
    CLOTHING: "clothing"
};

// ─── Weapon definitions ───
var WEAPONS = {
    "fists": {
        id: "fists", name: "Bare Fists", cat: CAT.WEAPON_MELEE,
        damage: 5, range: 28, attackSpeed: 0.35, knockback: 2,
        durability: -1, noise: 5
    },
    "frying_pan": {
        id: "frying_pan", name: "Frying Pan", cat: CAT.WEAPON_MELEE,
        damage: 15, range: 32, attackSpeed: 0.5, knockback: 4,
        durability: 100, noise: 15
    },
    "baseball_bat": {
        id: "baseball_bat", name: "Baseball Bat", cat: CAT.WEAPON_MELEE,
        damage: 25, range: 38, attackSpeed: 0.6, knockback: 8,
        durability: 150, noise: 20
    },
    "kitchen_knife": {
        id: "kitchen_knife", name: "Kitchen Knife", cat: CAT.WEAPON_MELEE,
        damage: 20, range: 30, attackSpeed: 0.35, knockback: 3,
        durability: 80, noise: 10
    },
    "axe": {
        id: "axe", name: "Axe", cat: CAT.WEAPON_MELEE,
        damage: 40, range: 35, attackSpeed: 0.8, knockback: 10,
        durability: 200, noise: 25
    },
    "crowbar": {
        id: "crowbar", name: "Crowbar", cat: CAT.WEAPON_MELEE,
        damage: 30, range: 36, attackSpeed: 0.65, knockback: 7,
        durability: 300, noise: 18
    },
    "hammer": {
        id: "hammer", name: "Hammer", cat: CAT.WEAPON_MELEE,
        damage: 22, range: 30, attackSpeed: 0.5, knockback: 6,
        durability: 200, noise: 15
    },
    "machete": {
        id: "machete", name: "Machete", cat: CAT.WEAPON_MELEE,
        damage: 35, range: 36, attackSpeed: 0.45, knockback: 5,
        durability: 180, noise: 12
    },
    "pistol": {
        id: "pistol", name: "Pistol", cat: CAT.WEAPON_RANGED,
        damage: 35, range: 300, attackSpeed: 0.4, knockback: 5,
        durability: -1, noise: 60, ammoType: "pistol_ammo", magSize: 12
    },
    "shotgun": {
        id: "shotgun", name: "Shotgun", cat: CAT.WEAPON_RANGED,
        damage: 60, range: 150, attackSpeed: 0.9, knockback: 15,
        durability: -1, noise: 80, ammoType: "shotgun_ammo", magSize: 6,
        pellets: 5, spread: 0.3
    },
    "rifle": {
        id: "rifle", name: "Hunting Rifle", cat: CAT.WEAPON_RANGED,
        damage: 80, range: 500, attackSpeed: 1.2, knockback: 8,
        durability: -1, noise: 70, ammoType: "rifle_ammo", magSize: 5
    }
};

// ─── Food items ───
var FOODS = {
    "canned_beans": { id: "canned_beans", name: "Canned Beans", cat: CAT.FOOD, hunger: 30, perishable: false, weight: 0.5 },
    "canned_soup": { id: "canned_soup", name: "Canned Soup", cat: CAT.FOOD, hunger: 25, perishable: false, weight: 0.4 },
    "chips": { id: "chips", name: "Bag of Chips", cat: CAT.FOOD, hunger: 15, perishable: false, weight: 0.2 },
    "bread": { id: "bread", name: "Bread", cat: CAT.FOOD, hunger: 20, perishable: true, weight: 0.3 },
    "apple": { id: "apple", name: "Apple", cat: CAT.FOOD, hunger: 10, thirst: 5, perishable: true, weight: 0.1 },
    "chocolate": { id: "chocolate", name: "Chocolate Bar", cat: CAT.FOOD, hunger: 15, perishable: false, weight: 0.1 },
    "cereal": { id: "cereal", name: "Cereal Box", cat: CAT.FOOD, hunger: 35, perishable: false, weight: 0.5 },
    "canned_tuna": { id: "canned_tuna", name: "Canned Tuna", cat: CAT.FOOD, hunger: 20, perishable: false, weight: 0.3 }
};

// ─── Drink items ───
var DRINKS = {
    "water_bottle": { id: "water_bottle", name: "Water Bottle", cat: CAT.DRINK, thirst: 30, weight: 0.5 },
    "soda": { id: "soda", name: "Soda Can", cat: CAT.DRINK, thirst: 20, hunger: 5, weight: 0.3 },
    "juice": { id: "juice", name: "Orange Juice", cat: CAT.DRINK, thirst: 25, weight: 0.5 }
};

// ─── Tools ───
var TOOLS = {
    "hammer_tool": { id: "hammer_tool", name: "Hammer", cat: CAT.TOOL, weight: 1.0 },
    "saw": { id: "saw", name: "Saw", cat: CAT.TOOL, weight: 0.8 },
    "screwdriver": { id: "screwdriver", name: "Screwdriver", cat: CAT.TOOL, weight: 0.3 },
    "flashlight": { id: "flashlight", name: "Flashlight", cat: CAT.TOOL, weight: 0.5 },
    "lighter": { id: "lighter", name: "Lighter", cat: CAT.TOOL, weight: 0.1 },
    "can_opener": { id: "can_opener", name: "Can Opener", cat: CAT.TOOL, weight: 0.2 },
    "bandage": { id: "bandage", name: "Bandage", cat: CAT.MEDICAL, healing: 15, weight: 0.1 },
    "painkillers": { id: "painkillers", name: "Painkillers", cat: CAT.MEDICAL, healing: 10, weight: 0.1 },
    "antibiotics": { id: "antibiotics", name: "Antibiotics", cat: CAT.MEDICAL, curesInfection: true, weight: 0.1 },
    "first_aid_kit": { id: "first_aid_kit", name: "First Aid Kit", cat: CAT.MEDICAL, healing: 40, weight: 1.0 }
};

// ─── Materials ───
var MATERIALS = {
    "wood_plank": { id: "wood_plank", name: "Wood Plank", cat: CAT.MATERIAL, weight: 0.5, stackable: true, maxStack: 50 },
    "nails": { id: "nails", name: "Box of Nails", cat: CAT.MATERIAL, weight: 0.3, stackable: true, maxStack: 100 },
    "metal_scrap": { id: "metal_scrap", name: "Metal Scrap", cat: CAT.MATERIAL, weight: 0.5, stackable: true, maxStack: 50 },
    "rope": { id: "rope", name: "Rope", cat: CAT.MATERIAL, weight: 0.3, stackable: true, maxStack: 10 },
    "duct_tape": { id: "duct_tape", name: "Duct Tape", cat: CAT.MATERIAL, weight: 0.2, stackable: true, maxStack: 20 },
    "sheet": { id: "sheet", name: "Sheet", cat: CAT.MATERIAL, weight: 0.3, stackable: true, maxStack: 10 }
};

// ─── Ammo ───
var AMMO = {
    "pistol_ammo": { id: "pistol_ammo", name: "Pistol Ammo", cat: CAT.AMMO, weight: 0.1, stackable: true, maxStack: 100 },
    "shotgun_ammo": { id: "shotgun_ammo", name: "Shotgun Shells", cat: CAT.AMMO, weight: 0.15, stackable: true, maxStack: 50 },
    "rifle_ammo": { id: "rifle_ammo", name: "Rifle Ammo", cat: CAT.AMMO, weight: 0.1, stackable: true, maxStack: 50 }
};

// ─── Build recipes (crafting / fortification) ───
// tile values mirror World.T so the engine stays in sync with the tile set.
var RECIPES = {
    "barricade": {
        id: "barricade", name: "Barricade",
        tile: 26,            // World.T.BARRICADE — solid barrier, zombies beat it down
        materials: { wood_plank: 3, nails: 2 },
        hp: 100, blocks: true
    },
    "barbed_wire": {
        id: "barbed_wire", name: "Barbed Wire",
        tile: 35,            // World.T.BARBED_WIRE — passable, shreds zombies walking through
        materials: { metal_scrap: 2 },
        hp: 60, blocks: false, damagePerSecond: 6
    }
};

// ─── All items registry ───
var ALL_ITEMS = {};
function _register(obj) {
    for (var k in obj) ALL_ITEMS[k] = obj[k];
}
_register(WEAPONS);
_register(FOODS);
_register(DRINKS);
_register(TOOLS);
_register(MATERIALS);
_register(AMMO);

function getItem(id) {
    return ALL_ITEMS[id] || null;
}

function isWeapon(item) {
    return item && (item.cat === CAT.WEAPON_MELEE || item.cat === CAT.WEAPON_RANGED);
}

function isRangedWeapon(item) {
    return item && item.cat === CAT.WEAPON_RANGED;
}

// ─── Loot tables ───
// Quality levels: 1 (common/residential), 2 (commercial), 3 (downtown),
// 4 (hospital), 5 (military)
var LOOT_TABLES = {
    // Common loot (residential, farm, park)
    1: [
        { id: "canned_beans", chance: 0.3 }, { id: "canned_soup", chance: 0.25 },
        { id: "chips", chance: 0.2 }, { id: "bread", chance: 0.15 },
        { id: "apple", chance: 0.1 }, { id: "chocolate", chance: 0.15 },
        { id: "water_bottle", chance: 0.3 }, { id: "soda", chance: 0.2 },
        { id: "kitchen_knife", chance: 0.1 }, { id: "frying_pan", chance: 0.08 },
        { id: "hammer", chance: 0.05 }, { id: "bandage", chance: 0.15 },
        { id: "painkillers", chance: 0.1 }, { id: "wood_plank", chance: 0.2 },
        { id: "nails", chance: 0.15 }, { id: "rope", chance: 0.08 },
        { id: "duct_tape", chance: 0.1 }, { id: "sheet", chance: 0.1 },
        { id: "can_opener", chance: 0.05 }, { id: "lighter", chance: 0.08 },
        { id: "cereal", chance: 0.15 }, { id: "canned_tuna", chance: 0.2 },
        { id: "baseball_bat", chance: 0.04 }, { id: "flashlight", chance: 0.06 }
    ],
    // Commercial
    2: [
        { id: "canned_beans", chance: 0.25 }, { id: "canned_soup", chance: 0.2 },
        { id: "chips", chance: 0.3 }, { id: "chocolate", chance: 0.25 },
        { id: "water_bottle", chance: 0.35 }, { id: "soda", chance: 0.4 },
        { id: "juice", chance: 0.2 }, { id: "kitchen_knife", chance: 0.08 },
        { id: "crowbar", chance: 0.06 }, { id: "bandage", chance: 0.12 },
        { id: "painkillers", chance: 0.1 }, { id: "nails", chance: 0.15 },
        { id: "duct_tape", chance: 0.15 }, { id: "pistol_ammo", chance: 0.05 },
        { id: "lighter", chance: 0.1 }, { id: "canned_tuna", chance: 0.15 },
        { id: "baseball_bat", chance: 0.06 }, { id: "screwdriver", chance: 0.1 },
        { id: "first_aid_kit", chance: 0.04 }, { id: "metal_scrap", chance: 0.15 }
    ],
    // Downtown
    3: [
        { id: "canned_beans", chance: 0.2 }, { id: "cereal", chance: 0.15 },
        { id: "water_bottle", chance: 0.25 }, { id: "soda", chance: 0.25 },
        { id: "pistol", chance: 0.04 }, { id: "pistol_ammo", chance: 0.12 },
        { id: "crowbar", chance: 0.08 }, { id: "axe", chance: 0.05 },
        { id: "machete", chance: 0.04 }, { id: "bandage", chance: 0.15 },
        { id: "painkillers", chance: 0.12 }, { id: "first_aid_kit", chance: 0.06 },
        { id: "metal_scrap", chance: 0.2 }, { id: "nails", chance: 0.18 },
        { id: "duct_tape", chance: 0.18 }, { id: "hammer_tool", chance: 0.08 },
        { id: "saw", chance: 0.06 }, { id: "screwdriver", chance: 0.1 },
        { id: "flashlight", chance: 0.08 }, { id: "rope", chance: 0.1 }
    ],
    // Hospital
    4: [
        { id: "bandage", chance: 0.5 }, { id: "painkillers", chance: 0.4 },
        { id: "first_aid_kit", chance: 0.2 }, { id: "antibiotics", chance: 0.08 },
        { id: "water_bottle", chance: 0.2 }, { id: "juice", chance: 0.15 },
        { id: "soda", chance: 0.1 }, { id: "pistol_ammo", chance: 0.05 },
        { id: "metal_scrap", chance: 0.1 }, { id: "duct_tape", chance: 0.1 },
        { id: "screwdriver", chance: 0.06 }, { id: "can_opener", chance: 0.05 }
    ],
    // Military
    5: [
        { id: "pistol", chance: 0.15 }, { id: "shotgun", chance: 0.08 },
        { id: "rifle", chance: 0.06 }, { id: "pistol_ammo", chance: 0.4 },
        { id: "shotgun_ammo", chance: 0.25 }, { id: "rifle_ammo", chance: 0.2 },
        { id: "first_aid_kit", chance: 0.2 }, { id: "antibiotics", chance: 0.1 },
        { id: "bandage", chance: 0.3 }, { id: "axe", chance: 0.08 },
        { id: "machete", chance: 0.1 }, { id: "metal_scrap", chance: 0.25 },
        { id: "nails", chance: 0.2 }, { id: "rope", chance: 0.15 },
        { id: "duct_tape", chance: 0.15 }, { id: "canned_beans", chance: 0.2 },
        { id: "canned_tuna", chance: 0.2 }, { id: "water_bottle", chance: 0.2 }
    ]
};

// Fridge-specific loot
var FRIDGE_LOOT = [
    { id: "water_bottle", chance: 0.4 }, { id: "soda", chance: 0.3 },
    { id: "juice", chance: 0.2 }, { id: "apple", chance: 0.25 },
    { id: "bread", chance: 0.15 }, { id: "canned_tuna", chance: 0.1 }
];

function generateLoot(qualityLevel, containerType, districtType) {
    Utils.setSeed(Date.now() + Math.random() * 1000000);
    var items = [];
    
    if (containerType === 20) { // FRIDGE
        for (var i = 0; i < FRIDGE_LOOT.length; i++) {
            if (Utils.chance(FRIDGE_LOOT[i].chance)) {
                items.push({ id: FRIDGE_LOOT[i].id, count: 1 });
            }
        }
        return items;
    }
    
    var table = LOOT_TABLES[qualityLevel] || LOOT_TABLES[1];
    var numItems = Utils.randInt(1, 4);
    
    for (var j = 0; j < numItems; j++) {
        for (var k = 0; k < table.length; k++) {
            if (Utils.chance(table[k].chance)) {
                var existing = items.find(function(it) { return it.id === table[k].id; });
                if (existing) {
                    existing.count++;
                } else {
                    items.push({ id: table[k].id, count: 1 });
                }
                break;
            }
        }
    }
    
    return items;
}