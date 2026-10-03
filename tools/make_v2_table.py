"""Build the table from the hand-drawn October 2023 art (tools/source_art/).

The table art is the grey-stone v2 layout (map_f1_v2.png) and its original orange and
green ramps (map_f2.png). This finishes it with:

  - Tlaloc's ziggurat, top right: a stepped temple whose doorway swallows the ball
    off the right ramp's top branch (Scripts/shrine_door.gd). Its top shrine holds
    Tlaloc's mask, its tiers the four raindrop lamps of the curse meter, and fire
    bowls burn either side of the door (Scripts/table_features.gd places those)
  - the chute from that doorway down to the ramp, in the ramps' own orange and green
  - jungle leaves (leaves.png) growing out of the walls

and writes the playfield sprites cut from the hand-drawn sheets:

  Sprites/map_f1.png, Sprites/map_f2.png   the table layers
  Sprites/ball_spin.png       the ball's 16 roll frames, one row per ball upgrade
  bumper_mushroom.png, bumper_mushroom_dust.png, paddle_left.png, paddle_right.png
  Sprites/table/torch.png     6 burning frames, then the same 6 as embers
  Sprites/table/fire.png      15 flame frames for the ziggurat's fire bowls
  Sprites/table/fire_bowl.png the bowl the flames sit in
  Sprites/table/spinner.png   15 frames of the plate turning on its axle
  Sprites/table/jaguar.png    the jaguar's head: rosettes 0-3 lit, roaring, asleep
  Sprites/table/whirl.png     3 frames of the spirit whirl

Everything is at the table art's native resolution (256x424), so the scene's
MAP_SCALE puts it all on one pixel grid. The tiki and the golden idol are drawn
in tools/make_tiki_idol.py.

Run from the repo root:  python3 tools/make_v2_table.py
"""
import random
from pathlib import Path

from PIL import Image

SRC = Path(__file__).parent / "source_art"
T = (0, 0, 0, 0)


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def shade(color, factor):
    return tuple(max(0, min(255, int(round(c * factor)))) for c in color[:3]) + (color[3],)


# ---------- the walls: where decoration may be painted ----------

def wall_mask(art):
    """Every pixel of brick wall reachable from the top-right corner, without crossing
    into the playfield (the orbit rims and floors aren't brick colours)."""
    bricks = {art.getpixel((x, y))[:3] for x in range(170, 256) for y in range(0, 40)}
    w, h = art.size
    seen = [[False] * w for _ in range(h)]
    stack = [(255, 0), (0, 0)]
    while stack:
        x, y = stack.pop()
        if not (0 <= x < w and 0 <= y < h) or seen[y][x] or art.getpixel((x, y))[:3] not in bricks:
            continue
        seen[y][x] = True
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return seen


# ---------- the ziggurat ----------

CX = 224  # the doorway's centre column; the shrine chute's walls are built around it (scene x 600-662)
OUTLINE = hexc("#2c3448")
SAND_HI = hexc("#ecd8a0")
SAND_LT = hexc("#d4b06c")
SAND = hexc("#ae8649")
SAND_DK = hexc("#966a27")
SAND_DD = hexc("#6a4818")
DOOR = hexc("#1a1e2c")
DOOR_IN = hexc("#262c40")
MOSS = hexc("#18b818")
MOSS_DK = hexc("#105808")
GOLD = hexc("#f8d000")
GOLD_DK = hexc("#c8a000")
JADE = hexc("#089890")
RAMP = hexc("#f8a008")
RAMP_DK = hexc("#d07808")
RAIL_DK = hexc("#105808")
RAIL = hexc("#18b818")
RAIL_LT = hexc("#d0f8d0")
SOCKET = hexc("#344761")

# Tiers, top to bottom: (left x, right x, top y, bottom y), symmetric about CX
SHRINE = (204, 244, 4, 24)
TIERS = [(202, 246, 24, 34), (196, 252, 34, 46), (190, 258, 46, 58), (184, 264, 58, 79)]
STAIRS = (217, 231, 24, 58)
DOORWAY = (215, 233, 60, 76)
CHUTE = (212, 236, 70, 101)    # down over the orbit to the ramp's top branch (Sprites/map_f2.png)
# Sprite spots (art pixels), read by Scripts/table_features.gd
MASK_AT = (224.0, 14.5)
LAMPS_AT = [(203.0, 52.0), (245.0, 52.0), (208.0, 40.0), (240.0, 40.0)]
FIRE_BOWLS_AT = [(204.0, 71.0), (244.0, 71.0)]
# The golden idol's plinth, mid-table above the temple hole (Scripts/idol.gd stands it at
# scene (337, 586), art (119.8, 194.1))
PLINTH = (112, 127, 200, 205)


