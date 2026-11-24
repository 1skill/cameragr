"""Deploys Koco's community Worker to Cloudflare, without wrangler.
Reads the token and ids from ~/.cloudflare-koco.env (never printed).
  python3 tools/cf_deploy.py [--schema] [--sql "…"]
--schema  apply server/schema.sql to D1 first
--sql     run one statement on D1 and print the result (for checks)
--secret NAME   set a Worker secret from stdin (never printed), then exit
--migrate apply server/migrations.sql, each statement once (a column already
          there is taken as done)
--test    act on the test Worker koco-community-test, its own D1 and R2
          (made if missing), with test sign-in on (TEST_LOGIN from
          ~/.cloudflare-koco.env, made if missing); never the real one
"""
import json, os, sys, uuid, urllib.request, urllib.error

env = {}
for line in open(os.path.expanduser("~/.cloudflare-koco.env")):
    if "=" in line:
        k, v = line.strip().split("=", 1); env[k] = v
TOKEN, ACC, DB = env["CLOUDFLARE_API_TOKEN"], env["CLOUDFLARE_ACCOUNT_ID"], env["D1_DATABASE_ID"]
API = f"https://api.cloudflare.com/client/v4/accounts/{ACC}"
NAME, BUCKET = "koco-community", "koco-photos"
TEST = "--test" in sys.argv

def call(method, path, body=None, headers=None, raw=None):
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    h = {"Authorization": f"Bearer {TOKEN}"}
    if raw is None and body is not None: h["Content-Type"] = "application/json"
    h.update(headers or {})
    req = urllib.request.Request(API + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req) as r: return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        out = json.loads(e.read() or b"{}"); raise SystemExit(f"{method} {path} → {e.code} {out.get('errors')}")

def sql(statement):
    return call("POST", f"/d1/database/{DB}/query", {"sql": statement})

if TEST:
    # The test Worker's own database and bucket, made once and remembered.
    NAME, BUCKET = "koco-community-test", "koco-photos-test"
    path = os.path.expanduser("~/.cloudflare-koco.env")
    if "D1_TEST_ID" not in env:
        res = call("POST", "/d1/database", {"name": "koco-community-test"})
        env["D1_TEST_ID"] = res["result"]["uuid"]
        open(path, "a").write(f"\nD1_TEST_ID={env['D1_TEST_ID']}\n")
    DB = env["D1_TEST_ID"]
    buckets = [b["name"] for b in call("GET", "/r2/buckets")["result"]["buckets"]]
    if BUCKET not in buckets:
        call("POST", "/r2/buckets", {"name": BUCKET})
    if "TEST_LOGIN" not in env:
        import secrets
        env["TEST_LOGIN"] = secrets.token_urlsafe(32)
        open(path, "a").write(f"TEST_LOGIN={env['TEST_LOGIN']}\n")
    os.chmod(path, 0o600)

if "--sql" in sys.argv:
    res = sql(sys.argv[sys.argv.index("--sql") + 1])
    print(json.dumps([r.get("results") for r in res["result"]], ensure_ascii=False)[:3000]); sys.exit()

if "--secret" in sys.argv:
    name = sys.argv[sys.argv.index("--secret") + 1]
    value = sys.stdin.read().strip()
    res = call("PUT", f"/workers/scripts/{NAME}/secrets", {"name": name, "text": value, "type": "secret_text"})
    print("secret", name, res.get("success")); sys.exit()

if "--migrate" in sys.argv:
    text = "\n".join(l for l in open("server/migrations.sql").read().splitlines() if not l.strip().startswith("--"))
    for stmt in [x.strip() for x in text.split(";")]:
        if not stmt: continue
        try:
            sql(stmt); print("migrated:", stmt[:60])
        except SystemExit as e:
            if "duplicate column" in str(e): print("already:", stmt[:60])
            elif "no such table" in str(e): print("new database (the schema makes it whole):", stmt[:40])
            else: raise

if "--schema" in sys.argv:
    res = sql(open("server/schema.sql").read())
    print("schema:", res.get("success"))

# The Worker, as an ES module with its bindings.
boundary = "----koco" + uuid.uuid4().hex
meta = {
    "main_module": "worker.js",
    "compatibility_date": "2026-10-01",
    "keep_bindings": ["secret_text"],   # secrets set with --secret survive deploys
    "bindings": [
        {"type": "d1", "name": "DB", "id": DB},
        {"type": "r2_bucket", "name": "PHOTOS", "bucket_name": BUCKET},
    ],
}
parts = [
    (f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\nContent-Type: application/json\r\n\r\n').encode()
    + json.dumps(meta).encode() + b"\r\n",
    (f'--{boundary}\r\nContent-Disposition: form-data; name="worker.js"; filename="worker.js"\r\n'
     f'Content-Type: application/javascript+module\r\n\r\n').encode() + open("server/worker.js", "rb").read() + b"\r\n",
    f"--{boundary}--\r\n".encode(),
]
res = call("PUT", f"/workers/scripts/{NAME}", raw=b"".join(parts),
           headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
print("deployed:", res.get("success"))
res = call("POST", f"/workers/scripts/{NAME}/subdomain", {"enabled": True, "previews_enabled": False})
print("workers.dev:", res.get("success"))
# Hourly: Apple grants still to revoke are tried again.
res = call("PUT", f"/workers/scripts/{NAME}/schedules", [{"cron": "17 * * * *"}])
print("schedule:", res.get("success"))
if TEST:
    import secrets
    call("PUT", f"/workers/scripts/{NAME}/secrets", {"name": "TEST_LOGIN", "text": env["TEST_LOGIN"], "type": "secret_text"})
    # One picture key for the test Worker, kept: a new one each deploy would
    # leave links signed with the old one for a moment.
    if "TEST_PHOTO_KEY" not in env:
        env["TEST_PHOTO_KEY"] = secrets.token_urlsafe(48)
        path = os.path.expanduser("~/.cloudflare-koco.env")
        open(path, "a").write(f"TEST_PHOTO_KEY={env['TEST_PHOTO_KEY']}\n"); os.chmod(path, 0o600)
    call("PUT", f"/workers/scripts/{NAME}/secrets", {"name": "PHOTO_KEY", "text": env["TEST_PHOTO_KEY"], "type": "secret_text"})
    print("test sign-in: on")
sub = call("GET", "/workers/subdomain")["result"]["subdomain"]
print(f"https://{NAME}.{sub}.workers.dev")
