"""Generate the spinner: Sprites/table/spinner.png.

A plate hung between two stone posts across the left loop lane, seen from above. It
turns through 8 frames: the gold face (with a sun mark) narrows to its edge, the jade
back comes round, and back to gold. Each frame mirrors left to right exactly.

Drawn at the table art's native resolution (map_f1.png is 256x424) with colors
sampled from it. Run from the repo root:  python3 tools/make_spinner_sprites.py
"""
import math
from pathlib import Path

from pixel_art import Canvas, asymmetry, strip

OUT = Path("Sprites/table/spinner.png")
W, H = 22, 9
FRAMES = 8

INK = (0x16, 0x0E, 0x20, 255)
STONE_D = (0x57, 0x6E, 0x78, 255)
STONE = (0x74, 0x8C, 0x9A, 255)
STONE_L = (0x9E, 0xB2, 0xBC, 255)
GOLD = (0xF8, 0xD0, 0x00, 255)
GOLD_D = (0xC0, 0x8A, 0x10, 255)
ORANGE = (0xF8, 0xA0, 0x08, 255)
PALE = (0xF0, 0xF0, 0x90, 255)
JADE_D = (0x25, 0x5C, 0x4B, 255)
JADE = (0x33, 0x77, 0x61, 255)
GREEN = (0x1E, 0xB6, 0x21, 255)


def frame(i):
    c = Canvas(W, H)
    angle = 2 * math.pi * i / FRAMES
    half = abs(math.cos(angle)) * 3.0  # how tall the plate looks from above
    front = math.cos(angle) >= 0
    top, face, mark = (PALE, GOLD, ORANGE) if front else (GREEN, JADE, JADE_D)
    mid = H / 2
    if half < 0.6:
        c.rect(4, 4, W - 5, 4, GOLD_D)  # edge on
    else:
        y0, y1 = int(round(mid - half)), int(round(mid + half)) - 1
        c.rect(4, y0, W - 5, y1, face)
        c.rect(4, y0, W - 5, y0, top)
        if y1 - y0 >= 2:
            c.rect(10, y0 + 1, 11, y1 - 1, mark)  # the sun mark, or the jade back's seam
    # the posts it hangs between, lit from the top
    for x in (1, W - 2):
        c.ellipse(x + 0.5, mid, 1.6, 2.4, STONE)
        c.set(x, 3, STONE_L)
        c.set(x, 5, STONE_D)
    c.mirror()
    c.outline(INK)
    return c.image()


def main():
    frames = [frame(i) for i in range(FRAMES)]
    for f in frames:
        assert asymmetry(f) == 0, "the spinner must mirror exactly"
    strip(frames).save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
