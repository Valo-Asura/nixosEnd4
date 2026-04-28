{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.hyprland;
  upstreamDotfiles = inputs.illogical-flake.inputs.dotfiles;
  hyprPatchedGeneral =
    builtins.replaceStrings
      [
        "gesture = 3, swipe, move,"
        "enable_gesture = false"
        "gesture_distance = 300"
        "gesture_positive = false"
      ]
      [
        "gesture = 3, horizontal, workspace"
        "# enable_gesture = false  # Removed: obsolete hyprexpo option"
        "# gesture_distance = 300  # Removed: obsolete hyprexpo option"
        "# gesture_positive = false  # Removed: obsolete hyprexpo option"
      ]
      (builtins.readFile "${upstreamDotfiles}/dots/.config/hypr/hyprland/general.conf");

  hyprPatchedExecs =
    builtins.replaceStrings
      [
        "exec-once = easyeffects --hide-window --service-mode"
        "exec-once = ~/.config/hypr/custom/scripts/__restore_video_wallpaper.sh"
        "exec-once = qs -c $qsConfig &"
        "qs -c $qsConfig ipc call cliphistService update"
        "exec-once = gnome-keyring-daemon --start --components=secrets"
      ]
      [
        "# exec-once = easyeffects --hide-window --service-mode  # Disabled for idle RSS/process targets"
        "# exec-once = ~/.config/hypr/custom/scripts/__restore_video_wallpaper.sh  # Disabled for faster static-wallpaper startup"
        "exec-once = qs -p $qsConfig &"
        "qs -p $qsConfig ipc call cliphistService update"
        "# exec-once = gnome-keyring-daemon --start --components=secrets  # Managed by PAM + system keyring service"
      ]
      (builtins.readFile "${upstreamDotfiles}/dots/.config/hypr/hyprland/execs.conf");

  hyprPatchedRules =
    let
      rules = lib.splitString "\n" (
        builtins.readFile "${upstreamDotfiles}/dots/.config/hypr/hyprland/rules.conf"
      );
      keepBlurRule =
        line:
        !(
          (lib.hasInfix "blur on" line || lib.hasInfix "blur_popups on" line)
          && !(lib.hasInfix "quickshell:" line)
        );
    in
    lib.concatStringsSep "\n" (builtins.filter keepBlurRule rules) + "\n";

  soundUp = pkgs.writeShellScriptBin "sound-up" ''
    set -euo pipefail
    ${pkgs.pamixer}/bin/pamixer -i 5
    vol="$(${pkgs.pamixer}/bin/pamixer --get-volume)"
    ${pkgs.libnotify}/bin/notify-send -a "audio" -u low -r 9201 -t 1200 "Volume" "$vol%"
  '';

  soundDown = pkgs.writeShellScriptBin "sound-down" ''
    set -euo pipefail
    ${pkgs.pamixer}/bin/pamixer -d 5
    vol="$(${pkgs.pamixer}/bin/pamixer --get-volume)"
    ${pkgs.libnotify}/bin/notify-send -a "audio" -u low -r 9201 -t 1200 "Volume" "$vol%"
  '';

  soundToggle = pkgs.writeShellScriptBin "sound-toggle" ''
    set -euo pipefail
    ${pkgs.pamixer}/bin/pamixer -t
    if [ "$(${pkgs.pamixer}/bin/pamixer --get-mute)" = "true" ]; then
      ${pkgs.libnotify}/bin/notify-send -a "audio" -u low -r 9201 -t 1200 "Volume" "Muted"
    else
      vol="$(${pkgs.pamixer}/bin/pamixer --get-volume)"
      ${pkgs.libnotify}/bin/notify-send -a "audio" -u low -r 9201 -t 1200 "Volume" "$vol%"
    fi
  '';

  brightnessUp = pkgs.writeShellScriptBin "brightness-up" ''
    set -euo pipefail
    ${pkgs.brightnessctl}/bin/brightnessctl set +5%
    level="$(${pkgs.brightnessctl}/bin/brightnessctl -m | ${pkgs.gawk}/bin/awk -F, '{print $4}')"
    ${pkgs.libnotify}/bin/notify-send -a "backlight" -u low -r 9202 -t 1200 "Brightness" "$level"
  '';

  brightnessDown = pkgs.writeShellScriptBin "brightness-down" ''
    set -euo pipefail
    ${pkgs.brightnessctl}/bin/brightnessctl set 5%-
    level="$(${pkgs.brightnessctl}/bin/brightnessctl -m | ${pkgs.gawk}/bin/awk -F, '{print $4}')"
    ${pkgs.libnotify}/bin/notify-send -a "backlight" -u low -r 9202 -t 1200 "Brightness" "$level"
  '';

  nightLightToggle = pkgs.writeShellScriptBin "night-light-toggle" ''
    set -euo pipefail

    if ${pkgs.procps}/bin/pgrep -x hyprsunset >/dev/null 2>&1; then
      ${pkgs.procps}/bin/pkill -x hyprsunset
      ${pkgs.libnotify}/bin/notify-send -a "display" -u low -r 9203 -t 1200 "Night light" "Disabled"
    else
      ${pkgs.hyprsunset}/bin/hyprsunset --temperature 5000 >/dev/null 2>&1 &
      ${pkgs.libnotify}/bin/notify-send -a "display" -u low -r 9203 -t 1200 "Night light" "Enabled"
    fi
  '';

  nightShift = pkgs.writeShellScriptBin "night-shift" ''
    exec ${nightLightToggle}/bin/night-light-toggle "$@"
  '';

  clipboardPicker = pkgs.writeShellScriptBin "clipboard" ''
    set -euo pipefail

    selection="$(${pkgs.cliphist}/bin/cliphist list | ${pkgs.wofi}/bin/wofi --dmenu -i -p clipboard 2>/dev/null || true)"
    [ -n "$selection" ] || exit 0

    printf '%s\n' "$selection" | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
  '';

  searchLauncher = pkgs.writeShellScriptBin "search-launcher" ''
    set -euo pipefail

    if ${pkgs.quickshell}/bin/qs -p "$HOME/.config/quickshell/ii" ipc show >/dev/null 2>&1; then
      exec ${pkgs.hyprland}/bin/hyprctl dispatch global quickshell:searchToggle
    fi

    if ${pkgs.procps}/bin/pgrep -x fuzzel >/dev/null 2>&1; then
      exec ${pkgs.procps}/bin/pkill -x fuzzel
    fi

    exec ${pkgs.fuzzel}/bin/fuzzel
  '';

  fileManager = pkgs.writeShellScriptBin "file-manager" ''
    set -euo pipefail

    target="''${1:-$HOME}"

    # Keep the file manager on the GTK3 theme contract in Hyprland sessions.
    export GTK_THEME="adw-gtk3-dark"
    exec ${pkgs.nemo}/bin/nemo "$target"
  '';

  wallpaperSwitch = pkgs.writeShellScriptBin "wallpaper-switch" ''
    set -euo pipefail

    mode="''${1:-static}"
    switchwall="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"

    if [ ! -x "$switchwall" ]; then
      ${pkgs.libnotify}/bin/notify-send -a "wallpaper" -u normal -t 1500 "Wallpaper switch" "switchwall.sh is not available"
      exit 1
    fi

    case "$mode" in
      static|animated)
        exec "$switchwall" --mode dark
        ;;
      *)
        exec "$switchwall" --mode dark
        ;;
    esac
  '';

  wallpaperRandom = pkgs.writeShellScriptBin "wallpaper-random" ''
    set -euo pipefail

    config_file="$HOME/.config/illogical-impulse/config.json"
    switchwall="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"

    if [ ! -x "$switchwall" ]; then
      ${pkgs.libnotify}/bin/notify-send -a "wallpaper" -u normal -t 1500 "Wallpaper random" "switchwall.sh is not available"
      exit 1
    fi

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

    if [ -z "$selected" ]; then
      ${pkgs.libnotify}/bin/notify-send -a "wallpaper" -u normal -t 1800 "Wallpaper random" "No images found in wallpaper folders"
      exit 1
    fi

    exec "$switchwall" --image "$selected" --mode dark
  '';

  workspaceKeycodes = builtins.genList (i: "code:1${toString i}") 9;

  mkInterruptBindLine =
    mod: key: "    bindn = ${mod}, ${key}, global, quickshell:searchToggleReleaseInterrupt";

  workspaceInterruptBinds = lib.concatStringsSep "\n" (
    (builtins.map (key: mkInterruptBindLine "$mod" key) workspaceKeycodes)
    ++ (builtins.map (key: mkInterruptBindLine "$shiftMod" key) workspaceKeycodes)
  );

  workspaceDispatchBinds = lib.concatStringsSep "\n" (
    builtins.genList
      (i:
        let
          ws = toString (i + 1);
          key = "code:1${toString i}";
        in
        "    bind = $mod, ${key}, workspace, ${ws}\n    bind = $shiftMod, ${key}, movetoworkspace, ${ws}"
      )
      9
  );

  hyprIdleConf = ''
    $lock_cmd = bash -lc 'hyprctl dispatch global quickshell:lock || qs -p "$HOME/.config/quickshell/ii" ipc call lock activate'
    $suspend_cmd = systemctl suspend || loginctl suspend

    general {
        lock_cmd = $lock_cmd
        before_sleep_cmd = $lock_cmd
        after_sleep_cmd = hyprctl dispatch global quickshell:lockFocus
        inhibit_sleep = 3
    }

    listener {
        timeout = 300
        on-timeout = $lock_cmd
    }

    listener {
        timeout = 600
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }

    listener {
        timeout = 900
        on-timeout = $suspend_cmd
    }
  '';

  hyprMainKeybinds = ''
    # Own the main keybind file directly so upstream End-4 shell binds do not
    # keep leaking in underneath local overrides.
    submap = global

    $mainMod = SUPER
    $shiftMod = SUPER SHIFT
    $altMod = SUPER ALT
    $mod = SUPER

    # End-4 launcher on Super release. If Super is used as a chord modifier
    # (e.g. Super+Q), interrupt so release does not also open launcher.
    bindid = Super, Super_L, Toggle launcher, global, quickshell:searchToggleRelease
    bindid = Super, Super_R, Toggle launcher, global, quickshell:searchToggleRelease
    binditn = Super, catchall, global, quickshell:searchToggleReleaseInterrupt
    bind = Ctrl, Super_L, global, quickshell:searchToggleReleaseInterrupt
    bind = Ctrl, Super_R, global, quickshell:searchToggleReleaseInterrupt
    bind = Super, mouse:272, global, quickshell:searchToggleReleaseInterrupt
    bind = Super, mouse:273, global, quickshell:searchToggleReleaseInterrupt
    bind = Super, mouse:274, global, quickshell:searchToggleReleaseInterrupt
    bind = Super, mouse:275, global, quickshell:searchToggleReleaseInterrupt
    bind = Super, mouse:276, global, quickshell:searchToggleReleaseInterrupt
    bind = Super, mouse:277, global, quickshell:searchToggleReleaseInterrupt
    bind = Super, mouse_up, global, quickshell:searchToggleReleaseInterrupt
    bind = Super, mouse_down, global, quickshell:searchToggleReleaseInterrupt

    bindn = $mainMod, Q, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, H, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, F, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, V, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, J, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, B, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, T, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, C, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, E, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, Tab, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, L, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, P, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, F2, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, Left, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, Right, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, Up, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, Down, global, quickshell:searchToggleReleaseInterrupt
    bindn = $mainMod, Print, global, quickshell:searchToggleReleaseInterrupt

    bindn = $shiftMod, C, global, quickshell:searchToggleReleaseInterrupt
    bindn = $shiftMod, E, global, quickshell:searchToggleReleaseInterrupt
    bindn = $shiftMod, P, global, quickshell:searchToggleReleaseInterrupt
    bindn = $shiftMod, R, global, quickshell:searchToggleReleaseInterrupt
    bindn = $shiftMod, Tab, global, quickshell:searchToggleReleaseInterrupt
    bindn = $shiftMod, Left, global, quickshell:searchToggleReleaseInterrupt
    bindn = $shiftMod, Right, global, quickshell:searchToggleReleaseInterrupt
    bindn = $shiftMod, Up, global, quickshell:searchToggleReleaseInterrupt
    bindn = $shiftMod, Down, global, quickshell:searchToggleReleaseInterrupt
    bindn = $shiftMod, Print, global, quickshell:searchToggleReleaseInterrupt

    bindn = $altMod, P, global, quickshell:searchToggleReleaseInterrupt

