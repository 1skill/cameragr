"""App Store screenshots for the iPhone Duo slots (landscape), in the grammar
of the approved iPhone set (tools/appstore_v6.py): one yellow ground, a
two-line headline, one big hero. Inner screen 2853x2007, outer 2034x1398.

    lut-test/venv-sfl/bin/python tools/appstore_duo_v7.py <zh|en> <inner|outer> <outdir> [page ...]

Pages: 1 camera, 2 rolls, 3 community (not until it ships: skipped),
4 not for sale, 5 bag, 6 what you see, 7 try, 8 two ways in.
Reuses v6's helpers by running its definitions with the size changed.
"""
import sys, os, math
LANG, SCREEN, OUTDIR = sys.argv[1], sys.argv[2], sys.argv[3]
PAGES = [int(p) for p in sys.argv[4:]] or [1, 2, 4, 5, 6, 7, 8]   # 3 (community) waits for the community
sys.argv = ["appstore_v6.py", LANG, "/tmp"]
src = open(os.path.join(os.path.dirname(__file__), "appstore_v6.py")).read().split("os.makedirs(out, exist_ok=True)\nfor p in pages:")[0]
exec(src)
W, H = (2853, 2007) if SCREEN == "inner" else (2034, 1398)
U = H / 2007   # 1 on the inner screen

def head(im, n):
    """Two lines at the top left, a size that suits the landscape page."""
    text = COPY[str(n)][0]
    d = ImageDraw.Draw(im)
    size = round((150 if zh else 128) * U)
    step = round(size * 1.2)
    y = round(130 * U)
    for row in text.split("\n"):
        d.text((round(150 * U), y), row, font=font(size), fill=INK, anchor="lt")
        y += step
    return y

def fit(img, w=None, h=None):
    if w: return img.resize((round(w), round(img.height * w / img.width)), Image.LANCZOS)
    return img.resize((round(img.width * h / img.height), round(h)), Image.LANCZOS)

def on_yellow(path, theirs=None):
    """A GPT picture drawn on its own yellow, with only its ground moved to ours."""
    import numpy as np
    a = Image.open(path).convert("RGB")
    t = np.array(theirs or a.getpixel((10, 10)), float); o = np.array(YELLOW, float)
    x = np.asarray(a).astype(float)
    w = np.clip(1 - (np.sqrt(((x - t) ** 2).sum(-1)) - 18) / 50, 0, 1)[..., None]
    return Image.fromarray(np.clip(x + w * (o - t), 0, 255).astype("uint8"))

def d1():
    """Not an iPhone, a film camera: rolls strewn on the yellow, the whole
    camera large on the right."""
    import random
    rnd = random.Random(3)
    im = Image.new("RGB", (W, H), YELLOW)
    for row in range(5):
        for col in range(9):
            x = col * W / 8 - 60 * U + (row % 2) * W / 16
            y = H * 0.30 + row * H * 0.18
            if x < W * 0.42 and y < H * 0.36: continue
            roll = roll_img(rnd.randrange(len(ROLL_IDS)), round(170 * U))
            place(im, roll, (round(x), round(y)), angle=rnd.uniform(-30, 30), shadow=round(10 * U))
    body = body_img(round(W * 0.60))
    place(im, body, (round(W * 0.37), round(H * 0.26)), radius=round(body.width * 0.09), shadow=round(70 * U))
    head(im, 1)
    return im

