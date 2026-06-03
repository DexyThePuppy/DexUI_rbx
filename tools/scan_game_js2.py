import re
from pathlib import Path

t = Path(__file__).parent.joinpath("rbx-game-page.js").read_text(encoding="utf-8", errors="ignore")
idx = 0
while True:
    i = t.find("quicklaunch", idx)
    if i < 0:
        break
    print(t[max(0, i - 120) : i + 200])
    print("---")
    idx = i + 1
    if idx > 50000:
        break
