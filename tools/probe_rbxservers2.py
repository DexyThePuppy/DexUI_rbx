import json
import re
import urllib.request

API = "https://fast-api.rbxservers.xyz"

def get(path):
    url = API + path
    req = urllib.request.Request(url, headers={"User-Agent": "DexUI"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return r.status, r.read().decode("utf-8", errors="replace")

status, body = get("/games/v1/list")
data = json.loads(body)
print("games count", len(data.get("games", [])))
if data.get("games"):
    g = data["games"][0]
    print("sample game keys", list(g.keys()))
    print("sample", {k: g[k] for k in list(g.keys())[:8]})

place_id = data["games"][0]["place_id"]
print("try place_id", place_id)

paths = [
    f"/games/v1/{place_id}/servers/list",
    f"/games/v1/{place_id}/servers",
    f"/servers/v1/list?place_id={place_id}",
    f"/servers/v1/list?placeId={place_id}",
    f"/servers/v1/game/{place_id}",
    f"/games/v1/servers?place_id={place_id}",
    f"/games/v1/servers/list?place_id={place_id}",
    f"/place/v1/{place_id}/servers",
    f"/places/v1/{place_id}/servers",
]
for p in paths:
    try:
        s, b = get(p)
        print(s, p, b[:200])
    except Exception as e:
        print("ERR", p, e)

for name in ["rbx526.js", "rbx-server-page.js", "rbx-game-page.js"]:
    try:
        text = open(__file__.replace("probe_rbxservers2.py", name), encoding="utf-8", errors="ignore").read()
    except FileNotFoundError:
        continue
    hits = sorted(set(re.findall(r"/[a-zA-Z0-9_./?=&-]*servers[a-zA-Z0-9_./?=&-]*", text)))
    hits += sorted(set(re.findall(r"/games/v1/[a-zA-Z0-9_./?=&-]+", text)))
    print("===", name, len(hits))
    for h in hits[:30]:
        print(" ", h)
