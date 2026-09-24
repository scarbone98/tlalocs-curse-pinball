"""Generate the jaguar in its den: Sprites/table/jaguar.png.

A jaguar peering out of the little arch right of the right ramp's mouth. Shots up into
the den light the rosettes on its brow in symmetric steps (the centre one, the inner
pair, the outer pair); all three steps earn an extra ball. Six frames: none, one, two
and three steps lit, roaring, and asleep while it rests after giving one away. Drawn
on the left and mirrored, so it's exactly symmetrical.

Drawn at the table art's native resolution (map_f1.png is 256x424) with colors
sampled from it. Run from the repo root:  python3 tools/make_jaguar_sprites.py
"""
from pathlib import Path

from pixel_art import Canvas, asymmetry, strip

OUT = Path("Sprites/table/jaguar.png")
INK=(0x16,0x0E,0x20,255); FUR=(0xF8,0xA0,0x08,255); FUR_L=(0xF8,0xD0,0x00,255); FUR_D=(0xBE,0x56,0x2E,255)
CREAM=(0xF0,0xF0,0x90,255); SPOT=(0x5A,0x2A,0x18,255); WHITE=(0xDE,0xF1,0xEE,255)
JADE=(0x1E,0xB6,0x21,255); TURQ=(0x8B,0xE6,0xEE,255); MOUTH=(0x6A,0x1A,0x1A,255); PALE=(0xFF,0xFF,0xE0,255)
W, H = 13, 13
# Forehead rosettes, lit a step per shot so the face stays symmetrical: the centre one,
# then the inner pair, then the outer pair
STEPS = [[(6, 3)], [(4, 4), (8, 4)], [(3, 2), (9, 2)]]

def jaguar(lit, state="idle"):
    c = Canvas(W, H)
    c.ellipse(2.8, 2.2, 1.6, 1.6, FUR_D)                      # ears
    c.ellipse(6.5, 7.0, 5.2, 5.0, FUR)                        # head
    c.rect(3, 2, 6, 3, FUR_L)                                 # lit brow
    c.ellipse(6.5, 9.4, 2.6, 2.0, CREAM)                      # muzzle
    c.set(6, 8, INK)                                          # nose
    if state == "sleep":
        c.rect(3, 6, 4, 6, SPOT)                              # eyes shut
    else:
        c.rect(3, 5, 4, 6, JADE if state == "idle" else PALE); c.set(4, 6, INK)
    if state == "roar":
        c.rect(5, 10, 6, 11, MOUTH); c.set(5, 10, WHITE)      # jaws open, a fang
    else:
        c.set(6, 11, SPOT)
    c.set(2, 8, SPOT)                                         # cheek spot
    c.mirror()
    for step, spots in enumerate(STEPS):
        for x, y in spots:
            c.set(x, y, TURQ if step < lit else SPOT)
    c.outline(INK)
    return c.image()


def main():
    frames = [jaguar(n) for n in range(4)] + [jaguar(3, "roar"), jaguar(0, "sleep")]
    for frame in frames:
        assert asymmetry(frame) == 0, "the jaguar must mirror exactly"
    strip(frames).save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
