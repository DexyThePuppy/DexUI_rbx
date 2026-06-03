import re
from pathlib import Path

t = Path(__file__).parent.joinpath("rbx-game-page.js").read_text(encoding="utf-8", errors="ignore")
patterns = [
    r"games/v1/[a-zA-Z0-9_/.?=&$-]+",
    r"servers/v[0-9]/[a-zA-Z0-9_/.?=&$-]+",
    r"server_[a-z_]+",
    r"place_[a-z_]+",
    r"job_[a-z_]+",
    r"access_[a-z_]+",
    r"uuid",
    r"quicklaunch",
    r"recommended",
]
for pat in patterns:
    hits = sorted(set(re.findall(pat, t, re.I)))
    if hits:
        print(pat, hits[:20])

# also find template strings like `...${...}...`
backticks = re.findall(r"`([^`]{10,120})`", t)
apiish = [b for b in backticks if "games" in b or "server" in b]
print("backticks", len(apiish))
for b in apiish[:30]:
    print(" ", b)
