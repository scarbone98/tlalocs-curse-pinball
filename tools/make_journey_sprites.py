"""Generate the sprites for the journey to El Dorado on the main table.

  serpent.png      stone serpent head set into the side walls (idle, struck)
  serpent_pip.png  one of the three hit pips above each head (off, on)
  relics.png       the four gold relics: mask, sun, pyramid, jaguar (4 dark, then 4 lit)
  temple_hole.png  the hole in the middle (idle, flash, El Dorado gate A, gate B)

Drawn at the table art's native resolution (map_f1.png is 256x424) with colors
sampled from it, so they share its pixel grid once the scene scales them up.

Run from the repo root:  python3 tools/make_journey_sprites.py
"""
from pathlib import Path

from PIL import Image

from pixel_art import Canvas, asymmetry

OUT_DIR = Path("Sprites/table")

T = (0, 0, 0, 0)
INK = (0x16, 0x0E, 0x20, 255)
OUTLINE = (0x32, 0x4A, 0x68, 255)
STONE_D = (0x57, 0x6E, 0x78, 255)
STONE = (0x74, 0x8C, 0x9A, 255)
STONE_L = (0x9E, 0xB2, 0xBC, 255)
JADE_D = (0x25, 0x5C, 0x4B, 255)
JADE = (0x33, 0x77, 0x61, 255)
GREEN = (0x1E, 0xB6, 0x21, 255)
GOLD = (0xF8, 0xD0, 0x00, 255)
GOLD_D = (0xC0, 0x8A, 0x10, 255)
ORANGE = (0xF8, 0xA0, 0x08, 255)
EMBER = (0xBE, 0x56, 0x2E, 255)
PALE = (0xF0, 0xF0, 0x90, 255)
WHITE = (0xDE, 0xF1, 0xEE, 255)
NAVY = (0x0F, 0x26, 0x41, 255)
BLUE_D = (0x18, 0x42, 0x88, 255)
DIM = (0x3A, 0x2C, 0x4C, 255)
DIM_L = (0x57, 0x4A, 0x6A, 255)


def from_rows(rows, key):
    width = max(len(r) for r in rows)
    img = Image.new("RGBA", (width, len(rows)), T)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row.ljust(width, ".")):
            img.putpixel((x, y), key[ch])
    return img


def strip(frames):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), T)
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * w, 0))
    return sheet


# A feathered serpent's head coming out of the left wall, facing right (flipped in game
# for the right wall). A side view, so it's placed pixel by pixel rather than mirrored.
SERPENT = [
    "....Y.....Y.........",
    "...oJo...oJo..Y.....",
    "..oJgJo.oJgJooJo....",
    "..oJgJooJgJooJgJo...",
    "...oJgJoJgJoJgJo....",
    "....ojJJjJJjJJo.....",
    "ooooooooooooooooo...",
    "oLLLLLLLLLLLLLLLLoo.",
    "oSSSSSsssssSSSSSLLLo",
    "oSSSSSoEEEoSSSSSSSLo",
    "oSsSSSoEKEoSSSSSSSSo",
    "oSSSSSSoooSSSSSSSsSo",
    "oSsSSSSSSSSSSSSSSSSo",
    "oSSSSSSSSSSSSSSSSSo.",
    "oSsSSSSSWoWooWooWo..",
    "oSSSSSSMMMMMMMMMMM..",
    "oSsSSSSMMRRRRRRMMM..",
    "oSSSSSSMMMMMMMRoRo..",
    "osssssssWooWoooo....",
    "osssssssssssssso....",
    "ossssssssssssso.....",
    "oJjJjJjooooooo......",
    "oJgJgJo.............",
    "ooooooo.............",
]
SERPENT_IDLE = {".": T, "o": INK, "S": STONE, "s": STONE_D, "L": STONE_L, "J": JADE,
                "j": JADE_D, "g": GREEN, "Y": GOLD, "E": GOLD, "K": INK, "W": WHITE, "M": INK, "R": EMBER}
SERPENT_STRUCK = dict(SERPENT_IDLE, S=STONE_L, s=STONE, L=WHITE, E=WHITE, K=EMBER, J=GREEN, g=PALE, R=ORANGE)


def serpent(struck):
    """A feathered serpent's head coming out of the left wall, facing right. 20x24."""
    key = SERPENT_STRUCK if struck else SERPENT_IDLE
    img = Image.new("RGBA", (20, len(SERPENT)), T)
    for y, row in enumerate(SERPENT):
        for x, ch in enumerate(row.ljust(20, ".")):
            img.putpixel((x, y), key[ch])
    return img


