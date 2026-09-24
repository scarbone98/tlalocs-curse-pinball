"""Generate the spirits for the Spirit Codex: Sprites/table/spirits.png.

Sixteen spirits, four per city (three common and a rare), like Pokemon Pinball's
Pokemon by map location. Each is 18x14 at the table art's native resolution, drawn
as its left half and mirrored so it's exactly symmetrical. One row per spirit, three
frames each: resting, blinking, and struck (washed out in gold, as the ajolote is).

The ajolote is the table's original water spirit (tools/make_mode_sprites.py), padded
to the same size.

Also writes Sprites/table/offering.png, the sacred offering (a jade bead in a gold
ring, two frames as it glints) that appears on the table during an Awakening, and
Sprites/table/spirits_awakened.png: each spirit's divine form after the
Awakening, like Pokemon Pinball's evolutions. It's the spirit brightened, outlined in
gold and wrapped in an aura, 22x18, two frames as the aura pulses.

Run from the repo root:  python3 tools/make_spirit_sprites.py
"""
from pathlib import Path

from PIL import Image

from pixel_art import Canvas, asymmetry
import make_mode_sprites as mode_sprites

OUT = Path("Sprites/table/spirits.png")
AWAKENED_OUT = Path("Sprites/table/spirits_awakened.png")
W, H = 18, 14
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

# Left halves, 9 columns each; column 8 sits against the centre line.
SPIRITS = {
    "xolo": [
        "o........", "oo.......", "oGo....oo", "oGPo..oDD", "oGPGooGGG", ".oGGGGGGG", ".oGGgGGGG",
        ".oGkwGGGG", ".oGkkGGGG", "..oGGGggg", "...oGggDD", "....oggPP", ".....oooo", ".........",
    ],
    "heron": [
        ".......oo", "......oWo", "......oWW", ".....oWWW", ".....oWkW", "......oWY", "......oWY",
        ".....oWWY", "..oooWWWW", ".oWWWWWWW", ".oggWWWWW", "..oggWWWW", "...oooOOo", ".......O.",
    ],
    "eagle": [
        ".........", "......ooo", ".....oYYY", ".....oYkY", "oo....oYO", "oBoo..oBB", "oBBBooBBB",
        ".oBbBBBBB", ".obBbBBBB", "..obBbBBB", "...oobBBB", ".....oBBB", ".....oYoY", "......o.o",
    ],
    "butterfly": [
        ".oo......", "oOOoo..o.", "oOYOOo..o", "oOYYOOo.o", "oOOOOOOoD", ".oOOOOOoD", "..oooooDD",
        "..oTTToDD", ".oTtTTToD", ".oTTTTToD", "..oTTToD.", "...ooo...", ".........", ".........",
    ],
    "owl": [
        "..o......", "..oo.....", "..oBo....", "..oBBoooo", ".oBBBBBBB", ".oBbbbBBB", ".oBbYYYbB",
        ".oBYkkYbB", ".oBYkwYbO", ".oBbYYbBO", ".oBBBBBbb", "..oBbBbBb", "...oBBBBB", "....ooooo",
    ],
    "coyote": [
        ".o.......", ".oo......", ".oBo.....", ".obBo....", ".obBBo...", "..oBBBooo", "..oBBBBBB",
        "..oBkBBBB", "..oBBBBBC", "...oBBBCC", "....oBCCC", ".....oCCD", "......oCC", ".......oo",
    ],
    "feathered_serpent": [
        "oJ..J..J.", "oJJoJJoJJ", ".oJJJJJJJ", "..oJEEEEE", "..oEETTTT", "..oETkwTT", "..oETkkTT",
        "...oTTTTT", "...oTTTYY", "....oTTTT", ".....oTRR", "......oR.", "......R..", ".........",
    ],
    "iguana": [
        ".......oo", "......oJJ", "......oJk", "......oJJ", "..oo..oJE", ".oJJooJJE", "..ooJJJJE",
        "....oJJJE", "....oJJJE", "..ooJJJJE", ".oJJooJJE", "..oo..oJE", ".......oJ", "........o",
    ],
    "bat": [
        ".........", "oo.....o.", "oVo...oVo", "oVVo..oVV", "oVVVooVVV", ".oVVVVVRV", ".oVvVVVVV",
        "..oVvVVVW", "...oVvoVV", "....oo.oV", ".......oo", ".........", ".........", ".........",
    ],
    "rattlesnake": [
        "......ooo", ".....oBBB", ".....oBkB", "......oBR", "...oooBBB", "..oBbBBbB", ".oBbBooBb",
        ".oBBo..oB", ".oBbo..oB", ".oBBBooBb", "..obBBbBB", "...oooBBB", "......oYY", ".......oo",
    ],
    "sun_macaw": [
        "......ooo", ".....oRRR", ".....oRRR", ".....oWkR", ".....oWWR", "oo....oDD", "oUoo..oRD",
        "oUYRooRRR", ".oUYRRRRR", ".oUYRRRRR", "..oUYRRRR", "...ooRRRR", "......oRR", ".......oR",
    ],
    "howler_monkey": [
        ".........", "....ooooo", "...oBBBBB", "..oBBBBBB", ".oBBBbbbb", "oCoBbkwbb", "oCoBbkkbb",
        ".ooBbbbbD", "...oBbbbb", "...oBbRRR", "....oBRrr", ".....oBBB", "......ooo", ".........",
    ],
    "hummingbird": [
        ".........", "oo.......", "oEoo.....", "oEEEo..oo", ".oEEEooJJ", "..oEEoJkJ", "...ooJJJR",
        "....oJRRR", ".....oRRR", "......oJJ", ".......oD", ".......oD", ".......oD", ".........",
    ],
    "tapir": [
        ".........", "..oo.....", ".oWGo....", ".oGGGoooo", "..oGGGGGG", "..oGkwGGG", "..oGkkGGG",
        "...oGGGGG", "....oGGGG", ".....oGgg", "......ogg", "......ogg", "......ogD", ".......oo",
    ],
    "quetzal": [
        "......ooo", ".....oEEE", ".....oEEE", ".....oEkY", "....oEEEE", "...oEJEEE", "..oEJJRRR",
        "..oEJRRRR", "...oERRRR", "....oRRRR", "......oJJ", ".....oJ.o", ".....oJ..", "......o..",
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


def ajolote_frames():
    """The original water spirit, padded from 18x12 to 18x14."""
    rows = mode_sprites.SPIRIT
    frames = []
    for key in (mode_sprites.SPIRIT_KEY, mode_sprites.SPIRIT_KEY_ALT, mode_sprites.SPIRIT_KEY_HIT):
        img = Image.new("RGBA", (W, H), T)
        img.alpha_composite(mode_sprites.from_rows(rows, key), (0, 1))
        frames.append(img)
    return frames


def main():
    sheet = Image.new("RGBA", (W * 3, H * len(ORDER)), T)
    divine = Image.new("RGBA", (AW * 2, AH * len(ORDER)), T)
    for row, (name, _city, _rare) in enumerate(ORDER):
        if name == "ajolote":
            frames = ajolote_frames()
        else:
            half = SPIRITS[name]
            assert len(half) == H and all(len(r) == 9 for r in half), name
            rest = from_half(half)
            frames = [rest, from_half(half, blink=True), struck(rest)]
            for f in frames:
                assert asymmetry(f) == 0, name
        for i, frame in enumerate(frames):
            sheet.paste(frame, (i * W, row * H))
        for i in range(2):
            form = awakened(frames[0], i == 1)
            # the ajolote keeps its original art's highlight on one side
            assert name == "ajolote" or asymmetry(form) == 0, name
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
