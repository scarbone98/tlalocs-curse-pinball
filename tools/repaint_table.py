"""Repaint the table art as Tlaloc's temple.

Reads the original layout art from tools/source_art/ (shapes only) and writes the
repainted layers used by the game:

  Sprites/map_f1.png  base layer: tezontle stone walls, Maya-blue plaza floor,
                      cenote pool, jade slingshots, gold trim
  Sprites/map_f2.png  overlay: turquoise water channels with gold rails

Every source pixel is classified (tools/table_classes.py) and repainted with the
new palette. Large-scale light and shadow from the source is kept so the walls
still read as raised, but the textures themselves (bricks, sand) are replaced.

Run from the repo root:  python3 tools/repaint_table.py
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).parent))
from table_classes import (  # noqa: E402
    BLUE, DIRT, DIRT_BOX, EMBER, FLOOR, FLOOR_DEEP, FLOOR_SHADOW, GOLD, JADE, ORANGE,
    OTHER, OUTLINE, RED, RIM, STONE, classify,
)

SRC = Path(__file__).parent / "source_art"
OUT = Path("Sprites")
SEED = 7


def hexc(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def shade(color, factor):
    return tuple(max(0, min(255, int(round(c * factor)))) for c in color)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def luma(rgb):
    return (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255


# --- palette -----------------------------------------------------------------
TEZONTLE = [hexc(c) for c in ("#5A2A36", "#66303D", "#4E2531", "#703844", "#613040")]
PORE_DARK = hexc("#3A1A24")
PORE_LIGHT = hexc("#8A4E57")
MORTAR = hexc("#2A1420")
GLYPH = hexc("#9A6468")

OBSIDIAN_DARK = hexc("#140B18")
OBSIDIAN = hexc("#2A1B33")
OBSIDIAN_LIGHT = hexc("#4A3560")

GOLD_LIGHT = hexc("#FFF1C2")
GOLD_HI = hexc("#F5D77A")
GOLD_MID = hexc("#D9A62E")
GOLD_DARK = hexc("#8A5F14")
GOLD_DEEP = hexc("#4A3208")

FLOOR_BASE = hexc("#244C78")
FLOOR_SHADE = hexc("#18375A")
FLOOR_DEEPEST = hexc("#0F2640")
FLOOR_RING = hexc("#3B72AA")

POOL_DEEP = hexc("#0B2F42")
POOL = hexc("#0F3D52")
POOL_RIPPLE = hexc("#2A7894")
LILY = hexc("#2F7D4B")
LILY_DARK = hexc("#1D5530")
LILY_FLOWER = hexc("#F2A7C3")

WATER = hexc("#2BB5C9")
WATER_DEEP = hexc("#1A86A3")
WATER_FOAM = hexc("#8BE6EE")

JADE_DARK = hexc("#15573F")
JADE_MID = hexc("#2E8B6A")
JADE_LIGHT = hexc("#6FD3A6")

SHRINE_DARK = hexc("#1B3F66")
SHRINE = hexc("#2F6FB0")
SHRINE_LIGHT = hexc("#6FB4E6")

# Face center in map pixels (center_face is at scene (337, 900))
FACE = (337 / (720 / 256), 900 / (1280 / 424))


# --- textures ----------------------------------------------------------------
def tezontle_texture(w, h, rng):
    """Large cut volcanic-stone blocks with pores; about one in five carries a carved glyph."""
    tex = Image.new("RGB", (w, h))
    px = tex.load()
    y = 0
    while y < h:
        row_h = rng.randint(14, 19)
        x = -rng.randint(0, 20)
        while x < w:
            block_w = rng.randint(22, 40)
            base = rng.choice(TEZONTLE)
            motif = rng.choice(MOTIFS) if rng.random() < 0.22 else None
            for by in range(row_h):
                for bx in range(block_w):
                    tx, ty = x + bx, y + by
                    if not (0 <= tx < w and 0 <= ty < h):
                        continue
                    if bx == 0 or by == 0:
                        px[tx, ty] = MORTAR
                        continue
                    c = base
                    roll = rng.random()
                    if roll < 0.05:
                        c = PORE_DARK
                    elif roll < 0.07:
                        c = PORE_LIGHT
                    if by == 1 or bx == 1:
                        c = shade(c, 1.14)
                    elif by == row_h - 1 or bx == block_w - 1:
                        c = shade(c, 0.82)
                    if motif:
                        carved = motif(bx - block_w / 2, by - row_h / 2, block_w, row_h)
                        if carved == 1:
                            c = GLYPH
                        elif carved == 2:
                            c = shade(base, 0.7)  # carved shadow under the relief
                    px[tx, ty] = c
            x += block_w
        y += row_h
    return tex


def _relief(inside, below):
    return 1 if inside else (2 if below else 0)


def chalchihuitl(dx, dy, w, h):
    """Jade symbol: a ring with a center dot."""
    d = math.hypot(dx, dy)
    d_up = math.hypot(dx, dy - 1)
    ring = lambda r: 3.2 <= r <= 4.4 or r <= 1.2
    return _relief(ring(d), ring(d_up))


def step_fret(dx, dy, w, h):
    """Xicalcoliuhqui: a stepped hook across the block."""
    def on(x, y):
        x, y = x + 9, y + 4
        if not (0 <= x < 18 and 0 <= y < 8):
            return False
        return (y == 0 and x < 12) or (x == 11 and y < 5) or (y == 4 and 5 <= x <= 11) or \
               (x == 5 and 2 <= y <= 4) or (y == 7 and x > 5) or (x == 17 and y > 2)
    return _relief(on(int(round(dx)), int(round(dy))), on(int(round(dx)), int(round(dy)) - 1))


def rain_marks(dx, dy, w, h):
    """Three falling rain strokes."""
    def on(x, y):
        return any(x == cx and -4 + i <= y <= 1 + i for i, cx in enumerate((-5, 0, 5)))
    return _relief(on(int(round(dx)), int(round(dy))), on(int(round(dx)), int(round(dy)) - 1))


MOTIFS = [chalchihuitl, step_fret, rain_marks]


def floor_color(x, y, cls, rng_tile):
    base = {FLOOR: FLOOR_BASE, FLOOR_SHADOW: FLOOR_SHADE, FLOOR_DEEP: FLOOR_DEEPEST}[cls]
    tile = 12
    tx, ty = x // tile, y // tile
    jitter = 1.0 + ((rng_tile[(tx, ty)] - 0.5) * 0.08)
    c = shade(base, jitter)
    if x % tile == 0 or y % tile == 0:
        c = shade(c, 0.86)
    # Sun-stone rings carved around the Tlaloc face
    d = math.hypot(x - FACE[0], (y - FACE[1]) * 1.07)
    for radius in (26, 34):
        if abs(d - radius) < 0.6:
            c = mix(c, FLOOR_RING, 0.8 if cls == FLOOR else 0.4)
    if 34 < d < 40:
        angle = math.atan2(y - FACE[1], x - FACE[0])
        if int((angle + math.pi) / (2 * math.pi) * 32) % 2 == 0 and abs(d - 37) < 1.2:
            c = mix(c, FLOOR_RING, 0.55 if cls == FLOOR else 0.25)
    return c


def pool_color(x, y, v, rng):
    c = mix(POOL_DEEP, POOL, max(0.0, min(1.0, (v - 0.3) * 2.2)))
    # a few clean ripple rings spreading from drip points
    for cx, cy in ((142, 140), (176, 160)):
        d = math.hypot(x - cx, (y - cy) * 1.6)
        for i, radius in enumerate((4, 9, 15)):
            if abs(d - radius) < 0.55:
                c = mix(c, POOL_RIPPLE, 0.75 - i * 0.2)
    return c


LILY_PADS = [(118, 128, 5), (180, 132, 4), (158, 176, 5), (132, 150, 3), (190, 168, 4)]


def lily_color(x, y):
    for cx, cy, r in LILY_PADS:
        dx, dy = x - cx, (y - cy) * 1.3
        d = math.hypot(dx, dy)
        if d <= r and not (dx > 0 and abs(dy) < 1.0):  # notch cut into each pad
            if d > r - 1:
                return LILY_DARK
            if (cx, cy) == (158, 176) and d < 1.5:
                return LILY_FLOWER
            return LILY
    return None


def ramp_by_luma(v, dark, mid, light):
    if v < 0.5:
        return mix(dark, mid, v / 0.5)
    return mix(mid, light, (v - 0.5) / 0.5)


# --- layers ------------------------------------------------------------------
def repaint_base(src):
    rng = random.Random(SEED)
    w, h = src.size
    sp = src.load()
    stone = tezontle_texture(w, h, rng).load()
    # large-scale light from the source walls, without its brick pattern
    light = src.convert("L").filter(ImageFilter.GaussianBlur(4)).load()
    tile_rng = random.Random(SEED + 1)
    tiles = {(tx, ty): tile_rng.random() for tx in range(w // 12 + 2) for ty in range(h // 12 + 2)}

    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            rgba = sp[x, y]
            rgb = rgba[:3]
            v = luma(rgb)
            cls = classify(rgb, (x, y))
            if cls == STONE:
                c = shade(stone[x, y], 0.75 + light[x, y] / 255 * 0.5)
            elif cls == OUTLINE:
                c = ramp_by_luma(v * 2.2, OBSIDIAN_DARK, OBSIDIAN, OBSIDIAN_LIGHT)
            elif cls == RIM:
                c = GOLD_HI if v > 0.95 else GOLD_MID
            elif cls in (FLOOR, FLOOR_SHADOW, FLOOR_DEEP):
                c = floor_color(x, y, cls, tiles)
            elif cls == DIRT:
                c = lily_color(x, y) or pool_color(x, y, v, rng)
            elif cls in (ORANGE, EMBER):
                c = WATER if v > 0.8 else WATER_DEEP
            elif cls == RED:
                c = ramp_by_luma(v, JADE_DARK, JADE_MID, JADE_LIGHT)
            elif cls == JADE:
                c = ramp_by_luma(v * 1.6, JADE_DARK, JADE_MID, JADE_LIGHT)
            elif cls == BLUE:
                c = ramp_by_luma(v, SHRINE_DARK, SHRINE, SHRINE_LIGHT)
                # Tlaloc's shrine at the Templo Mayor was painted in blue and white bands
                if x > 185 and y < 85 and (y // 4) % 3 == 0:
                    c = mix(c, (236, 244, 250), 0.8)
            elif cls == GOLD:
                c = GOLD_HI
            else:
                c = _other(rgb, v)
            op[x, y] = c + (rgba[3],)
    return out


def _other(rgb, v):
    r, g, b = rgb
    if g > r and g > b:  # green rail edges peeking out under the ramps
        return ramp_by_luma(v, GOLD_DEEP, GOLD_MID, GOLD_LIGHT)
    if b >= r:  # dark teal pockets
        return OBSIDIAN
    return ramp_by_luma(v, OBSIDIAN_DARK, OBSIDIAN, OBSIDIAN_LIGHT)


TOP_MAP = {
    "#F8A008": WATER, "#D07808": WATER_DEEP,
    "#105808": GOLD_DEEP, "#089810": GOLD_DARK, "#18B818": GOLD_MID, "#28D820": GOLD_HI,
    "#D0F8D0": GOLD_LIGHT, "#88D890": GOLD_HI,
    "#F0F090": GOLD_LIGHT, "#F8D000": GOLD_HI, "#C8A000": GOLD_MID, "#605000": GOLD_DEEP,
    "#183880": OBSIDIAN,
}


def repaint_top(src):
    w, h = src.size
    sp = src.load()
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a == 0:
                op[x, y] = (0, 0, 0, 0)
                continue
            key = "#%02X%02X%02X" % (r, g, b)
            c = TOP_MAP.get(key)
            if c is None:
                c = WATER
            if c == WATER and (x * 2 + y) % 11 == 0:
                c = WATER_FOAM  # flowing streaks down the channels
            op[x, y] = c + (a,)
    return out


def main():
    base = Image.open(SRC / "map_f1.png").convert("RGBA")
    top = Image.open(SRC / "map_f2.png").convert("RGBA")
    repaint_base(base).save(OUT / "map_f1.png")
    repaint_top(top).save(OUT / "map_f2.png")
    print("wrote Sprites/map_f1.png and Sprites/map_f2.png")


if __name__ == "__main__":
    main()