PIP_OFF = ["oooo", "oDDo", "oddo", "oooo"]
PIP_ON = ["oooo", "oPPo", "oGGo", "oooo"]
PIP_KEY = {".": T, "o": INK, "D": DIM_L, "d": DIM, "P": PALE, "G": GOLD, "O": ORANGE}

# Relics, 10x10: a mask, the sun, a stepped pyramid, a jaguar
RELICS = [
    [
        "..oooooo..",
        ".oGGGGGGo.",
        "oGGGGGGGGo",
        "oGooGGooGo",
        "oGoEGGEoGo",
        "oGGGGGGGGo",
        "oGGGOOGGGo",
        ".oGGGGGGo.",
        ".oGGooGGo.",
        "..oooooo..",
    ],
    [
        "....oo....",
        ".o.oGGo.o.",
        "..oGGGGo..",
        ".oGGOOGGo.",
        "oGGOPPOGGo",
        "oGGOPPOGGo",
        ".oGGOOGGo.",
        "..oGGGGo..",
        ".o.oGGo.o.",
        "....oo....",
    ],
    [
        "....oo....",
        "...oGGo...",
        "...oOOo...",
        "..oGGGGo..",
        "..oOOOOo..",
        ".oGGGGGGo.",
        ".oOOOOOOo.",
        "oGGGGGGGGo",
        "oOOOOOOOOo",
        "oooooooooo",
    ],
    [
        ".oo....oo.",
        "oGGo..oGGo",
        "oGGGooGGGo",
        "oGEGGGGEGo",
        "oGGoGGoGGo",
        "oGGGGGGGGo",
        ".oGGooGGo.",
        ".oGoWWoGo.",
        "..oGGGGo..",
        "...oooo...",
    ],
]
RELIC_LIT = {".": T, "o": INK, "G": GOLD, "O": ORANGE, "P": PALE, "E": EMBER, "W": WHITE}
RELIC_DARK = dict(RELIC_LIT, G=DIM_L, O=DIM, P=DIM_L, E=DIM, W=DIM_L)

# Temple hole: a stepped temple sunk into the floor with a corbelled doorway, drawn on the
# left and mirrored. The gate frames fill it with El Dorado's gold.
def hole(state):
    """A stepped temple sunk into the floor with a corbelled doorway, 22x16."""
    c = Canvas(22, 16)
    lit, mid, dark = {"idle": (STONE_L, STONE, STONE_D), "flash": (PALE, GOLD, ORANGE),
                      "gate_a": (GOLD, GOLD_D, ORANGE), "gate_b": (PALE, GOLD, GOLD_D)}[state]
    # three courses, each with a lit top edge and a shadowed underside
    for x0, y0, y1 in ((6, 1, 3), (3, 4, 7), (1, 8, 14)):
        c.rect(x0, y0, 10, y1, mid)
        c.rect(x0, y0, 10, y0, lit)
        c.rect(x0, y1, 10, y1, dark)
    for y in (10, 12):
        c.rect(1, y, 2, y, dark)              # jamb blocks
    # corbelled doorway, narrowing toward the top
    inside, deep = {"idle": (NAVY, INK), "flash": (BLUE_D, NAVY),
                    "gate_a": (ORANGE, GOLD), "gate_b": (GOLD, PALE)}[state]
    c.rect(8, 6, 10, 14, INK); c.rect(6, 8, 10, 14, INK); c.rect(4, 10, 10, 14, INK)
    c.rect(9, 7, 10, 14, inside); c.rect(7, 9, 10, 14, inside); c.rect(5, 11, 10, 14, inside)
    c.rect(8, 11, 10, 14, deep)
    c.mirror()
    c.outline(INK)
    return c.image()


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    strip([serpent(False), serpent(True)]).save(OUT_DIR / "serpent.png")
    strip([from_rows(PIP_OFF, PIP_KEY), from_rows(PIP_ON, PIP_KEY)]).save(OUT_DIR / "serpent_pip.png")
    relics = [from_rows(r, RELIC_DARK) for r in RELICS] + [from_rows(r, RELIC_LIT) for r in RELICS]
    strip(relics).save(OUT_DIR / "relics.png")
    holes = [hole(state) for state in ("idle", "flash", "gate_a", "gate_b")]
    pips = [from_rows(PIP_OFF, PIP_KEY), from_rows(PIP_ON, PIP_KEY)]
    for img in holes + relics + pips:
        assert asymmetry(img) == 0, "front-facing sprites must mirror exactly"
    strip(holes).save(OUT_DIR / "temple_hole.png")
    print("wrote serpent, pips, relics and temple hole sprites")


if __name__ == "__main__":
    main()
