import json
import urllib.request

API = "https://fast-api.rbxservers.xyz"
PLACE = 1537690962

url = f"{API}/games/v1/recommended/{PLACE}"
req = urllib.request.Request(url, headers={"User-Agent": "DexUI"})
with urllib.request.urlopen(req, timeout=20) as res:
    body = res.read().decode("utf-8")
data = json.loads(body)
print(json.dumps(data, indent=2)[:4000])
if isinstance(data, dict):
    print("keys", list(data.keys()))
    for k, v in data.items():
        if isinstance(v, list) and v:
            print("list", k, "len", len(v), "item0 keys", list(v[0].keys()) if isinstance(v[0], dict) else type(v[0]))
