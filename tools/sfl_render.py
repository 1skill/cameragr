#!/usr/bin/env python3
"""Render test photos through Spectral Film LUT (MIT, github.com/JanLohse/spectral_film_lut).

Each look is a negative (or reversal) stock, optionally printed on a print stock,
simulated from the manufacturers' datasheets. All parameters are the tool's
defaults; nothing is tuned here.

Usage (inside lut-test/venv-sfl):
    python tools/sfl_render.py OUT_DIR PHOTO [PHOTO ...] [--only "Portra 400"]
"""
import argparse
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps

import spectral_film_lut as sfl
from spectral_film_lut.film_spectral import FilmSpectral
from spectral_film_lut.utils import film_conversion

# label, camera stock, print stock (None = reversal film viewed directly)
LOOKS = [
    ("Portra 400", "Kodak Portra 400", "Kodak Portra Endura Paper"),
    ("Portra 800", "Kodak Portra 800", "Kodak Portra Endura Paper"),
    ("Ektar 100", "Kodak Ektar 100", "Kodak Portra Endura Paper"),
    ("Gold 200", "Kodak Gold 200", "Kodak Portra Endura Paper"),
    ("Ultramax 400", "Kodak Ultramax 400", "Kodak Portra Endura Paper"),
    ("Fuji Pro 400H", "Fuji Pro 400H", "Fujiflex Crystal Archive New Version"),
    ("Fuji Superia 400", "Fuji Superia X-Tra 400", "Fujiflex Crystal Archive New Version"),
    ("Fuji C200", "Fuji C200", "Fujiflex Crystal Archive New Version"),
    ("Cine 500T + 2383", "Kodak Vision3 500T 5219", "Kodak Vision 2383"),
    ("Cine 250D + 2383", "Kodak Vision3 250D 5207", "Kodak Vision 2383"),
    ("Velvia 50", "Fuji Velvia 50", None),
    ("Provia 100F", "Fuji Provia 100F", None),
    ("Kodachrome 64", "Kodachrome 64", None),
    ("Ektachrome 100D", "Kodak Ektachrome 100D", None),
    ("Instax", "Fuji Instax color", None),
    ("Tri-X 400", "Kodak Tri-X 400", "Kodak Professional Polymax Fine-Art Paper"),
]

_cache = {}


def stock(name):
    if name is None:
        return None
    if name not in _cache:
        data = next(s for s in sfl.FILM_STOCKS if s.name == name)
        f = FilmSpectral(data)
        f.set_color_checker()
        _cache[name] = f
    return _cache[name]


def labelled(im, text):
    w, h = im.size
    c = Image.new("RGB", (w, h + 110), (15, 15, 15))
    c.paste(im, (0, 0))
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 60)
    ImageDraw.Draw(c).text((28, h + 22), text, fill=(245, 245, 245), font=font)
    return c


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out_dir")
    ap.add_argument("photos", nargs="+")
    ap.add_argument("--only", action="append")
    ap.add_argument("--long-edge", type=int, default=1600)
    a = ap.parse_args()

    looks = [l for l in LOOKS if not a.only or l[0] in a.only]
    for photo in a.photos:
        name = Path(photo).stem
        out = Path(a.out_dir) / name
        out.mkdir(parents=True, exist_ok=True)
        src = ImageOps.exif_transpose(Image.open(photo)).convert("RGB")
        src.thumbnail((a.long_edge, a.long_edge), Image.LANCZOS)
        arr = np.asarray(src, dtype=np.float32) / 255.0
        labelled(src, "00 Original (no filter)").save(out / "00_original.jpg", quality=93)
        src.save(out / "raw_00_original.png")
        for i, (label, neg, pr) in enumerate(looks, 1):
            t = time.time()
            try:
                res = film_conversion(
                    arr, stock(neg), stock(pr),
                    input_colorspace="sRGB", output_gamut="Rec. 709", gamma_func="sRGB",
                )
            except Exception as e:  # keep going; report which look failed
                print(f"FAIL {name} {label}: {type(e).__name__}: {e}")
                continue
            res = np.clip(np.nan_to_num(res), 0, 1)
            if res.shape[-1] == 1:
                res = np.repeat(res, 3, axis=-1)
            im = Image.fromarray((res * 255 + 0.5).astype(np.uint8))
            slug = label.lower().replace(" ", "_").replace("+", "").replace("__", "_")
            im.save(out / f"raw_{slug}.png")
            labelled(im, f"{i:02d} {label}").save(out / f"{i:02d}_{slug}.jpg", quality=93)
            print(f"{name} {label}: {time.time() - t:.1f}s mean={res.mean():.3f}")


if __name__ == "__main__":
    main()
