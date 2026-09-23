"""Classify table art pixels into semantic classes (shared by repaint tooling)."""
import colorsys

FLOOR, FLOOR_SHADOW, FLOOR_DEEP, DIRT, STONE, OUTLINE, RIM, ORANGE, EMBER, JADE, RED, BLUE, GOLD, OTHER = range(14)
NAMES = ["floor", "floor_shadow", "floor_deep", "dirt", "stone", "outline", "rim", "orange", "ember", "jade", "red", "blue", "gold", "other"]

# Mushroom-area dirt patch in map_f1 pixel coordinates
DIRT_BOX = (105, 108, 200, 190)


def classify(rgb, xy=None):
    r, g, b = (c / 255 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    hd = h * 360
    in_dirt = xy is not None and DIRT_BOX[0] <= xy[0] <= DIRT_BOX[2] and DIRT_BOX[1] <= xy[1] <= DIRT_BOX[3]
    if v > 0.85 and s < 0.12:
        return RIM
    if 180 <= hd <= 230 and s < 0.45 and v > 0.3:
        return STONE if v < 0.8 or s > 0.08 else RIM
    if 195 <= hd <= 240 and v <= 0.5:
        return OUTLINE
    if 200 <= hd <= 230 and s >= 0.45:
        return BLUE
    if 140 <= hd <= 175 and s > 0.3:
        return JADE
    if (hd >= 330 or hd <= 8) and s > 0.35:
        return RED
    if 25 <= hd <= 45 and s > 0.85 and v > 0.9:
        return ORANGE
    if 45 < hd <= 62 and s > 0.8:
        return GOLD
    if 15 <= hd <= 50:
        if in_dirt and v < 0.78:
            return DIRT
        if v > 0.92 and s < 0.4:
            return FLOOR
        if v > 0.7:
            return FLOOR_SHADOW
        if s > 0.7 and v > 0.6:
            return EMBER
        return FLOOR_DEEP
    if hd < 25 and s > 0.5:
        return EMBER
    return OTHER
