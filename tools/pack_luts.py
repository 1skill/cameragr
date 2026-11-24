"""Packs the baked cubes (float32 RGBA, from export_luts.py / creative_looks.py)
into half-float RGB in place: a third of the size, and still far finer than the
8-bit pictures they make. The app reads both (FilmLibrary.cube). Safe to re-run.

    lut-test/venv-sfl/bin/python tools/pack_luts.py cameragr/Resources/Films
"""
import sys, numpy as np
from pathlib import Path
for f in sorted(Path(sys.argv[1]).glob("*.lut")):
    raw = f.read_bytes()
    n = 33 ** 3
    if len(raw) == n * 3 * 2: continue                   # already packed
    a = np.frombuffer(raw, dtype="<f4").reshape(-1, 4)
    assert len(a) == n, f
    h = a[:, :3].astype("<f2")
    err = np.abs(h.astype("<f4") - a[:, :3]).max()
    f.write_bytes(h.tobytes())
    print(f.name, f"max error {err:.5f}")
