from pathlib import Path

t = Path(__file__).parent.joinpath("rbx-game-page.js").read_text(encoding="utf-8", errors="ignore")
for needle in ["getServerSideProps", "getStaticProps", "__N_SSP", "server_count", "/games/v1/", "official_servers"]:
    start = 0
    n = 0
    while n < 8:
        i = t.find(needle, start)
        if i < 0:
            break
        print(f"--- {needle} @ {i} ---")
        print(t[i : i + 500])
        start = i + 1
        n += 1
