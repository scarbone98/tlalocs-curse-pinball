"""The left orbit's guide line (Scripts/orbit_geometry.gd), for Scripts/orbit_guide.gd.

A fast ball running along the left orbit's outer wall - round over the top from the
launch side and down the left lane, or up the lane (the torch lane) and round the other
way - is carried along this line, a ball's radius in from the wall, rather than left to
the physics: a ball skidding round a tight curve of straight wall pieces hitches as it
taps from one to the next. Read from the wall colliders in node_2d.tscn, so re-run this
after editing them. Run from the repo root:  python3 tools/make_orbit_path.py
"""
import math
import re

BALL = 19.5      # the ball's radius, and a hair: the line keeps it just off the wall
OUT = "Scripts/orbit_geometry.gd"
SCENE = "node_2d.tscn"
TOP_FROM = (336.0, 410.0)  # how far along the top run (scene x) the line starts
LAUNCH_TO = 395.0          # the launch orbit's line ends here on the top run (scene x), where the left's begins


def polygon(scene, name):
    """A layer_1_colliders polygon from the scene, in scene units."""
    m = re.search(r'\[node name="%s" type="CollisionPolygon2D" parent="layer_1_colliders"[^\]]*\]\n((?:[^\[]*?))'
                  r'polygon = PackedVector2Array\(([^)]*)\)' % name, scene)
    pos = re.search(r'position = Vector2\(([-\d.]+), ([-\d.]+)\)', m.group(1))
    ox, oy = (float(pos.group(1)), float(pos.group(2))) if pos else (0.0, 0.0)
    v = [float(x) for x in m.group(2).split(',')]
    return [(v[i] + ox, v[i + 1] + oy) for i in range(0, len(v), 2)]


def wall():
    """The orbit's outer wall as the colliders in node_2d.tscn have it (scene units): the
    launch orbit's wall coming across the top, the left wall round and down the left lane,
    and on along the wall below it past the lane's foot. Read from the scene, so it follows
    any edit made to the colliders: re-run this after changing them."""
    scene = open(SCENE, encoding="utf8").read()
    right = polygon(scene, "CollisionPolygon2D2")
    left = polygon(scene, "CollisionPolygon2D")
    below = polygon(scene, "CollisionPolygon2D7")
    # the launch wall's top run, from where it meets the left wall rightward (taken right to left)
    top = [q for q in right if 180 < q[1] < 215 and TOP_FROM[0] < q[0] <= TOP_FROM[1]]
    top.sort(key=lambda q: -q[0])
    # the left wall, from the junction at the top round and down to the lane's foot
    start = min((q for q in left if 185 < q[1] < 200), key=lambda q: q[0] if q[0] > 300 else 1e9)
    i0 = left.index(start)
    # down the lane to where the wall below takes over (its top corner), then on along that
    # wall's edge toward the inlane, rather than turning the left wall's own sharp foot
    corner = min(below, key=lambda q: q[1] if q[0] > 30 else 1e9)
    nxt = below[(below.index(corner) - 1) % len(below)]
    i1 = max(i for i, q in enumerate(left) if q[1] < corner[1] - 4 and q[0] > 30 and i > i0)
    chain = top + left[i0:i1 + 1] + [corner]
    for t in (0.35, 0.7, 1.0):
        chain.append((corner[0] + (nxt[0] - corner[0]) * t, corner[1] + (nxt[1] - corner[1]) * t))
    dedup = [chain[0]]
    for q in chain[1:]:
        if math.dist(q, dedup[-1]) > 0.5:
            dedup.append(q)
    return dedup


def chaikin(chain, rounds):
    for _ in range(rounds):
        out = [chain[0]]
        for a, b in zip(chain, chain[1:]):
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        out.append(chain[-1])
        chain = out
    return chain


def launch_wall():
    """The launch orbit's outer wall (scene units): up the launch tube's straight wall, round the
    top-right and along the top run to where the left orbit's line takes over."""
    scene = open(SCENE, encoding="utf8").read()
    right = polygon(scene, "CollisionPolygon2D2")
    # the orbit's wall runs from the top run's left end (its point after the corner at the top
    # of the frame) round to the top of the tube's straight outer wall
    top_left = min((q for q in right if 185 < q[1] < 200 and q[0] < 360), key=lambda q: q[0])
    a = right.index(top_left)
    b = max(i for i, q in enumerate(right) if i > a and q[0] > 700 and 650 < q[1] < 700)
    wall = list(reversed(right[a:b + 1]))
    wall = [(wall[0][0], 960.0), (wall[0][0], 820.0)] + wall
    return [q for q in wall if q[0] > LAUNCH_TO or q[1] > 300.0]


def guide_line(wall, spacing):
    w = chaikin(wall, 2)
    line = []
    for k, q in enumerate(w):
        a, b = w[max(k - 1, 0)], w[min(k + 1, len(w) - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(tx, ty) or 1.0
        line.append((q[0] + ty / ln * BALL, q[1] - tx / ln * BALL))  # in from the wall, toward the playfield
    line = chaikin(line, 1)
    kept = [line[0]]
    for q in line[1:]:
        if math.dist(q, kept[-1]) >= spacing:
            kept.append(q)
    return kept


def main():
    kept = guide_line(wall(), 4.0)
    launch = guide_line(launch_wall(), 4.0)
    lines = ["## The orbits' guide lines, a ball's radius in from their outer walls (scene units), used",
             "## when node_2d.tscn's RailEdits has no orbit_guide / launch_guide placed by hand.",
             "## Generated by tools/make_orbit_path.py from the wall colliders: re-run it rather than",
             "## editing this.",
             "",
             "## The left orbit: from the top run across from the launch side, round, and down the left",
             "## lane to its foot",
             "const PATH := ["]
    lines += ["\tVector2(%.1f, %.1f)," % q for q in kept]
    lines += ["]", "",
              "## The launch orbit: up out of the launch tube, round the top-right and along the top run",
              "const LAUNCH_PATH := ["]
    lines += ["\tVector2(%.1f, %.1f)," % q for q in launch]
    lines += ["]", ""]
    open(OUT, "w", newline="\n").write("\n".join(lines))
    print("wrote", OUT, len(kept), "+", len(launch), "points")


if __name__ == "__main__":
    main()
