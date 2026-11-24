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
    h = {"x-test-login": env["TEST_LOGIN"], "user-agent": "koco-worker-test/1.0"}   # Python's own is refused (1010)
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

def session(name, admin=False, tz="UTC", rules=True):
    s, b = call("POST", "/v1/test/session", body={"sub": f"{RUN}-{name}", "name": name, "admin": admin, "tz": tz})
    assert s == 200, (s, b)
    if rules: call("POST", "/v1/me/rules", b["token"], body={"version": b["user"]["rulesCurrent"]})
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

print("rules and names")
N, n_id = session("N", rules=False)
s, b0 = post(N, theme)
check(s == 428, "no post before agreeing to the rules")
check(call("POST", "/v1/me/rules", N, body={"version": 99})[0] == 409, "agreeing to a wrong version refused")
call("POST", "/v1/me/rules", N, body={"version": call("GET", "/v1/me", N)[1]["rulesCurrent"]})
check(post(N, theme)[0] == 201, "agreed: posting works")
check(call("PATCH", "/v1/me", N, body={"name": "  New   name "})[1]["profile"]["name"] == "New name", "renamed (spaces tidied)")
check(call("PATCH", "/v1/me", N, body={"name": "x" * 31})[0] == 422, "a name over 30 refused")

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

print("two posts approved at once on the third day")
K, k_id = session("K")
kb = T0 + timedelta(days=60)
for i in range(2):
    s, p = post(K, theme, now=kb + timedelta(days=i))
    call("POST", f"/v1/admin/posts/{p['id']}/approve", M, body={}, now=kb + timedelta(days=i, minutes=5))
third = kb + timedelta(days=2)
s, k1 = post(K, theme, now=third); s, k2 = post(K, theme, now=third)
results = []
threads = [threading.Thread(target=lambda q=q: results.append(call("POST", f"/v1/admin/posts/{q['id']}/approve", M, body={}, now=third + timedelta(minutes=5)))) for q in (k1, k2)]
[t.start() for t in threads]; [t.join() for t in threads]
check(len(d1(f"SELECT 1 FROM eligibility WHERE user_id = '{k_id}' AND milestone = 3")) == 1, "the 3-day milestone recorded")

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

print("comments")
G, g_id = session("G"); H, h_id = session("H")
s, pg = post(G, theme); call("POST", f"/v1/admin/posts/{pg['id']}/approve", M, body={})
cid = uuid.uuid4().hex
s, c1 = call("POST", f"/v1/posts/{pg['id']}/comments", H, body={"text": "Lovely light", "clientId": cid})
check(s == 201 and c1["state"] == "pending", "a comment waits for approval")
check(call("POST", f"/v1/posts/{pg['id']}/comments", H, body={"text": "Lovely light", "clientId": cid})[1]["id"] == c1["id"], "sent again: the same comment")
check(call("POST", f"/v1/posts/{pg['id']}/comments", H, body={"text": "x" * 121, "clientId": uuid.uuid4().hex})[0] == 422, "over 120 characters refused")
check(call("POST", f"/v1/posts/{pg['id']}/comments", H, body={"text": "see https://spam.example", "clientId": uuid.uuid4().hex})[0] == 422, "links refused")
s, l = call("GET", f"/v1/posts/{pg['id']}/comments", G)
check(not l["comments"], "G doesn't see H's waiting comment")
s, l = call("GET", f"/v1/posts/{pg['id']}/comments", H)
check([c["id"] for c in l["comments"]] == [c1["id"]], "H sees it, waiting")
check(call("POST", f"/v1/admin/comments/{c1['id']}/approve", M, body={})[0] == 204, "approved")
s, news = call("GET", "/v1/me/news", G)
check(any(c["id"] == c1["id"] for c in news["comments"]), "G is told of the new comment")
call("POST", "/v1/me/news/seen", G, body={})
check(call("GET", "/v1/me/news", G)[1]["count"] == 0, "seen: nothing new")
call("PUT", f"/v1/blocks/{h_id}", G)
check(not call("GET", f"/v1/posts/{pg['id']}/comments", G)[1]["comments"], "G blocked H: H's comment hidden from G")
check(call("POST", f"/v1/posts/{pg['id']}/comments", H, body={"text": "hi", "clientId": uuid.uuid4().hex})[0] == 403, "and H can't write under G's picture")
call("DELETE", f"/v1/blocks/{h_id}", G)
check(call("DELETE", f"/v1/comments/{c1['id']}", G)[0] == 204, "the picture's author can delete a comment under it")
s, c2 = call("POST", f"/v1/posts/{pg['id']}/comments", H, body={"text": "Again", "clientId": uuid.uuid4().hex})
call("POST", f"/v1/admin/comments/{c2['id']}/approve", M, body={})
for who in ("Q1", "Q2", "Q3"):
    t, _ = session(who); call("POST", f"/v1/comments/{c2['id']}/report", t, body={"reason": "spam"})
