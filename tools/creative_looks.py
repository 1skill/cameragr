"""Koco's own creative looks (no reference film to fit, no third-party data):
designed transforms baked to 33^3 cubes like the other looks.

- purple (暮紫): the purple-shift colour-negative look — greens turn
  violet, blues turn teal, yellows pink, reds and skin stay warm; neutrals
  untouched. A piecewise hue remap weighted by saturation.
- infrared (火叶): false-colour infrared. RGB carries no infrared, so an
  infrared estimate is made from how "leafy" a colour is (green over red
  and blue, the way chlorophyll reflects near-IR) plus some of its
  brightness, then the colour-infrared channel shift: IR -> red,
  red -> green, green -> blue. Foliage goes red, sky deep blue.

    lut-test/venv-sfl/bin/python tools/creative_looks.py <out dir> [preview.jpg]
    lut-test/venv-sfl/bin/python tools/creative_looks.py --catalogue   (writes the limited rolls into the app)

Afterwards pack them: lut-test/venv-sfl/bin/python tools/pack_luts.py cameragr/Resources/Films
"""
import sys
import numpy as np

def srgb_to_lin(x): return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)
def lin_to_srgb(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * x ** (1 / 2.4) - 0.055)

def rgb_to_hsv(c):
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    mx, mn = c.max(-1), c.min(-1); d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rr = m & (mx == r); gg = m & (mx == g) & ~rr; bb = m & ~rr & ~gg
    h[rr] = ((g - b)[rr] / d[rr]) % 6
    h[gg] = (b - r)[gg] / d[gg] + 2
    h[bb] = (r - g)[bb] / d[bb] + 4
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h * 60.0, s, mx

def hsv_to_rgb(h, s, v):
    h = (h % 360) / 60.0
    i = np.floor(h).astype(int) % 6; f = h - np.floor(h)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    out = np.stack([np.choose(i, [v, q, p, p, t, v]), np.choose(i, [t, v, v, q, p, p]), np.choose(i, [p, p, t, v, v, q])], -1)
    return out

# hue in -> hue out (degrees), interpolated round the circle
# Targets unwrapped (continuous, may go below 0) so the interpolation never
# crosses the circle the long way (review: orange went green): read mod 360.
PURPLE_MAP = [(0, 2), (30, 16), (55, -20), (90, -60), (130, -75), (170, -125), (205, -172), (240, -178), (280, -105), (330, -15), (360, 2)]

def remap_hue(h, table):
    xs = np.array([a for a, _ in table], float); ys = np.array([b for _, b in table], float)
    return np.interp(h, xs, ys) % 360

def purple(rgb):
    h, s, v = rgb_to_hsv(rgb)
    h2 = remap_hue(h, PURPLE_MAP)
    w = np.clip((s - 0.08) / 0.25, 0, 1)            # neutrals near neutral, a little warm
    dh = ((h2 - h + 180) % 360) - 180
    hn = h + dh * w
    # remapped colours are softer than the originals: the stock's dyes are
    # muted (greens to a dusky violet, sky to a pale teal)
    moved = np.clip(np.abs(dh) / 90.0, 0, 1) * w
    s2 = np.clip(s * (1 - 0.38 * moved), 0, 1)
    v = v * (1 - 0.12 * moved)
    out = hsv_to_rgb(hn, s2, v)
    # a little contrast and a cool-violet shadow tint, like the stock's base
    lum = out @ np.array([0.2126, 0.7152, 0.0722])
    out = out + (np.array([0.03, -0.02, 0.05]) * (1 - lum)[..., None]) * 0.6
    out = 0.5 + (out - 0.5) * 1.08
    return np.clip(out, 0, 1)

