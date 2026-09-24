"""Generate sprites for the table modes: kickback frogs and the water spirit.

Drawn at the table art's native resolution with colors taken from map_f1.png and
the existing lamp sprites, so the scene can scale them by MAP_SCALE onto the same
pixel grid. Run from the repo root:  python3 tools/make_mode_sprites.py

  Sprites/table/kickback_frog.png   3 frames: stone (uncharged), jade (charged), leap
  Sprites/table/spirit.png          3 frames: ajolote water spirit idle x2, hit flash
  Sprites/table/ripple.png          4 frames: water ring the spirit rises from / sinks into
"""
import math
from pathlib import Path

from PIL import Image

OUT_DIR = Path("Sprites/table")
T = (0, 0, 0, 0)


def rgba(hex_color, alpha=255):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


# Obsidian and gold match the arrow inserts; jade and water come from the table art
OBSIDIAN_O = rgba("#140B18")
OBSIDIAN_D = rgba("#2A1B33")
OBSIDIAN = rgba("#4A3560")
GOLD = rgba("#F8D000")
ORANGE = rgba("#F8A008")
CREAM = rgba("#FFF1C2")
JADE_DD = rgba("#1C3F35")
JADE_D = rgba("#255C4B")
JADE = rgba("#337761")
JADE_L = rgba("#409F7A")
DEEP = rgba("#0D374B")
WATER = rgba("#1A86A3")
WATER_L = rgba("#8BE6EE")
FOAM = rgba("#DEF1EE")


def from_rows(rows, key):
    img = Image.new("RGBA", (len(rows[0]), len(rows)), T)
    for y, row in enumerate(rows):
        assert len(row) == len(rows[0]), (y, row)
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), key[ch])
    return img


def strip(frames):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), T)
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * w, 0))
    return sheet


# --- kickback frog statue ----------------------------------------------------
# Sits at the foot of each outlane. Dark obsidian until the frogs in the pool
# charge it, then it wakes up jade with gold eyes and leaps to kick the ball back.
FROG_SIT = [
    "............",
    "............",
    "..oo....oo..",
    ".oeeo..oeeo.",
    ".oSHooooHSo.",
    "oSHSSSSSSSSo",
    "oSsSSSSSSsSo",
    "oSSSmmmmSSSo",
    ".oSSSSSSSSo.",
    "oSoSSssSSoSo",
    "oSSooooooSSo",
    ".oo......oo.",
]
FROG_LEAP = [
    "..oo....oo..",
    ".oeeo..oeeo.",
    ".oSHooooHSo.",
    "oSHSSSSSSSSo",
    "oSsSSSSSSsSo",
    "oSSSmmmmSSSo",
    ".oSSSSSSSSo.",
    "..oSSssSSo..",
    "..oSo..oSo..",
    "..oSo..oSo..",
    ".oSSo..oSSo.",
    ".ooo....ooo.",
]
FROG_STONE = {"o": OBSIDIAN_O, "S": OBSIDIAN_D, "H": OBSIDIAN, "s": OBSIDIAN_O, "m": OBSIDIAN_O, "e": JADE_DD}
FROG_AWAKE = {"o": OBSIDIAN_O, "S": JADE, "H": JADE_L, "s": JADE_D, "m": JADE_DD, "e": GOLD}


# --- ajolote water spirit ----------------------------------------------------
# Front-on axolotl with frond gills, rising out of the temple floor like water
SPIRIT = [
    "g................g",
    "gg..oooooooooo..gg",
    ".gooCCCCCCCCCCoog.",
    "ggoCLLCCCCCCCCCogg",
    ".goCkwCCCCCCkwCog.",
    "ggoCkkCCCCCCkkCogg",
    "g.oCCCCmCCmCCCCo.g",
    "...oCCCCmmCCCCo...",
    "....ooCCCCCCoo....",
    "...oCCoCCCCoCCo...",
    "...oooooCCooooo...",
    "........oo........",
]
SPIRIT_KEY = {"o": DEEP, "C": WATER_L, "L": FOAM, "k": OBSIDIAN_O, "w": CREAM, "m": DEEP, "g": ORANGE}
SPIRIT_KEY_ALT = dict(SPIRIT_KEY, g=GOLD)  # gills shimmer between frames
SPIRIT_KEY_HIT = dict(SPIRIT_KEY, o=GOLD, C=CREAM, L=FOAM, m=ORANGE, g=GOLD)


def ripple_frame(i):
    w, h = 22, 8
    img = Image.new("RGBA", (w, h), T)
    rx = [3.0, 6.0, 8.5, 10.5][i]
    alpha = [255, 230, 170, 100][i]
    ring, inner = rgba("#DEF1EE", alpha), rgba("#8BE6EE", alpha)
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5 - w / 2) / rx, (y + 0.5 - h / 2) / (rx * 0.36)
            d = math.hypot(dx, dy)
            if abs(d - 1.0) < 0.5 / max(1.0, rx * 0.36):
                img.putpixel((x, y), ring)
            elif i < 3 and abs(d - 0.6) < 0.4 / max(1.0, rx * 0.36):
                img.putpixel((x, y), inner)
    return img


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    strip([from_rows(FROG_SIT, FROG_STONE), from_rows(FROG_SIT, FROG_AWAKE), from_rows(FROG_LEAP, FROG_AWAKE)]).save(
        OUT_DIR / "kickback_frog.png")
    strip([from_rows(SPIRIT, SPIRIT_KEY), from_rows(SPIRIT, SPIRIT_KEY_ALT), from_rows(SPIRIT, SPIRIT_KEY_HIT)]).save(
        OUT_DIR / "spirit.png")
    strip([ripple_frame(i) for i in range(4)]).save(OUT_DIR / "ripple.png")
    print("wrote kickback frog, spirit and ripple sprites")


if __name__ == "__main__":
    main()
