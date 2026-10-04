"""Draw the second and third of Tlaloc's sacrifices (the first is the beating heart).

  Sprites/table/sacrifice_goat.png    26x20 frames x6: a white goat with curling horns and
                                      a beard - standing, its tail flicking, blinking, bleating
  Sprites/table/sacrifice_turkey.png  26x22 frames x6: a bronze turkey (huexolotl, the
                                      Aztecs' sacrificial bird), its tail fanned - standing,
                                      the fan quivering, blinking, gobbling with its wattle shaking

Drawn at the table art's native resolution (256x424), like everything on the table, and
shown at the table's scale by Scripts/sacrifices.gd. Run from the repo root:
  python3 tools/make_sacrifice_sprites.py
"""
from pathlib import Path

from PIL import Image

OUT_DIR = Path("Sprites/table")
T = (0, 0, 0, 0)

#   o ink   W wool   w wool, shaded   H horn   h horn, dark   k eye   P pink   L hoof
GOAT = [
    "....................oo....",
    "...................oHHo...",
    "..................oHhoHo..",
    "...............oo.oHo.oo..",
    "..............oPWooWWo....",
    "...............oWWWWWWo...",
    "...............oWWWkWWWo..",
    "..ooo..........oWWWWWWWWo.",
    ".oWWWo.........owWWWWWPPo.",
    ".oWwWoooooooooowwWWWWooo..",
    "..oWWWWWWWWWWWWwwwWWo.....",
    "..oWWWWWWWWWWWWWwwwwo.....",
    "..owWWWWWWWWWWWWWwwo......",
    "..owwWWWWWWWWWWWWwwo......",
    "..owwwwWWWWWWWWwwwo.......",
    "...owwwwwwwwwwwwwo........",
    "...oWo.oWo..oWo.oWo.......",
    "...oWo.oWo..oWo.oWo.......",
    "...oLo.oLo..oLo.oLo.......",
    "...ooo.ooo..ooo.ooo.......",
]
GOAT_COLOURS = {
    "o": (28, 22, 30), "W": (236, 230, 214), "w": (176, 166, 150), "H": (196, 160, 104),
    "h": (120, 92, 56), "k": (20, 16, 20), "P": (226, 150, 150), "L": (60, 48, 44),
}

#   o ink   F tail feather   f feather band   D bronze   d bronze, dark   B head   k eye
#   Y beak, legs   R wattle
TURKEY = [
    "..........................",
    "..........................",
    "..........................",
    "..........................",
    ".....................oo...",
    "....................oBBo..",
    "....................oBkBo.",
    "....................oBBBYY",
    "....................oRBBo.",
    "....................oRRo..",
    "............oDDooo..oRBo..",
    "...........oDDdDDDooBBo...",
    "..........oDDdDdDDDDBo....",
    ".....oooDDdDdDdDDDDDo.....",
    ".......oDdDdDdDdDDDDo.....",
    ".......oDDdDdDdDDDDo......",
    "........oDDdDdDDDDo.......",
    ".........ooDDDDDoo........",
    "...........oYooYo.........",
    "...........oYooYo.........",
    "..........oYYooYYo........",
    "..........oooooooo........",
]
TURKEY_COLOURS = {
    "o": (24, 16, 12), "F": (150, 96, 50), "f": (236, 214, 170), "D": (116, 84, 52),
    "d": (60, 90, 70), "B": (150, 170, 196), "k": (16, 12, 12), "Y": (214, 160, 70),
    "R": (210, 40, 40),
}


def draw(grid, colours, swap=None, shift=None):
    """One frame: `swap` recolours single pixels {(x, y): key}, `shift` moves whole cells
    {(x, y): (dx, dy)} before drawing (a flicking tail, a shaking wattle)."""
    w, h = len(grid[0]), len(grid)
    img = Image.new("RGBA", (w, h), T)
    swap = swap or {}
    shift = shift or {}
    for y, row in enumerate(grid):
        for x, key in enumerate(row):
            key = swap.get((x, y), key)
            if key not in colours:
                continue
            dx, dy = shift.get((x, y), (0, 0))
            if 0 <= x + dx < w and 0 <= y + dy < h:
                img.putpixel((x + dx, y + dy), colours[key] + (255,))
    return img


def cells(grid, x0, y0, x1, y1):
    return [(x, y) for y in range(y0, y1) for x in range(x0, x1) if grid[y][x] != "."]


def goat_frames():
    still = draw(GOAT, GOAT_COLOURS)
    tail = draw(GOAT, GOAT_COLOURS, shift={c: (0, -1) for c in cells(GOAT, 0, 7, 6, 10)})
    blink = draw(GOAT, GOAT_COLOURS, swap={(19, 6): "W"})
    bleat = draw(GOAT, GOAT_COLOURS, swap={(21, 9): "o", (22, 9): "P", (23, 9): "o"})  # its mouth open
    return [still, still, tail, blink, bleat, bleat]


FAN_CENTRE = (10.5, 13.0)
FAN_RADIUS = 11.5


def fan(quiver=0.0):
    """The tail fanned out behind it: feathers radiating from its rump, each bronze with a
    dark bar and a pale tip, the edge inked. `quiver` turns the feathers a touch."""
    import math
    w, h = len(TURKEY[0]), len(TURKEY)
    img = Image.new("RGBA", (w, h), T)
    cx, cy = FAN_CENTRE
    for y in range(h):
        for x in range(w):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx * 0.95, dy)
            if r > FAN_RADIUS or dy > 1.5:
                continue
            angle = math.atan2(dy, dx) + quiver
            if r > FAN_RADIUS - 1:
                col = TURKEY_COLOURS["o"]
            elif r > FAN_RADIUS - 2.6:
                col = TURKEY_COLOURS["f"]          # the pale tips
            elif r > FAN_RADIUS - 4:
                col = (40, 26, 18)                 # the dark bar
            else:
                feather = int((angle + math.pi) / 0.34) % 2
                col = TURKEY_COLOURS["F"] if feather else (124, 76, 40)
            img.putpixel((x, y), col + (255,))
    return img


def turkey_frame(quiver=0.0, **kw):
    out = fan(quiver)
    out.alpha_composite(draw(TURKEY, TURKEY_COLOURS, **kw))
    return out


def turkey_frames():
    still = turkey_frame()
    shiver = turkey_frame(0.17)  # the fan quivers
    blink = turkey_frame(swap={(22, 6): "B"})
    wattle = cells(TURKEY, 20, 8, 24, 11)
    gobble = turkey_frame(shift={c: (1, 0) for c in wattle})
    gobble2 = turkey_frame(shift={c: (-1, 0) for c in wattle})
    return [still, shiver, still, blink, gobble, gobble2]


def sheet(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), T)
    for i, fr in enumerate(frames):
        out.paste(fr, (i * w, 0))
    return out


def main():
    sheet(goat_frames()).save(OUT_DIR / "sacrifice_goat.png")
    sheet(turkey_frames()).save(OUT_DIR / "sacrifice_turkey.png")
    print("wrote", OUT_DIR / "sacrifice_goat.png", "and", OUT_DIR / "sacrifice_turkey.png")


if __name__ == "__main__":
    main()
