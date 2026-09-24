"""Generate the sprites that fill Tlaloc's shrine, the striped temple top right.

The table art paints the shrine's panels as flat dark purple. This draws what goes
in them at the art's native resolution (map_f1.png is 256x424), so they share its
pixel grid once the scene scales them up:

  tlaloc_mask.png  the rain god's goggle-eyed mask for the middle panel
                   (asleep, stirring, cursed)
  rain_lamp.png    one raindrop lamp of the curse meter in the top panel (off, on)
  brazier.png      fire bowls either side of the doorway (4 flame frames)

Run from the repo root:  python3 tools/make_shrine_sprites.py
"""
from pathlib import Path

from PIL import Image

from pixel_art import Canvas, asymmetry

OUT_DIR = Path("Sprites/table")

# Sampled from Sprites/map_f1.png
T = (0, 0, 0, 0)
PANEL = (0x33, 0x22, 0x3F, 255)  # the empty panel fill
INK = (0x16, 0x0E, 0x20, 255)
STRIPE_B = (0x2C, 0x67, 0xA4, 255)
STRIPE_W = (0xC6, 0xD8, 0xE9, 255)
TEAL = (0x1A, 0x86, 0xA3, 255)
TEAL_L = (0x8B, 0xE6, 0xEE, 255)
NAVY = (0x0F, 0x26, 0x41, 255)
STONE_D = (0x57, 0x6E, 0x78, 255)
STONE = (0x74, 0x8C, 0x9A, 255)
GOLD = (0xF8, 0xD0, 0x00, 255)
ORANGE = (0xF8, 0xA0, 0x08, 255)
EMBER = (0xBE, 0x56, 0x2E, 255)
PALE = (0xF0, 0xF0, 0x90, 255)
WHITE = (0xDE, 0xF1, 0xEE, 255)
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


# Tlaloc's mask: goggle rings for eyes, a curled moustache lip and fangs, drawn on the
# left and mirrored so it's exactly symmetrical. The eyes change per frame: shut while
# he sleeps, gold as he stirs, lightning white under the curse.
BLUE_D = (0x18, 0x42, 0x88, 255)


def mask_frame(state):
    c = Canvas(35, 17)
    # goggle rings joined by a bridge over the nose
    c.ellipse(8.5, 6.8, 7.0, 5.9, TEAL)
    c.ellipse(8.5, 6.8, 7.0, 5.9, TEAL_L, where=lambda x, y: y <= 1)       # lit top of the ring
    c.rect(15, 4, 17, 7, TEAL); c.rect(15, 4, 17, 4, TEAL_L)
    c.ellipse(8.5, 6.8, 4.6, 3.9, NAVY)
    inner = {"asleep": BLUE_D, "stirring": ORANGE, "glowing": GOLD, "cursed": RAIN}[state]
    c.ellipse(8.5, 6.8, 3.7, 3.0, inner)
    if state == "asleep":
        c.rect(5, 6, 11, 6, STRIPE_B)          # shut lid
    elif state == "stirring":
        c.rect(7, 5, 9, 7, GOLD); c.set(8, 6, PALE)
    elif state == "glowing":
        c.rect(7, 5, 9, 7, PALE); c.set(8, 6, (255, 255, 255, 255))
    else:
        c.rect(7, 5, 9, 7, WHITE); c.set(8, 6, (255, 255, 255, 255))
    # moustache band, curling up into a spiral at each end
    c.rect(4, 11, 17, 12, STRIPE_B); c.rect(5, 11, 17, 11, STRIPE_W)
    c.ellipse(3.0, 10.4, 2.3, 2.3, STRIPE_B); c.set(3, 10, STRIPE_W); c.set(2, 10, NAVY)
    # fangs hanging from the lip, tapering to a point
    for fx, ln in ((9, 2), (12, 3), (15, 3)):
        c.rect(fx - 1, 13, fx, 13, WHITE)
        c.rect(fx, 14, fx, 12 + ln, WHITE)
    c.mirror()
    c.outline(INK)
    return c.image()


def mask_frames():
    return [mask_frame(state) for state in ("asleep", "stirring", "cursed", "glowing")]


# One lamp of the curse meter: a raindrop that fills as Tlaloc stirs.
DROP = [
    "..o..",
    ".oDo.",
    ".oDo.",
    "odDdo",
    "odDdo",
    "osdso",
    ".ooo.",
]
DROP_OFF = {".": T, "o": INK, "D": STRIPE_B, "d": NAVY, "s": NAVY}
DROP_ON = {".": T, "o": INK, "D": WHITE, "d": RAIN, "s": TEAL}

# Stone fire bowl; the flame on top flickers through four frames.
BOWL = [
    "oooooooooo",
    "oSSSSSSSSo",
    ".oSssssSo.",
    "..oSssSo..",
    "...oSSo...",
    "...oSSo...",
    "..oSSSSo..",
    "..oooooo..",
]
BOWL_KEY = {".": T, "o": INK, "S": STONE, "s": STONE_D}
# The flame stands straight, leans one way, leans the other, then gutters low
FLAME_UP = [
    "....pp....",
    "....GG....",
    "...GGGG...",
    "...GOOG...",
    "..GOOOOG..",
    "..GOPPOG..",
    ".EOPPPPOE.",
]
FLAME_LEAN = [
    "...p......",
    "...GG.....",
    "...GGGG...",
    "..GGOOG...",
    "..GOOOOG..",
    "..GOPPOG..",
    ".EOPPPPOE.",
]
FLAME_LOW = [
    "..........",
    "....pp....",
    "...GGGG...",
    "...GOOG...",
    "..GOOOOG..",
    "..GOPPOG..",
    ".EOPPPPOE.",
]
FLAMES = [FLAME_UP, FLAME_LEAN, [r[::-1] for r in FLAME_LEAN], FLAME_LOW]
FLAME_KEY = {".": T, "p": PALE, "G": GOLD, "O": ORANGE, "P": PALE, "E": EMBER}


def brazier_frames():
    frames = []
    for flame in FLAMES:
        img = Image.new("RGBA", (10, 15), T)
        img.alpha_composite(from_rows(flame, FLAME_KEY), (0, 0))
        img.alpha_composite(from_rows([r.ljust(10, ".") for r in BOWL], BOWL_KEY), (0, 7))
        frames.append(img)
    return frames


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    masks = mask_frames()
    bowl = from_rows(BOWL, BOWL_KEY)
    for img in masks + [from_rows(DROP, DROP_OFF), from_rows(DROP, DROP_ON), bowl]:
        assert asymmetry(img) == 0, "shrine sprites must mirror exactly"
    strip(masks).save(OUT_DIR / "tlaloc_mask.png")
    strip([from_rows(DROP, DROP_OFF), from_rows(DROP, DROP_ON)]).save(OUT_DIR / "rain_lamp.png")
    strip(brazier_frames()).save(OUT_DIR / "brazier.png")
    print("wrote tlaloc mask, rain lamp and brazier sprites")


if __name__ == "__main__":
    main()