def d2():
    """A different roll, a different life: a wall of prints, each from a
    different roll, filling the page under the headline."""
    import random
    rnd = random.Random(5)
    im = Image.new("RGB", (W, H), YELLOW)
    films = ["portra400", "cine500t", "trix400", "velvia50", "gold200", "natura1600", "fp100c", "ccd",
             "kodachrome64", "doublex", "instax", "pro400h", "vista100", "ektachrome", "grneg", "c200"]
    pw = round(470 * U); k = 0; used = set()
    for row in range(3):
        for col in range(6):
            x = round(-40 * U + col * (pw + 30 * U) + (row % 2) * 60 * U)
            y = round(H * 0.31 + row * 470 * U)
            if x > W: continue
            fid = films[k % len(films)]; k += 1
            cands = sorted(f for f in os.listdir(SAMPLES) if f.startswith(fid + "__"))
            pick = next((f for f in cands if f.split("__")[1] not in used), cands[0]); used.add(pick.split("__")[1])
            place(im, card(f"{SAMPLES}/{pick}", pw, round(14 * U)), (x, y), angle=rnd.uniform(-4, 4), shadow=round(22 * U))
            place(im, roll_img(ROLL_IDS.index(fid), round(150 * U)), (x + pw - round(80 * U), y + round(240 * U)),
                  angle=rnd.uniform(-20, 20), shadow=round(10 * U))
    head(im, 2)
    return im

def hero_right(path, n, scale, cx, bottom):
    """A tall GPT hero (portrait art) right of the headline: scaled by the
    page height, its middle at cx (0…1 of the width), the bottom of what it
    shows (`bottom`, 0…1 of the art) just above the page's foot."""
    im = Image.new("RGB", (W, H), YELLOW)
    a = fit(on_yellow(path), h=H * scale)
    im.paste(a, (round(W * cx - a.width / 2), round(H - 50 * U - a.height * bottom)))
    head(im, n)
    return im

def d4():
    return hero_right(f"design/appstore/v6/locked_roll_{'zh' if zh else 'en'}.png", 43, 1.50, 0.64, 0.90)

def d8():
    return hero_right("design/appstore/v6/ways_phone4.png", 8, 1.26, 0.60, 0.93)

def d5():
    """Not a camera bag, a film arsenal: the open bag whole, large."""
    im = Image.new("RGB", (W, H), YELLOW)
    # Straight (user), and cut inside the leather's own rounded corner so no
    # black from the render's margin shows.
    raw = Image.open(f"{SRC}/bag4.png").convert("RGB")
    raw = crop_rel(raw, (0.004, 0.006, 0.996, 0.994))
    bag = fit(raw, w=W * 0.72)
    place(im, bag, (W - bag.width - round(110 * U), H - bag.height - round(80 * U)),
          radius=round(bag.width * 0.046), shadow=round(70 * U))
    head(im, 9)
    return im

def d6():
    """What you see is what you get: the camera and the print it gives, at
    one angle, the print tucked under the camera."""
    im = Image.new("RGB", (W, H), YELLOW)
    pr = card(f"{SAMPLES}/gold200__gold200_3.jpg", round(W * 0.42), round(26 * U))
    place(im, pr, (round(W * 0.52), round(H * 0.42)), angle=-6, shadow=round(60 * U))
    body = body_img(round(W * 0.52))
    place(im, body, (round(W * 0.10), round(H * 0.33)), angle=-6, radius=round(body.width * 0.09), shadow=round(70 * U))
    head(im, 3)
    return im

def d7():
    """Try before you buy: the real compare viewer, the photo whole (it is
    landscape here), the white line through the red car."""
    full = Image.open(f"{SRC}/own_cine.png").convert("RGB")
    k = full.width / 3804
    photo = full.crop(tuple(round(v * k) for v in (348, 108, 3460, 2180)))
    im = Image.new("RGB", (W, H), YELLOW)
    p = fit(photo, w=W * 0.74)
    place(im, p, (W - p.width - round(120 * U), H - p.height - round(110 * U)), radius=round(50 * U), shadow=round(70 * U))
    head(im, 4)
    return im

if __name__ == "__main__":
    os.makedirs(OUTDIR, exist_ok=True)
    make = {1: d1, 2: d2, 4: d4, 5: d5, 6: d6, 7: d7, 8: d8}
    for p in PAGES:
        if p not in make: continue
        make[p]().convert("RGB").save(f"{OUTDIR}/{p}_{SCREEN}_{LANG}.png")
    print("ok", PAGES)
