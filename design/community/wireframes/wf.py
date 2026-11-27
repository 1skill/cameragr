"""Wireframe primitives for the community redesign page (grey boxes + labels).

Wireframes only - not art. Colours come from the page's CSS variables so the
SVGs follow light/dark mode. Run make.py to rebuild index.html.
"""
from html import escape

DUO_W, DUO_H, DUO_R = 951, 669, 55
PH_W, PH_H, PH_R = 402, 874, 55


def t(x, y, s, size=13, cls="t", anchor="start", weight=None):
    w = f' font-weight="{weight}"' if weight else ""
    return (f'<text x="{x}" y="{y}" font-size="{size}" class="{cls}" '
            f'text-anchor="{anchor}"{w}>{escape(s)}</text>')


def box(x, y, w, h, label=None, cls="bx", size=12, r=6, lcls="m"):
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" class="{cls}"/>'
    if label:
        s += t(x + w / 2, y + h / 2 + size * 0.36, label, size, lcls, "middle")
    return s


def photo(x, y, w, h, cap=None, likes=None, note=None, cls="ph"):
    """Photo placeholder with a cross, optional caption strip and comment line."""
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" class="{cls}"/>'
    s += (f'<path d="M{x} {y}L{x+w} {y+h}M{x+w} {y}L{x} {y+h}" class="phx"/>')
    if cap:
        s += f'<rect x="{x}" y="{y+h-18}" width="{w}" height="18" class="cap"/>'
        s += t(x + 5, y + h - 5, cap, 10, "t")
        if likes is not None:
            s += t(x + w - 5, y + h - 5, f"♡{likes}", 10, "m", "end")
    if note:
        s += f'<rect x="{x}" y="{y+h+3}" width="{w}" height="17" rx="3" class="note"/>'
        s += t(x + 5, y + h + 15, note, 10, "a")
    return s


def tag(x, y, n):
    """Numbered red marker that points at a legend entry."""
    return (f'<circle cx="{x}" cy="{y}" r="9" class="mk"/>'
            + t(x, y + 4, str(n), 11, "mkt", "middle", 700))


def line(x1, y1, x2, y2, cls="ln"):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" class="{cls}"/>'


def duo(body, title):
    """Duo inner screen, open flat: 951x669, 55pt corners, long brass nav bar."""
    nav = box(155, 622, 640, 34, None, "nav", r=17)
    for i, n in enumerate(["相机", "胶卷", "社区", "设置"]):
        cx = 155 + 80 + i * 160
        nav += t(cx, 644, n, 13, "a" if n == "社区" else "m", "middle",
                 700 if n == "社区" else None)
    return (f'<svg viewBox="0 0 {DUO_W} {DUO_H}" role="img" aria-label="{escape(title)}">'
            f'<rect x="1" y="1" width="{DUO_W-2}" height="{DUO_H-2}" rx="{DUO_R}" class="fr"/>'
            f'{body}{nav}</svg>')


def phone(body, title):
    """Ordinary iPhone, portrait single page: 402x874, nav bar at the bottom."""
    nav = box(36, 800, 330, 32, None, "nav", r=16)
    for i, n in enumerate(["相机", "胶卷", "社区", "设置"]):
        cx = 36 + 41 + i * 82.5
        nav += t(cx, 821, n, 12, "a" if n == "社区" else "m", "middle",
                 700 if n == "社区" else None)
    return (f'<svg viewBox="0 0 {PH_W} {PH_H}" role="img" aria-label="{escape(title)}">'
            f'<rect x="1" y="1" width="{PH_W-2}" height="{PH_H-2}" rx="{PH_R}" class="fr"/>'
            f'<rect x="146" y="12" width="110" height="30" rx="15" class="isl"/>'
            f'{body}{nav}</svg>')


def grid(x, y, cols, rows, w, h, gap, caps, notes=None, likes=None):
    s, k = "", 0
    for r in range(rows):
        for c in range(cols):
            cap = caps[k % len(caps)] if caps else None
            nt = notes.get(k) if notes else None
            lk = (likes[k % len(likes)] if likes else None)
            s += photo(x + c * (w + gap), y + r * (h + gap + (20 if notes else 0)),
                       w, h, cap, lk, nt)
            k += 1
    return s
