"""Fit Koco's own colour model to a reference look, then bake it to a LUT.

The reference (a LUT we may not ship) is only applied to sample photos to
make target pictures. Our model starts from "no change" and its ~75
parameters are optimised until its output matches those pictures:
  3x3 matrix + offset -> per-channel tone curves (11 knots each)
  -> 8 hue bands (hue shift, saturation, value) -> shadow/highlight tint.
The baked LUT is computed from the model alone.

    python tools/fit_look.py <reference_haldclut.png> <photos dir> <out dir> [val names...]
"""
import sys, glob, os, json
import numpy as np
from PIL import Image
from scipy.optimize import least_squares
from scipy.interpolate import PchipInterpolator
from scipy.ndimage import map_coordinates

def load_hald(path):
    a = np.asarray(Image.open(path)).astype(np.float64)
    a = a / (65535.0 if a.max() > 255 else 255.0)
    w = a.shape[0]; level = round(w ** (1 / 3)); n = level * level
    return a.reshape(n, n, n, 3)  # [b, g, r]

def apply_lut(lut, rgb):
    n = lut.shape[0]
    c = [rgb[..., 2] * (n - 1), rgb[..., 1] * (n - 1), rgb[..., 0] * (n - 1)]
    return np.stack([map_coordinates(lut[..., k], c, order=1, mode='nearest') for k in range(3)], -1)

def lab(rgb):
    rgb = np.clip(rgb, 0, 1)
    a = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = a @ M.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

K = 11; KX = np.linspace(0, 1, K); BANDS = 8
NP = 12 + 3 * K + 3 * BANDS + 6

def init_params():
    p = np.zeros(NP); p[:9] = np.eye(3).ravel(); p[12:12 + 3 * K] = np.tile(KX, 3); return p

def unpack(p):
    M = p[:9].reshape(3, 3); off = p[9:12]
    curves = p[12:12 + 3 * K].reshape(3, K)
    o = 12 + 3 * K
    dh, ds, dv = p[o:o + BANDS], p[o + BANDS:o + 2 * BANDS], p[o + 2 * BANDS:o + 3 * BANDS]
    tint = p[o + 3 * BANDS:].reshape(2, 3)
    return M, off, curves, dh, ds, dv, tint

def rgb2hsv(x):
    mx = x.max(-1); mn = x.min(-1); d = mx - mn + 1e-9
    r, g, b = x[..., 0], x[..., 1], x[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    s = np.where(mx > 0, (mx - mn) / (mx + 1e-9), 0); return h, s, mx

def hsv2rgb(h, s, v):
    h6 = (h % 1) * 6; i = np.floor(h6); f = h6 - i
    p_ = v * (1 - s); q = v * (1 - s * f); t = v * (1 - s * (1 - f)); i = i.astype(int) % 6
    r = np.choose(i, [v, q, p_, p_, t, v]); g = np.choose(i, [t, v, v, q, p_, p_]); b = np.choose(i, [p_, p_, t, v, v, q])
    return np.stack([r, g, b], -1)

def model(p, x, smooth=False):
    M, off, curves, dh, ds, dv, tint = unpack(p)
    y = x @ M.T + off
    y = np.clip(y, 0, 1)
    out = []
    for c in range(3):
        if smooth:
            out.append(PchipInterpolator(KX, np.maximum.accumulate(curves[c]))(y[..., c]))
        else:
            out.append(np.interp(y[..., c], KX, curves[c]))
    y = np.clip(np.stack(out, -1), 0, 1)
    h, s, v = rgb2hsv(y)
    centres = np.arange(BANDS) / BANDS
    dist = np.abs(((h[..., None] - centres) + 0.5) % 1 - 0.5) * BANDS
    w = np.clip(1 - dist, 0, 1) * s[..., None]          # bands matter only where there is colour
    h = h + (w * dh).sum(-1) * 0.1
    s = np.clip(s * np.exp((w * ds).sum(-1)), 0, 1)
    v = np.clip(v * np.exp((w * dv).sum(-1) * 0.5), 0, 1)
    y = hsv2rgb(h, s, v)
    L = y.mean(-1, keepdims=True)
    y = y + (1 - L) ** 2 * tint[0] * 0.2 + L ** 2 * tint[1] * 0.2
    return np.clip(y, 0, 1)

def main():
    ref, photos, out = sys.argv[1], sys.argv[2], sys.argv[3]; val = set(sys.argv[4:])
    os.makedirs(out, exist_ok=True)
    lut = load_hald(ref)
    rng = np.random.default_rng(0)
    train_x, train_y, sets = [], [], {}
    for f in sorted(glob.glob(photos + '/*.jpg')):
        im = Image.open(f).convert('RGB'); im.thumbnail((512, 512))
        x = np.asarray(im).astype(np.float64) / 255; t = apply_lut(lut, x)
        sets[os.path.basename(f)] = (x, t)
        if os.path.basename(f) not in val:
            idx = rng.choice(x.shape[0] * x.shape[1], 3000, replace=False)
            train_x.append(x.reshape(-1, 3)[idx]); train_y.append(t.reshape(-1, 3)[idx])
    X = np.concatenate(train_x); Y = lab(np.concatenate(train_y))
    reg_w = 0.05
    o = 12 + 3 * K
    ident = np.tile(KX, 3)
    def resid(p):
        r = (lab(model(p, X)) - Y).ravel()
        # Weak pulls toward "no change": keeps knots that no pixel reaches,
        # and hue bands with no data, where they started.
        return np.concatenate([r, reg_w * p[o:o + 3 * BANDS] * 10, 2.0 * (p[12:o] - ident)])
    p0 = init_params()
    lo = np.full(NP, -np.inf); hi = np.full(NP, np.inf)
    lo[12:o] = -0.2; hi[12:o] = 1.2
    lo[o:o + 3 * BANDS] = -2; hi[o:o + 3 * BANDS] = 2
    res = least_squares(resid, p0, method='trf', max_nfev=4000, x_scale='jac', bounds=(lo, hi))
    p = res.x
    report = {}
    for name, (x, t) in sets.items():
        y0 = model(p0, x); y = model(p, x, smooth=True)
        report[name] = {'val': name in val,
                        'dE_before': float(np.sqrt(((lab(y0) - lab(t)) ** 2).sum(-1)).mean()),
                        'dE_after': float(np.sqrt(((lab(y) - lab(t)) ** 2).sum(-1)).mean())}
        Image.fromarray((np.concatenate([x, t, y], 0) * 255).round().astype(np.uint8)).save(f'{out}/{name[:-4]}_cmp.jpg', quality=90)
    np.save(f'{out}/params.npy', p)
    # bake our model alone into a 33^3 cube, [b, g, r] order like the app's LUTs
    N = 33; g = np.linspace(0, 1, N); b_, g_, r_ = np.meshgrid(g, g, g, indexing='ij')
    cube = model(p, np.stack([r_, g_, b_], -1), smooth=True)
    np.save(f'{out}/cube33.npy', cube.astype(np.float32))
    json.dump(report, open(f'{out}/report.json', 'w'), indent=1)
    for n, r in report.items():
        print(f"{n:22s} {'VAL ' if r['val'] else 'fit '} before {r['dE_before']:5.2f}  after {r['dE_after']:5.2f}")
    print('cost', res.cost, 'nfev', res.nfev)

if __name__ == '__main__':
    main()
