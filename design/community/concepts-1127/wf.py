"""Wireframes for the 11/27 community concepts (directions A and B).

Grey boxes at real point sizes (1 SVG unit = 1 pt), so the SVGs show how big
text and buttons really are. Blue labels are size notes, not UI. Colours come
from the page's CSS variables. Run: python3 wf.py > wireframes.html.part
"""
from html import escape

IW, IH, IR = 951, 669, 55          # Duo inner, open flat
OW, OH = 466, 678                  # Duo outer, held upright
CREASE = IW / 2

NAMES = ["阿栗", "Momo", "小川", "Kai", "青山", "Lena", "竹子", "Ren"]
FILMS = ["Porto 400", "C200", "Cine 500T", "Tri-Ax", "Gold 200", "CCD"]


def t(x, y, s, size=15, cls="t", anchor="start", weight=None):
    w = f' font-weight="{weight}"' if weight else ""
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" class="{cls}" '
            f'text-anchor="{anchor}"{w}>{escape(s)}</text>')


def rect(x, y, w, h, cls="bx", r=8):
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r}" class="{cls}"/>'


def ph(x, y, w, h, cls="ph"):
    return (rect(x, y, w, h, cls, 3)
            + f'<path d="M{x:.1f} {y:.1f}L{x+w:.1f} {y+h:.1f}M{x+w:.1f} {y:.1f}L{x:.1f} {y+h:.1f}" class="phx"/>')


def av(cx, cy, r, dot=False):
    s = f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r}" class="av"/>'
    if dot:
        s += f'<circle cx="{cx+r*0.72:.1f}" cy="{cy-r*0.72:.1f}" r="5" class="dot"/>'
    return s


def btn(x, y, w, h, label, size=17, cls="btn"):
    return rect(x, y, w, h, cls, h / 2) + t(x + w / 2, y + h / 2 + size * 0.36, label, size,
                                            "bt" if cls == "btn" else "t", "middle", 600)


def dim(x, y, s, anchor="start"):
    """Size note (blue, not part of the UI)."""
    return t(x, y, s, 11, "dim", anchor, 600)


def mk(x, y, n):
    return (f'<circle cx="{x}" cy="{y}" r="10" class="mk"/>'
            + t(x, y + 4, str(n), 12, "mkt", "middle", 700))


def seg(x, y, w, labels, sel=0, h=44):
    s = rect(x, y, w, h, "seg", h / 2)
    cw = w / len(labels)
    for i, lb in enumerate(labels):
        if i == sel:
            s += rect(x + i * cw + 3, y + 3, cw - 6, h - 6, "segsel", (h - 6) / 2)
        s += t(x + i * cw + cw / 2, y + h / 2 + 5.5, lb, 15, "t" if i == sel else "m", "middle",
               600 if i == sel else None)
    return s


def film_picker(x, y, w, label="全部胶卷"):
    s = rect(x, y, w, 44, "card", 10)
    s += rect(x + 12, y + 10, 16, 24, "can", 3)
    s += t(x + 38, y + 28, label, 15, "t") + t(x + w - 16, y + 28, "▾", 15, "m", "end")
    return s


def work_card(x, y, w, k, ph_h=None):
    """One work: photo, then a paper label with avatar+name, film tag, like."""
    ph_h = ph_h or round(w * 0.75)
    s = ph(x, y, w, ph_h)
    ly = y + ph_h
    s += rect(x, ly, w, 46, "lab", 0)
    s += av(x + 16, ly + 15, 10)
    s += t(x + 32, ly + 20, NAMES[k % len(NAMES)], 13, "t", weight=600)
    s += t(x + 8, ly + 39, FILMS[k % len(FILMS)], 11, "m")
    s += t(x + w - 8, ly + 39, f"♡ {[215, 62, 97, 18, 31, 140, 9, 54][k % 8]}", 13, "t", "end")
    return s, ph_h + 46