def infrared(rgb):
    lin = srgb_to_lin(rgb)
    r, g, b = lin[..., 0], lin[..., 1], lin[..., 2]
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    leaf = np.clip(g - np.maximum(r * 0.85, b), 0, None)          # how leafy
    leaf = leaf / (leaf + 0.06)                                    # saturates
    # skin and warm surfaces reflect near-IR well too (pale in the stock)
    ir = np.clip((0.25 * y + 0.95 * r) / 1.12 + 0.85 * leaf * (0.35 + y) + 0.9 * np.clip(r - g, 0, None), 0, 1)   # neutrals near neutral, a little warm
    out = np.stack([ir, r * 0.84 + 0.12 * y, g * 0.55 + 0.45 * b], -1)
    out = lin_to_srgb(out * 1.05)
    out = 0.5 + (out - 0.5) * 1.12
    return np.clip(out, 0, 1)

LOOKS = {"purple": purple, "infrared": infrared}

def bake(fn, size=33):
    g = np.linspace(0.0, 1.0, size)
    b, gg, r = np.meshgrid(g, g, g, indexing="ij")
    grid = np.stack([r, gg, b], -1)
    return fn(grid).astype(np.float32)

if __name__ == "__main__" and "--catalogue" not in sys.argv:
    from pathlib import Path
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    for fid, fn in LOOKS.items():
        res = bake(fn)
        rgba = np.concatenate([res, np.ones(res.shape[:-1] + (1,), np.float32)], -1)
        (out / f"{fid}.lut").write_bytes(rgba.astype("<f4").tobytes())
        print(fid, "mid-grey ->", res[16, 16, 16].round(3))
    if len(sys.argv) > 2:
        from PIL import Image
        names = ["c200_3", "gold200_1", "kodachrome64_4", "portra400_4", "c200_1", "portra400_1"]
        rows = []
        for n in names:
            x = np.asarray(Image.open(f"cameragr/Resources/Samples/{n}.jpg").convert("RGB").resize((420, 280))).astype(np.float64) / 255
            rows.append(np.concatenate([x, purple(x), infrared(x)], 1))
        Image.fromarray((np.concatenate(rows, 0) * 255).astype("uint8")).save(sys.argv[2])

