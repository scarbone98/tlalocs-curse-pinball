"""Generate the Chac Mool: Sprites/table/chac_mool.png.

The reclining stone figure at the end of the U-shaped lane left of the frog pool,
holding his offering bowl on his belly. Four frames as shots up the lane fill the bowl
with water: empty, a third, two thirds, and full with a glint. Drawn on the left and
mirrored, so it's exactly symmetrical.

Drawn at the table art's native resolution (map_f1.png is 256x424) with colors
sampled from it. Run from the repo root:  python3 tools/make_chac_mool_sprites.py
"""
from pathlib import Path

from pixel_art import Canvas, asymmetry, strip

OUT = Path("Sprites/table/chac_mool.png")
INK=(0x16,0x0E,0x20,255); STONE_D=(0x57,0x6E,0x78,255); STONE=(0x74,0x8C,0x9A,255); STONE_L=(0x9E,0xB2,0xBC,255)
NAVY=(0x0F,0x26,0x41,255); BLUE=(0x2C,0x67,0xA4,255); TEAL=(0x1A,0x86,0xA3,255); TEAL_L=(0x8B,0xE6,0xEE,255)
WHITE=(0xDE,0xF1,0xEE,255); JADE=(0x33,0x77,0x61,255); GOLD=(0xF8,0xD0,0x00,255)
W, H = 21, 20
C = 10.5

def chac_mool(level):
    c = Canvas(W, H)
    # raised knees and shins, either side at the front
    c.ellipse(4.5, 14.5, 3.0, 3.6, STONE); c.ellipse(4.5, 13.2, 2.2, 1.4, STONE_L)
    c.rect(3, 17, 6, 18, STONE_D)                      # feet
    # torso, lit along its top
    c.ellipse(C, 10.5, 6.4, 5.2, STONE); c.ellipse(C, 8.2, 5.0, 1.6, STONE_L)
    # head turned toward you, with a flat headdress band
    c.ellipse(C, 3.6, 3.2, 3.2, STONE); c.ellipse(C, 2.6, 2.2, 1.2, STONE_L)
    c.rect(7, 0, 10, 0, JADE); c.rect(8, 1, 10, 1, JADE)   # jade headband
    c.set(9, 3, INK); c.set(9, 4, STONE_D)             # eye, cheek
    c.set(10, 6, STONE_D)                              # mouth
    # arms reaching down to hold the bowl
    c.rect(4, 9, 5, 12, STONE_D)
    # the offering bowl on his belly, filling with water
    c.ellipse(C, 12.4, 4.2, 2.6, INK)
    c.ellipse(C, 12.4, 3.4, 1.9, STONE_D)
    fill = [None, NAVY, BLUE, TEAL][level]
    if fill:
        c.ellipse(C, 12.4 + (3 - level) * 0.5, 3.4, 1.9 - (3 - level) * 0.45, fill)
    if level == 3:
        c.set(9, 12, TEAL_L); c.set(8, 12, WHITE)      # glint on the full bowl
    c.mirror()
    c.outline(INK)
    return c.image()



def main():
    frames = [chac_mool(level) for level in range(4)]
    for frame in frames:
        assert asymmetry(frame) == 0, "the Chac Mool must mirror exactly"
    strip(frames).save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
