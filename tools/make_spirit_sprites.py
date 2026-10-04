"""Generate the spirits for the Spirit Codex: Sprites/table/spirits.png.

Sixteen spirits, four per city (three common and a rare), like Pokemon Pinball's
Pokemon by map location. Each is 26x22 at the table art's native resolution, drawn
front-on in a Mesoamerican codex style as its left half and mirrored so it's exactly
symmetrical. One row per spirit, three
frames each: resting, blinking, and struck (washed out in gold, as the ajolote is).

Also writes Sprites/table/offering.png, the sacred offering (a jade bead in a gold
ring, two frames as it glints) that appears on the table during an Awakening, and
Sprites/table/spirits_awakened.png: each spirit's divine form after the
Awakening, like Pokemon Pinball's evolutions. It's the spirit brightened, outlined in
gold and wrapped in an aura, 30x26, two frames as the aura pulses.

Run from the repo root:  python3 tools/make_spirit_sprites.py
"""
from pathlib import Path

from PIL import Image

from pixel_art import Canvas, asymmetry

OUT = Path("Sprites/table/spirits.png")
AWAKENED_OUT = Path("Sprites/table/spirits_awakened.png")
W, H = 26, 22
AW, AH = W + 4, H + 4
T = (0, 0, 0, 0)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


PALETTE = {
    ".": T, "o": rgb("#160e20"), "k": rgb("#101010"), "w": rgb("#f0f0e8"), "W": rgb("#e8eef0"),
    "G": rgb("#4a5a60"), "g": rgb("#8a9aa0"), "D": rgb("#2a2224"),
    "B": rgb("#7a4a24"), "b": rgb("#c89060"), "C": rgb("#f0e0b8"),
    "Y": rgb("#f8d000"), "O": rgb("#f8a008"), "R": rgb("#d83828"), "r": rgb("#6a1a1a"),
    "J": rgb("#1f6e3c"), "E": rgb("#3ec048"), "T": rgb("#2a9ec8"), "t": rgb("#8be6ee"),
    "U": rgb("#2c67a4"), "V": rgb("#5a3a7a"), "v": rgb("#9a7ac0"), "P": rgb("#e88aa0"),
}

