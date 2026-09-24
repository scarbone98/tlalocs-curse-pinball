"""Generate the pinball's spin frames: Sprites/ball_spin.png.

Drawn like Pokemon Pinball's ball: seen from above, so rolling shows as the ball
turning in place. A jade top half and a silver bottom half, split by a dark band
with a stone button in the middle, turn through 16 frames (22.5 degrees apart).
The light stays fixed at the top left while the design turns under it.

The sprite is drawn bigger than the ball's collision circle, like Pokemon
Pinball's (its 16px ball collides as a 4px-radius circle), so the ball reads big
without getting any wider to the walls.

Run from the repo root:  python3 tools/make_ball_sprites.py
"""
import math
from pathlib import Path

from PIL import Image

OUT = Path("Sprites/ball_spin.png")
SIZE = 22
FRAMES = 16
RADIUS = 10.6

T = (0, 0, 0, 0)
INK = (0x16, 0x0E, 0x20, 255)
# (shadow, mid, lit) for each part of the ball, sampled from the table art
JADE = [(0x1C, 0x3F, 0x35, 255), (0x25, 0x5C, 0x4B, 255), (0x33, 0x77, 0x61, 255)]
SILVER = [(0x74, 0x8C, 0x9A, 255), (0xB4, 0xC4, 0xCC, 255), (0xDE, 0xF1, 0xEE, 255)]
BAND = [(0x16, 0x0E, 0x20, 255), (0x2A, 0x1E, 0x38, 255), (0x3A, 0x2C, 0x4C, 255)]
BUTTON = [(0x57, 0x6E, 0x78, 255), (0xDE, 0xF1, 0xEE, 255), (0xFF, 0xFF, 0xFF, 255)]
GLYPH = (0x1E, 0xB6, 0x21, 255)
SHINE = (0xFF, 0xFF, 0xFF, 255)
LIGHT = (-0.55, -0.65)  # from the top left


def shade(tones, x, y):
    """Pick shadow/mid/lit from how much this spot of the sphere faces the light."""
    z = math.sqrt(max(0.0, 1.0 - x * x - y * y))
    lx, ly = LIGHT
    lz = math.sqrt(max(0.0, 1.0 - lx * lx - ly * ly))
    facing = x * lx + y * ly + z * lz
    return tones[2] if facing > 0.75 else tones[1] if facing > 0.25 else tones[0]


def frame(angle):
    img = Image.new("RGBA", (SIZE, SIZE), T)
    c = SIZE / 2
    ca, sa = math.cos(-angle), math.sin(-angle)
    for py in range(SIZE):
        for px in range(SIZE):
            dx, dy = px + 0.5 - c, py + 0.5 - c
            d = math.hypot(dx, dy)
            if d > RADIUS:
                continue
            if d > RADIUS - 1.0:
                img.putpixel((px, py), INK)
                continue
            x, y = dx / RADIUS, dy / RADIUS  # position on the sphere, for lighting
            # the same spot in the ball's own turning frame, for the design
            u, v = dx * ca - dy * sa, dx * sa + dy * ca
            r = math.hypot(u, v)
            if r < 2.2:
                color = GLYPH if r < 1.0 else BUTTON[1]
            elif r < 3.4:
                color = INK
            elif abs(v) < 1.3:
                color = shade(BAND, x, y)
            elif v < 0:
                color = shade(JADE, x, y)
            else:
                color = shade(SILVER, x, y)
            img.putpixel((px, py), color)
    # fixed glint, so the ball keeps its light while the design turns
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
