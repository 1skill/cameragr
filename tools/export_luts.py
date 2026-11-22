#!/usr/bin/env python3
"""Bake the app's film LUTs with Spectral Film LUT (MIT).

Each film is a full sRGB -> negative -> print -> sRGB transform sampled on a
33^3 grid and written as raw little-endian float32 RGBA, red varying fastest
(the layout CIColorCube expects). A films.json catalogue is written next to them.

Film stocks also get the library's three-stage grain set (its documented
workflow): <id>_neg.lut (photo -> negative, ADX-encoded), <id>_grain.lut
(negative -> grain intensity from the stock's datasheet RMS granularity)
and <id>_print.lut (negative -> print). The app adds grain between the
first and the last. Each stock's ADX scaling is chosen so its negative
spans most of [0, 1], for precision in the 33^3 print cube.

Usage (inside lut-test/venv-sfl):
    python tools/export_luts.py cameragr/Resources/Films
"""
import json
import sys
from pathlib import Path

import numpy as np

import spectral_film_lut as sfl
from spectral_film_lut.film_spectral import FilmSpectral
from spectral_film_lut.utils import film_conversion

SIZE = 33

# id, display name, LCD code, short label for the canister, ISO, kind, negative, print, canister colours
FILMS = [
    ("portra400", "Porto 400", "P400", "PORTO", 400, "color", "Kodak Portra 400", "Kodak Portra Endura Paper", ["#E9C46A", "#5B3A8C"]),
    ("gold200", "Golden 200", "GN200", "GOLDEN", 200, "color", "Kodak Gold 200", "Kodak Portra Endura Paper", ["#F2B705", "#C8102E"]),
    ("c200", "C200", "C200", "C200", 200, "color", "Fuji C200", "Fujiflex Crystal Archive New Version", ["#2E9E5B", "#F4F4F0"]),
    ("cine500t", "Cine 500T", "500T", "500T", 500, "color", "Kodak Vision3 500T 5219", "Kodak Vision 2383", ["#1C1C1C", "#D94F04"]),
    ("kodachrome64", "Chroma 64", "CH64", "CHROMA", 64, "color", "Kodachrome 64", None, ["#F5C400", "#B3261E"]),
    ("trix400", "Tri-Ax 400", "TA400", "TRI-AX", 400, "bw", "Kodak Tri-X 400", "Kodak Professional Polymax Fine-Art Paper", ["#F5F5F5", "#111111"]),
    ("instax", "Instant 800", "INST", "INSTANT", 800, "color", "Fuji Instax color", None, ["#F2F2EE", "#3A6EA5"]),
    # The second tray (2026-11-22, user picked all seven candidates).
    ("velvia50", "Velva 50", "VL50", "VELVA", 50, "color", "Fuji Velvia 50", None, ["#2E7D32", "#111111"]),
    ("fp100c", "Peel 100C", "PL100", "PEEL", 100, "color", "Fuji FP-100C", None, ["#1B1B1B", "#E85D04"]),
    ("doublex", "Double-X", "DX250", "DBL-X", 250, "bw", "Kodak 5222", "Kodak 2302", ["#E8E2D0", "#1A1A1A"]),
    ("vista100", "Vesta 100", "VE100", "VESTA", 100, "color", "Agfa Vista 100", "Kodak Portra Endura Paper", ["#D62828", "#1D3557"]),
    ("ektachrome", "Electra 100", "EL100", "ELECTRA", 100, "color", "Kodak Ektachrome 100D", None, ["#0F0F0F", "#F2C230"]),
    ("natura1600", "Nature 1600", "N1600", "NATURE", 1600, "color", "Fuji Natura 1600", "Fujiflex Crystal Archive New Version", ["#3F2A56", "#D4AF37"]),
    ("pro400h", "Pro 400H", "400H", "400H", 400, "color", "Fuji Pro 400H", "Fujiflex Crystal Archive New Version", ["#6FA8DC", "#F5F5F5"]),
]
# Looks fitted with tools/fit_pairs.py / fit_look2.py: Koco's own colour
# model, parameters in tools/looks/<id>.npy (no third-party LUT data).
# 35 mm-equivalent focal length of the lens whose natural (cos^4) falloff the
# app applies before the look; None = no falloff (the GR corrects its own).
# Instax: the mini's 60 mm lens on a 62 x 46 mm frame is about 34 mm equivalent.
LENS = {"instax": 34, "grneg": None, "ccd": 38}
# Films that need no purchase (the rest are sold singly or with "all films").
FREE = {"gold200", "trix400", "instax"}
# Baked but not offered yet (canister, samples, second tray still to come):
# listed last, marked upcoming, hidden by the app.
UPCOMING: set[str] = set()   # 2026-11-22: the second tray shipped; all seven offered   # T10: 6.33 mm on 1/2.5", ~38 mm equivalent
# Exposure compensation (stops) where the library's default puts mid-grey far
# from the other stocks: Instax at 0 maps sRGB 128 to 207 and clips everything
# above ~190; -1 puts mid-grey at 137, in line with the rest (135-148).
EXP = {"instax": -1.0,
       # Mid-grey to ~140 like the rest (measured 2026-11-22 at exp 0: Velvia 134,
       # FP-100C 194, Double-X 99, Natura 150, Pro 400H 147).
       "velvia50": 0.1, "fp100c": -0.75, "doublex": 0.95, "natura1600": -0.15, "pro400h": -0.1}
