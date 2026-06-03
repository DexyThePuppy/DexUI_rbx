from pathlib import Path

t = Path(__file__).parent.joinpath("rbx-game-page.js").read_text(encoding="utf-8", errors="ignore")
for needle in ["getServerSideProps", "official_servers", "community_servers", "isValidPlaceId", "blacklisted", "games/v1/"]:
    i = t.find(needle)
    if i >= 0:
        print("===", needle, "===")
        print(t[i : i + 800])
        print()
