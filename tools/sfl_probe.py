"""List Spectral Film LUT stocks and time one conversion (diagnostic)."""
import sys, time
import numpy as np
from PIL import Image
import spectral_film_lut as sfl
from spectral_film_lut.film_spectral import FilmSpectral
from spectral_film_lut.utils import film_conversion

stocks = sfl.FILM_STOCKS
print(len(stocks), "stocks")
for s in stocks:
    print(" ", getattr(s, "stage", "?"), "|", getattr(s, "type", "?"), "|", s.name)

by = {s.name: s for s in stocks}
t = time.time()
neg = FilmSpectral(by[sys.argv[2]]); neg.set_color_checker()
pr = FilmSpectral(by[sys.argv[3]]); pr.set_color_checker()
print("load", round(time.time() - t, 1), "s")
im = Image.open(sys.argv[1]).convert("RGB"); im.thumbnail((1200, 1200))
a = np.asarray(im, dtype=np.float32) / 255
t = time.time()
out = film_conversion(a, neg, pr, input_colorspace="sRGB", output_gamut="Rec. 709", gamma_func="sRGB")
print("convert", round(time.time() - t, 1), "s", out.shape, out.dtype, float(out.min()), float(out.max()), float(out.mean()))
Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(sys.argv[4], quality=93)
