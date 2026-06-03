import json
import re
from pathlib import Path

html = Path(__file__).parent.joinpath("rbx-server-html.html").read_text(encoding="utf-8", errors="ignore")
m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.S)
data = json.loads(m.group(1))
pp = data.get("props", {}).get("pageProps", {})
inner = pp.get("data") or pp
print("keys", list(inner.keys()) if isinstance(inner, dict) else inner)
print(json.dumps(inner, indent=2)[:3000])
