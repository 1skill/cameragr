#!/usr/bin/env python3
"""Shadow and grain variants with Spectral Film LUT (diagnostic sheets).

Grain follows raw2film's pipeline (same author, MIT): simulate the negative,
add density-dependent grain from the stock's RMS data on the negative, then print.

Usage (inside lut-test/venv-sfl):
    python tools/sfl_variants.py OUT_DIR PHOTO NEG PRINT
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

import spectral_film_lut as sfl
from spectral_film_lut.film_spectral import FilmSpectral
from spectral_film_lut.grain_generation import generate_grain
from spectral_film_lut.utils import film_conversion

OUT = dict(output_gamut="Rec. 709", gamma_func="sRGB")


def stock(name):
    if name in (None, "None"):
        return None
    f = FilmSpectral(next(s for s in sfl.FILM_STOCKS if s.name == name))
    f.set_color_checker()
    return f


def render(arr, neg, pr, grain=False, grain_size_mm=0.01, grain_sigma=0.4,
           frame_mm=36.0, **kw):
    """Full pipeline; `kw` are film_conversion parameters (exp_comp, shadow_comp, ...)."""
    neg_kw = {k: kw[k] for k in ("exp_comp", "push_pull") if k in kw}
    out_kw = {k: kw[k] for k in ("shadow_comp", "sat_adjust") if k in kw}
    if not grain:
        res = film_conversion(arr, neg, pr, input_colorspace="sRGB", **neg_kw, **out_kw, **OUT)
    else:
        dens = film_conversion(arr, neg, None, mode="negative", input_colorspace="sRGB",
                               adx_coding=False, **neg_kw)
        scale = max(arr.shape[:2]) / frame_mm  # pixels per mm of film
        g = generate_grain(dens.shape, scale, grain_size_mm, False, cached=False,
                           grain_sigma=grain_sigma)
        dens = np.clip(dens + g * neg.grain_transform(dens, scale, adx=False), 0, None)
        res = film_conversion(np.ascontiguousarray(dens, dtype=np.float32), neg, pr,
                              mode="print", adx_coding=False, **out_kw, **OUT)
    res = np.clip(np.nan_to_num(res), 0, 1)
    if res.shape[-1] == 1:
        res = np.repeat(res, 3, axis=-1)
    return Image.fromarray((res * 255 + 0.5).astype(np.uint8))


VARIANTS = [
    ("default", {}),
    ("shadow_comp 0.5", dict(shadow_comp=0.5)),
    ("shadow_comp 1.0", dict(shadow_comp=1.0)),
    ("exp +0.5", dict(exp_comp=0.5)),
    ("pull -1", dict(push_pull=-1.0)),
    ("pull -1 + exp +0.5", dict(push_pull=-1.0, exp_comp=0.5)),
    ("grain (default)", dict(grain=True)),
    ("grain + shadow_comp 0.5", dict(grain=True, shadow_comp=0.5)),
]


def main():
    out, photo, neg_name, pr_name = sys.argv[1:5]
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    src = ImageOps.exif_transpose(Image.open(photo)).convert("RGB")
    src.thumbnail((1600, 1600), Image.LANCZOS)
    arr = np.asarray(src, dtype=np.float32) / 255.0
    neg, pr = stock(neg_name), stock(pr_name)
    stem = Path(photo).stem
    src.save(out / f"{stem}__original.png")
    for label, kw in VARIANTS:
        try:
            im = render(arr, neg, pr, **kw)
        except Exception as e:
            print("FAIL", label, type(e).__name__, e)
            continue
        slug = label.replace(" ", "_").replace("+", "p").replace("(", "").replace(")", "")
        im.save(out / f"{stem}__{slug}.png")
        a = np.asarray(im, dtype=np.float32) / 255
        L = a @ np.array([0.2126, 0.7152, 0.0722], np.float32)
        print(f"{label:26s} mean={L.mean():.3f}  <3%={100*(L<0.03).mean():5.1f}%  >97%={100*(L>0.97).mean():5.1f}%")


if __name__ == "__main__":
    main()
