"""Generate playfield feature sprites for Tlaloc's Curse.

Sprites are drawn at the table art's native resolution (map_f1.png is 256x424)
using colors sampled from it, so they share its pixel grid once the scene scales
them up. Run from the repo root:  python3 tools/make_table_sprites.py
"""
from pathlib import Path

from PIL import Image

OUT_DIR = Path("Sprites/table")

# Sampled from Sprites/map_f1.png
T = (0, 0, 0, 0)
OUTLINE = (0x32, 0x4A, 0x68, 255)
STONE_D = (0x57, 0x6E, 0x78, 255)
STONE = (0x74, 0x8C, 0x9A, 255)
JADE_DD = (0x1C, 0x3F, 0x35, 255)
JADE_D = (0x25, 0x5C, 0x4B, 255)
JADE = (0x33, 0x77, 0x61, 255)
GREEN = (0x1E, 0xB6, 0x21, 255)
GOLD = (0xF8, 0xD0, 0x00, 255)
ORANGE = (0xF8, 0xA0, 0x08, 255)
EMBER = (0xBE, 0x56, 0x2E, 255)
PALE = (0xF0, 0xF0, 0x90, 255)
WHITE = (0xDE, 0xF1, 0xEE, 255)
BLUE = (0x09, 0x83, 0xD1, 255)
BLUE_D = (0x18, 0x42, 0x88, 255)
RAIN = (0xA8, 0xD8, 0xF8, 255)


def glow(color, alpha):
    return (color[0], color[1], color[2], alpha)


def from_rows(rows, key):
    """Build an image from a list of strings, one char per pixel."""
    img = Image.new("RGBA", (len(rows[0]), len(rows)), T)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            img.putpixel((x, y), key[ch])
    return img


def strip(frames):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), T)
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * w, 0))
    return sheet


# Round lane lamp: fills the empty circle inserts painted on the table.
LAMP_UNLIT = [
    "....ooooo....",
    "...oJJJJJo...",
    "..oJjjjjjdo..",
    ".oJjjjjjjjdo.",
    ".oJjjjjjjjdo.",
    ".oJjjjjjjjdo.",
    ".oJjjjjjjjdo.",
    ".oJjjjjjjjdo.",
    ".oJjjjjjjddo.",
    "..odddddddo..",
    "...oddddddo..",
    "....ooooo....",
    ".............",
]
LAMP_LIT = [
    "...ggggggg...",
    "..gooooooog..",
    ".goPPPGGGGog.",
    "gowPPPGGGGGog",
    "goPPPGGGGGGog",
    "goPPGGGGGGOog",
    "goGGGGGGGGOog",
    "goGGGGGGGOOog",
    "goGGGGGGOOOog",
    ".goOOOOOOOog.",
    "..goOOOOOog..",
    "...gooooog...",
    "....ggggg....",
]
LAMP_KEY = {
    ".": T, "o": OUTLINE, "J": JADE, "j": JADE_D, "d": JADE_DD,
    "G": GOLD, "O": ORANGE, "P": PALE, "w": WHITE, "g": glow(GOLD, 90),
}

# Multiplier bank light: matches the five green bars above the flippers.
BAR_UNLIT = [
    "oooooo",
    "oJJJjo",
    "oJjjdo",
    "oJjjdo",
    "oJjjdo",
    "oJjjdo",
    "oJjjdo",
    "oJjjdo",
    "oJjjdo",
    "oJjjdo",
    "ojdddo",
    "oooooo",
]
BAR_LIT = [
    "oooooo",
    "owPPGo",
    "oPPGGo",
    "oPGGGo",
    "oGGGGo",
    "oGGGGo",
    "oGGGOo",
    "oGGGOo",
    "oGGOOo",
    "oGOOOo",
    "oOOOEo",
    "oooooo",
]
BAR_KEY = dict(LAMP_KEY, E=EMBER)

# Arrow inserts: the small white rectangles that point at the orbits and ramps.
# Obsidian when off, gold when lit, so they read on the Maya-blue temple floor
ARROW_UNLIT = [
    ".ooo.",
    "oSSSo",
    "oSsso",
    "oSsso",
    "oSsso",
    "oSsso",
    "ossso",
    ".ooo.",
]
ARROW_LIT = [
    ".ooo.",
    "owwBo",
    "owBBo",
    "oBBBo",
    "oBBBo",
    "oBBbo",
    "oBbbo",
    ".ooo.",
]
ARROW_KEY = {
    ".": T, "o": (0x14, 0x0B, 0x18, 255), "S": (0x4A, 0x35, 0x60, 255), "s": (0x2A, 0x1B, 0x33, 255),
    "w": (0xFF, 0xF1, 0xC2, 255), "B": GOLD, "b": ORANGE,
}

# Temple torch flames that sit on the three orange wall lamps.
TORCH_FRAMES = [
    [
        "....p....",
        "....G....",
        "...GG....",
        "...GOG...",
        "..GOOG...",
        "..GOPOG..",
        "..OOPPO..",
        ".EOPPPOE.",
        ".EOPwPOE.",
        ".EOPPPOE.",
        "..EOOOE..",
        "...EEE...",
    ],
    [
        ".....p...",
        ".....G...",
        "....GG...",
        "...GOG...",
        "...GOOG..",
        "..GOPOG..",
        "..OOPPO..",
        ".EOPPPOE.",
        ".EOPwPOE.",
        ".EOPPPOE.",
        "..EOOOE..",
        "...EEE...",
    ],
    [
        ".........",
        "...p.....",
        "...GG....",
        "..GOG....",
        "..GOOG...",
        "..GOPOG..",
        "..OPPOO..",
        ".EOPPPOE.",
        ".EOPwPOE.",
        ".EOPPPOE.",
        "..EOOOE..",
        "...EEE...",
    ],
    [
        "....p....",
        "...GG....",
        "...GOG...",
        "..GOOG...",
        "..GOPOG..",
        "..GOPPO..",
        "..OPPPO..",
        ".EOPPPOE.",
        ".EOPwPOE.",
        ".EOPPPOE.",
        "..EOOOE..",
        "...EEE...",
    ],
]
TORCH_KEY = {".": T, "p": glow(PALE, 160), "G": GOLD, "O": ORANGE, "P": PALE, "w": WHITE, "E": EMBER}

# Raindrop for the curse storm particles.
# Two pixels wide with a blue edge so drops read against the light sand floor
RAINDROP = [
    ".r",
    "br",
    "bR",
    "bR",
    "bR",
    "Bw",
]
RAIN_KEY = {".": T, "r": glow(RAIN, 140), "R": RAIN, "w": WHITE, "b": glow(BLUE, 150), "B": BLUE}


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    strip([from_rows(LAMP_UNLIT, LAMP_KEY), from_rows(LAMP_LIT, LAMP_KEY)]).save(OUT_DIR / "lane_lamp.png")
    strip([from_rows(BAR_UNLIT, BAR_KEY), from_rows(BAR_LIT, BAR_KEY)]).save(OUT_DIR / "bonus_bar.png")
    strip([from_rows(ARROW_UNLIT, ARROW_KEY), from_rows(ARROW_LIT, ARROW_KEY)]).save(OUT_DIR / "arrow_insert.png")
    strip([from_rows(f, TORCH_KEY) for f in TORCH_FRAMES]).save(OUT_DIR / "torch.png")
    from_rows(RAINDROP, RAIN_KEY).save(OUT_DIR / "raindrop.png")
    print("wrote", sorted(p.name for p in OUT_DIR.iterdir()))


if __name__ == "__main__":
    main()
