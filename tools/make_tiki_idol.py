"""Draw the golden idol that sits atop the spinning tower in the idol lane.

  Sprites/table/idol.png   22x22 frames: gleaming, glinting, struck, rocking left,
                           rocking right, and toppled on its side (Scripts/idol_tower.gd)

A squat seated Aztec idol in gold, the kind you'd steal from a jungle temple: a feathered
headdress with a jade jewel, a broad face with heavy brows, staring eyes and a downturned
mouth, jade ear-spools, a jade pectoral on its chest, hands on its knees, sitting on a
stepped stone base. Drawn at the table art's native resolution (256x424), front-facing,
as its left half mirrored. tools/make_table.py turns it round in depth for idol_spin.png.
Run from the repo root:  python3 tools/make_tiki_idol.py
"""
from pathlib import Path

from PIL import Image

OUT_DIR = Path("Sprites/table")
T = (0, 0, 0, 0)
FRAME = 22  # each frame is square; the idol is 20x22 within it

# Left half, 10 columns; column 9 sits against the centre line.
#   o ink   L gold, lit   Y gold   D gold, shaded   S deep shadow   E jade   e jade, dark
#   K stone   k stone, dark
HALF = [
    "......oooo",  # the headdress's crest of feathers
    "....ooLoLL",
    "...oLLYLYY",
    "..oLYYYYEE",  # a jade jewel set in the middle of the band
    ".oYYDYYYEe",
    "oDYDDooooo",  # the band's lower edge: his heavy brow
    "oDo.oDYYYY",
    "oEeooYLLLY",  # ear-spools, the brow ridge catching the light
    "oEEoYSSoYY",  # staring eyes
    "oeEoYSSoDD",
    ".ooo.YYYDD",  # the nose
    "....oYYYDY",
    "....oYSSSS",  # a downturned mouth
    ".....oYYYY",
    "...ooYYYEe",  # a jade pectoral on his chest
    "..oYYDYEEE",
    ".oYYDoYYEe",
    ".oYDoDDYYY",  # his arms down to his hands, resting on his knees
    ".oLLLLDYYY",
    "okkkkkkkkk",  # the stepped stone base
    "oKkKkKkKkK",
    "oooooooooo",
]

COLOURS = {
    "o": (32, 16, 8), "L": (248, 232, 112), "Y": (248, 192, 0), "D": (176, 112, 0),
    "S": (96, 52, 0), "E": (40, 200, 120), "e": (20, 120, 76),
    "K": (130, 136, 146), "k": (86, 92, 104),
}


def idol(kind="still"):
    w, h = len(HALF[0]) * 2, len(HALF)
    img = Image.new("RGBA", (FRAME, FRAME), T)
    x0, y0 = (FRAME - w) // 2, FRAME - h
    for y, row in enumerate(HALF):
        for x, key in enumerate(row):
            if key not in COLOURS:
                continue
            col = COLOURS[key]
            if kind == "hit" and key in "LYDS":
                col = tuple(min(255, int(v + (255 - v) * 0.6)) for v in col)  # washed bright as it's struck
            for px in (x0 + x, x0 + w - 1 - x):
                img.putpixel((px, y0 + y), col + (255,))
    if kind == "glint":  # a star of light off the headdress
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            img.putpixel((x0 + 5 + dx, y0 + 2 + dy), (255, 255, 255, 255))
    return img


def rock(upright, way):
    """Rocking on its base: everything above the base leans a pixel one way."""
    out = Image.new("RGBA", upright.size, T)
    base_top = FRAME - 3
    for y in range(FRAME):
        shift = way if y < base_top - 6 else 0
        for x in range(FRAME):
            p = upright.getpixel((x, y))
            if p[3] and 0 <= x + shift < FRAME:
                out.putpixel((x + shift, y), p)
    return out


def toppled(upright):
    """Fallen on its side, head to the right, lying at the bottom of the frame."""
    side = upright.rotate(-90, expand=True)
    side = side.crop(side.getbbox())
    out = Image.new("RGBA", (FRAME, FRAME), T)
    out.paste(side, ((FRAME - side.width) // 2, FRAME - side.height))
    return out


def main():
    still = idol()
    frames = [still, idol("glint"), idol("hit"), rock(still, -1), rock(still, 1), toppled(still)]
    sheet = Image.new("RGBA", (FRAME * len(frames), FRAME), T)
    for i, f in enumerate(frames):
        sheet.paste(f, (i * FRAME, 0))
    sheet.save(OUT_DIR / "idol.png")
    print("wrote", OUT_DIR / "idol.png")


if __name__ == "__main__":
    main()
