"""App Store screenshots, fifth direction (after studying the best sets and
discussing with GPT, project/discuss/shots-redo.md): a charcoal photographer's
table (GPT art), one hero each, big and allowed to crop at the edges; pairs of
screens share the table's light; every headline stays inside its own screen.
Regular iPhone portrait 1206x2622 (the required slot).
  appstore_v5.py <lang zh|en> <out dir> [first last]
Real app renders come from design/appstore/iphone/src (<lang>/ for English).
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1206, 2622
SRC = "design/appstore/iphone/src"
ROLLS = "cameragr/Resources/Rolls"
TABLE = "design/appstore/v5/table_a.png"   # GPT art, a pair of screens side by side
lang, out = sys.argv[1], sys.argv[2]
first, last = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (1, 3)
zh = lang.startswith("zh")
COPY = json.load(open("design/appstore/v5/copy.json"))[("zh" if zh else "en")]
INK, SUB = (240, 233, 220), (176, 166, 150)

def font(size, weight="bold"):
    if zh:
        return ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", size, index={"bold": 1, "regular": 0}[weight])
    return ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", size, index={"bold": 1, "regular": 0}[weight])

def ui(name):
    p = f"{SRC}/{'zh' if zh else 'en'}/{name}"
    if os.path.exists(p): return p
    if not zh: raise SystemExit(f"missing English render {p}")
    return f"{SRC}/{name}"

def table(half):
    """Left or right half of the pair's table, at the screenshot's size."""
    t = Image.open(TABLE).convert("RGB")
    s = H / t.height
    t = t.resize((round(t.width * s), H), Image.LANCZOS)
    mid = t.width // 2
    box = (mid - W, 0, mid, H) if half == 0 else (mid, 0, mid + W, H)
    return t.crop(box)

def headline(im, n):
    head, line = COPY[str(n)]
    d = ImageDraw.Draw(im)
    size = 108 if zh else 100
    while d.textlength(head, font=font(size)) > W - 140: size -= 2   # a long headline shrinks to fit
    d.text((W / 2, 300), head, font=font(size), fill=INK, anchor="mm")
    d.text((W / 2, 430), line, font=font(50 if zh else 46, "regular"), fill=SUB, anchor="mm")

def place(im, piece, xy, angle=0, radius=0, shadow=40):
    """A real render or print on the table: rounded, turned, with a soft shadow."""
    piece = piece.convert("RGBA")
    if radius:
        m = Image.new("L", piece.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, piece.width - 1, piece.height - 1), radius, fill=255)
        piece.putalpha(m)
    if angle:
        piece = piece.rotate(angle, expand=True, resample=Image.BICUBIC)
    a = piece.split()[-1]
    sh = Image.new("RGBA", piece.size, (0, 0, 0, 0)); sh.putalpha(a.point(lambda v: v * 0.7))
    sh = sh.filter(ImageFilter.GaussianBlur(shadow))
    x, y = xy
    im.paste(sh, (x + shadow // 3, y + shadow // 2), sh)
    im.paste(piece, (x, y), piece)
    return piece.size

def fit_w(img, w): return img.resize((w, round(img.height * w / img.width)), Image.LANCZOS)
def fit_h(img, h): return img.resize((round(img.width * h / img.height), h), Image.LANCZOS)

def print_(path, w):
    p = fit_w(Image.open(path).convert("RGB"), w - 36)
    card = Image.new("RGB", (w, p.height + 36), (238, 233, 222)); card.paste(p, (18, 18))
    return card

def roll_tag(im, film_id, name, x, y):
    roll = fit_h(Image.open(f"{ROLLS}/roll_{film_id}.png").convert("RGBA"), 120)
    im.paste(roll, (x, y), roll)
    ImageDraw.Draw(im).text((x + roll.width + 20, y + 60), name, font=font(42, "regular"), fill=INK, anchor="lm")

shots = {}
def chip(im, text, x, y, dark=False):
    """A small label pinned to a print."""
    f = font(40, "bold")
    d = ImageDraw.Draw(im)
    w = d.textlength(text, font=f)
    d.rounded_rectangle((x, y, x + w + 44, y + 64), 32, fill=(28, 24, 20) if dark else (240, 233, 220))
    d.text((x + 22, y + 32), text, font=f, fill=INK if dark else (28, 24, 20), anchor="lm")

# 1 · the camera, big, the right way up, so the picture in its window reads
#     (the viewfinder is the point); grip off the left edge, shutter whole.
#     The print it took lies by its lower right, smaller: the result.
if first <= 1 <= last:
    im = table(0); headline(im, 1)
    body = Image.open(ui("outer.png")).convert("RGB").rotate(90, expand=True)   # upright window -> landscape body
    body = fit_w(body, 1320)
    place(im, print_(f"{SRC}/gold200__gold200_3.jpg", 720), (430, 1700), angle=-5, shadow=30)
    roll_tag(im, "gold200", "Golden 200", 450, 2300)
    place(im, body, (-170, 740), angle=-4, radius=120, shadow=46)
    shots[1] = im
# 2 · the same picture, same crop: the original above, the film below
if first <= 2 <= last:
    im = table(1); headline(im, 2)
    a = print_(f"{SRC}/orig__instax_3.jpg", 1000); b = print_(f"{SRC}/instax__instax_3.jpg", 1000)
    place(im, a, (103, 600), angle=1, shadow=30)
    place(im, b, (103, 600 + a.height + 90), angle=-1, shadow=30)
    chip(im, "原图" if zh else "Original", 140, 600 + 40)
    chip(im, "Instant 800", 140, 600 + a.height + 90 + 40, dark=True)
    shots[2] = im
# 3 · the camera bag, open, the whole width; under it the card of the roll
#     being looked at, magnified: pick on the left, see it on the right.
if first <= 3 <= last:
    im = table(0); headline(im, 3)
    src = Image.open(ui("bag.png")).convert("RGB")
    bag = fit_w(src, 1150)
    top = 820
    place(im, bag, ((W - bag.width) // 2, top), radius=90, shadow=46)
    sw, sh_ = src.size
    card = src.crop((int(sw * 0.535), int(sh_ * 0.03), int(sw * 0.975), int(sh_ * 0.27)))   # the roll card
    card = fit_w(card, 1100)
    place(im, card, ((W - card.width) // 2, top + bag.height + 130), angle=-1.5, radius=36, shadow=40)
    shots[3] = im

os.makedirs(out, exist_ok=True)
for n, im in shots.items():
    im.save(f"{out}/{n}_{lang}.png")
print("ok", sorted(shots))
