"""What community use costs on Cloudflare (C12), measured on the TEST Worker:
each request asks for an X-Test-Cost header (D1 rows read and written, R2
class A / B operations and bytes), and the time it took.

Three kinds of use:
  browse  — open the community: themes, one page of a theme's pictures, its
            30 thumbnails, one picture opened with its comments
  post    — post a picture: an upload, two pictures, the post
  repeat  — the same picture link opened again and again

    python3 tools/load_test.py            # prints per-action costs as JSON
The numbers feed project/capacity.md.
"""
import json, os, statistics, sys, time, uuid, urllib.request, urllib.error

env = {}
for line in open(os.path.expanduser("~/.cloudflare-koco.env")):
    if "=" in line:
        k, v = line.strip().split("=", 1); env[k] = v
BASE = "https://koco-community-test.sybbzb.workers.dev"
HERE = os.path.dirname(__file__)
PHOTO = open(os.path.join(HERE, "fixtures/test_photo.jpg"), "rb").read()
THUMB = open(os.path.join(HERE, "fixtures/test_thumb.jpg"), "rb").read()
RUN = uuid.uuid4().hex[:6]

def call(method, path, token=None, body=None, raw=None, full=None):
    h = {"x-test-login": env["TEST_LOGIN"], "x-test-cost": "1", "user-agent": "koco-load-test/1.0"}
    if token: h["authorization"] = "Bearer " + token
    if raw is not None: h["content-type"] = "image/jpeg"
    elif body is not None: h["content-type"] = "application/json"
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(full or BASE + path, data=data, method=method, headers=h)
    t = time.time()
    try:
        with urllib.request.urlopen(req) as r:
            text, cost, status = r.read(), r.headers.get("x-test-cost"), r.status
    except urllib.error.HTTPError as e:
        text, cost, status = e.read(), e.headers.get("x-test-cost"), e.code
    ms = (time.time() - t) * 1000
    out = json.loads(text) if text and text[:1] in b"{[" else None
    return status, out, (json.loads(cost) if cost else {}), ms

def add(total, c):
    for k, v in c.items(): total[k] = total.get(k, 0) + v
    total["requests"] = total.get("requests", 0) + 1

def session(name, admin=False):
    s, b, _, _ = call("POST", "/v1/test/session", body={"sub": f"load-{RUN}-{name}", "name": name, "admin": admin})
    call("POST", "/v1/me/rules", b["token"], body={"version": b["user"]["rulesCurrent"]})
    return b["token"]

# A theme with 40 approved pictures to browse.
U = session("U"); M = session("M", admin=True)
themes = call("GET", "/v1/themes")[1]
theme = themes[0]["id"]
def post_one(token):
    total = {}
    s, up, c, _ = call("POST", "/v1/uploads", token, body={}); add(total, c)
    for part, data in (("photo", PHOTO), ("thumb", THUMB)):
        s, _, c, _ = call("PUT", f"/v1/uploads/{up['uploadId']}/{part}", token, raw=data); add(total, c)
    s, p, c, _ = call("POST", "/v1/posts", token, body={"themeId": theme, "uploadId": up["uploadId"], "filmId": "portra400",
                                                        "clientId": uuid.uuid4().hex}); add(total, c)
    return p, total

posting = []
for i in range(5):
    p, cost = post_one(U); posting.append(cost)
    call("POST", f"/v1/admin/posts/{p['id']}/approve", M, body={})
posters = [session(f"P{k}") for k in range(3)]   # 20 posts a day each, at most
for i in range(35):
    p, _ = post_one(posters[i % 3]); call("POST", f"/v1/admin/posts/{p['id']}/approve", M, body={})

V = session("V")
browsing, latencies = [], []
for i in range(5):
    total = {}
    s, _, c, ms = call("GET", "/v1/themes", V); add(total, c); latencies.append(ms)
    s, page, c, ms = call("GET", f"/v1/themes/{theme}/posts", V); add(total, c); latencies.append(ms)
    for p in page["posts"]:
        s, _, c, ms = call("GET", "", full=p["thumbURL"]); add(total, c)
    first = page["posts"][0]
    s, _, c, _ = call("GET", "", full=first["photoURL"]); add(total, c)
    s, _, c, _ = call("GET", f"/v1/posts/{first['id']}/comments", V); add(total, c)
    s, _, c, _ = call("GET", "/v1/me/news", V); add(total, c)
    browsing.append(total)

repeat = []
for i in range(20):
    s, _, c, ms = call("GET", "", full=first["thumbURL"]); repeat.append(c)

def mean(rows):
    keys = sorted({k for r in rows for k in r})
    return {k: round(statistics.mean(r.get(k, 0) for r in rows), 1) for k in keys}

print(json.dumps({"post": mean(posting), "browse": mean(browsing), "repeat_one_picture": mean(repeat),
                  "pictures_in_theme": len(page["posts"]), "api_ms_median": round(statistics.median(latencies))}, indent=1))