# Left halves, 13 columns each (column 12 sits against the centre line): front-on
# figures in the manner of the Mesoamerican codices, heavy outlines and flat jade,
# turquoise, red and gold, crests and plumes, ringed eyes, ear-spools and collars.
SPIRITS = {
    "ajolote": [
        ".............",
        "..oo.........",
        ".oPPo..o.....",
        ".oPRPooPo....",
        "..oPRPPRPo...",
        "...oPPPPPoooo",
        "....ooTTTTTTT",
        "...oTTTTTTTTT",
        "..oTTwwwTTTTT",
        "..oTwkkwTTTTT",
        "..oTwkkwTTTTt",
        "..oTTwwTTTTtt",
        "...oTTTTTTttt",
        "....oTTTTTTRR",
        ".....oTTTTTTT",
        "....oTtoTTTTT",
        "...oTto.oTTTT",
        "...oo...oTtTT",
        ".........oTTT",
        "..........oTT",
        "...........oT",
        "............o",
    ],
    "xolo": [
        "..o..........",
        "..oo.........",
        "..oGo........",
        "..oGPo.......",
        "..oGPGo......",
        "..oGPGGo.oooo",
        "..oGGGGGoGGGG",
        "...oGGGGGGGGG",
        "...oGGGGGGGGG",
        "...oGwwwGGGGG",
        "...oGwkkGGGGG",
        "...oGwkkGGGGG",
        "...oGGGGGGGGg",
        "....oGGGGGGgg",
        ".....oGGGGggg",
        "......oGGggDD",
        ".......oGgggP",
        "......oYJYJYJ",
        "......oYJYJYJ",
        ".......oGGGGG",
        "........oGGGG",
        ".........oooo",
    ],
    "heron": [
        "..........ooo",
        ".........oWWW",
        "........oWWWW",
        "........oWkWW",
        "........oWWWY",
        ".........oWWY",
        "..........oWY",
        "..........oWW",
        "..........oWW",
        "oo.......oWWW",
        "oWoo....oWWWW",
        "oWWWoo.oWWWWW",
        ".oWWWWoWWWWWW",
        ".oggWWWWWWWWW",
        "..oggWWWWWWWW",
        "...oggWWWWWWW",
        "....oogWWWWWW",
        "......ooWWWWW",
        "........ooWWW",
        "..........oYo",
        "..........oY.",
        ".........oYY.",
    ],
    "eagle": [
        "...........oo",
        "..........oYY",
        ".........oYYY",
        ".........oYkY",
        ".........oBYO",
        "oo........oBO",
        "oBo......oBBB",
        "oBBoo...oBBBB",
        "obBBBooobBBBB",
        ".obBBBBbBBBBB",
        ".obbBBBBbBBBB",
        "..obbBBBBbBBB",
        "..obbbBBBBBBB",
        "...obbbBBBBBY",
        "....oobbBBBYY",
        "......oobBBYY",
        "........oBBBB",
        "........obBbB",
        ".........obbo",
        ".........oYo.",
        ".........oY..",
        "........oYY..",
    ],
    "butterfly": [
        ".oo..........",
        "oOOoo........",
        "oOYYOoo......",
        "oOYkYOOoo...o",
        "oOYYYOOOOo.o.",
        "oOOOOOJJOOooD",
        "oOOOOJEEJOOoD",
        ".oOOOJEEJOOoD",
        ".oOOOOJJOOOoD",
        "..oOOOOOOOOoD",
        "...ooooooooDD",
        "...oTTTTTToDD",
        "..oTTttTTTToD",
        "..oTtYYtTTToD",
        "..oTtYYtTTToD",
        "...oTttTTToDD",
        "....oTTTToDD.",
        ".....ooooDD..",
        "..........oD.",
        "...........o.",
        ".............",
        ".............",
    ],
    "owl": [
        "...o.........",
        "...oo........",
        "...oBo.......",
        "...oBBo......",
        "..oBBBBoooooo",
        "..oBBBBBBBBBB",
        "..oBYYYYBBBBB",
        ".oBYOOOOYBBBB",
        ".oBYOwwOYBBBB",
        ".oBYOwkkOYBBB",
        ".oBYOwkkOYBBO",
        ".oBBYOOOOYBOO",
        ".oBBBYYYYBBBO",
        ".oBBbBBBBBBBB",
        ".oBbBbCbCbCbC",
        ".oBbBbbCbCbCb",
        ".oBbBbCbCbCbC",
        "..oBbBbbCbCbC",
        "...oBBBBBBBBB",
        "....ooooOoOoO",
        "........O.O.O",
        ".............",
    ],
    "coyote": [
        ".o...........",
        ".oo..........",
        ".oBo.........",
        ".oRBo........",
        ".oRBBo.......",
        ".oRRBBo......",
        ".oRRBBBoooooo",
        "..oRBBBBBBBBB",
        "..oBBBBBBBBBB",
        "..oBBwwwBBBBB",
        "..oBBwkkBBBBB",
        "..JBBBBBBBBBC",
        ".oEJBBBBBBBCC",
        ".oJoBBBBBBCCC",
        "..o.oBBBBBCCC",
        ".....oBBBCCCC",
        "......oBBCCCD",
        ".......oBCCDD",
        "........oCCCC",
        ".........oCRR",
        "..........ooo",
        ".............",
    ],
    "feathered_serpent": [
        "oE...E...E...",
        "oEE.oEE.oEE.E",
        ".oEEoEEEoEEoE",
        "..oEJEEJEEJEE",
        "...oJJJJJJJJJ",
        "...oYRYRYRYRY",
        "...oTTTTTTTTT",
        "..oTTTTTTTTTT",
        "..oTwwwTTTTTT",
        "..oTwkkwTTTTT",
        "..oTwkkwTTTTT",
        "..oTTwwTTTTTT",
        "..oTTTTTTTTtt",
        "...oTTTTTTttt",
        "...oTTTTTtttt",
        "....oTTTTtoot",
        "....oTTTToRRo",
        ".....oTTTWRRR",
        ".....oTTTW.RR",
        "......oTTToRR",
        ".......ooo.oR",
        "...........oR",
    ],
    "iguana": [
        "...........oo",
        "..........oJJ",
        ".........oJEE",
        "........oJEEE",
        "....o..oJEEEE",
        "...oJooJEkwEE",
        "...oJJJEEEEEE",
        "....oJJEEEEEE",
        ".....oJJEEEEE",
        "......oJEEEEY",
        ".....ooJEEEYY",
        "....oJJJEEEEE",
        "...oJJoJEEEEE",
        "...oo.oJEEEEE",
        "......oJEEEYY",
        "......oJEEEEE",
        "......oJJEEEE",
        ".......oJEEEE",
        "........oJEEE",
        ".........oJEE",
        "..........oJE",
        "...........oo",
    ],
    "bat": [
        ".............",
        "o............",
        "oVo........o.",
        "oVVo......oVo",
        "oVVVo.....oVV",
        "oVvVVo...oVVV",
        "oVvvVVoooVVVV",
        ".oVvvVVVVVwVV",
        ".oVvvvVVVVkVV",
        ".oVvvvVVVVVVR",
        "..oVvvvVVVVVR",
        "..oVvvvVVVoVV",
        "...oVvvVVVoWo",
        "...oVvvVVVVVV",
        "....oVvoVVVVV",
        "....oVo.oVVVV",
        ".....o...oVVV",
        "..........oVV",
        "...........oV",
        "............o",
        ".............",
        ".............",
    ],
    "rattlesnake": [
        "..........ooo",
        ".........oBBB",
        "........oBBBB",
        "........oBkBB",
        ".........oBBR",
        "..........oBR",
        ".......oooBBB",
        ".....ooBbBBbB",
        "....oBbYbBbYb",
        "...oBbYYYbBYY",
        "...oBbbYbBbbY",
        "..oBBbBbBBbBb",
        "..oBbYbBooooo",
        "..oBYYYbBbBbB",
        "..oBbYbBbYbBb",
        "...oBbBbYYYbB",
        "....oBBBbYbBB",
        ".....oooBBBBB",
        "........ooooo",
        ".............",
        ".............",
        ".............",
    ],
    "sun_macaw": [
        "..........ooo",
        ".........oRRR",
        "........oRRRR",
        "........oWkRR",
        "........oWWRD",
        ".........oWDD",
        "oo........oRR",
        "oUoo.....oRRR",
        "oUYRoo..oRRRR",
        ".oUYRRooRRRRR",
        ".oUYYRRRRRRRR",
        "..oUYRRRRRRRR",
        "..oUUYYRRRRRR",
        "...oUUYRRRRRR",
        "....ooUYRRRRR",
        "......ooRRRRR",
        "........oRRRR",
        ".........oRRR",
        "..........oRU",
        "..........oUU",
        "...........oU",
        "............o",
    ],
    "howler_monkey": [
        ".............",
        ".....oooooooo",
        "....oBBBBBBBB",
        "...oBBBBBBBBB",
        "..oBBBrrrrrrr",
        ".oBBBrCCCCCCC",
        ".oBBrCCCCCCCC",
        "oCoBrCwwwCCCC",
        "oCoBrCwkkCCCC",
        "oCoBrCwkkCCCC",
        ".ooBrCCCCCCCC",
        "...oBrCCCCCCD",
        "...oBrCCCCCDD",
        "...oBBrCCCCCC",
        "....oBrCCrrrr",
        "....oBBrrRRRR",
        ".....oBBrRrRR",
        ".....oBBBrrrr",
        "......oBBBBBB",
        ".......oBBBBB",
        "........ooooo",
        ".............",
    ],
    "hummingbird": [
        "oo...........",
        "oEoo.........",
        "oEEEoo.......",
        ".oEJEEoo.....",
        ".oEJJEEEo....",
        "..oEJJEEEo...",
        "..oEEJJEEEooo",
        "...oEEJJEoJJJ",
        "....oEEEoJJJJ",
        ".....ooooJkJJ",
        "........oJJJJ",
        "........oJRRR",
        "........oRRRR",
        "........oRRRY",
        ".........oJJJ",
        ".........oJJJ",
        "..........oJD",
        "..........ooD",
        "...........oD",
        "............D",
        ".............",
        ".............",
    ],
    "tapir": [
        ".............",
        "...oo........",
        "..oWGo.......",
        "..oGGGo......",
        "...oGGGoooooo",
        "...oGGGGGGGGG",
        "...oGGGGGGGGG",
        "...oGwwGGGGGG",
        "...oGwkGGGGGG",
        "...oGGGGGGGGG",
        "....oGGGGGGGg",
        ".....oGGGGGgg",
        "......oGGGggg",
        ".......oGgggg",
        "........oGggg",
        "........oGggg",
        ".........oggg",
        ".........oggD",
        "..........ogD",
        "..........oDD",
        "...........oo",
        ".............",
    ],
    "quetzal": [
        "..........o.o",
        ".........oEoE",
        "........oEEEE",
        "........oEEEE",
        "........oEkEY",
        "........oEEEY",
        ".....ooooEEEE",
        "...ooEEEJEEEE",
        "..oEEEJJJEEEE",
        ".oEEJJJJEERRR",
        ".oEJJJJEERRRR",
        "..oJJJEERRRRR",
        "...oJEERRRRRR",
        "....ooERRRRRR",
        "......oRRRRRR",
        ".......oJEEEJ",
        "........oEEJE",
        "........oEJEE",
        ".........oJEJ",
        ".........oEJE",
        "..........oEJ",
        "...........oE",
    ],
}

