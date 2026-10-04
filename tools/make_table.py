"""Build the table from the hand-drawn layers in Sprites/layers/ and the layout mock-up.

  Sprites/layers/basemap.png  the playfield: walls, lanes, the warriors' round arena
  Sprites/layers/temple.png   the golden temple, top right
  Sprites/layers/rails.png    the two wire ramps, both running into the temple
  Sprites/exampleLayout.png   the layout mock-up: only the palms, the stone face in the
                              top left corner and the cap on the temple's pipe are copied
                              from it, so changes to the basemap always show through (the
                              other sprites in it are placed by the scripts)

It writes

  Sprites/map_f1.png        the base layer: basemap, the mock-up's palms and stone face,
                            a step-fret border round the whole rim of the walls, carved
                            glyphs, and the slots in the walls the jaguars hide in
  Sprites/map_palms.png     the mock-up's palms, over a ball on the playfield but under
                            the rails (and a ball riding them)
  Sprites/map_f2.png        the top layer: the temple and the rails
  Sprites/ramp_zone.png     where a ball on the rails may be (see Scripts/ball.gd)
  Scripts/rails_geometry.gd the rails' walls, traced from rails.png, with their ends, and
                            the line down the middle of each track a riding ball follows
                            (needs numpy and scipy)
                            left open (see Scripts/rails.gd)

and the playfield sprites cut from the hand-drawn sheets in tools/source_art/:

  Sprites/ball_spin.png       the ball's 16 roll frames, one row per ball upgrade (iron,
                              silver, emerald and gold, all hand-drawn)
  paddle_left.png, paddle_right.png
  Sprites/table/torch.png     6 burning frames, then the same 6 as embers
  Sprites/table/blue_flipper.png  15 frames of the flipper plate turning, in blue
  Sprites/table/wall_jaguar.png  the jaguar heads set in the side walls, facing into the
                              table from the left: watching, roaring, blinking
  Sprites/table/whirl.png     3 frames of the spirit whirl
  Sprites/face_sockets.png    the centre face without its eyes (eyeless.png: calm, struck)
  Sprites/table/face_eye.png  its eyes (yelloweye.png, redeye.png), drawn over the sockets
                              so they can follow the ball
  Sprites/table/sling_left_lit.png, sling_right_lit.png  the slingshots lit up as they kick
                              (bumperleftlightup.png, bumperrightlightup.png)
  Sprites/table/warrior.png   the arena's warriors (warrior.png, as drawn): four frames turning
                              round, then the fifth for when one's struck
  Sprites/table/skull_shine.png  the skull's brightest facets, for it to gleam in a light
  Sprites/table/skull_shimmer.png  a glint sweeping over the skull's dome (6 frames, a row
                              for each of its two frames), as the spotlight comes and goes
  Sprites/table/skull_top.png, skull_jaw.png  the skull's top (skullupper.png: shut, open)
                              and lower jaw (skulllower.png), drawn either side of the ball
  Sprites/table/tower_drum.png, spikes.png, torch_button.png  as drawn (spinningtower.png,
                              spikes.png, torchbutton.png)
  Sprites/table/spring.png    the plunger's spring, at rest down to fully pulled
  Sprites/table/rail_gem.png, rail_gem_shadow.png  the emerald hovering up the left rail
                              (plain, glinting) and its shadow
  Sprites/table/idol_spin.png the golden idol turning on its tower (from idol.png)
  Sprites/table/blood_heart.png  the beating heart for Tlaloc (8 Bit Evil Returns'
                              heartbeat.png, redrawn at half size)
  Sprites/table/spirit_lamp.png  the right lane's floor lamps (dark, lit)
  Sprites/table/shard.png     a crystal sliver, for the tower breaking
  Sprites/table/temple_interior.png  the inside of the golden temple, seen through its windows
  Sprites/table/arena_hole.png  the stone tablet in the warriors' arena (shut, open)
  Sprites/table/dart_falling.png, dart_stuck.png, dart_shadow.png  the poison dart trap's
                              darts: falling, stuck in the floor (still, quivering), and
                              the shadow of one falling
  Sprites/table/lava_glow.png, lava_embers.png  the lava pit (lava.png): its glow, and its
                              embers and edge in 4 frames
  Sprites/table/roulette_pictures.png, roulette_border.png, roulette_doors.png  the floor
                              roulette: its pictures (cities, then prizes), border and doors
  Sprites/table/claw_swipe.png  a jaguar's claw marks as it swipes (striking, full, fading)
  Sprites/table/leaf_bit.png  a scrap of frond a shaken palm drops
  Sprites/table/temple_gems_lit.png  the temple ring's gems, lit
  Scripts/table_geometry.gd   each palm's box, and the temple ring's gems in order

Everything is at the table art's native resolution (256x424), so the scene's
MAP_SCALE (720/256 by 1280/424) puts it all on one pixel grid.

Run from the repo root:  python3 tools/make_table.py
"""
import colorsys
import random
from pathlib import Path

from PIL import Image, ImageDraw

SRC = Path(__file__).parent / "source_art"
LAYERS = Path("Sprites/layers")
EXAMPLE = Path("Sprites/exampleLayout.png")
T = (0, 0, 0, 0)
SCALE = (720.0 / 256.0, 1280.0 / 424.0)


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


GOLD = hexc("#f8d000")
JADE = hexc("#089890")
CARVE = hexc("#3f5560")      # the shadow inside a carving
CARVE_LIT = hexc("#b4c8cf")  # its lit lower edge
FRIEZE = hexc("#7d96a0")
FRIEZE_EDGE = hexc("#566d77")


# ---------- masks ----------

def mask_of(image, test):
    w, h = image.size
    px = image.load()
    return [[test(px[x, y]) for x in range(w)] for y in range(h)]


def grow(mask, steps):
    """Dilates (steps > 0) or erodes (steps < 0) a mask by whole pixels, 8-connected."""
    h, w = len(mask), len(mask[0])
    out = mask
    for _ in range(abs(steps)):
        want = steps > 0
        nxt = [row[:] for row in out]
        for y in range(h):
            for x in range(w):
                if out[y][x] == want:
                    continue
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        yy, xx = y + dy, x + dx
                        if 0 <= yy < h and 0 <= xx < w and out[yy][xx] == want:
                            nxt[y][x] = want
                            break
                    else:
                        continue
                    break
        out = nxt
    return out


def wall_mask(art):
    """Every pixel of brick wall connected to the table's corners and edges, without
    crossing into the playfield (its rims and floors aren't brick colours)."""
    bricks = {art.getpixel((x, y))[:3] for x in range(0, 256) for y in range(0, 12)}
    w, h = art.size
    seen = [[False] * w for _ in range(h)]
    stack = [(x, 0) for x in range(0, w, 8)] + [(0, y) for y in range(0, h, 8)] + [(w - 1, y) for y in range(0, h, 8)]
    while stack:
        x, y = stack.pop()
        if not (0 <= x < w and 0 <= y < h) or seen[y][x] or art.getpixel((x, y))[:3] not in bricks:
            continue
        seen[y][x] = True
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return seen


# ---------- decor copied from the mock-up ----------

# Game sprites drawn into the mock-up, left out when copying its decor (art pixels)
SPRITE_BOXES = [
    (14, 211, 75, 288),     # the six torches and the stone buttons between them
    (48, 117, 72, 186),     # the three blue flippers
    (88, 232, 154, 299),    # the centre face
    (43, 286, 65, 312), (181, 286, 195, 313),  # the wall jaguars
    (118, 110, 166, 166),   # the warriors in the arena
    (76, 108, 103, 188),    # the idol's tower, its golden orb and the spikes before it
    (167, 147, 206, 192),   # the crystal skull
]
TOP_DECOR_BOXES = [(156, 20, 172, 46)]  # the temple pipe's cap goes on the top layer
STONE_FACE_BOX = (17, 15, 52, 50)        # the stone face in the top-left corner


