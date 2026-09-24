"""Generate the pinball's spin frames: Sprites/ball_spin.png.

A silver stone ball carved with Tlaloc's water spiral in jade and three gold inlays,
seen from above like Pokemon Pinball's ball, so rolling shows as the carving turning in
place. The carving turns through 16 frames (22.5 degrees apart) while the light stays
at the top left.

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
# (shadow, mid, lit, shine) for the stone, sampled from the table art
SILVER = [(0x57, 0x6E, 0x78, 255), (0x9E, 0xB2, 0xBC, 255), (0xC6, 0xD8, 0xE0, 255), (0xDE, 0xF1, 0xEE, 255)]
JADE = [(0x1C, 0x3F, 0x35, 255), (0x25, 0x5C, 0x4B, 255), (0x1E, 0xB6, 0x21, 255)]
GOLD = (0xF8, 0xD0, 0x00, 255)
GOLD_D = (0xC0, 0x8A, 0x10, 255)
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


def frame(angle):
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
            color = SILVER[tone]
            u, v = dx * ca - dy * sa, dx * sa + dy * ca
            if on_spiral(u, v):
                color = JADE[2] if tone >= 2 else JADE[1] if tone >= 1 else JADE[0]
            if any(math.hypot(dx - ix, dy - iy) < 1.1 for ix, iy in inlays):
                color = GOLD if tone >= 1 else GOLD_D
            img.putpixel((px, py), color)
    # fixed glint, so the ball keeps its light while the carving turns
    for gx, gy in ((6, 5), (7, 5), (6, 6)):
        img.putpixel((gx, gy), SHINE)
    return img


def main():
    sheet = Image.new("RGBA", (SIZE * FRAMES, SIZE), T)
    for i in range(FRAMES):
        sheet.paste(frame(2 * math.pi * i / FRAMES), (i * SIZE, 0))
    sheet.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
