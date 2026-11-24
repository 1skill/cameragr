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

PAGE_COLOR = None   # a flat ground for the page being drawn (colour schemes A/B)

def studio():
    if PAGE_COLOR: return Image.new("RGB", (W, H), PAGE_COLOR)
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
    # Room around it for the blur to spread: a shadow blurred inside the
    # piece's own box was cut off at the box and showed as a hard rectangle.
    pad = shadow * 3
    mask = Image.new("L", (piece.width + 2 * pad, piece.height + 2 * pad), 0)
    mask.paste(a.point(lambda v: v * 0.45), (pad, pad))
    mask = mask.filter(ImageFilter.GaussianBlur(shadow))
    sh = Image.new("RGB", mask.size, (40, 30, 20))
    x, y = xy
    im.paste(sh, (x + shadow // 2 - pad, y + shadow - pad), mask)
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
    grey = (abs(a - a[5, 5]).sum(axis=2) > 90)   # the widget itself, not its shadow on the grey
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
    """One press away: the widgets (real renders) and the Camera Control
    button on the phone's side (GPT photo)."""
    im = studio(); top = headline(im, 8)
    pcs = widget_pieces()
    large = max(pcs, key=lambda p: p.width * p.height)
    medium = max((p for p in pcs if p is not large), key=lambda p: p.width)
    L = large.resize((660, round(large.height * 660 / large.width)), Image.LANCZOS)
    y0 = top + 170
    hand = Image.open("design/appstore/v6/camera_control.png").convert("RGB")
    hand = hand.resize((560, round(hand.height * 560 / hand.width)), Image.LANCZOS)
    place(im, hand, (W - hand.width - 50, y0 + 80), radius=40, shadow=50)
    place(im, L, (50, y0), radius=60, shadow=50)
    M = medium.resize((1060, round(medium.height * 1060 / medium.width)), Image.LANCZOS)
    place(im, M, ((W - M.width) // 2, max(y0 + L.height, y0 + 80 + hand.height) + 70), radius=60, shadow=50)
    return im

def page_bag():
    """The camera bag, open: rolls under straps with their tags, the card and
    the sleeve of samples; a few rolls out on the table below."""
    import random
    rnd = random.Random(3)
    im = studio(); top = headline(im, 9)
    bag = Image.open(f"{SRC}/bag4.png").convert("RGB")
    bag = bag.resize((1180, round(bag.height * 1180 / bag.width)), Image.LANCZOS)
    place(im, bag, ((W - bag.width) // 2, top + 150), radius=60, shadow=56)
    y = top + 150 + bag.height + 110
    for k, (fid, x, dy, ang) in enumerate([("velvia50", 70, 40, -18), ("trix400", 330, 0, 8),
                                            ("natura1600", 600, 60, -6), ("fp100c", 860, 10, 16)]):
        place(im, roll_img(ROLL_IDS.index(fid), 250), (x, y + dy), angle=ang, shadow=22)
    return im

def page_community():
    """同一道题，各自的生活 (concept until the community ships): the shared
    album page as the hero; other people's prints spilling past its edges and
    off the page (GPT concept art, cut out and placed)."""
    import random
    rnd = random.Random(9)
    im = studio(); top = headline(im, 10)
    C = "design/appstore/v6/community"
    loose = [Image.open(f"{C}/p{k}.png").convert("RGB") for k in range(6)]
    def put(k, w, x, y, ang):
        p = loose[k].resize((w, round(loose[k].height * w / loose[k].width)), Image.LANCZOS)
        place(im, p, (x, y), angle=ang, shadow=26)
    # behind the album: prints entering from the edges
    put(0, 430, -150, round(H * 0.30), -14)
    put(4, 430, W - 260, round(H * 0.36), 12)
    album = Image.open("design/appstore/v6/community_concept_tall.png").convert("RGB")
    aw = round(W * 0.80)
    album = album.resize((aw, round(album.height * aw / album.width)), Image.LANCZOS)
    ay = top + 170
    place(im, album, ((W - aw) // 2, ay), angle=-1.5, radius=26, shadow=56)
    # in front: prints sliding out over its lower edge, off the bottom of the page
    put(1, 460, -60, round(H * 0.80), 9)
    put(2, 440, 380, round(H * 0.86), -6)
    put(5, 460, W - 400, round(H * 0.79), -11)
    return im

YELLOW = (236, 186, 52)

def ground(kind):
    if PAGE_COLOR: return Image.new("RGB", (W, H), PAGE_COLOR)
    return Image.new("RGB", (W, H), YELLOW) if kind == "yellow" else studio()

def page3b():
    """所见即所得 (yellow): the camera 94% wide; under it the very picture its
    finder shows, a big print running off the bottom edge."""
    im = ground("yellow"); headline(im, 3)
    body = body_img(round(W * 0.94))
    pr = card(f"{SAMPLES}/gold200__gold200_3.jpg", round(W * 0.83), 26)
    place(im, pr, (round(W * 0.10), round(H * 0.585)), angle=-4, shadow=40)
    place(im, body, ((W - body.width) // 2, round(H * 0.27)), radius=110, shadow=60)
    place(im, roll_img(ROLL_IDS.index("gold200"), 300), (-40, round(H * 0.80)), angle=-30, shadow=24)
    return im

def page4b():
    """买之前，先试试 (grey): the real compare view; under it the same photo
    of yours in five films, fanned out past the edges, each with its roll."""
    im = ground("grey"); headline(im, 4)
    own = crop_rel(Image.open(f"{SRC}/own4.png").convert("RGB"), (0.08, 0.025, 0.92, 0.975))
    own = own.resize((round(W * 0.92), round(own.height * W * 0.92 / own.width)), Image.LANCZOS)
    place(im, own, ((W - own.width) // 2, round(H * 0.21)), radius=46, shadow=50)
    fan = [("trix400", -60, 0.66, -14), ("cine500t", 230, 0.69, -6), ("kodachrome64", 520, 0.70, 3), ("instax", 800, 0.68, 11), ("velvia50", 990, 0.72, 18)]
    for fid, x, yr, ang in fan:
        c = card(f"design/appstore/v6/one/{fid}.jpg", 470, 16)
        place(im, c, (x, round(H * yr)), angle=ang, shadow=28)
    for fid, x, yr, ang in fan[1::2]:
        place(im, roll_img(ROLL_IDS.index(fid), 200), (x + 260, round(H * yr) + 320), angle=ang * 2, shadow=16)
    return im

def page_bag2():
    """军火库 (grey): the open bag across the page; rolls crossing its sides;
    two of the roll's pictures spill from its lower edge off the page."""
    im = ground("grey"); headline(im, 9)
    bag = Image.open(f"{SRC}/bag4.png").convert("RGB")
    bag = bag.resize((round(W * 0.96), round(bag.height * W * 0.96 / bag.width)), Image.LANCZOS)
    y = round(H * 0.49) - bag.height // 2
    place(im, card(f"{SAMPLES}/cine500t__cine500t_1.jpg", 640, 20), (-40, y + bag.height - 120), angle=-7, shadow=34)
    place(im, card(f"{SAMPLES}/cine500t__cine500t_4.jpg", 640, 20), (560, y + bag.height - 40), angle=6, shadow=34)
    place(im, bag, ((W - bag.width) // 2, y), radius=60, shadow=60)
    place(im, roll_img(ROLL_IDS.index("velvia50"), 300), (-90, y - 150), angle=-60, shadow=22)
    place(im, roll_img(ROLL_IDS.index("trix400"), 300), (W - 200, y + bag.height - 260), angle=35, shadow=22)
    return im

def page8b():
    """两种方式，一键直达 (yellow): a GPT photo made for this page — the hand
    and phone, thumb on the Camera Control button, in the lower right — and
    the widget in the clear yellow above."""
    photo = Image.open("design/appstore/v6/camera_control_page.png").convert("RGB")
    sc = max(W / photo.width, H / photo.height)
    photo = photo.resize((round(photo.width * sc), round(photo.height * sc)), Image.LANCZOS)
    im = photo.crop(((photo.width - W) // 2, 0, (photo.width - W) // 2 + W, H))
    headline(im, 8)
    pcs = widget_pieces()
    large = max(pcs, key=lambda p: p.width * p.height)
    L = large.resize((round(W * 0.52), round(large.height * W * 0.52 / large.width)), Image.LANCZOS)
    place(im, L, (70, round(H * 0.20)), angle=-4, radius=52, shadow=46)
    return im

def cut_white(path):
    """A GPT illustration on plain white, its white made transparent (soft
    contact shadow kept as a light shade)."""
    import numpy as np
    img = Image.open(path).convert("RGB"); a = np.asarray(img).astype(float)
    dist = 255 - a.min(axis=2)                      # how far from white
    alpha = np.clip((dist - 50) * 3, 0, 255).astype("uint8")   # the pale contact shadow goes too
    out = img.convert("RGBA"); out.putalpha(Image.fromarray(alpha))
    return out

def page8c():
    """两种方式，一键直达: the widget (real render) and, large in the lower
    right, a close-up illustration of the Camera Control button (GPT)."""
    im = ground("yellow"); headline(im, 8)
    pcs = widget_pieces()
    large = max(pcs, key=lambda p: p.width * p.height)
    L = large.resize((round(W * 0.62), round(large.height * W * 0.62 / large.width)), Image.LANCZOS)
    place(im, L, (60, round(H * 0.19)), angle=-4, radius=56, shadow=46)
    d = cut_white("design/appstore/v6/camera_control_diagram.png")
    d = d.resize((1080, 1080), Image.LANCZOS)
    # the picture ends in a straight line across the phone: fade that edge out
    import numpy as np
    al = np.asarray(d.split()[-1]).astype(float)
    ramp = np.clip(np.arange(d.height) / 260.0, 0, 1)[:, None] * np.clip(np.arange(d.width) / 260.0, 0, 1)[None, :]
    d.putalpha(Image.fromarray((al * ramp).astype("uint8")))
    im.paste(d, (W - 1080 + 40, H - 1080 - 60), d)   # button and arrow wholly inside the page
    return im

def field(im, items, cell, size, jitter=12, seed=1, start_y=520, keep_top=True):
    """A page-wide field of real objects (like page 1's rolls): items cycled
    over a staggered grid, each a little turned. `items` are (image) or
    callables returning one; `size` is the object's longer side."""
    import random
    rnd = random.Random(seed)
    k = 0
    cw, ch = cell
    for row, y in enumerate(range(start_y - ch // 2, H + ch, ch)):
        for x in range(-cw // 2 + (row % 2) * cw // 2, W + cw, cw):
            it = items[k % len(items)]; k += 1
            img = it() if callable(it) else it
            s_ = size / max(img.size)
            img = img.resize((max(1, round(img.width * s_)), max(1, round(img.height * s_))), Image.LANCZOS)
            place(im, img, (x - img.width // 2, y - img.height // 2), angle=rnd.uniform(-jitter, jitter), shadow=12)
    if keep_top:   # a calm band for the headline, as on page 1
        im.paste(Image.new("RGB", (W, start_y - 40), im.getpixel((5, 5))), (0, 0))

def rolls_of(ids):
    return [Image.open(f"{ROLLS}/roll_{i}.png").convert("RGBA") for i in ids]

def pcard(path, w=300, b=10):
    return card(path, w, b)

def y3_community():
    im = ground("yellow")
    C = "design/appstore/v6/community"
    field(im, [pcard(f"{C}/p{k}.png", 320, 0) for k in range(6)], (330, 300), 260, jitter=10, seed=4)
    headline(im, 10)
    album = Image.open("design/appstore/v6/community_concept_tall.png").convert("RGB")
    aw = round(W * 0.82)
    album = album.resize((aw, round(album.height * aw / album.width)), Image.LANCZOS)
    place(im, album, ((W - aw) // 2, 600), angle=-1.5, radius=26, shadow=60)
    return im

def y4_bag():
    im = ground("yellow")
    field(im, rolls_of(ROLL_IDS), (300, 300), 200, jitter=25, seed=2)
    headline(im, 9)
    bag = Image.open(f"{SRC}/bag4.png").convert("RGB")
    bag = bag.resize((round(W * 0.96), round(bag.height * W * 0.96 / bag.width)), Image.LANCZOS)
    place(im, bag, ((W - bag.width) // 2, round(H * 0.33)), radius=60, shadow=60)
    return im

def y5_wysiwyg():
    im = ground("yellow")
    field(im, rolls_of(["gold200"]), (300, 300), 200, jitter=25, seed=3)
    headline(im, 3)
    pr = card(f"{SAMPLES}/gold200__gold200_3.jpg", round(W * 0.80), 26)
    place(im, pr, (round(W * 0.12), round(H * 0.57)), angle=-4, shadow=50)
    body = body_img(round(W * 0.94))
    place(im, body, ((W - body.width) // 2, round(H * 0.25)), radius=110, shadow=60)
    return im

def y6_try():
    im = ground("yellow")
    films = ["portra400", "cine500t", "trix400", "velvia50", "gold200", "instax", "kodachrome64", "natura1600",
             "fp100c", "ccd", "doublex", "pro400h", "c200", "ektachrome", "vista100", "grneg"]
    field(im, [pcard(f"design/appstore/v6/one/{f}.jpg", 300, 10) for f in films], (400, 360), 270, jitter=9, seed=6)
    headline(im, 4)
    own = crop_rel(Image.open(f"{SRC}/own4.png").convert("RGB"), (0.08, 0.025, 0.92, 0.975))
    own = own.resize((round(W * 0.92), round(own.height * W * 0.92 / own.width)), Image.LANCZOS)
    place(im, own, ((W - own.width) // 2, round(H * 0.33)), radius=46, shadow=60)
    return im

def y7_ways():
    im = ground("yellow")
    field(im, rolls_of(ROLL_IDS), (300, 300), 200, jitter=25, seed=7)
    headline(im, 8)
    pcs = widget_pieces()
    large = max(pcs, key=lambda p: p.width * p.height)
    L = large.resize((round(W * 0.66), round(large.height * W * 0.66 / large.width)), Image.LANCZOS)
    place(im, L, (50, round(H * 0.21)), angle=-4, radius=60, shadow=60)
    d = cut_white("design/appstore/v6/camera_control_diagram.png")
    d = d.crop(d.getbbox())
    dw = round(W * 0.62)
    d = d.resize((dw, round(d.height * dw / d.width)), Image.LANCZOS)
    import numpy as np   # soften the cut top and left edges into the ground
    al = np.asarray(d.split()[-1]).astype(float)
    ramp = np.clip(np.arange(d.height) / 140.0, 0, 1)[:, None] * np.clip(np.arange(d.width) / 140.0, 0, 1)[None, :]
    d.putalpha(Image.fromarray((al * ramp).astype("uint8")))
    im.paste(d, (W - dw, H - d.height), d)
    return im

def half(p, side, radius=70, at=0.5):
    """One part of a landscape screen cut at `at` (side 'L' or 'R'), outer corners rounded."""
    w, h = p.size
    c = round(w * at)
    box = (0, 0, c, h) if side == "L" else (c, 0, w, h)
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=255)
    q = p.crop(box).convert("RGBA"); q.putalpha(m.crop(box))
    return q

def put_half(im, q, ang, cut_side, top=None, bottom=None):
    """Turn half q by ang and place it so its cut edge lies just past the
    page edge ('R' right, 'L' left); its top or bottom at the given y."""
    import math
    a = math.radians(ang)
    rp = lambda dx, dy: (dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a))
    r = q.rotate(ang, expand=True, resample=Image.BICUBIC)
    sx = q.width / 2 if cut_side == "R" else -q.width / 2
    xs = [rp(sx, s_ * q.height / 2)[0] for s_ in (-1, 1)]
    ys = [rp(dx, dy)[1] for dx in (-q.width / 2, q.width / 2) for dy in (-q.height / 2, q.height / 2)]
    cx = W + 10 - min(xs) if cut_side == "R" else -10 - max(xs)
    cy = top - min(ys) if top is not None else bottom - max(ys)
    place(im, r, (round(cx - r.width / 2), round(cy - r.height / 2)), shadow=60)

def split_page(n, img, ang=25, L=1900, top=480, bottom=H + 200, at=0.5):
    """A landscape screen too small on a portrait page: turned and split in
    two, the left half above running off the right edge, the right half below
    running off the left (user, 11/23)."""
    im = ground("yellow"); headline(im, n)
    img = img.resize((L, round(img.height * L / img.width)), Image.LANCZOS)
    put_half(im, half(img, "L", at=at), ang, "R", top=top)
    put_half(im, half(img, "R", at=at), ang, "L", bottom=bottom)
    return im

def z3_club():
    """Community, on the club page as designed (concept v4, GPT; the screen
    is landscape): split like the bag page, the prompt-and-tabs side above,
    the album of everyone's photos below. Headline a placeholder (53)."""
    img = Image.open("design/appstore/v6/community_v4.png").convert("RGB")
    return split_page(53, img, L=2350, at=0.31)

def z4_bag():
    return split_page(9, Image.open(f"{SRC}/bag4.png").convert("RGB"))

def z6_try():
    own = crop_rel(Image.open(f"{SRC}/own4.png").convert("RGB"), (0.08, 0.025, 0.92, 0.975))
    # Split, the before/after line was lost; whole screen + the print it gives.
    im = ground("yellow"); headline(im, 4)
    own = own.resize((round(W * 1.04), round(own.height * W * 1.04 / own.width)), Image.LANCZOS)
    place(im, own, (-20, 560), angle=-4, radius=60, shadow=60)
    pr = card("design/appstore/v6/one/portra400.jpg", round(W * 0.92), 28)
    place(im, pr, (round(W * 0.07), round(H * 0.53)), angle=5, shadow=60)
    return im

def z3_community():
    im = ground("yellow"); headline(im, 10)
    album = Image.open("design/appstore/v6/community_concept_tall.png").convert("RGB")
    aw = round(W * 1.0)
    album = album.resize((aw, round(album.height * aw / album.width)), Image.LANCZOS)
    place(im, album, ((W - aw) // 2 + 20, 520), angle=-3, radius=30, shadow=60)
    return im

def z5_wysiwyg():
    im = ground("yellow"); headline(im, 3)
    body = body_img(round(W * 1.25))
    place(im, body, (-round(W * 0.18), 560), angle=-6, radius=130, shadow=60)
    pr = card(f"{SAMPLES}/gold200__gold200_3.jpg", round(W * 1.0), 30)
    place(im, pr, (round(W * 0.06), round(H * 0.50)), angle=5, shadow=60)
    return im

def z7_ways():
    im = ground("yellow"); headline(im, 8)
    pcs = widget_pieces()
    large = max(pcs, key=lambda p: p.width * p.height)
    L_ = large.resize((round(W * 0.86), round(large.height * W * 0.86 / large.width)), Image.LANCZOS)
    place(im, L_, (40, 540), angle=-5, radius=70, shadow=60)
    d = cut_white("design/appstore/v6/camera_control_diagram.png")
    d = d.crop(d.getbbox())
    dw = round(W * 0.95)
    d = d.resize((dw, round(d.height * dw / d.width)), Image.LANCZOS)
    import numpy as np
    al = np.asarray(d.split()[-1]).astype(float)
    ramp = np.clip(np.arange(d.height) / 220.0, 0, 1)[:, None] * np.clip(np.arange(d.width) / 220.0, 0, 1)[None, :]
    d.putalpha(Image.fromarray((al * ramp).astype("uint8")))
    im.paste(d, (W - dw, H - d.height), d)
    return im

def z3_earn():
    """Community page, second take (GPT concept, shots-community): a check-in
    book holding a film you can only earn. GPT's yellow is shifted to ours
    on the background only (weight by closeness to its ground colour)."""
    import numpy as np
    im = ground("yellow")
    a = Image.open("design/appstore/v6/community_earn.png").convert("RGB")
    a = a.resize((W, round(a.height * W / a.width)), Image.LANCZOS)
    x = np.asarray(a).astype(float)
    theirs = np.array([242, 180, 34.0]); ours = np.array(im.getpixel((5, 5)), float)
    d = np.sqrt(((x - theirs) ** 2).sum(-1))
    w = np.clip(1 - (d - 18) / 50, 0, 1)[..., None]
    x = x + w * (ours - theirs)
    a = Image.fromarray(np.clip(x, 0, 255).astype("uint8"))
    im.paste(a, (0, H - a.height + 70))   # a little lower: the headline has three lines
    headline(im, 43)
    return im

def gpt_on_yellow(path, scale_to="width", y=0, theirs=None):
    """A GPT hero drawn on its own yellow, moved onto ours: only pixels close
    to its ground colour are shifted (compositing, no retouching)."""
    import numpy as np
    im = ground("yellow")
    a = Image.open(path).convert("RGB")
    if theirs is None: theirs = a.getpixel((10, 10))
    if scale_to == "width": a = a.resize((W, round(a.height * W / a.width)), Image.LANCZOS)
    else: a = a.resize((round(a.width * H / a.height), H), Image.LANCZOS)
    x = np.asarray(a).astype(float)
    t = np.array(theirs, float); o = np.array(im.getpixel((5, 5)), float)
    d = np.sqrt(((x - t) ** 2).sum(-1))
    w = np.clip(1 - (d - 18) / 50, 0, 1)[..., None]
    a = Image.fromarray(np.clip(x + w * (o - t), 0, 255).astype("uint8"))
    im.paste(a, ((W - a.width) // 2, y))
    return im

def z6_strip():
    """Try before you buy: a roll with its first three frames shot, the rest
    still blank (GPT art)."""
    im = gpt_on_yellow("design/appstore/v6/try_strip.png", y=-60)
    headline(im, 4)
    return im

def z8_phone():
    """Two ways in, one picture: the widget on the home screen and the Camera
    Control button ringed on the same phone (GPT art)."""
    im = gpt_on_yellow("design/appstore/v6/ways_phone.png", scale_to="height")
    headline(im, 8)
    return im

def z5_stack():
    """What you see is what you get: the whole camera, and right under it the
    print it gives, the same picture, both straight and the same width."""
    im = ground("yellow"); headline(im, 3)
    body = body_img(round(W * 0.92))
    place(im, body, ((W - body.width) // 2, 560), radius=round(body.width * 0.09), shadow=60)
    pr = card(f"{SAMPLES}/gold200__gold200_3.jpg", round(W * 0.92), 30)
    place(im, pr, ((W - pr.width) // 2, 560 + body.height + 70), angle=-2, shadow=60)
    return im

def z4_box():
    """Not for sale: a mystery box opened on a roll you can't buy (GPT art)."""
    im = gpt_on_yellow("design/appstore/v6/mystery_box.png", y=-150)
    headline(im, 43)
    return im

def z8_phone2():
    """The phone with only the widget and the Dock (no other icons, no Camera)."""
    im = gpt_on_yellow("design/appstore/v6/ways_phone2.png", scale_to="height")
    headline(im, 8)
    return im

def z5_pair():
    """What you see is what you get: the camera and the print it gives, at the
    same angle, the print tucked under the body's corner like it just came out."""
    im = ground("yellow"); headline(im, 3)
    pr = card(f"{SAMPLES}/gold200__gold200_3.jpg", round(W * 0.90), 30)
    place(im, pr, (round(W * 0.08), 1300), angle=-6, shadow=60)
    body = body_img(round(W * 0.88))
    place(im, body, (round(W * 0.02), 610), angle=-6, radius=round(body.width * 0.09), shadow=70)
    return im

def z6_compare():
    """Try before you buy: the real compare viewer (Grit Neg on a red car split by
    the line), cut to a tall window around the white line so it fills the page;
    its two labels moved to the window's top corners."""
    full = Image.open(f"{SRC}/own_cine.png").convert("RGB")
    k = full.width / 3804
    photo = (round(348 * k), round(108 * k), round(3460 * k), round(2180 * k))
    line_x = round(1900 * k)
    im = ground("yellow"); headline(im, 4)
    win_w, win_h = W - 2 * 46, H - 560 - 90
    ph = photo[3] - photo[1]
    cw = round(ph * win_w / win_h)
    crop = full.crop((line_x - cw // 2, photo[1], line_x + cw // 2, photo[3])).resize((win_w, win_h), Image.LANCZOS)
    pills = []
    for b in (((412, 172, 704, 320) if zh else (408, 168, 844, 324)), (2724, 168, 3396, 324)):   # pill widths follow the film name (Grit Neg)
        p = full.crop(tuple(round(v * k) for v in b)).convert("RGBA")
        m = Image.new("L", p.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, p.width - 1, p.height - 1), p.height // 2, fill=255)
        p.putalpha(m)
        sc = 0.62
        pills.append(p.resize((round(p.width * sc), round(p.height * sc)), Image.LANCZOS))
    crop.paste(pills[0], (36, 36), pills[0])
    crop.paste(pills[1], (win_w - pills[1].width - 36, 36), pills[1])
    place(im, crop, (46, 560), radius=56, shadow=60)
    return im

def z4_locked():
    """Not for sale, in the app's own drawing: a limited roll strapped shut,
    its kraft tag stamped three days running and sealed (GPT art)."""
    # The card on it says how (user: the headline alone is too vague): a zh
    # and an en drawing of the same picture.
    im = gpt_on_yellow(f"design/appstore/v6/locked_roll_{'zh' if zh else 'en'}.png", y=-120)
    headline(im, 43)
    return im

def z8_phone3():
    """The phone, widget and Dock; the phone turned so its side shows, the Camera Control button lit (no arrow: user)."""
    im = gpt_on_yellow("design/appstore/v6/ways_phone4.png", scale_to="height")
    headline(im, 8)
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

SCHEME = os.environ.get("SCHEME", "")
SCHEME_B = {2: (233, 136, 59), 10: (216, 87, 63), 19: (143, 165, 86), 13: (90, 158, 170), 14: (222, 141, 134), 28: (141, 183, 209)}
def colour_for(p):
    if SCHEME == "A": return YELLOW
    if SCHEME == "B": return SCHEME_B.get(p)
    return None

os.makedirs(out, exist_ok=True)
for p in pages:
    PAGE_COLOR = colour_for(p)
    if p in (2, 3, 4, 5, 6, 8, 9, 10, 13, 14, 18, 19, 28, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53): {2: page2, 3: page3, 4: page4, 5: page5, 6: page6, 8: page8, 9: page_bag, 10: page_community, 13: page3b, 14: page4b, 19: page_bag2, 18: page8b, 28: page8c, 33: y3_community, 34: y4_bag, 35: y5_wysiwyg, 36: y6_try, 37: y7_ways, 41: z3_community, 38: z4_bag, 39: z5_wysiwyg, 40: z6_try, 42: z7_ways, 43: z3_earn, 44: z6_strip, 45: z8_phone, 46: z5_stack, 47: z4_box, 48: z8_phone2, 49: z5_pair, 50: z6_compare, 51: z4_locked, 52: z8_phone3, 53: z3_club}[p]().save(f"{out}/{p}_{lang}.png")
    elif 21 <= p <= 25: page1_variant(p - 20).save(f"{out}/1v{p-20}_{lang}.png")
    elif p == 11: page1b("rolls").save(f"{out}/1a_{lang}.png")
    elif p == 12: page1b("prints").save(f"{out}/1b_{lang}.png")
    else: {1: page1}[p]().save(f"{out}/{p}_{lang}.png")
print("ok", pages)