def nav_inner():
    s = rect(155, 622, 640, 36, "nav", 18)
    for i, n in enumerate(["相机", "胶卷", "社区", "设置"]):
        cx = 155 + 80 + i * 160
        s += t(cx, 646, n, 15, "a" if n == "社区" else "m", "middle", 700 if n == "社区" else None)
    return s


def nav_outer():
    s = rect(40, 626, 386, 36, "nav", 18)
    for i, n in enumerate(["相机", "胶卷", "社区", "设置"]):
        cx = 40 + 48 + i * 96.5
        s += t(cx, 650, n, 15, "a" if n == "社区" else "m", "middle", 700 if n == "社区" else None)
    return s


def frame_inner(body, title, crease=True):
    c = (f'<line x1="{CREASE}" y1="6" x2="{CREASE}" y2="{IH-6}" class="crease"/>'
         + dim(CREASE + 4, 16, "折痕")) if crease else ""
    return (f'<svg viewBox="0 0 {IW} {IH}" role="img" aria-label="{escape(title)}">'
            f'<rect x="1" y="1" width="{IW-2}" height="{IH-2}" rx="{IR}" class="fr"/>'
            f'{body}{nav_inner()}{c}</svg>')


def frame_outer(body, title):
    # Outer screen held upright: right corners 59pt, left corners 8pt.
    d = (f"M9 1H{OW-60}A59 59 0 0 1 {OW-1} 60V{OH-60}A59 59 0 0 1 {OW-60} {OH-1}"
         f"H9A8 8 0 0 1 1 {OH-9}V9A8 8 0 0 1 9 1Z")
    return (f'<svg viewBox="0 0 {OW} {OH}" role="img" aria-label="{escape(title)}">'
            f'<path d="{d}" class="fr"/>{body}{nav_outer()}</svg>')


# ---------- shared left-column blocks (direction A) ----------

def theme_card(x, y, w):
    h = 150
    s = rect(x, y, w, h, "card sel", 12)
    s += ph(x + 10, y + 10, 104, 130)
    tx = x + 126
    s += t(tx, y + 30, "今日主题 · 还剩 20 小时", 13, "m")
    s += t(tx, y + 62, "它睡着了", 22, "t", weight=700)
    s += av(tx + 10, y + 86, 10) + av(tx + 26, y + 86, 10) + av(tx + 42, y + 86, 10)
    s += t(tx + 58, y + 91, "12 人参与", 13, "m")
    s += btn(tx, y + 102, w - 136, 40, "去发布", 17)
    return s, h


def picks_block(x, y, w):
    """本周精选 as one entry in the same style as a theme (user 11/27: no grid of small pictures)."""
    h = 76
    s = rect(x, y, w, h, "card", 12)
    s += ph(x + 8, y + 8, 60, 60)
    s += rect(x + 12, y + 12, 26, 18, "stamp", 9) + t(x + 25, y + 25, "精", 11, "st", "middle", 700)
    s += t(x + 80, y + 32, "本周精选", 17, "t", weight=700)
    s += t(x + 80, y + 56, "6 张 · 5 位作者", 13, "m")
    s += t(x + w - 14, y + 44, "›", 20, "m", "end")
    return s, h


def follow_block(x, y, w):
    s = t(x + 2, y + 18, "关注的人", 17, "t", weight=700) + t(x + w - 2, y + 18, "3 人有新作品", 13, "m", "end")
    for i in range(5):
        cx = x + 24 + i * 56
        s += av(cx, y + 56, 22, dot=i < 3)
        s += t(cx, y + 94, NAMES[i], 11, "m", "middle")
    return s, 100


