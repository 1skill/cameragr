"""Fit Koco's own colour model (fit_look2) to a camera's rendering of a
GretagMacbeth ColorChecker and a Kodak grey scale: ideal colours in, the
camera's measured colours out. Used for cameras we only have a studio chart
shot of (e.g. early CCD compacts from Imaging Resource's reviews).

    python tools/fit_chart.py <meas.npy from the chart shot> <out dir>
"""
import sys, os
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fit_look import lab
import fit_look2 as M

# ColorChecker Classic, sRGB 8-bit (X-Rite, D65), patches 1..24.
CC = np.array([[115,82,68],[194,150,130],[98,122,157],[87,108,67],[133,128,177],[103,189,170],
               [214,126,44],[80,91,166],[193,90,99],[94,60,108],[157,188,64],[224,163,46],
               [56,61,150],[70,148,73],[175,54,60],[231,199,31],[187,86,149],[8,133,161],
               [243,243,242],[200,200,200],[160,160,160],[122,122,121],[85,85,85],[52,52,52]]) / 255.0

def srgb_encode(lin):
    return np.where(lin <= 0.0031308, 12.92 * lin, 1.055 * lin ** (1 / 2.4) - 0.055)

def fit(X, Y, reg=float(os.environ.get('BAND_REG', '3.0')), smooth=6.0):
    Yl = lab(Y); ident = np.concatenate([np.tile(M.KX, 3), M.SX])
    def resid(p):
        bands = p[M.O_B:M.O_T].reshape(3, M.T, M.B)
        return np.concatenate([(lab(M.model(p, X)) - Yl).ravel(), reg * bands.ravel(),
                               smooth * (np.roll(bands, -1, axis=2) - bands).ravel(),
                               2.0 * (bands[:, 1, :] - bands[:, 0, :]).ravel(),
                               1.0 * (p[M.O_C:M.O_B] - ident)])
    lo = np.full(M.NP, -np.inf); hi = np.full(M.NP, np.inf)
    lo[M.O_C:M.O_B] = -0.2; hi[M.O_C:M.O_B] = 1.2; lo[M.O_B:M.O_T] = -3; hi[M.O_B:M.O_T] = 3
    return least_squares(resid, M.init_params(), method='trf', max_nfev=3000, x_scale='jac', bounds=(lo, hi)).x

def main():
    d = np.load(sys.argv[1], allow_pickle=True).item(); out = sys.argv[2]; os.makedirs(out, exist_ok=True)
    cam_cc = np.array([d['cc'][k] for k in range(1, 25)]) / 255.0
    grey = np.array(d['grey']) / 255.0
    # Kodak grey scale: step i has density 0.05 + 0.10 i.
    ideal_grey = np.repeat(srgb_encode(10 ** -(0.05 + 0.10 * np.arange(len(grey))))[:, None], 3, 1)
    X = np.concatenate([CC, ideal_grey]); Y = np.concatenate([cam_cc, grey])
    p = fit(X, Y); np.save(f'{out}/params.npy', p)
    err = np.sqrt(((lab(M.model(p, X, smooth=True)) - lab(Y)) ** 2).sum(-1))
    before = np.sqrt(((lab(X) - lab(Y)) ** 2).sum(-1))
    print('ideal vs camera, before: chart %.2f  grey %.2f' % (before[:24].mean(), before[24:].mean()))
    print('fit:  chart %.2f  grey %.2f' % (err[:24].mean(), err[24:].mean()))
    # Leave one chart patch out at a time: how well is an unseen colour predicted?
    loo = []
    for k in range(24):
        keep = np.ones(len(X), bool); keep[k] = False
        q = fit(X[keep], Y[keep])
        loo.append(float(np.sqrt(((lab(M.model(q, X[k:k + 1], smooth=True)) - lab(Y[k:k + 1])) ** 2).sum())))
    loo = np.array(loo)
    print('leave-one-out chart patches: mean %.2f  max %.2f (patch %d)' % (loo.mean(), loo.max(), loo.argmax() + 1))
    print('per patch:', np.round(loo, 1).tolist())

if __name__ == '__main__':
    main()