def ziggurat():
    layer = Image.new("RGBA", (256, 424), T)
    rng = random.Random(23)

    def put(x, y, c):
        if 0 <= x < 256 and 0 <= y < 424:
            layer.putpixel((x, y), c)

    def block(x0, x1, y0, y1, top_rows):
        """One stepped tier: a lit ledge on top, a face of cut blocks below. Lit from
        the top left like the walls, so the right half of each face falls into shade."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if y < y0 + top_rows:
                    c = SAND_HI if y == y0 else SAND_LT
                else:
                    row = y - y0 - top_rows
                    course = row // 4
                    joint = (x - x0 + (course % 2) * 4) % 8 == 0
                    c = SAND_DK if row % 4 == 3 or joint else SAND
                    if x > CX + 2 and c == SAND:
                        c = shade(SAND, 0.9)
                    if y == y1:
                        c = SAND_DD
                put(x, y, c)
        # the shadow the ledge above casts on the face
        for x in range(x0, x1 + 1):
            put(x, y0 + top_rows, SAND_DD if x > CX else SAND_DK)

    # the tiers, widest at the bottom
    for x0, x1, y0, y1 in reversed(TIERS):
        block(x0, x1, y0, y1, 2)
    # a stepped-fret frieze along the bottom tier
    for x in range(TIERS[-1][0] + 2, TIERS[-1][1] - 1):
        k = (x - TIERS[-1][0]) % 6
        put(x, 74, SAND_DD)
        put(x, 75 if k < 3 else 73, SAND_DD)

    # the shrine on top: roof comb, roof, and the dark chamber behind Tlaloc's mask
    x0, x1, y0, y1 = SHRINE
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(x, y, SAND if x <= CX + 2 else shade(SAND, 0.9))
    for x in range(x0 - 2, x1 + 3):
        put(x, y0, SAND_HI)
        put(x, y0 + 1, SAND_LT)
        put(x, y0 + 2, SAND_DK)
    for i, x in enumerate(range(x0 + 4, x1 - 3)):
        for y in range(0, y0):
            if (x - x0) % 5 != 0 or y > 2:  # the comb's open slots
                put(x, y, SAND_LT if y < 2 else SAND)
    for y in range(y0 + 3, y1 + 1):
        for x in range(x0 + 2, x1 - 1):
            put(x, y, DOOR_IN)
    for x in range(x0 + 2, x1 - 1):
        put(x, y0 + 3, DOOR)

    # the stairs up the front, between two balustrades
    sx0, sx1, sy0, sy1 = STAIRS
    for y in range(sy0, sy1 + 1):
        for x in range(sx0, sx1 + 1):
            if x in (sx0, sx1):
                c = SAND_DD if x == sx1 else SAND_DK
            elif x in (sx0 + 1, sx1 - 1):
                c = SAND_LT if x == sx0 + 1 else SAND
            else:
                c = SAND_HI if (y - sy0) % 2 == 0 else SAND_DK
            put(x, y, c)

    # the doorway the offerings go in, with a gold lintel
    dx0, dx1, dy0, dy1 = DOORWAY
    for y in range(dy0, dy1 + 1):
        for x in range(dx0, dx1 + 1):
            corner = y == dy0 and x in (dx0, dx1)
            if not corner:
                put(x, y, DOOR if y < dy0 + 4 else DOOR_IN)
    for x in range(dx0 - 1, dx1 + 2):
        put(x, dy0 - 2, GOLD)
        put(x, dy0 - 1, GOLD_DK if (x - dx0) % 3 else JADE)

    # sockets for the raindrop lamps and the fire bowls' plinths
    for lx, ly in LAMPS_AT:
        for y in range(int(ly) - 4, int(ly) + 4):
            for x in range(int(lx) - 6, int(lx) + 6):
                put(x, y, SOCKET if y in (int(ly) - 4, int(ly) + 3) or x in (int(lx) - 6, int(lx) + 5) else DOOR_IN)
    for bx, by in FIRE_BOWLS_AT:
        for y in range(int(by) + 2, int(by) + 6):
            for x in range(int(bx) - 4, int(bx) + 5):
                put(x, y, SAND_DD if y == int(by) + 5 else SAND_LT if y == int(by) + 2 else SAND_DK)

    # moss and vines creeping over the corners
    for x0, x1, y0, y1 in TIERS:
        for x in (x0, x0 + 1, x1 - 1, x1):
            for y in range(y0, y1):
                if rng.random() < 0.35:
                    put(x, y, MOSS if rng.random() < 0.6 else MOSS_DK)
        for _ in range(4):
            x = rng.randrange(x0, x1)
            if not STAIRS[0] - 1 <= x <= STAIRS[1] + 1:
                put(x, y0, MOSS)
                put(x, y0 + 1, MOSS_DK)

    # outline the whole silhouette
    alpha = [[layer.getpixel((x, y))[3] > 0 for x in range(256)] for y in range(424)]
    for y in range(424):
        for x in range(256):
            if not alpha[y][x] and any(0 <= x + dx < 256 and 0 <= y + dy < 424 and alpha[y + dy][x + dx]
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                layer.putpixel((x, y), OUTLINE)
    return layer


def chute():
    """The doorway's channel down to the ramp's top branch, in the ramps' colours."""
    layer = Image.new("RGBA", (256, 424), T)
    x0, x1, y0, y1 = CHUTE
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if x in (x0, x1):
                c = RAIL_DK
            elif x in (x0 + 1, x1 - 1):
                c = RAIL if x == x0 + 1 else RAIL_LT
            else:
                c = RAMP_DK if (x - x0 + y) % 7 == 0 else RAMP
            layer.putpixel((x, y), c)
    # the channel runs out of the dark of the doorway
    for x in range(x0 + 2, x1 - 1):
        for y in range(y0, y0 + 3):
            layer.putpixel((x, y), shade(RAMP, 0.45 + 0.18 * (y - y0)))
    return layer