${workspaceInterruptBinds}

    # Apps and shell entry points.
    bind = $mainMod, Q, killactive,
    bind = $mainMod, H, exit,
    bind = $mainMod, F, exec, file-manager
    bind = $mainMod, V, togglefloating,
    bind = $mainMod, J, togglesplit,
    bind = $mainMod, B, exec, ${pkgs.firefox}/bin/firefox
    bind = $mainMod, T, exec, ${pkgs.kitty}/bin/kitty
    bind = $mainMod, C, exec, code --enable-features=UseOzonePlatform --ozone-platform=wayland
    bind = $mainMod, E, exec, ${pkgs.telegram-desktop}/bin/telegram-desktop
    bind = $mainMod, Tab, submap, resize
    bind = $shiftMod, Tab, global, quickshell:overviewWorkspacesToggle
    bind = CTRL, L, global, quickshell:lock
    bind = $mainMod, L, global, quickshell:lock

    # Utilities.
    bind = $shiftMod, C, exec, clipboard
    bind = $shiftMod, E, exec, ${pkgs.wofi-emoji}/bin/wofi-emoji
    bind = $mainMod, P, global, quickshell:wallpaperSelectorToggle
    bind = $shiftMod, P, exec, wallpaper-random
    bind = $mod, F2, exec, night-shift

    # Window focus and movement.
    bind = $mainMod, Left, movefocus, l
    bind = $mainMod, Right, movefocus, r
    bind = $mainMod, Up, movefocus, u
    bind = $mainMod, Down, movefocus, d
    bind = $shiftMod, Left, movewindow, l
    bind = $shiftMod, Right, movewindow, r
    bind = $shiftMod, Up, movewindow, u
    bind = $shiftMod, Down, movewindow, d

    bindm = $mod, mouse:272, movewindow
    bindm = $mod, mouse:273, resizewindow
    bindm = $mod, Control_L, movewindow
    bindm = $mod, ALT_L, resizewindow

    # Super+Tab enters resize mode.
    # End-4 workspace overview is moved to Super+Shift+Tab.
    bind = $shiftMod, R, submap, resize
    submap = resize
    binde = , Left, resizeactive, -40 0
    binde = , Right, resizeactive, 40 0
    binde = , Up, resizeactive, 0 -40
    binde = , Down, resizeactive, 0 40
    binde = , mouse_up, resizeactive, 40 0
    binde = , mouse_down, resizeactive, -40 0
    binde = SHIFT, mouse_up, resizeactive, 0 40
    binde = SHIFT, mouse_down, resizeactive, 0 -40
    bind = , Escape, submap, global
    bind = , Return, submap, global
    bind = , Tab, submap, global
    bind = $shiftMod, R, submap, global
    submap = global

    # Screenshots.
    bind = , Print, exec, ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.wl-clipboard}/bin/wl-copy
    bind = $mainMod, Print, exec, mkdir -p ~/Pictures && ${pkgs.grim}/bin/grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
    bind = $shiftMod, Print, exec, mkdir -p ~/Pictures && ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png

    # Workspaces.
