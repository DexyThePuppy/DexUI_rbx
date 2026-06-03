from pathlib import Path

t = Path(__file__).parent.joinpath("rbx-game-page.js").read_text(encoding="utf-8", errors="ignore")
# page module starts around 6151 - search for function before default T
idx = t.find("8568:function")
print("chunk start", idx)
chunk = t[idx:idx+12000]
for needle in ["fetch(", "games/v1", "servers", "placeid", "getStatic", "getServer"]:
    i = 0
    while True:
        j = chunk.find(needle, i)
        if j < 0:
            break
        print(needle, j, chunk[max(0,j-60):j+120])
        i = j + 1
