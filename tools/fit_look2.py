"""Fit Koco's own colour model to a reference look (v2), then bake a LUT.

The reference (a LUT we may not ship) is only applied, locally, to sample
photos and to a colour chart (a dense grid of patches spanning sRGB, as used
to profile a camera's colours) to make target pictures. Our model starts
from "no change"; its parameters are optimised to match those pictures:
  3x3 matrix + offset -> per-channel tone curves (11 knots)
  -> saturation curve (6 knots) -> 16 hue bands x 2 lightness tiers
     (hue shift, saturation, value) -> shadow/highlight tint.
Checked on photos left out of the fit and on every colour of a 33^3 grid.

    python tools/fit_look2.py <reference_haldclut.png> <photos dir> <out dir> [val names...]
"""
import sys, glob, os, json
import numpy as np
from PIL import Image
from scipy.optimize import least_squares
from scipy.interpolate import PchipInterpolator
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fit_look import load_hald, apply_lut, lab, rgb2hsv, hsv2rgb

K = 11; KX = np.linspace(0, 1, K)
SK = 6; SX = np.linspace(0, 1, SK)
B = 16; T = 2
NB = 3 * B * T
NP = 12 + 3 * K + SK + NB + 6
O_C = 12; O_S = O_C + 3 * K; O_B = O_S + SK; O_T = O_B + NB

def init_params():
    p = np.zeros(NP); p[:9] = np.eye(3).ravel()
    p[O_C:O_S] = np.tile(KX, 3); p[O_S:O_B] = SX; return p

def model(p, x, smooth=False):
    M = p[:9].reshape(3, 3); off = p[9:12]
    curves = p[O_C:O_S].reshape(3, K); sc = p[O_S:O_B]
    bands = p[O_B:O_T].reshape(3, T, B); tint = p[O_T:].reshape(2, 3)
    y = np.clip(x @ M.T + off, 0, 1)
    interp = (lambda xs, ys, v: PchipInterpolator(xs, np.maximum.accumulate(ys))(v)) if smooth else (lambda xs, ys, v: np.interp(v, xs, ys))
    y = np.clip(np.stack([interp(KX, curves[c], y[..., c]) for c in range(3)], -1), 0, 1)
    h, s, v = rgb2hsv(y)
    s = np.clip(interp(SX, sc, s), 0, 1)
    dist = np.abs(((h[..., None] - np.arange(B) / B) + 0.5) % 1 - 0.5) * B
    wh = np.clip(1 - dist, 0, 1) * s[..., None]                     # [..., B]
    wl = np.stack([1 - v, v], -1)                                   # [..., T] dark / light tier
    w = wl[..., :, None] * wh[..., None, :]                          # [..., T, B]
    h = h + (w * bands[0]).sum((-1, -2)) * 0.1
    s = np.clip(s * np.exp((w * bands[1]).sum((-1, -2))), 0, 1)
    v = np.clip(v * np.exp((w * bands[2]).sum((-1, -2)) * 0.5), 0, 1)
    y = hsv2rgb(h, s, v)
    L = y.mean(-1, keepdims=True)
    return np.clip(y + (1 - L) ** 2 * tint[0] * 0.2 + L ** 2 * tint[1] * 0.2, 0, 1)

def chart(n=17):
    g = np.linspace(0, 1, n); b, gg, r = np.meshgrid(g, g, g, indexing='ij')
    return np.stack([r, gg, b], -1).reshape(-1, 3)

def grid_report(p, lut):
    N = 33; g = np.linspace(0, 1, N); b, gg, r = np.meshgrid(g, g, g, indexing='ij')
    X = np.stack([r, gg, b], -1).reshape(-1, 3)
    dE = np.sqrt(((lab(model(p, X, smooth=True)) - lab(apply_lut(lut, X))) ** 2).sum(-1))
    _, s, _ = rgb2hsv(X)
    out = {'mean': dE.mean(), 'p90': np.percentile(dE, 90), 'p99': np.percentile(dE, 99)}
    for lo, hi in [(0, .2), (.2, .5), (.5, .8), (.8, 1.01)]:
        m = (s >= lo) & (s < hi); out[f's{lo}-{hi}'] = (dE[m].mean(), np.percentile(dE[m], 90))
    return out

def main():
    ref, photos, out = sys.argv[1], sys.argv[2], sys.argv[3]; val = set(sys.argv[4:])
    os.makedirs(out, exist_ok=True)
    lut = load_hald(ref); rng = np.random.default_rng(0)
    xs, ys, sets = [], [], {}
    for f in sorted(glob.glob(photos + '/*.jpg')):
        im = Image.open(f).convert('RGB'); im.thumbnail((512, 512))
        x = np.asarray(im).astype(np.float64) / 255; t = apply_lut(lut, x)
        sets[os.path.basename(f)] = (x, t)
        if os.path.basename(f) not in val:
            idx = rng.choice(x.shape[0] * x.shape[1], 3000, replace=False)
            xs.append(x.reshape(-1, 3)[idx]); ys.append(t.reshape(-1, 3)[idx])
    C = chart(17); xs.append(C); ys.append(apply_lut(lut, C))     # the colour chart
    X = np.concatenate(xs); Y = lab(np.concatenate(ys))
    ident = np.concatenate([np.tile(KX, 3), SX])
    def resid(p):
        r = (lab(model(p, X)) - Y).ravel()
        return np.concatenate([r, 0.3 * p[O_B:O_T], 2.0 * (p[O_C:O_B] - ident)])
    p0 = init_params()
    lo = np.full(NP, -np.inf); hi = np.full(NP, np.inf)
    lo[O_C:O_B] = -0.2; hi[O_C:O_B] = 1.2; lo[O_B:O_T] = -3; hi[O_B:O_T] = 3
    res = least_squares(resid, p0, method='trf', max_nfev=3000, x_scale='jac', bounds=(lo, hi))
    p = res.x; np.save(f'{out}/params.npy', p)
    rep = {}
    for name, (x, t) in sets.items():
        y = model(p, x, smooth=True)
        rep[name] = (name in val, float(np.sqrt(((lab(y) - lab(t)) ** 2).sum(-1)).mean()))
        Image.fromarray((np.concatenate([x, t, y], 0) * 255).round().astype(np.uint8)).save(f'{out}/{name[:-4]}_cmp.jpg', quality=90)
    for n, (v_, d) in rep.items(): print(f"{n:22s} {'VAL' if v_ else 'fit'} dE {d:5.2f}")
    g = grid_report(p, lut)
    print('grid: mean %.2f  90%% %.2f  99%% %.2f' % (g['mean'], g['p90'], g['p99']))
    for k, v_ in g.items():
        if k.startswith('s'): print('  sat %-9s mean %.2f  90%% %.2f' % (k[1:], v_[0], v_[1]))
    print('params', NP, 'nfev', res.nfev)

if __name__ == '__main__':
    main()
