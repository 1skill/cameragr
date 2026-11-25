import urllib.parse
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

def sweep_old_runs(hours=2):
    """Earlier runs' accounts (and with them their posts, comments, likes…)
    are cleared from the test database first, so it doesn't keep growing and
    every run's reads stay small (user 11/25: the free daily reads nearly ran out)."""
    cutoff = (datetime.now(timezone.utc) - timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%S")
    for _ in range(40):
        d1(f"DELETE FROM users WHERE id IN (SELECT id FROM users WHERE created_at < '{cutoff}' LIMIT 100)")
        if d1(f"SELECT count(*) AS n FROM users WHERE created_at < '{cutoff}'")[0]["n"] == 0: break
    d1(f"DELETE FROM test_mail WHERE at < '{cutoff}'")

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

print("sweeping earlier runs")
sweep_old_runs()
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
nt = uuid.uuid4().hex[:4]
check(call("PATCH", "/v1/me", N, body={"name": f"  New   {nt} "})[1].get("profile", {}).get("name") == f"New {nt}", "renamed (spaces tidied)")
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
s, own = call("POST", f"/v1/posts/{p1}/comments", A, body={"text": "mine, before review", "clientId": uuid.uuid4().hex})
check(s == 201, "the author can comment on their own picture in review (nobody should notice the review)")
s, mine_view = call("GET", f"/v1/posts/{p1}", A)
check(call("GET", "", full_url=mine_view["thumbURL"])[0] == 200, "the author's own picture loads while in review")

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

print("own posts by id, any age (retro 10)")
s, got = call("GET", f"/v1/me/posts?ids={p1}", A)
check(s == 200 and [p["id"] for p in got["posts"]] == [p1], "A gets her own post by id")
s, got = call("GET", f"/v1/me/posts?ids={p1}", B)
check(s == 200 and got["posts"] == [], "B doesn't get A's post that way")
check(call("GET", "/v1/me/posts?ids=" + ",".join(str(i) for i in range(21)), A)[0] == 400, "more than twenty refused")
print("everyone's latest, and by film (C18)")
def finds(path, pid, pages=20):
    cursor = None
    for _ in range(pages):
        q = path + ("&" if "?" in path else "?") + f"limit=60" + (f"&cursor={urllib.parse.quote(cursor)}" if cursor else "")
        s, page = call("GET", q, B)
        if s != 200: return False
        if any(p["id"] == pid for p in page["posts"]): return True
        cursor = page.get("next")
        if not cursor: return False
    return False
check(finds("/v1/posts", p1), "site-wide latest has it")
check(finds("/v1/posts?film=portra400", p1), "its film's room has it")
check(not finds("/v1/posts?film=cine500t", p1), "another film's room doesn't")

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
# One's own picture approved is never news (C16: the review isn't felt).
s, mine_news = call("GET", "/v1/me/news", A)
check(s == 200 and mine_news.get("postsApproved", 0) == 0 and mine_news["count"] == len(mine_news["comments"]),
      "own approvals aren't counted in news")
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
Bd, _ = session("Bd"); three_days(Bd)
s, got = call("POST", "/v1/rewards/3/claim", Bd, body={"badge": True})
check(s == 200 and got.get("filmId") == "badge", "owns every roll: the keepsake badge")
Vb, _ = session("Vb"); three_days(Vb)
call("POST", "/v1/rewards/3/claim", Vb, body={"voucher": True})
s, got = call("POST", "/v1/rewards/3/redeem", Vb, body={"filmId": "badge"})
check(s == 200 and got.get("filmId") == "badge", "a voucher with nothing left to become: the badge")

print("names, one to a person (S3)")
tag = uuid.uuid4().hex[:4]
Q, q_id = session(f"Q{tag}"); R, r_id = session(f"R{tag}")
s, pa = post(A, theme); pa = pa["id"]
call("POST", f"/v1/admin/posts/{pa}/approve", M, body={})
want = f"Ann{tag}"
s, mine_me = call("PATCH", "/v1/me", A, body={"name": want})
check(s == 200 and mine_me["profile"]["name"] == want, f"A asks for {want} and sees it at once ({s})")
s, seen = call("GET", f"/v1/posts/{pa}", Q)
check(s == 200 and seen["author"]["name"] != want, f"another still sees the old name while it waits ({s} {str(seen)[:120]})")
s, _ = call("PATCH", "/v1/me", R, body={"name": f" ANN {tag.upper()} "})
check(s == 409, f"the same name, other spacing and case, is taken ({s})")
check(call("PATCH", "/v1/me", R, body={"name": "Koco Fan"})[0] == 422, "a house word refused")
check(call("PATCH", "/v1/me", R, body={"name": "x"})[0] == 422, "one letter refused")
check(call("PATCH", "/v1/me", R, body={"name": "abcdefghijklm"})[0] == 422, "thirteen letters refused")
s, pend = call("GET", "/v1/admin/names", M)
check(s == 200 and any(n["userId"] == a_id and n["requested"] == want for n in pend["names"]), "it waits in the admin list")
ver = next(n["version"] for n in pend["names"] if n["userId"] == a_id)
check(call("POST", f"/v1/admin/names/{a_id}/approve", M, body={"version": "old"})[0] == 409, "a decision on another request than the one seen is refused")
check(call("POST", f"/v1/admin/names/{a_id}/approve", M, body={"version": ver})[0] == 204, "approved")
s, seen = call("GET", f"/v1/posts/{pa}", Q)
check(s == 200 and seen["author"]["name"] == want, "approved: others see it")
check(call("PATCH", "/v1/me", A, body={"name": f"Bee{tag}"})[0] == 429, "again within thirty days: not yet")
s, c_me = call("PATCH", "/v1/me", R, body={"name": f"Cat{tag}"})
c_old = call("GET", "/v1/me", R)[1]
c_id_ = c_me["profile"]["id"]
c_ver = next(n["version"] for n in call("GET", "/v1/admin/names", M)[1]["names"] if n["userId"] == c_id_)
check(call("POST", f"/v1/admin/names/{c_id_}/reject", M, body={"version": c_ver})[0] == 204, "turned down")
s, c_after = call("GET", "/v1/me", R)
check(s == 200 and c_after["profile"]["name"] == f"Cat{tag}" and not c_after.get("needsRename"), "turned down: they still see it themselves, nothing said")
s, r_post = post(R, theme); call("POST", f"/v1/admin/posts/{r_post['id']}/approve", M, body={})
check(call("GET", f"/v1/posts/{r_post['id']}", Q)[1]["author"]["name"] != f"Cat{tag}", "others never see the turned-down name")
r_own = call("GET", f"/v1/posts/{r_post['id']}", R)[1]
check(r_own["author"]["name"] == f"Cat{tag}", "on their own picture too, they see it")
rc = call("POST", f"/v1/posts/{r_post['id']}/comments", R, body={"text": "mine", "clientId": uuid.uuid4().hex})[1]
check(rc["author"]["name"] == f"Cat{tag}", "and on their own comment")
check(call("GET", f"/v1/users/{r_id}", R)[1]["name"] == f"Cat{tag}", "and on their own page")
check(call("GET", f"/v1/users/{r_id}", Q)[1]["name"] != f"Cat{tag}", "others see the approved name on the page")
check(call("PATCH", "/v1/me", R, body={"name": f"Cub{tag}"})[0] == 200, "a refusal doesn't start the thirty days")
check(d1(f"SELECT count(*) AS n FROM names WHERE name_norm = 'cat{tag}'")[0]["n"] == 0, "and the name let go")
r_ = call("PATCH", "/v1/me", Q, body={"name": f"Cat{tag}"}); check(r_[0] == 200, f"someone else can now ask for it {r_}")
# The first real name after the placeholder (Apple's, here) isn't a change:
# approved, they may still change it at once; the next approved change counts.
W, w_id = session(f"Wq{tag}")
d1(f"DELETE FROM names WHERE user_id = '{w_id}'")
d1(f"UPDATE users SET name = 'Koco ' || substr(id, 1, 6), name_norm = NULL, name_changed_at = NULL WHERE id = '{w_id}'")
check(call("PATCH", "/v1/me", W, body={"name": f"Wen{tag}"})[0] == 200, "the placeholder: a first real name asked for")
w_ver = next(n_["version"] for n_ in call("GET", "/v1/admin/names", M)[1]["names"] if n_["userId"] == w_id)
call("POST", f"/v1/admin/names/{w_id}/approve", M, body={"version": w_ver})
s, w_me = call("PATCH", "/v1/me", W, body={"name": f"Wil{tag}"})
check(s == 200 and w_me["profile"]["name"] == f"Wil{tag}", f"after the first name, changed again at once and seen at once ({s})")
w_ver = next(n_["version"] for n_ in call("GET", "/v1/admin/names", M)[1]["names"] if n_["userId"] == w_id)
call("POST", f"/v1/admin/names/{w_id}/approve", M, body={"version": w_ver})
check(call("PATCH", "/v1/me", W, body={"name": f"Wyn{tag}"})[0] == 429, "a real change approved: thirty days from when it was asked")
chg = d1(f"SELECT name_changed_at FROM users WHERE id = '{w_id}'")[0]["name_changed_at"]
check(chg == w_ver, "counted from the request, not the approval")
# Accounts from before with the same name: the one who signed up first keeps it,
# even when the later one signs in first.
D, d_id = session(f"Dup{tag}")
E, e_id = session(f"Dup{tag}x")
d1(f"DELETE FROM names WHERE user_id IN ('{d_id}', '{e_id}')")
d1(f"UPDATE users SET name = 'Dup{tag}', name_norm = NULL, must_rename = 0 WHERE id IN ('{d_id}', '{e_id}')")
d1(f"UPDATE users SET created_at = '2020-01-01T00:00:00.000Z' WHERE id = '{d_id}'")
s, e_again = call("POST", "/v1/test/session", body={"sub": f"{RUN}-Dup{tag}x"})
check(s == 200 and not e_again["user"].get("needsRename"), "the later one, signing in first, holds it for now")
s, d_again = call("POST", "/v1/test/session", body={"sub": f"{RUN}-Dup{tag}"})
check(s == 200 and not d_again["user"].get("needsRename"), "the earlier one signs in: it is theirs")
s, e_me = call("GET", "/v1/me", e_again["token"])
check(s == 200 and e_me.get("needsRename") is True, "and the later one is asked to choose another name")
check(call("PATCH", "/v1/me", e_again["token"], body={"name": f"Eve{tag}"})[0] == 200, "and may at once")
for _ in range(200):
    r_s = call("POST", "/v1/admin/names/settle", M, body={})
    if r_s[0] != 200 or r_s[1]["left"] == 0: break
check(r_s[0] == 200 and r_s[1]["left"] == 0, f"every older account settled, ten at a time {r_s}")

print("following (S1)")
F1, f1_id = session(f"F1{uuid.uuid4().hex[:4]}"); F2, f2_id = session(f"F2{uuid.uuid4().hex[:4]}")
s, fp = post(F2, theme); fp = fp["id"]
call("POST", f"/v1/admin/posts/{fp}/approve", M, body={})
check(call("PUT", f"/v1/follows/{f1_id}", F1)[0] == 400, "not oneself")
check(call("PUT", f"/v1/follows/{f2_id}", F1)[0] == 204, "F1 follows F2")
check(call("PUT", f"/v1/follows/{f2_id}", F1)[0] == 204, "again: nothing changes")
check(d1(f"SELECT count(*) AS n FROM follows WHERE follower = '{f1_id}'")[0]["n"] == 1, "one row")
s, fl = call("GET", "/v1/me/following", F1)
check(s == 200 and [p_["id"] for p_ in fl["people"]] == [f2_id], "F1's list has F2")
s, fr = call("GET", "/v1/me/followers", F2)
check(s == 200 and [p_["id"] for p_ in fr["people"]] == [f1_id], "F2 sees F1 among followers")
s, feed = call("GET", "/v1/feed/following", F1)
check(s == 200 and any(p_["id"] == fp for p_ in feed["posts"]), "F2's picture in F1's following feed")
s, own = post(F1, theme)
s, feed = call("GET", "/v1/feed/following", F1)
check(all(p_["author"]["id"] in (f2_id,) for p_ in feed["posts"]), "only people followed, not one's own")
check("followers" not in json.dumps(call("GET", f"/v1/posts/{fp}", F1)[1]).lower(), "no counts on a picture")
check(call("PUT", f"/v1/blocks/{f1_id}", F2)[0] == 204, "F2 blocks F1")
check(d1(f"SELECT count(*) AS n FROM follows WHERE follower = '{f1_id}' OR followee = '{f1_id}'")[0]["n"] == 0, "blocking ends following both ways")
check(call("PUT", f"/v1/follows/{f2_id}", F1)[0] == 404, "can't follow someone who blocked you")
call("DELETE", f"/v1/blocks/{f1_id}", F2)
check(call("PUT", f"/v1/follows/{f2_id}", F1)[0] == 204, "unblocked: following again")
check(call("DELETE", f"/v1/follows/{f2_id}", F1)[0] == 204, "and unfollowing")
check(call("GET", "/v1/me/following", F1)[1]["people"] == [], "the list empty again")

print("an author's page (S2)")
G1, g1_id = session(f"G1{uuid.uuid4().hex[:4]}"); G2, g2_id = session(f"G2{uuid.uuid4().hex[:4]}")
ga = post(G1, theme)[1]["id"]; call("POST", f"/v1/admin/posts/{ga}/approve", M, body={})
gb = post(G1, theme)[1]["id"]   # waiting: not counted, not shown to others
s, card = call("GET", f"/v1/users/{g1_id}", G2)
check(s == 200 and card["topFilm"] == "portra400" and card["films"] == 1 and card["followed"] is False, f"G1's card from public pictures only {card}")
check("followers" not in card and "count" not in json.dumps(card), "no counts of people")
s, page = call("GET", f"/v1/users/{g1_id}/posts", G2)
ids = [p_["id"] for p_ in page["posts"]]
check(s == 200 and ga in ids and gb not in ids, "their public pictures, not the waiting one")
s, page = call("GET", f"/v1/users/{g1_id}/posts", G1)
check(gb in [p_["id"] for p_ in page["posts"]], "one's own page shows one's own waiting picture too")
call("PUT", f"/v1/follows/{g1_id}", G2)
check(call("GET", f"/v1/users/{g1_id}", G2)[1]["followed"] is True, "followed shows on the card")
call("PUT", f"/v1/blocks/{g2_id}", G1)
check(call("GET", f"/v1/users/{g1_id}", G2)[0] == 404, "blocked: the page isn't there")
check(call("GET", f"/v1/users/{g1_id}/posts", G2)[0] == 404, "nor the pictures")

print("bio (S2b)")
B1, b1_id = session(f"B1{uuid.uuid4().hex[:4]}"); B2, b2_id = session(f"B2{uuid.uuid4().hex[:4]}")
for bad in ["see https://x.co", "wechat abc123", "加我微信", "ig: @lens_amy", "mail me a@b.cn", "138 0013 8000", "x" * 41,
            "example.dev", "find me @a", "lens dot studio", "koco。shop"]:
    check(call("PATCH", "/v1/me/bio", B1, body={"bio": bad})[0] == 422, f"refused: {bad[:20]}")
check(call("PATCH", "/v1/me/bio", B1, body={"bio": "Film 35mm, f/2. Mostly dusk."})[0] == 200, "ordinary words with dots pass")
s, bm = call("PATCH", "/v1/me/bio", B1, body={"bio": "  Shooting rainy streets  "})
check(s == 200 and bm["bio"] == "Shooting rainy streets", f"asked for, seen by oneself at once ({s})")
check(call("GET", f"/v1/users/{b1_id}", B1)[1]["bio"] == "Shooting rainy streets", "on one's own page too")
check(call("GET", f"/v1/users/{b1_id}", B2)[1]["bio"] is None, "others don't see it yet")
s, lst = call("GET", "/v1/admin/bios", M)
req = next(x for x in lst["bios"] if x["userId"] == b1_id)
check(call("POST", f"/v1/admin/bios/{b1_id}/approve", M, body={"version": "old"})[0] == 409, "a stale decision refused")
check(call("POST", f"/v1/admin/bios/{b1_id}/approve", M, body={"version": req["version"]})[0] == 204, "approved")
check(call("GET", f"/v1/users/{b1_id}", B2)[1]["bio"] == "Shooting rainy streets", "others see it now")
call("PATCH", "/v1/me/bio", B1, body={"bio": "Mostly dusk"})
req = next(x for x in call("GET", "/v1/admin/bios", M)[1]["bios"] if x["userId"] == b1_id)
check(call("POST", f"/v1/admin/bios/{b1_id}/reject", M, body={"version": req["version"]})[0] == 204, "turned down")
check(call("GET", "/v1/me", B1)[1]["bio"] == "Mostly dusk", "turned down: they still see it, nothing said")
check(call("GET", f"/v1/users/{b1_id}", B2)[1]["bio"] == "Shooting rainy streets", "others keep the approved one")
s, bm = call("PATCH", "/v1/me/bio", B1, body={"bio": ""})
check(s == 200 and bm["bio"] is None and call("GET", f"/v1/users/{b1_id}", B2)[1]["bio"] is None, "cleared at once, no review")
check(call("PATCH", "/v1/me/bio", B1, raw=b"null")[0] == 400, "a null body refused")

print("messages (S5)")
D1_, d1_id = session(f"Da{uuid.uuid4().hex[:4]}"); D2_, d2_id = session(f"Db{uuid.uuid4().hex[:4]}")
cid = lambda: uuid.uuid4().hex
check(call("POST", f"/v1/dms/{d2_id}", D1_, body={"text": "hi", "clientId": cid()})[0] == 403, "not following each other: no messages")
call("PUT", f"/v1/follows/{d2_id}", D1_)
check(call("POST", f"/v1/dms/{d2_id}", D1_, body={"text": "hi", "clientId": cid()})[0] == 403, "one-way is not enough")
call("PUT", f"/v1/follows/{d1_id}", D2_)
for bad in ["add me on wechat", "see koco.shop", "call 138 0013 8000", "x" * 301]:
    check(call("POST", f"/v1/dms/{d2_id}", D1_, body={"text": bad, "clientId": cid()})[0] == 422, f"refused: {bad[:18]}")
k1 = cid()
s, m1 = call("POST", f"/v1/dms/{d2_id}", D1_, body={"text": "Lovely light on that one", "clientId": k1})
check(s == 201 and m1["mine"], f"mutual: the first message goes ({s})")
check(call("POST", f"/v1/dms/{d2_id}", D1_, body={"text": "Lovely light on that one", "clientId": k1})[1]["id"] == m1["id"], "sent again: the same message")
check(call("POST", f"/v1/dms/{d2_id}", D1_, body={"text": "hello?", "clientId": cid()})[0] == 409, "one until they answer")
s, th = call("GET", "/v1/dms", D2_)
check(s == 200 and th["unread"] == 1 and th["threads"][0]["with"]["id"] == d1_id, "D2 sees one unread from D1")
check(call("GET", "/v1/me", D2_)[1]["dmUnread"] == 1, "and the count on me")
s, conv = call("GET", f"/v1/dms/{d1_id}", D2_)
check(s == 200 and [m["text"] for m in conv["messages"]] == ["Lovely light on that one"] and conv["canWrite"], "D2 reads it, may answer")
check(call("GET", "/v1/dms", D2_)[1]["unread"] == 1, "fetched isn't read")
check(call("POST", f"/v1/dms/{d1_id}/read", D2_, body={"ids": [conv["messages"][0]["id"]]})[0] == 204, "shown: told")
check(call("GET", "/v1/dms", D2_)[1]["unread"] == 0, "read once shown")
check(call("POST", f"/v1/dms/{d1_id}", D2_, body={"text": "Thanks! Dusk, Porto 400", "clientId": cid()})[0] == 201, "D2 answers")
check(call("POST", f"/v1/dms/{d2_id}", D1_, body={"text": "Nice", "clientId": cid()})[0] == 201, "now D1 may write again")
s, conv = call("GET", f"/v1/dms/{d2_id}", D1_)
check(conv["waiting"] and not conv["canWrite"] and len(conv["messages"]) == 3 and conv["messages"][0]["text"] == "Nice", "newest first; waiting again")
s, mine_view = call("GET", f"/v1/dms/{d2_id}", D2_)
check(not any(m["mine"] for m in mine_view["messages"] if m["text"] == "Nice"), "mine/theirs from each side")
# Twins of one message at the same moment: one message, the same answer to both.
kt = cid(); outs = [None, None]
call("POST", f"/v1/dms/{d1_id}", D2_, body={"text": "Thursday?", "clientId": cid()})   # D2's turn again after "Nice"
def twin(i): outs[i] = call("POST", f"/v1/dms/{d2_id}", D1_, body={"text": "Thursday works", "clientId": kt})
ts = [threading.Thread(target=twin, args=(i,)) for i in (0, 1)]; [t.start() for t in ts]; [t.join() for t in ts]
check(all(o_[0] in (200, 201) for o_ in outs) and outs[0][1]["id"] == outs[1][1]["id"], f"twins: one message {[o_[0] for o_ in outs]}")
check(d1(f"SELECT count(*) AS n FROM messages WHERE client_id = '{kt}'")[0]["n"] == 1, "written once")
thanks_id = next(m["id"] for m in call("GET", f"/v1/dms/{d2_id}", D1_)[1]["messages"] if m["text"].startswith("Thanks"))
check(call("POST", f"/v1/dms/{d2_id}/report", D1_, body={"reason": "spam", "messageId": m1["id"]})[0] == 404, "only their messages can be reported")
check(call("POST", f"/v1/dms/{d2_id}/report", D1_, body={"reason": "spam", "messageId": thanks_id})[0] == 204, "a report on messages")
s, dr = call("GET", "/v1/admin/dm-reports", M)
rep_ = next(r for r in dr["reports"] if r["reporter"]["id"] == d1_id)
check(rep_["messages"][-1]["text"].startswith("Thanks") and rep_["messages"][-1]["reported"], f"the evidence ends at the message reported, marked {[m_['text'][:8] for m_ in rep_['messages']]}")
check(call("GET", "/v1/admin/dm-reports", D1_)[0] == 403, "only admins read reports")
check(call("POST", f"/v1/admin/dm-reports/{rep_['id']}/handled", M, body={})[0] == 204, "handled")
check(not any(r["id"] == rep_["id"] for r in call("GET", "/v1/admin/dm-reports", M)[1]["reports"]), "gone from the list")
call("PUT", f"/v1/blocks/{d1_id}", D2_)
check(call("GET", "/v1/dms", D1_)[1]["threads"] == [], "blocked: the conversation is gone for D1")
check(call("GET", f"/v1/dms/{d2_id}", D1_)[0] == 404, "and can't be opened")
check(call("POST", f"/v1/dms/{d1_id}", D2_, body={"text": "x y", "clientId": cid()})[0] == 403, "nor written to, either way")
call("DELETE", f"/v1/blocks/{d1_id}", D2_)
check(call("POST", f"/v1/dms/{d2_id}", D1_, body={"text": "hi again", "clientId": cid()})[0] == 403, "unblocked: follows ended, no messages until both follow again")
check(len(call("GET", f"/v1/dms/{d2_id}", D1_)[1]["messages"]) == 5, "but the old ones can still be read")
# Twenty sent a day; refused tries don't count.
E1, e1_id = session(f"Ea{uuid.uuid4().hex[:4]}"); E2, e2_id = session(f"Eb{uuid.uuid4().hex[:4]}")
call("PUT", f"/v1/follows/{e2_id}", E1); call("PUT", f"/v1/follows/{e1_id}", E2)
for k in range(5): call("POST", f"/v1/dms/{e2_id}", E1, body={"text": "again", "clientId": cid()})   # 1 sent, 4 refused (turn)
fill = uuid.uuid4().hex[:6]
now_s = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S')
d1(f"WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 18) "
   f"INSERT INTO messages (id, pair, sender, recipient, text, client_id, created_at) "
   f"SELECT '{fill}-' || x, '{min(e1_id, e2_id)}:{max(e1_id, e2_id)}', '{e1_id}', '{e2_id}', 'x', '{fill}-' || x, '{now_s}' FROM n")
call("POST", f"/v1/dms/{e1_id}", E2, body={"text": "ok", "clientId": cid()})
check(call("POST", f"/v1/dms/{e2_id}", E1, body={"text": "nineteenth plus one", "clientId": cid()})[0] == 201, "refused tries didn't use up the day")
call("POST", f"/v1/dms/{e1_id}", E2, body={"text": "ok", "clientId": cid()})
check(call("POST", f"/v1/dms/{e2_id}", E1, body={"text": "twenty first", "clientId": cid()})[0] == 429, "the 21st in a day: not now")

print("notices (S4)")
N1, n1_id = session(f"N1{uuid.uuid4().hex[:4]}"); N2, n2_id = session(f"N2{uuid.uuid4().hex[:4]}"); N3, n3_id = session(f"N3{uuid.uuid4().hex[:4]}")
npub = post(N1, theme)[1]["id"]; call("POST", f"/v1/admin/posts/{npub}/approve", M, body={})
nwait = post(N1, theme)[1]["id"]                       # still waiting: nothing about it
s, nb = call("GET", "/v1/me/notices", N1)
check(s == 200 and nb["notices"] == [] and nb["unread"] == 0, f"nothing yet, and no word of one's own approval {nb}")
call("PUT", f"/v1/posts/{npub}/like", N1)              # one's own like: never a notice
call("PUT", f"/v1/posts/{npub}/like", N2); call("PUT", f"/v1/posts/{npub}/like", N3)
call("PUT", f"/v1/follows/{n1_id}", N2)
s, nc = call("POST", f"/v1/posts/{npub}/comments", N2, body={"text": "lovely light", "clientId": uuid.uuid4().hex})
s, nb = call("GET", "/v1/me/notices", N1)
kinds = sorted(i["kind"] for i in nb["notices"])
check(kinds == ["follows", "likes"], f"likes and follows; the waiting comment not yet {kinds}")
lk = next(i for i in nb["notices"] if i["kind"] == "likes")
check(lk["count"] == 2 and {p_["id"] for p_ in lk["people"]} == {n2_id, n3_id} and lk["postId"] == npub, f"two likes merged on one picture, one's own left out {lk}")
fw = next(i for i in nb["notices"] if i["kind"] == "follows")
check(fw["count"] == 1 and fw["people"][0]["id"] == n2_id, "a new follower, by day")
call("POST", f"/v1/admin/comments/{nc['id']}/approve", M, body={})
s, nb = call("GET", "/v1/me/notices", N1)
check(any(i["kind"] == "comment" and i["text"] == "lovely light" for i in nb["notices"]) and nb["unread"] == 3, f"the comment once public; three unread {nb['unread']}")
cm = next(i for i in nb["notices"] if i["kind"] == "comment")
check(call("POST", "/v1/me/notices/seen", N1, body={"shown": [{"key": cm["key"], "at": cm["at"], "count": cm["count"]}]})[0] == 204, "shown: the comment")
nb = call("GET", "/v1/me/notices", N1)[1]
check(nb["unread"] == 2 and not next(i for i in nb["notices"] if i["kind"] == "comment")["unread"], "only what was shown is read")
lk = next(i for i in nb["notices"] if i["kind"] == "likes")
call("POST", "/v1/me/notices/seen", N1, body={"shown": [{"key": i["key"], "at": i["at"], "count": i["count"]} for i in nb["notices"]]})
check(call("GET", "/v1/me/notices", N1)[1]["unread"] == 0, "all shown: none unread")
call("POST", "/v1/me/notices/seen", N1, body={"shown": [{"key": lk["key"], "at": "2020-01-01T00:00:00Z", "count": 9}]})   # a late, older one
check(call("GET", "/v1/me/notices", N1)[1]["unread"] == 0, "a mark never goes back")
N4, n4_id = session(f"N4{uuid.uuid4().hex[:4]}"); call("PUT", f"/v1/posts/{npub}/like", N4)
nb = call("GET", "/v1/me/notices", N1)[1]
lk = next(i for i in nb["notices"] if i["kind"] == "likes")
check(lk["unread"] and lk["count"] == 3 and lk["people"][0]["id"] == n4_id, "a new like: the group is new again, newest name first")
check(call("POST", "/v1/me/notices/seen", N1, body={"shown": []})[0] == 400, "nothing shown is refused")
check(call("POST", "/v1/me/notices/seen", N1, raw=b"null")[0] == 400, "a null body is refused")
# Same time, more people: still new (the version is time and count).
d1(f"UPDATE likes SET created_at = (SELECT MAX(created_at) FROM likes WHERE post_id = '{npub}') WHERE post_id = '{npub}'")
lk = next(i for i in call("GET", "/v1/me/notices", N1)[1]["notices"] if i["kind"] == "likes")
call("POST", "/v1/me/notices/seen", N1, body={"shown": [{"key": lk["key"], "at": lk["at"], "count": lk["count"] - 1}]})
check(next(i for i in call("GET", "/v1/me/notices", N1)[1]["notices"] if i["kind"] == "likes")["unread"], "same time, one more like: still unread")
check(call("POST", "/v1/me/notices/seen", N1, body={"shown": [{"key": "c:x", "at": "soon", "count": 1}]})[0] == 400, "a bad time is refused")
call("PUT", f"/v1/blocks/{n3_id}", N1)
lk = next(i for i in call("GET", "/v1/me/notices", N1)[1]["notices"] if i["kind"] == "likes")
check(n3_id not in [p_["id"] for p_ in lk["people"]] and lk["count"] == 2, "a blocked person drops out")
check(all("approved" not in json.dumps(i).lower() and i["postId"] != nwait for i in call("GET", "/v1/me/notices", N1)[1]["notices"]), "nothing about review or waiting pictures")
# More than a page: 33 comments from two people, then page through.
for who, n in ((N2, 20), (N4, 13)):
    for k in range(n):
        c_ = call("POST", f"/v1/posts/{npub}/comments", who, body={"text": f"note {k}", "clientId": uuid.uuid4().hex})[1]
        call("POST", f"/v1/admin/comments/{c_['id']}/approve", M, body={})
s, pg1 = call("GET", "/v1/me/notices", N1)
check(s == 200 and len(pg1["notices"]) == 30 and pg1["nextCursor"], "thirty on the first page")
s, pg2 = call("GET", f"/v1/me/notices?cursor={urllib.parse.quote(pg1['nextCursor'])}", N1)
keys1 = [i["key"] for i in pg1["notices"]]; keys2 = [i["key"] for i in pg2["notices"]]
check(s == 200 and keys2 and not set(keys1) & set(keys2) and pg2["nextCursor"] is None, f"the rest on the second, none twice ({len(keys2)})")
check(len(keys1) + len(keys2) == 36, f"every notice reachable: 34 comments, likes, follows ({len(keys1) + len(keys2)})")
call("POST", "/v1/me/notices/seen", N1, body={"shown": [{"key": i["key"], "at": i["at"], "count": i["count"]} for i in pg1["notices"]]})
check(call("GET", "/v1/me/notices", N1)[1]["unread"] == len([i for i in pg2["notices"] if i["unread"]]), "page two, not shown, stays unread")

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
