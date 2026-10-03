"""Draw the UI's pixel-art frames in the temple's stone and gold.

  ui/frames/panel.png         dark stone slab, gold trim and step-fret corners (menus,
                              the market, the end-of-ball bonus, the banners)
  ui/frames/button.png        a stone button: up, lit (hover/focus, gold edge) and pressed,
                              side by side
  ui/frames/pill.png          the small slab behind the score, the balls and the jade count

Each is drawn at the table art's own pixel size and then scaled up 3x (nearest), the
same as the table on screen, so the scene's StyleBoxTextures (ui/temple_theme.gd)
can nine-slice them without blurring. Run from the repo root:  python3 tools/make_ui.py
"""
from pathlib import Path

from PIL import Image

OUT = Path("ui/frames")
SCALE = 3
T = (0, 0, 0, 0)


def c(value, alpha=255):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


INK = c("#141824")
STONE_DD = c("#232b3a")
STONE_D = c("#344761")
STONE = c("#566d77")
STONE_L = c("#88a3ab")
STONE_H = c("#a4bac3")
GOLD = c("#f8d000")
GOLD_D = c("#c88a10")
JADE = c("#20d8a0")


def slab(size, fill, top, bottom, edge, corner_steps=True, inlay=None):
    """A square slab, nine-sliced in-game: outline, a bevel (lit top, shaded bottom), a
    trim line, and a stepped gold notch in each corner."""
    img = Image.new("RGBA", (size, size), T)
    px = img.load()
    for y in range(size):
        for x in range(size):
            border = min(x, y, size - 1 - x, size - 1 - y)
            if border == 0:
                col = INK
            elif border == 1:
                col = top if y < size // 2 and y <= x and y <= size - 1 - x else (bottom if y > size // 2 else (top if x < size // 2 else bottom))
                col = top if y == 1 or x == 1 else bottom if y == size - 2 or x == size - 2 else col
            elif border == 2:
                col = edge
            else:
                col = fill
            px[x, y] = col
    if corner_steps:
        for cx, cy, dx, dy in ((3, 3, 1, 1), (size - 4, 3, -1, 1), (3, size - 4, 1, -1), (size - 4, size - 4, -1, -1)):
            for i, j in ((0, 0), (1, 0), (0, 1), (2, 0), (0, 2), (2, 1), (1, 2)):
                px[cx + i * dx, cy + j * dy] = GOLD if (i + j) % 2 == 0 else GOLD_D
    if inlay:
        mid = size // 2
        px[mid, 3] = inlay
        px[mid, size - 4] = inlay
    return img


def up(img):
    return img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    up(slab(16, STONE_DD, STONE_D, INK, GOLD_D)).save(OUT / "panel.png")
    states = [
        slab(12, STONE, STONE_H, STONE_D, STONE_L, corner_steps=False),   # up
        slab(12, STONE_D, STONE_H, STONE_DD, GOLD, corner_steps=False),   # lit: hover / focus, dark so gold text reads
        slab(12, STONE_DD, INK, STONE_L, GOLD_D, corner_steps=False),     # pressed: bevel flipped
    ]
    sheet = Image.new("RGBA", (12 * 3, 12), T)
    for i, state in enumerate(states):
        sheet.paste(state, (i * 12, 0))
    up(sheet).save(OUT / "button.png")
    up(slab(10, c("#1a2130", 225), STONE_D, INK, GOLD_D, corner_steps=False)).save(OUT / "pill.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
