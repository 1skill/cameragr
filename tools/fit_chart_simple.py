"""Fit a camera-pipeline look to a chart shot: linear-light 3x3 colour matrix
(rows sum-normalised, plus white-balance gains) and one shared tone curve.
~23 parameters, for when only a ColorChecker + grey scale is available.

    python tools/fit_chart_simple.py <meas.npy> <out dir>
"""
import sys, os
import numpy as np
from scipy.optimize import least_squares
from scipy.interpolate import PchipInterpolator
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fit_look import lab
from fit_chart import CC, srgb_encode

K = 11; KX = np.linspace(0, 1, K)
def decode(x): return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)

def model(p, x, smooth=False):
    Mx = p[:9].reshape(3, 3); curve = np.maximum.accumulate(p[12:12 + K])
    # White balance is only the ratio between channels: the gains are scaled
    # so the largest is 1, and brightness is left to the tone curve. (Gains
    # above 1 clipped everything bright to one value: blown highlights.)
    gains = p[9:12] / np.max(p[9:12])
    lin = decode(np.clip(x, 0, 1)) @ Mx.T * gains
    e = srgb_encode(np.clip(lin, 0, 1))
    f = PchipInterpolator(KX, curve) if smooth else (lambda v: np.interp(v, KX, curve))
    return np.clip(f(e), 0, 1)

def init():
    p = np.zeros(12 + K); p[:9] = np.eye(3).ravel(); p[9:12] = 1; p[12:] = KX; return p

def fit(X, Y):
    Yl = lab(Y)
    def resid(p):
        rows = p[:9].reshape(3, 3).sum(1) - 1          # matrix keeps white white; gains set the balance
        return np.concatenate([(lab(model(p, X)) - Yl).ravel(), 20 * rows, 0.5 * (p[12:] - KX)])
    return least_squares(resid, init(), method='trf', max_nfev=4000, x_scale='jac').x

def main():
    d = np.load(sys.argv[1], allow_pickle=True).item(); out = sys.argv[2]; os.makedirs(out, exist_ok=True)
    cam = np.array([d['cc'][k] for k in range(1, 25)]) / 255.0; grey = np.array(d['grey']) / 255.0
    ig = np.repeat(srgb_encode(10 ** -(0.05 + 0.10 * np.arange(len(grey))))[:, None], 3, 1)
    X = np.concatenate([CC, ig]); Y = np.concatenate([cam, grey])
    p = fit(X, Y); np.save(f'{out}/params.npy', p)
    e = np.sqrt(((lab(model(p, X, True)) - lab(Y)) ** 2).sum(-1))
    print('fit: chart %.2f grey %.2f' % (e[:24].mean(), e[24:].mean()))
    loo = []
    for k in range(24):
        keep = np.ones(len(X), bool); keep[k] = False; q = fit(X[keep], Y[keep])
        loo.append(float(np.sqrt(((lab(model(q, X[k:k+1], True)) - lab(Y[k:k+1])) ** 2).sum())))
    loo = np.array(loo); print('leave-one-out: mean %.2f max %.2f (patch %d)' % (loo.mean(), loo.max(), loo.argmax() + 1))
    print(np.round(loo, 1).tolist()); print('matrix', np.round(p[:9].reshape(3, 3), 3).tolist(), 'gains', np.round(p[9:12], 3))

if __name__ == '__main__':
    main()
