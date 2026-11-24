"""Fills the empty club page (GPT art, design/community/community_empty_<lang>.png)
with real-looking member photos: rainy-day pictures (GPT, each its own shot)
each rendered through a different Koco film (design/community/rain), placed
into the sleeve pockets behind the plastic's shine, and their kraft labels
written (who · film · likes). Compositing only.

    lut-test/venv-sfl/bin/python tools/club_fill.py <zh|en> <out.png>
"""
import sys, os, numpy as np
from PIL import Image, ImageDraw, ImageFont
lang, out = sys.argv[1], sys.argv[2]
base = Image.open(f"design/community/community_empty_{lang}.png").convert("RGB")
W0, H0 = base.size; k = W0 / 1495
cols = [(540, 828), (840, 1133), (1145, 1452)]
rows = [(36, 96, None), (110, 300, 300), (348, 538, 538), (588, 780, 780), (828, 965, 965)]
labels_x = [(560, 810), (866, 1112), (1176, 1437)]
films = {"portra400": "Porto 400", "trix400": "Tri-Ax 400", "cine500t": "Cine 500T", "instax": "Instant 800",
         "ccd": "CCD 100", "kodachrome64": "Chroma 64", "gold200": "Golden 200", "fp100c": "Peel 100C",
         "natura1600": "Nature 1600", "doublex": "Double-X", "velvia50": "Velva 50", "grneg": "Grit Neg"}
names_zh = ["小川", "Lena", "竹子", "阿木", "Momo", "老陈", "琦", "青山", "Kai", "小鱼", "Ren", "我"]
names_en = ["Ogawa", "Lena", "Zhuzi", "Amu", "Momo", "Chen", "Qi", "Aoyama", "Kai", "Xiaoyu", "Ren", "Me"]
likes = [215, 362, 97, 184, 289, 301, 76, 119, 58, 143, 231, 268]
photos = sorted(os.listdir("design/community/rain"))
order = [0, 4, 2, 7, 6, 3, 9, 1, 5, 11, 10, 8]   # spread the looks out
arr = np.asarray(base).astype(np.float32)
img = base.copy()
d = ImageDraw.Draw(img)
fz = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", round(15 * k), index=0)
fl = ImageFont.truetype("/System/Library/Fonts/Supplemental/Georgia Italic.ttf", round(15 * k)) if os.path.exists("/System/Library/Fonts/Supplemental/Georgia Italic.ttf") else fz
fh = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", round(15 * k))
n = 0
for ri, (y0, y1, ly) in enumerate(rows):
    for ci, (x0, x1) in enumerate(cols):
        f = photos[order[n % len(photos)]]; fid = f[3:-4]
        box = (round((x0 + 4) * k), round((y0 + 4) * k), round((x1 - 4) * k), round((y1 - 2) * k))
        bw, bh = box[2] - box[0], box[3] - box[1]
        ph = Image.open(f"design/community/rain/{f}").convert("RGB")
        s = max(bw / ph.width, bh / ph.height)
        ph = ph.resize((round(ph.width * s), round(ph.height * s)), Image.LANCZOS)
        ph = ph.crop(((ph.width - bw) // 2, (ph.height - bh) // 2, (ph.width - bw) // 2 + bw, (ph.height - bh) // 2 + bh))
        # The plastic's shine over it: what is brighter than the empty pocket's dark.
        pocket = arr[box[1]:box[3], box[0]:box[2]]
        lum = pocket.mean(-1, keepdims=True)
        shine = np.clip(lum - np.median(lum), 0, None) * 0.9
        p = np.asarray(ph).astype(np.float32) * 0.93 + shine
        img.paste(Image.fromarray(np.clip(p, 0, 255).astype("uint8")), box[:2])
        if ly is not None:
            lx0, lx1 = labels_x[ci]
            who = (names_zh if lang == "zh" else names_en)[n % 12]
            text = f"{who} · {films[fid]}"
            cy = round((ly + 16) * k)
            d.text((round((lx0 + 12) * k), cy), text, font=fz if lang == "zh" else fl, fill=(60, 38, 22), anchor="lm")
            num = str(likes[n % 12])
            d.text((round((lx1 - 12) * k), cy), num, font=fz, fill=(170, 30, 25), anchor="rm")
            nw = d.textlength(num, font=fz)
            d.text((round((lx1 - 12) * k - nw - 4 * k), cy), "♥", font=fh, fill=(170, 30, 25), anchor="rm")
        n += 1
img.save(out)
print("ok", out)
