# X15 XS NixOS Flake

NixOS unstable on `x15xs`, using `Hyprland 0.54` with end-4's Illogical Impulse shell via `github:soymou/illogical-flake`.

## Stack

- Compositor/Shell: `Hyprland 0.54` + Illogical Impulse / QuickShell
- Theme: `adw-gtk3-dark` + `kvantum-dark` + `Bibata-Modern-Classic 24`
- Color pipeline: `matugen image <wallpaper> --mode dark --source-color-index 0`
- Portals: `xdg-desktop-portal-hyprland` only
- Display: explicit `eDP-1 = 1920x1080@144`
- Perf defaults: QuickShell-only blur, `QSG_RENDER_LOOP=basic`, `zramSwap.enable=true`

## Inputs

- `illogical-flake = github:soymou/illogical-flake`
- `hyprland = github:hyprwm/Hyprland/v0.54.0`
- `quickshell = git+https://git.outfoxxed.me/quickshell/quickshell`
- `matugen = github:InioX/matugen`

Update one input at a time:

```bash
nix flake update hyprland
nix flake update quickshell
nix flake update matugen
```

No runtime `git clone` is used.

## Source Of Truth

- [flake.nix](./flake.nix): inputs and overlays
- [configuration.nix](./configuration.nix): host config
- [home/illogical-impulse-module.nix](./home/illogical-impulse-module.nix): local wrapper around `illogical-flake`
- [home/illogical-settings.nix](./home/illogical-settings.nix): end-4 settings, writable theme outputs, dark-mode bootstrap
- [home/end4-overrides/Todo.qml](./home/end4-overrides/Todo.qml): local QuickShell todo override with safer JSON loading and persistence
- [home/hyprland.nix](./home/hyprland.nix): scrolling layout, bindings, perf-sensitive Hyprland overrides
- [home/browser.nix](./home/browser.nix): Zen/Brave browser ownership, default browser handlers, Brave profile tuning
- [home/ide.nix](./home/ide.nix): VS Code/Cursor/Kiro/Antigravity ownership and shared IDE settings
- [home/mimeapps.nix](./home/mimeapps.nix): writable MIME defaults and file-manager/open-with behavior
- [HYPRLAND_CONTROLS.md](./HYPRLAND_CONTROLS.md): local control map for navigation, resize mode, and workspace travel
- [END4_SETTINGS.md](./END4_SETTINGS.md): end-4 / QuickShell settings reference

## Core Values

- Declarative first: all critical behavior should be encoded in Nix and survive rebuilds.
- Single owner per concern: avoid split ownership for bindings, MIME, theming, and launcher behavior.
- Stable dark contract: GTK `adw-gtk3-dark`, Qt `kvantum-dark`, and wallpaper-driven Matugen colors remain aligned.
- Practical performance: prefer lower-latency, low-overhead defaults that keep Hyprland sessions responsive.
- Reproducible debugging: pair every meaningful config change with docs and structural tests.

## Settings

Persistent end-4 defaults are merged into `~/.config/illogical-impulse/config.json` from [home/illogical-settings.nix](./home/illogical-settings.nix). Use that file for values you want to survive rebuilds.

## Apps

- Browsers: Zen Browser and Brave are installed declaratively; Firefox is removed from the active Home Manager profile.
- Web defaults: Zen Browser is the default web handler for `http`, `https`, and `text/html`.
- IDEs: VS Code `1.109.2`, Cursor `2.4.31`, Kiro `0.9.2`, and Antigravity `1.16.5` come from the pinned unstable input set through Nixpkgs and are tuned by [home/ide.nix](./home/ide.nix).
- Python/DS tooling: `conda` (Anaconda-compatible workflow), `jupyterlab`, and `uv` are installed declaratively via [home/packages.nix](./home/packages.nix).
- AI tooling: `claude-code` (CLI agent) and `ollama` (CLI client) are installed declaratively; the local Ollama CUDA service + Open WebUI stack remains managed by [modules/ollama.nix](./modules/ollama.nix).
- GUI file managers: Nemo is kept as the single primary GUI file manager; redundant `nautilus` and `thunar` installs were removed.
- Nix maintenance: Limine natively shows only the latest `7` system generations, daily garbage collection deletes paths older than `7d`, and store optimization stays enabled.
- Boot layout: the active Limine ESP is `nvme0n1p1` (`BB34-5262`), while the Windows EFI files live on `nvme1n1p1` (`D85E-0D8D`) and are targeted by GUID from Limine.

Important defaults:

- `language.ui = "en_US"`
- `calendar.locale = "en-GB"`
- `time.format = "hh:mm AP"`
- `background.parallax.enableSidebar = false`
- `background.parallax.workspaceZoom = 1.03`
- `light.night.automatic = true`
- `light.night.colorTemperature = 3966`
- `lock.blur.radius = 64`
- `resources.updateInterval = 5000`
- `sidebar.keepRightSidebarLoaded = false`
- `bar.weather.enable = true`
- `bar.weather.enableGPS = false`
- `bar.weather.city = "Rishikesh, India 249204"`
- `bar.weather.useUSCS = false`
- `appearance.wallpaperTheming.enableAppsAndShell = true`
- `appearance.wallpaperTheming.enableQtApps = false`
- `appearance.wallpaperTheming.enableTerminal = true`
- `appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode = true`
- wallpapers below `1920x1080` are replaced with the bundled `3840x2160` default during Home Manager activation
- QuickShell state is bootstrapped declaratively in `~/.local/state/quickshell/user`, including `todo.json` and `notes.txt`

