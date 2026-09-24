"""Generate the billboard pictures: Sprites/billboard.png.

Pokemon Pinball's billboard shows where you are on the map and spins its slot machine.
Ours pops up under the score with, one 64x40 frame each:

   0-3   the four cities: Tenochtitlan's Templo Mayor on its lake, Teotihuacan's Pyramid
         of the Sun, El Castillo at Chichen Itza, Palenque's Temple of the Inscriptions
   4     El Dorado: the gilded king on his raft on Lake Guatavita
   5-9   the temple roulette's prizes: offering, treasure, kickback, water spirit, travel
   10-13 the four relics
   14-17 the four ball upgrades
   18-33 the sixteen spirits of the Spirit Codex, on a teal sunburst
   34-49 the same spirits awakened into their divine forms, on a gold sunburst

The monuments are drawn on the left and mirrored, lit evenly from the front so the
mirror holds. The prizes, relics and balls are the table's own sprites, enlarged on a
sunburst, so they match what's on the table.

Run from the repo root:  python3 tools/make_billboard_art.py
"""
import math
from pathlib import Path

from PIL import Image

from pixel_art import Canvas, strip

OUT = Path("Sprites/billboard.png")
W, H = 64, 40
T = (0, 0, 0, 0)
INK=(0x16,0x0E,0x20,255)
def C(h): h=h.lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))+(255,)

def sky(c, bands):
    """Horizontal bands top to bottom, dithered one row at each boundary."""
    for y in range(H):
        for i, (y0, col) in enumerate(bands):
            if y >= y0: color, prev = col, bands[i-1][1] if i else col
        for x in range(W):
            edge = any(y == b[0] for b in bands[1:])
            c.set(x, y, prev if edge and (x % 2 == 0) else color)

def pyramid(c, cx, base, tiers, lit, face, shade, stair=None):
    """Stepped pyramid centred on cx: tiers of (height, half_width at the foot). Each tier
    leans in as it rises (talud), with a lit terrace edge on top and a shadow at the foot.
    A central stair of alternating lit and dark treads if given. Returns the top row."""
    y = base
    for h, half in tiers:
        for i in range(h):
            yy = y - 1 - i
            w = half - i * 0.5
            for x in range(int(round(cx - w)), int(round(cx + w))):
                c.set(x, yy, lit if i == h - 1 else shade if i == 0 else face)
        y -= h
    if stair:
        s_lit, s_dark, s_side, half = stair
        for yy in range(y, base):
            for x in range(int(cx - half - 1), int(cx + half + 1)):
                edge = x < cx - half or x >= cx + half
                c.set(x, yy, s_side if edge else s_lit if (base - yy) % 2 == 0 else s_dark)
    return y

def teotihuacan():
    c = Canvas(W, H)
    sky(c, [(0, C('#1b3a6b')), (7, C('#2c67a4')), (14, C('#4f8fc6')), (21, C('#8ec5e0'))])
    # the sun, high over the pyramid
    c.ellipse(32, 4.5, 3.4, 3.4, C('#f8d000')); c.ellipse(32, 4.5, 2.2, 2.2, C('#f0f090'))
    # Cerro Gordo and the hills, either side
    for x in range(W):
        h = 22 + 3 * math.cos((x - 32) / 64 * 2 * math.pi) + 1.2 * math.sin(abs(x - 32) / 3.5)
        for y in range(int(h), H):
            c.set(x, y, C('#3d6b5a') if y > h + 1 else C('#5a8a6e'))
    # ground and the Avenue of the Dead
    c.rect(0, 33, W - 1, H - 1, C('#8a6a3a'))
    c.rect(0, 33, W - 1, 33, C('#a8864a'))
    c.poly([(29, 33), (35, 33), (39, 40), (25, 40)], C('#b8986a'))
    for x in (6, 12, 52, 58):   # platforms along the avenue
        c.rect(x - 2, 31, x + 1, 32, C('#a07848')); c.rect(x - 2, 31, x + 1, 31, C('#d0a868'))
    # the Pyramid of the Sun: five leaning terraces and a stair up the middle
    top = pyramid(c, 32, 33, [(5, 23), (5, 19), (4, 15), (4, 11), (3, 8)],
                  C('#e8c080'), C('#b98a4e'), C('#7a5230'),
                  stair=(C('#f0d8a0'), C('#c9a060'), C('#8a6034'), 2))
    # the temple on the summit
    c.rect(29, top - 3, 34, top - 1, C('#9a6a3c')); c.rect(29, top - 3, 34, top - 3, C('#e8c080'))
    c.rect(31, top - 2, 32, top - 1, C('#3a2418'))
    c.mirror()
    return c.image()