def member_card(x, y, w, h=112):
    s = rect(x, y, w, h, "card", 12)
    s += av(x + 32, y + 32, 20)
    s += t(x + 62, y + 30, "Kooo", 17, "t", weight=700) + t(x + 62, y + 48, "连续 3 天", 13, "m")
    s += t(x + w - 14, y + 38, "›", 20, "m", "end")
    cw = (w - 20) / 4
    for i, (n, lb, add) in enumerate([("26", "拍摄", None), ("83", "获赞", "+12"),
                                      ("4", "粉丝", "+4"), ("2", "关注", None)]):
        cx = x + 10 + cw * i + cw / 2
        s += t(cx, y + 84, n, 20, "t", "middle", 700) + t(cx, y + 102, lb, 13, "m", "middle")
        if add:
            s += rect(cx + 8, y + 58, 34, 18, "stamp", 3) + t(cx + 25, y + 71, add, 11, "st", "middle", 700)
    if h >= 150:
        s += t(x + 14, y + 132, "7 天打卡", 13, "m")
        for i in range(7):
            s += rect(x + 80 + i * 26, y + 118, 20, 20, "chip" if i > 2 else "btn", 4)
    return s, h


# ---------- direction A ----------

def a_inner_home():
    L, LW = 28, 284
    s = seg(L, 22, LW, ["主题", "大家", "关注"])
    y = 76
    b, h = theme_card(L, y, LW); s += b + mk(L - 8, y + 8, 1); y += h + 16
    b, h = picks_block(L, y, LW); s += b + mk(L - 8, y + 8, 2); y += h + 14
    b, h = follow_block(L, y, LW); s += b + mk(L - 8, y + 8, 3); y += h + 6
    # member card gets the remaining height above the nav bar
    b, h = member_card(L, y, LW, 612 - y); s += b + mk(L - 8, y + 8, 4)
    # right column: film picker + 4-col grid
    R, RW = 330, 595
    s += film_picker(R, 22, 220) + mk(R - 8, 30, 5)
    s += t(R + 236, 50, "主题：它睡着了 · 38 张", 15, "m")
    gap = 8
    cw = (RW - 3 * gap) / 4
    k = 0
    for row in range(4):
        for c in range(4):
            if 76 + row * (cw * 0.75 + 46 + gap) > 600:
                continue
            b, hh = work_card(R + c * (cw + gap), 76 + row * (cw * 0.75 + 46 + gap), cw, k)
            s += b; k += 1
    s += mk(R - 8, 84, 6)
    # size notes
    s += dim(L + 2, 238, "主题名 22 · 按钮高 40（可点区补到 44）")
    s += dim(R + RW, 70, f"4 列 · 卡宽 {cw:.0f}pt · 纸签两行：名字 13 / 胶卷 11 · 赞 13", "end")
    s += dim(L + LW - 2, y - 30, "头像 44", "end")
    return frame_inner(s, "方向 A 内屏首页")


def a_inner_detail():
    L, LW = 28, 284
    s = seg(L, 22, LW, ["主题", "大家", "关注"])
    y = 76
    b, h = theme_card(L, y, LW); s += b; y += h + 14
    b, h = picks_block(L, y, LW); s += b; y += h + 14
    b, h = follow_block(L, y, LW); s += b; y += h + 6
    b, h = member_card(L, y, LW, 612 - y); s += b
    s += rect(L - 6, 70, LW + 12, 546, "dim-veil", 14)
    R, RW = 330, 595
    s += rect(R, 18, RW, 596, "card", 14)
    s += btn(R + 10, 26, 44, 44, "‹", 22, "ghost") + mk(R + 2, 26, 1)
    s += ph(R + 64, 26, 400, 300)
    s += btn(R + 474, 150, 44, 44, "›", 22, "ghost")
    s += dim(R + 64, 340, "图 400×300，原比例")
    # meta
    my = 352
    s += av(R + 30, my + 20, 18) + t(R + 58, my + 26, "Momo", 17, "t", weight=700)
    s += btn(R + RW - 104, my, 92, 44, "+ 关注", 15, "ghost") + mk(R + 2, my + 6, 2)
    s += rect(R + 12, my + 52, 112, 32, "chip", 16) + rect(R + 12 + 4, my + 58, 12, 20, "can", 2)
    s += t(R + 36, my + 73, "Porto 400", 13, "t")
    s += rect(R + 132, my + 52, 124, 32, "chip", 16) + t(R + 194, my + 73, "# 它睡着了", 13, "t", "middle")
    s += t(R + RW - 14, my + 73, "♡ 215   留言 6", 15, "t", "end")
    # comments
    cy = my + 98
    for i, (n, c) in enumerate([("小川", "光线好温柔，窗框的影子太好看了"),
                                ("Lena", "是哪个窗边？想去拍")]):
        s += av(R + 26, cy + 14 + i * 50, 14)
        s += t(R + 48, cy + 10 + i * 50, n, 13, "m", weight=600) + t(R + 48, cy + 30 + i * 50, c, 15, "t")
    s += mk(R + 2, cy + 6, 3)
    s += rect(R + 12, 560, RW - 24, 44, "input", 22) + t(R + 30, 588, "说点什么…", 15, "m")
    s += dim(R + RW - 16, 552, "输入框 44", "end") + dim(R + 300, cy + 30, "正文 15", "start")
    return frame_inner(s, "方向 A 内屏点开作品")


