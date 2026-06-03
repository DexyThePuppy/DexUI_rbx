from pathlib import Path

t = Path(__file__).parent.joinpath("rbx-server-page.js").read_text(encoding="utf-8", errors="ignore")
idx = 0
while True:
    i = t.find("fetch-link", idx)
    if i < 0:
        break
    print(t[max(0, i - 150) : i + 350])
    print("---")
    idx = i + 1