def plinth(base):
    x0, x1, y0, y1 = PLINTH
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y == y1
            c = OUTLINE if edge else SAND_HI if y == y0 else SAND_LT if y == y0 + 1 else SAND if x <= 120 else SAND_DK
            base.putpixel((x, y), c)
    for x in range(x0 + 1, x1):  # its shadow on the floor
        p = base.getpixel((x + 2, y1 + 1))
        base.putpixel((x + 2, y1 + 1), shade(p, 0.8))


# ---------- leaves ----------

# Where tufts grow out of the walls (top-left corner of the stamp, art pixels)
LEAF_SPOTS = [(150, 28, True), (238, 80, False), (2, 4, False), (100, 2, True), (223, 300, False), (0, 290, True)]


def leaves(base, walls):
    tuft = Image.open(SRC / "leaves.png").convert("RGBA")
    for x0, y0, flip in LEAF_SPOTS:
        stamp = tuft.transpose(Image.FLIP_LEFT_RIGHT) if flip else tuft
        for y in range(stamp.height):
            for x in range(stamp.width):
                p = stamp.getpixel((x, y))
                tx, ty = x0 + x, y0 + y
                if p[3] and 0 <= tx < 256 and 0 <= ty < 424 and walls[ty][tx]:
                    base.putpixel((tx, ty), p)


# ---------- sprites cut from the hand-drawn sheets ----------

def ball_tiers():
    """Stone (as drawn), jade, turquoise and gold: the lit half of the ball takes the
    tier's colour; the grey half, the outline and the shine stay as drawn."""
    sheet = Image.open(SRC / "pinball_sprite.png").convert("RGBA")
    lit = {(0xf8, 0xf8, 0xf8): 0, (0xe4, 0xe4, 0xe4): 0, (0xb0, 0xb8, 0xf0): 1, (0x40, 0x50, 0xc8): 2}
    tiers = [None,
             [hexc("#c8f8d8"), hexc("#40c070"), hexc("#107040")],
             [hexc("#c0f8f8"), hexc("#40d0e0"), hexc("#1078a0")],
             [hexc("#fff0a0"), hexc("#f8c000"), hexc("#b07000")]]
    out = Image.new("RGBA", (sheet.width, sheet.height * len(tiers)), T)
    for row, colors in enumerate(tiers):
        for y in range(sheet.height):
            for x in range(sheet.width):
                p = sheet.getpixel((x, y))
                if colors and p[3] and p[:3] in lit:
                    p = colors[lit[p[:3]]]
                out.putpixel((x, row * sheet.height + y), p)
    return out


