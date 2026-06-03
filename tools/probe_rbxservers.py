import re
import urllib.request

API = "https://fast-api.rbxservers.xyz"
PATHS = [
    "/games/v1/list",
    "/games/v1/list?page=1",
    "/games/v1/search?query=adopt",
    "/games/v1/2753915549",
    "/games/v1/2753915549/servers",
    "/games/v1/place/2753915549",
    "/games/v1/place/2753915549/servers",
    "/games/2753915549/servers/v1/list",
    "/docs",
    "/openapi.json",
    "/redoc",
    "/games",
    "/games/2753915549",
    "/games/2753915549/servers",
    "/place/2753915549",
    "/places/2753915549",
    "/places/2753915549/servers",
    "/servers",
    "/servers/game/2753915549",
    "/v1/games/2753915549",
    "/v1/games/2753915549/servers",
    "/v1/places/2753915549/servers",
    "/discover",
    "/search?q=adopt",
    "/stats",
]

for path in PATHS:
    url = API + path
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "DexUI-probe"})
        with urllib.request.urlopen(req, timeout=12) as r:
            body = r.read(500).decode("utf-8", errors="replace")
            print(r.status, path, body[:120].replace("\n", " "))
    except Exception as e:
        print("ERR", path, str(e)[:80])

# scrape game page js for path hints
js_url = "https://rbxservers.com/_next/static/chunks/pages/games/%5Bplaceid%5D-65e3f9e90083cbce.js"
try:
    with urllib.request.urlopen(js_url, timeout=15) as r:
        js = r.read().decode("utf-8", errors="replace")
    for m in sorted(set(re.findall(r'["\'](/[a-zA-Z0-9_\-./{}]+)["\']', js))):
        if any(k in m for k in ("game", "server", "place", "vip", "api")):
            print("JS", m)
except Exception as e:
    print("JS ERR", e)
