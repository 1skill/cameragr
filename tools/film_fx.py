#!/usr/bin/env python3
"""Film texture pass: glow, halation, vignette, grain.

A direct numpy port of `filmBright` + `filmComposite` from
Film-Camera-IOS (MIT), Film Camera/Rendering/FilmShaders.metal, so the test
sheets match what that Metal pipeline renders. Constants are copied from the
shader; do not tune them here.

Usage:
    python3 tools/film_fx.py PHOTO LUT_ROOT OUT_DIR
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

import apply_luts as al

LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)

# FilmAdjustments defaults in the source project.
DEFAULT = dict(grain=0.3, grain_size=0.35, glow=0.0, halation=0.0, vignette=0.2)
# Same sliders pushed up (slider values are ours; the maths is the project's).
STRONG = dict(grain=0.6, grain_size=0.5, glow=0.35, halation=0.5, vignette=0.4)

FILMS = [
    ("Portra 400", "negative_new/kodak_portra_400.cube"),
    ("Portra 800", "negative_new/kodak_portra_800.cube"),
    ("Superia 200", "negative_color/fuji_superia_200.cube"),
    ("Velvia 50", "colorslide/fuji_velvia_50.cube"),
    ("Classic Chrome", "fujixtransiii/fuji_xtrans_iii_classic_chrome.cube"),
    ("Polaroid 669", "colorslide/polaroid_669.cube"),
    ("Tri-X 400", "negative_new/kodak_tri-x_400.cube"),
]


def luma(c):
    return c @ LUMA


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def gaussian_blur(img, sigma):
    radius = max(1, int(sigma * 3))
    x = np.arange(-radius, radius + 1, dtype=np.float32)
    k = np.exp(-(x * x) / (2 * sigma * sigma))
    k /= k.sum()
    out = img
    for axis in (0, 1):
        pad = [(0, 0)] * out.ndim
        pad[axis] = (radius, radius)
        p = np.pad(out, pad, mode="edge")
        acc = np.zeros_like(out)
        for i, w in enumerate(k):
            sl = [slice(None)] * out.ndim
            sl[axis] = slice(i, i + out.shape[axis])
            acc += w * p[tuple(sl)]
        out = acc
    return out


def bloom(graded):
    """filmBright: quarter-res highlight extraction + Gaussian blur."""
    h, w, _ = graded.shape
    bh, bw = max(1, h // 4), max(1, w // 4)
    small = np.asarray(
        Image.fromarray((graded * 255 + 0.5).astype(np.uint8)).resize((bw, bh), Image.BOX),
        dtype=np.float32,
    ) / 255.0
    small = small * smoothstep(0.55, 0.95, luma(small))[..., None]
    small = gaussian_blur(small, max(bw, bh) * 0.03)
    chans = [
        np.asarray(Image.fromarray(small[..., i]).resize((w, h), Image.BILINEAR), dtype=np.float32)
        for i in range(3)
    ]
    return np.stack(chans, -1)


def pcg3d(x, y, z):
    with np.errstate(over="ignore"):
        m, a = np.uint32(1664525), np.uint32(1013904223)
        x = x * m + a
        y = y * m + a
        z = z * m + a
        x = x + y * z; y = y + z * x; z = z + x * y
        x = x ^ (x >> np.uint32(16)); y = y ^ (y >> np.uint32(16)); z = z ^ (z >> np.uint32(16))
        x = x + y * z; y = y + z * x; z = z + x * y
    return x, y, z


def gaussian3(cx, cy, seed, salt):
    acc = np.zeros(cx.shape + (3,), dtype=np.float32)
    for off in (0, 0x9E3779B9, 0x7F4A7C15):
        s = np.uint32((seed ^ ((salt + off) & 0xFFFFFFFF)) & 0xFFFFFFFF)
        x, y, z = pcg3d(cx.astype(np.uint32), cy.astype(np.uint32), np.full(cx.shape, s, np.uint32))
        acc += np.stack([x, y, z], -1).astype(np.float32) * np.float32(1.0 / 4294967295.0)
    return (acc - 1.5) * 2.0


def grain_noise(px, py, seed, salt):
    ix, iy = np.floor(px), np.floor(py)
    fx, fy = px - ix, py - iy
    wx = (fx * fx * (3 - 2 * fx))[..., None]
    wy = (fy * fy * (3 - 2 * fy))[..., None]
    cx, cy = ix.astype(np.int32), iy.astype(np.int32)
    n00 = gaussian3(cx, cy, seed, salt)
    n10 = gaussian3(cx + 1, cy, seed, salt)
    n01 = gaussian3(cx, cy + 1, seed, salt)
    n11 = gaussian3(cx + 1, cy + 1, seed, salt)
    top = n00 + (n10 - n00) * wx
    bot = n01 + (n11 - n01) * wx
    return (top + (bot - top) * wy) * 1.6


def composite(graded, grain=0.3, grain_size=0.35, glow=0.0, halation=0.0, vignette=0.2, seed=7,
              grain_scale=None, dye_amount=0.25, clump_amount=0.45):
    """filmComposite: glow, halation, vignette, grain.

    grain_scale / dye_amount / clump_amount default to the shader's own values;
    they are exposed only for diagnostic comparisons.
    """
    h, w, _ = graded.shape
    c = graded.astype(np.float32).copy()
    if glow > 0.001 or halation > 0.001:
        b = bloom(graded)
        c = 1.0 - (1.0 - c) * (1.0 - np.clip(b * glow * 1.6, 0, 1))
        c += np.array([1.0, 0.28, 0.1], np.float32) * luma(b)[..., None] * halation * 1.4

    v, u = np.meshgrid((np.arange(h) + 0.5) / h, (np.arange(w) + 0.5) / w, indexing="ij")
    r = np.sqrt(((u - 0.5) * 2) ** 2 + ((v - 0.5) * 2) ** 2) * 0.7071
    c *= (1.0 - vignette * 0.85 * smoothstep(0.35, 1.05, r))[..., None]

    if grain > 0:
        s = (seed * 747796405 + 2891336453) & 0xFFFFFFFF
        scale = grain_scale or 1500.0 / (1.0 + grain_size * 3.0)
        gx, gy = u * (w / h) * scale, v * scale
        fine = grain_noise(0.8660 * gx - 0.5 * gy, 0.5 * gx + 0.8660 * gy, s, 0x68E31DA4)
        bx, by = 0.3420 * gx + 0.9397 * gy, -0.9397 * gx + 0.3420 * gy
        clump = grain_noise(bx * 0.45 + 17.0, by * 0.45 + 17.0, s, 0xB5297A4D)
        g = fine * 0.75 + clump * clump_amount
        response = np.clip(4.0 * c * (1.0 - c), 0, 1) ** 0.75
        l = luma(c)[..., None]
        chroma = np.clip(np.linalg.norm(c - l, axis=-1, keepdims=True) * 4.0, 0, 1)
        dye = np.stack([g[..., 1], -0.5 * (g[..., 1] + g[..., 2]), g[..., 2]], -1) * dye_amount * chroma
        c += (g[..., 0:1] + dye) * grain * 0.11 * response
    return np.clip(c, 0, 1)


def to_img(a):
    return Image.fromarray((a * 255 + 0.5).astype(np.uint8))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("photo")
    ap.add_argument("lut_root")
    ap.add_argument("out_dir")
    ap.add_argument("--long-edge", type=int, default=1600)
    ap.add_argument("--tile-edge", type=int, default=800)
    a = ap.parse_args()
    out = Path(a.out_dir)
    (out / "fx_single").mkdir(parents=True, exist_ok=True)

    src = ImageOps.exif_transpose(Image.open(a.photo)).convert("RGB")
    src.thumbnail((a.long_edge, a.long_edge), Image.LANCZOS)
    arr = np.asarray(src, dtype=np.float32) / 255.0

    def tile(im):
        t = im.copy()
        t.thumbnail((a.tile_edge, a.tile_edge), Image.LANCZOS)
        return t

    for tag, params in (("default", DEFAULT), ("strong", STRONG)):
        tiles = [("Original (no filter)", tile(src))]
        for label, rel in FILMS:
            graded = al.apply_lut(arr, al.load_cube(Path(a.lut_root) / rel))
            res = to_img(composite(graded, **params))
            res.save(out / "fx_single" / f"{label.lower().replace(' ', '_')}_{tag}.jpg", quality=93)
            tiles.append((label, tile(res)))
        dest = out / f"fx_sheet_{tag}.jpg"
        title = "Texture: default (grain + light vignette)" if tag == "default" else \
            "Texture: strong (grain, halation, glow, vignette)"
        al.sheet(title, tiles, dest)
        print(dest)


if __name__ == "__main__":
    main()
