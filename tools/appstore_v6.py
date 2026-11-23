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

os.makedirs(out, exist_ok=True)
for p in pages:
    {1: page1}[p]().save(f"{out}/{p}_{lang}.png")
print("ok", pages)
