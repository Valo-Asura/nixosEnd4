{ config, lib, pkgs, ... }:

let
  cfg = config.modules.batteryCare;
  stateDir = "/var/lib/x15-charge-limit";
  stateFile = "${stateDir}/desired-state";

  batteryCareStatus = pkgs.writeShellScriptBin "x15-charge-limit-status" ''
    set -euo pipefail

    state_file="${stateFile}"
    default_desired="${if cfg.defaultEnabled then "enabled" else "disabled"}"
    desired_state="$default_desired"

    if [ -r "$state_file" ]; then
      desired_state="$(${pkgs.coreutils}/bin/cat "$state_file" 2>/dev/null || printf '%s' "$default_desired")"
    fi

    battery_name="$(${pkgs.findutils}/bin/find /sys/class/power_supply -maxdepth 1 -mindepth 1 -printf '%f\n' | ${pkgs.gnugrep}/bin/grep '^BAT' | ${pkgs.coreutils}/bin/head -n 1 || true)"
    tuxedo_profile_path=""
    current_profile=""
    current_stop_threshold="null"
    backend="unsupported"
    message="No supported battery charge limit backend detected"
    supported=false
    enabled=false

    for candidate in \
      /sys/devices/platform/tuxedo_keyboard/charging_profile/charging_profile \
      /sys/devices/platform/tuxedo_io/charging_profile/charging_profile; do
      if [ -r "$candidate" ]; then
        tuxedo_profile_path="$candidate"
        break
      fi
    done

    target_profile=""
    case "${toString cfg.stopThreshold}" in
      80) target_profile="stationary" ;;
      90) target_profile="balanced" ;;
      100) target_profile="high_capacity" ;;
    esac

    if [ -n "$tuxedo_profile_path" ]; then
      backend="tuxedo-profile"
      supported=true
      current_profile="$(${pkgs.coreutils}/bin/cat "$tuxedo_profile_path" 2>/dev/null || true)"
      case "$current_profile" in
        high_capacity) current_stop_threshold=100 ;;
        balanced) current_stop_threshold=90 ;;
        stationary) current_stop_threshold=80 ;;
      esac
      if [ -n "$target_profile" ] && [ "$current_profile" = "$target_profile" ]; then
        enabled=true
      fi
      message="Tuxedo charging profile backend detected"
    elif [ -n "$battery_name" ] && [ -r "/sys/class/power_supply/$battery_name/charge_control_end_threshold" ]; then
      backend="sysfs-threshold"
      supported=true
      current_stop_threshold="$(${pkgs.coreutils}/bin/cat "/sys/class/power_supply/$battery_name/charge_control_end_threshold" 2>/dev/null || printf 'null')"
      if [ "$current_stop_threshold" = "${toString cfg.stopThreshold}" ]; then
        enabled=true
      fi
      message="Sysfs battery threshold backend detected"
    elif [ -n "$battery_name" ]; then
      message="Battery detected, but this kernel exposes no writable charge limit backend"
    else
      message="No laptop battery detected"
    fi

    ${pkgs.jq}/bin/jq -n \
      --arg battery "$battery_name" \
      --arg backend "$backend" \
      --arg message "$message" \
      --arg desiredState "$desired_state" \
      --arg currentProfile "$current_profile" \
      --argjson available "$([ -n "$battery_name" ] && printf true || printf false)" \
      --argjson supported "$supported" \
      --argjson enabled "$enabled" \
      --argjson requestedStopThreshold ${toString cfg.stopThreshold} \
      --argjson currentStopThreshold "$current_stop_threshold" \
      '{
        available: $available,
        supported: $supported,
        enabled: $enabled,
        desiredEnabled: ($desiredState == "enabled"),
        backend: $backend,
        battery: (if $battery == "" then null else $battery end),
        requestedStopThreshold: $requestedStopThreshold,
        currentStopThreshold: $currentStopThreshold,
        currentProfile: (if $currentProfile == "" then null else $currentProfile end),
        message: $message
      }'
  '';

  batteryCareCtl = pkgs.writeShellScriptBin "x15-charge-limitctl" ''
    set -euo pipefail

    action="''${1:-status}"
    state_dir="${stateDir}"
    state_file="${stateFile}"
    battery_name="$(${pkgs.findutils}/bin/find /sys/class/power_supply -maxdepth 1 -mindepth 1 -printf '%f\n' | ${pkgs.gnugrep}/bin/grep '^BAT' | ${pkgs.coreutils}/bin/head -n 1 || true)"
    tuxedo_profile_path=""
    charge_end_path=""
    charge_type_path=""
    default_desired="${if cfg.defaultEnabled then "enabled" else "disabled"}"
    target_profile=""

    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

    for candidate in \
      /sys/devices/platform/tuxedo_keyboard/charging_profile/charging_profile \
      /sys/devices/platform/tuxedo_io/charging_profile/charging_profile; do
      if [ -w "$candidate" ]; then
        tuxedo_profile_path="$candidate"
        break
      fi
    done

    if [ -n "$battery_name" ] && [ -w "/sys/class/power_supply/$battery_name/charge_control_end_threshold" ]; then
      charge_end_path="/sys/class/power_supply/$battery_name/charge_control_end_threshold"
    fi

    if [ -n "$battery_name" ] && [ -w "/sys/class/power_supply/$battery_name/charge_type" ]; then
      charge_type_path="/sys/class/power_supply/$battery_name/charge_type"
    fi

    case "${toString cfg.stopThreshold}" in
      80) target_profile="stationary" ;;
      90) target_profile="balanced" ;;
      100) target_profile="high_capacity" ;;
    esac

    enable_limit() {
      ${pkgs.coreutils}/bin/printf 'enabled\n' > "$state_file"

      if [ -n "$tuxedo_profile_path" ]; then
        if [ -z "$target_profile" ]; then
          echo "Configured stop threshold ${toString cfg.stopThreshold}% is not supported by the Tuxedo profile backend" >&2
          return 1
        fi

        ${pkgs.coreutils}/bin/printf '%s\n' "$target_profile" > "$tuxedo_profile_path"
        return 0
      fi

      if [ -n "$charge_end_path" ]; then
        if [ -n "$charge_type_path" ]; then
          ${pkgs.coreutils}/bin/printf 'Custom\n' > "$charge_type_path" 2>/dev/null || true
        fi

        ${pkgs.coreutils}/bin/printf '%s\n' '${toString cfg.stopThreshold}' > "$charge_end_path"
        return 0
      fi

      echo "No supported battery charge limit backend detected" >&2
      return 1
    }

    disable_limit() {
      ${pkgs.coreutils}/bin/printf 'disabled\n' > "$state_file"

      if [ -n "$tuxedo_profile_path" ]; then
        ${pkgs.coreutils}/bin/printf 'high_capacity\n' > "$tuxedo_profile_path"
        return 0
      fi

      if [ -n "$charge_end_path" ]; then
        ${pkgs.coreutils}/bin/printf '100\n' > "$charge_end_path"
        return 0
      fi

      echo "No supported battery charge limit backend detected" >&2
      return 1
    }

    restore_limit() {
      local desired_state="$default_desired"

      if [ -r "$state_file" ]; then
        desired_state="$(${pkgs.coreutils}/bin/cat "$state_file" 2>/dev/null || printf '%s' "$default_desired")"
      fi

      if [ "$desired_state" = "enabled" ]; then
        enable_limit || true
      else
        disable_limit || true
      fi
    }

    case "$action" in
      enable)
        enable_limit
        ;;
      disable)
        disable_limit
        ;;
      restore)
        restore_limit
        ;;
      status)
        exec ${batteryCareStatus}/bin/x15-charge-limit-status
        ;;
      *)
        echo "Usage: x15-charge-limitctl {enable|disable|restore|status}" >&2
        exit 64
        ;;
    esac
  '';