def outer_home(variant):
    W = OW
    s = ""
    s += seg(20, 18, 300, ["主题", "大家", "关注"])
    s += btn(332, 18, 74, 44, "我", 15, "ghost")
    s += mk(14, 22, 1)
    # theme card full width
    y = 72
    s += rect(20, y, W - 60, 128, "card sel", 12)
    s += ph(30, y + 10, 100, 108)
    s += t(144, y + 30, "今日主题 · 还剩 20 小时", 13, "m")
    s += t(144, y + 60, "它睡着了", 22, "t", weight=700)
    s += t(144, y + 84, "12 人参与", 13, "m")
    s += btn(144, y + 92, 150, 30, "去发布", 15)
    s += dim(300, y + 112, "按钮可点区 44")
    s += mk(14, y + 6, 2)
    y += 140
    if variant == "A":
        # A: the left column's blocks become one row under the theme
        s += rect(20, y, 190, 76, "card", 12) + ph(28, y + 8, 60, 60)
        s += t(98, y + 32, "本周精选", 15, "t", weight=700) + t(98, y + 54, "6 张", 13, "m")
        s += t(222, y + 16, "关注的人", 15, "t", weight=700)
        for i in range(4):
            s += av(244 + i * 50, y + 50, 22, dot=i < 2)
        s += mk(14, y + 6, 3)
        y += 88
    else:
        # B: the top band becomes one swipeable card: 主题 / 精选 / 关注
        s += t(W / 2 - 20, y + 2, "● ○ ○  左右滑：主题 / 精选 / 关注", 11, "m", "middle")
        s += mk(14, y - 4, 3)
        y += 16
    s += film_picker(20, y, 200) + mk(14, y + 6, 4)
    y += 54
    gap = 10
    cw = (W - 40 - 20 - gap) / 2
    for row in range(2):
        for c in range(2):
            b, hh = work_card(20 + c * (cw + gap), y + row * (cw * 0.75 + 46 + gap), cw, row * 2 + c)
            s += b
    s += dim(W - 44, y - 8, f"2 列 · 卡宽 {cw:.0f}", "end")
    return frame_outer(s, f"方向 {variant} 外屏首页")


# ---------- direction B ----------