Mutable generated outputs are copied or linked into:

- `~/.config/matugen`
- `~/.config/fuzzel`
- `~/.config/hypr/hyprland/colors.conf`
- `~/.config/hypr/hyprlock`
- `~/.config/hypr/custom/scripts`
- `~/.config/gtk-4.0/gtk.css`

## Key Bindings

- `tap/release Super`: End-4 app search / launcher
- `Super+Tab`: End-4 workspace overview
- `Super+Shift+C`: clipboard
- `Super+Shift+E`: emoji
- `Super+Shift+R`: enter resize mode
- `Super+P`: End-4 wallpaper selector
- `Super+Shift+P`: random wallpaper (prefers current wallpaper folder)
- `Super+Alt+P`: sync lock wallpaper
- `Super+L` or `Ctrl+L`: lock
- `Super+T`: Kitty
- `Super+B`: Zen
- `Super+C`: VS Code
- `Super+E`: Telegram
- `Super+F`: Nemo (via local `file-manager` wrapper)
- `Super+Q`: close window
- `Super+H`: exit Hyprland
- `Super+V`: toggle floating
- `Super+J`: toggle the current dwindle split
- `Super+Left/Right/Up/Down`: move focus in the tiled tree
- `Super+Shift+Left/Right/Up/Down`: move the focused window in the tiled tree
- `Super+LMB`: drag-move the active window
- `Super+RMB`: drag-resize the active window
- `Super+Ctrl` + touchpad drag: move the active window
- `Super+Alt` + touchpad drag: resize the active window
- `Super+1..9`: focus workspace
- `Super+Shift+1..9`: move window to workspace
- `3-finger horizontal swipe`: switch workspaces

## Notes

- Hyprland now uses `general.layout = dwindle` with `dwindle.preserve_split = true` and `dwindle.precise_mouse_move = true`.
- The local Hyprland layer keeps the classic layout, restores `3-finger` workspace swipes, and uses your requested classic bind set.
- The local module now overrides `hypr/hyprland/keybinds.conf` directly; this is deliberate so End-4's upstream `bind`, `bindd`, `bindid`, and other shell-specific bindings stop colliding with your map.
- End-4 search now uses `Super` release with interrupt-safe `bindn` action chords so `Super+Q` and other `Super+...` bindings do not also trigger the launcher.
- `Super+F` now launches Nemo through a local wrapper pinned to `GTK_THEME=adw-gtk3-dark`, avoiding GNOME-shell-specific startup overhead in Hyprland.
- `custom/keybinds.conf` is intentionally kept empty now, so there is only one declarative local binding layer to reason about.
- `Super+Tab` is restored to End-4's workspace overview, and resize mode now sits on `Super+Shift+R` while still returning cleanly to Hyprland's global submap.
- The touchpad config now sets `clickfinger_behavior = false` and `tap_button_map = lrm`, and also enables Hyprland's modifier-drag touchpad fallbacks for move/resize.
- The upstream End-4 touchpad gestures are kept, but the obsolete `hyprexpo` gesture options are still stripped because Hyprland 0.54 rejects them.
- `hypr/monitors.conf` pins the internal panel to `1920x1080@144` so the session does not drift into a softer fallback mode.
- The portal module uses `lib.mkForce`, so the final declared system config does not include `xdg-desktop-portal-gtk`.
- [home/mimeapps.nix](./home/mimeapps.nix) keeps baseline app associations declarative, but converts `mimeapps.list` into writable regular files so Nemo can save right-click `Open With` choices during a session.
- [home/browser.nix](./home/browser.nix) removes Firefox from the active profile and keeps Brave lighter by merging a small `Preferences` delta instead of replacing the whole profile.

## Recent Changes (March 28, 2026)

- Removed unused legacy modules and assets from the repo tree (`niri`, `noctalia`, local `waybar`, and unused local `starship.toml`) to keep the structure focused on the active Hyprland + End-4 stack.
- File manager stack is now consistently Nemo:
  `Super+F` launcher, MIME defaults, and right-click association flow all point to the same app.
- Touchpad click handling is pinned to `clickfinger_behavior = false` with `tap_button_map = lrm` for more reliable two-finger right-click.
- GTK dark mode enforcement now runs during activation via `gsettings` to keep file-manager theming consistent after rebuilds.
- Matugen extraction is non-interactive and deterministic:
  `matugen image ... --mode dark --source-color-index 0 --prefer closest-to-fallback`.
- Weather defaults are now pinned declaratively to `Rishikesh, India 249204`.

## Validation

```bash
nix flake check . --no-build --option abort-on-warn true
nix-shell -p python3 python3Packages.pytest python3Packages.hypothesis --run "pytest tests/test_migration.py -q"
nix build .#nixosConfigurations.x15xs.config.system.build.toplevel --no-link
```

## GitHub Workflows

- CI: [`.github/workflows/ci.yml`](./.github/workflows/ci.yml)
- Markdown lint: [`.github/workflows/markdown.yml`](./.github/workflows/markdown.yml)
- Contribution guide: [`CONTRIBUTING.md`](./CONTRIBUTING.md)