${workspaceDispatchBinds}

    # Hardware keys.
    bindl = , XF86AudioMute, exec, sound-toggle
    bindl = , XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause
    bindl = , XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next
    bindl = , XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous
    bindl = , switch:Lid Switch, global, quickshell:lock

    bindle = , XF86AudioRaiseVolume, exec, sound-up
    bindle = , XF86AudioLowerVolume, exec, sound-down
    bindle = , XF86MonBrightnessUp, exec, brightness-up
    bindle = , XF86MonBrightnessDown, exec, brightness-down
  '';

  hyprCustomKeybinds = ''
    # Intentionally empty.
    # Own the main hyprland/keybinds.conf directly to avoid End-4 conflicts.
  '';

  hyprCustomGeneral = ''
    # Keep the local layer on a classic tiled Hyprland layout.
    general {
        layout = dwindle
        gaps_in = 3
        gaps_out = 6
        border_size = 3
        no_focus_fallback = true
        col.active_border = rgba(00d9ffff)
        col.inactive_border = rgba(3c3836ff)
    }

    dwindle {
        preserve_split = true
        smart_split = false
        smart_resizing = false
        precise_mouse_move = true
    }

    binds {
        drag_threshold = 10
    }

    gestures {
        workspace_swipe_distance = 320
        workspace_swipe_cancel_ratio = 0.2
        workspace_swipe_min_speed_to_force = 5
        workspace_swipe_direction_lock = true
        workspace_swipe_direction_lock_threshold = 10
        workspace_swipe_create_new = true
    }

    misc {
        # Disable panel VRR to avoid intermittent flicker on this internal eDP.
        vrr = 0
    }

    render {
        # Keep scanout path conservative for hybrid graphics stability.
        direct_scanout = false
    }

    cursor {
        # On some hybrid/NVIDIA laptops this removes visible cursor-related
        # flicker/artifacts under Wayland compositors.
        no_hardware_cursors = true
    }

    decoration {
        rounding = 8
        dim_inactive = false

        blur {
            enabled = true
            xray = false
            size = 4
            passes = 1
            vibrancy = 0.15
        }

        shadow {
            enabled = false
        }
    }

    input {
        touchpad {
            clickfinger_behavior = false
            natural_scroll = true
            tap-to-click = true
            tap_button_map = lrm
        }
    }
  '';

  hyprCustomExecs = ''
    # Align Hyprland's runtime cursor with the Home Manager theme.
    exec-once = hyprctl setcursor Bibata-Modern-Classic 24
  '';

  hyprCustomMonitors = ''
    # Pin the internal panel to its native mode so Hyprland does not soften the
    # session with a fallback mode.
    monitor = eDP-1, 1920x1080@144, 0x0, 1, vrr, 0
  '';
