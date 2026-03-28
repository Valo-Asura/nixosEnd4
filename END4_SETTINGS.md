# END-4 Settings

This flake keeps end-4 / Illogical Impulse settings in two layers:

- Nix-owned defaults live in [home/illogical-settings.nix](./home/illogical-settings.nix).
- Runtime state lives in `~/.config/illogical-impulse/config.json`.

## Core Values

- Persistent by default: settings should survive `nixos-rebuild switch`.
- Predictable output: one declarative source should define each behavior.
- Dark-first consistency: theme and color generation stay aligned across shell, GTK, and Qt.
- Low-friction operations: common actions (launcher, file manager, weather, wallpaper) should work without manual repair.

## Current Defaults

- Dark mode is forced through `matugen image ... --mode dark`.
- `language.ui = "en_US"`
- `calendar.locale = "en-GB"`
- `time.format = "hh:mm AP"`
- `appearance.wallpaperTheming.enableAppsAndShell = true`
- `appearance.wallpaperTheming.enableQtApps = false`
- `appearance.wallpaperTheming.enableTerminal = true`
- `background.parallax.enableSidebar = false`
- `background.parallax.enableWorkspace = true`
- `background.parallax.workspaceZoom = 1.03`
- `lock.blur.enable = true`
- `lock.blur.extraZoom = 1.05`
- `lock.blur.radius = 64`
- `resources.updateInterval = 5000`
- `sidebar.keepRightSidebarLoaded = false`
- `bar.weather.enable = true`
- `bar.weather.enableGPS = false`
- `bar.weather.city = "Rishikesh, India 249204"`
- `bar.weather.useUSCS = false`

## Display And Wallpaper Rules

- The laptop panel is pinned in Hyprland to `eDP-1, 1920x1080@144, 0x0, 1`.
- Wallpapers below `1920x1080` are replaced with the bundled `3840x2160` default during Home Manager activation.
- QuickShell reads live colors from `~/.config/matugen/colors.json`.

## Shell State Files

- Home Manager bootstraps `~/.local/state/quickshell/user/todo.json` as a writable JSON array.
- Home Manager bootstraps `~/.local/state/quickshell/user/notes.txt` as a writable text file.
- The local [home/end4-overrides/Todo.qml](./home/end4-overrides/Todo.qml) override normalizes malformed todo entries instead of letting the widget break on bad JSON.

## Infinite Workspace Behavior

- `general.layout = scrolling`
- `gestures.workspace_swipe_create_new = true`
- `gestures.workspace_swipe_forever = true`
- `gestures.workspace_swipe_use_r = true`
- `binds.allow_workspace_cycles = true`
- `animations.workspace_wraparound = true`

## JSON Examples

Use the end-4 settings UI if you want, or edit `~/.config/illogical-impulse/config.json` directly.

```json
{
  "language": {
    "ui": "en_US"
  },
  "calendar": {
    "locale": "en-GB"
  },
  "time": {
    "format": "hh:mm AP",
    "shortDateFormat": "dd/MM",
    "dateFormat": "ddd, dd/MM",
    "dateWithYearFormat": "dd/MM/yyyy",
    "secondPrecision": false
  },
  "background": {
    "parallax": {
      "enableWorkspace": true,
      "enableSidebar": false,
      "workspaceZoom": 1.03
    }
  },
  "appearance": {
    "wallpaperTheming": {
      "enableAppsAndShell": true,
      "enableQtApps": false,
      "enableTerminal": true,
      "terminalGenerationProps": {
        "forceDarkMode": true
      }
    }
  },
  "resources": {
    "updateInterval": 5000
  },
  "bar": {
    "weather": {
      "enable": true,
      "enableGPS": false,
      "city": "Rishikesh, India 249204",
      "useUSCS": false,
      "fetchInterval": 10
    }
  },
  "sidebar": {
    "keepRightSidebarLoaded": false
  }
}
```