def torch_sheet():
    """The six burning frames, then six embers: the same torch with the flame burnt
    down to a few coals glowing in the bowl."""
    sheet = Image.open(SRC / "torch.png").convert("RGBA")
    out = Image.new("RGBA", (sheet.width * 2, sheet.height), T)
    out.paste(sheet, (0, 0))
    bowl_top = 12  # rows above this are flame
    rng = random.Random(5)
    for frame in range(6):
        for y in range(sheet.height):
            for x in range(16):
                p = sheet.getpixel((frame * 16 + x, y))
                if not p[3]:
                    continue
                if y < bowl_top - 2:
                    continue
                if y < bowl_top:
                    if rng.random() < 0.6:
                        p = hexc("#bd3410") if rng.random() < 0.7 else hexc("#d58144")
                    else:
                        continue
                out.putpixel((sheet.width + frame * 16 + x, y), p)
    return out


def jaguar_sheet():
    """The hand-drawn jaguar, turned to face into the table. Its three brow spots light
    gold a step at a time; roaring, its eye blazes; asleep, its eye shuts."""
    head = Image.open(SRC / "jaguar.png").convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT)
    w, h = head.size
    red = {}
    for y in range(h):
        for x in range(w):
            p = head.getpixel((x, y))
            if p[3] and p[0] > 200 and p[1] < 60 and p[2] < 60:
                red[(x, y)] = p
    # three rosettes across the brow, behind the eye, lit nearest the eye first
    brow = [[(9, 6), (10, 6)], [(12, 7), (13, 7)], [(15, 8), (16, 8)]]
    frames = []
    for lit in range(4):
        f = head.copy()
        for rosette in brow[:lit]:
            for x, y in rosette:
                f.putpixel((x, y), GOLD)
        frames.append(f)
    roar = frames[3].copy()
    for (x, y) in red:
        roar.putpixel((x, y), hexc("#fff890"))
    frames.append(roar)
    sleep = head.copy()
    for (x, y) in red:
        sleep.putpixel((x, y), hexc("#402000"))
    frames.append(sleep)
    out = Image.new("RGBA", (w * len(frames), h), T)
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def fire_bowl():
    bowl = Image.new("RGBA", (12, 5), T)
    for y in range(5):
        for x in range(12):
            inset = y // 2
            if inset <= x < 12 - inset:
                c = GOLD if y == 0 else (hexc("#8a5610") if y < 4 else hexc("#402000"))
                bowl.putpixel((x, y), c)
    return bowl


def main():
    base = Image.open(SRC / "map_f1_v2.png").convert("RGBA")
    walls = wall_mask(base)
    zig = ziggurat()
    for y in range(424):
        for x in range(256):
            p = zig.getpixel((x, y))
            if p[3] and walls[y][x]:
                base.putpixel((x, y), p)
    base.alpha_composite(chute())
    plinth(base)
    chute_box = CHUTE
    leaves(base, [[walls[y][x] and zig.getpixel((x, y))[3] == 0
                   and not (chute_box[0] <= x <= chute_box[1] and chute_box[2] <= y <= chute_box[3])
                   for x in range(256)] for y in range(424)])
    base.save("Sprites/map_f1.png")
    Image.open(SRC / "map_f2.png").convert("RGBA").save("Sprites/map_f2.png")

    ball_tiers().save("Sprites/ball_spin.png")
    for name in ("bumper_mushroom.png", "bumper_mushroom_dust.png", "paddle_left.png", "paddle_right.png"):
        Image.open(SRC / name).convert("RGBA").save(name)
    torch_sheet().save("Sprites/table/torch.png")
    Image.open(SRC / "fire.png").convert("RGBA").save("Sprites/table/fire.png")
    fire_bowl().save("Sprites/table/fire_bowl.png")
    Image.open(SRC / "flipper.png").convert("RGBA").save("Sprites/table/spinner.png")
    jaguar_sheet().save("Sprites/table/jaguar.png")
    Image.open(SRC / "magicWhirl.png").convert("RGBA").save("Sprites/table/whirl.png")
    print("wrote the table and its sprites")


if __name__ == "__main__":
    main()
