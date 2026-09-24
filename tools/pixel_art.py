"""Small pixel-art canvas shared by the sprite scripts.

Front-facing sprites (masks, the Gilded King, the temple hole) are drawn with shape
primitives, then the left half is mirrored onto the right so they come out exactly
symmetrical, and an outline is traced around everything filled. Shading is kept
symmetric too (lit in the middle, darker toward both edges), so the mirror holds.
"""
import math

from PIL import Image

T = (0, 0, 0, 0)


class Canvas:
    def __init__(self, width, height):
        self.w, self.h = width, height
        self.px = [[T] * width for _ in range(height)]

    def set(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = color

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else T

    def filled(self, x, y):
        return self.get(x, y)[3] > 0

    def ellipse(self, cx, cy, rx, ry, color, where=None):
        """Fills pixels whose centres fall inside the ellipse (cx, cy in pixel units)."""
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0 and (where is None or where(x, y)):
                    self.set(x, y, color)

    def rect(self, x0, y0, x1, y1, color):
        """Fills columns x0..x1 and rows y0..y1, inclusive."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, color)

    def poly(self, points, color):
        for y in range(self.h):
            for x in range(self.w):
                if _inside(points, x + 0.5, y + 0.5):
                    self.set(x, y, color)

    def feather(self, base, angle_deg, length, width, body, vein, tip):
        """A plume from base (x, y) leaning angle_deg off vertical, tip at the far end."""
        a = math.radians(angle_deg)
        ux, uy = math.sin(a), -math.cos(a)
        for y in range(self.h):
            for x in range(self.w):
                rx, ry = x + 0.5 - base[0], y + 0.5 - base[1]
                along = rx * ux + ry * uy
                across = rx * -uy + ry * ux
                if 0 <= along <= length:
                    half = width * 0.5 * math.sin(math.pi * min(1.0, along / length * 0.9 + 0.1))
                    if abs(across) <= half:
                        color = tip if along > length - 2.2 else vein if abs(across) < 0.6 else body
                        self.set(x, y, color)

    def mirror(self):
        """Copies the left half onto the right, mirrored."""
        for y in range(self.h):
            for x in range(self.w // 2):
                self.px[y][self.w - 1 - x] = self.px[y][x]

    def outline(self, color, diagonal=False):
        """Traces an outline in the empty pixels around everything filled."""
        steps = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            steps += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
        edge = [(x, y) for y in range(self.h) for x in range(self.w)
                if not self.filled(x, y) and any(self.filled(x + dx, y + dy) for dx, dy in steps)]
        for x, y in edge:
            self.set(x, y, color)

    def recolor(self, mapping):
        out = Canvas(self.w, self.h)
        out.px = [[mapping.get(c, c) for c in row] for row in self.px]
        return out

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), T)
        for y in range(self.h):
            for x in range(self.w):
                img.putpixel((x, y), self.px[y][x])
        return img


def _inside(poly, x, y):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def asymmetry(img):
    """How many pixels differ from the mirror image; 0 for a symmetric sprite."""
    w, h = img.size
    return sum(1 for y in range(h) for x in range(w) if img.getpixel((x, y)) != img.getpixel((w - 1 - x, y)))


def strip(frames):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), T)
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * w, 0))
    return sheet
