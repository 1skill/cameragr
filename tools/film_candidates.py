#!/usr/bin/env python3
"""3.4 — new-film candidates. Renders candidate stocks from Spectral Film LUT
on a few sample photos, and measures how far each looks from the films the
app already has (mean CIE ΔE2000-ish via CIE76 in Lab, per pixel, averaged),
so the shortlist favours looks that are really new.

    lut-test/venv-sfl/bin/python tools/film_candidates.py lut-test/candidates
"""
import json, sys, time
from pathlib import Path
import numpy as np
from PIL import Image
import spectral_film_lut as sfl
from spectral_film_lut.film_spectral import FilmSpectral
from spectral_film_lut.utils import film_conversion

out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
root = Path(__file__).resolve().parents[1]
SAMPLES = ["portra400_1", "gold200_1", "kodachrome64_1", "cine500t_1"]   # portrait, family, colour, night
NEG_PAPER = "Kodak Portra Endura Paper"
EXISTING = [("portra400", "Kodak Portra 400", NEG_PAPER), ("gold200", "Kodak Gold 200", NEG_PAPER),
            ("c200", "Fuji C200", "Fujiflex Crystal Archive New Version"),
            ("cine500t", "Kodak Vision3 500T 5219", "Kodak Vision 2383"), ("kodachrome64", "Kodachrome 64", None),
            ("trix400", "Kodak Tri-X 400", "Kodak Professional Polymax Fine-Art Paper"), ("instax", "Fuji Instax color", None)]
CANDIDATES = [
    ("pro400h", "Fuji Pro 400H", "Fujiflex Crystal Archive New Version", "pastel, airy skin; a discontinued favourite"),
    ("ektar100", "Kodak Ektar 100", NEG_PAPER, "saturated, fine-grained landscape negative"),
    ("velvia50", "Fuji Velvia 50", None, "the most vivid slide film: deep blues, hot greens"),
    ("superia400", "Fuji Superia X-Tra 400", "Fujiflex Crystal Archive New Version", "consumer negative with a green cast, very 2000s Japan"),
    ("natura1600", "Fuji Natura 1600", "Fujiflex Crystal Archive New Version", "cult fast film for available light at night"),
    ("vista100", "Agfa Vista 100", NEG_PAPER, "cheap warm drugstore film, reds pop"),
    ("ultramax400", "Kodak Ultramax 400", NEG_PAPER, "everyday consumer Kodak, warmer and grainier than Gold"),
    ("aerochrome", "Kodak Aerochrome III Infrared Film 1443", None, "infrared: green foliage turns red/pink"),
    ("fp100c", "Fuji FP-100C", None, "peel-apart instant: soft, cyan-leaning"),
    ("double_x", "Kodak 5222", "Kodak 2302", "Double-X cinema black and white"),
    ("ektachrome", "Kodak Ektachrome 100D", None, "clean, neutral modern slide film"),
]
by = {}
for s in sfl.FILM_STOCKS: by.setdefault(s.name, s)
cache = {}
def spectral(name):
    if name not in cache:
        f = FilmSpectral(by[name]); f.set_color_checker(); cache[name] = f
    return cache[name]

imgs = {}
for n in SAMPLES:
    im = Image.open(root / f"cameragr/Resources/Samples/{n}.jpg").convert("RGB"); im.thumbnail((640, 640))
    imgs[n] = np.asarray(im, dtype=np.float32) / 255
def render(neg, paper):
    return {n: np.clip(film_conversion(a, spectral(neg), spectral(paper) if paper else None,
                                       input_colorspace="sRGB", output_gamut="Rec. 709", gamma_func="sRGB"), 0, 1)
            for n, a in imgs.items()}

def lab(rgb):   # sRGB -> CIE Lab (D65)
    c = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)
def de(a, b): return float(np.mean([np.linalg.norm(lab(a[n]) - lab(b[n]), axis=-1).mean() for n in SAMPLES]))

t = time.time()
have = {fid: render(neg, paper) for fid, neg, paper in EXISTING}
print("existing rendered", round(time.time() - t), "s", flush=True)
rows = []
for cid, neg, paper, note in CANDIDATES:
    try:
        r = render(neg, paper)
    except Exception as e:
        print("skip", cid, e); continue
    dist = {fid: de(r, h) for fid, h in have.items()}
    near = min(dist, key=dist.get)
    rows.append({"id": cid, "stock": neg, "print": paper, "note": note, "nearest": near, "deltaE": round(dist[near], 1)})
    for n in SAMPLES:
        Image.fromarray((r[n] * 255 + 0.5).astype(np.uint8)).save(out / f"{cid}_{n}.jpg", quality=90)
    print(cid, "nearest", near, round(dist[near], 1), flush=True)
for n, a in imgs.items():
    Image.fromarray((a * 255 + 0.5).astype(np.uint8)).save(out / f"original_{n}.jpg", quality=90)
rows.sort(key=lambda r: -r["deltaE"])
json.dump(rows, open(out / "candidates.json", "w"), indent=2, ensure_ascii=False)
print(json.dumps(rows, ensure_ascii=False, indent=1))
