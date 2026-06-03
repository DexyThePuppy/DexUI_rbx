import re
from pathlib import Path

for p in Path(__file__).parent.glob("rbx*.js"):
    t = p.read_text(encoding="utf-8", errors="ignore")
    paths = set(re.findall(r"/[a-zA-Z0-9_./?=&-]{4,80}", t))
    interesting = [x for x in sorted(paths) if any(k in x for k in ("server", "game", "place", "embed", "fetch", "list", "search"))]
    if interesting:
        print("===", p.name)
        for x in interesting:
            print(x)
