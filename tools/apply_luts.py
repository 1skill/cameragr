#!/usr/bin/env python3
"""Apply a set of .cube film LUTs to one photo and build comparison sheets.

Usage:
    python3 -I tools/apply_luts.py PHOTO LUT_ROOT OUT_DIR [--long-edge 1600]

Only colour is applied here (the 3D LUT). Grain, halation and vignette are
added later by the app's Metal pipeline and are not part of this preview.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps

# (sheet title, [(label, path relative to LUT_ROOT)])
GROUPS = [
    ("1 Color negative", [
        ("Kodak Ektar 100", "negative_color/kodak_ektar_100.cube"),
        ("Kodak Portra 160", "negative_new/kodak_portra_160.cube"),
        ("Kodak Portra 400", "negative_new/kodak_portra_400.cube"),
        ("Kodak Portra 800", "negative_new/kodak_portra_800.cube"),
        ("Kodak Portra 160 VC", "negative_color/kodak_portra_160_vc.cube"),
        ("Fuji Pro 400H", "negative_new/fuji_400h.cube"),
        ("Fuji Pro 160C", "negative_new/fuji_160c.cube"),
        ("Fuji Superia 200", "negative_color/fuji_superia_200.cube"),
        ("Fuji Superia 400", "negative_old/fuji_superia_400.cube"),
        ("Fuji Reala 100", "negative_color/fuji_superia_reala_100.cube"),
        ("Agfa Vista 200", "negative_color/agfa_vista_200.cube"),
    ]),
    ("2 Slide film", [
        ("Fuji Velvia 50", "colorslide/fuji_velvia_50.cube"),
        ("Fuji Provia 100F", "colorslide/fuji_provia_100f.cube"),
        ("Kodak Kodachrome 64", "colorslide/kodak_kodachrome_64.cube"),
        ("Kodak Ektachrome 100 VS", "colorslide/kodak_ektachrome_100_vs.cube"),
        ("Agfa Precisa 100", "colorslide/agfa_precisa_100.cube"),
    ]),
    ("3 BW and instant", [
        ("Kodak Tri-X 400", "negative_new/kodak_tri-x_400.cube"),
        ("Ilford HP5", "negative_new/ilford_hp_5.cube"),
        ("Polaroid 669", "colorslide/polaroid_669.cube"),
    ]),
    ("4 Fuji digital sims", [
        ("Classic Chrome", "fujixtransiii/fuji_xtrans_iii_classic_chrome.cube"),
        ("Pro Neg Hi", "fujixtransiii/fuji_xtrans_iii_pro_neg_hi.cube"),
        ("Astia", "fujixtransiii/fuji_xtrans_iii_astia.cube"),
        ("Acros", "fujixtransiii/fuji_xtrans_iii_acros.cube"),
    ]),
]


def load_cube(path):
    size = None
    lo = np.zeros(3)
    hi = np.ones(3)
    rows = []
    for line in Path(path).read_text(errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        key = parts[0].upper()
        if key == "LUT_3D_SIZE":
            size = int(parts[1])
        elif key == "DOMAIN_MIN":
            lo = np.array([float(v) for v in parts[1:4]])
        elif key == "DOMAIN_MAX":
            hi = np.array([float(v) for v in parts[1:4]])
        elif key in ("TITLE", "LUT_1D_SIZE", "LUT_1D_INPUT_RANGE", "LUT_3D_INPUT_RANGE"):
            continue
        else:
            try:
                rows.append([float(parts[0]), float(parts[1]), float(parts[2])])
            except (ValueError, IndexError):
                continue
    if size is None or len(rows) != size ** 3:
        raise ValueError(f"{path}: bad cube (size={size}, rows={len(rows)})")
    # .cube order: red changes fastest, then green, then blue -> index [b, g, r]
    table = np.asarray(rows, dtype=np.float32).reshape(size, size, size, 3)
    return table, size, lo, hi


def apply_lut(img, cube):
    """img: float32 HxWx3 in 0..1. Trilinear interpolation."""
    table, n, lo, hi = cube
    x = np.clip((img - lo) / (hi - lo), 0.0, 1.0) * (n - 1)
    i0 = np.floor(x).astype(np.int32)
    i0 = np.minimum(i0, n - 2)
    f = (x - i0).astype(np.float32)
    r0, g0, b0 = i0[..., 0], i0[..., 1], i0[..., 2]
    fr, fg, fb = f[..., 0:1], f[..., 1:2], f[..., 2:3]
    out = np.zeros_like(img, dtype=np.float32)
    for db in (0, 1):
        wb = fb if db else 1 - fb
        for dg in (0, 1):
            wg = fg if dg else 1 - fg
            for dr in (0, 1):
                wr = fr if dr else 1 - fr
                out += table[b0 + db, g0 + dg, r0 + dr] * (wb * wg * wr)
    return np.clip(out, 0.0, 1.0)


def font(size):
    for p in ("/System/Library/Fonts/Helvetica.ttc", "/System/Library/Fonts/SFNS.ttf"):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


def sheet(title, tiles, out_path, cols=2, pad=16, label_h=44):
    w, h = tiles[0][1].size
    rows = -(-len(tiles) // cols)
    head = 70
    W = cols * w + (cols + 1) * pad
    H = head + rows * (h + label_h + pad) + pad
    canvas = Image.new("RGB", (W, H), (18, 18, 18))
    d = ImageDraw.Draw(canvas)
    d.text((pad, 18), title, fill=(240, 240, 240), font=font(34))
    for i, (label, im) in enumerate(tiles):
        x = pad + (i % cols) * (w + pad)
        y = head + (i // cols) * (h + label_h + pad)
        canvas.paste(im, (x, y))
        d.text((x + 2, y + h + 8), label, fill=(230, 230, 230), font=font(26))
    canvas.save(out_path, quality=90)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("photo")
    ap.add_argument("lut_root")
    ap.add_argument("out_dir")
    ap.add_argument("--long-edge", type=int, default=1600)
    ap.add_argument("--tile-edge", type=int, default=700)
    a = ap.parse_args()

    lut_root = Path(a.lut_root)
    out = Path(a.out_dir)
    (out / "single").mkdir(parents=True, exist_ok=True)

    src = ImageOps.exif_transpose(Image.open(a.photo)).convert("RGB")
    src.thumbnail((a.long_edge, a.long_edge), Image.LANCZOS)
    arr = np.asarray(src, dtype=np.float32) / 255.0

    def tile(im):
        t = im.copy()
        t.thumbnail((a.tile_edge, a.tile_edge), Image.LANCZOS)
        return t

    src.save(out / "single" / "00_original.jpg", quality=92)
    made = []
    for title, items in GROUPS:
        tiles = [("Original", tile(src))]
        for label, rel in items:
            p = lut_root / rel
            if not p.exists():
                print(f"missing: {rel}", file=sys.stderr)
                continue
            res = Image.fromarray((apply_lut(arr, load_cube(p)) * 255 + 0.5).astype(np.uint8))
            name = label.lower().replace(" ", "_")
            res.save(out / "single" / f"{name}.jpg", quality=92)
            tiles.append((label, tile(res)))
        dest = out / f"sheet_{title.split()[0]}_{'_'.join(title.split()[1:]).lower()}.jpg"
        sheet(title, tiles, dest)
        made.append(dest)
    for m in made:
        print(m)


if __name__ == "__main__":
    main()
