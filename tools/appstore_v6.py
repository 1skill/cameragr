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
INK, SUB = (30, 26, 22), (98, 90, 80)

def font(size, bold=True):
    if zh: return ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", size, index=1 if bold else 0)
    return ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", size, index=1 if bold else 0)

def studio():
    bg = Image.open("design/appstore/v6/studio.png").convert("RGB")
    s = max(W / bg.width, H / bg.height)
    bg = bg.resize((round(bg.width * s), round(bg.height * s)), Image.LANCZOS)
    return bg.crop(((bg.width - W) // 2, 0, (bg.width - W) // 2 + W, H))

def headline(im, n):
    head, line = COPY[str(n)]
    d = ImageDraw.Draw(im)
    x, y = round(W * 0.07), round(H * 0.06)
    size = 100
    while d.textlength(head, font=font(size)) > W * 0.86: size -= 2
    d.text((x, y), head, font=font(size), fill=INK, anchor="la")
    d.text((x, y + size + 34), line, font=font(round(size * 0.44), False), fill=SUB, anchor="la")

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
    if 21 <= p <= 25: page1_variant(p - 20).save(f"{out}/1v{p-20}_{lang}.png")
    elif p == 11: page1b("rolls").save(f"{out}/1a_{lang}.png")
    elif p == 12: page1b("prints").save(f"{out}/1b_{lang}.png")
    else: {1: page1}[p]().save(f"{out}/{p}_{lang}.png")
print("ok", pages)
