import json
import urllib.request

API = "https://fast-api.rbxservers.xyz"
PLACE = 1537690962

def req(path, method="GET", body=None):
    url = API + path
    headers = {"User-Agent": "DexUI", "Accept": "application/json"}
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(r, timeout=20) as res:
        return res.status, res.read().decode("utf-8", errors="replace")

paths = [
    f"/games/v1/quicklaunch/{PLACE}",
    f"/games/v1/quicklaunch?place_id={PLACE}",
    f"/games/v1/recommended/{PLACE}",
    f"/games/v1/recommended?place_id={PLACE}",
    f"/servers/?place_id={PLACE}",
    f"/servers?place_id={PLACE}",
    f"/servers/v1/?place_id={PLACE}",
    f"/servers/v2/?place_id={PLACE}",
    f"/servers/v2/list/{PLACE}",
    f"/servers/v2/game/{PLACE}/list",
    f"/games/v1/{PLACE}/quicklaunch",
]
for p in paths:
    try:
        s, b = req(p)
        print(s, p)
        print(b[:500])
        print("---")
    except Exception as e:
        print("ERR", p, e)
