"""End-to-end checks of the community Worker, through its real routes, on the
TEST Worker only (koco-community-test: its own D1 and R2, test sign-in on).
Run before deploying the real one (retro 7, C2-test):

    python3 tools/cf_deploy.py --test --migrate --schema   # deploy the test Worker
    python3 tools/worker_test.py

Never points at the real Worker: the test sign-in exists only where the
TEST_LOGIN secret is set. Secrets are read from ~/.cloudflare-koco.env and
never printed.
"""
import json, os, subprocess, sys, threading, uuid, urllib.request, urllib.error
from datetime import datetime, timedelta, timezone

env = {}
for line in open(os.path.expanduser("~/.cloudflare-koco.env")):
    if "=" in line:
        k, v = line.strip().split("=", 1); env[k] = v
if "TEST_LOGIN" not in env:
    sys.exit("no test Worker yet: run tools/cf_deploy.py --test --migrate --schema first")
BASE = os.environ.get("KOCO_TEST_BASE", "https://koco-community-test.sybbzb.workers.dev")
assert "test" in BASE, "only the test Worker"
HERE = os.path.dirname(__file__)
PHOTO = open(os.path.join(HERE, "fixtures/test_photo.jpg"), "rb").read()
THUMB = open(os.path.join(HERE, "fixtures/test_thumb.jpg"), "rb").read()
RUN = uuid.uuid4().hex[:6]           # this run's accounts and theme, apart from earlier runs
T0 = datetime(2027, 3, 10, 12, 0, tzinfo=timezone.utc)

failures = []
def check(ok, what):
    print(("  ok   " if ok else "  FAIL ") + what)
    if not ok: failures.append(what)

def call(method, path, token=None, body=None, raw=None, now=None, full_url=None):
    h = {"x-test-login": env["TEST_LOGIN"]}
    if token: h["authorization"] = "Bearer " + token
    if now: h["x-test-now"] = now.isoformat().replace("+00:00", "Z")
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    if raw is not None: h["content-type"] = "image/jpeg"
    elif body is not None: h["content-type"] = "application/json"
    req = urllib.request.Request(full_url or BASE + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req) as r:
            text = r.read()
            return r.status, (json.loads(text) if text and r.headers.get("content-type", "").startswith("application/json") else text)
    except urllib.error.HTTPError as e:
        text = e.read()
        try: return e.code, json.loads(text)
        except Exception: return e.code, text

def d1(statement):
    out = subprocess.run([sys.executable, os.path.join(HERE, "cf_deploy.py"), "--test", "--sql", statement],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out.strip().splitlines()[-1])[0]

def session(name, admin=False, tz="UTC"):
    s, b = call("POST", "/v1/test/session", body={"sub": f"{RUN}-{name}", "name": name, "admin": admin, "tz": tz})
    assert s == 200, (s, b)
    return b["token"], b["user"]["profile"]["id"]

def upload(token, now=None):
    s, b = call("POST", "/v1/uploads", token, body={}, now=now)
    assert s == 200, (s, b)
    up = b["uploadId"]
    assert call("PUT", f"/v1/uploads/{up}/photo", token, raw=PHOTO, now=now)[0] == 204
    assert call("PUT", f"/v1/uploads/{up}/thumb", token, raw=THUMB, now=now)[0] == 204
    return up

def post(token, theme, now=None, client=None):
    up = upload(token, now)
    return call("POST", "/v1/posts", token, now=now,
                body={"themeId": theme, "uploadId": up, "filmId": "portra400", "clientId": client or uuid.uuid4().hex})

print(f"Worker: {BASE}  run {RUN}")
theme = f"test-{RUN}"
d1(f"""INSERT INTO themes (id, kind, starts_at, ends_at, title, prompt) VALUES ('{theme}', 'daily',
   '2020-01-01T00:00:00Z', '2099-01-01T00:00:00Z', '{{"en":"Test"}}', '{{"en":"Test"}}')""")

