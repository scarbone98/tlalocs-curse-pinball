"""Generate the El Dorado bonus stage: its walls and its art, from one set of shapes.

Writes
  Scripts/el_dorado_geometry.gd      wall polygons and object spots the game builds
  Sprites/el_dorado/stage.png        the chamber, painted from those same polygons
  Sprites/el_dorado/gilded_king.png  the boss (idle, hit, beaten)
  Sprites/el_dorado/gold_coin.png    the pop bumpers (idle, lit)

Everything is in scene units (the 720x1280 table). The art is painted at the table
art's resolution (256x424) and stretched by the same MAP_SCALE, so it shares the
main table's pixel grid. The flipper area (inlane rails, slingshots, trap plugs) is
copied from the main table so the flippers play exactly the same; the outlanes are
walled off, as in Pokemon Pinball's bonus stages.

Run from the repo root:  python3 tools/make_el_dorado.py
"""
import math
from pathlib import Path

from PIL import Image

from pixel_art import Canvas, asymmetry

ART_W, ART_H = 256, 424
SX, SY = 720.0 / ART_W, 1280.0 / ART_H

# Arch over the top of the chamber
TOP = [(0, 0), (720, 0), (720, 300), (656, 300), (646, 232), (618, 170), (572, 118), (508, 82),
       (436, 63), (360, 58), (284, 63), (212, 82), (148, 118), (102, 170), (74, 232), (64, 300),
       (0, 300)]
# The main table's flipper area is centred on x 341 (its plunger lane takes the right
# side), so the pieces copied from it are shifted to the chamber's centre line, 360.
# Only the left side is written out; the right side is its mirror image.
SHIFT = 19
CENTRE = 360


def shifted(points):
    return [(x + SHIFT, y) for x, y in points]


def mirrored(points):
    return [(2 * CENTRE - x, y) for x, y in reversed(points)]


# Side wall: straight down, then angled in to land on top of the inlane rail's cap
LEFT = [(0, 290), (64, 290), (64, 880)] + shifted(
    [(130, 1000), (121, 1003), (121, 1123), (117, 1163), (174, 1210), (278, 1264), (279, 1282)]
) + [(0, 1282)]
# From the main table's left side (node_2d.tscn: layer_1_colliders/CollisionPolygon2D5
# and 8, ball_trap_plugs/left), in scene coordinates
RAIL = shifted([(122, 1003), (130, 1000), (140, 1005), (142, 1083), (144, 1092), (157, 1105),
                (181, 1121), (254, 1167), (240, 1172), (238, 1186), (242, 1200), (231, 1198),
                (217, 1189), (142, 1139), (126, 1128), (121, 1123), (121, 1116)])
SLING = shifted([(189, 1002), (184, 1008), (185, 1064), (238, 1098), (248, 1094), (249, 1083),
                 (197, 1003)])
PLUG = shifted([(242, 1188), (226, 1188), (190, 1214), (196, 1219), (234, 1238), (246, 1210)])

RIGHT = mirrored(LEFT)
RAILS = [RAIL, mirrored(RAIL)]
SLINGS = [SLING, mirrored(SLING)]
PLUGS = [PLUG, mirrored(PLUG)]
WALLS = [TOP, LEFT, RIGHT] + RAILS + SLINGS + PLUGS

KING_Y = 250
KING_X = (220, 500)
COINS = [(200, 560), (520, 560), (360, 470)]
COIN_RADIUS = 24
ENTRY = (360, 380)
DRAIN_AT = (CENTRE, 1272)
DRAIN_SIZE = (115, 20)

