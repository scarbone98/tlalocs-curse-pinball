"""Generate the pinball's spin frames: Sprites/ball_spin.png.

A stone ball carved with Tlaloc's water spiral and three inlays, seen from above like
Pokemon Pinball's ball, so rolling shows as the carving turning in place. The carving
turns through 16 frames (22.5 degrees apart) while the light stays at the top left.

One row per ball upgrade, like Pokemon Pinball's Poke, Great, Ultra and Master Balls:
stone (x1), jade (x2), turquoise (x3) and gold (x5).

The sprite is drawn about 1.35x the ball's collision circle: bigger than the circle,
as Pokemon Pinball draws its ball, but not so much that it spills far over the walls
and posts it's passing.

Run from the repo root:  python3 tools/make_ball_sprites.py
"""
import math
from pathlib import Path

from PIL import Image

OUT = Path("Sprites/ball_spin.png")
SIZE = 20
FRAMES = 16
RADIUS = 9.6

T = (0, 0, 0, 0)
INK = (0x16, 0x0E, 0x20, 255)
# Per tier: the body (shadow, mid, lit, shine), the spiral (shadow, mid, lit) and the
# inlays (dark side, lit side). Colors sampled from the table art.
SILVER = [(0x57, 0x6E, 0x78, 255), (0x9E, 0xB2, 0xBC, 255), (0xC6, 0xD8, 0xE0, 255), (0xDE, 0xF1, 0xEE, 255)]
JADE_BODY = [(0x1C, 0x3F, 0x35, 255), (0x25, 0x5C, 0x4B, 255), (0x33, 0x77, 0x61, 255), (0x6F, 0xC0, 0x9A, 255)]
TURQ_BODY = [(0x14, 0x5A, 0x78, 255), (0x1A, 0x86, 0xA3, 255), (0x2A, 0x9E, 0xC8, 255), (0x8B, 0xE6, 0xEE, 255)]
GOLD_BODY = [(0xC0, 0x8A, 0x10, 255), (0xF8, 0xA0, 0x08, 255), (0xF8, 0xD0, 0x00, 255), (0xF0, 0xF0, 0x90, 255)]
JADE_LINE = [(0x1C, 0x3F, 0x35, 255), (0x25, 0x5C, 0x4B, 255), (0x1E, 0xB6, 0x21, 255)]
GOLD_LINE = [(0xC0, 0x8A, 0x10, 255), (0xF8, 0xA0, 0x08, 255), (0xF8, 0xD0, 0x00, 255)]
TURQ_LINE = [(0x14, 0x5A, 0x78, 255), (0x1A, 0x86, 0xA3, 255), (0x2A, 0x9E, 0xC8, 255)]
GOLD = (0xF8, 0xD0, 0x00, 255)
GOLD_D = (0xC0, 0x8A, 0x10, 255)
WHITE = (0xDE, 0xF1, 0xEE, 255)
CORAL = (0xE0, 0x60, 0x40, 255)
EMBER = (0xBE, 0x56, 0x2E, 255)
TIERS = [
    (SILVER, JADE_LINE, (GOLD_D, GOLD)),        # stone
    (JADE_BODY, GOLD_LINE, (WHITE, WHITE)),     # jade
    (TURQ_BODY, GOLD_LINE, (EMBER, CORAL)),     # turquoise
    (GOLD_BODY, TURQ_LINE, (WHITE, WHITE)),     # gold
]
SHINE = (0xFF, 0xFF, 0xFF, 255)
LIGHT = (-0.55, -0.65)  # from the top left


def facing(x, y):
    """How much this spot of the sphere faces the light, 0..1."""
    z = math.sqrt(max(0.0, 1.0 - x * x - y * y))
    lx, ly = LIGHT
    lz = math.sqrt(max(0.0, 1.0 - lx * lx - ly * ly))
    return max(0.0, x * lx + y * ly + z * lz)


def on_spiral(u, v):
    """Whether (u, v), in the ball's own turning frame, lies on the carved water spiral."""
    r = math.hypot(u, v)
    if r > 6.6:
        return False
    if r < 1.5:
        return True  # a solid eye at the centre, where the spiral starts
    # r grows 3.4px per turn; a point is on the line if its angle matches that radius.
    # The line takes half of each turn's width, so it stays unbroken at this size.
    turns = (r - 1.5) / 3.4
    angle = math.atan2(v, u) / (2 * math.pi)
    return abs(((turns - angle) % 1.0) - 0.5) > 0.25


def frame(angle, tier=0):
    body, line, inlay = TIERS[tier]
    img = Image.new("RGBA", (SIZE, SIZE), T)
    c = SIZE / 2
    ca, sa = math.cos(-angle), math.sin(-angle)
    inlays = [(math.cos(angle + k * 2 * math.pi / 3) * 6.9, math.sin(angle + k * 2 * math.pi / 3) * 6.9)
              for k in range(3)]
    for py in range(SIZE):
        for px in range(SIZE):
            dx, dy = px + 0.5 - c, py + 0.5 - c
            d = math.hypot(dx, dy)
            if d > RADIUS:
                continue
            if d > RADIUS - 1.0:
                img.putpixel((px, py), INK)
                continue
            light = facing(dx / RADIUS, dy / RADIUS)
            tone = 3 if light > 0.93 else 2 if light > 0.7 else 1 if light > 0.35 else 0
            color = body[tone]
            u, v = dx * ca - dy * sa, dx * sa + dy * ca
            if on_spiral(u, v):
                color = line[min(tone, 2)]
            if any(math.hypot(dx - ix, dy - iy) < 1.1 for ix, iy in inlays):
                color = inlay[1] if tone >= 1 else inlay[0]
            img.putpixel((px, py), color)
    # fixed glint, so the ball keeps its light while the carving turns
    for gx, gy in ((6, 5), (7, 5), (6, 6)):
        img.putpixel((gx, gy), SHINE)
    return img


def main():
    sheet = Image.new("RGBA", (SIZE * FRAMES, SIZE * len(TIERS)), T)
    for tier in range(len(TIERS)):
        for i in range(FRAMES):
            sheet.paste(frame(2 * math.pi * i / FRAMES, tier), (i * SIZE, tier * SIZE))
    sheet.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
