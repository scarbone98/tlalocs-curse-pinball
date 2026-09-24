"""Generate Sprites/ramp_zone.png: where a ball on the ramp layer may legitimately be.

The ball uses it to catch a ball that clipped a ramp mouth and bounced back out onto
the playfield (see Scripts/ball.gd). It's the ramp art (Sprites/map_f2.png), but the
right ramp's lower stretch is drawn as two rails with the base table showing between
them, and a ball rolling up the middle of it looked "off the ramp" there, so it got
dropped through to roll under the ramp. A morphological closing (grow, then shrink
back) fills gaps like that between rails without moving the ramps' outer edges.

Run from the repo root:  python3 tools/make_ramp_zone.py
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

SRC = Path("Sprites/map_f2.png")
OUT = Path("Sprites/ramp_zone.png")
CLOSE_RADIUS = 9  # art pixels; the widest gap between rails is about 17


def main():
    art = Image.open(SRC).convert("RGBA")
    mask = art.getchannel("A").point(lambda a: 255 if a > 0 else 0)
    size = CLOSE_RADIUS * 2 + 1
    closed = mask.filter(ImageFilter.MaxFilter(size)).filter(ImageFilter.MinFilter(size))
    zone = ImageChops.lighter(closed, mask)  # never smaller than the art itself
    out = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    out.putalpha(zone)
    out.save(OUT)
    grown = sum(1 for v in zone.getdata() if v) - sum(1 for v in mask.getdata() if v)
    print("wrote", OUT, "(%d art pixels added between rails)" % grown)


if __name__ == "__main__":
    main()
