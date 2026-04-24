# END-4 Settings

This flake keeps end-4 / Illogical Impulse settings in two layers:

- Nix-owned defaults live in [home/desktop/end4/settings.nix](./home/desktop/end4/settings.nix).
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
- `background.parallax.enableWorkspace = false`
- `background.parallax.workspaceZoom = 1.0`
- `lock.blur.enable = true`
- `lock.blur.extraZoom = 1.05`
- `lock.blur.radius = 64`
- `lock.useHyprlock = false`
- `bar.utilButtons.showChargeLimitToggle = true`
- `resources.updateInterval = 10000`
- `resources.historyLength = 30`
- `sidebar.keepRightSidebarLoaded = false`
- `time.pomodoro.focus = 2700` (`45 minutes`)
- `bar.weather.enable = true`
- `bar.weather.enableGPS = false`
- `bar.weather.city` is auto-synced from current public IP geolocation at Home Manager activation (`ipapi.co`), fallback is `Rishikesh, Uttarakhand, India 249204`
- `bar.weather.useUSCS = false`

## Display And Wallpaper Rules

- The laptop panel is pinned in Hyprland to `eDP-1, 1920x1080@144, 0x0, 1, vrr, 0`.
- Wallpapers below `1920x1080` are replaced with the bundled `3840x2160` default during Home Manager activation.
- QuickShell reads live colors from `~/.config/matugen/colors.json`.

## Shell State Files

- Home Manager bootstraps `~/.local/state/quickshell/user/todo.json` as a writable JSON array.
- Home Manager bootstraps `~/.local/state/quickshell/user/notes.txt` as a writable text file.
- The local [home/desktop/end4/overrides/Todo.qml](./home/desktop/end4/overrides/Todo.qml) override normalizes malformed todo entries instead of letting the widget break on bad JSON.

## Workspace And Display Behavior

- Local Hyprland layer enforces `general.layout = dwindle`.
- Panel mode is pinned to `eDP-1, 1920x1080@144, 0x0, 1, vrr, 0`.
- Touchpad workspace swipe remains enabled (`3-finger horizontal`) from the upstream general config patch.
- `misc.vrr = 0`, `render.direct_scanout = false`, and `cursor.no_hardware_cursors = true` are set for hybrid laptop stability.

## Lock Behavior

- QuickShell/PAM is the primary lockscreen provider.
- Local Hyprland and Hypridle wiring call QuickShell lock directly.
- Hyprlock is not part of the active lock path anymore.

## Battery Care

- A QuickShell bar utility button for battery care is enabled by default.
- The system restores a `90%` stop-charge target on supported backends.
- On hardware without a writable charge-limit backend, the button stays visible and reports that limitation instead of pretending to work.

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
    "secondPrecision": false,
    "pomodoro": {
      "focus": 2700
    }
  },
  "lock": {
    "useHyprlock": false
  },
  "background": {
    "parallax": {
      "enableWorkspace": false,
      "enableSidebar": false,
      "workspaceZoom": 1.0
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
    "updateInterval": 10000,
    "historyLength": 30
  },
  "bar": {
    "utilButtons": {
      "showChargeLimitToggle": true
    },
    "weather": {
      "enable": true,
      "enableGPS": false,
      "city": "Auto-detected at activation (ipapi.co)",
      "useUSCS": false,
      "fetchInterval": 10
    }
  },
  "sidebar": {
    "keepRightSidebarLoaded": false
  }
}
```