# The last field names the model module: fit_look2 (photo pairs) or
# fit_chart_simple (camera pipeline fitted to a ColorChecker + grey scale).
FITTED = [
    ("grneg", "Grit Neg", "GRIT", "GRIT", 200, "color", "Fitted to Ricoh GR III Standard/Negative Film pairs", ["#2B2B2B", "#8A8F8C"], "fit_look2"),
    ("ccd", "CCD", "CCD", "CCD", 100, "color", "Fitted to Imaging Resource's Sony DSC-T10 chart shot (colour), plus measured sharpening and noise", ["#C9CED6", "#2F3A4A"], "fit_chart_simple"),
]


def stock(name):
    if name is None:
        return None
    f = FilmSpectral(next(s for s in sfl.FILM_STOCKS if s.name == name))
    f.set_color_checker()
    return f


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    g = np.linspace(0.0, 1.0, SIZE, dtype=np.float32)
    b, gg, r = np.meshgrid(g, g, g, indexing="ij")  # index [b, g, r]; r fastest when flattened
    grid = np.stack([r, gg, b], axis=-1)

    catalogue = []
    def write(path, res, clip=True):
        res = np.nan_to_num(res).astype(np.float32)
        if clip:
            res = np.clip(res, 0.0, 1.0)
        if res.shape[-1] == 1:
            res = np.repeat(res, 3, axis=-1)
        rgba = np.concatenate([res, np.ones(res.shape[:-1] + (1,), np.float32)], axis=-1)
        path.write_bytes(rgba.astype("<f4").tobytes())
        return res

    common = dict(input_colorspace="sRGB", output_gamut="Rec. 709", gamma_func="sRGB")
    for fid, name, lcd, label, iso, kind, neg, pr, colors in FILMS:
        n, p = stock(neg), stock(pr)
        common = dict(input_colorspace="sRGB", output_gamut="Rec. 709", gamma_func="sRGB", exp_comp=EXP.get(fid, 0.0))
        res = write(out / f"{fid}.lut", film_conversion(grid, n, p, **common))
        if getattr(n, "grain_curve", None) is None:      # no datasheet granularity (e.g. Instax)
            for stage in ("neg", "print", "grain"):
                (out / f"{fid}_{stage}.lut").unlink(missing_ok=True)
            print(f"{fid:12s} no granularity data: single LUT, no grain")
            catalogue.append({"id": fid, "lcd": lcd, "name": name, "label": label, "iso": iso, "kind": kind,
                              "lutSize": SIZE, "colors": colors, "grain": False, "lens": LENS.get(fid, 35), "free": fid in FREE,
                              "source": f"{neg}" + (f" / {pr}" if pr else "")})
            continue
        # Three-stage set for grain. ADX scaling: fill [0, 0.9] with the negative.
        probe = np.nan_to_num(film_conversion(grid, n, p, mode="negative", adx_scaling=1.0, **common))
        adx = float(np.clip(0.9 / max(probe.max(), 1e-3), 1.0, 8.0))
        negl = write(out / f"{fid}_neg.lut", film_conversion(grid, n, p, mode="negative", adx_scaling=adx, **common))
        prl = write(out / f"{fid}_print.lut", film_conversion(grid, n, p, mode="print", adx_scaling=adx, **common))
        write(out / f"{fid}_grain.lut", film_conversion(grid, n, p, mode="grain", adx_scaling=adx, **common), clip=False)
        back = prl.reshape(-1, 3)
        idx = np.clip(np.rint(negl.reshape(-1, 3) * (SIZE - 1)).astype(int), 0, SIZE - 1)
        roundtrip = back.reshape(SIZE, SIZE, SIZE, 3)[idx[:, 2], idx[:, 1], idx[:, 0]].reshape(res.shape)
        print(f"{fid:12s} adx {adx:.2f}  negative max {negl.max():.3f}  "
              f"neg->print vs full (nearest-grid check) {np.abs(roundtrip - res).mean() * 255:.2f}/255")
        catalogue.append({"id": fid, "lcd": lcd, "name": name, "label": label, "iso": iso, "kind": kind,
                          "lutSize": SIZE, "colors": colors, "grain": True, "lens": LENS.get(fid, 35), "free": fid in FREE,
                          "source": f"{neg}" + (f" / {pr}" if pr else "")})
        mid = res[SIZE // 2, SIZE // 2, SIZE // 2]
        print(f"{fid:10s} mid-grey -> {mid.round(3)}  black -> {res[0,0,0].round(3)}  white -> {res[-1,-1,-1].round(3)}")
    sys.path.insert(0, str(Path(__file__).parent))
    import importlib
    for fid, name, lcd, label, iso, kind, source, colors, module in FITTED:
        p = np.load(Path(__file__).parent / "looks" / f"{fid}.npy")
        res = importlib.import_module(module).model(p, grid.reshape(-1, 3).astype(np.float64), smooth=True).reshape(grid.shape).astype(np.float32)
        rgba = np.concatenate([res, np.ones(res.shape[:-1] + (1,), np.float32)], axis=-1)
        (out / f"{fid}.lut").write_bytes(rgba.astype("<f4").tobytes())
        catalogue.append({"id": fid, "lcd": lcd, "name": name, "label": label, "iso": iso, "kind": kind,
                          "lutSize": SIZE, "colors": colors, "grain": False, "lens": LENS.get(fid, 35), "free": fid in FREE, "source": source,
                          **({"texture": "ccd"} if fid == "ccd" else {})})
        print(f"{fid:10s} fitted, mid-grey -> {res[SIZE // 2, SIZE // 2, SIZE // 2].round(3)}")
    for entry in catalogue:
        if entry["id"] in UPCOMING:
            entry["upcoming"] = True
    catalogue.sort(key=lambda e: e["id"] in UPCOMING)   # stable: the offered films keep their order
    (out / "films.json").write_text(json.dumps(catalogue, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
