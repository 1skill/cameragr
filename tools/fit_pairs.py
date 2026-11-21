"""Fit Koco's own colour model (the fit_look2 model) to pairs of pictures of
the same frame: a camera's neutral rendering and the look we are after.
Used when no reference LUT exists, only straight-out-of-camera JPEG pairs.

    python tools/fit_pairs.py <pairs dir with NAME_std.jpg / NAME_neg.jpg> <out dir> <look suffix> [val names...]
"""
import sys, glob, os
import numpy as np
from PIL import Image, ImageFilter
from scipy.optimize import least_squares
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fit_look import lab
import fit_look2 as M

def radius(x):
    H, W = x.shape[:2]; yy, xx = np.mgrid[0:H, 0:W]
    return np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2)) / np.sqrt(2)

def load(path, w=250):
    im = Image.open(path).convert('RGB')
    im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.7))
    return np.asarray(im).astype(np.float64) / 255

def main():
    d, out, suffix = sys.argv[1], sys.argv[2], sys.argv[3]; val = set(sys.argv[4:])
    os.makedirs(out, exist_ok=True)
    pairs = {}
    for s in sorted(glob.glob(f'{d}/*_std.jpg')):
        name = os.path.basename(s)[:-8]
        pairs[name] = (load(s), load(s.replace('_std.jpg', f'_{suffix}.jpg')))
    rng = np.random.default_rng(0); xs, ys, rs = [], [], []
    for n, (x, y) in pairs.items():
        if n in val: continue
        idx = rng.choice(x.shape[0] * x.shape[1], min(6000, x.shape[0] * x.shape[1]), replace=False)
        xs.append(x.reshape(-1, 3)[idx]); ys.append(y.reshape(-1, 3)[idx]); rs.append(radius(x).ravel()[idx])
    X = np.concatenate(xs); Y = lab(np.concatenate(ys)); R = np.concatenate(rs)
    ident = np.concatenate([np.tile(M.KX, 3), M.SX])
    # Two extra numbers, not part of the look: the difference in corner
    # shading between the two modes (gain = 1 + v1 r^2 + v2 r^4 on the input).
    def shade(x, r, v):
        return np.clip(x * (1 + v[0] * r ** 2 + v[1] * r ** 4)[..., None], 0, 1)
    BAND_REG = float(os.environ.get('BAND_REG', '1.5'))
    def resid(q):
        p, v = q[:M.NP], q[M.NP:]
        r = (lab(M.model(p, shade(X, R, v))) - Y).ravel()
        bands = p[M.O_B:M.O_T].reshape(3, M.T, M.B)
        # Neighbouring hue bands should agree: colours the photos never show
        # are then interpolated from either side instead of left to jump.
        smooth = (np.roll(bands, -1, axis=2) - bands).ravel()
        tiers = (bands[:, 1, :] - bands[:, 0, :]).ravel()
        return np.concatenate([r, BAND_REG * bands.ravel(), 4.0 * smooth, 1.0 * tiers,
                               2.0 * (p[M.O_C:M.O_B] - ident)])
    q0 = np.concatenate([M.init_params(), [0.0, 0.0]])
    lo = np.full(M.NP + 2, -np.inf); hi = np.full(M.NP + 2, np.inf)
    lo[M.O_C:M.O_B] = -0.2; hi[M.O_C:M.O_B] = 1.2; lo[M.O_B:M.O_T] = -3; hi[M.O_B:M.O_T] = 3
    lo[M.NP:] = -1.5; hi[M.NP:] = 1.5
    res = least_squares(resid, q0, method='trf', max_nfev=3000, x_scale='jac', bounds=(lo, hi))
    p, v = res.x[:M.NP], res.x[M.NP:]; np.save(f'{out}/params.npy', p)
    print('corner shading between modes:', np.round(v, 3))
    for n, (x, y) in pairs.items():
        f = M.model(p, shade(x, radius(x), v), smooth=True)
        before = np.sqrt(((lab(x) - lab(y)) ** 2).sum(-1)).mean()
        after = np.sqrt(((lab(f) - lab(y)) ** 2).sum(-1))
        print(f"{n} {'VAL' if n in val else 'fit'}  before {before:5.2f}  after {after.mean():5.2f}  worst5% {np.percentile(after, 95):5.2f}")
        Image.fromarray((np.concatenate([x, y, f], 0) * 255).round().astype(np.uint8)).save(f'{out}/{n}_cmp.jpg', quality=90)
    # Stability: on every colour of a grid, how far from "no change" and how
    # smoothly does the model move between neighbouring colours?
    N = 33; g = np.linspace(0, 1, N); b, gg, r = np.meshgrid(g, g, g, indexing='ij')
    C = np.stack([r, gg, b], -1); F = M.model(p, C.reshape(-1, 3), smooth=True).reshape(C.shape)
    L = lab(F); jumps = np.concatenate([np.sqrt(((np.diff(L, axis=a)) ** 2).sum(-1)).ravel() for a in range(3)])
    base = lab(C); bj = np.concatenate([np.sqrt(((np.diff(base, axis=a)) ** 2).sum(-1)).ravel() for a in range(3)])
    print('neighbour step: ours p99 %.2f max %.2f  | identity p99 %.2f max %.2f' % (np.percentile(jumps, 99), jumps.max(), np.percentile(bj, 99), bj.max()))
    print('nfev', res.nfev)

if __name__ == '__main__':
    main()