def decor(base_layers):
    """The mock-up's own additions: its palms (pixels in the leaves' colours), the stone
    face and the pipe cap, wherever they differ from the layers stacked up and lie
    outside the game sprites' boxes. Nothing else is taken from it, so the basemap's own
    changes (the slingshots' colour, say) aren't painted over by an older mock-up."""
    example = Image.open(EXAMPLE).convert("RGBA")
    palm = {p[:3] for p in Image.open(SRC / "leaves.png").convert("RGBA").get_flattened_data() if p[3]}
    in_box = lambda x, y, box: box[0] <= x <= box[2] and box[1] <= y <= box[3]
    w, h = example.size
    bottom = Image.new("RGBA", (w, h), T)
    top = Image.new("RGBA", (w, h), T)
    ex, lay = example.load(), base_layers.load()
    rails = Image.open(LAYERS / "rails.png").convert("RGBA").load()
    for y in range(h):
        for x in range(w):
            a, b = ex[x, y], lay[x, y]
            if max(abs(a[i] - b[i]) for i in range(3)) <= 6:
                continue
            if any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in SPRITE_BOXES):
                continue
            wanted = a[:3] in palm or in_box(x, y, STONE_FACE_BOX) or any(in_box(x, y, box) for box in TOP_DECOR_BOXES)
            if not wanted:
                continue
            on_top = rails[x, y][3] > 0 or any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in TOP_DECOR_BOXES)
            (top if on_top else bottom).putpixel((x, y), a)
    return bottom, top


# ---------- carved details ----------

STEP_FRET = [  # xicalcoliuhqui, the stepped spiral, repeated along a frieze
    "XXXXXX..",
    "X....X..",
    "X.XX.X.X",
    "X..X...X",
    "XXXXXXXX",
]
GLYPHS = {
    "sun": ["X..X..X", ".XXXXX.", ".X...X.", "XX.X.XX", ".X...X.", ".XXXXX.", "X..X..X"],
    "ollin": ["XX...XX", "X.X.X.X", "..XXX..", "..X.X..", "..XXX..", "X.X.X.X", "XX...XX"],
    "rain": ["..X....", ".XXX...", ".XXX.X.", "..X.XXX", "....XXX", ".X...X.", "XXX...."],
    "spiral": ["XXXXXXX", "X.....X", "X.XXX.X", "X.X.X.X", "X.X...X", "X.XXXXX", "X......"],
}
RIM_INSET = 2             # the step-fret border runs this far in from the table's edge, all the way round
GLYPH_COUNT = 34          # carved glyphs scattered over the walls
GLYPH_SPACING = 24        # art pixels between any two details
# The slots in the side walls the jaguars hide in (Scripts/journey.gd): the dark pixels
# of the mock-up inside these boxes
JAGUAR_SLOTS = [(38, 282, 68, 314), (176, 282, 206, 314)]
SLOT_DARK = (0x1b, 0x1e, 0x29)
# The idol's lane: a glyph slot in its left wall beside each stone block (Scripts/idol_puzzle.gd)


def fits(walls, x0, y0, w, h, share=1.0):
    if x0 < 0 or y0 < 0 or x0 + w > 256 or y0 + h > 424:
        return False
    on = sum(1 for y in range(h) for x in range(w) if walls[y0 + y][x0 + x])
    return on >= share * w * h


def carve(base, rows, x0, y0, style):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != "X":
                continue
            base.putpixel((x0 + x, y0 + y), {"carve": CARVE, "jade": JADE, "gold": GOLD}[style])
            below = rows[y + 1][x] if y + 1 < len(rows) else "."
            if below != "X":
                base.putpixel((x0 + x, y0 + y + 1), CARVE_LIT if style == "carve" else CARVE)


def border(base, walls):
    """The step-fret frieze all the way round the table's rim: along the top and bottom
    edges, and up both sides (the pattern turned on its side), only where it's wall."""
    n = len(STEP_FRET)
    w = len(STEP_FRET[0])
    band = n + 2
    edges = [
        [(x, RIM_INSET + i) for x in range(256)] for i in range(band)
    ] + [
        [(x, 423 - RIM_INSET - i) for x in range(256)] for i in range(band)
    ]
    for i in range(band):
        top, bottom = edges[i], edges[band + i]
        for x, y in top:
            _rim_pixel(base, walls, x, y, i, x, n, w)
        for x, y in bottom:
            _rim_pixel(base, walls, x, y, band - 1 - i, x, n, w)
    for i in range(band):
        for y in range(RIM_INSET + band, 424 - RIM_INSET - band):
            _rim_pixel(base, walls, RIM_INSET + i, y, i, y, n, w)
            _rim_pixel(base, walls, 255 - RIM_INSET - i, y, i, y, n, w)


def _rim_pixel(base, walls, x, y, row, along, n, w):
    """One pixel of the border: its edge lines, or the pattern's row across the band."""
    if not walls[y][x]:
        return
    if row == 0 or row == n + 1:
        base.putpixel((x, y), FRIEZE_EDGE)
    else:
        ch = STEP_FRET[row - 1][along % w]
        base.putpixel((x, y), CARVE if ch == "X" else FRIEZE)


def jaguar_slots(base):
    example = Image.open(EXAMPLE).convert("RGBA")
    for x0, y0, x1, y1 in JAGUAR_SLOTS:
        for y in range(y0, y1):
            for x in range(x0, x1):
                p = example.getpixel((x, y))
                if p[:3] == SLOT_DARK:
                    base.putpixel((x, y), p)


def details(base, walls, keep_clear):
    """Glyphs on clear brick wall, spaced apart, off the border, and away from keep_clear
    (art-pixel boxes the scripts put sprites over)."""
    rng = random.Random(11)
    spots = [(x, y) for y in range(0, 424, 3) for x in range(0, 256, 3)]
    rng.shuffle(spots)
    taken = [((x0 + x1) / 2, (y0 + y1) / 2) for x0, y0, x1, y1 in keep_clear]
    clear = lambda x, y, w, h: all(not (x < bx1 and x + w > bx0 and y < by1 and y + h > by0) for bx0, by0, bx1, by1 in keep_clear)
    spaced = lambda cx, cy: all(abs(cx - tx) + abs(cy - ty) > GLYPH_SPACING for tx, ty in taken)
    names, styles = list(GLYPHS), ["carve", "carve", "jade", "carve", "gold"]
    placed = 0
    for x0, y0 in spots:
        if placed == GLYPH_COUNT:
            break
        off_border = RIM_INSET + 10 <= x0 <= 245 - RIM_INSET - 10 and RIM_INSET + 10 <= y0 <= 413 - RIM_INSET - 10
        if off_border and fits(walls, x0 - 1, y0 - 1, 9, 9) and clear(x0 - 1, y0 - 1, 9, 9) and spaced(x0 + 3, y0 + 3):
            carve(base, GLYPHS[names[placed % len(names)]], x0, y0, styles[placed % len(styles)])
            taken.append((x0 + 3, y0 + 3))
            placed += 1
    print("details: %d glyphs" % placed)


# ---------- the rails ----------

# Where the rails' ends are open (art pixels): the walls traced round the rails are left
# out inside these boxes, so the ball can run on and off
OPENINGS = {
    "left_entry": (44, 202, 68, 222),   # the very end of the bottom left, up from the floor
    "left_exit": (128, 60, 166, 98),    # the fork's lower branch, drops onto the top lanes
    "left_pipe": (155, 16, 176, 50),    # the fork's upper branch, into the temple's pipe
    "right_entry": (168, 210, 206, 252),  # bottom of the right rail, up from the left flipper
    "right_top": (224, 84, 256, 104),   # into the temple's chute
}
WALL_OUTSET = 2   # the walls stand this far outside the outer wires, so the ball fits between
MIN_WALL = 8.0    # traced bits shorter than this (art pixels) are just notches between wire ends
# The left rail ends over the top of the left inlane wall, so a short chute carries on
# from its end down to clear floor (art pixels): a one-way guide that keeps a ball coming
# back down off the wall top but lets shots coming up steeply from the flippers through
# (it stops balls on its left, going from its first point to its second), and the area
# it covers
LEFT_CHUTE_WALLS = [[(42.7, 216.0), (64.7, 228.6)]]
LEFT_CHUTE = [(42, 214), (65, 230), (82, 216), (63, 199)]


def rail_blob():
    rails = Image.open(LAYERS / "rails.png").convert("RGBA")
    wires = mask_of(rails, lambda p: p[3] > 0)
    filled = grow(grow(wires, 4), -4)  # close the gaps between the wires
    return grow(filled, WALL_OUTSET)