# Journey order, one row of the sheet each: the city, and whether it's the rare one
ORDER = [
    ("ajolote", 0, False), ("xolo", 0, False), ("heron", 0, False), ("eagle", 0, True),
    ("butterfly", 1, False), ("owl", 1, False), ("coyote", 1, False), ("feathered_serpent", 1, True),
    ("iguana", 2, False), ("bat", 2, False), ("rattlesnake", 2, False), ("sun_macaw", 2, True),
    ("howler_monkey", 3, False), ("hummingbird", 3, False), ("tapir", 3, False), ("quetzal", 3, True),
]


def from_half(half, blink=False):
    img = Image.new("RGBA", (W, H), T)
    for y, row in enumerate(half):
        for x, ch in enumerate(row):
            if blink and ch in "kw":
                ch = "o"  # eyes shut
            color = PALETTE[ch]
            img.putpixel((x, y), color)
            img.putpixel((W - 1 - x, y), color)
    return img


def struck(img):
    """The hit frame: outline turns gold and everything else washes out bright."""
    out = img.copy()
    ink, gold = PALETTE["o"], PALETTE["Y"]
    for y in range(H):
        for x in range(W):
            c = out.getpixel((x, y))
            if c[3] == 0:
                continue
            if c == ink:
                out.putpixel((x, y), gold)
            else:
                out.putpixel((x, y), tuple(int(v + (255 - v) * 0.6) for v in c[:3]) + (255,))
    return out


