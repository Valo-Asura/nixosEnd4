{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.quickshell;
  ilyamiroSource = inputs.ilyamiro-nixos-configuration;

  profileStateDir = "$HOME/.local/state/quickshell";
  profileStateFile = "${profileStateDir}/profile";
  defaultProfile = cfg.activeProfile;

  ilyamiroHyprScripts =
    pkgs.runCommand "ilyamiro-quickshell-scripts-low-resource"
      {
        buildInputs = [
          pkgs.bash
          pkgs.perl
        ];
      }
      ''
        cp -r ${ilyamiroSource}/config/sessions/hyprland/scripts $out
        chmod -R u+w $out

        patchShebangs $out

        substituteInPlace $out/quickshell/Config.qml \
          --replace 'property bool openGuideAtStartup: true' 'property bool openGuideAtStartup: false' \
          --replace 'property bool topbarHelpIcon: true' 'property bool topbarHelpIcon: false' \
          --replace 'property int workspaceCount: 8' 'property int workspaceCount: 9' \
          --replace 'property int initialWorkspaceCount: 8' 'property int initialWorkspaceCount: 9'

        substituteInPlace $out/quickshell/SysData.qml \
          --replace 'interval: 2000' 'interval: ${toString cfg.pollInterval}'

        substituteInPlace $out/quickshell/workspaces.sh \
          --replace ".workspaceCount // 8" ".workspaceCount // 9"

        ${lib.optionalString cfg.lowResource ''
                    substituteInPlace $out/quickshell/Main.qml \
                      --replace 'let widgetsToPreload = ["settings", "search", "help"];' 'let widgetsToPreload = [];'

                    perl -0pi -e 'my $from = q{if ! pgrep -f "quickshell.*Floating\.qml" >/dev/null; then
              quickshell -p "$FLOATING_QML_PATH" >/dev/null 2>&1 &
              disown
          fi}; my $to = q{if [ "''${QS_ENABLE_FLOATING:-0}" = "1" ] && ! pgrep -f "quickshell.*Floating\.qml" >/dev/null; then
              quickshell -p "$FLOATING_QML_PATH" >/dev/null 2>&1 &
              disown
          fi}; s/\Q$from\E/$to/ or die "failed to patch ilyamiro floating watchdog\n";' \
                      $out/qs_manager.sh
        ''}
      '';

  quickshellProfile = pkgs.writeShellScriptBin "quickshell-profile" ''
    set -euo pipefail

    mkdir -p "${profileStateDir}"

    current_profile() {
      if [ -s "${profileStateFile}" ]; then
        read -r profile < "${profileStateFile}"
        case "$profile" in
          end4|ilyamiro)
            printf '%s\n' "$profile"
            return 0
            ;;
        esac
      fi

      printf '%s\n' "${defaultProfile}"
    }

    case "''${1:-get}" in
      get|status)
        current_profile
        ;;
      set)
        profile="''${2:-}"
        case "$profile" in
          end4|ilyamiro)
            printf '%s\n' "$profile" > "${profileStateFile}"
            ;;
          *)
            echo "usage: quickshell-profile set end4|ilyamiro" >&2
            exit 2
            ;;
        esac
        ;;
      *)
        echo "usage: quickshell-profile [get|status|set end4|ilyamiro]" >&2
        exit 2
        ;;
    esac
  '';

  quickshellSession = pkgs.writeShellScriptBin "quickshell-session" ''
    set -euo pipefail

    profile="$(${quickshellProfile}/bin/quickshell-profile get)"

    stop_shells() {
      ${pkgs.procps}/bin/pkill -x qs 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -x quickshell 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "$HOME/.config/quickshell/ii" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "$HOME/.config/hypr/scripts/quickshell" 2>/dev/null || true
    }

    start_end4() {
      exec qs -p "$HOME/.config/quickshell/ii"
    }

    start_ilyamiro() {
      qs_dir="$HOME/.config/hypr/scripts/quickshell"
      if [ ! -f "$qs_dir/Main.qml" ] || [ ! -f "$qs_dir/TopBar.qml" ]; then
        ${pkgs.libnotify}/bin/notify-send -a quickshell "Quickshell" "ilyamiro profile is not installed"
        exit 1
      fi

      quickshell -p "$qs_dir/Main.qml" >/dev/null 2>&1 &
      quickshell -p "$qs_dir/TopBar.qml" >/dev/null 2>&1 &
    }

    case "''${1:-start}" in
      start)
        case "$profile" in
          end4) start_end4 ;;
          ilyamiro) start_ilyamiro ;;
        esac
        ;;
      stop)
        stop_shells
        ;;
      restart|reload)
        stop_shells
        sleep 0.35
        exec "$0" start
        ;;
      profile)
        ${quickshellProfile}/bin/quickshell-profile set "''${2:-}"
        exec "$0" restart
        ;;
      status)
        printf 'profile=%s\n' "$profile"
        if ${pkgs.procps}/bin/pgrep -x qs >/dev/null 2>&1 || ${pkgs.procps}/bin/pgrep -x quickshell >/dev/null 2>&1; then
          printf 'running=yes\n'
        else
          printf 'running=no\n'
        fi
        ;;
      *)
        echo "usage: quickshell-session [start|stop|restart|reload|status|profile end4|ilyamiro]" >&2
        exit 2
        ;;
    esac
  '';

  quickshellSwitch = pkgs.writeShellScriptBin "quickshell-switch" ''
    exec ${quickshellSession}/bin/quickshell-session profile "$@"
  '';

  quickshellReload = pkgs.writeShellScriptBin "quickshell-reload" ''
    exec ${quickshellSession}/bin/quickshell-session restart
  '';

  quickshellCommand = pkgs.writeShellScriptBin "quickshell" ''
    exec qs "$@"
  '';