check(d1(f"SELECT state FROM comments WHERE id = '{c2['id']}'")[0]["state"] == "hidden", "three reports hide a comment")
s, rep = call("GET", "/v1/admin/comments?state=reported", M)
check(any(c["id"] == c2["id"] for c in rep), "the admin sees it reported")
call("POST", f"/v1/admin/posts/{pg['id']}/hide", M, body={})
call("POST", f"/v1/admin/comments/{c2['id']}/restore", M, body={})
check(call("GET", f"/v1/posts/{pg['id']}/comments", H)[0] == 404 or not call("GET", f"/v1/posts/{pg['id']}/comments", H)[1].get("comments"), "a hidden picture's comments are gone")
s, me_ = call("GET", "/v1/me", H)
check(me_["streak"] == 0, "comments count no day")
call("POST", "/v1/me/news/seen", G, body={})
call("POST", f"/v1/admin/posts/{pg['id']}/restore", M, body={})
s, c3 = call("POST", f"/v1/posts/{pg['id']}/comments", H, body={"text": "Hidden?", "clientId": uuid.uuid4().hex})
call("POST", f"/v1/admin/comments/{c3['id']}/approve", M, body={})
call("POST", f"/v1/admin/posts/{pg['id']}/hide", M, body={})
check(not any(c["postId"] == pg["id"] for c in call("GET", "/v1/me/news", G)[1]["comments"]), "a hidden picture's comments aren't news")

print("one's own")
W, w_id = session("W")
s, w1 = post(W, theme); s, w2 = post(W, theme)
call("POST", f"/v1/admin/posts/{w1['id']}/approve", M, body={})
call("POST", f"/v1/admin/posts/{w2['id']}/hide", M, body={})
s, mine = call("GET", "/v1/me/mine", W)
states = {p["id"]: p["state"] for p in mine["posts"]}
check(states.get(w1["id"]) == "public" and states.get(w2["id"]) == "hidden", "one's own pictures with their states (turned down included)")
s, wc = call("POST", f"/v1/posts/{w1['id']}/comments", W, body={"text": "mine", "clientId": uuid.uuid4().hex})
check(any(c["id"] == wc["id"] and c["state"] == "pending" for c in call("GET", "/v1/me/mine", W)[1]["comments"]), "and one's waiting comments")

print("mail to the admins")
X, _ = session("X")
s, px = post(A, theme); call("POST", f"/v1/admin/posts/{px['id']}/approve", M, body={})
call("POST", "/v1/test/outbox", body={"failNext": 2})
for who in ("X1", "X2"):
    t, _ = session(who); call("POST", f"/v1/posts/{px['id']}/report", t, body={"reason": "spam"})
box = call("POST", "/v1/test/outbox", body={})[1]
rep = [r for r in box if r["kind"] == "report" and f"picture {px['id']}" in r["body"]]
check(len(rep) == 1 and rep[0]["count"] >= 2, "two reports in an hour: one message")
check(rep and rep[0]["state"] == "pending" and rep[0]["attempts"] >= 1, "a failed send waits to be tried again")
later = datetime.now(timezone.utc) + timedelta(hours=1)
for i in range(4):   # each try later than the longest wait (six hours)
    box = call("POST", "/v1/test/outbox", body={}, now=later + timedelta(hours=7 * i))[1]
