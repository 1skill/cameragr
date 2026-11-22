"""App Store screenshots for iPhone Duo, landscape, in the same direction and
with the same eight scenes as tools/appstore_iphone.py (the camera or bag
whole, finished pictures as prints, warm paper). One layout in units of the
canvas height, written at either Duo size.
  appstore_duo_v4.py <inner|outer> <lang> <out dir> [titles.json]
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

which, lang, out = sys.argv[1], sys.argv[2], sys.argv[3]
titles = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else {}
W, H = (2853, 2007) if which == "inner" else (2034, 1398)
u = H / 2007
PAPER, INK, MUTED = (239, 233, 221), (34, 28, 22), (120, 108, 94)
SRC, ROLLS = "design/appstore/iphone/src", "cameragr/Resources/Rolls"
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
zh = lang.startswith("zh")

def font(size, bold=False): return ImageFont.truetype(FONT, int(size * u), index=1 if bold else 0)
def canvas(): return Image.new("RGB", (W, H), PAPER)
def fit_w(img, w): return img.resize((int(w), round(img.height * w / img.width)), Image.LANCZOS)
def fit_h(img, h): return img.resize((round(img.width * h / img.height), int(h)), Image.LANCZOS)

def headline(im, n):
    d = ImageDraw.Draw(im)
    head, line = titles.get(str(n), ["（标题）" if zh else "(Title)", "（副标题）" if zh else "(Subtitle)"])
    d.text((W / 2, 150 * u), head, font=font(96, True), fill=INK, anchor="mm")
    d.text((W / 2, 262 * u), line, font=font(48), fill=MUTED, anchor="mm")

def shadowed(im, piece, xy, radius=0, blur=30):
    piece = piece.convert("RGBA"); blur = int(blur * u)
    if radius:
        m = Image.new("L", piece.size, 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, piece.width - 1, piece.height - 1], radius=int(radius * u), fill=255)
        piece.putalpha(m)
    sh = Image.new("RGBA", (piece.width + blur * 4, piece.height + blur * 4), (0, 0, 0, 0))
    sh.paste((0, 0, 0, 110), (blur * 2, blur * 2), piece.split()[-1])
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    x, y = int(xy[0]), int(xy[1])
    im.paste(sh, (x - blur * 2, y - blur * 2 + int(18 * u)), sh)
    im.paste(piece, (x, y), piece)

def print_(path, w, tilt=0):
    p = fit_w(Image.open(path).convert("RGB"), w - 48 * u)
    card = Image.new("RGB", (int(w), p.height + int(48 * u)), (250, 248, 243))
    card.paste(p, (int(24 * u), int(24 * u)))
    return card.rotate(tilt, expand=True, fillcolor=PAPER) if tilt else card

def roll_label(im, film_id, name, x, y):
    roll = Image.open(f"{ROLLS}/roll_{film_id}.png").convert("RGBA")
    roll = fit_h(roll, 150 * u)
    im.paste(roll, (int(x), int(y)), roll)
    ImageDraw.Draw(im).text((x + roll.width + 22 * u, y + 75 * u), name, font=font(46, True), fill=INK, anchor="lm")

def outer(): return Image.open(f"{SRC}/outer.png").convert("RGB").rotate(90, expand=True)
top = 400 * u          # below the headline
room = H - top - 120 * u

shots = []
# 1 · the camera, and the picture it took
im = canvas(); headline(im, 1)
body = fit_w(outer(), W * 0.50); shadowed(im, body, (W * 0.04, top + (room - body.height) / 2), radius=60)
pr = print_(f"{SRC}/gold200__gold200_3.jpg", W * 0.40, -2)
py = top + (room - pr.height - 200 * u) / 2; shadowed(im, pr, (W * 0.57, py))
roll_label(im, "gold200", "Golden 200", W * 0.58, py + pr.height + 50 * u)
shots.append(im)
# 2 · before and after
im = canvas(); headline(im, 2)
a = print_(f"{SRC}/orig__instax_3.jpg", W * 0.43); b = print_(f"{SRC}/instax__instax_3.jpg", W * 0.43)
mid = top + (room - b.height - 200 * u) / 2
shadowed(im, a, (W * 0.05, mid)); shadowed(im, b, (W * 0.52, mid))
d = ImageDraw.Draw(im); d.text((W * 0.06, mid + a.height + 70 * u), "iPhone", font=font(46), fill=MUTED)
roll_label(im, "instax", "Instant 800", W * 0.53, mid + b.height + 50 * u)
shots.append(im)
# 3 · the bag
im = canvas(); headline(im, 3)
bag = fit_h(Image.open(f"{SRC}/bag.png").convert("RGB"), room); shadowed(im, bag, ((W - bag.width) / 2, top), radius=70)
shots.append(im)
# 4 · Cine 500T nights
im = canvas(); headline(im, 4)
mid = top + (room - W * 0.43 / 1.5 - 230 * u) / 2
shadowed(im, print_(f"{SRC}/cine500t__cine500t_1.jpg", W * 0.43, 1.5), (W * 0.05, mid))
p2 = print_(f"{SRC}/cine500t__cine500t_4.jpg", W * 0.43, -1.5); shadowed(im, p2, (W * 0.52, mid))
roll_label(im, "cine500t", "Cine 500T", W * 0.06, mid + p2.height + 50 * u)
shots.append(im)
# 5 · summer
im = canvas(); headline(im, 5)
mid = top + (room - W * 0.43 / 1.5 - 230 * u) / 2
shadowed(im, print_(f"{SRC}/gold200__gold200_1.jpg", W * 0.43, -1.5), (W * 0.05, mid))
p2 = print_(f"{SRC}/kodachrome64__kodachrome64_1.jpg", W * 0.43, 1.5); shadowed(im, p2, (W * 0.52, mid))
roll_label(im, "gold200", "Golden 200", W * 0.06, mid + p2.height + 50 * u)
roll_label(im, "kodachrome64", "Chroma 64", W * 0.53, mid + p2.height + 50 * u)
shots.append(im)
# 6 · the letter
im = canvas(); headline(im, 6)
letter = fit_h(Image.open(f"{SRC}/letter.jpg"), room); shadowed(im, letter, ((W - letter.width) / 2, top), radius=8)
shots.append(im)
# 7 · the photo book
im = canvas(); headline(im, 7)
book = fit_h(Image.open(f"{SRC}/book.png").convert("RGB"), room); shadowed(im, book, ((W - book.width) / 2, top), radius=70)
shots.append(im)
# 8 · private
im = canvas(); headline(im, 8)
body = fit_h(outer(), room * 0.75); shadowed(im, body, (W * 0.07, top + room * 0.1), radius=50)
d = ImageDraw.Draw(im)
for i, t in enumerate(["不用账号", "不上传", "不追踪"] if zh else ["No account", "No uploads", "No tracking"]):
    d.text((W * 0.78, top + room * 0.25 + i * 190 * u), t, font=font(92, True), fill=INK, anchor="mm")
shots.append(im)

os.makedirs(out, exist_ok=True)
for i, im in enumerate(shots, 1):
    im.save(f"{out}/{i}_{which}_{lang}.png")
    im.resize((1100, round(1100 * H / W)), Image.LANCZOS).save(f"{out}/{i}_{which}_{lang}_m.jpg", quality=82)
print("ok", which, lang, len(shots))