in
{
  options.modules.hyprland = {
    enable = lib.mkEnableOption "Hyprland configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      soundUp
      soundDown
      soundToggle
      brightnessUp
      brightnessDown
      nightLightToggle
      nightShift
      clipboardPicker
      searchLauncher
      fileManager
      wallpaperSwitch
      wallpaperRandom
    ];

    # The soymou/illogical-flake manages most of Hyprland; keep overrides in custom/*.
    xdg.configFile."hypr/custom/execs.conf".source = lib.mkForce (
      pkgs.writeText "hypr-custom-execs.conf" hyprCustomExecs
    );

    xdg.configFile."hypr/custom/keybinds.conf".source = lib.mkForce (
      pkgs.writeText "hypr-custom-keybinds.conf" hyprCustomKeybinds
    );

    xdg.configFile."hypr/hyprland/keybinds.conf".source = lib.mkForce (
      pkgs.writeText "hypr-hyprland-keybinds.conf" hyprMainKeybinds
    );

    xdg.configFile."hypr/hyprland/execs.conf".source = lib.mkForce (
      pkgs.writeText "hypr-hyprland-execs.conf" hyprPatchedExecs
    );

    xdg.configFile."hypr/hypridle.conf".source = lib.mkForce (
      pkgs.writeText "hypr-hypridle.conf" hyprIdleConf
    );

    xdg.configFile."hypr/monitors.conf".source = lib.mkForce (
      pkgs.writeText "hypr-monitors.conf" hyprCustomMonitors
    );

    xdg.configFile."hypr/hyprland/general.conf".source = lib.mkForce (
      pkgs.writeText "hypr-hyprland-general.conf" hyprPatchedGeneral
    );

    xdg.configFile."hypr/hyprland/rules.conf".source = lib.mkForce (
      pkgs.writeText "hypr-hyprland-rules.conf" hyprPatchedRules
    );

    # Keep style/input tuning here; illogical's default execs.conf already starts qs.
    xdg.configFile."hypr/custom/general.conf".source = lib.mkForce (
      pkgs.writeText "hypr-custom-general.conf" hyprCustomGeneral
    );
  };
}