def water(c, y0, tones):
    """A lake from row y0 down, in horizontal ripple bands."""
    for y in range(y0, H):
        for x in range(W):
            c.set(x, y, tones[(y - y0) % len(tones)] if (x + y) % 7 else tones[0])

def tenochtitlan():
    c = Canvas(W, H)
    sky(c, [(0, C('#3b2a5a')), (6, C('#6b3a6b')), (12, C('#b8586a')), (18, C('#f0a060')), (23, C('#f8d090'))])
    # Popocatepetl and Iztaccihuatl, snow on their peaks
    for cx, peak, half in ((14, 13, 13), (50, 15, 14)):
        for x in range(W):
            top = peak + abs(x - cx) * 0.8
            for y in range(int(top), 27):
                c.set(x, y, C('#f0f0ff') if y < peak + 3 else C('#6a5a8a'))
    water(c, 27, [C('#2c67a4'), C('#1a86a3'), C('#2c67a4'), C('#4f8fc6')])
    # the island platform and the Templo Mayor, a double stair up to twin shrines
    c.rect(10, 27, 53, 29, C('#8a6a4a')); c.rect(10, 27, 53, 27, C('#c8a878'))
    top = pyramid(c, 32, 27, [(4, 18), (4, 15), (3, 12), (3, 10)], C('#e8d8c0'), C('#b8a080'), C('#7a6448'))
    for sx in (27, 35):   # two stairways side by side
        for yy in range(top, 27):
            c.rect(sx, yy, sx + 1, yy, C('#f0e8d8') if (27 - yy) % 2 == 0 else C('#c8b8a0'))
    # Tlaloc's shrine in blue and white on the left, Huitzilopochtli's in red on the right
    for x0, stripe, roof in ((24, C('#2c67a4'), C('#c6d8e9')), (33, C('#b83838'), C('#f0e8d8'))):
        c.rect(x0, top - 5, x0 + 6, top - 1, C('#f0e8d8'))
        for yy in range(top - 5, top):
            if yy % 2 == 0:
                c.rect(x0, yy, x0 + 6, yy, stripe)
        c.rect(x0 + 2, top - 3, x0 + 4, top - 1, INK)     # doorway
        c.rect(x0 - 1, top - 6, x0 + 7, top - 6, roof)
    # canoes on the lake
    for cx in (8, 56):
        c.rect(cx - 3, 33, cx + 2, 33, C('#5a3a28')); c.set(cx, 32, C('#3a2418'))
    return c.image()

def chichen_itza():
    c = Canvas(W, H)
    sky(c, [(0, C('#1a4a5a')), (7, C('#2a7a7a')), (14, C('#e08a4a')), (21, C('#f8c070'))])
    # jungle either side
    for x in range(W):
        d = abs(x - 32)
        if d > 20:
            top = 18 + int(3 * math.sin(d * 0.9))
            for y in range(top, 34):
                c.set(x, y, C('#1c4a2c') if (x + y) % 5 else C('#2e6a3c'))
    c.rect(0, 34, W - 1, H - 1, C('#5a7a3a')); c.rect(0, 34, W - 1, 34, C('#7a9a4a'))
    # El Castillo: nine terraces, a temple on top, serpent heads at the foot of the stair
    top = pyramid(c, 32, 34, [(3, 20), (3, 18), (3, 16), (3, 14), (3, 12), (2, 10), (2, 9), (2, 8), (2, 7)],
                  C('#e8d8b0'), C('#c0a878'), C('#806840'),
                  stair=(C('#f4ead0'), C('#c8b888'), C('#9a8050'), 2))
    c.rect(27, top - 5, 36, top - 1, C('#c0a878')); c.rect(27, top - 5, 36, top - 5, C('#e8d8b0'))
    c.rect(30, top - 3, 33, top - 1, INK)
    for sx in (28, 35):   # Kukulkan's heads, jaws open at the bottom of the stair
        c.rect(sx - 1, 32, sx + 1, 33, C('#33776a')); c.set(sx, 33, C('#be562e'))
    c.mirror()
    return c.image()

