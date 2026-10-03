"""Draw the sprites for the Ruby & Sapphire style modes, in the ziggurat's sandstone.

  Sprites/table/glyph_tile.png   8x8 carved stone tiles that hide a rising spirit
                                 (whole, cracked); bumper hits break them
                                 (Scripts/spirit_capture.gd)
  Sprites/table/bonus_lamp.png   7x7 sun-disc lamps by the temple (dark, lit): three
                                 lit open El Dorado in Tlaloc's mouth (Scripts/temple_hole.gd)
  Sprites/table/stone_eye.png    3x3 eye of the stone face, top left, that shows Tlaloc's
                                 mood: asleep, stirring, cursed, glowing (Scripts/table_features.gd)

Drawn at the table art's native resolution (256x424) so the scene's MAP_SCALE puts
them on the table's pixel grid. Run from the repo root:  python3 tools/make_rs_sprites.py
"""
from pathlib import Path

from pixel_art import T, Canvas, strip

OUT_DIR = Path("Sprites/table")


def c(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


OUTLINE = c("#2c3448")
SAND_HI = c("#ecd8a0")
SAND_LT = c("#d4b06c")
SAND = c("#ae8649")
SAND_DK = c("#966a27")
SAND_DD = c("#6a4818")
JADE = c("#089890")
GOLD = c("#f8d000")
GOLD_L = c("#fff890")
EMBER = c("#bd3410")


def tile(cracked):
    k = Canvas(8, 8)
    k.rect(0, 0, 7, 7, OUTLINE)
    k.rect(1, 1, 6, 6, SAND)
    k.rect(1, 1, 6, 1, SAND_HI)       # lit top edge
    k.rect(1, 2, 1, 6, SAND_LT)       # lit left edge
    k.rect(6, 2, 6, 6, SAND_DK)
    k.rect(2, 6, 6, 6, SAND_DK)
    # a carved spiral glyph
    for x, y in ((3, 3), (4, 3), (4, 4), (3, 4), (2, 4), (2, 3)):
        k.set(x, y, SAND_DD)
    k.set(5, 3, JADE)
    if cracked:
        for x, y in ((1, 2), (2, 2), (3, 2), (3, 1), (5, 4), (5, 5), (6, 5), (4, 5)):
            k.set(x, y, OUTLINE)
    return k.image()


def lamp(lit):
    k = Canvas(7, 7)
    k.ellipse(3.5, 3.5, 3.5, 3.5, OUTLINE)
    k.ellipse(3.5, 3.5, 2.6, 2.6, GOLD if lit else SAND_DD)
    k.ellipse(3.5, 3.5, 1.4, 1.4, GOLD_L if lit else SAND_DK)
    if lit:
        k.set(2, 2, c("#ffffff"))
    else:
        k.set(3, 3, EMBER)
    return k.image()


SOCKET_DARK = c("#1a1e40")


def stone_eye(state):
    k = Canvas(3, 3)
    colour = {"asleep": SOCKET_DARK, "stirring": GOLD, "cursed": c("#ff3030"), "glowing": GOLD_L}[state]
    k.set(1, 1, colour)
    if state != "asleep":
        for x, y in ((0, 1), (2, 1), (1, 0), (1, 2)):
            k.set(x, y, colour[:3] + (110,))
    return k.image()


def main():
    strip([tile(False), tile(True)]).save(OUT_DIR / "glyph_tile.png")
    strip([lamp(False), lamp(True)]).save(OUT_DIR / "bonus_lamp.png")
    strip([stone_eye(s) for s in ("asleep", "stirring", "cursed", "glowing")]).save(OUT_DIR / "stone_eye.png")
    print("wrote the mode sprites")


if __name__ == "__main__":
    main()