def awakened(img, pulse):
    """The divine form: brightened, a gold outline, and an aura that pulses."""
    base = Image.new("RGBA", (AW, AH), T)
    base.alpha_composite(img, (2, 2))
    ink, gold = PALETTE["o"], PALETTE["Y"]
    out = Image.new("RGBA", (AW, AH), T)
    filled = lambda x, y: 0 <= x < AW and 0 <= y < AH and base.getpixel((x, y))[3] > 0
    near = lambda x, y, r: any(filled(x + dx, y + dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1)
                               if abs(dx) + abs(dy) <= r)
    for y in range(AH):
        for x in range(AW):
            c = base.getpixel((x, y))
            if c[3] > 0:
                if c == ink:
                    out.putpixel((x, y), gold)
                else:  # a warm lift toward gold
                    out.putpixel((x, y), tuple(int(v + (w - v) * 0.3) for v, w in zip(c[:3], (0xFF, 0xE8, 0x80))) + (255,))
            elif near(x, y, 1):
                out.putpixel((x, y), (0xFF, 0xF4, 0xC0, 170) if pulse else (0xF8, 0xD0, 0x00, 130))
            elif near(x, y, 2):
                out.putpixel((x, y), (0xF8, 0xD0, 0x00, 70 if pulse else 35))
    return out


def offering(glint):
    c = Canvas(12, 12)
    c.ellipse(6, 6, 5.4, 5.4, PALETTE["Y"])           # gold ring
    c.ellipse(6, 6, 4.0, 4.0, PALETTE["J"])           # jade bead
    c.ellipse(6, 5, 2.6, 2.4, PALETTE["E"])
    if glint:
        c.rect(4, 3, 5, 4, PALETTE["w"])
    c.mirror()
    c.outline(PALETTE["o"])
    return c.image()


def main():
    sheet = Image.new("RGBA", (W * 3, H * len(ORDER)), T)
    divine = Image.new("RGBA", (AW * 2, AH * len(ORDER)), T)
    for row, (name, _city, _rare) in enumerate(ORDER):
        half = SPIRITS[name]
        assert len(half) == H and all(len(r) == W // 2 for r in half), name
        rest = from_half(half)
        frames = [rest, from_half(half, blink=True), struck(rest)]
        for f in frames:
            assert asymmetry(f) == 0, name
        for i, frame in enumerate(frames):
            sheet.paste(frame, (i * W, row * H))
        for i in range(2):
            form = awakened(frames[0], i == 1)
            assert asymmetry(form) == 0, name
            divine.paste(form, (i * AW, row * AH))
    sheet.save(OUT)
    divine.save(AWAKENED_OUT)
    bead = [offering(False), offering(True)]
    strip = Image.new("RGBA", (24, 12), T)
    for i, f in enumerate(bead):
        assert asymmetry(f) == 0, "offering"
        strip.paste(f, (i * 12, 0))
    strip.save(Path("Sprites/table/offering.png"))
    print("wrote", OUT, "with", len(ORDER), "spirits")


if __name__ == "__main__":
    main()