def b_band(y=18):
    s = ""
    # theme card
    s += rect(28, y, 330, 150, "card sel", 12)
    s += ph(38, y + 10, 104, 130)
    s += t(154, y + 30, "今日主题 · 还剩 20 小时", 13, "m")
    s += t(154, y + 62, "它睡着了", 22, "t", weight=700)
    s += av(164, y + 86, 10) + av(180, y + 86, 10) + av(196, y + 86, 10) + t(212, y + 91, "12 人参与", 13, "m")
    s += btn(154, y + 102, 192, 40, "去发布", 17)
    s += mk(22, y + 8, 1)
    # picks: one cover entry
    px = 372
    s += rect(px, y, 300, 150, "card", 12)
    s += ph(px + 10, y + 10, 130, 130)
    s += rect(px + 16, y + 16, 26, 18, "stamp", 9) + t(px + 29, y + 29, "精", 11, "st", "middle", 700)
    s += t(px + 154, y + 40, "本周精选", 17, "t", weight=700)
    s += t(px + 154, y + 64, "6 张 · 5 位作者", 13, "m")
    s += av(px + 164, y + 92, 10) + av(px + 180, y + 92, 10) + av(px + 196, y + 92, 10)
    s += t(px + 154, y + 134, "看全部 ›", 15, "a")
    s += mk(px - 6, y + 8, 2)
    # follow + nameplate
    fx = 686
    s += rect(fx, y, 237, 150, "card", 12)
    s += t(fx + 14, y + 26, "关注的人", 17, "t", weight=700)
    for i in range(4):
        s += av(fx + 36 + i * 54, y + 60, 22, dot=i < 2)
    s += line(fx + 10, y + 92, fx + 227, y + 92)
    s += av(fx + 32, y + 120, 18) + t(fx + 58, y + 116, "Kooo", 15, "t", weight=700)
    s += t(fx + 58, y + 136, "获赞 83 · 粉丝 4", 13, "m")
    s += rect(fx + 178, y + 104, 40, 20, "stamp", 3) + t(fx + 198, y + 118, "+16", 11, "st", "middle", 700)
    s += mk(fx - 6, y + 8, 3) + mk(fx - 6, y + 102, 4)
    return s


def line(x1, y1, x2, y2, cls="ln"):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" class="{cls}"/>'


def b_cols():
    # 4 columns, the middle gap straddles the crease (2 + 2)
    L, R, gap, mid = 28, 923, 10, 24
    cw = (R - L - 2 * gap - mid) / 4
    xs = [L, L + cw + gap, CREASE + mid / 2, CREASE + mid / 2 + cw + gap]
    return xs, cw


def b_inner_home():
    s = b_band()
    y = 180
    s += seg(28, y, 270, ["主题", "大家", "关注"]) + mk(22, y + 8, 5)
    s += film_picker(310, y, 210)
    s += t(923, y + 28, "主题：它睡着了 · 38 张", 15, "m", "end")
    xs, cw = b_cols()
    y0 = 236
    k = 0
    for row in range(2):
        for x in xs:
            b, hh = work_card(x, y0 + row * (cw * 0.75 + 46 + 10), cw, k)
            s += b; k += 1
    s += mk(22, y0 + 8, 6)
    s += dim(923, 230, f"4 列 · 卡宽 {cw:.0f}pt · 中缝正对折痕（半折 2+2）", "end")
    s += dim(30, 176, "主题名 22 · 按钮 40/44")
    s += dim(918, 34, "头像 44", "end")
    return frame_inner(s, "方向 B 内屏首页")


