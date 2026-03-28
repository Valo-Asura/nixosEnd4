{ config, lib, pkgs, ... }:

let
  cfg = config.modules.performance;
  isMax = cfg.profile == "max";
  isBalanced = cfg.profile == "balanced";
  isCool = cfg.profile == "cool";
in
{
  options.modules.performance = {
    enable = lib.mkEnableOption "performance tuning stack";

    profile = lib.mkOption {
      type = lib.types.enum [
        "max"
        "balanced"
        "cool"
      ];
      default = "balanced";
      description = ''
        Thermal and power profile:
        - max: highest performance, hottest idle/load behavior
        - balanced: reduced heat with strong performance
        - cool: lowest thermals/noise, reduced peak performance
      '';
    };

    nbfcProfile = lib.mkOption {
      type = lib.types.str;
      default = "Colorful X15 AT 22";
      description = "NBFC profile name used in /etc/nbfc/nbfc.json";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [
      "preempt=full"
      "threadirqs"
      "mitigations=off"
      "nvidia-drm.modeset=1"
    ]
    ++ lib.optionals isMax [
      "intel_idle.max_cstate=1"
      "i915.enable_psr=0"
    ]
    ++ lib.optionals (!isMax) [
      "intel_idle.max_cstate=9"
      "i915.enable_psr=1"
    ];

    boot.kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
      "kernel.numa_balancing" = 0;
    };

    zramSwap = {
      enable = true;
      algorithm = "lz4";
      memoryPercent = 50;
    };

    services.power-profiles-daemon.enable = false;

    services.tlp = {
      enable = true;
      settings = {
        # Alder Lake on this machine exposes only: performance, powersave.
        CPU_SCALING_GOVERNOR_ON_AC = if isMax then "performance" else "powersave";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_BOOST_ON_AC = if isMax then 1 else 0;
        CPU_BOOST_ON_BAT = 0;
        CPU_MAX_PERF_ON_AC =
          if isMax then
            100
          else if isBalanced then
            85
          else
            65;
        CPU_MAX_PERF_ON_BAT = if isCool then 45 else 60;
        PLATFORM_PROFILE_ON_AC =
          if isMax then
            "performance"
          else if isCool then
            "low-power"
          else
            "balanced";
        PLATFORM_PROFILE_ON_BAT = "low-power";
        RUNTIME_PM_ON_AC = if isMax then "on" else "auto";
        RUNTIME_PM_ON_BAT = "auto";
        PCIE_ASPM_ON_AC = if isMax then "default" else "powersupersave";
        PCIE_ASPM_ON_BAT = "powersupersave";
      };
    };

    systemd.oomd.enable = true;

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "x15-thermals" ''
        #!/usr/bin/env bash
        set -euo pipefail
        echo "Configured profile: ${cfg.profile}"
        echo
        echo "Thermal zones (milli-C):"
        for z in /sys/class/thermal/thermal_zone*; do
          [ -e "$z/type" ] || continue
          printf '  %-20s %s\n' "$(cat "$z/type")" "$(cat "$z/temp" 2>/dev/null || echo n/a)"
        done
        echo
        echo "Top CPU consumers:"
        ps -eo pid,pcpu,pmem,comm,args --sort=-pcpu | head -n 12
        echo
        echo "GPU:"
        nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,power.draw,pstate,memory.used --format=csv,noheader 2>/dev/null || true
      '')
      (pkgs.writeShellScriptBin "x15-power-status" ''
        #!/usr/bin/env bash
        set -euo pipefail
        echo "Configured profile: ${cfg.profile}"
        echo
        tlp-stat -s 2>/dev/null || true
        echo
        echo "CPU governors:"
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort -u | tr '\n' ' '; echo
        echo
        echo "Ollama service:"
        systemctl is-active ollama 2>/dev/null || true
      '')
    ];

    # TODO: Run `sudo nbfc config --recommend` after first boot and update this profile if needed.
    environment.etc."nbfc/nbfc.json".text = builtins.toJSON {
      SelectedConfigId = cfg.nbfcProfile;
    };

    systemd.services.nbfc_service = {
      description = "Notebook FanControl service";
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.kmod ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.nbfc-linux}/bin/nbfc_service --config-file /etc/nbfc/nbfc.json";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
