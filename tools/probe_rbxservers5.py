import json
import urllib.request

API = "https://fast-api.rbxservers.xyz"
PLACE = 1537690962

paths = [
    f"/games/v1/game/{PLACE}",
    f"/games/v1/info/{PLACE}",
    f"/games/v1/details/{PLACE}",
    f"/games/v1/{PLACE}",
    f"/games/v1/place/{PLACE}",
    f"/games/v1/data/{PLACE}",
    f"/games/v1/servers/{PLACE}",
    f"/games/v1/servers/list/{PLACE}",
    f"/games/v1/servers?place_id={PLACE}",
    f"/games/v1/page/{PLACE}",
]
for p in paths:
    url = API + p
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "DexUI"})
        with urllib.request.urlopen(req, timeout=15) as res:
            body = res.read().decode("utf-8", errors="replace")
            print(res.status, p, body[:200])
    except Exception as e:
        print("ERR", p, str(e)[:60])
