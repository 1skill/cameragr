"""Composes App Store screenshots for the iPhone Duo slots (outer 2034x1398,
inner 2853x2007, landscape): a real capture of the screen, shrunk onto a warm
dark ground with its own rounded corners, and a headline + one line beside it.
  appstore_duo.py <outer|inner> <capture.png> <out.png> "<headline>" "<line>"
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

kind, src, out, head, line = sys.argv[1:6]
bgfile = sys.argv[6] if len(sys.argv) > 6 else None
W, H = (2034, 1398) if kind == "outer" else (2853, 2007)
u = W / 2034
if bgfile:
    # A GPT still life, covering the canvas, dimmed a little so the headline reads.
    src_bg = Image.open(bgfile).convert("RGB")
    k = max(W / src_bg.width, H / src_bg.height)
    src_bg = src_bg.resize((int(src_bg.width * k + 1), int(src_bg.height * k + 1)), Image.LANCZOS)
    left, top = (src_bg.width - W) // 2, (src_bg.height - H) // 2
    bg = src_bg.crop((left, top, left + W, top + H))
    bg = Image.blend(bg, Image.new("RGB", (W, H), (12, 8, 6)), 0.38)
else:
    bg = Image.new("RGB", (W, H))
    dd = ImageDraw.Draw(bg)
    for y in range(H):  # warm charcoal, lighter at the top
        t = y / H
        dd.line([(0, y), (W, y)], fill=(int(46 - 22 * t), int(40 - 19 * t), int(34 - 17 * t)))
d = ImageDraw.Draw(bg)
font = "/System/Library/Fonts/Hiragino Sans GB.ttc"
f_head = ImageFont.truetype(font, int(92 * u), index=1)
f_line = ImageFont.truetype(font, int(44 * u), index=0)
d.text((int(110 * u), int(92 * u)), head, font=f_head, fill=(246, 238, 222))
d.text((int(114 * u), int(92 * u) + int(128 * u)), line, font=f_line, fill=(196, 182, 160))

cap = Image.open(src).convert("RGB")
scale = 0.72
cw, ch = int(cap.width * scale * W / cap.width), int(cap.height * scale * W / cap.width)
cap = cap.resize((cw, ch), Image.LANCZOS)
# the screen's own corners: outer 59 pt on the top, 8 pt below; inner 55 pt all round
r_top = int((59 if kind == "outer" else 55) * 3 * cw / (W))
r_bot = int((8 if kind == "outer" else 55) * 3 * cw / (W))
mask = Image.new("L", (cw, ch), 0)
m = ImageDraw.Draw(mask)
m.rounded_rectangle([0, 0, cw - 1, ch - 1], radius=r_top, fill=255)
if r_bot < r_top:
    m.rectangle([0, ch - r_top, cw - 1, ch - 1], fill=255)
    for x0 in (0, cw - 2 * r_bot - 1):  # small bottom corners
        pass
    m.rectangle([0, ch - r_top, cw, ch], fill=255)
    m2 = Image.new("L", (cw, ch), 0); ImageDraw.Draw(m2).rounded_rectangle([0, ch - 4 * r_top, cw - 1, ch - 1], radius=r_bot, fill=255)
    top = Image.new("L", (cw, ch), 0); ImageDraw.Draw(top).rounded_rectangle([0, 0, cw - 1, ch - 1], radius=r_top, fill=255)
    lower = Image.new("L", (cw, ch), 0); ImageDraw.Draw(lower).rectangle([0, ch // 2, cw, ch], fill=255)
    mask = Image.composite(m2, top, lower)
x, y = (W - cw) // 2, H - ch - int(48 * u)
shadow = Image.new("L", (W, H), 0)
shadow.paste(mask, (x, y + int(24 * u)))
shadow = shadow.filter(ImageFilter.GaussianBlur(40 * u))
bg.paste(Image.new("RGB", (W, H), (0, 0, 0)), (0, 0), shadow.point(lambda v: int(v * 0.75)))
bg.paste(cap, (x, y), mask)
bg.save(out)
print(out, bg.size)
