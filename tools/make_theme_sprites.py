"""Generate Tlaloc-themed replacements for the ball, bumpers and flippers.

Writes over the files the scenes already reference, so no scene edits are needed:

  Sprites/pinball_sprite.png     16 frames of a silver ball with a spinning jade glyph
  bumper_mushroom.png            frog-on-lily-pad bumper (idle, hit)
  bumper_mushroom_dust.png       5-frame water splash played on each bumper hit
  paddle_left.png / right.png    gold flippers (recolored from tools/source_art)

(The bumper files keep their old "mushroom" names so existing scenes keep working.)
Run from the repo root:  python3 tools/make_theme_sprites.py
"""
import math
from pathlib import Path

from PIL import Image

SRC = Path(__file__).parent / "source_art"
T = (0, 0, 0, 0)


def rgba(hex_color, alpha=255):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def from_rows(rows, key):
    img = Image.new("RGBA", (len(rows[0]), len(rows)), T)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), key[ch])
    return img


def strip(frames):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), T)
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * w, 0))
    return sheet


def upscale(img, factor):
    return img.resize((img.width * factor, img.height * factor), Image.NEAREST)


# --- ball ----------------------------------------------------------------------
def ball_frame(angle):
    size, r = 16, 7.0
    img = Image.new("RGBA", (size, size), T)
    light = (-0.5, -0.6, 0.62)
    for y in range(size):
        for x in range(size):
            nx, ny = (x + 0.5 - 8) / r, (y + 0.5 - 8) / r
            d2 = nx * nx + ny * ny
            if d2 > 1.0:
                continue
            nz = math.sqrt(1.0 - d2)
            lambert = max(0.0, nx * light[0] + ny * light[1] + nz * light[2])
            # Rotate the surface about the vertical axis so the glyph spins across the ball
            u = nx * math.cos(angle) + nz * math.sin(angle)
            w = -nx * math.sin(angle) + nz * math.cos(angle)
            on_glyph = w > 0 and (abs(u) < 0.14 or (0.28 < math.hypot(u, ny) < 0.5))
            if on_glyph:
                base = (46, 139, 106)
                shade = 0.55 + lambert * 0.7
            else:
                base = (198, 206, 216)
                shade = 0.45 + lambert * 0.75
            c = tuple(min(255, int(ch * shade)) for ch in base)
            if lambert > 0.93:
                c = (255, 255, 255)
            if d2 > 0.8:
                c = tuple(int(ch * 0.55) for ch in c)
            img.putpixel((x, y), c + (255,))
    return img


# --- frog bumper -------------------------------------------------------------
FROG = [
    ".oYo..oYo.",
    ".oko..oko.",
    "oGGGGGGGGo",
    "oGlGGGGlGo",
    "oGGGmmGGGo",
    ".oGGGGGGo.",
    "Fo.oGGo.oF",
    "FF..oo..FF",
]


def frog_frame(hit):
    pad = Image.new("RGBA", (14, 14), T)
    lily, lily_dark, glow = rgba("#1F5E45"), rgba("#123D2C"), rgba("#F5D77A")
    for y in range(14):
        for x in range(14):
            dx, dy = x + 0.5 - 7, y + 0.5 - 7
            d = math.hypot(dx, dy)
            if dx > 1 and abs(dy) < 1.2 and d > 2:
                continue  # notch cut into the pad
            if d <= 6.8:
                pad.putpixel((x, y), glow if (hit and d > 5.8) else (lily_dark if d > 5.8 else lily))
    key = {
        "o": rgba("#14301A"), "G": rgba("#A6E85A" if hit else "#7FCF45"), "l": rgba("#E4FFB0" if hit else "#C2F07A"),
        "Y": rgba("#FFE27A"), "k": rgba("#101010"), "m": rgba("#3F8A2A"), "F": rgba("#5DB23A"),
    }
    frog = from_rows(FROG, key)
    pad.alpha_composite(frog, (2, 3 if not hit else 2))
    return upscale(pad, 3)


def splash_frame(i):
    img = Image.new("RGBA", (14, 14), T)
    radius = [2.0, 3.5, 5.0, 6.0, 6.6][i]
    alpha = [230, 200, 160, 110, 60][i]
    foam, water = rgba("#E6FBFF", alpha), rgba("#8BE6EE", alpha)
    for y in range(14):
        for x in range(14):
            d = math.hypot(x + 0.5 - 7, y + 0.5 - 7)
            if abs(d - radius) < 0.55:
                img.putpixel((x, y), foam)
            elif abs(d - radius + 1) < 0.5:
                img.putpixel((x, y), water)
    for k in range(6):  # droplets flung outward
        a = k * math.pi / 3 + 0.4
        dist = radius + 1.5
        px, py = int(7 + math.cos(a) * dist), int(7 + math.sin(a) * dist)
        if 0 <= px < 14 and 0 <= py < 14:
            img.putpixel((px, py), foam)
    return upscale(img, 3)


# --- flippers ----------------------------------------------------------------
FLIPPER_MAP = {
    (0xF8, 0xF8, 0xF8): rgba("#F5D77A"),
    (0x70, 0xA8, 0xE8): rgba("#D9A62E"),
    (0x38, 0x68, 0xB0): rgba("#6B4A12"),
}


def recolor_flipper(name):
    src = Image.open(SRC / name).convert("RGBA")
    out = Image.new("RGBA", src.size, T)
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src.getpixel((x, y))
            if a:
                out.putpixel((x, y), FLIPPER_MAP.get((r, g, b), (r, g, b, a))[:3] + (a,))
    out.save(name)


def main():
    strip([ball_frame(i * 2 * math.pi / 16) for i in range(16)]).save("Sprites/pinball_sprite.png")
    strip([frog_frame(False), frog_frame(True)]).save("bumper_mushroom.png")
    strip([splash_frame(i) for i in range(5)]).save("bumper_mushroom_dust.png")
    recolor_flipper("paddle_left.png")
    recolor_flipper("paddle_right.png")
    print("wrote ball, frog bumper, splash and flipper sprites")


if __name__ == "__main__":
    main()