T = (0, 0, 0, 0)
INK = (0x16, 0x0E, 0x20, 255)
FLOOR = [(0x2A, 0x17, 0x10, 255), (0x3A, 0x22, 0x14, 255), (0x4E, 0x31, 0x18, 255)]
BRICK = [(0x6E, 0x44, 0x12, 255), (0x9A, 0x66, 0x1C, 255), (0xC2, 0x8A, 0x2A, 255)]
GOLD = (0xF8, 0xD0, 0x00, 255)
GOLD_D = (0xC0, 0x8A, 0x10, 255)
PALE = (0xF0, 0xF0, 0x90, 255)
ORANGE = (0xF8, 0xA0, 0x08, 255)
EMBER = (0xBE, 0x56, 0x2E, 255)
JADE = [(0x1C, 0x3F, 0x35, 255), (0x25, 0x5C, 0x4B, 255), (0x33, 0x77, 0x61, 255)]
JADE_D, JADE_M = JADE[1], JADE[2]
WHITE = (0xDE, 0xF1, 0xEE, 255)
SUN = [(0x5A, 0x3A, 0x14, 255), (0x7A, 0x52, 0x1A, 255)]


def inside(poly, x, y):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def region(px, py):
    """What the scene point under art pixel (px, py) is: wall, rail, sling, plug or floor."""
    x, y = (px + 0.5) * SX, (py + 0.5) * SY
    for kind, polys in (("sling", SLINGS), ("rail", RAILS), ("plug", PLUGS), ("wall", [TOP, LEFT, RIGHT])):
        if any(inside(p, x, y) for p in polys):
            return kind
    return "floor"


def pyramid(px, py):
    """Step number (1-5) of the stepped pyramid inlaid in the lower floor, or 0."""
    base, step_h, half = 290, 7, 34
    for step in range(5):
        top = base - step_h * (step + 1)
        if top <= py < top + step_h and abs(px + 0.5 - 128) < half - step * 6:
            return step + 1
    return 0