def palenque():
    c = Canvas(W, H)
    sky(c, [(0, C('#0c1430')), (9, C('#18244a')), (17, C('#2a3a6a'))])
    # jungle hills and a band of mist
    for x in range(W):
        top = 20 + int(2.5 * math.cos(x / 5.0))
        for y in range(top, H):
            c.set(x, y, C('#16402a') if (x * 3 + y) % 6 else C('#24603a'))
    c.rect(0, 27, W - 1, 28, C('#6a8aa0'))
    # the Temple of the Inscriptions: steep terraces, a wide temple and its lattice roof comb
    top = pyramid(c, 32, 36, [(2, 16), (2, 15), (2, 14), (2, 13), (2, 12), (2, 11), (2, 10), (2, 9)],
                  C('#c8c8b8'), C('#8a8a7a'), C('#5a5a4e'),
                  stair=(C('#d8d8c8'), C('#a0a090'), C('#6a6a5a'), 2))
    c.rect(22, top - 6, 41, top - 1, C('#9a9a8a')); c.rect(22, top - 6, 41, top - 6, C('#d8d8c8'))
    for dx in (24, 28, 32, 36):   # five doorways (the middle one straddles the centre)
        c.rect(dx, top - 4, dx + 1, top - 1, INK)
    c.rect(30, top - 10, 33, top - 7, C('#8a8a7a'))
    for yy in (top - 10, top - 8):
        c.rect(30, yy, 33, yy, C('#c8c8b8'))
    c.mirror()
    # the night sky isn't symmetrical: one crescent moon and scattered stars
    for x, y in ((5, 3), (20, 2), (27, 6), (44, 4), (52, 8), (59, 3)):
        c.set(x, y, C('#f0f0ff'))
    c.ellipse(12, 8, 3, 3, C('#f0f0d0')); c.ellipse(13.3, 7.3, 2.5, 2.5, C('#0c1430'))
    return c.image()