rep = [r for r in box if r["id"] == rep[0]["id"]]
check(rep and rep[0]["state"] == "sent", "then sent")
mails = d1(f"SELECT body FROM test_mail WHERE body LIKE '%picture {px['id']}%'")
check(len(mails) >= 1 and sum(m["body"].count(px["id"]) for m in mails) == 2, "the inbox holds both reports, each once")
t3, _ = session("X3"); call("POST", f"/v1/posts/{px['id']}/report", t3, body={"reason": "hate"})
call("POST", f"/v1/posts/{px['id']}/report", t3, body={"reason": "hate"})   # the same again: no new report
for i in range(4): call("POST", "/v1/test/outbox", body={}, now=later + timedelta(hours=30 + 7 * i))
mails = d1(f"SELECT body FROM test_mail WHERE body LIKE '%picture {px['id']}%'")
check(sum(m["body"].count(px["id"]) for m in mails) == 3, "a later report goes alone, the earlier ones not again")
call("POST", "/v1/test/outbox", body={"failNext": 1000})   # every send fails for now
s, py = post(A, theme); call("POST", f"/v1/admin/posts/{py['id']}/approve", M, body={})   # a fresh one (px is hidden by now)
t4, _ = session("X4"); call("POST", f"/v1/posts/{py['id']}/report", t4, body={"reason": "other"})
for i in range(9): call("POST", "/v1/test/outbox", body={}, now=later + timedelta(days=3, hours=7 * i))
failed = call("GET", "/v1/admin/outbox", M)[1]
check(any(f["state"] == "failed" and f["attempts"] >= 8 for f in failed), "eight failures: given up, listed for the admin")
call("POST", "/v1/test/outbox", body={"failNext": 0})
fid = failed[0]["id"]
check(call("POST", f"/v1/admin/outbox/{fid}/retry", M, body={})[0] == 204, "sent again by hand")
call("POST", "/v1/test/outbox", body={})
check(not any(f["id"] == fid for f in call("GET", "/v1/admin/outbox", M)[1]), "and it went")
s, st = call("GET", "/v1/admin/status", M)
check(s == 200 and "waiting" in st["pictures"] and "pending" in st["mail"], "the admin's status: queue and mail")

print("rewards")
F, f_id = session("F")
base = T0 + timedelta(days=40)
def three_days(token):
    for i in range(3):
        when = base + timedelta(days=i)
        s, p = post(token, theme, now=when)
        call("POST", f"/v1/admin/posts/{p['id']}/approve", M, body={}, now=when + timedelta(minutes=5))
    return p
check(call("POST", "/v1/rewards/3/claim", F, body={})[0] == 409, "not reached: can't claim")
pf = three_days(F)
s, got = call("POST", "/v1/rewards/3/claim", F, body={})
check(s == 200 and got.get("filmId") == "portra400", "three days: the 3-day roll")
check(call("POST", "/v1/rewards/3/claim", F, body={})[1].get("filmId") == "portra400", "claiming again: the same roll")
check(call("POST", "/v1/rewards/7/claim", F, body={})[0] == 409, "7 days not reached")
L1, l_id = session("L1"); three_days(L1)
d1(f"UPDATE users SET leaving_at = '2026-01-01T00:00:00Z' WHERE id = '{l_id}'")   # as if deleting were under way
check(call("POST", "/v1/rewards/3/claim", L1, body={})[0] == 409, "no claim while the account is being deleted")
V, v_id = session("V")
three_days(V)
s, got = call("POST", "/v1/rewards/3/claim", V, body={"voucher": True})
check(s == 200 and got.get("filmId") == "voucher", "already has the roll: a voucher instead")
check(call("POST", "/v1/rewards/3/redeem", V, body={"filmId": "dusk200"})[0] == 400, "a voucher can't become a limited roll")
check(call("POST", "/v1/rewards/3/redeem", V, body={"filmId": "nosuchfilm"})[0] == 400, "nor an unknown one")
check(call("GET", "/v1/me", V)[1]["rewards"][0]["filmId"] == "voucher", "a refused exchange keeps the voucher")
s, got = call("POST", "/v1/rewards/3/redeem", V, body={"filmId": "cine500t"})
check(s == 200 and got.get("filmId") == "cine500t", "the voucher becomes a roll")
check(call("POST", "/v1/rewards/3/redeem", V, body={"filmId": "c200"})[0] == 409, "only once")

print("leaving")
s, f_view = call("GET", f"/v1/posts/{pf['id']}", F)
check(call("DELETE", "/v1/me", F)[0] == 200, "leave")
check(call("GET", "", full_url=f_view["thumbURL"])[0] == 404, "their pictures are gone")
check(len(d1(f"SELECT 1 FROM users WHERE id = '{f_id}'")) == 0, "their account is gone")
F2, _ = session("F")                     # the same Apple account, back
three_days(F2)
check(call("POST", "/v1/rewards/3/claim", F2, body={})[0] == 409, "rebuilt account: the roll isn't given again")

print()
print("all passed" if not failures else f"{len(failures)} failed")
sys.exit(1 if failures else 0)
