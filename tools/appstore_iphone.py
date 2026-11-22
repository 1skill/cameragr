"""App Store screenshots for iPhone (6.9", 1320x2868 portrait), in the
direction chosen after looking at other camera apps: the camera or the bag
whole, and finished pictures as large prints, on warm paper; the headline
is written by the user (placeholders until then).
  appstore_iphone.py <lang> <out dir> [titles.json]
"""
import json, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
PAPER = (239, 233, 221)
INK = (34, 28, 22)
MUTED = (120, 108, 94)
SRC = "design/appstore/iphone/src"
ROLLS = "cameragr/Resources/Rolls"
lang, out = sys.argv[1], sys.argv[2]
titles = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else {}
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"

def font(size, bold=False):
    return ImageFont.truetype(FONT, size, index=1 if bold else 0)

def canvas():
    return Image.new("RGB", (W, H), PAPER)

def headline(im, n):
    d = ImageDraw.Draw(im)
    head, line = titles.get(str(n), ["（标题）" if lang.startswith("zh") else "(Title)",
                                      "（副标题）" if lang.startswith("zh") else "(Subtitle)"])
    d.text((W / 2, 250), head, font=font(92, True), fill=INK, anchor="mm")
    d.text((W / 2, 360), line, font=font(46), fill=MUTED, anchor="mm")

def shadowed(im, piece, xy, radius=0, blur=28, offset=18):
    piece = piece.convert("RGBA")
    if radius:
        mask = Image.new("L", piece.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, piece.width - 1, piece.height - 1], radius=radius, fill=255)
        piece.putalpha(mask)
    shadow = Image.new("RGBA", (piece.width + blur * 4, piece.height + blur * 4), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 110), (blur * 2, blur * 2), piece.split()[-1])
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    im.paste(shadow, (xy[0] - blur * 2, xy[1] - blur * 2 + offset), shadow)
    im.paste(piece, xy, piece)

def fit(img, width):
    return img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)

def print_(path, width):
    """A finished picture as a print with a white border."""
    p = fit(Image.open(path).convert("RGB"), width - 48)
    card = Image.new("RGB", (width, p.height + 48), (250, 248, 243))
    card.paste(p, (24, 24))
    return card

def roll_label(im, film_id, name, x, y):
    roll = Image.open(f"{ROLLS}/roll_{film_id}.png").convert("RGBA")
    roll = roll.resize((round(roll.width * 150 / roll.height), 150), Image.LANCZOS)
    im.paste(roll, (x, y), roll)
    ImageDraw.Draw(im).text((x + roll.width + 22, y + 75), name, font=font(44, True), fill=INK, anchor="lm")

def rotated_screen(path):
    """A render of the upright-window outer screen, turned the right way."""
    return Image.open(path).convert("RGB").rotate(90, expand=True)

shots = []
# 1 · the camera, and the picture it took
im = canvas(); headline(im, 1)
body = fit(rotated_screen(f"{SRC}/outer.png"), 1220)
shadowed(im, body, (50, 520), radius=60)
pr = print_(f"{SRC}/gold200__gold200_3.jpg", 1160).rotate(-2, expand=True, fillcolor=PAPER)
shadowed(im, pr, (80, 1500))
roll_label(im, "gold200", "Golden 200", 120, 1500 + pr.height + 70)
shots.append(im)
# 2 · before and after
im = canvas(); headline(im, 2)
a = print_(f"{SRC}/orig__instax_3.jpg", 1160); b = print_(f"{SRC}/instax__instax_3.jpg", 1160)
shadowed(im, a, (80, 520)); shadowed(im, b, (80, 1440))
d = ImageDraw.Draw(im)
d.text((120, 1360), "iPhone", font=font(44), fill=MUTED)
roll_label(im, "instax", "Instant 800", 120, 2300)
shots.append(im)
# 3 · the bag
im = canvas(); headline(im, 3)
bag = Image.open(f"{SRC}/bag.png").convert("RGB")
shadowed(im, fit(bag, 1240), (40, 560), radius=70)
detail = bag.crop((0, 0, bag.width // 2, bag.height // 2))
shadowed(im, fit(detail, 1000), (160, 1560), radius=40)
shots.append(im)
# 4 · nights on Cine 500T
im = canvas(); headline(im, 4)
shadowed(im, print_(f"{SRC}/cine500t__cine500t_1.jpg", 1160).rotate(1.5, expand=True, fillcolor=PAPER), (70, 520))
shadowed(im, print_(f"{SRC}/cine500t__cine500t_4.jpg", 1160).rotate(-1.5, expand=True, fillcolor=PAPER), (80, 1400))
roll_label(im, "cine500t", "Cine 500T", 120, 2330)
shots.append(im)
# 5 · summer on Golden 200 and Chroma 64
im = canvas(); headline(im, 5)
shadowed(im, print_(f"{SRC}/gold200__gold200_1.jpg", 1160).rotate(-1.5, expand=True, fillcolor=PAPER), (70, 520))
shadowed(im, print_(f"{SRC}/kodachrome64__kodachrome64_1.jpg", 1160).rotate(1.5, expand=True, fillcolor=PAPER), (80, 1400))
roll_label(im, "kodachrome64", "Chroma 64", 120, 2330)
shots.append(im)
# 6 · the letter
im = canvas(); headline(im, 6)
shadowed(im, fit(Image.open(f"{SRC}/letter.jpg"), 1120), (100, 560), radius=8)
shots.append(im)
# 7 · the photo book
im = canvas(); headline(im, 7)
book = Image.open(f"{SRC}/book.png").convert("RGB")
shadowed(im, fit(book, 1240), (40, 560), radius=70)
shadowed(im, fit(book.crop((0, 0, book.width // 2, book.height)), 820), (250, 1500), radius=50)
shots.append(im)
# 8 · private
im = canvas(); headline(im, 8)
body = fit(rotated_screen(f"{SRC}/outer.png"), 1000)
shadowed(im, body, (160, 900), radius=50)
d = ImageDraw.Draw(im)
for i, t in enumerate(["No account", "No uploads", "No tracking"] if not lang.startswith("zh") else ["不用账号", "不上传", "不追踪"]):
    d.text((W / 2, 1720 + i * 150), t, font=font(76, True), fill=INK, anchor="mm")
shots.append(im)

import os
os.makedirs(out, exist_ok=True)
for i, im in enumerate(shots, 1):
    im.save(f"{out}/{i}_{lang}.png")
    small = im.resize((440, 956), Image.LANCZOS); small.save(f"{out}/{i}_{lang}_s.jpg", quality=85)
print("ok", len(shots))
