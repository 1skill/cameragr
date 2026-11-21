"""Prototype of Spectral Film LUT's own grain workflow, to port to the app.

As documented by the library (docs/2_usage.md, "Resolve node tree"):
  photo -> negative LUT -> + (grain overlay - 0.5) x grain LUT(negative) -> print LUT
The grain overlay depends only on frame size and pixel count (36 mm frame,
6 um grains by default); the grain LUT carries the stock's datasheet RMS
granularity against density. All three LUTs share one ADX scaling.

    python tools/grain_proto.py <photo> <negative stock> <print stock|None> <out.jpg> [width_px]
"""
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates
import spectral_film_lut as sfl
from spectral_film_lut.film_spectral import FilmSpectral
from spectral_film_lut.utils import film_conversion
from spectral_film_lut.grain_generation import generate_grain

ADX = 2.0      # "Density 4"
N = 33
FRAME_MM = 36.0
GRAIN_MM = 0.006

def stock(name):
    if name in (None, 'None'): return None
    f = FilmSpectral(next(s for s in sfl.FILM_STOCKS if s.name == name)); f.set_color_checker(); return f

def grid():
    g = np.linspace(0, 1, N, dtype=np.float32); b, gg, r = np.meshgrid(g, g, g, indexing='ij')
    return np.stack([r, gg, b], -1)

def apply(lut, x):
    n = lut.shape[0]; c = [x[..., 2] * (n - 1), x[..., 1] * (n - 1), x[..., 0] * (n - 1)]
    return np.stack([map_coordinates(lut[..., k], c, order=1, mode='nearest') for k in range(lut.shape[-1])], -1)

def luts(neg, pr):
    n, p = stock(neg), stock(pr); G = grid()
    common = dict(input_colorspace='sRGB', output_gamut='Rec. 709', gamma_func='sRGB', adx_scaling=ADX)
    full = np.clip(np.nan_to_num(film_conversion(G, n, p, **common)), 0, 1)
    negl = np.clip(np.nan_to_num(film_conversion(G, n, p, mode='negative', **common)), 0, 1)
    prl = np.clip(np.nan_to_num(film_conversion(G, n, p, mode='print', **common)), 0, 1)
    grl = np.nan_to_num(film_conversion(G, n, p, mode='grain', **common))
    fix = lambda a: np.repeat(a, 3, -1) if a.shape[-1] == 1 else a
    return fix(full), fix(negl), fix(prl), fix(grl)

def render(x, full, negl, prl, grl, grain=True, seed=0):
    H, W = x.shape[:2]; scale = W / FRAME_MM                 # pixels per mm on the film
    neg = apply(negl, x)
    if grain:
        np.random.seed(seed)
        noise = generate_grain((H, W, 3), scale, grain_size_mm=GRAIN_MM)
        overlay = np.clip(noise * scale * 0.001 + 0.5, 0, 1)  # as generate_grain_frame, before 8-bit
        neg = np.clip(neg + (overlay - 0.5) * apply(grl, neg), 0, 1)
    return apply(prl, neg)

if __name__ == '__main__':
    photo, neg, pr, out = sys.argv[1:5]; w = int(sys.argv[5]) if len(sys.argv) > 5 else 3000
    im = Image.open(photo).convert('RGB'); im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    x = np.asarray(im).astype(np.float32) / 255
    full, negl, prl, grl = luts(neg, pr)
    y0 = apply(full, x); y1 = render(x, full, negl, prl, grl, grain=False); y2 = render(x, full, negl, prl, grl, grain=True)
    print('negative+print vs full, mean abs diff (0-255): %.2f' % (np.abs(y1 - y0).mean() * 255))
    print('grain std added (0-255): %.2f' % ((y2 - y1).std() * 255))
    Image.fromarray((np.clip(y2, 0, 1) * 255).round().astype(np.uint8)).save(out, quality=95)
    np.save(out + '.nograin.npy', y1.astype(np.float16))