def el_dorado():
    """The gilded king on his raft on Lake Guatavita, against a rising sun."""
    c = Canvas(W, H)
    sky(c, [(0, C('#5a2a18')), (6, C('#a8581c')), (12, C('#e8902a')), (18, C('#f8c050'))])
    # the sun rising behind him, with broad rays
    for y in range(H):
        for x in range(W):
            ray = int(math.degrees(math.atan2(x + 0.5 - 32, 24 - y)) // 15) % 2 == 0
            if y < 24 and ray and math.hypot(x + 0.5 - 32, 24 - y) > 12:
                c.set(x, y, C('#f8d070') if y > 10 else C('#e8a040'))
    c.ellipse(32, 24, 11, 11, C('#f8d000')); c.ellipse(32, 24, 9, 9, C('#f8e8a0'))
    # the ring of mountains round the lake, dark against the dawn
    for x in range(W):
        top = 17 + int(5 * (1 - abs(x + 0.5 - 32) / 32) ** 2)
        if abs(x + 0.5 - 32) > 13:
            for y in range(top, 26):
                c.set(x, y, C('#3a2418') if y > top else C('#6a4228'))
    # the lake, with the sun's gold running down it
    water(c, 26, [C('#1a4a5a'), C('#23606a'), C('#1a4a5a'), C('#2a6a6a')])
    for y in range(27, H, 2):
        half = 6 - (y - 27) // 3
        c.rect(32 - half, y, 31, y, C('#f8d070'))
    # the raft
    c.rect(20, 31, 31, 33, C('#7a4a20')); c.rect(20, 31, 31, 31, C('#b07a3a'))
    for x in (22, 26, 30):
        c.rect(x, 32, x, 33, C('#5a3418'))
    c.rect(22, 25, 22, 30, C('#5a3418')); c.set(22, 24, C('#f8a008')); c.set(22, 23, C('#f8d000'))  # torch
    # the gilded man: gold from head to foot, arms raised to the sun, plumes on his head.
    # Drawn on his own layer and outlined in bronze so he stands out against the sun.
    sky_c = c
    c = Canvas(W, H)
    c.rect(30, 23, 31, 30, C('#f8d000'))              # body
    c.rect(29, 24, 29, 28, C('#f8a008'))              # shaded side
    c.rect(30, 28, 30, 30, C('#f8a008'))
    for i in range(4):                                 # raised arm
        c.set(28 - i, 22 - i, C('#f8d000'))
    c.ellipse(32, 21, 1.8, 1.8, C('#f8d000'))         # head
    c.rect(29, 17, 31, 18, C('#1eb621')); c.set(30, 16, C('#1eb621')); c.set(28, 16, C('#33776a'))
    c.mirror()
    c.outline(C('#5a2a0a'), diagonal=True)
    sky_c.mirror()
    scene = sky_c.image()
    scene.alpha_composite(c.image())
    return scene


def sunburst(dark, light):
    """A symmetric sunburst backdrop for the prize, relic and ball pictures."""
    c = Canvas(W, H)
    for y in range(H):
        for x in range(W):
            ray = int(abs(math.degrees(math.atan2(x + 0.5 - 32, y + 0.5 - 20))) // 18) % 2 == 0
            c.set(x, y, light if ray else dark)
    c.ellipse(32, 20, 13, 13, light)
    return c.image()


def framed(sprite, scale, backdrop=(C('#5a2a18'), C('#8a4a1c'))):
    """A sprite from the table, enlarged by whole pixels and centred on a sunburst."""
    img = sunburst(*backdrop)
    big = sprite.resize((sprite.width * scale, sprite.height * scale), Image.NEAREST)
    img.alpha_composite(big, ((W - big.width) // 2, (H - big.height) // 2))
    return img


def frames_of(path, count):
    sheet = Image.open(path).convert("RGBA")
    w = sheet.width // count
    return [sheet.crop((i * w, 0, (i + 1) * w, sheet.height)) for i in range(count)]


def coin_pile(count):
    coin = frames_of("Sprites/el_dorado/gold_coin.png", 2)[0]
    img = sunburst(C('#5a2a18'), C('#8a4a1c'))
    rows = [[(32, 26)], [(23, 26), (41, 26), (32, 18)], [(14, 28), (23, 26), (32, 26), (41, 26), (50, 28), (27, 18), (37, 18), (32, 10)]]
    for x, y in rows[count]:
        img.alpha_composite(coin, (x - 9, y - 9))
    return img


def main():
    cities = [tenochtitlan(), teotihuacan(), chichen_itza(), palenque()]
    relics = frames_of("Sprites/table/relics.png", 8)[4:]
    ball_sheet = Image.open("Sprites/ball_spin.png").convert("RGBA")
    balls = [ball_sheet.crop((0, t * 20, 20, (t + 1) * 20)) for t in range(4)]
    prizes = [
        coin_pile(1),                                                      # offering
        coin_pile(2),                                                      # treasure
        framed(frames_of("Sprites/table/kickback_frog.png", 3)[1], 2),     # kickback
        framed(frames_of("Sprites/table/spirit.png", 3)[0], 2),            # water spirit
        framed(frames_of("Sprites/table/serpent.png", 3)[0], 1),           # travel
    ]
    pictures = cities + [el_dorado()] + prizes
    pictures += [framed(r, 3) for r in relics]
    pictures += [framed(b, 2) for b in balls]
    sheet = Image.open("Sprites/table/spirits.png").convert("RGBA")
    for row in range(sheet.height // 14):
        spirit = sheet.crop((0, row * 14, 18, row * 14 + 14))
        pictures.append(framed(spirit, 2, backdrop=(C('#123a4a'), C('#1a5a6a'))))
    divine = Image.open("Sprites/table/spirits_awakened.png").convert("RGBA")
    for row in range(divine.height // 18):
        form = divine.crop((0, row * 18, 22, row * 18 + 18))
        pictures.append(framed(form, 2, backdrop=(C('#6a3a10'), C('#a8681c'))))
    strip(pictures).save(OUT)
    print("wrote", OUT, len(pictures), "pictures")


if __name__ == "__main__":
    main()
