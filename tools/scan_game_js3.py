import re
from pathlib import Path

t = Path(__file__).parent.joinpath("rbx-game-page.js").read_text(encoding="utf-8", errors="ignore")
for needle in ["server_count", "servers/v", "fetch(", "concat((0,R.j())", "server_uuid", "placeid"]:
    idx = 0
    count = 0
    while count < 5:
        i = t.find(needle, idx)
        if i < 0:
            break
        print("===", needle, "===")
        print(t[max(0, i - 80) : i + 250])
        print()
        idx = i + len(needle)
        count += 1
