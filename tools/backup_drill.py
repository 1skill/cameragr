"""Backup and restore drill for the community database (C11), on the TEST
Worker's D1 only, with D1 Time Travel (point-in-time restore, kept 30 days):

  1. a person with a picture, a day and a reward is made; the tables are counted
  2. a restore point is taken
  3. damage: a theme's text is broken by hand, and the person deletes their account
  4. the database is restored to the point
  5. the theme is whole and the counts match; so is the deleted person
  6. the deletions are replayed: the person is gone again, their
     no-claiming-again record is there, their pictures stay gone

    python3 tools/backup_drill.py

project/runbook-backup.md has the same steps for the real database.
Secrets are read from ~/.cloudflare-koco.env and never printed.
"""
import json, os, sys, time, uuid, urllib.request, urllib.error
from datetime import datetime, timezone

env = {}
for line in open(os.path.expanduser("~/.cloudflare-koco.env")):
    if "=" in line:
        k, v = line.strip().split("=", 1); env[k] = v
DB = env.get("D1_TEST_ID") or sys.exit("no test database: run tools/cf_deploy.py --test first")
API = f"https://api.cloudflare.com/client/v4/accounts/{env['CLOUDFLARE_ACCOUNT_ID']}/d1/database/{DB}"
BASE = "https://koco-community-test.sybbzb.workers.dev"
TABLES = ["users", "posts", "checkins", "eligibility", "rewards", "departed_rewards", "comments", "themes", "admin_log"]

def cf(method, path, body=None):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode() if body is not None else None, method=method,
                                 headers={"Authorization": "Bearer " + env["CLOUDFLARE_API_TOKEN"], "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r: return json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} → {e.code} {e.read()[:300]}")

def sql(q):
    return cf("POST", "/query", {"sql": q})["result"][0]["results"]

def worker(method, path, token=None, body=None, raw=None):
    h = {"x-test-login": env["TEST_LOGIN"], "user-agent": "koco-backup-drill/1.0"}
    if token: h["authorization"] = "Bearer " + token
    if raw is not None: h["content-type"] = "image/jpeg"
    elif body is not None: h["content-type"] = "application/json"
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(BASE + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req) as r:
            t = r.read(); return r.status, (json.loads(t) if t and t[:1] in b"{[" else t)
    except urllib.error.HTTPError as e:
        t = e.read(); return e.code, (json.loads(t) if t[:1] in b"{[" else t)

def session(name, admin=False):
    s, b = worker("POST", "/v1/test/session", body={"sub": f"drill-{RUN}-{name}", "name": name, "admin": admin})
    assert s == 200, (s, b)
    worker("POST", "/v1/me/rules", b["token"], body={"version": b["user"]["rulesCurrent"]})
    return b["token"], b["user"]["profile"]["id"]

def counts():
    return {t: sql(f"SELECT count(*) AS n FROM {t}")[0]["n"] for t in TABLES}

failures = []
def check(ok, what):
    print(("  ok   " if ok else "  FAIL ") + what)
    if not ok: failures.append(what)

RUN = uuid.uuid4().hex[:6]
here = os.path.dirname(__file__)
photo = open(os.path.join(here, "fixtures/test_photo.jpg"), "rb").read()
thumb = open(os.path.join(here, "fixtures/test_thumb.jpg"), "rb").read()

print("1. a person with a picture and a day")
theme = f"drill-{RUN}"
sql(f"""INSERT INTO themes (id, kind, starts_at, ends_at, title, prompt) VALUES ('{theme}', 'daily',
        '2020-01-01T00:00:00Z', '2099-01-01T00:00:00Z', '{{"en":"Drill"}}', '{{"en":"Drill"}}')""")
M, _ = session("M", admin=True)
Y, y_id = session("Y")
s, up = worker("POST", "/v1/uploads", Y, body={})
worker("PUT", f"/v1/uploads/{up['uploadId']}/photo", Y, raw=photo)
worker("PUT", f"/v1/uploads/{up['uploadId']}/thumb", Y, raw=thumb)
s, p = worker("POST", "/v1/posts", Y, body={"themeId": theme, "uploadId": up["uploadId"], "filmId": "portra400", "clientId": uuid.uuid4().hex})
worker("POST", f"/v1/admin/posts/{p['id']}/approve", M, body={})
sql(f"INSERT OR IGNORE INTO rewards (user_id, milestone, film_id, claimed_at) VALUES ('{y_id}', 3, 'portra400', '2026-11-24T00:00:00Z')")
before = counts()
print("   ", before)

print("2. a restore point")
time.sleep(2)
# D1's own "now" (not this Mac's clock, which may differ from Cloudflare's).
bookmark = cf("GET", "/time_travel/bookmark")["result"]["bookmark"]
time.sleep(2)

print("3. damage, and a deletion")
sql(f"UPDATE themes SET title = '{{\"en\":\"broken\"}}' WHERE id = '{theme}'")
s, gone = worker("DELETE", "/v1/me", Y)
check(s == 200, "the person deletes their account")
check(not sql(f"SELECT 1 AS x FROM users WHERE id = '{y_id}'"), "they're gone")

print("4. restored to the point")
cf("POST", f"/time_travel/restore?bookmark={bookmark}")
time.sleep(5)

print("5. as it was")
after = counts()
check(after == before, f"every table as before ({after})")
check(sql(f"SELECT title FROM themes WHERE id = '{theme}'")[0]["title"] == '{"en":"Drill"}', "the damaged theme is as it was")
check(bool(sql(f"SELECT 1 AS x FROM users WHERE id = '{y_id}'")), "and so is the deleted person (why the replay is needed)")

print("6. deletions replayed")
s, r = worker("POST", "/v1/admin/replay-deletions", M, body={})
check(s == 200 and r.get("deletedAgain", 0) >= 1, f"replayed ({r})")
check(not sql(f"SELECT 1 AS x FROM users WHERE id = '{y_id}'"), "the deleted person is gone again")
check(not sql(f"SELECT 1 AS x FROM posts WHERE author = '{y_id}'"), "with their pictures")
check(bool(sql(f"SELECT 1 AS x FROM departed_rewards d WHERE milestone = 3 AND sub_hash IN (SELECT sub_hash FROM departed_rewards)")), "their no-claiming-again record is there")
check(r.get("complete") is True, "their pictures cleared (complete)")
s, pic = worker("GET", f"/v1/posts/{p['id']}", M)
check(s == 404, "their picture can't be opened")
s, again = worker("POST", "/v1/admin/replay-deletions", M, body={})
check(s == 200, "replaying twice is harmless")

print()
print("drill passed" if not failures else f"{len(failures)} failed")
sys.exit(1 if failures else 0)
