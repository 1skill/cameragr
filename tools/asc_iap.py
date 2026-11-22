"""Creates Koco's in-app purchases in App Store Connect from Config/Koco.storekit:
non-consumable, Family Sharing on, English and Simplified Chinese names and
descriptions, USA base price (Apple's equivalents elsewhere), every territory.
Safe to run again: a product that already exists is left as it is.
Reads ASC_* from ~/.appstoreconnect/koco.env.   python3 tools/asc_iap.py
"""
import json, os, subprocess, sys, urllib.request, urllib.error

env = {}
for line in open(os.path.expanduser("~/.appstoreconnect/koco.env")):
    if "=" in line:
        k, v = line.strip().split("=", 1); env[k] = os.path.expandvars(v)
KEY = os.path.expanduser(env["ASC_KEY_PATH"].replace("$HOME", "~"))
TOKEN = subprocess.run([sys.executable, "tools/asc_jwt.py", KEY, env["ASC_KEY_ID"], env["ASC_ISSUER_ID"]],
                       capture_output=True, text=True, check=True).stdout.strip()
APP = env["ASC_APP_ID"]
API = "https://api.appstoreconnect.apple.com"

def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        err = json.loads(e.read() or b"{}")
        raise RuntimeError(f"{method} {path} → {e.code} {[(x.get('code'), x.get('detail')) for x in err.get('errors', [])]}")

def all_pages(path):
    out = []
    while path:
        d = call("GET", path); out += d.get("data", [])
        nxt = d.get("links", {}).get("next"); path = nxt.replace(API, "") if nxt else None
    return out

store = json.load(open("Config/Koco.storekit"))
existing = {p["attributes"]["productId"]: p["id"] for p in all_pages(f"/v1/apps/{APP}/inAppPurchasesV2?limit=200")}
territories = [t["id"] for t in all_pages("/v1/territories?limit=200")]
LOCALE = {"en_US": "en-US", "zh_Hans": "zh-Hans"}

for p in store["products"]:
    pid, price = p["productID"], p["displayPrice"]
    if pid in existing:
        print("exists", pid); continue
    iap = call("POST", "/v2/inAppPurchases", {"data": {"type": "inAppPurchases",
        "attributes": {"name": p["referenceName"], "productId": pid, "inAppPurchaseType": "NON_CONSUMABLE",
                       "familySharable": True,
                       "reviewNote": "A film look for the camera. Each paid film has 3 free trial shots; buying unlocks it for good. All Films unlocks every film, including later ones."},
        "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]
    for l in p.get("localizations", []):
        call("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations",
            "attributes": {"locale": LOCALE.get(l["locale"], l["locale"]), "name": l["displayName"], "description": l["description"]},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}}}}})
    points = all_pages(f"/v2/inAppPurchases/{iap}/pricePoints?filter[territory]=USA&limit=200")
    point = next(x["id"] for x in points if x["attributes"]["customerPrice"] == price)
    call("POST", "/v1/inAppPurchasePriceSchedules", {"data": {"type": "inAppPurchasePriceSchedules",
        "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
                          "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                          "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p0}"}]}}},
        "included": [{"type": "inAppPurchasePrices", "id": "${p0}", "attributes": {"startDate": None},
                      "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": point}}}}]})
    call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {"type": "inAppPurchaseAvailabilities",
        "attributes": {"availableInNewTerritories": True},
        "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
                          "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]}}}})
    print("created", pid, iap, "$" + price)
