"""Uploads each in-app purchase's App Review screenshot
(design/appstore/iap2/<film id>.png, or allfilms.png) and replaces an older one.
python3 tools/asc_iap_shots.py
"""
import hashlib, json, os, subprocess, sys, urllib.request, urllib.error
sys.path.insert(0, "tools")
env = {}
for line in open(os.path.expanduser("~/.appstoreconnect/koco.env")):
    if "=" in line:
        k, v = line.strip().split("=", 1); env[k] = v
KEY = os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_" + env["ASC_KEY_ID"] + ".p8")
TOKEN = subprocess.run([sys.executable, "tools/asc_jwt.py", KEY, env["ASC_KEY_ID"], env["ASC_ISSUER_ID"]],
                       capture_output=True, text=True, check=True).stdout.strip()
API = "https://api.appstoreconnect.apple.com"

def call(method, url, body=None, raw=None, headers=None):
    h = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"} if raw is None else (headers or {})
    req = urllib.request.Request(url if url.startswith("http") else API + url, method=method,
                                 data=raw if raw is not None else (json.dumps(body).encode() if body else None), headers=h)
    try:
        with urllib.request.urlopen(req) as r:
            b = r.read(); return json.loads(b) if b and raw is None else {}
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {url} → {e.code} {e.read()[:300]}")

iaps = call("GET", f"/v1/apps/{env['ASC_APP_ID']}/inAppPurchasesV2?limit=200")["data"]
for p in iaps:
    pid = p["attributes"]["productId"]; short = pid.rsplit(".", 1)[-1]
    path = f"design/appstore/iap2/{short}.png"
    data = open(path, "rb").read()
    old = call("GET", f"/v2/inAppPurchases/{p['id']}/appStoreReviewScreenshot").get("data")
    if old: call("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{old['id']}")
    shot = call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
        "attributes": {"fileName": f"{short}.png", "fileSize": len(data)},
        "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": p["id"]}}}}})["data"]
    for op in shot["attributes"]["uploadOperations"]:
        part = data[op["offset"]:op["offset"] + op["length"]]
        call(op["method"], op["url"], raw=part, headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])})
    call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{shot['id']}", {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
        "id": shot["id"], "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print("uploaded", pid)
