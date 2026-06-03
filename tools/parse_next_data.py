import json
import re
from pathlib import Path

html = Path(__file__).parent.joinpath("rbx-game-html.html").read_text(encoding="utf-8", errors="ignore")
m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.S)
if not m:
    print("no next data")
    exit(1)
data = json.loads(m.group(1))
pp = data.get("props", {}).get("pageProps", {})
print("pageProps keys", list(pp.keys()))
inner = pp.get("data") or pp
print("inner keys", list(inner.keys()) if isinstance(inner, dict) else type(inner))
for key in ["servers", "official_servers", "community_servers", "server_count", "name", "blacklisted"]:
    if isinstance(inner, dict) and key in inner:
        val = inner[key]
        if isinstance(val, list) and val:
            print(key, "count", len(val), "sample", json.dumps(val[0], indent=2)[:1200])
        else:
            print(key, val)
