import json
import re
import urllib.request
from pathlib import Path

API = "https://fast-api.rbxservers.xyz"

def get(path, method="GET", body=None):
    url = API + path
    data = None
    headers = {"User-Agent": "DexUI", "Accept": "application/json"}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=15) as r:
        return r.status, r.read().decode("utf-8", errors="replace")

text = Path(__file__).parent.joinpath("rbx-server-page.js").read_text(encoding="utf-8", errors="ignore")
for m in sorted(set(re.findall(r"/servers/[a-zA-Z0-9_./?=&-]+", text))):
    print("JS", m)

place_id = 1537690962
paths = [
    f"/servers/v1/list?place_id={place_id}",
    f"/servers/v2/list?place_id={place_id}",
    f"/servers/v2/list?placeId={place_id}",
    f"/servers/v2/game/{place_id}",
    f"/servers/v2/games/{place_id}",
    f"/servers/v2/fetch-link/{place_id}",
    f"/servers/v2/fetch-link?place_id={place_id}",
]
for p in paths:
    try:
        s, b = get(p)
        print(s, p, b[:300])
    except Exception as e:
        print("ERR", p, e)

# POST variants
for p in ["/servers/v2/list", "/servers/v2/fetch-link"]:
    try:
        s, b = get(p, method="POST", body={"place_id": place_id})
        print("POST", s, p, b[:300])
    except Exception as e:
        print("POST ERR", p, e)
