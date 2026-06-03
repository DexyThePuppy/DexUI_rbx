#!/usr/bin/env python3
"""Merge Fabrik modules into scripts/fabrik-tycoon.lua (single file, DexUI only)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "scripts"

def unwrap_return_function(src: str, fn_name: str, params: str) -> str:
    lines = src.splitlines()
    if not lines[0].strip().startswith("--") and "return function" not in lines[0]:
        pass
    start = next(i for i, L in enumerate(lines) if L.strip().startswith("return function"))
    body_lines = lines[start + 1 :]
    if body_lines and body_lines[-1].strip() == "end":
        body_lines = body_lines[:-1]
    body = "\n".join(body_lines)
    return f"local function {fn_name}({params})\n{body}\nend"

def main():
    session = (ROOT / "sdk/session.lua").read_text(encoding="utf-8")
    loop = (ROOT / "sdk/loop.lua").read_text(encoding="utf-8")
    api = (ROOT / "helpers/fabrik/api.lua").read_text(encoding="utf-8")
    game_main = (ROOT / "games/fabrik-tycoon/main.lua").read_text(encoding="utf-8-sig")

    create_ctx = unwrap_return_function(session, "createCtx", "manifest, DexUI")
    attach_loop = unwrap_return_function(loop, "attachLoop", "ctx")
    init_api = unwrap_return_function(api, "initFabrikApi", "ctx")

    # manifest table from main.lua
    m_start = game_main.index("local manifest = {")
    m_end = game_main.index("\n\t}", m_start) + len("\n\t}")
    manifest = game_main[m_start : m_end]
    manifest = manifest.replace("\t", "  ")
    # drop SDK-only manifest keys
    for key in ("prefixes", "pipeline", "abortAfter"):
        import re
        manifest = re.sub(
            rf"\n  {key} = [^\n]+,\n",
            "\n",
            manifest,
        )
        manifest = re.sub(
            rf"\n  {key} = \{{[^}}]*\}},\n",
            "\n",
            manifest,
            flags=re.DOTALL,
        )

    body_start = game_main.index("\t-- init\n")
    body_end = game_main.rindex("\nend")
    body = game_main[body_start:body_end]
    # one tab less (was inside return function(DexUI))
    body = "\n".join(
        line[1:] if line.startswith("\t") else line for line in body.splitlines()
    )

    body = body.replace("ctx.dexui.bindUnload({", "/*BIND*/")
    # UI block replacements done as strings
    body = body.replace(
        """local unloadScript = ctx.dexui.bindUnload({
\t\tmasterKey = "Enabled",
\t\tclearWidgets = true,
\t})""",
        """local function unloadScript()
\tConfig.Enabled = false
\tctx.shutdown(true)
\tctx.session = nil
\tctx.clearGenv()
\tfor key in ctx.widgets do
\t\tctx.widgets[key] = nil
\tend
end""",
    )
    body = body.replace(
        'ctx.dexui.bindUnload({\n\t\tmasterKey = "Enabled",\n\t\tclearWidgets = true,\n\t})',
        'unloadScript_placeholder',
    )

    # Simpler: patch dexui calls line by line after generation
    dexui_patches = [
        (
            "\tlocal unloadScript = ctx.dexui.bindUnload({\n\t\tmasterKey = \"Enabled\",\n\t\tclearWidgets = true,\n\t})",
            """local function unloadScript()
\tConfig.Enabled = false
\tctx.shutdown(true)
\tctx.session = nil
\tctx.clearGenv()
\tfor key in ctx.widgets do
\t\tctx.widgets[key] = nil
\tend
end""",
        ),
        (
            "\tctx.dexui.publishUi(ui)",
            """\tctx.ui = ui
\tif ctx.genv.ui then
\t\tctx.G[ctx.genv.ui] = ui
\tend""",
        ),
        (
            "\tctx.dexui.applyNotifyStyle(ui)",
            """\tdo
\t\tlocal style = ctx.manifest.notifyStyle or {
\t\t\tLife = ctx.notifDuration,
\t\t\tText = { Gradient = "rainbow" },
\t\t\tTextStroke = { Gradient = "rainbow", Thickness = 3.5 },
\t\t\tStackPosition = UDim2.new(1, -16, 0.58, 0),
\t\t}
\t\tif ui.SetNotificationStyle then
\t\t\tui:SetNotificationStyle(style)
\t\tend
\tend""",
        ),
        (
            "\tctx.dexui.addAboutTab(ui)",
            """\tif ui.AddGameInfo then
\t\tui:AddTab("About", 6026568227)
\t\tui:AddGameInfo()
\tend""",
        ),
    ]

    header = '''--[[
  [UPD] Fabrik-Tycoon — DexUI auto farmer (single file)
  Place: 15197136141
  Requires getgenv().DexUI from the DexUI hub before run.
]]

local DexUI = (getgenv and getgenv().DexUI) or nil
if not DexUI then
\terror("[fabrik-tycoon] DexUI not found. Launch from the DexUI scripts hub.")
end

'''

    bootstrap = f"""{manifest}

local ctx = attachLoop(createCtx(manifest, DexUI))
if not ctx.isAlive() then
\treturn
end

if not initFabrikApi(ctx) then
\tctx.log.error("Fabrik API failed (Scripts.Other) — aborting")
\tctx.shutdown(false)
\treturn
end

"""

    out = (
        header
        + create_ctx
        + "\n\n"
        + attach_loop
        + "\n\n"
        + init_api
        + "\n\n"
        + bootstrap
        + body
    )

    for old, new in dexui_patches:
        if old not in out:
            # try without leading tab mismatch
            old2 = old.replace("\t", "  ")
            if old2 in out:
                out = out.replace(old2, new.replace("\t", "  "))
            else:
                print("WARN: patch not found:", old[:60])
        else:
            out = out.replace(old, new)

    out = out.replace("\u2014", "-").replace("\u00e2\u20ac\u201d", "-")
    out = out.replace("Â·", "·")

    out_path = ROOT / "fabrik-tycoon.lua"
    out_path.write_text(out, encoding="utf-8", newline="\n")
    print(f"Wrote {out_path} ({len(out.splitlines())} lines)")

if __name__ == "__main__":
    main()
