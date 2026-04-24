# Hyprland Controls

This file is the quickest map for local Hyprland behavior in this flake.

## Source Of Truth

- [home/desktop/hyprland.nix](./home/desktop/hyprland.nix) owns the local Hyprland overrides.
- [README.md](./README.md) is the high-level stack overview.
- [END4_SETTINGS.md](./END4_SETTINGS.md) documents the end-4 / QuickShell settings layer.

## Requested Keymap

- `tap/release Super`: End-4 app search / launcher
- `Super+Q`: close the active window
- `Super+H`: exit Hyprland
- `Super+F`: launch Nemo (via local `file-manager` wrapper)
- `Super+V`: toggle floating
- `Super+J`: toggle the current dwindle split
- `Super+B`: launch Firefox
- `Super+T`: launch Kitty
- `Super+C`: launch VS Code
- `Super+E`: launch Telegram
- `Super+Tab`: enter resize mode
- `Super+Shift+Tab`: open End-4 workspace overview
- `Super+L` or `Ctrl+L`: lock with QuickShell
- `Super+Shift+C`: clipboard picker
- `Super+Shift+E`: emoji picker
- `Super+P`: open End-4 wallpaper selector
- `Super+Shift+P`: pick a random wallpaper (prefers current wallpaper folder)
- `Super+Left/Right/Up/Down`: move focus in the tiled tree
- `Super+Shift+Left/Right/Up/Down`: move the active window in the tiled tree
- `Super+1..9`: focus workspaces 1 through 9
- `Super+Shift+1..9`: move the active window to workspaces 1 through 9
- `3-finger horizontal swipe`: switch workspaces with the restored local gesture override

## Mouse Controls

- `Super+LMB`: move the active window
- `Super+RMB`: resize the active window
- `Super+Ctrl` + touchpad drag: move the active window
- `Super+Alt` + touchpad drag: resize the active window

## Resize Mode

- `Super+Tab`: enter resize mode
- `Super+Shift+R`: enter resize mode
- In resize mode:
  `Left/Right`: resize width
  `Up/Down`: resize height
  `Mouse Wheel`: resize width
  `Shift+Mouse Wheel`: resize height
  `Esc`, `Enter`, or `Tab`: leave resize mode

## Recent Fixes (March 28, 2026)

- `Super+F` now opens the local `file-manager` wrapper which launches Nemo.
- Locking is now handled by the QuickShell lockscreen end-to-end, including idle and lid-switch paths.
- Touchpad click behavior is pinned to `clickfinger_behavior = false` so two-finger right-click is reliable.
- MIME defaults and keybind behavior now use one file-manager target (`nemo.desktop`) to avoid split behavior.
- Dark GTK values are enforced during activation to keep file-manager theme consistent after rebuilds.

## Why It Is Split This Way

- Hyprland behavior is kept declarative in `home/desktop/hyprland.nix`.
- The local module now owns `hypr/hyprland/keybinds.conf` directly, not just `custom/keybinds.conf`, so upstream End-4 shell binds cannot keep colliding underneath your map.
- Runtime shell options stay in `~/.config/illogical-impulse/config.json`, with defaults managed from `home/desktop/end4/settings.nix`.
- Idle behavior is also owned locally through `hypr/hypridle.conf` so lock/suspend flow stays declarative.
- `custom/keybinds.conf` is intentionally left empty to avoid a second local binding layer.
- `Super+Tab` enters resize mode, while End-4 workspace overview moved to `Super+Shift+Tab`.
- The touchpad is pinned to `clickfinger_behavior = false` and `tap_button_map = lrm`, and the official Hyprland modifier-drag fallbacks are enabled too.
- End-4 search uses `Super` release and non-consuming `bindn` interrupts on all `Super+...` action chords, so window/workspace binds do not also trigger launcher.
