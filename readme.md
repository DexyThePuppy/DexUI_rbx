# DexUI

A modular **Material Design 3** UI library for Roblox script executors. Ripple feedback, sliding tabs, contained cards, live theming/tinting, draggable + resizable window, a 3D world-pin mode, and built-in media & icon browsers.

The library ships as a single bundled file built from a modular Luau source tree (`src/`) via [darklua](https://darklua.com).

## Install (always-latest release)

The CI publishes a minified build to the GitHub **Releases** on every push to `main`, marked as *latest*. This URL always points at the newest build:

```lua
local DexUI = loadstring(game:HttpGet("https://github.com/DexyThePuppy/DexUI_rbx/releases/latest/download/dexui.lua"))()
```

Run the full showcase/demo instead:

```lua
loadstring(game:HttpGet("https://github.com/DexyThePuppy/DexUI_rbx/releases/latest/download/demo.lua"))()
```

## Quick start

```lua
local DexUI = loadstring(game:HttpGet("https://github.com/DexyThePuppy/DexUI_rbx/releases/latest/download/dexui.lua"))()

local ui = DexUI.CreateWindow("My Script")

ui:AddTab("Main", 4483362458) -- title, icon asset id (optional)
ui:AddSection("Inputs")
ui:AddSlider("Volume", 0, 100, 50, function(v) print("slider", v) end)
ui:AddSwitch("Enabled", true, function(on) print("switch", on) end, "Optional subtitle")
ui:AddDropdown("Mode", { "Blue", "Purple", "Green" }, "Blue", function(opt) print(opt) end)

ui:AddSection("Actions")
ui:AddButton("Run", function()
    ui:Notify({ Title = "Hi", Content = "Button clicked!", Duration = 3 })
end)
ui:AddKeybind("Toggle", Enum.KeyCode.B, function() print("key pressed") end)
ui:AddColorPicker("Accent", Color3.fromRGB(162, 201, 255), function(c) print(c) end)

ui:Show()
```

## API

`DexUI.CreateWindow(title: string?) -> Window` and `DexUI.Version`.

### Window

| Method | Description |
|--------|-------------|
| `AddTab(text, icon?)` | Add a sidebar tab; subsequent `Add*` calls attach to it. `icon` is an asset id or `rbxassetid://` string. |
| `SelectTab(text)` | Switch to a tab by name. |
| `AddSection(text)` | Group heading inside the current tab. |
| `AddDivider()` | Thin separator. |
| `AddLabel(text, icon?)` | Static label; returns `{ SetText }`. |
| `AddParagraph(title, body)` | Title + wrapped body card. |
| `AddButton(text, cb?)` | Button with ripple. |
| `AddSwitch(text, default?, cb?, subtitle?)` | Toggle, optional subtitle. |
| `AddSlider(text, min, max, default?, cb?)` | Value slider. |
| `AddTextBox(label, cb?)` | Text input; `cb(text, enterPressed)`. |
| `AddDropdown(text, options, default?, cb?)` | Floating dropdown. |
| `AddKeybind(text, default?, cb?, subtitle?)` | Keybind picker, optional subtitle. |
| `AddColorPicker(text, default?, cb?, subtitle?)` | Floating color picker. |
| `AddMediaBrowser()` | Creator-store video/audio browser. |
| `AddIconBrowser()` | Material Icons catalog (search + copy id). |
| `Notify({ Title?, Content?, Duration? })` | Toast notification. |
| `ChangePalette(name)` | Switch built-in palette (`Blue`, `Purple`, `Green`, `Orange`, `Red`, `PitchBlack`). |
| `ApplyTint(color)` | Derive a full theme from one `Color3`. |
| `PlayIntro({ Brand?, OnComplete? }?)` | Play the 3D world intro. |
| `Show()` | Reveal the window. |
| `Destroy()` | Fully unload: removes UI and disconnects all connections. |
| `Reload()` / `SetReloadCallback(cb)` | Rebuild the UI (re-runs `cb`, replays intro). |
| `SetSoundsEnabled(bool)` / `SetSoundVolume(scale)` / `PlayFeedback(pattern)` | Haptic-style sound feedback. |

## Build from source

Requires [Rokit](https://github.com/rojo-rbx/rokit) (pins darklua via `rokit.toml`).

```powershell
rokit install
./build.ps1            # -> dist/dexui.lua + dist/demo.lua
./build.ps1 -Minify    # also emit *.min.lua
./build.ps1 -Stage     # copy bundles into the Volt executor workspace
```

## Project layout

```
src/
  init.luau            entry point -> { Version, CreateWindow }
  config.luau          brand + constants
  services.luau        cached game services
  theme/palettes.luau  Material 3 dark palettes
  core/                util, fonts, sound, context (shared ctx factory)
  components/          one file per component (button, slider, dropdown, ...)
  window/              window assembler + 3D intro
  demo.luau            showcase consumer of the library
.github/workflows/     CI: build + publish release
build.ps1, .darklua.json, rokit.toml
```