def b_inner_detail():
    s = ""
    # left: the photo on a light table, as large as fits
    s += rect(20, 18, 455, 596, "table", 14)
    s += btn(30, 28, 44, 44, "‹", 22, "ghost") + mk(24, 26, 1)
    s += ph(40, 120, 415, 311)
    s += btn(30, 250, 44, 44, "‹", 20, "ghost") + btn(421, 250, 44, 44, "›", 20, "ghost")
    s += dim(40, 446, "图 415×311（半折时正好占左半）")
    s += t(247, 590, "3 / 38", 13, "m", "middle")
    # right: note card
    R, RW = 487, 436
    s += rect(R, 18, RW, 596, "card", 14)
    s += av(R + 34, 52, 22) + t(R + 66, 48, "Momo", 17, "t", weight=700) + t(R + 66, 68, "主要用 Porto 400 · 12 卷", 13, "m")
    s += btn(R + RW - 104, 30, 92, 44, "+ 关注", 15, "ghost") + mk(R + 6, 26, 2)
    s += rect(R + 16, 90, 118, 32, "chip", 16) + rect(R + 22, 96, 12, 20, "can", 2) + t(R + 42, 111, "Porto 400", 13, "t")
    s += rect(R + 142, 90, 124, 32, "chip", 16) + t(R + 204, 111, "# 它睡着了", 13, "t", "middle")
    s += t(R + RW - 16, 112, "11/27", 13, "m", "end")
    s += t(R + 16, 152, "下午四点的光，猫在窗台上睡着了。", 17, "t")
    s += btn(R + 16, 168, 120, 44, "♡ 215", 17, "ghost") + t(R + 150, 196, "留言 6", 15, "m") + mk(R + 6, 168, 3)
    s += line(R + 16, 224, R + RW - 16, 224)
    cy = 240
    for i, (n, c, tm) in enumerate([("小川", "光线好温柔，窗框的影子太好看了", "2 小时前"),
                                    ("Lena", "是哪个窗边？想去拍", "1 小时前"),
                                    ("Momo", "@Lena 家里的东窗，下午四点左右", "40 分钟前"),
                                    ("Kai", "这卷的暖色好舒服", "10 分钟前")]):
        yy = cy + i * 66
        s += av(R + 32, yy + 18, 16)
        s += t(R + 58, yy + 14, n, 13, "m", weight=600) + t(R + RW - 16, yy + 14, tm, 11, "m", "end")
        s += t(R + 58, yy + 36, c, 15, "t")
    s += mk(R + 6, cy, 4)
    s += rect(R + 16, 556, RW - 92, 44, "input", 22) + t(R + 34, 584, "说点什么…", 15, "m")
    s += btn(R + RW - 68, 556, 52, 44, "发", 15)
    s += dim(R + RW - 16, 548, "输入框 44 · 正文 15", "end")
    return frame_inner(s, "方向 B 内屏点开作品")


CSS = """
.fr{fill:var(--bg);stroke:var(--fg);stroke-width:2}
.bx{fill:var(--box);stroke:var(--line)}
.card{fill:var(--card);stroke:var(--muted);stroke-width:1}
.card.sel{fill:var(--sel);stroke:var(--accent);stroke-width:1.6}
.table{fill:var(--box);stroke:var(--muted)}
.ph{fill:var(--ph);stroke:none}.phx{stroke:var(--bg);stroke-width:1;opacity:.55}
.lab{fill:var(--card);stroke:var(--line)}
.av{fill:var(--ph);stroke:var(--muted)}
.dot{fill:var(--accent);stroke:var(--card);stroke-width:1.5}
.btn{fill:var(--accent)}.bt{fill:#fff}
.ghost{fill:var(--card);stroke:var(--muted)}
.seg{fill:var(--box);stroke:var(--line)}.segsel{fill:var(--card);stroke:var(--muted)}
.can{fill:var(--accent);opacity:.75}
.chip{fill:var(--box);stroke:var(--line)}
.input{fill:var(--bg);stroke:var(--muted)}
.stamp{fill:none;stroke:var(--accent);stroke-width:1.5}.st{fill:var(--accent)}
.nav{fill:var(--box);stroke:var(--muted)}
.ln{stroke:var(--line)}
.crease{stroke:#3b82f6;stroke-dasharray:6 6;stroke-width:1.2;opacity:.7}
.dim{fill:#2f6fd6}
.dim-veil{fill:var(--bg);opacity:.35}
.t{fill:var(--fg)}.m{fill:var(--muted)}.a{fill:var(--accent)}
.mk{fill:#c0392b}.mkt{fill:#fff}
"""

if __name__ == "__main__":
    import json
    import sys
    out = {
        "a_home": a_inner_home(), "a_detail": a_inner_detail(), "a_outer": outer_home("A"),
        "b_home": b_inner_home(), "b_detail": b_inner_detail(), "b_outer": outer_home("B"),
        "css": CSS,
    }
    json.dump(out, sys.stdout, ensure_ascii=False)
