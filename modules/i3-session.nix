{ config, lib, pkgs, ... }:

let
  cfg = config.modules.i3Session;
  greenclipPkg = pkgs.haskellPackages.greenclip;

  i3Launcher = pkgs.writeShellScriptBin "x15-i3-launcher" ''
    exec ${pkgs.rofi}/bin/rofi -show drun -show-icons
  '';

  i3Overview = pkgs.writeShellScriptBin "x15-i3-overview" ''
    exec ${pkgs.rofi}/bin/rofi -show window -show-icons
  '';

  i3Lock = pkgs.writeShellScriptBin "x15-i3-lock" ''
    exec ${pkgs.i3lock}/bin/i3lock -c 120b10
  '';

  i3Clipboard = pkgs.writeShellScriptBin "x15-i3-clipboard" ''
    set -euo pipefail

    if ! ${pkgs.procps}/bin/pgrep -x greenclip >/dev/null 2>&1; then
      ${greenclipPkg}/bin/greenclip daemon >/dev/null 2>&1 &
      sleep 0.2
    fi

    selection="$(${greenclipPkg}/bin/greenclip print | ${pkgs.rofi}/bin/rofi -dmenu -i -p clipboard 2>/dev/null || true)"
    [ -n "$selection" ] || exit 0

    printf '%s' "$selection" | ${pkgs.xclip}/bin/xclip -selection clipboard
    printf '%s' "$selection" | ${pkgs.xclip}/bin/xclip -selection primary
  '';

  i3Emoji = pkgs.writeShellScriptBin "x15-i3-emoji" ''
    exec ${pkgs.rofimoji}/bin/rofimoji --action copy
  '';

  i3NightShift = pkgs.writeShellScriptBin "x15-i3-night-shift" ''
    set -euo pipefail

    if ${pkgs.procps}/bin/pgrep -x redshift >/dev/null 2>&1; then
      ${pkgs.procps}/bin/pkill -x redshift
      ${pkgs.libnotify}/bin/notify-send -a "display" -u low -r 9203 -t 1200 "Night light" "Disabled"
    else
      ${pkgs.redshift}/bin/redshift -m randr -P -O 5000 >/dev/null 2>&1 &
      ${pkgs.libnotify}/bin/notify-send -a "display" -u low -r 9203 -t 1200 "Night light" "Enabled"
    fi
  '';

  i3ApplyWallpaper = pkgs.writeShellScriptBin "x15-i3-apply-wallpaper" ''
    set -euo pipefail

    config_file="$HOME/.config/illogical-impulse/config.json"
    default_wallpaper="$HOME/.config/quickshell/ii/assets/images/default_wallpaper.png"
    wallpaper=""

    if [ -f "$config_file" ]; then
      wallpaper="$(${pkgs.jq}/bin/jq -r '.background.wallpaperPath // empty' "$config_file" 2>/dev/null || true)"
    fi

    if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
      wallpaper="$default_wallpaper"
    fi

    [ -f "$wallpaper" ] || exit 0
    exec ${pkgs.feh}/bin/feh --no-fehbg --bg-fill "$wallpaper"
  '';

  i3WallpaperRandom = pkgs.writeShellScriptBin "x15-i3-wallpaper-random" ''
    set -euo pipefail

    config_file="$HOME/.config/illogical-impulse/config.json"

    pick_random_image() {
      local dir="$1"
      [ -d "$dir" ] || return 1

      ${pkgs.findutils}/bin/find "$dir" -maxdepth 4 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' \) \
        | ${pkgs.coreutils}/bin/shuf -n 1
    }

    current_dir=""
    if [ -f "$config_file" ]; then
      current_wallpaper="$(${pkgs.jq}/bin/jq -r '.background.wallpaperPath // empty' "$config_file" 2>/dev/null || true)"
      if [ -n "$current_wallpaper" ]; then
        candidate_dir="$(${pkgs.coreutils}/bin/dirname "$current_wallpaper")"
        if [ -d "$candidate_dir" ]; then
          current_dir="$candidate_dir"
        fi
      fi
    fi

    selected=""
    for dir in \
      "$current_dir" \
      "$HOME/Pictures/Wallpapers/showcase" \
      "$HOME/Pictures/Wallpapers" \
      "$HOME/Wallpapers" \
      "$HOME/Pictures"; do
      [ -n "$dir" ] || continue
      selected="$(pick_random_image "$dir" || true)"
      if [ -n "$selected" ]; then
        break
      fi
    done

    [ -n "$selected" ] || exit 1

    if [ -f "$config_file" ]; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq --arg path "$selected" '.background.wallpaperPath = $path' "$config_file" > "$tmp"
      mv "$tmp" "$config_file"
    fi

    exec ${pkgs.feh}/bin/feh --no-fehbg --bg-fill "$selected"
  '';

  i3WallpaperMenu = pkgs.writeShellScriptBin "x15-i3-wallpaper-menu" ''
    set -euo pipefail

    mapfile -t candidates < <(
      ${pkgs.findutils}/bin/find \
        "$HOME/Pictures/Wallpapers/showcase" \
        "$HOME/Pictures/Wallpapers" \
        "$HOME/Wallpapers" \
        "$HOME/Pictures" \
        -maxdepth 4 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' \) \
        2>/dev/null | ${pkgs.coreutils}/bin/sort -u
    )

    [ "''${#candidates[@]}" -gt 0 ] || exit 1

    selection="$(printf '%s\n' "''${candidates[@]}" | ${pkgs.rofi}/bin/rofi -dmenu -i -p wallpaper 2>/dev/null || true)"
    [ -n "$selection" ] || exit 0

    config_file="$HOME/.config/illogical-impulse/config.json"
    if [ -f "$config_file" ]; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq --arg path "$selection" '.background.wallpaperPath = $path' "$config_file" > "$tmp"
      mv "$tmp" "$config_file"
    fi

    exec ${pkgs.feh}/bin/feh --no-fehbg --bg-fill "$selection"
  '';

  i3Screenshot = pkgs.writeShellScriptBin "x15-i3-screenshot" ''
    exec ${pkgs.flameshot}/bin/flameshot gui
  '';
in
{
  options.modules.i3Session = {
    enable = lib.mkEnableOption "X11 i3 fallback session";
  };

  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable = true;
      windowManager.i3 = {
        enable = true;
        configFile = ../home/desktop/i3/config;
        extraPackages = with pkgs; [
          dex
          feh
          flameshot
          greenclipPkg
          i3status
          redshift
          rofi
          rofimoji
          xclip
          xss-lock
        ];
        extraSessionCommands = ''
          export XDG_CURRENT_DESKTOP=i3
          export XDG_SESSION_DESKTOP=i3
          export XDG_SESSION_TYPE=x11
          export GTK_THEME=adw-gtk3-dark
          export QT_STYLE_OVERRIDE=kvantum
          export _JAVA_AWT_WM_NONREPARENTING=1
          export MOZ_ENABLE_WAYLAND=0
        '';
      };
    };

    environment.etc."i3status.conf".source = ../home/desktop/i3/i3status.conf;
    environment.systemPackages = [
      i3ApplyWallpaper
      i3Clipboard
      i3Emoji
      i3Launcher
      i3Lock
      i3NightShift
      i3Overview
      i3Screenshot
      i3WallpaperMenu
      i3WallpaperRandom
    ];
  };
}