# The limited rolls (user 2026-11-24): earned only by check-in days in the
# Book, never sold, no free trial shots. Written into films.json and the
# notes by `--catalogue`.
LIMITED = [
    # look, id, name, lcd, label, iso, canister colours, days
    ("purple", "dusk200", "Dusk 200", "DK200", "DUSK", 200, ["#5B3A8C", "#D4AF37"], 7),
    ("infrared", "ember400", "Ember 400", "EM400", "EMBER", 400, ["#B3261E", "#1A1A1A"], 14),
]
NOTES = {
    "dusk200": {
        "en": {"tagline": "Greens turn violet, skies go teal", "about": "A purple-shift colour negative: leaves and grass come out dusky violet, blue skies turn pale teal, yellows go pink, while skin and reds stay warm. Not for sale: seven days running in the Book.", "suits": ["Gardens", "Parks", "Dreamy days"]},
        "zh-Hans": {"tagline": "绿叶变紫，蓝天变青", "about": "紫调幻彩负片：树叶草地变成暮色的紫，蓝天变成淡青，黄色偏粉，肤色和红色仍是暖的。非卖品：在小册里连续打卡 7 天获得。", "suits": ["花园", "公园", "梦幻的日子"]},
        "zh-Hant": {"tagline": "綠葉變紫，藍天變青", "about": "紫調幻彩負片：樹葉草地變成暮色的紫，藍天變成淡青，黃色偏粉，膚色和紅色仍是暖的。非賣品：在小冊裡連續打卡 7 天獲得。", "suits": ["花園", "公園", "夢幻的日子"]},
        "ja": {"tagline": "緑は紫に、青空は青緑に", "about": "パープル系のカラーネガ。葉や芝は夕暮れのような紫に、青空は淡い青緑に、黄色はピンクに。肌と赤は温かいまま。非売品：ブックに7日続けて入れるともらえます。", "suits": ["庭", "公園", "夢見る日"]},
        "ko": {"tagline": "초록은 보라로, 하늘은 청록으로", "about": "보라색으로 물드는 컬러 네거티브. 잎과 잔디는 해질녘 보라, 파란 하늘은 옅은 청록, 노랑은 분홍이 되고 피부와 빨강은 따뜻하게 남습니다. 비매품: 북에 7일 연속 넣으면 받을 수 있어요.", "suits": ["정원", "공원", "꿈같은 날"]},
    },
    "ember400": {
        "en": {"tagline": "Leaves glow red, the sky goes deep", "about": "A false-colour infrared look: foliage burns red and pink, skies turn deep blue-violet, skin goes pale and warm. Best in sunlight with plenty of green. Not for sale: fourteen days running in the Book.", "suits": ["Trees", "Sunny days", "Landscapes"]},
        "zh-Hans": {"tagline": "树叶发红，天空变深", "about": "彩色红外效果：植物烧成红粉色，天空变成深蓝紫，肤色苍白偏暖。阳光充足、绿色多的地方最好看。非卖品：在小册里连续打卡 14 天获得。", "suits": ["树木", "晴天", "风景"]},
        "zh-Hant": {"tagline": "樹葉發紅，天空變深", "about": "彩色紅外效果：植物燒成紅粉色，天空變成深藍紫，膚色蒼白偏暖。陽光充足、綠色多的地方最好看。非賣品：在小冊裡連續打卡 14 天獲得。", "suits": ["樹木", "晴天", "風景"]},
        "ja": {"tagline": "葉は赤く燃え、空は深く", "about": "カラー赤外線風。植物は赤やピンクに燃え、空は深い青紫に、肌は淡く温かく。日差しがあって緑の多い場所がいちばん。非売品：ブックに14日続けて入れるともらえます。", "suits": ["木々", "晴れの日", "風景"]},
        "ko": {"tagline": "잎은 붉게, 하늘은 깊게", "about": "컬러 적외선 느낌. 식물은 붉고 분홍빛으로 타오르고, 하늘은 깊은 청보라, 피부는 창백하고 따뜻하게. 햇빛 좋고 초록이 많은 곳에서 가장 좋아요. 비매품: 북에 14일 연속 넣으면 받을 수 있어요.", "suits": ["나무", "맑은 날", "풍경"]},
    },
}

def catalogue(films_dir):
    import json
    from pathlib import Path
    d = Path(films_dir)
    cat = json.loads((d / "films.json").read_text())
    cat = [f for f in cat if f["id"] not in {l[1] for l in LIMITED}]
    for look, fid, name, lcd, label, iso, colors, days in LIMITED:
        res = bake(LOOKS[look])
        rgba = np.concatenate([res, np.ones(res.shape[:-1] + (1,), np.float32)], -1)
        (d / f"{fid}.lut").write_bytes(rgba.astype("<f4").tobytes())
        cat.append({"id": fid, "lcd": lcd, "name": name, "label": label, "iso": iso, "kind": "color",
                    "lutSize": 33, "colors": colors, "grain": False, "lens": 35, "free": False,
                    "limited": True, "earnDays": days,
                    "source": "Koco's own design (tools/creative_looks.py), no film data"})
    (d / "films.json").write_text(json.dumps(cat, indent=2, ensure_ascii=False) + "\n")
    notes = json.loads((d / "film_notes.json").read_text())
    for fid, text in NOTES.items():
        notes[fid] = {"samples": [{"file": f"{fid}_{k}", "iso": 100, "split": 0.5} for k in range(1, 5)], "text": text}
    (d / "film_notes.json").write_text(json.dumps(notes, indent=2, ensure_ascii=False) + "\n")
    print("catalogue:", [l[1] for l in LIMITED])

if __name__ == "__main__" and "--catalogue" in sys.argv:
    catalogue("cameragr/Resources/Films")
