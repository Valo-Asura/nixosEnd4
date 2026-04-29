{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.illogical-impulse;
  dotfilesSource = inputs.illogical-flake.inputs.dotfiles;
  gtk4CssSeed = pkgs.writeText "illogical-impulse-gtk4.css" ''
    /**
     * GTK 4 reads the theme configured by gtk-theme-name, but ignores it.
     * It does however respect user CSS, so import the theme from here.
    **/
    @import url("file://${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0/gtk.css");
  '';
  quickshellSourcePatched =
    pkgs.runCommand "quickshell-patched-local"
      {
        buildInputs = [
          pkgs.bash
          config.programs.illogical-impulse.internal.pythonEnv
        ];
      }
      ''
                      cp -r ${dotfilesSource}/dots/.config/quickshell $out
                      chmod -R +w $out
                      cp ${./overrides/Todo.qml} "$out/ii/services/Todo.qml"
                      cp ${./overrides/ChargeLimit.qml} "$out/ii/services/ChargeLimit.qml"
                      cp ${./overrides/UtilButtons.qml} "$out/ii/modules/ii/bar/UtilButtons.qml"

                      find "$out" -name "*.py" -print0 | xargs -0 sed -i \
                        's|^#!.*ILLOGICAL_IMPULSE_VIRTUAL_ENV.*|#!/usr/bin/env python3|'

                      sed -i \
                        's|cp "$SCRIPT_DIR/terminal/sequences.txt" "$STATE_DIR"/user/generated/terminal/sequences.txt|cp "$SCRIPT_DIR/terminal/sequences.txt" "$STATE_DIR"/user/generated/terminal/sequences.txt\
                chmod u+w "$STATE_DIR"/user/generated/terminal/sequences.txt|' \
                        "$out/ii/scripts/colors/applycolor.sh"

                      # Make switchwall non-interactive with newer matugen builds.
                      sed -i \
                        's|^    matugen .*|    matugen --source-color-index 0 --prefer closest-to-fallback "''${matugen_args[@]}"|' \
                        "$out/ii/scripts/colors/switchwall.sh"

                      sed -i \
                        's|interval: 200|interval: 1000|' \
                        "$out/ii/services/TimerService.qml"

                      sed -i \
                        's|Quickshell.execDetached(\\["loginctl", "lock-session"\\]);|GlobalStates.screenLocked = true;|' \
                        "$out/ii/modules/common/functions/Session.qml"

                      sed -i \
                        '/function lock() {/,/^    }/c\    function lock() {\n        GlobalStates.screenLocked = true;\n    }' \
                        "$out/ii/modules/common/panels/lock/LockScreen.qml"

                      sed -i \
                        's|property bool showPerformanceProfileToggle: false|property bool showPerformanceProfileToggle: false\
                            property bool showChargeLimitToggle: false|' \
                        "$out/ii/modules/common/Config.qml"

                      sed -i \
                        '/text: Translation.tr("Performance Profile toggle")/,/}/c\            ConfigSwitch {\
        \                buttonIcon: "speed"\
        \                text: Translation.tr("Performance Profile toggle")\
        \                checked: Config.options.bar.utilButtons.showPerformanceProfileToggle\
        \                onCheckedChanged: {\
        \                    Config.options.bar.utilButtons.showPerformanceProfileToggle = checked;\
        \                }\
        \            }\
        \            ConfigSwitch {\
        \                buttonIcon: "battery_6_bar"\
        \                text: Translation.tr("Charge limit toggle")\
        \                checked: Config.options.bar.utilButtons.showChargeLimitToggle\
        \                onCheckedChanged: {\
        \                    Config.options.bar.utilButtons.showChargeLimitToggle = checked;\
        \                }\
        \            }' \
                        "$out/ii/modules/settings/BarConfig.qml"

                      patchShebangs "$out"
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
      updateInterval = 10000;
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

  managedSettingsJson = pkgs.writeText "illogical-impulse-managed-settings.json" (
    builtins.toJSON managedSettings
  );
in
{
  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "fuzzel".enable = lib.mkForce false;
      "gtk-4.0/gtk.css".enable = lib.mkForce false;
      "hypr/custom/scripts".enable = lib.mkForce false;
      "hypr/hyprland/colors.conf".enable = lib.mkForce false;
      "hypr/hyprlock".enable = lib.mkForce false;
      "matugen".enable = lib.mkForce false;
      "quickshell".source = lib.mkForce quickshellSourcePatched;
    };

    home.activation.mergeIllogicalImpulseSettings =
      lib.hm.dag.entryAfter [ "copyIllogicalImpulseConfigs" ]
        ''
          set -euo pipefail

          target="$HOME/.config/illogical-impulse/config.json"
          tmp="$(${pkgs.coreutils}/bin/mktemp)"

          mkdir -p "$HOME/.config/illogical-impulse"

          if [ ! -s "$target" ] || ! ${pkgs.jq}/bin/jq -e . "$target" >/dev/null 2>&1; then
            printf '{}\n' > "$target"
          fi

          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
            "$target" \
            "${managedSettingsJson}" > "$tmp"

          mv "$tmp" "$target"
        '';

    home.activation.prepareIllogicalImpulseMutableThemeOutputs =
      lib.hm.dag.entryAfter [ "linkGeneration" ]
        ''
                    set -euo pipefail

                    copy_mutable_dir() {
                      src="$1"
                      dest="$2"

                      mkdir -p "$(dirname "$dest")"
                      rm -rf "$dest"
                      cp -r "$src" "$dest"
                      chmod -R u+w "$dest"
                    }

                    copy_mutable_file() {
                      src="$1"
                      dest="$2"

                      mkdir -p "$(dirname "$dest")"
                      rm -f "$dest"
                      cp "$src" "$dest"
                      chmod u+w "$dest"
                    }

                    copy_mutable_dir "${dotfilesSource}/dots/.config/fuzzel" "$HOME/.config/fuzzel"
                    copy_mutable_dir "${dotfilesSource}/dots/.config/hypr/custom/scripts" "$HOME/.config/hypr/custom/scripts"
          copy_mutable_dir "${dotfilesSource}/dots/.config/matugen" "$HOME/.config/matugen"
          copy_mutable_file "${dotfilesSource}/dots/.config/hypr/hyprland/colors.conf" "$HOME/.config/hypr/hyprland/colors.conf"
          copy_mutable_file "${gtk4CssSeed}" "$HOME/.config/gtk-4.0/gtk.css"
          ln -sfn "$HOME/.local/state/quickshell/user/generated/colors.json" "$HOME/.config/matugen/colors.json"
        '';

    home.activation.bootstrapQuickshellUserState = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      set -euo pipefail

      state_dir="$HOME/.local/state/quickshell/user"
      todo_file="$state_dir/todo.json"
      notes_file="$state_dir/notes.txt"

      mkdir -p "$state_dir"

      if [ ! -s "$todo_file" ] || ! ${pkgs.jq}/bin/jq -e 'type == "array"' "$todo_file" >/dev/null 2>&1; then
        printf '[]\n' > "$todo_file"
      fi

      touch "$notes_file"
    '';

    home.activation.bootstrapMatugenDark =
      lib.hm.dag.entryAfter
        [
          "linkGeneration"
          "mergeIllogicalImpulseSettings"
          "prepareIllogicalImpulseMutableThemeOutputs"
        ]
        ''
          set -euo pipefail

          target="$HOME/.config/illogical-impulse/config.json"
          default_wallpaper="$HOME/.config/quickshell/ii/assets/images/default_wallpaper.png"
          wallpaper="$(${pkgs.jq}/bin/jq -r '.background.wallpaperPath // empty' "$target" 2>/dev/null || true)"

          if [ -z "$wallpaper" ] || [ "$wallpaper" = "null" ]; then
            wallpaper="$default_wallpaper"
            if [ -f "$wallpaper" ]; then
              tmp="$(${pkgs.coreutils}/bin/mktemp)"
              ${pkgs.jq}/bin/jq --arg path "$wallpaper" \
                '.background.wallpaperPath = $path' \
                "$target" > "$tmp"
              mv "$tmp" "$target"
            fi
          fi

          if [ -f "$wallpaper" ]; then
            size="$(${pkgs.imagemagick}/bin/magick identify -format '%w %h' "$wallpaper" 2>/dev/null || true)"
            if [ -n "$size" ]; then
              read -r width height <<<"$size"
              if [ "''${width:-0}" -lt 1920 ] || [ "''${height:-0}" -lt 1080 ]; then
                wallpaper="$default_wallpaper"
                if [ -f "$wallpaper" ]; then
                  tmp="$(${pkgs.coreutils}/bin/mktemp)"
                  ${pkgs.jq}/bin/jq --arg path "$wallpaper" \
                    '.background.wallpaperPath = $path | .background.thumbnailPath = ""' \
                    "$target" > "$tmp"
                  mv "$tmp" "$target"
                fi
              fi
            fi
          fi

          export PATH="$HOME/.nix-profile/bin:/run/current-system/sw/bin:$PATH"

          if [ -x "$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh" ] && [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            if ! "$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh" --mode dark --noswitch >/dev/null 2>&1; then
              if [ -f "$wallpaper" ]; then
                ${pkgs.matugen}/bin/matugen image "$wallpaper" --mode dark --source-color-index 0 --prefer closest-to-fallback >/dev/null 2>&1 || true
              fi
            fi
          elif [ -f "$wallpaper" ]; then
            ${pkgs.matugen}/bin/matugen image "$wallpaper" --mode dark --source-color-index 0 --prefer closest-to-fallback >/dev/null 2>&1 || true
          fi
        '';
  };
}
