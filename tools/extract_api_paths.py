import re
from pathlib import Path

for name in [
    "rbx883.js",
    "freeserver-load.js",
    "rbx-discover.js",
    "rbx-game-page.js",
]:
    p = Path(__file__).parent / name
    if not p.exists():
        continue
    text = p.read_text(encoding="utf-8", errors="ignore")
    print("===", name, "size", len(text))
    for pat in [
        r"https://[a-zA-Z0-9._/-]+",
        r'["\'](/[a-zA-Z0-9_\-./?=&{}]+)["\']',
        r"fast-api[^\"']{0,80}",
        r"embedded/game[^\"']{0,40}",
    ]:
        hits = sorted(set(re.findall(pat, text)))
        if hits:
            print("--", pat[:40], len(hits))
            for h in hits[:40]:
                if any(k in h.lower() for k in ("api", "server", "game", "place", "rbx", "embed", "fast")):
                    print(" ", h[:120])