print("access")
check(call("GET", "/v1/health")[0] == 200, "health")
check(call("GET", "/v1/me")[0] == 401, "signed out: 401")
A, a_id = session("A"); B, b_id = session("B"); M, m_id = session("M", admin=True)
check(call("GET", "/v1/admin/queue", A)[0] == 403, "not an admin: admin routes refused")

print("uploads")
s, b = call("POST", "/v1/uploads", A, body={}); up = b["uploadId"]
check(call("PUT", f"/v1/uploads/{up}/photo", A, raw=b"\xff\xd8\xff" + b"\0" * 200 + b"\xff\xd9")[0] == 415, "fake JPEG refused")
check(call("PUT", f"/v1/uploads/{up}/thumb", A, raw=PHOTO)[0] in (413, 415), "a full picture as thumbnail refused")
check(call("PUT", f"/v1/uploads/{up}/photo", B, raw=PHOTO)[0] == 404, "someone else's upload refused")

print("posting once")
up = upload(A); cid = uuid.uuid4().hex
body = {"themeId": theme, "uploadId": up, "filmId": "portra400", "clientId": cid}
results = []
threads = [threading.Thread(target=lambda: results.append(call("POST", "/v1/posts", A, body=body))) for _ in range(5)]
[t.start() for t in threads]; [t.join() for t in threads]
ids = {r[1]["id"] for r in results if r[0] in (200, 201)}
check(len(ids) == 1, f"five retries at once make one post ({len(ids)})")
p1 = ids.pop()
check(d1(f"SELECT count(*) AS n FROM posts WHERE client_id = '{cid}'")[0]["n"] == 1, "one row in the database")

print("waiting for approval")
s, page = call("GET", f"/v1/themes/{theme}/posts", B)
check(all(p["id"] != p1 for p in page["posts"]), "B doesn't see A's waiting post")
s, page = call("GET", f"/v1/themes/{theme}/posts", A)
check(any(p["id"] == p1 and p["state"] == "pending" for p in page["posts"]), "A sees it, waiting")
check(call("GET", f"/v1/posts/{p1}", B)[0] == 404, "B can't open it")
check(call("PUT", f"/v1/posts/{p1}/like", B)[0] == 404, "nor like it")

print("approving, at once and across midnight")
night = [T0.replace(hour=23, minute=59, second=59), T0 + timedelta(hours=12, seconds=1)]
results = []
threads = [threading.Thread(target=lambda n=n: results.append(call("POST", f"/v1/admin/posts/{p1}/approve", M, body={}, now=n))) for n in night * 2]
[t.start() for t in threads]; [t.join() for t in threads]
days = d1(f"SELECT day FROM checkins WHERE user_id = '{a_id}'")
check(len(days) == 1, f"four approvals at once count one day ({len(days)})")
s, page = call("GET", f"/v1/themes/{theme}/posts", B)
check(any(p["id"] == p1 for p in page["posts"]), "approved: B sees it")
check(len(d1(f"SELECT id FROM admin_log WHERE target = '{p1}'")) >= 1, "approval logged")

print("days in a row, milestones kept")
C, c_id = session("C")
for i in range(3):
    when = T0 + timedelta(days=i)
    s, p = post(C, theme, now=when)
    call("POST", f"/v1/admin/posts/{p['id']}/approve", M, body={}, now=when + timedelta(minutes=5))
s, me = call("GET", "/v1/me", C, now=T0 + timedelta(days=2, hours=1))
check(me["streak"] == 3, f"three days approved: streak 3 ({me['streak']})")
check(len(d1(f"SELECT 1 FROM eligibility WHERE user_id = '{c_id}' AND milestone = 3")) == 1, "3-day milestone recorded")