def paint_stage():
    kinds = [[region(px, py) for px in range(ART_W)] for py in range(ART_H)]
    img = Image.new("RGBA", (ART_W, ART_H), T)
    cx, cy = 128, 150  # the sun disc under the King's path, in art pixels
    for py in range(ART_H):
        for px in range(ART_W):
            kind = kinds[py][px]
            near_floor = any(
                0 <= px + dx < ART_W and 0 <= py + dy < ART_H and kinds[py + dy][px + dx] == "floor"
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if kind == "floor":
                # Tiled gold-leaf floor, darker toward the flippers
                across = int(abs(px + 0.5 - 128))
                tile = FLOOR[1] if (across // 8 + py // 8) % 2 else FLOOR[0]
                if across % 8 == 7 or py % 8 == 0:
                    tile = FLOOR[2] if py < 300 else FLOOR[1]
                d = math.hypot((px + 0.5 - cx) * SX / SY, py - cy)
                if pyramid(px, py):
                    tile = SUN[pyramid(px, py) % 2]
                elif 30 < d < 34 or 44 < d < 46:
                    tile = SUN[1]
                elif d < 30 and int(abs(math.degrees(math.atan2(px + 0.5 - cx, py - cy))) // 15) % 2 == 0:
                    tile = SUN[0]
                img.putpixel((px, py), tile)
            elif kind == "floor":
                pass
            elif near_floor:
                img.putpixel((px, py), GOLD if kind != "sling" else PALE)
            elif kind == "wall":
                # Gold bricks, offset every other course
                # measured out from the centre line, so the brickwork mirrors too
                row = py // 5
                across = int(abs(px + 0.5 - 128)) + (4 if row % 2 else 0)
                col = across // 9
                edge = py % 5 == 0 or across % 9 == 0
                tone = BRICK[(row * 7 + col * 3) % 2 + 1] if not edge else BRICK[0]
                img.putpixel((px, py), tone)
            elif kind == "sling":
                img.putpixel((px, py), JADE[2] if (int(abs(px + 0.5 - 128)) + py) % 5 else JADE[1])
            elif kind == "rail":
                img.putpixel((px, py), GOLD_D)
            else:
                img.putpixel((px, py), BRICK[0])
    for (a, b) in ((LEFT, RIGHT), (RAIL, RAILS[1]), (SLING, SLINGS[1]), (PLUG, PLUGS[1])):
        assert sorted(b) == sorted((2 * CENTRE - x, y) for x, y in a)
    # A dark line just inside the gold rim, so the floor reads clearly against the walls
    for py in range(ART_H):
        for px in range(ART_W):
            if kinds[py][px] == "floor" and any(
                    0 <= px + dx < ART_W and 0 <= py + dy < ART_H and kinds[py + dy][px + dx] != "floor"
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                img.putpixel((px, py), INK)
    # Jade mound at the drain, like the main table's
    for py in range(ART_H):
        for px in range(ART_W):
            if kinds[py][px] == "floor" and math.hypot((px + 0.5 - 128) * 0.6, py - 428) < 17:
                img.putpixel((px, py), JADE[1] if py > 418 else JADE[2])
    return img


def from_rows(rows, key):
    img = Image.new("RGBA", (len(rows[0]), len(rows)), T)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            img.putpixel((x, y), key[ch])
    return img


def strip(frames):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), T)
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    return sheet


# The Gilded King: a gold mask under a crown of quetzal plumes, drawn on the left and
# mirrored, so it's exactly symmetrical. Lit down the middle, darker toward both sides.
BRONZE = (0x8A, 0x5A, 0x10, 255)
TURQ = (0x2A, 0x9E, 0xC8, 255)
TURQ_L = (0x8B, 0xE6, 0xEE, 255)
GREEN = (0x1E, 0xB6, 0x21, 255)
# the mask's outline, left half; mirrored for the right
FACE_L = [(16, 13.5), (7, 13.5), (6.2, 17), (6.4, 22), (7.6, 26), (10, 29), (13, 31), (16, 31.6)]
FACE = FACE_L + [(32 - x, y) for x, y in reversed(FACE_L)]

def king_frame(state):
    c = Canvas(32, 34)
    for base, ang, ln, wd in [((9.8, 14), -56, 9, 4.0), ((12.4, 13), -28, 10.5, 4.2), ((16, 12.5), 0, 12, 4.8)]:
        c.feather(base, ang, ln, wd, JADE_M, GREEN, GOLD)
    # face: gold, lit down the middle, shading toward the sides and the jaw
    c.poly(FACE, GOLD)
    for y in range(c.h):
        edge = next((e for e in range(16) if c.get(e, y) == GOLD), 16)
        for x in range(16):
            if c.get(x, y) == GOLD:
                if x - edge < 1 or y >= 30:
                    c.set(x, y, GOLD_D)
                elif x - edge < 2 or y >= 28:
                    c.set(x, y, ORANGE)
    c.rect(13, 15, 15, 15, PALE); c.rect(14, 16, 15, 16, PALE)       # forehead shine
    # crown band with turquoise inlays
    c.rect(6, 11, 15, 11, GOLD_D); c.rect(5, 12, 15, 12, GOLD); c.rect(5, 13, 15, 13, GOLD_D)
    c.rect(5, 12, 5, 12, ORANGE)
    for gx in (7, 11):
        c.rect(gx, 12, gx + 1, 12, TURQ); c.set(gx, 12, TURQ_L)
    c.rect(15, 11, 15, 13, TURQ); c.set(15, 11, TURQ_L)
    # round ear spools: gold ring, turquoise disc, dark centre
    c.ellipse(4.5, 21, 2.9, 2.9, GOLD_D); c.ellipse(4.5, 21, 2.0, 2.0, TURQ); c.set(4, 21, INK); c.set(3, 20, TURQ_L)
    # brow ridge and almond eyes of shell and obsidian
    c.rect(9, 17, 13, 17, ORANGE)
    white, pupil = (WHITE, INK) if state == "idle" else (PALE, WHITE) if state == "hit" else (GOLD_D, GOLD_D)
    if state == "blink":
        white, pupil = ORANGE, ORANGE
    c.rect(10, 18, 13, 18, INK); c.set(9, 19, INK); c.set(14, 19, INK)
    c.rect(10, 19, 13, 19, white); c.rect(11, 19, 12, 19, pupil)
    c.rect(10, 20, 13, 20, INK if state not in ("beaten", "blink") else GOLD_D)
    if state == "beaten":
        c.rect(9, 19, 14, 19, BRONZE); c.rect(10, 18, 13, 18, GOLD_D)
    # nose: lit bridge between shaded wings, nostrils
    c.rect(15, 19, 15, 22, PALE); c.rect(14, 21, 14, 22, ORANGE); c.set(13, 23, ORANGE); c.set(14, 23, EMBER)
    # lips and teeth
    if state == "hit":
        c.rect(12, 25, 15, 25, EMBER); c.rect(12, 26, 15, 26, INK); c.rect(13, 27, 15, 27, EMBER)
    else:
        c.rect(12, 25, 15, 25, ORANGE); c.set(11, 26, EMBER); c.rect(12, 26, 15, 26, EMBER)
        c.rect(13, 26, 14, 26, WHITE); c.rect(13, 27, 15, 27, ORANGE)
    # collar of gold and turquoise beads
    c.ellipse(16, 33.4, 10.5, 2.4, GOLD_D)
    for bx in (7, 10, 13):
        c.set(bx, 32, TURQ); c.set(bx, 33, TURQ)
    c.mirror()
    c.outline(INK)
    if state == "beaten":
        c = c.recolor({GOLD: GOLD_D, PALE: GOLD, ORANGE: BRONZE, GREEN: JADE_M, JADE_M: JADE_D, TURQ_L: TURQ})
    if state == "hit":
        c = c.recolor({GOLD: PALE, ORANGE: GOLD, GOLD_D: ORANGE})
    return c.image()



def king_frames():
    return [king_frame(state) for state in ("idle", "hit", "beaten", "blink")]


def coin_frame(lit):
    """A gold coin with a sun on it. Rays are measured off the vertical, so it mirrors exactly."""
    c = Canvas(18, 18)
    for py in range(18):
        for px in range(18):
            dx, dy = px + 0.5 - 9, py + 0.5 - 9
            d = math.hypot(dx, dy)
            ray = int(abs(math.degrees(math.atan2(dx, -dy))) // 22.5) % 2 == 0
            if d > 8.1:
                continue
            if d > 6.9:
                color = (PALE if dy < 0 else GOLD) if lit else (GOLD if dy < 0 else GOLD_D)
            elif d < 2.6:
                color = WHITE if lit else ORANGE
            elif d < 5.6 and ray:
                color = WHITE if lit else ORANGE
            else:
                color = GOLD if lit else GOLD_D
            c.set(px, py, color)
    c.outline(INK)
    return c.image()


def fmt(points):
    # plain arrays: PackedVector2Array(...) isn't allowed in a GDScript constant
    return "[%s]" % ", ".join("Vector2(%g, %g)" % p for p in points)


def write_geometry(path):
    lines = [
        "# Generated by tools/make_el_dorado.py; edit the shapes there, not here.",
        "extends RefCounted",
        "",
        "const WALLS := [",
    ] + ["\t%s," % fmt(p) for p in WALLS] + [
        "]",
        "const KING_Y := %g" % KING_Y,
        "const KING_X := Vector2(%g, %g)  # the two ends of his path" % KING_X,
        "const COINS := [%s]" % ", ".join("Vector2(%g, %g)" % c for c in COINS),
        "const COIN_RADIUS := %g" % COIN_RADIUS,
        "const ENTRY := Vector2(%g, %g)" % ENTRY,
        "const DRAIN_AT := Vector2(%g, %g)" % DRAIN_AT,
        "const DRAIN_SIZE := Vector2(%g, %g)" % DRAIN_SIZE,
        "const SHIFT := %g  # the table's flipper area, moved to the chamber's centre line" % SHIFT,
        "const CENTRE := %g" % CENTRE,
        "",
    ]
    Path(path).write_text("\n".join(lines))


def main():
    out = Path("Sprites/el_dorado")
    out.mkdir(parents=True, exist_ok=True)
    stage = paint_stage()
    assert asymmetry(stage) == 0, "the chamber must mirror exactly"
    stage.save(out / "stage.png")
    king = king_frames()
    coins = [coin_frame(False), coin_frame(True)]
    for frame in king + coins:
        assert asymmetry(frame) == 0, "the King and the coin must mirror exactly"
    strip(king).save(out / "gilded_king.png")
    strip(coins).save(out / "gold_coin.png")
    write_geometry("Scripts/el_dorado_geometry.gd")
    print("wrote El Dorado stage, sprites and geometry")


if __name__ == "__main__":
    main()
