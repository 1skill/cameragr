#!/usr/bin/env python3
"""Bake the app's film LUTs with Spectral Film LUT (MIT).

Each film is a full sRGB -> negative -> print -> sRGB transform sampled on a
33^3 grid and written as raw little-endian float32 RGBA, red varying fastest
(the layout CIColorCube expects). A films.json catalogue is written next to them.

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

# id, display name, short label for the canister, ISO, kind, negative, print, canister colours
FILMS = [
    ("portra400", "Portra 400", "PORTRA", 400, "color", "Kodak Portra 400", "Kodak Portra Endura Paper", ["#E9C46A", "#5B3A8C"]),
    ("gold200", "Gold 200", "GOLD", 200, "color", "Kodak Gold 200", "Kodak Portra Endura Paper", ["#F2B705", "#C8102E"]),
    ("pro400h", "Pro 400H", "400H", 400, "color", "Fuji Pro 400H", "Fujiflex Crystal Archive New Version", ["#D9D9D9", "#3FA34D"]),
    ("cine500t", "Cine 500T", "500T", 500, "color", "Kodak Vision3 500T 5219", "Kodak Vision 2383", ["#1C1C1C", "#D94F04"]),
    ("velvia50", "Velvia 50", "VELVIA", 50, "color", "Fuji Velvia 50", None, ["#2E7D32", "#C2185B"]),
    ("trix400", "Tri-X 400", "TRI-X", 400, "bw", "Kodak Tri-X 400", "Kodak Professional Polymax Fine-Art Paper", ["#F5F5F5", "#111111"]),
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
    for fid, name, label, iso, kind, neg, pr, colors in FILMS:
        res = film_conversion(grid, stock(neg), stock(pr), input_colorspace="sRGB",
                              output_gamut="Rec. 709", gamma_func="sRGB")
        res = np.clip(np.nan_to_num(res), 0.0, 1.0).astype(np.float32)
        if res.shape[-1] == 1:
            res = np.repeat(res, 3, axis=-1)
        rgba = np.concatenate([res, np.ones(res.shape[:-1] + (1,), np.float32)], axis=-1)
        (out / f"{fid}.lut").write_bytes(rgba.astype("<f4").tobytes())
        catalogue.append({"id": fid, "name": name, "label": label, "iso": iso, "kind": kind,
                          "lutSize": SIZE, "colors": colors,
                          "source": f"{neg}" + (f" / {pr}" if pr else "")})
        mid = res[SIZE // 2, SIZE // 2, SIZE // 2]
        print(f"{fid:10s} mid-grey -> {mid.round(3)}  black -> {res[0,0,0].round(3)}  white -> {res[-1,-1,-1].round(3)}")
    (out / "films.json").write_text(json.dumps(catalogue, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