def trace(mask):
    """The boundary of a mask as loops of pixel-corner points, inside on the left."""
    h, w = len(mask), len(mask[0])
    inside = lambda x, y: 0 <= x < w and 0 <= y < h and mask[y][x]
    edges = {}
    for y in range(h):
        for x in range(w):
            if not mask[y][x]:
                continue
            if not inside(x, y - 1):
                edges.setdefault((x + 1, y), []).append((x, y))
            if not inside(x, y + 1):
                edges.setdefault((x, y + 1), []).append((x + 1, y + 1))
            if not inside(x - 1, y):
                edges.setdefault((x, y), []).append((x, y + 1))
            if not inside(x + 1, y):
                edges.setdefault((x + 1, y + 1), []).append((x + 1, y))
    loops = []
    while edges:
        start = next(iter(edges))
        loop = [start]
        at = start
        while True:
            nxt = edges[at].pop()
            if not edges[at]:
                del edges[at]
            if nxt == start:
                break
            loop.append(nxt)
            at = nxt
            if at not in edges:
                break
        loops.append(loop)
    return loops


def simplify(points, epsilon):
    if len(points) < 3:
        return points
    a, b = points[0], points[-1]
    best, index = -1.0, 0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = (dx * dx + dy * dy) ** 0.5 or 1.0
        d = abs(dy * px - dx * py + b[0] * a[1] - b[1] * a[0]) / length
        if d > best:
            best, index = d, i
    if best <= epsilon:
        return [a, b]
    return simplify(points[:index + 1], epsilon)[:-1] + simplify(points[index:], epsilon)


def in_opening(point):
    return any(x0 <= point[0] <= x1 and y0 <= point[1] <= y1 for x0, y0, x1, y1 in OPENINGS.values())


def rail_walls(blob):
    walls = []
    for loop in trace(blob):
        # cut each loop at the openings into open chains, then simplify each chain
        chain = []
        for p in loop + loop[:1]:
            if in_opening(p):
                if len(chain) > 1:
                    walls.append(chain)
                chain = []
            else:
                chain.append(p)
        if len(chain) > 1:
            if walls and walls[0][0] == loop[0] and not in_opening(loop[0]):
                walls[0] = chain + walls[0][1:]  # the loop's start was mid-chain; join them
            else:
                walls.append(chain)
    walls = [smooth(simplify(chain, 1.0)) for chain in walls if len(chain) > 3]
    return [w for w in walls if length(w) >= MIN_WALL]


def length(points):
    return sum(((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5 for a, b in zip(points, points[1:]))


def smooth(points, rounds=3):
    """Chaikin corner-cutting: the traced walls follow the pixels in little steps, which
    the ball would rattle over, so the corners are rounded off into curves. The ends stay
    where they are so the openings don't move."""
    for _ in range(rounds):
        out = [points[0]]
        for a, b in zip(points, points[1:]):
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        out.append(points[-1])
        points = out
    return simplify(points, 0.15)


# ---------- the line down the middle of each track ----------

# Each track's middle, from mouth to end, as the cheapest way along it when every step
# costs more the nearer it runs to the track's edge, then smoothed and set out at an
# even spacing. Scripts/rails.gd carries a riding ball along these.
PATH_SUPERSAMPLE = 4
PATH_SPACING = 6.0  # art pixels between points
PATH_SMOOTHING = 9  # art pixels either side averaged in
RAIL_PATHS = {  # name: [the mouth (art pixels, or an opening), ..., the end]
    # the left one starts from the foot of the chute under the rail's end
    "left_lanes": [(74.7, 232.5), "left_entry", "left_exit"],
    "left_temple": [(74.7, 232.5), "left_entry", "left_pipe"],
    "right": ["right_entry", "right_top"],
}
# Straight lead-ins before a path's mouth (art pixels): the right rail's mouth is barely
# wider than the ball, so a ball is taken on below it, on the line up into it
RAIL_LEADS = {"right": (174.9, 251.7)}


def rail_paths(blob):
    import numpy as np
    from scipy import ndimage
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import dijkstra

    ss = PATH_SUPERSAMPLE
    band = np.array(blob, dtype=bool)
    chute = Image.new("L", (256, 424), 0)
    ImageDraw.Draw(chute).polygon(LEFT_CHUTE, fill=255)
    band |= np.array(chute) > 0
    big = np.kron(band, np.ones((ss, ss), dtype=bool))
    clearance = ndimage.distance_transform_edt(big)
    h, w = big.shape
    ys, xs = np.nonzero(big)
    index = -np.ones(big.shape, dtype=np.int64)
    index[ys, xs] = np.arange(len(ys))
    rows, cols, costs = [], [], []
    for dy, dx in ((0, 1), (1, 0), (1, 1), (1, -1)):
        y2, x2 = ys + dy, xs + dx
        ok = (y2 < h) & (x2 >= 0) & (x2 < w)
        ok[ok] &= big[y2[ok], x2[ok]]
        a, b = index[ys[ok], xs[ok]], index[y2[ok], x2[ok]]
        room = np.minimum(clearance[ys[ok], xs[ok]], clearance[y2[ok], x2[ok]])
        cost = np.hypot(dx, dy) * (1.0 + 400.0 / (room * room))
        rows += [a, b]
        cols += [b, a]
        costs += [cost, cost]
    graph = coo_matrix((np.concatenate(costs), (np.concatenate(rows), np.concatenate(cols))),
                       shape=(len(ys), len(ys))).tocsr()

    def point(p):
        if isinstance(p, str):
            x0, y0, x1, y1 = OPENINGS[p]
            p = ((x0 + x1) / 2, (y0 + y1) / 2)
        return p

    def node(p):
        d = (xs + 0.5 - p[0] * ss) ** 2 + (ys + 0.5 - p[1] * ss) ** 2
        return int(np.argmin(d))

    def middle(a, b):
        start, end = node(a), node(b)
        _, came_from = dijkstra(graph, indices=start, return_predecessors=True)
        way = [end]
        while way[-1] != start:
            way.append(came_from[way[-1]])
        way.reverse()
        return [((xs[i] + 0.5) / ss, (ys[i] + 0.5) / ss) for i in way]

    def even(points):
        pts = np.array(points)
        k = PATH_SMOOTHING * ss
        padded = np.concatenate([np.repeat(pts[:1], k, 0), pts, np.repeat(pts[-1:], k, 0)])
        window = np.ones(2 * k + 1) / (2 * k + 1)
        smooth_pts = np.stack([np.convolve(padded[:, i], window, "valid") for i in range(2)], 1)
        smooth_pts[0], smooth_pts[-1] = pts[0], pts[-1]
        along = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(smooth_pts, axis=0).T))])
        # the same spacing from the mouth on every path, so the left rail's two share their trunk
        at = list(np.arange(0.0, along[-1] - PATH_SPACING * 0.5, PATH_SPACING)) + [along[-1]]
        return [(float(np.interp(s, along, smooth_pts[:, 0])), float(np.interp(s, along, smooth_pts[:, 1]))) for s in at]

    paths = {}
    for name, stops in RAIL_PATHS.items():
        stops = [point(p) for p in stops]
        points = []
        for a, b in zip(stops, stops[1:]):
            leg = middle(a, b)
            points += leg if not points else leg[1:]
        if name in RAIL_LEADS:
            lead, mouth = RAIL_LEADS[name], points[0]
            steps = max(2, int(((mouth[0] - lead[0]) ** 2 + (mouth[1] - lead[1]) ** 2) ** 0.5 * ss))
            points = [(lead[0] + (mouth[0] - lead[0]) * i / steps, lead[1] + (mouth[1] - lead[1]) * i / steps)
                      for i in range(steps)] + points
        paths[name] = even(points)
    return paths


def scene(p):
    return (round(p[0] * SCALE[0], 1), round(p[1] * SCALE[1], 1))


def gd_points(points):
    return "[%s]" % ", ".join("Vector2(%s, %s)" % scene(p) for p in points)


def write_geometry(walls, paths):
    lines = [
        "## The wire rails' walls, traced from Sprites/layers/rails.png by tools/make_table.py.",
        "## Generated: edit the art and re-run the tool rather than editing this.",
        "",
        "const WALLS := [",
    ]
    lines += ["\t%s," % gd_points(chain) for chain in walls]
    lines += ["]", ""]
    lines.append("## One-way guides: a ball is stopped coming from the left of the first point to the second")
    lines.append("const ONE_WAY := [")
    lines += ["\t%s," % gd_points(chain) for chain in LEFT_CHUTE_WALLS]
    lines += ["]", ""]
    lines.append("## The middle of each track, mouth to end (scene units): a riding ball follows these")
    lines.append("const PATHS := {")
    for name, points in paths.items():
        lines.append('\t"%s": %s,' % (name, gd_points(points)))
    lines += ["}", ""]
    lines.append("## The rails' open ends (scene units): [centre, size]")
    lines.append("const OPENINGS := {")
    for name, (x0, y0, x1, y1) in OPENINGS.items():
        c = scene(((x0 + x1) / 2, (y0 + y1) / 2))
        s = (round((x1 - x0) * SCALE[0], 1), round((y1 - y0) * SCALE[1], 1))
        lines.append('\t"%s": [Vector2(%s, %s), Vector2(%s, %s)],' % (name, c[0], c[1], s[0], s[1]))
    lines.append("}")
    Path("Scripts/rails_geometry.gd").write_text("\n".join(lines) + "\n", encoding="utf8")


