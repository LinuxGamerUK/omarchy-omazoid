// Utils.js — PRNG, noise, math helpers
.pragma library

// ─── Seeded PRNG (Linear Congruential Generator) ───
var _seed = 12345;

function setSeed(s) {
    _seed = (s | 0) || 12345;
    if (_seed < 0) _seed = -_seed;
}

function rand() {
    _seed = (Math.imul(_seed, 1103515245) + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
}

function randInt(min, max) {
    return Math.floor(rand() * (max - min + 1)) + min;
}

function randFloat(min, max) {
    return rand() * (max - min) + min;
}

function randChoice(arr) {
    return arr[Math.floor(rand() * arr.length)];
}

function chance(p) {
    return rand() < p;
}

// ─── Hash-based noise (seeded, deterministic) ───
function _hash(x, y, seed) {
    var h = seed | 0;
    h = Math.imul(h ^ (x | 0), 374761393);
    h = Math.imul(h ^ (y | 0), 668265263);
    h = (h ^ (h >>> 13)) >>> 0;
    h = Math.imul(h, 1274126177);
    h = (h ^ (h >>> 16)) >>> 0;
    return h / 4294967295;
}

function noise2D(x, y, seed) {
    var x0 = Math.floor(x);
    var y0 = Math.floor(y);
    var sx = x - x0;
    var sy = y - y0;
    var n00 = _hash(x0, y0, seed);
    var n10 = _hash(x0 + 1, y0, seed);
    var n01 = _hash(x0, y0 + 1, seed);
    var n11 = _hash(x0 + 1, y0 + 1, seed);
    var sx2 = sx * sx * (3 - 2 * sx);
    var sy2 = sy * sy * (3 - 2 * sy);
    var nx0 = n00 + (n10 - n00) * sx2;
    var nx1 = n01 + (n11 - n01) * sx2;
    return nx0 + (nx1 - nx0) * sy2;
}

// Fractal noise (octaves of value noise)
function fbm(x, y, seed, octaves) {
    var val = 0;
    var amp = 0.5;
    var freq = 1;
    for (var i = 0; i < (octaves || 4); i++) {
        val += noise2D(x * freq, y * freq, seed + i * 1013) * amp;
        freq *= 2;
        amp *= 0.5;
    }
    return val;
}

// ─── Math helpers ───
function clamp(v, min, max) {
    return v < min ? min : (v > max ? max : v);
}

function lerp(a, b, t) {
    return a + (b - a) * t;
}

function dist(x1, y1, x2, y2) {
    var dx = x2 - x1, dy = y2 - y1;
    return Math.sqrt(dx * dx + dy * dy);
}

function distSq(x1, y1, x2, y2) {
    var dx = x2 - x1, dy = y2 - y1;
    return dx * dx + dy * dy;
}

function angleTo(x1, y1, x2, y2) {
    return Math.atan2(y2 - y1, x2 - x1);
}

function angleDiff(a, b) {
    var d = b - a;
    while (d > Math.PI) d -= 2 * Math.PI;
    while (d < -Math.PI) d += 2 * Math.PI;
    return d;
}

function normalizeAngle(a) {
    while (a > Math.PI) a -= 2 * Math.PI;
    while (a < -Math.PI) a += 2 * Math.PI;
    return a;
}

function approach(current, target, delta) {
    if (current < target) return Math.min(current + delta, target);
    if (current > target) return Math.max(current - delta, target);
    return current;
}

// ─── Color helpers ───
function parseHex(hex) {
    return {
        r: parseInt(hex.substr(1, 2), 16),
        g: parseInt(hex.substr(3, 2), 16),
        b: parseInt(hex.substr(5, 2), 16)
    };
}

function rgbStr(r, g, b) {
    return "rgb(" + Math.round(r) + "," + Math.round(g) + "," + Math.round(b) + ")";
}

function rgbaStr(r, g, b, a) {
    return "rgba(" + Math.round(r) + "," + Math.round(g) + "," + Math.round(b) + "," + a + ")";
}

function tint(color, factor) {
    var c = parseHex(color);
    return rgbStr(c.r * factor, c.g * factor, c.b * factor);
}

function blend(c1, c2, t) {
    var a = parseHex(c1), b = parseHex(c2);
    return rgbStr(lerp(a.r, b.r, t), lerp(a.g, b.g, t), lerp(a.b, b.b, t));
}

// ─── Time helpers ───
// 24 game hours = 1 real hour => 1 real second = 24/3600 game hours = 0.00667 game hours
// 1 real minute = 24/60 = 0.4 game hours = 24 game minutes
var GAME_TIME_SCALE = 24.0 / 3600.0; // game hours per real second

function gameHoursToTimeString(hours) {
    var h = Math.floor(hours) % 24;
    var m = Math.floor((hours - Math.floor(hours)) * 60);
    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
}

function isNightTime(hours) {
    return hours < 6.5 || hours > 19.5;
}

function nightFactor(hours) {
    // 0 = full daylight, 1 = full night
    // Day: 7:00 - 19:00, transitions at dawn/dusk
    if (hours >= 8 && hours <= 18) return 0;
    if (hours >= 20 || hours <= 5) return 1;
    if (hours > 5 && hours < 8) return clamp((8 - hours) / 3, 0, 1);
    if (hours > 18 && hours < 20) return clamp((hours - 18) / 2, 0, 1);
    return 0;
}