print("the one-hour rule")
D, d_id = session("D")
day = T0 + timedelta(days=20)
s, q1 = post(D, theme, now=day); s, q2 = post(D, theme, now=day)
for q in (q1, q2): call("POST", f"/v1/admin/posts/{q['id']}/approve", M, body={}, now=day + timedelta(minutes=1))
call("POST", f"/v1/admin/posts/{q1['id']}/hide", M, body={}, now=day + timedelta(minutes=2))
results = []
threads = [threading.Thread(target=lambda q=q: results.append(call("DELETE", f"/v1/posts/{q['id']}", D, now=day + timedelta(minutes=10)))) for q in (q1, q2)]
[t.start() for t in threads]; [t.join() for t in threads]
check(len(d1(f"SELECT day FROM checkins WHERE user_id = '{d_id}'")) == 0, "both deleted within the hour (one hidden first, at once): the day goes")
s, q3 = post(D, theme, now=day + timedelta(days=1))
call("POST", f"/v1/admin/posts/{q3['id']}/approve", M, body={}, now=day + timedelta(days=1, minutes=1))
call("DELETE", f"/v1/posts/{q3['id']}", D, now=day + timedelta(days=1, hours=2))
check(len(d1(f"SELECT day FROM checkins WHERE user_id = '{d_id}'")) == 1, "deleted after two hours: the day stays")

print("hidden pictures")
s, a_view = call("GET", f"/v1/posts/{p1}", B)
check(call("GET", "", full_url=a_view["thumbURL"])[0] == 200, "B's link works while public")
call("POST", f"/v1/admin/posts/{p1}/hide", M, body={})
check(call("GET", "", full_url=a_view["thumbURL"])[0] == 404, "hidden: B's link dies at once")
s, m_view = call("GET", f"/v1/posts/{p1}", M)
check(call("GET", "", full_url=m_view["thumbURL"])[0] == 200, "the admin's link still shows it")
forged = a_view["thumbURL"].replace("adm=0", "adm=1")
check(call("GET", "", full_url=forged)[0] == 403, "a link changed by hand is refused")

print("banning")
s, pb = post(B, theme); call("POST", f"/v1/admin/posts/{pb['id']}/approve", M, body={})
check(call("POST", f"/v1/admin/users/{b_id}/ban", M, body={"reason": "test"})[0] == 204, "ban")
check(call("GET", "/v1/me", B)[0] in (401, 403), "banned: B's session ends at once")
check(call("POST", f"/v1/admin/posts/{pb['id']}/restore", M, body={})[0] == 409, "a banned person's post can't be restored")
check(call("POST", f"/v1/admin/users/{m_id}/ban", M, body={})[0] == 409, "an admin can't be banned")
call("POST", f"/v1/admin/users/{b_id}/unban", M, body={})

print("reports")
E, e_id = session("E")
check(call("POST", f"/v1/posts/{pb['id']}/report", E, body={"reason": "spam"})[0] in (204, 404), "a report (hidden post: 404 is right too)")
s, pc = post(C, theme); call("POST", f"/v1/admin/posts/{pc['id']}/approve", M, body={})
for who in ("R1", "R2", "R3"):
    t, _ = session(who); call("POST", f"/v1/posts/{pc['id']}/report", t, body={"reason": "spam"})
check(d1(f"SELECT state FROM posts WHERE id = '{pc['id']}'")[0]["state"] == "hidden", "three reports hide a post")
s, reps = call("GET", "/v1/admin/reports", M)
check(any(r["post"]["id"] == pc["id"] for r in reps), "the admin sees the reports")

print("leaving")
F, f_id = session("F")
s, pf = post(F, theme); call("POST", f"/v1/admin/posts/{pf['id']}/approve", M, body={})
s, f_view = call("GET", f"/v1/posts/{pf['id']}", F)
check(call("DELETE", "/v1/me", F)[0] == 200, "leave")
check(call("GET", "", full_url=f_view["thumbURL"])[0] == 404, "their pictures are gone")
check(len(d1(f"SELECT 1 FROM users WHERE id = '{f_id}'")) == 0, "their account is gone")
# Rebuilt accounts can't claim again: checked with C5's claim route.

print()
print("all passed" if not failures else f"{len(failures)} failed")
sys.exit(1 if failures else 0)
