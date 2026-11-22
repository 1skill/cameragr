import base64, json, subprocess, sys, time
KEY = sys.argv[1]; KID = sys.argv[2]; ISS = sys.argv[3]
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
head = b64(json.dumps({"alg": "ES256", "kid": KID, "typ": "JWT"}).encode())
now = int(time.time())
body = b64(json.dumps({"iss": ISS, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}).encode())
msg = f"{head}.{body}".encode()
der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY], input=msg, capture_output=True, check=True).stdout
# DER ECDSA signature -> raw r||s
def ints(d):
    assert d[0] == 0x30; i = 2 if d[1] < 0x80 else 3
    out = []
    for _ in range(2):
        assert d[i] == 0x02; n = d[i + 1]; v = d[i + 2:i + 2 + n]; i += 2 + n
        out.append(v.lstrip(b"\0").rjust(32, b"\0"))
    return out[0] + out[1]
print(f"{head}.{body}.{b64(ints(der))}")
