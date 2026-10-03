"""Draw the tiki and the golden idol, the table's two knock-over targets.

  Sprites/table/tiki.png   16x24 frames: glaring, eyes flaring, struck, tottering,
                           and toppled on its back (Scripts/tiki.gd)
  Sprites/table/idol.png   18x18 frames: gleaming, glinting, struck, rocking left,
                           rocking right, and toppled on its side (Scripts/idol.gd)

The tiki stands at the top of the U-shaped lane, upper left, where Cyndaquil stands
on Pokemon Pinball Ruby's field: each shot up the lane knocks it back a step, and the
third knocks it over. The idol sits on its plinth in the middle of the table.

Both are drawn at the table art's native resolution (256x424), front-facing, as
their left halves mirrored, in colours from the hand-drawn art (tools/source_art).
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


# ---------- the tiki ----------

TW, TH = 16, 24


def tiki(state="idle"):
    k = Canvas(TW, TH)
    # crown of fronds
    k.feather((5.5, 6.5), -55, 6.5, 3.2, LEAF, LEAF_D, LEAF_L)
    k.feather((6.5, 6.0), -25, 6.5, 3.2, LEAF, LEAF_D, LEAF_L)
    k.feather((7.6, 6.0), -4, 6.5, 3.0, LEAF_L, LEAF, LEAF_L)
    # the great carved head
    k.rect(2, 6, 7, 17, WOOD)
    k.rect(1, 8, 1, 15, WOOD_D)
    k.rect(3, 6, 7, 6, WOOD_L)              # lit crown of the head
    k.rect(3, 7, 7, 7, WOOD_DD)              # brow ridge groove
    # glaring eyes under a scowling brow
    eye = EYE_HOT if state in ("flare", "hit") else EYE
    k.rect(3, 8, 5, 8, WOOD_H)               # brow, sloping down to the nose
    k.set(6, 9, WOOD_H)
    k.rect(3, 9, 5, 10, WHITE if state == "hit" else eye)
    k.set(5, 10, INK)                         # pupils glare inward
    if state == "hit":
        k.set(4, 10, INK)
    k.rect(6, 10, 7, 12, WOOD_L)             # the nose
    k.set(7, 12, WOOD_D)
    k.rect(2, 11, 3, 11, PAINT)              # war paint on the cheeks
    k.rect(2, 13, 2, 13, PAINT)
    # the huge grin, full of teeth (wider when struck)
    top = 13 if state != "hit" else 12
    k.rect(3, top, 7, 16, MOUTH)
    for x in (3, 5, 7):
        k.set(x, top, WHITE)
        k.set(x, 16, WHITE)
    k.rect(2, 17, 7, 17, WOOD_D)              # jaw
    k.rect(2, 15, 2, 16, WHITE)               # tusks curling up out of the grin
    k.set(1, 14, WHITE)
    # a little carved body: arms folded on the belly, stubby legs
    k.rect(3, 18, 7, 21, WOOD)
    k.rect(2, 18, 2, 20, WOOD_D)             # arms
    k.rect(3, 19, 6, 19, WOOD_L)
    k.set(7, 20, WOOD_DD)                    # belly button
    k.rect(3, 22, 5, 23, WOOD_D)              # legs
    k.mirror()
    k.outline(INK)
    return k.image()


def tottering(upright):
    """Leaning back as it starts to fall: the top half slides up and in a pixel."""
    out = Image.new("RGBA", upright.size, T)
    for y in range(upright.height):
        for x in range(upright.width):
            p = upright.getpixel((x, y))
            if p[3]:
                out.putpixel((x, y - 1 if 0 < y < 12 else y), p)
                if y == 11:
                    out.putpixel((x, y), p)  # the neck stretches as it leans
    return out


def fallen(upright):
    """Lying on its back, seen from above: foreshortened to half its height and
    pushed to the top of the frame (the back of the lane), its face to the sky."""
    flat = upright.resize((TW, 13), Image.NEAREST)
    out = Image.new("RGBA", upright.size, T)
    out.paste(flat, (0, 0))
    return out


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
    upright = tiki()
    frames = [upright, tiki("flare"), tiki("hit"), tottering(upright), fallen(upright)]
    for frame in frames[:3]:
        assert asymmetry(frame) == 0, "the tiki must mirror exactly"
    strip(frames).save(OUT_DIR / "tiki.png")

    still = idol()
    frames = [still, idol("glint"), idol("hit"), rock(still, -1), rock(still, 1), toppled(still)]
    assert asymmetry(still) == 0, "the idol must mirror exactly"
    strip(frames).save(OUT_DIR / "idol.png")
    print("wrote", OUT_DIR / "tiki.png", "and", OUT_DIR / "idol.png")


if __name__ == "__main__":
    main()
