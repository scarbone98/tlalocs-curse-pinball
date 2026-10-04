"""Generate sprites for the table modes: kickback frogs and the water spirit.

Drawn at the table art's native resolution with colors taken from map_f1.png and
the existing lamp sprites, so the scene can scale them by MAP_SCALE onto the same
pixel grid. Run from the repo root:  python3 tools/make_mode_sprites.py

  Sprites/table/kickback_frog.png   3 frames (18x15): stone (uncharged), jade (charged), leap
  Sprites/table/spirit.png          3 frames: ajolote water spirit idle x2, hit flash
"""
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
# Drawn as its left half (9 columns), mirrored: bulging eyes with pupils (a glint in the
# left one), a wide mouth, a pale throat, front feet with toes, haunches, spots on its back
FROG_SIT = [
    "...ooo...",
    "..oeeeo..",
    ".oewpeoo.",
    ".oeeppoHo",
    ".ooeeoHHH",
    "oHHooHHHH",
    "oHSSSHSSS",
    "oSSdSSSSS",
    "oSSSmmmmm",
    ".oSSSbbbb",
    "oSsoSbbbb",
    "osSsoSbbb",
    "ostto.oSs",
    ".oooo..oo",
    ".........",
]
FROG_LEAP = [  # stretched up off its pad, its back legs out under it
    "...ooo...",
    "..oeeeo..",
    ".oewpeoo.",
    ".oeeppoHo",
    ".ooeeoHHH",
    "oHHooHHHH",
    "oHSSSHSSS",
    "oSSdSSSSS",
    ".oSSmmmmm",
    "..oSSbbbb",
    ".oSsoSbbb",
    "oSso.oSSs",
    "osso..oSs",
    "otto...oo",
    "oooo.....",
]
FROG_SPOTS = [(6, 7), (11, 6), (12, 8)]  # dark spots on its back, a little off true
FROG_STONE = {"o": OBSIDIAN_O, "H": rgba("#5A4472"), "S": rgba("#3C2A50"), "s": OBSIDIAN_D, "d": OBSIDIAN_D,
              "e": JADE_DD, "p": OBSIDIAN_O, "w": JADE_D, "m": OBSIDIAN_O, "b": OBSIDIAN, "t": OBSIDIAN_D}
FROG_AWAKE = {"o": rgba("#0E2A22"), "H": rgba("#62C496"), "S": JADE_L, "s": rgba("#2C6E56"), "d": JADE_D,
              "e": GOLD, "p": OBSIDIAN_O, "w": CREAM, "m": rgba("#0E2A22"), "b": rgba("#9ADFB4"), "t": ORANGE}


def frog(half, key):
    w, h = len(half[0]) * 2, len(half)
    img = Image.new("RGBA", (w, h), T)
    for y, row in enumerate(half):
        assert len(row) == len(half[0]), (y, row)
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            img.putpixel((x, y), key[ch])
            img.putpixel((w - 1 - x, y), key["e"] if ch == "w" else key[ch])  # the glint only in one eye
    for x, y in FROG_SPOTS:
        if img.getpixel((x, y))[3]:
            img.putpixel((x, y), key["d"])
    return img


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


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    strip([frog(FROG_SIT, FROG_STONE), frog(FROG_SIT, FROG_AWAKE), frog(FROG_LEAP, FROG_AWAKE)]).save(
        OUT_DIR / "kickback_frog.png")
    strip([from_rows(SPIRIT, SPIRIT_KEY), from_rows(SPIRIT, SPIRIT_KEY_ALT), from_rows(SPIRIT, SPIRIT_KEY_HIT)]).save(
        OUT_DIR / "spirit.png")
    print("wrote kickback frog and spirit sprites")


if __name__ == "__main__":
    main()