in
{
  options.modules.batteryCare = {
    enable = lib.mkEnableOption "battery charge limit helpers";

    stopThreshold = lib.mkOption {
      type = lib.types.int;
      default = 90;
      description = "Stop charging at this percentage on supported backends.";
    };

    defaultEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the configured battery charge limit after boot by default.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "asura";
      description = "Desktop user allowed to toggle the battery charge limit service.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 root root -"
    ];

    environment.systemPackages = [
      batteryCareCtl
      batteryCareStatus
    ];

    systemd.services.x15-charge-limit-enable = {
      description = "Enable the battery charge limit";
      after = [ "tlp.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${batteryCareCtl}/bin/x15-charge-limitctl enable";
      };
    };

    systemd.services.x15-charge-limit-disable = {
      description = "Disable the battery charge limit";
      after = [ "tlp.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${batteryCareCtl}/bin/x15-charge-limitctl disable";
      };
    };

    systemd.services.x15-charge-limit-restore = {
      description = "Restore the desired battery charge limit state";
      wants = [ "tlp.service" ];
      after = [ "tlp.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${batteryCareCtl}/bin/x15-charge-limitctl restore";
      };
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id !== "org.freedesktop.systemd1.manage-units") {
          return polkit.Result.NOT_HANDLED;
        }

        if (subject.user !== "${cfg.user}") {
          return polkit.Result.NOT_HANDLED;
        }

        var unit = action.lookup("unit");
        var verb = action.lookup("verb");

        if ((unit === "x15-charge-limit-enable.service" || unit === "x15-charge-limit-disable.service") &&
            (verb === "start" || verb === "restart")) {
          return polkit.Result.YES;
        }

        return polkit.Result.NOT_HANDLED;
      });
    '';
  };
}
