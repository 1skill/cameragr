"""App Store screenshots, sixth direction (project/discuss/shots-form.md):
one warm-grey studio backdrop (GPT art) for the whole set, the headline at
the top left, and one hero per page: a real app render shown big, bleeding
off at least one edge, no insets. Regular iPhone portrait 1206x2622.
  appstore_v6.py <zh|en> <out dir> <page ...>
Renders: design/appstore/v6/src/<zh|en>/ (outer5.png = the outer screen @5x).
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1206, 2622
lang, out, pages = sys.argv[1], sys.argv[2], [int(p) for p in sys.argv[3:]] or [1]
zh = lang.startswith("zh")
SRC = f"design/appstore/v6/src/{'zh' if zh else 'en'}"
COPY = json.load(open("design/appstore/v6/copy.json"))["zh" if zh else "en"]
INK, SUB = (0x21, 0x1E, 0x18), (98, 90, 80)

def font(size, bold=True):
    if zh: return ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", size, index=2 if bold else 0)   # 2 = W6 bold, 0 = W3
    return ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", size, index=1 if bold else 0)

def studio():
    bg = Image.open("design/appstore/v6/studio.png").convert("RGB")
    s = max(W / bg.width, H / bg.height)
    bg = bg.resize((round(bg.width * s), round(bg.height * s)), Image.LANCZOS)
    return bg.crop(((bg.width - W) // 2, 0, (bg.width - W) // 2 + W, H))

def headline(im, n):
    """Left-aligned headline in up to two lines (broken by hand in copy.json
    with \\n, never shrunk to fit), the same size on every page; an optional
    subtitle below (project/discuss/shots-title.md)."""
    head, line = COPY[str(n)]
    d = ImageDraw.Draw(im)
    x, top = 84, 150
    size = 132 if zh else 112
    step = 158 if zh else 136                     # baseline to baseline
    f = font(size)
    y = top
    for row in head.split("\n"):
        d.text((x, y), row, font=f, fill=INK, anchor="lt")
        y += step
    bottom = y - step + size
    if line:
        d.text((x, bottom + 36), line, font=font(52, False), fill=SUB, anchor="lt")
        bottom += 36 + 52
    return bottom

def place(im, piece, xy, angle=0, radius=0, shadow=60):
    """A real render on the backdrop: rounded, turned, with a soft studio shadow."""
    piece = piece.convert("RGBA")
    if radius:
        m = Image.new("L", piece.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, piece.width - 1, piece.height - 1), radius, fill=255)
        piece.putalpha(m)
    if angle: piece = piece.rotate(angle, expand=True, resample=Image.BICUBIC)
    a = piece.split()[-1]
    sh = Image.new("RGBA", piece.size, (40, 30, 20, 0)); sh.putalpha(a.point(lambda v: v * 0.45))
    sh = sh.filter(ImageFilter.GaussianBlur(shadow))
    x, y = xy
    im.paste(sh, (x + shadow // 2, y + shadow), sh)
    im.paste(piece, (x, y), piece)

def page1():
    """A real film camera: the body huge, its LCD, red shutter, grille and
    stripe filling the page; the left of the body runs off the edge."""
    im = studio(); headline(im, 1)
    body = Image.open(f"{SRC}/outer5.png").convert("RGB").rotate(90, expand=True)   # landscape body
    h = 1900
    body = body.resize((round(body.width * h / body.height), h), Image.LANCZOS)
    turned = body.rotate(-3, expand=True)                                      # only to measure
    place(im, body, (W - turned.width - 30, 560), angle=-3, radius=150, shadow=70)  # right edge inside
    return im

ROLLS = "cameragr/Resources/Rolls"
ROLL_IDS = ["gold200", "portra400", "cine500t", "kodachrome64", "trix400", "instax", "c200", "ccd",
            "velvia50", "fp100c", "grneg", "doublex", "vista100", "ektachrome", "natura1600", "pro400h"]
SAMPLES = "design/appstore/iphone/src"

def pattern(im, kind, top=0):
    """Spaced, tiled rolls or small prints over the backdrop, a little turned
    each, like things laid out on a studio table (app art, only placed)."""
    import random
    rnd = random.Random(7)
    if kind == "rolls":
        cell_w, cell_h, k = 300, 300, 0
        for row, y in enumerate(range(top - 40, H + 200, cell_h)):
            for col, x in enumerate(range(-60 + (row % 2) * cell_w // 2, W + 200, cell_w)):
                roll = Image.open(f"{ROLLS}/roll_{ROLL_IDS[k % len(ROLL_IDS)]}.png").convert("RGBA"); k += 5
                roll = roll.resize((round(roll.width * 190 / roll.height), 190), Image.LANCZOS)
                place(im, roll, (x, y), angle=rnd.uniform(-25, 25), shadow=14)
    else:
        files = sorted(f for f in os.listdir(SAMPLES) if "__" in f and not f.startswith("orig"))
        cell_w, cell_h, k = 330, 300, 0
        for row, y in enumerate(range(top - 60, H + 200, cell_h)):
            for col, x in enumerate(range(-80 + (row % 2) * cell_w // 2, W + 200, cell_w)):
                ph = Image.open(f"{SAMPLES}/{files[k % len(files)]}").convert("RGB"); k += 7
                ph = ph.resize((230, round(ph.height * 230 / ph.width)), Image.LANCZOS)
                card = Image.new("RGB", (ph.width + 20, ph.height + 20), (240, 236, 228)); card.paste(ph, (10, 10))
                place(im, card, (x, y), angle=rnd.uniform(-14, 14), shadow=16)

def roll_img(k, h):
    roll = Image.open(f"{ROLLS}/roll_{ROLL_IDS[k % len(ROLL_IDS)]}.png").convert("RGBA")
    return roll.resize((round(roll.width * h / roll.height), h), Image.LANCZOS)

def body_img(w):
    body = Image.open(f"{SRC}/outer5.png").convert("RGB").rotate(90, expand=True)
    return body.resize((w, round(body.height * w / body.width)), Image.LANCZOS)

def calm_top(im, h=560):
    im.paste(studio().crop((0, 0, W, h)), (0, 0))

def page1_variant(v):
    """Page 1 layouts with rolls (all app art, placed): v1 grid, v2 diagonal
    rows, v3 one band behind the camera, v4 a pile poured round it, v5 on
    the body's yellow."""
    import random
    rnd = random.Random(11)
    im = studio()
    if v == 5:
        im = Image.new("RGB", (W, H), (236, 186, 52))
    if v in (1, 5):
        pattern(im, "rolls", top=0)
    elif v == 2:
        k = 0
        for row, y in enumerate(range(-300, H + 300, 260)):
            for col, x in enumerate(range(-400 + (row % 2) * 130, W + 300, 260)):
                place(im, roll_img(k, 170), (x + row * 60, y), angle=-30, shadow=12); k += 3
    elif v == 3:
        k = 0
        # two shelves of rolls standing upright: above and below the camera
        for y in (790, 2010, 2300):
            for x in range(-60 + (y // 7) % 70, W + 100, 150):
                place(im, roll_img(k, 250), (x, y), angle=rnd.uniform(-3, 3), shadow=18); k += 3
    elif v == 4:
        k = 0
        for _ in range(46):
            x = rnd.uniform(-120, W - 60); y = rnd.uniform(900, H - 120)
            place(im, roll_img(k, rnd.randint(180, 260)), (int(x), int(y)), angle=rnd.uniform(-80, 80), shadow=16); k += 1
    if v != 5: calm_top(im)
    else: im.paste(Image.new("RGB", (W, 560), (236, 186, 52)), (0, 0))
    headline(im, 1)
    body = body_img(1120)
    place(im, body, ((W - body.width) // 2, 1180 if v != 4 else 760), radius=110, shadow=60)
    return im

def page2():
    """Lots of films: a wall of prints, each from a different roll, its
    canister pinned at the corner (real renders from the app, placed)."""
    import random
    rnd = random.Random(5)
    im = studio(); headline(im, 2)
    films = ["portra400", "cine500t", "trix400", "velvia50", "gold200", "natura1600", "fp100c", "ccd",
             "kodachrome64", "doublex", "instax", "pro400h", "vista100", "ektachrome", "grneg", "c200"]
    cols, pw = 3, 360
    k = 0
    used = set()
    for row in range(5):
        for col in range(cols):
            fid = films[k % len(films)]; n = 1 + (k * 7) % 4; k += 1
            # a scene not shown yet on this page (rolls share source pictures)
            cands = sorted(f for f in os.listdir(SAMPLES) if f.startswith(fid + "__"))
            pick = next((f for f in cands if f.split("__")[1] not in used), cands[0]); used.add(pick.split("__")[1])
            ph = Image.open(f"{SAMPLES}/{pick}").convert("RGB")
            ph = ph.resize((pw, round(ph.height * pw / ph.width)), Image.LANCZOS)
            card = Image.new("RGBA", (ph.width + 24, ph.height + 24), (240, 236, 228, 255)); card.paste(ph, (12, 12))
            x = 40 + col * (pw + 30) + (row % 2) * 30 - 15
            y = 640 + row * 400
            place(im, card, (x, y), angle=rnd.uniform(-5, 5), shadow=22)
            roll = roll_img(ROLL_IDS.index(fid), 130)
            place(im, roll, (x + card.width - 90, y + card.height - 110), angle=rnd.uniform(-20, 20), shadow=10)
    return im

def card(path, w, border=16):
    ph = Image.open(path).convert("RGB")
    ph = ph.resize((w, round(ph.height * w / ph.width)), Image.LANCZOS)
    c = Image.new("RGB", (ph.width + 2 * border, ph.height + 2 * border), (240, 236, 228)); c.paste(ph, (border, border))
    return c

def crop_rel(img, box):
    w, h = img.size
    return img.crop((round(box[0] * w), round(box[1] * h), round(box[2] * w), round(box[3] * h)))

def page3():
    """所见即所得: the camera, and below it the very picture its finder shows."""
    im = studio(); top = headline(im, 3)
    body = body_img(1120)
    place(im, body, ((W - body.width) // 2, top + 160), radius=110, shadow=60)
    pr = card(f"{SAMPLES}/gold200__gold200_3.jpg", 760, 22)
    place(im, pr, (W - pr.width - 40, top + 160 + body.height + 60), angle=-4, shadow=34)
    place(im, roll_img(ROLL_IDS.index("gold200"), 230), (90, top + 160 + body.height + 260), angle=-14, shadow=20)
    return im

def page4():
    """Try it on your own photo: the real compare view, and a few of your photos."""
    im = studio(); top = headline(im, 4)
    own = crop_rel(Image.open(f"{SRC}/own4.png").convert("RGB"), (0.08, 0.025, 0.92, 0.975))
    own = own.resize((1140, round(own.height * 1140 / own.width)), Image.LANCZOS)
    place(im, own, ((W - own.width) // 2, top + 150), radius=46, shadow=50)
    y = top + 150 + own.height + 90
    for i, (f, x, ang) in enumerate([("orig__instax_3.jpg", 70, -8), ("orig__gold200_4.jpg", 420, 5), ("orig__c200_4.jpg", 760, -3)]):
        place(im, card(f"{SAMPLES}/{f}", 380, 14), (x, y + (i % 2) * 40), angle=ang, shadow=24)
    return im

def page5():
    """Send it to a friend: the 'your turn' letter itself."""
    im = studio(); top = headline(im, 5)
    letter = Image.open(f"{SRC}/letter.jpg").convert("RGB")
    letter = letter.resize((1060, round(letter.height * 1060 / letter.width)), Image.LANCZOS)
    place(im, letter, ((W - letter.width) // 2, top + 140), angle=-2, radius=14, shadow=50)
    return im

def page6():
    """A theme a day in the little book; the roll it gives."""
    im = studio(); top = headline(im, 6)
    book = Image.open(f"{SRC}/book4.png").convert("RGB")
    book = book.resize((1180, round(book.height * 1180 / book.width)), Image.LANCZOS)
    place(im, book, ((W - book.width) // 2, top + 150), radius=60, shadow=56)
    # the days' pictures, loose on the table, and the roll three days running gives
    y = top + 150 + book.height + 80
    place(im, card("design/appstore/v6/book/cat.jpg", 470, 18), (60, y + 30), angle=-6, shadow=28)
    place(im, card("design/appstore/v6/book/dog.jpg", 470, 18), (500, y + 120), angle=5, shadow=28)
    roll = roll_img(ROLL_IDS.index("portra400"), 300)
    place(im, roll, (W - roll.width - 60, y - 10), angle=-18, shadow=24)
    return im

def widget_pieces():
    """The three widgets cut from the simulator's grey along their own edges."""
    import numpy as np
    g = Image.open(f"{SRC}/widgets.png").convert("RGB"); a = np.asarray(g).astype(int)
    grey = (abs(a - a[5, 5]).sum(axis=2) > 24)
    rows = np.where(grey.any(axis=1))[0]
    bands, start = [], rows[0]
    for r0, r1 in zip(rows, rows[1:]):
        if r1 - r0 > 10: bands.append((start, r0)); start = r1
    bands.append((start, rows[-1]))
    pieces = []
    for y0, y1 in bands:
        cols = np.where(grey[y0:y1 + 1].any(axis=0))[0]
        xs, s0 = [], cols[0]
        for c0, c1 in zip(cols, cols[1:]):
            if c1 - c0 > 10: xs.append((s0, c0)); s0 = c1
        xs.append((s0, cols[-1]))
        for x0, x1 in xs:
            if x1 - x0 > 100 and y1 - y0 > 100: pieces.append(g.crop((x0, y0, x1 + 1, y1 + 1)))
    return pieces

def page8():
    """Shoot any time: the widgets (real renders)."""
    im = studio(); top = headline(im, 8)
    pcs = widget_pieces()
    large = max(pcs, key=lambda p: p.width * p.height)
    medium = max((p for p in pcs if p is not large), key=lambda p: p.width)
    L = large.resize((1000, round(large.height * 1000 / large.width)), Image.LANCZOS)
    M = medium.resize((1000, round(medium.height * 1000 / medium.width)), Image.LANCZOS)
    place(im, L, ((W - L.width) // 2, top + 150), radius=70, shadow=50)
    place(im, M, ((W - M.width) // 2, top + 150 + L.height + 60), radius=70, shadow=50)
    return im

def page1b(kind):
    """The whole camera, centred, over a tiled table of rolls or prints."""
    im = studio()
    pattern(im, kind, top=0)
    # the headline sits on a calm band of the backdrop
    band = studio().crop((0, 0, W, 560))
    im.paste(band, (0, 0))
    headline(im, 1)
    body = Image.open(f"{SRC}/outer5.png").convert("RGB").rotate(90, expand=True)
    body = body.resize((1120, round(body.height * 1120 / body.width)), Image.LANCZOS)
    place(im, body, ((W - body.width) // 2, 1180), angle=0, radius=110, shadow=60)
    return im

os.makedirs(out, exist_ok=True)
for p in pages:
    if p in (2, 3, 4, 5, 6, 8): {2: page2, 3: page3, 4: page4, 5: page5, 6: page6, 8: page8}[p]().save(f"{out}/{p}_{lang}.png")
    elif 21 <= p <= 25: page1_variant(p - 20).save(f"{out}/1v{p-20}_{lang}.png")
    elif p == 11: page1b("rolls").save(f"{out}/1a_{lang}.png")
    elif p == 12: page1b("prints").save(f"{out}/1b_{lang}.png")
    else: {1: page1}[p]().save(f"{out}/{p}_{lang}.png")
print("ok", pages)
