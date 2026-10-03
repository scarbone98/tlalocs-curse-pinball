"""Draw the golden idol that waits at the top of the idol lane.

  Sprites/table/idol.png   18x18 frames: gleaming, glinting, struck, rocking left,
                           rocking right, and toppled on its side (Scripts/idol_puzzle.gd)

It stands at the top of the U-shaped lane, upper left, where Cyndaquil's Egg Stand is on
Pokemon Pinball Ruby's field, behind three stone blocks that have to be driven into the
lane's wall before it can be claimed.

Drawn at the table art's native resolution (256x424), front-facing, as its left half
mirrored, in colours from the hand-drawn art (tools/source_art).
Run from the repo root:  python3 tools/make_tiki_idol.py
"""
from pathlib import Path

from PIL import Image

from pixel_art import Canvas, asymmetry, strip

OUT_DIR = Path("Sprites/table")
T = (0, 0, 0, 0)


def c(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


INK = c("#201008")
WOOD_DD = c("#402000")
WOOD_D = c("#74460a")
WOOD = c("#a96d14")
WOOD_L = c("#d78d20")
WOOD_H = c("#ea9923")
LEAF_D = c("#186070")
LEAF = c("#089890")
LEAF_L = c("#20d8a0")
PAINT = c("#bd3410")
WHITE = c("#f8f0f0")
EYE = c("#f8d000")
EYE_HOT = c("#fff890")
MOUTH = c("#5a1008")
GOLD_DD = c("#7a4a00")
GOLD_D = c("#b07000")
GOLD = c("#f8c000")
GOLD_L = c("#f8e870")
GOLD_H = c("#fffbd6")
JADE = c("#20b870")


# ---------- the golden idol ----------

IW, IH = 18, 18


def idol(state="idle"):
    k = Canvas(IW, IH)
    shine = GOLD_H if state == "hit" else GOLD_L
    body = GOLD_L if state == "hit" else GOLD
    # stepped headdress
    k.rect(4, 1, 8, 2, GOLD_D)
    k.rect(5, 0, 8, 0, GOLD)
    k.rect(3, 3, 8, 3, GOLD_D)
    # round head with big almond eyes and a jade jewel on the brow
    k.ellipse(9.0, 7.0, 5.0, 4.0, body)
    k.rect(6, 4, 8, 5, shine)
    k.set(8, 4, JADE)
    k.rect(5, 6, 7, 7, GOLD_DD)               # eyes
    k.set(6, 6, INK if state != "hit" else GOLD_H)
    k.rect(7, 9, 8, 9, GOLD_D)                # mouth
    # squat body, hugging its knees
    k.ellipse(9.0, 13.5, 6.0, 3.6, GOLD_D)
    k.rect(4, 11, 8, 13, body)
    k.rect(5, 12, 8, 12, shine)                # arms
    k.rect(3, 14, 8, 15, GOLD_D)               # knees
    k.rect(4, 16, 8, 17, GOLD_DD)              # base
    k.mirror()
    if state == "glint":
        for x, y in ((12, 4), (13, 3), (13, 5), (14, 4)):
            k.set(x, y, GOLD_H)
    k.outline(INK)
    return k.image()


def rock(upright, direction):
    """Rocking on its base: rows shear a pixel per few rows toward one side."""
    out = Image.new("RGBA", upright.size, T)
    for y in range(upright.height):
        shift = direction * ((IH - 1 - y) // 6)
        for x in range(upright.width):
            p = upright.getpixel((x, y))
            if p[3] and 0 <= x + shift < IW:
                out.putpixel((x + shift, y), p)
    return out


def toppled(upright):
    """Fallen on its side, head to the right, lying at the bottom of the frame."""
    side = upright.rotate(-90, expand=True)
    bbox = side.getbbox()
    side = side.crop(bbox)
    out = Image.new("RGBA", (IW, IH), T)
    out.paste(side, ((IW - side.width) // 2, IH - side.height))
    return out


def main():
    still = idol()
    frames = [still, idol("glint"), idol("hit"), rock(still, -1), rock(still, 1), toppled(still)]
    assert asymmetry(still) == 0, "the idol must mirror exactly"
    strip(frames).save(OUT_DIR / "idol.png")
    print("wrote", OUT_DIR / "idol.png")


if __name__ == "__main__":
    main()