def ramp_zone(blob):
    zone = Image.new("RGBA", (256, 424), T)
    grown = grow(blob, 1)
    for y in range(424):
        for x in range(256):
            if grown[y][x]:
                zone.putpixel((x, y), (255, 255, 255, 255))
    ImageDraw.Draw(zone).polygon(LEFT_CHUTE, fill=(255, 255, 255, 255))
    return zone


# ---------- sprites cut from the hand-drawn sheets ----------

def ball_tiers():
    """The four ball upgrades, all hand-drawn with the same 16 roll frames: iron (x1),
    silver (x2, the original pinball_sprite.png), emerald (x3) and gold (x4)."""
    rows = ["iron_ball.png", "pinball_sprite.png", "emerald_ball.png", "golden_ball.png"]
    sheets = [Image.open(SRC / name).convert("RGBA") for name in rows]
    w, h = sheets[0].size
    out = Image.new("RGBA", (w, h * len(rows)), T)
    for row, sheet in enumerate(sheets):
        out.alpha_composite(sheet, (0, row * h))
    return out


def torch_sheet():
    """The six burning frames, then six embers: the same torch with the flame burnt
    down to a few coals glowing in the bowl."""
    sheet = Image.open(SRC / "torch.png").convert("RGBA")
    out = Image.new("RGBA", (sheet.width * 2, sheet.height), T)
    out.paste(sheet, (0, 0))
    bowl_top = 12  # rows above this are flame
    rng = random.Random(5)
    for frame in range(6):
        for y in range(sheet.height):
            for x in range(16):
                p = sheet.getpixel((frame * 16 + x, y))
                if not p[3]:
                    continue
                if y < bowl_top - 2:
                    continue
                if y < bowl_top:
                    if rng.random() < 0.6:
                        p = hexc("#bd3410") if rng.random() < 0.7 else hexc("#d58144")
                    else:
                        continue
                out.putpixel((sheet.width + frame * 16 + x, y), p)
    return out


def blue_flipper():
    """The hand-drawn flipper plate (flipper.png), turned from red to blue."""
    sheet = Image.open(SRC / "flipper.png").convert("RGBA")
    out = sheet.copy()
    for y in range(sheet.height):
        for x in range(sheet.width):
            r, g, b, a = sheet.getpixel((x, y))
            if not a:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s > 0.3 and (h < 0.08 or h > 0.9):  # the reds
                r2, g2, b2 = colorsys.hsv_to_rgb(0.62, s, v)
                out.putpixel((x, y), (round(r2 * 255), round(g2 * 255), round(b2 * 255), a))
    return out


def jaguar_head():
    """The hand-drawn jaguar as drawn (facing right): watching, roaring (eye blazing)
    and blinking (eye shut), in 20x24 frames for the heads in the side walls."""
    head = Image.open(SRC / "jaguar.png").convert("RGBA")
    w, h = head.size
    red = [(x, y) for y in range(h) for x in range(w)
           if (lambda p: p[3] and p[0] > 200 and p[1] < 60 and p[2] < 60)(head.getpixel((x, y)))]
    roar, blink = head.copy(), head.copy()
    for x, y in red:
        roar.putpixel((x, y), hexc("#fff890"))
        blink.putpixel((x, y), hexc("#402000"))
    out = Image.new("RGBA", (w * 3, 24), T)
    for i, frame in enumerate((head, roar, blink)):
        out.paste(frame, (i * w, 24 - h))
    return out


# ---------- the beige apron above the flippers ----------

# Like the sand-coloured half circle of floor above Pokemon Pinball Ruby's flippers: the
# floor tiles below the jaguars, inside this arc, turn beige (shade for shade), with a
# darker rim along the arc (art pixels)
APRON_CENTRE = (121.0, 412.0)  # between the flippers, at the drain
APRON_RADIUS = 96.0
APRON_BEIGE = (172, 150, 122)  # a muted, earthy brown
APRON_RIM = (120, 96, 72)
APRON_RIM_WIDTH = 1.5
FLOOR_GREY = 152.0  # the floor tiles' brightness, which maps to APRON_BEIGE


def beige_apron(base, walls):
    for y in range(int(APRON_CENTRE[1] - APRON_RADIUS), base.height):
        for x in range(base.width):
            d = ((x + 0.5 - APRON_CENTRE[0]) ** 2 + (y + 0.5 - APRON_CENTRE[1]) ** 2) ** 0.5
            if d > APRON_RADIUS or walls[y][x]:
                continue
            p = base.getpixel((x, y))
            mean = sum(p[:3]) / 3
            if max(p[:3]) - min(p[:3]) > 14 or not 115 <= mean <= 170:
                continue  # only the grey floor and its grout, not the lanes' rims or the slingshots
            if d > APRON_RADIUS - APRON_RIM_WIDTH:
                base.putpixel((x, y), APRON_RIM + (255,))
                continue
            k = mean / FLOOR_GREY
            base.putpixel((x, y), tuple(min(255, int(c * k)) for c in APRON_BEIGE) + (255,))


# ---------- a jaguar's claw swipe ----------

CLAW = 12  # each frame's size (art pixels)


def claw_swipe():
    """Three claw marks raking down and across, for a jaguar swiping at the ball (facing
    right; flipped for the right-hand jaguar): striking, full, fading."""
    core, edge, dim = (255, 252, 230, 255), (248, 168, 40, 255), (190, 90, 30, 255)
    out = Image.new("RGBA", (CLAW * 3, CLAW), T)
    for f, reach in enumerate((5, 10, 10)):
        for k in range(3):
            for j in range(reach):
                x, y = f * CLAW + 1 + j // 2 + 3 * k, 1 + j
                if 0 <= x - f * CLAW < CLAW and y < CLAW:
                    tip = j == reach - 1
                    out.putpixel((x, y), dim if f == 2 else (edge if tip or j == 0 else core))
    return out


# ---------- the gold buttons, lit and pressed ----------

# The gold buttons painted in the basemap (art pixels, their boxes): lit and pressed
# frames to draw over them when they're hit, like the torches' stone buttons
GOLD_BUTTONS = {
    "spike_button": (110, 179, 117, 185),   # beside the idol pit's spikes
    "dart_button": (70, 266, 79, 274),      # on the left inlane wall's tip: fires the poison darts
    "skull_button": (154, 209, 160, 215),   # at the foot of the skull's lane: brings the jaguars out
}
PRESS_SHADOW = (112, 72, 8, 255)
BUTTON_GLOW = (255, 248, 168)  # lit, its gold blends halfway to this


def is_gold(p):
    return p[3] and p[0] > 180 and p[1] > 110 and p[2] < 170