in
{
  options.modules.quickshell = {
    enable = lib.mkEnableOption "central Quickshell profile, clipboard, and resource integration";

    activeProfile = lib.mkOption {
      type = lib.types.enum [
        "end4"
        "ilyamiro"
      ];
      default = "end4";
      description = "Quickshell profile to start from Hyprland.";
    };

    installIlyamiroProfile = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install only the ilyamiro quickshell/scripts profile for runtime switching.";
    };

    lowResource = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Patch optional quickshell preload and polling behavior for lower idle cost.";
    };

    pollInterval = lib.mkOption {
      type = lib.types.int;
      default = 10000;
      description = "Low-resource quickshell polling interval in milliseconds.";
    };

    updateInterval = lib.mkOption {
      type = lib.types.int;
      default = 2000;
      description = "Resource data staleness window in milliseconds.";
    };

    showGpu = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show GPU temperature in the End-4 resource widget.";
    };

    showFan = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show fan speed in the End-4 resource widget.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      quickshellCommand
      quickshellProfile
      quickshellSession
      quickshellSwitch
      quickshellReload
    ]
    ++ (with pkgs; [
      acpi
      bluez
      inotify-tools
      iw
      lm_sensors
      socat
      awww
      tree
    ]);

    systemd.user.services.cliphist-text = {
      Unit = {
        Description = "Store Wayland text clipboard history";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
        Restart = "on-failure";
        RestartSec = "2s";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.services.cliphist-image = {
      Unit = {
        Description = "Store Wayland image clipboard history";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
        Restart = "on-failure";
        RestartSec = "2s";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    home.activation.installQuickshellProfiles = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      set -euo pipefail

      mkdir -p "${profileStateDir}"
      printf '%s\n' "${defaultProfile}" > "${profileStateFile}"

      if ${lib.boolToString cfg.installIlyamiroProfile}; then
        dest="$HOME/.config/hypr/scripts"
        mkdir -p "$(dirname "$dest")"

        if [ -L "$dest" ]; then
          rm -f "$dest"
        fi

        mkdir -p "$dest"
        ${pkgs.rsync}/bin/rsync -a --delete "${ilyamiroHyprScripts}/" "$dest/"
        chmod -R u+rwX "$dest"

        settings="$HOME/.config/hypr/settings.json"
        if [ ! -s "$settings" ] || ! ${pkgs.jq}/bin/jq -e . "$settings" >/dev/null 2>&1; then
          printf '{}\n' > "$settings"
        fi

        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        ${pkgs.jq}/bin/jq \
          '.openGuideAtStartup = false
           | .topbarHelpIcon = false
           | .workspaceCount = (.workspaceCount // 9)
           | .uiScale = (.uiScale // 1.0)' \
          "$settings" > "$tmp"
        mv "$tmp" "$settings"
      fi
    '';
  };
}
