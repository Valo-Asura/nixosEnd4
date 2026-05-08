{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.quickshell;

  profileStateDir = "$HOME/.local/state/quickshell";
  profileStateFile = "${profileStateDir}/profile";
  defaultProfile = cfg.activeProfile;
  homeProfileBin = "${config.home.homeDirectory}/.local/state/nix/profiles/home-manager/home-path/bin";
  homeProfileShare = "${config.home.homeDirectory}/.local/state/nix/profiles/home-manager/home-path/share";
  userProfileBin = "/etc/profiles/per-user/${config.home.username}/bin";
  userProfileShare = "/etc/profiles/per-user/${config.home.username}/share";

  qsPackage = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    xorg = pkgs.xorg // {
      libxcb = pkgs.libxcb;
    };
  };

  qtImports = [
    pkgs.kdePackages.qtbase
    pkgs.kdePackages.qtdeclarative
    pkgs.kdePackages.qtsvg
    pkgs.kdePackages.qtwayland
    pkgs.kdePackages.qt5compat
    pkgs.kdePackages.qtimageformats
    pkgs.kdePackages.qtmultimedia
    pkgs.kdePackages.qtpositioning
    pkgs.kdePackages.qtsensors
    pkgs.kdePackages.qtquicktimeline
    pkgs.kdePackages.qttools
    pkgs.kdePackages.qttranslations
    pkgs.kdePackages.qtvirtualkeyboard
    pkgs.kdePackages.qtwebsockets
    pkgs.kdePackages.syntax-highlighting
    pkgs.kdePackages.kirigami.unwrapped
  ];

  quickshellPython = pkgs.python3.withPackages (ps: [
    ps.build
    ps.cffi
    ps.click
    ps."dbus-python"
    ps."kde-material-you-colors"
    ps.libsass
    ps.loguru
    ps."material-color-utilities"
    ps.materialyoucolor
    ps.numpy
    ps.pillow
    ps.psutil
    ps.pycairo
    ps.pygobject3
    ps.pywayland
    ps.setproctitle
    ps."setuptools-scm"
    ps.tqdm
    ps.wheel
    ps."pyproject-hooks"
    ps.opencv4
  ]);

  end4SourcePatched = pkgs.runCommand "x15-end4-quickshell-local" { buildInputs = [ pkgs.bash ]; } ''
    cp -r ${./profiles/end4/ii} $out
    chmod -R u+w $out
    patchShebangs $out

    substituteInPlace $out/services/TimerService.qml \
      --replace-fail 'interval: 1000' 'interval: ${toString cfg.updateInterval}'

    if grep -q 'property bool enableGpu:' $out/modules/ii/bar/ResourcesPopup.qml; then
      substituteInPlace $out/modules/ii/bar/ResourcesPopup.qml \
        --replace-fail 'property bool enableGpu: true' 'property bool enableGpu: ${
          if cfg.showGpu then "true" else "false"
        }' \
        --replace-fail 'property bool enableFan: true' 'property bool enableFan: ${
          if cfg.showFan then "true" else "false"
        }'
    fi

    find $out -type f -name '*.sh' -print0 \
      | xargs -0 sed -i '/ILLOGICAL_IMPULSE_VIRTUAL_ENV/d'
  '';

  quickshellConfigSource = pkgs.runCommand "x15-quickshell-config" { } ''
    mkdir -p $out
    ln -s ${end4SourcePatched} $out/ii
  '';

  ilyamiroHyprScripts =
    pkgs.runCommand "ilyamiro-quickshell-scripts-low-resource"
      {
        buildInputs = [
          pkgs.bash
          pkgs.perl
        ];
      }
      ''
        cp -r ${./profiles/ilyamiro/scripts} $out
        chmod -R u+w $out

        patchShebangs $out

        substituteInPlace $out/quickshell/Config.qml \
          --replace-fail 'property bool openGuideAtStartup: true' 'property bool openGuideAtStartup: false' \
          --replace-fail 'property bool topbarHelpIcon: true' 'property bool topbarHelpIcon: false' \
          --replace-fail 'property int workspaceCount: 8' 'property int workspaceCount: 9' \
          --replace-fail 'property int initialWorkspaceCount: 8' 'property int initialWorkspaceCount: 9'

        substituteInPlace $out/quickshell/SysData.qml \
          --replace-fail 'interval: 2000' 'interval: ${toString cfg.pollInterval}'

        substituteInPlace $out/quickshell/workspaces.sh \
          --replace-fail ".workspaceCount // 8" ".workspaceCount // 9"

        ${lib.optionalString cfg.lowResource ''
          substituteInPlace $out/quickshell/Main.qml \
            --replace-fail 'let widgetsToPreload = ["settings", "search", "help"];' 'let widgetsToPreload = [];'

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

  managedSettings = {
    apps = {
      bluetooth = "blueman-manager";
      changePassword = "kitty -1 --hold sh -lc 'passwd'";
      manageUser = "kitty -1 --hold sh -lc 'passwd'";
      network = "kitty -1 --hold sh -lc 'nmtui'";
      networkEthernet = "kitty -1 --hold sh -lc 'nmtui'";
      taskManager = "kitty -1 btm";
      terminal = "kitty -1";
      update = "kitty -1 --hold sh -lc 'sudo nixos-rebuild switch --flake /etc/nixos#x15xs'";
    };
    appearance.wallpaperTheming = {
      enableAppsAndShell = true;
      enableQtApps = false;
      enableTerminal = true;
      terminalGenerationProps.forceDarkMode = true;
    };
    background.parallax = {
      enableSidebar = false;
      enableWorkspace = false;
      workspaceZoom = 1.0;
    };
    bar.utilButtons = {
      showChargeLimitToggle = true;
      showDarkModeToggle = true;
      showPerformanceProfileToggle = false;
    };
    bar.weather = {
      enable = true;
      enableGPS = false;
      city = "Gumaniwala, Uttarakhand, India 249204";
      useUSCS = false;
      fetchInterval = 10;
    };
    calendar.locale = "en-GB";
    conflictKiller.autoKillNotificationDaemons = true;
    language.ui = "en_US";
    light.night = {
      automatic = true;
      colorTemperature = 3966;
    };
    lock.blur = {
      enable = true;
      extraZoom = 1.05;
      radius = 64;
    };
    lock.useHyprlock = false;
    resources = {
      updateInterval = cfg.pollInterval;
      historyLength = 30;
    };
    sidebar.keepRightSidebarLoaded = false;
    time = {
      dateFormat = "ddd, dd/MM";
      dateWithYearFormat = "dd/MM/yyyy";
      format = "hh:mm AP";
      pomodoro.focus = 2700;
      secondPrecision = false;
      shortDateFormat = "dd/MM";
    };
  };

  managedSettingsJson = pkgs.writeText "x15-quickshell-settings.json" (
    builtins.toJSON managedSettings
  );

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

    service_name="x15-quickshell.service"

    systemd_available() {
      command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1
    }

    service_is_active() {
      systemd_available && systemctl --user --quiet is-active "$service_name"
    }

    restart_service_if_active() {
      if [ "''${QUICKSHELL_SESSION_NO_SYSTEMD:-0}" != 1 ] && service_is_active; then
        exec systemctl --user restart "$service_name"
      fi
    }

    stop_service_if_active() {
      if [ "''${QUICKSHELL_SESSION_NO_SYSTEMD:-0}" != 1 ] && service_is_active; then
        systemctl --user stop "$service_name" || true
      fi
    }

    stop_shells() {
      ${qsCommand}/bin/qs kill -c ii --any-display >/dev/null 2>&1 || true
      ${pkgs.procps}/bin/pkill -x qs 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -x quickshell 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "$HOME/.config/quickshell/ii" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "$HOME/.config/hypr/scripts/quickshell" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "$HOME/.config/hypr/scripts/qs_manager.sh" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "$HOME/.config/hypr/scripts/settings_watcher.sh" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "inotifywait .* /tmp/qs_widget_state" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "inotifywait .* /tmp/qs_current_widget" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "inotifywait .* /tmp/qs_workspaces.json" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "cat /tmp/qs_widget_state" 2>/dev/null || true
    }

    start_end4() {
      exec ${qsCommand}/bin/qs -c ii
    }

    start_ilyamiro() {
      qs_dir="$HOME/.config/hypr/scripts/quickshell"
      if [ ! -f "$qs_dir/Main.qml" ] || [ ! -f "$qs_dir/TopBar.qml" ]; then
        ${pkgs.libnotify}/bin/notify-send -a quickshell "Quickshell" "ilyamiro profile is not installed"
        exit 1
      fi

      ${quickshellCommand}/bin/quickshell -p "$qs_dir/Main.qml" >/dev/null 2>&1 &
      main_pid="$!"
      ${quickshellCommand}/bin/quickshell -p "$qs_dir/TopBar.qml" >/dev/null 2>&1 &
      topbar_pid="$!"

      cleanup_ilyamiro() {
        kill "$main_pid" "$topbar_pid" 2>/dev/null || true
        wait "$main_pid" "$topbar_pid" 2>/dev/null || true
      }

      trap cleanup_ilyamiro INT TERM EXIT
      wait -n "$main_pid" "$topbar_pid"
    }

    start_profile() {
      profile="$1"
      case "$profile" in
        end4) start_end4 ;;
        ilyamiro) start_ilyamiro ;;
        *)
          ${pkgs.libnotify}/bin/notify-send -a quickshell "Quickshell" "Unknown profile: $profile" || true
          exit 2
          ;;
      esac
    }

    case "''${1:-start}" in
      start)
        stop_shells
        sleep 0.15
        start_profile "$(${quickshellProfile}/bin/quickshell-profile get)"
        ;;
      boot|start-default)
        ${quickshellProfile}/bin/quickshell-profile set "${defaultProfile}"
        stop_shells
        start_profile "${defaultProfile}"
        ;;
      stop)
        stop_service_if_active
        stop_shells
        ;;
      restart|reload)
        restart_service_if_active
        stop_shells
        sleep 0.35
        exec "$0" start
        ;;
      profile)
        ${quickshellProfile}/bin/quickshell-profile set "''${2:-}"
        restart_service_if_active
        exec "$0" restart
        ;;
      status)
        profile="$(${quickshellProfile}/bin/quickshell-profile get)"
        printf 'profile=%s\n' "$profile"
        if ${qsCommand}/bin/qs list --all 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q 'Config path:'; then
          printf 'running=yes\n'
        else
          printf 'running=no\n'
        fi
        ;;
      *)
        echo "usage: quickshell-session [start|boot|start-default|stop|restart|reload|status|profile end4|ilyamiro]" >&2
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
    exec ${qsCommand}/bin/qs "$@"
  '';

  qsCommand = pkgs.writeShellScriptBin "qs" ''
    export QT_PLUGIN_PATH="${lib.makeSearchPath "lib/qt-6/plugins" qtImports}:${lib.makeSearchPath "lib/qt6/plugins" qtImports}:${lib.makeSearchPath "lib/plugins" qtImports}"
    export QML2_IMPORT_PATH="${lib.makeSearchPath "lib/qt-6/qml" qtImports}"
    export XDG_DATA_DIRS="${
      lib.makeSearchPath "share" [
        pkgs.adwaita-icon-theme
        pkgs.hicolor-icon-theme
        pkgs.papirus-icon-theme
        pkgs.gnome-icon-theme
        pkgs.kdePackages.breeze-icons
        pkgs.lxqt.pavucontrol-qt
        pkgs.pavucontrol
      ]
    }:${homeProfileShare}:$HOME/.nix-profile/share:$HOME/.local/share:/etc/profiles/per-user/$USER/share:/run/current-system/sw/share:/usr/share:''${XDG_DATA_DIRS:-}"
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    export QT_QPA_PLATFORMTHEME=gtk3
    export QSG_RENDER_LOOP="''${QSG_RENDER_LOOP:-basic}"
    export PATH="${quickshellPython}/bin:${homeProfileBin}:$PATH"

    exec ${qsPackage}/bin/qs "$@"
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
      description = "Install the vendored ilyamiro quickshell/scripts profile for runtime switching.";
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
      description = "Show GPU temperature in the End4 resource widget.";
    };

    showFan = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show fan speed in the End4 resource widget.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      qsCommand
      quickshellCommand
      quickshellProfile
      quickshellSession
      quickshellSwitch
      quickshellReload
      quickshellPython
    ]
    ++ qtImports
    ++ (with pkgs; [
      acpi
      adw-gtk3
      awww
      axel
      bc
      bluez
      cava
      ddcutil
      easyeffects
      ffmpeg
      fuzzel
      glib
      gnome-icon-theme
      gobject-introspection
      hicolor-icon-theme
      hypridle
      hyprlock
      hyprpicker
      hyprshot
      hyprsunset
      imagemagick
      inotify-tools
      iw
      kdePackages.breeze-icons
      kdePackages.kdialog
      kdePackages.kirigami
      kdePackages.polkit-kde-agent-1
      libdbusmenu-gtk3
      libportal-gtk4
      libqalculate
      libsForQt5.qtgraphicaleffects
      libsForQt5.qtsvg
      libsecret
      lm_sensors
      lxqt.pavucontrol-qt
      matugen
      material-icons
      material-symbols
      mpv
      mpvpaper
      nerd-fonts.iosevka
      nerd-fonts.symbols-only
      networkmanagerapplet
      papirus-icon-theme
      pulseaudio
      qt6Packages.qt6ct
      rsync
      sassc
      slurp
      socat
      songrec
      swappy
      tesseract
      translate-shell
      tree
      upower
      wayland-protocols
      wget
      wireplumber
      wlogout
      wofi
      wofi-emoji
      wtype
      xdg-user-dirs
      ydotool
    ]);

    xdg.configFile."quickshell" = {
      source = lib.mkForce quickshellConfigSource;
      force = true;
    };
    xdg.configFile."fuzzel" = {
      source = lib.mkForce ./profiles/end4/fuzzel;
      recursive = true;
      force = true;
    };
    xdg.configFile."gtk-4.0/gtk.css".force = lib.mkForce true;
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

    systemd.user.services.x15-quickshell = {
      Unit = {
        Description = "x15xs QuickShell session";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${quickshellSession}/bin/quickshell-session start";
        ExecStop = "${pkgs.coreutils}/bin/env QUICKSHELL_SESSION_NO_SYSTEMD=1 ${quickshellSession}/bin/quickshell-session stop";
        Restart = "always";
        RestartSec = "2s";
        Environment = [
          "PATH=${homeProfileBin}:${userProfileBin}:${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:/run/wrappers/bin"
          "XDG_DATA_DIRS=${homeProfileShare}:${userProfileShare}:${config.home.homeDirectory}/.nix-profile/share:${config.home.homeDirectory}/.local/share:/run/current-system/sw/share:/usr/share"
        ];
        # QuickShell can launch desktop apps. Keep service stops scoped to the
        # shell process so switching profiles cannot kill apps in the same cgroup.
        KillMode = "process";
        TimeoutStopSec = "5s";
      };
    };

    home.activation.installQuickshellProfiles = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      set -euo pipefail

      mkdir -p "${profileStateDir}"
      if [ ! -s "${profileStateFile}" ] || ! ${pkgs.gnugrep}/bin/grep -Eq '^(end4|ilyamiro)$' "${profileStateFile}"; then
        printf '%s\n' "${defaultProfile}" > "${profileStateFile}"
      fi

      mkdir -p "$HOME/.config/illogical-impulse"
      shell_settings="$HOME/.config/illogical-impulse/config.json"
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      if [ ! -s "$shell_settings" ] || ! ${pkgs.jq}/bin/jq -e . "$shell_settings" >/dev/null 2>&1; then
        printf '{}\n' > "$shell_settings"
      fi
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$shell_settings" "${managedSettingsJson}" > "$tmp"
      mv "$tmp" "$shell_settings"

      mkdir -p "$HOME/.config/illogical-impulse/translations"
      if [ ! -s "$HOME/.config/illogical-impulse/translations/en_US.json" ]; then
        printf '{}\n' > "$HOME/.config/illogical-impulse/translations/en_US.json"
      fi

      state_dir="$HOME/.local/state/quickshell/user"
      mkdir -p "$state_dir"
      if [ ! -s "$state_dir/todo.json" ] || ! ${pkgs.jq}/bin/jq -e 'type == "array"' "$state_dir/todo.json" >/dev/null 2>&1; then
        printf '[]\n' > "$state_dir/todo.json"
      fi
      touch "$state_dir/notes.txt"

      mkdir -p "$HOME/.config/gtk-4.0"
      gtk_css="$HOME/.config/gtk-4.0/gtk.css"
      if [ ! -f "$gtk_css" ]; then
        printf '@import url("file://${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0/gtk.css");\n' > "$gtk_css"
      fi

      matugen_dir="$HOME/.config/matugen"
      if [ -L "$matugen_dir" ]; then
        rm -f "$matugen_dir"
      fi

      mkdir -p "$matugen_dir"
      ${pkgs.rsync}/bin/rsync -a --delete "${./profiles/end4/matugen}/" "$matugen_dir/"
      chmod -R u+rwX "$matugen_dir"
      ln -sfn "$state_dir/generated/colors.json" "$matugen_dir/colors.json"

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
