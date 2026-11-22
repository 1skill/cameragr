"""Writes Koco's store listing to App Store Connect from design/appstore/metadata.md:
category Photo & Video, copyright, and for each language the name, subtitle,
privacy policy URL, description, keywords, promotional text and support URL.
Only text fields of the editable 1.0 version; nothing is submitted.
Safe to run again: existing localizations are updated in place.
Reads ASC_* from ~/.appstoreconnect/koco.env.   python3 tools/asc_metadata.py [--dry]
"""
import json, os, re, subprocess, sys, urllib.request, urllib.error

DRY = "--dry" in sys.argv
env = {}
for line in open(os.path.expanduser("~/.appstoreconnect/koco.env")):
    if "=" in line:
        k, v = line.strip().split("=", 1); env[k] = os.path.expandvars(v)
KEY = os.path.expanduser(env["ASC_KEY_PATH"].replace("$HOME", "~"))
TOKEN = subprocess.run([sys.executable, "tools/asc_jwt.py", KEY, env["ASC_KEY_ID"], env["ASC_ISSUER_ID"]],
                       capture_output=True, text=True, check=True).stdout.strip()
APP = env["ASC_APP_ID"]
API = "https://api.appstoreconnect.apple.com"
SITE = "https://1skill.github.io/cameragr/"
PRIVACY = SITE + "privacy.html"
COPYRIGHT = "© 2026 水婴"

def call(method, path, body=None):
    if DRY and method != "GET":
        print("  (dry)", method, path); return {"data": {"id": "dry"}}
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        err = json.loads(e.read() or b"{}")
        raise RuntimeError(f"{method} {path} → {e.code} {[(x.get('code'), x.get('detail')) for x in err.get('errors', [])]}")

# --- metadata.md: one "## " section per language, fields in order ---
LOCALES = [("English", "en-US"), ("简体中文", "zh-Hans"), ("繁體中文", "zh-Hant"), ("日本語", "ja"), ("한국어", "ko")]
text = open("design/appstore/metadata.md", encoding="utf-8").read()
sections = re.split(r"^## ", text, flags=re.M)[1:]

def field(lines, i):
    """Value after the first ':' or '：' on a '- **…**' line."""
    s = re.sub(r"^- \*\*", "", lines[i])
    return re.split(r"[:：]\*\*\s*", s, maxsplit=1)[1].strip()

listing = {}
for sec in sections:
    head = sec.split("\n", 1)[0]
    loc = next((code for name, code in LOCALES if head.startswith(name)), None)
    if not loc: continue
    lines = sec.split("\n")
    items = [i for i, l in enumerate(lines) if l.startswith("- **")]
    name, subtitle, promo, keywords = (field(lines, items[k]) for k in range(4))
    desc = "\n".join(lines[items[4] + 1:]).strip()
    listing[loc] = dict(name=name, subtitle=subtitle, promo=promo, keywords=keywords, desc=desc)

LIMITS = dict(name=30, subtitle=30, promo=170, keywords=100, desc=4000)
for loc, d in listing.items():
    for k, n in LIMITS.items():
        assert 0 < len(d[k]) <= n, f"{loc} {k} is {len(d[k])} (limit {n})"
    assert "<" not in d["desc"], f"{loc} description has a placeholder"
    print(loc, {k: len(v) for k, v in d.items()})
assert len(listing) == 5, listing.keys()

# --- app info: category; names, subtitles, privacy URL ---
infos = call("GET", f"/v1/apps/{APP}/appInfos")["data"]
# The editable app info (a live app also has a read-only one for the version on sale).
info = next(x for x in infos if x["attributes"].get("state") not in ("READY_FOR_DISTRIBUTION", "REPLACED_WITH_NEW_INFO"))
call("PATCH", f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"],
     "relationships": {"primaryCategory": {"data": {"type": "appCategories", "id": "PHOTO_AND_VIDEO"}}}}})
print("category: Photo & Video")
have = {x["attributes"]["locale"]: x["id"] for x in call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]}
for loc, d in listing.items():
    attrs = {"name": d["name"], "subtitle": d["subtitle"], "privacyPolicyUrl": PRIVACY}
    if loc in have:
        call("PATCH", f"/v1/appInfoLocalizations/{have[loc]}", {"data": {"type": "appInfoLocalizations", "id": have[loc], "attributes": attrs}})
    else:
        call("POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": {"locale": loc, **attrs},
             "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
    print("app info", loc, "updated" if loc in have else "added")

# --- version 1.0: copyright; description, keywords, promo text, support URL ---
versions = call("GET", f"/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS")["data"]
version = next(v for v in versions if v["attributes"]["appStoreState"] == "PREPARE_FOR_SUBMISSION")
call("PATCH", f"/v1/appStoreVersions/{version['id']}", {"data": {"type": "appStoreVersions", "id": version["id"],
     "attributes": {"copyright": COPYRIGHT}}})
print("version", version["attributes"]["versionString"], "copyright set")
have = {x["attributes"]["locale"]: x["id"] for x in call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]}
for loc, d in listing.items():
    attrs = {"description": d["desc"], "keywords": d["keywords"], "promotionalText": d["promo"], "supportUrl": SITE}
    if loc in have:
        call("PATCH", f"/v1/appStoreVersionLocalizations/{have[loc]}", {"data": {"type": "appStoreVersionLocalizations", "id": have[loc], "attributes": attrs}})
    else:
        call("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": {"locale": loc, **attrs},
             "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
    print("version text", loc, "updated" if loc in have else "added")
print("done — nothing submitted")