def gold_button(base, box):
    """Two frames over one of the basemap's gold buttons: lit (its gold glowing pale), then
    pressed (sunk a pixel into its socket, a shadow above it)."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    out = Image.new("RGBA", (w * 2, h), T)
    gold = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if is_gold(base.getpixel((x, y)))]
    for x, y in gold:
        p = base.getpixel((x, y))
        out.putpixel((x - x0, y - y0), tuple(int(c + (g - c) * 0.55) for c, g in zip(p[:3], BUTTON_GLOW)) + (255,))
    for x, y in gold:
        out.putpixel((w + x - x0, y - y0), PRESS_SHADOW)
    for x, y in gold:
        if y + 1 < y1:
            p = base.getpixel((x, y))
            out.putpixel((w + x - x0, y + 1 - y0), (int(p[0] * 0.85), int(p[1] * 0.85), int(p[2] * 0.85), 255))
    return out


# ---------- palms, one sprite each ----------

PALM_KEEP = 10  # a patch of leaf-coloured pixels counts as a palm with this many outside the game sprites' boxes


def palm_layer(stacked):
    """The mock-up's palms, whole: every leaf-coloured pixel that differs from the layers,
    inside the game sprites' boxes too (the skull, the spikes and the tower stand in front
    of some), as long as it belongs to a palm reaching outside them. Returns the layer and
    each palm's box (art pixels), so each can be its own sprite and shake by itself."""
    import numpy as np
    from scipy import ndimage

    example = np.array(Image.open(EXAMPLE).convert("RGBA")).astype(int)
    layers = np.array(stacked).astype(int)
    palm = {p[:3] for p in Image.open(SRC / "leaves.png").convert("RGBA").get_flattened_data() if p[3]}
    h, w = example.shape[:2]
    leafy = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            if tuple(example[y, x, :3]) in palm and np.abs(example[y, x, :3] - layers[y, x, :3]).max() > 6 \
                    and not (STONE_FACE_BOX[0] <= x <= STONE_FACE_BOX[2] and STONE_FACE_BOX[1] <= y <= STONE_FACE_BOX[3]):
                leafy[y, x] = True
    boxed = np.zeros((h, w), dtype=bool)
    for x0, y0, x1, y1 in SPRITE_BOXES:
        boxed[y0:y1 + 1, x0:x1 + 1] = True
    # touching leaves are one palm; a pixel's gap between fronds doesn't split one either
    labels, count = ndimage.label(ndimage.binary_dilation(leafy, iterations=1), structure=np.ones((3, 3)))
    labels[~leafy] = 0
    out = Image.new("RGBA", (w, h), T)
    boxes = []
    for i, found in enumerate(ndimage.find_objects(labels), start=1):
        if found is None:
            continue
        mine = labels == i
        if (mine & ~boxed).sum() < PALM_KEEP:
            continue
        ys, xs = np.nonzero(mine)
        for y, x in zip(ys, xs):
            out.putpixel((int(x), int(y)), tuple(int(v) for v in example[y, x]))
        boxes.append((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    return out, boxes


def leaf_bit():
    """A scrap of palm frond, for the leaves a shaken palm drops (the palm's own colours)."""
    leaves = Image.open(SRC / "leaves.png").convert("RGBA")
    shades = sorted({p[:3] for p in leaves.get_flattened_data() if p[3]}, key=sum)
    dark, mid, light = shades[0], shades[len(shades) // 2], shades[-1]
    rows = ["LMM.", ".MDD"]
    key = {"L": light, "M": mid, "D": dark}
    img = Image.new("RGBA", (4, 2), T)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in key:
                img.putpixel((x, y), key[c] + (255,))
    return img


# ---------- the crystal skull, in two pieces ----------

def skull_pieces():
    """The skull's top (skullupper.png: jaws shut, then open) and its lower jaw
    (skulllower.png): a ball it takes goes over the jaw and under the top, into it."""
    upper = Image.open(SRC / "skullupper.png").convert("RGBA")
    w = upper.width // 2
    top = Image.new("RGBA", (w * 2, upper.height), T)
    top.alpha_composite(upper.crop((w, 0, w * 2, upper.height)), (0, 0))  # shut
    top.alpha_composite(upper.crop((0, 0, w, upper.height)), (w, 0))      # open
    return top, Image.open(SRC / "skulllower.png").convert("RGBA")


def skull_shine(top):
    """Where the crystal skull catches the light: its brightest facets, as white and
    pale-blue glints (one frame for each of the top's two), for the game to brighten as a
    light passes over it."""
    lums = sorted({sum(p[:3]) for p in top.get_flattened_data() if p[3]})
    hot, warm = lums[int(len(lums) * 0.85)], lums[int(len(lums) * 0.65)]
    out = Image.new("RGBA", top.size, T)
    for y in range(top.height):
        for x in range(top.width):
            p = top.getpixel((x, y))
            if not p[3] or y > top.height * 0.5:
                continue  # only the crystal dome, not its teeth
            if sum(p[:3]) >= hot:
                out.putpixel((x, y), (255, 255, 255, 255))
            elif sum(p[:3]) >= warm:
                out.putpixel((x, y), (170, 230, 255, 150))
    return out


SHIMMER_FRAMES = 6


def skull_shimmer(top):
    """A glint running diagonally across the crystal dome, the way light sweeps over the
    rail emerald's facets: SHIMMER_FRAMES frames across, one row for each of the top's two
    frames (jaws shut, open). The game plays it once as the spotlight comes onto the skull
    or leaves it."""
    fw, h = top.width // 2, top.height
    out = Image.new("RGBA", (fw * SHIMMER_FRAMES, h * 2), T)
    for row in range(2):
        frame = top.crop((row * fw, 0, row * fw + fw, h))
        box = frame.getbbox()
        span = (box[2] - box[0]) + (h * 0.5 - box[1]) * 0.6  # across the dome, corner to corner
        for f in range(SHIMMER_FRAMES):
            band = box[0] + 1 + (span - 2) * f / (SHIMMER_FRAMES - 1)
            for y in range(h):
                if y > h * 0.5:
                    break  # only the crystal dome, not its teeth
                for x in range(fw):
                    if not frame.getpixel((x, y))[3]:
                        continue
                    d = abs(x + (y - box[1]) * 0.6 - band)
                    if d < 1.0:
                        out.putpixel((f * fw + x, row * h + y), (255, 255, 255, 235))
                    elif d < 2.2:
                        out.putpixel((f * fw + x, row * h + y), (170, 230, 255, 140))
    return out


# ---------- the temple's gems, lit ----------

GEM_BLUE = (20, 124, 199)
GEM_LIT = (190, 250, 255)
TEMPLE_RING = ((208.0, 50.0), 26.0, 34.0)  # the ring's centre (art pixels), and the band its gems lie in


def temple_gems():
    """The blue gems round the temple's ring, lit: a strip of each one recoloured bright,
    and where each one sits, in order round the ring."""
    import math
    import numpy as np
    from scipy import ndimage

    temple = np.array(Image.open(LAYERS / "temple.png").convert("RGBA"))
    blue = (temple[:, :, 0] == GEM_BLUE[0]) & (temple[:, :, 1] == GEM_BLUE[1]) & (temple[:, :, 2] == GEM_BLUE[2])
    # a gem's white glint can split its blue in two, so neighbours a pixel apart are one gem
    labels, _ = ndimage.label(ndimage.binary_dilation(blue, iterations=1), structure=np.ones((3, 3)))
    labels[~blue] = 0
    (cx, cy), near, far = TEMPLE_RING
    gems = []
    for found in ndimage.find_objects(labels):
        ys, xs = found
        mx, my = (xs.start + xs.stop) / 2, (ys.start + ys.stop) / 2
        if near <= math.hypot(mx - cx, my - cy) <= far:
            gems.append((math.atan2(my - cy, mx - cx), xs.start, ys.start, xs.stop, ys.stop))
    gems.sort()
    sheet_w = sum(g[3] - g[1] for g in gems)
    height = max(g[4] - g[2] for g in gems)
    sheet = Image.new("RGBA", (sheet_w, height), T)
    placed = []
    at = 0
    for angle, x0, y0, x1, y1 in gems:
        for y in range(y0, y1):
            for x in range(x0, x1):
                if blue[y, x]:
                    sheet.putpixel((at + x - x0, y - y0), GEM_LIT + (255,))
        placed.append(((x0 + x1) / 2, (y0 + y1) / 2, at, x1 - x0, y1 - y0))
        at += x1 - x0
    return sheet, placed


# ---------- the plunger's spring ----------

SPRING_W = 12
SPRING_TALL = 12  # at rest (art pixels)
SPRING_SHORT = 4  # pulled all the way down


def spring_sheet():
    """The plunger: a gold cap on a steel coil, one frame for each pixel it's pulled down,
    from at rest to fully pulled, each standing on the frame's bottom edge."""
    ink, gold, gold_d = (20, 24, 36, 255), (248, 208, 0, 255), (200, 138, 16, 255)
    light, mid, dark = (214, 224, 232, 255), (142, 158, 172, 255), (74, 86, 102, 255)
    frames = []
    for tall in range(SPRING_TALL, SPRING_SHORT - 1, -1):
        img = Image.new("RGBA", (SPRING_W, SPRING_TALL), T)
        top = SPRING_TALL - tall
        for x in range(1, SPRING_W - 1):  # the cap
            img.putpixel((x, top), ink)
            img.putpixel((x, top + 1), gold if x < SPRING_W - 3 else gold_d)
            img.putpixel((x, top + 2), ink)
        img.putpixel((0, top + 1), ink)
        img.putpixel((SPRING_W - 1, top + 1), ink)
        coil = tall - 3
        loops = 4
        for r in range(coil):
            y = top + 3 + r
            front = (r * loops / max(coil, 1)) % 1.0 < 0.5
            if front:
                img.putpixel((2, y), ink)
                img.putpixel((SPRING_W - 3, y), ink)
                for x in range(3, SPRING_W - 3):
                    img.putpixel((x, y), light if x < 6 else mid)
            else:
                for x in range(3, SPRING_W - 3):
                    img.putpixel((x, y), dark)
        frames.append(img)
    sheet = Image.new("RGBA", (SPRING_W * len(frames), SPRING_TALL), T)
    for i, f in enumerate(frames):
        sheet.paste(f, (i * SPRING_W, 0))
    return sheet


# ---------- the poison dart trap ----------

# A poison dart seen from the table's view, point down: red feather flights, a cane shaft,
# a point wet with green poison. Falling, all of it; stuck in the floor, the point's buried
# and there's a little dark hole round the shaft.
DART_FALLING = [
    ".R.R.",
    "RRrRR",
    "RRrRR",
    ".RrR.",
    "..r..",
    "..W..",
    "..W..",
    "..W..",
    "..B..",
    "..W..",
    "..W..",
    "..W..",
    "..g..",
    "..G..",
    "..P..",
]
DART_STUCK = DART_FALLING[:10] + [".kok."]
DART_SHADOW = [".kkk.", "kkkkk", ".kkk."]


def dart_trap():
    """The poison dart trap's darts: one falling (point down), one stuck upright in the
    floor (two frames: still, and quivering a pixel when the ball knocks it), and the
    shadow a falling one throws on the floor."""
    key = {"R": (210, 50, 40, 255), "r": (140, 30, 30, 255), "W": (204, 168, 96, 255),
           "B": (120, 80, 40, 255), "g": (40, 140, 50, 255), "G": (90, 230, 90, 255),
           "P": (200, 255, 170, 255), "o": (16, 12, 18, 255), "k": (10, 8, 20, 120)}

    def draw(rows, img=None, dx=0, x0=0):
        if img is None:
            img = Image.new("RGBA", (len(rows[0]), len(rows)), T)
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                if c in key and 0 <= x + dx < len(row):
                    img.putpixel((x0 + x + dx * (y < len(rows) - 3), y), key[c])
        return img

    falling = draw(DART_FALLING)
    w, h = len(DART_STUCK[0]), len(DART_STUCK)
    stuck = Image.new("RGBA", (w * 2, h), T)
    draw(DART_STUCK, stuck)
    draw(DART_STUCK, stuck, dx=1, x0=w)  # quivering: its top leans a pixel over
    shadow = draw(DART_SHADOW)
    return falling, stuck, shadow


# ---------- the lava pit ----------

LAVA_FRAMES = 4
LAVA_TOP = 404  # art pixels: the lava's own glow starts here

def lava_layers():
    """The lava in the drain, from the hand-drawn lava.png (the lava reference layer, at
    the table's size): its translucent glow over the drain and its edges on its own (the
    game breathes it), and its solid pixels, the embers and the lava's edge along the
    bottom, in frames: embers flicker and drift up a pixel, the edge shimmers."""
    import random

    lava = Image.open(SRC / "lava.png").convert("RGBA")
    w, h = lava.size
    glow = Image.new("RGBA", (w, h), T)
    solid = []
    for y in range(h):
        for x in range(w):
            p = lava.getpixel((x, y))
            if not p[3] or y < LAVA_TOP:
                continue  # (above it, the glow it threw on the flippers, which showed through them)
            if p[3] < 255:
                glow.putpixel((x, y), p)
            else:
                solid.append((x, y, p))
    rng = random.Random(7)
    bright = (255, 150, 60, 255)
    box = lava.getbbox()
    frames = Image.new("RGBA", ((box[2] - box[0]) * LAVA_FRAMES, box[3] - box[1]), T)
    fw = box[2] - box[0]
    for f in range(LAVA_FRAMES):
        for x, y, p in solid:
            edge = y >= h - 3  # the lava's edge along the bottom
            if edge:
                col = bright if (x + f) % 4 == 0 else p
                frames.putpixel((f * fw + x - box[0], y - box[1]), col)
                continue
            phase = (rng.random() + f / LAVA_FRAMES) % 1.0  # each ember on its own beat
            if phase < 0.2:
                continue  # flickered out
            ny = y - (1 if phase > 0.6 else 0)
            frames.putpixel((f * fw + x - box[0], ny - box[1]), bright if phase > 0.85 else p)
        rng = random.Random(7)  # the same embers, frame to frame
    return glow, frames, box


# ---------- the warriors' hole in the arena ----------

HOLE_SIZE = (24, 16)


def arena_hole():
    """A round stone tablet set in the middle of the warriors' arena: shut, with a carved
    step-fret on it, then slid aside, a dark hole the warriors jump down into."""
    w, h = HOLE_SIZE
    ink, rim, stone, stone_l, carve = (20, 24, 36, 255), (84, 90, 100, 255), (112, 118, 128, 255), (148, 154, 160, 255), (70, 74, 84, 255)
    pit, pit_d = (34, 26, 30, 255), (16, 12, 18, 255)
    out = Image.new("RGBA", (w * 2, h), T)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for f in range(2):
        for y in range(h):
            for x in range(w):
                r = ((x - cx) / (w / 2)) ** 2 + ((y - cy) / (h / 2)) ** 2
                if r > 1.0:
                    continue
                if r > 0.78:
                    c = ink
                elif r > 0.55:
                    c = rim if f == 0 or y > cy else (60, 64, 74, 255)
                elif f == 0:
                    c = stone_l if y < cy - 2 else stone
                else:
                    c = pit if y < cy else pit_d
                out.putpixel((f * w + x, y), c)
        if f == 0:  # a step-fret carved across the shut tablet
            for dx, dy in ((-4, 0), (-3, 0), (-2, 0), (-2, -1), (-1, -1), (0, -1), (0, 0), (0, 1), (1, 1), (2, 1), (2, 0), (3, 0), (4, 0)):
                out.putpixel((int(cx + dx + 0.5), int(cy + dy + 0.5)), carve)
    return out


# ---------- inside the temple ----------

def temple_interior():
    """What shows through the golden temple's windows: the dark of its inside, lit warm
    from above (only inside the windows, the holes the temple art encloses; the rest is
    left clear so the temple, and the ball racing round under it, show as they are)."""
    import numpy as np
    from scipy import ndimage

    temple = np.array(Image.open(LAYERS / "temple.png").convert("RGBA"))
    solid = temple[:, :, 3] > 0
    holes = ndimage.binary_fill_holes(solid) & ~solid
    out = Image.new("RGBA", (temple.shape[1], temple.shape[0]), T)
    glow, dusk, dark = (126, 78, 34, 255), (70, 40, 30, 255), (40, 22, 26, 255)
    for y, x in zip(*np.nonzero(holes)):
        above = 0  # how far down from the window's top edge
        while y - above - 1 >= 0 and holes[y - above - 1, x]:
            above += 1
        out.putpixel((int(x), int(y)), glow if above == 0 else (dusk if above < 3 else dark))
    return out


# ---------- the floor roulette ----------

ROULETTE_PICTURE = (48, 30)    # each picture, redrawn smaller from Sprites/billboard.png's 64x40
ROULETTE_FRAMES = list(range(0, 4)) + list(range(5, 10))  # the four cities, then the five prizes
ROULETTE_BORDER = 3


def roulette_art():
    """The roulette set in the floor under Tlaloc: its pictures (the billboard's cities and
    prizes, redrawn at 48x30 in each picture's own colours), a stone border trimmed in gold,
    and the two carved stone doors that slide apart to show it."""
    sheet = Image.open("Sprites/billboard.png").convert("RGBA")
    pw, ph = ROULETTE_PICTURE
    pictures = Image.new("RGBA", (pw * len(ROULETTE_FRAMES), ph), T)
    for i, frame in enumerate(ROULETTE_FRAMES):
        src = sheet.crop((frame * 64, 0, frame * 64 + 64, 40))
        palette = list({p for p in src.get_flattened_data() if p[3]})
        small = src.resize((pw, ph), Image.LANCZOS)
        for y in range(ph):
            for x in range(pw):
                c = small.getpixel((x, y))
                near = min(palette, key=lambda p: sum((p[k] - c[k]) ** 2 for k in range(3)))
                pictures.putpixel((i * pw + x, y), near[:3] + (255,))
    b = ROULETTE_BORDER
    ink, stone_d, stone, stone_l = (20, 24, 36, 255), (70, 80, 96, 255), (104, 116, 130, 255), (150, 162, 172, 255)
    gold, gold_d = (248, 208, 0, 255), (200, 138, 16, 255)
    fw, fh = pw + b * 2, ph + b * 2
    frame = Image.new("RGBA", (fw, fh), T)
    for y in range(fh):
        for x in range(fw):
            edge = min(x, y, fw - 1 - x, fh - 1 - y)
            if edge >= b:
                continue
            col = ink if edge == 0 else (gold if edge == b - 1 else (stone_l if y < fh // 2 else stone_d))
            if edge == b - 1 and (x + y) % 6 == 0:
                col = gold_d
            frame.putpixel((x, y), col)
    doors = Image.new("RGBA", (pw, ph), T)
    half = pw // 2
    for y in range(ph):
        for x in range(pw):
            col = stone if (x // 4 + y // 3) % 2 else (96, 108, 122, 255)
            if x in (half - 1, half):
                col = gold_d if x == half - 1 else ink  # the seam where they meet
            if y in (0, ph - 1):
                col = stone_d
            doors.putpixel((x, y), col)
    # a carved step-fret glyph on each door
    for cx in (half // 2, half + half // 2):
        for dx, dy in ((-3, -3), (-2, -3), (-1, -3), (0, -3), (1, -3), (1, -2), (1, -1), (-1, -1), (-1, 0), (-1, 1), (0, 1), (1, 1), (2, 1), (3, 1), (3, 2), (3, 3), (-3, -2), (-3, -1), (-3, 0), (-3, 1), (-3, 2), (-3, 3), (-2, 3), (-1, 3), (0, 3), (1, 3)):
            doors.putpixel((cx + dx, ph // 2 + dy), stone_d)
    return pictures, frame, doors


# ---------- more table pieces ----------

IDOL_TURN_FRAMES = 8
IDOL_DEPTH = 0.6  # how deep the idol is, front to back, as a share of its width


def idol_spin():
    """The golden idol turning round on its tower, in depth: each row of it is a slice
    whose front shrinks as its side swings into view (shaded, as it turns from the light)
    and then the back comes round, plain where the face was. Eight frames, a full turn,
    on the table's pixel grid (built from idol.png's first frame)."""
    import math

    idol = Image.open("Sprites/table/idol.png").convert("RGBA")
    size = idol.height
    front = idol.crop((0, 0, size, size))
    gold, dark = (248, 192, 0, 255), (176, 112, 0, 255)
    face_rows = range(3, 18)  # the jewel, the face and the pectoral (tools/make_tiki_idol.py)
    rows = []
    for y in range(size):
        xs = [x for x in range(size) if front.getpixel((x, y))[3]]
        if not xs:
            continue
        l, r = min(xs), max(xs)
        inner = [front.getpixel((x, y)) for x in range(l + 1, r)]
        ink = front.getpixel((l, y))
        # the back: the face's eyes, jewel and brow smoothed into plain gold, a seam down the middle
        # the back of his head and body: plain gold, shaded at the sides
        back = list(inner)
        if y in face_rows:
            back = [dark if i in (0, len(inner) - 1) else gold for i in range(len(inner))]
        if back and y < 18:
            back[len(back) // 2] = dark
        rows.append((y, inner, back, ink))

    def shade(p, k):
        return (int(p[0] * k), int(p[1] * k), int(p[2] * k), 255)

    out = Image.new("RGBA", (size * IDOL_TURN_FRAMES, size), T)
    centre = size / 2
    for f in range(IDOL_TURN_FRAMES):
        angle = 2 * math.pi * f / IDOL_TURN_FRAMES
        c, s_ = math.cos(angle), math.sin(angle)
        for y, inner, back, ink in rows:
            w = len(inner)
            if w == 0:
                continue
            depth = max(1, round(w * IDOL_DEPTH))
            fw = round(w * abs(c))
            sw = round(depth * abs(s_))
            tex = inner if c >= 0 else back[::-1]
            face = [shade(tex[min(w - 1, int((i + 0.5) * w / fw))], 0.75 + 0.25 * abs(c)) for i in range(fw)] if fw else []
            edge = inner[0] if s_ > 0 else inner[-1]  # his sides (jade ear-spools and all), whichever way he faces
            side = [shade(edge, 0.62)] * sw
            body = side + face if s_ > 0 else face + side
            total = len(body) + 2
            x0 = int(round(centre - total / 2))
            for i, p in enumerate([ink] + body + [ink]):
                x = x0 + i
                if 0 <= x < size:
                    out.putpixel((f * size + x, y), p)
    return out


def blood_heart():
    """The beating heart from 8 Bit Evil Returns (heartbeat.png, 8 frames of 64x64), redrawn
    at half size so it sits in Tlaloc's mouth on the table's pixel grid: each 2x2 block
    becomes its most common colour, if most of it is heart."""
    sheet = Image.open(SRC / "heartbeat.png").convert("RGBA")
    n = sheet.width // sheet.height
    fs = sheet.height
    box = None
    for i in range(n):
        b = sheet.crop((i * fs, 0, (i + 1) * fs, fs)).getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    x0, y0, x1, y1 = box
    w, h = (x1 - x0 + 1) // 2, (y1 - y0 + 1) // 2
    out = Image.new("RGBA", (w * n, h), T)
    for i in range(n):
        frame = sheet.crop((i * fs + x0, y0, i * fs + x0 + w * 2, y0 + h * 2))
        for y in range(h):
            for x in range(w):
                block = [frame.getpixel((x * 2 + dx, y * 2 + dy)) for dx in (0, 1) for dy in (0, 1)]
                solid = [p for p in block if p[3] > 128]
                if len(solid) >= 2:
                    out.putpixel((i * w + x, y), max(set(solid), key=solid.count))
    return out


EMERALD_SIZE = 15
EMERALD_FRAMES = 4


def rail_gem():
    """A cut emerald hovering up the left rail, juicy: a flat table, a ring of crown facets
    and a deep pavilion of facets narrowing to a point, light sweeping across them over
    four frames (with a twinkle on the bright one); and its shadow."""
    import math

    n = EMERALD_SIZE
    cx = (n - 1) / 2
    girdle = 5
    ink = (8, 40, 26, 255)
    shades = [(10, 80, 50), (20, 125, 78), (36, 178, 104), (96, 230, 150), (190, 255, 214)]
    out = Image.new("RGBA", (n * EMERALD_FRAMES, n), T)

    def half_width(y):
        if y < 1:
            return -1
        if y <= girdle:  # the crown flares out from the table to the girdle
            return 3 + (y - 1) * 4 / (girdle - 1)
        return (n - 1 - y) * 7 / (n - 1 - girdle)  # the pavilion narrows to its point

    for f in range(EMERALD_FRAMES):
        sweep = -cx + f * (n + 4) / EMERALD_FRAMES  # where the light is, across the gem
        for y in range(n):
            hw = half_width(y)
            for x in range(n):
                dx = x - cx
                if hw < 0 or abs(dx) > hw + 0.4:
                    continue
                if abs(abs(dx) - hw) < 0.9 or y == 1:
                    out.putpixel((f * n + x, y), ink)
                    continue
                if y <= girdle:
                    facet = 2 if abs(dx) < 2.5 and y <= 2 else (3 if (int(dx + cx) // 3) % 2 else 2)
                    if y == girdle:
                        facet = 1
                else:
                    t = dx / max(hw, 1)
                    facet = 1 + (int((t + 1) * 2.5) % 2)
                    if abs(t) < 0.25:
                        facet = 0
                lit = math.exp(-((dx - sweep) ** 2) / 6.0)  # the sweep brightens what it crosses
                k = min(4, facet + round(lit * 2))
                out.putpixel((f * n + x, y), shades[k] + (255,))
        # a twinkle where the light catches
        tx = int(round(cx + sweep * 0.6))
        if 2 <= tx <= n - 3:
            for ddx, ddy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                px, py = tx + ddx, 3 + ddy
                if out.getpixel((f * n + px, py))[3]:
                    out.putpixel((f * n + px, py), (255, 255, 255, 255))
    shadow = Image.new("RGBA", (11, 3), T)
    for x, y in [(x, 1) for x in range(11)] + [(x, 0) for x in range(2, 9)] + [(x, 2) for x in range(2, 9)]:
        shadow.putpixel((x, y), (10, 12, 20, 110))
    return out, shadow


SPIRIT_LAMP = [
    "..ooooo..",
    ".oSSSSSo.",
    "oSKKKKKSo",
    "oSKKKKKSo",
    "oSKKKKKSo",
    ".oSSSSSo.",
    "..ooooo..",
]


def spirit_lamp():
    """A stone lamp set in the floor of the right lane: dark, then a spirit flame in it."""
    ink, stone, dark = (20, 24, 36, 255), (112, 124, 136, 255), (40, 44, 56, 255)
    blue, cyan, white = (30, 120, 170, 255), (90, 220, 255, 255), (230, 255, 255, 255)
    w, h = len(SPIRIT_LAMP[0]), len(SPIRIT_LAMP)
    out = Image.new("RGBA", (w * 2, h), T)
    for f in range(2):
        for y, row in enumerate(SPIRIT_LAMP):
            for x, c in enumerate(row):
                col = {"o": ink, "S": stone, "K": dark}.get(c)
                if f == 1 and c == "K":
                    col = white if (y == 3 and 3 <= x <= 5) else (cyan if 3 <= x <= 5 or y == 3 else blue)
                if col:
                    out.putpixel((f * w + x, y), col)
    return out


def shard():
    """A sliver of crystal, for the tower breaking up."""
    img = Image.new("RGBA", (2, 3), T)
    for (x, y), c in {(1, 0): (230, 252, 255), (0, 1): (130, 210, 245), (1, 1): (130, 210, 245), (0, 2): (60, 120, 180)}.items():
        img.putpixel((x, y), c + (255,))
    return img


# ---------- the gem up the left rail ----------

def write_table_geometry(palms, gems):
    def r(v):
        return round(v, 2)
    lines = [
        "## Where the table's separate sprites sit, from tools/make_table.py.",
        "## Generated: edit the art and re-run the tool rather than editing this.",
        "",
        "## Each palm's box in Sprites/map_palms.png (art pixels)",
        "const PALMS := [",
    ]
    lines += ["\tRect2(%d, %d, %d, %d)," % (x0, y0, x1 - x0, y1 - y0) for x0, y0, x1, y1 in palms]
    lines += ["]", "",
              "## The gold buttons painted in the basemap: their centres (art pixels)",
              "const GOLD_BUTTONS := {"]
    lines += ['	"%s": Vector2(%s, %s),' % (n, (b[0] + b[2]) / 2, (b[1] + b[3]) / 2) for n, b in GOLD_BUTTONS.items()]
    lines += ["}", "",
              "## The centre of the temple's ring of gems (art pixels)",
              "const TEMPLE_RING_CENTRE := Vector2(%s, %s)" % TEMPLE_RING[0], "",
              "## The temple's ring gems in order round the ring: [centre (art pixels), its strip in",
              "## Sprites/table/temple_gems_lit.png]",
              "const TEMPLE_GEMS := ["]
    lines += ["\t[Vector2(%s, %s), Rect2(%d, 0, %d, %d)]," % (r(x), r(y), at, w, h) for x, y, at, w, h in gems]
    lines += ["]"]
    Path("Scripts/table_geometry.gd").write_text("\n".join(lines) + "\n", encoding="utf8")


def main():
    base = Image.open(LAYERS / "basemap.png").convert("RGBA")
    temple = Image.open(LAYERS / "temple.png").convert("RGBA")
    rails = Image.open(LAYERS / "rails.png").convert("RGBA")
    stacked = base.copy()
    stacked.alpha_composite(temple)
    stacked.alpha_composite(rails)
    bottom_decor, top_decor = decor(stacked)

    walls = wall_mask(base)
    keep_clear = SPRITE_BOXES + [(17, 15, 52, 50), (156, 14, 256, 110), (0, 0, 256, 1)]  # sprites, the stone face, the temple
    border(base, walls)
    details(base, walls, keep_clear)
    jaguar_slots(base)
    beige_apron(base, walls)
    palm = {p[:3] for p in Image.open(SRC / "leaves.png").convert("RGBA").get_flattened_data() if p[3]}
    for y in range(base.height):
        for x in range(base.width):
            p = bottom_decor.getpixel((x, y))
            if p[3] and p[:3] in palm:
                bottom_decor.putpixel((x, y), T)  # the palms are sprites of their own
    for name, box in GOLD_BUTTONS.items():
        gold_button(base, box).save("Sprites/table/%s.png" % name)
    palms, palm_boxes = palm_layer(stacked)
    palms.save("Sprites/map_palms.png")
    gems_lit, gems = temple_gems()
    gems_lit.save("Sprites/table/temple_gems_lit.png")
    write_table_geometry(palm_boxes, gems)
    print("palms: %d, temple gems: %d" % (len(palm_boxes), len(gems)))
    base.alpha_composite(bottom_decor)
    base.save("Sprites/map_f1.png")
    top = temple.copy()
    top.alpha_composite(rails)
    top.alpha_composite(top_decor)
    top.save("Sprites/map_f2.png")

    blob = rail_blob()
    rails_walls = rail_walls(blob)
    paths = rail_paths(blob)
    write_geometry(rails_walls, paths)
    ramp_zone(blob).save("Sprites/ramp_zone.png")
    print("rails: %d walls, %d points; paths %s" % (len(rails_walls), sum(len(w) for w in rails_walls),
                                                      {name: len(p) for name, p in paths.items()}))

    ball_tiers().save("Sprites/ball_spin.png")
    for name in ("paddle_left.png", "paddle_right.png"):
        Image.open(SRC / name).convert("RGBA").save(name)
    torch_sheet().save("Sprites/table/torch.png")
    blue_flipper().save("Sprites/table/blue_flipper.png")
    jaguar_head().save("Sprites/table/wall_jaguar.png")
    Image.open(SRC / "magicWhirl.png").convert("RGBA").save("Sprites/table/whirl.png")
    Image.open(SRC / "warrior.png").convert("RGBA").save("Sprites/table/warrior.png")
    skull_top, skull_jaw = skull_pieces()
    skull_top.save("Sprites/table/skull_top.png")
    skull_shine(skull_top).save("Sprites/table/skull_shine.png")
    skull_shimmer(skull_top).save("Sprites/table/skull_shimmer.png")
    skull_jaw.save("Sprites/table/skull_jaw.png")
    spring_sheet().save("Sprites/table/spring.png")
    gem, gem_shadow = rail_gem()
    gem.save("Sprites/table/rail_gem.png")
    gem_shadow.save("Sprites/table/rail_gem_shadow.png")
    idol_spin().save("Sprites/table/idol_spin.png")
    blood_heart().save("Sprites/table/blood_heart.png")
    spirit_lamp().save("Sprites/table/spirit_lamp.png")
    shard().save("Sprites/table/shard.png")
    temple_interior().save("Sprites/table/temple_interior.png")
    arena_hole().save("Sprites/table/arena_hole.png")
    dart_falling, dart_stuck, dart_shadow = dart_trap()
    dart_falling.save("Sprites/table/dart_falling.png")
    dart_stuck.save("Sprites/table/dart_stuck.png")
    dart_shadow.save("Sprites/table/dart_shadow.png")
    lava_glow, lava_frames, lava_box = lava_layers()
    lava_glow.save("Sprites/table/lava_glow.png")
    lava_frames.save("Sprites/table/lava_embers.png")
    print("lava embers box", lava_box)
    reel, reel_border, reel_doors = roulette_art()
    reel.save("Sprites/table/roulette_pictures.png")
    reel_border.save("Sprites/table/roulette_border.png")
    reel_doors.save("Sprites/table/roulette_doors.png")
    claw_swipe().save("Sprites/table/claw_swipe.png")
    leaf_bit().save("Sprites/table/leaf_bit.png")
    for name, out in (("spinningtower", "tower_drum"), ("spikes", "spikes"), ("torchbutton", "torch_button")):
        Image.open(SRC / ("%s.png" % name)).convert("RGBA").save("Sprites/table/%s.png" % out)
    Image.open(SRC / "eyeless.png").convert("RGBA").save("Sprites/face_sockets.png")
    eyes = Image.new("RGBA", (12, 6), T)
    eyes.paste(Image.open(SRC / "yelloweye.png").convert("RGBA"), (0, 0))
    eyes.paste(Image.open(SRC / "redeye.png").convert("RGBA"), (6, 0))
    eyes.save("Sprites/table/face_eye.png")
    for side, name in (("left", "bumperleftlightup"), ("right", "bumperrightlightup")):
        Image.open(SRC / ("%s.png" % name)).convert("RGBA").save("Sprites/table/sling_%s_lit.png" % side)
    print("wrote the table and its sprites")


if __name__ == "__main__":
    main()
